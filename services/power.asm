#define SERVICE_CLASS 0x1fa4c95a

#define JD_POWER_POWER_STATUS_DISALLOWED 0x0
#define JD_POWER_POWER_STATUS_POWERING 0x1
#define JD_POWER_POWER_STATUS_OVERLOAD 0x2
#define JD_POWER_POWER_STATUS_OVERPROVISION 0x3

#define JD_POWER_REG_RW_ALLOWED JD_REG_RW_INTENSITY
#define JD_POWER_REG_RO_POWER_STATUS 0x81
#define JD_POWER_CMD_SHUTDOWN 0x80
#define JD_POWER_EV_POWER_STATUS_CHANGED JD_EV_CHANGE

#define MAX_POWER 900 // optional - needs ~19 ROM words

	BYTE	t_next_shutdown
	BYTE	t_re_enable
	BYTE    pwr_status
	BYTE    prev_pwr_status
	BYTE    switch_cnt
	BYTE	t_power_on_complete

txp_pwr_shutdown equ txp_serv0
txp_pwr_allowed equ txp_serv1
txp_pwr_status equ txp_serv2
#ifdef MAX_POWER
txp_pwr_max equ txp_serv3
#endif

#define SERV_BLINK .serv_blink

.serv_blink EXPAND
	if (pwr_status == JD_POWER_POWER_STATUS_POWERING) {
		mov a, t16_4us
		and a, 0xf0
		ifset ZF
			.led_on // 1/16 duty LED on
	}
ENDM

.serv_init EXPAND
	PAC.PIN_SWITCH = 1
	PA.PIN_SWITCH = 1
	call rng_next
	and a, 0xf // 0-240ms
	mov t_next_shutdown, a
	pwr_status = JD_POWER_POWER_STATUS_POWERING
ENDM

.serv_process EXPAND
	if (pwr_status == JD_POWER_POWER_STATUS_POWERING) {
		if (prev_pwr_status == JD_POWER_POWER_STATUS_POWERING) {
			// already in steady state
			if (!PA.PIN_LIMITER) {
				// fault!
				pwr_status = JD_POWER_POWER_STATUS_OVERLOAD
				.t16_set t16_262ms, t_re_enable, 4 // can re-enable after ~1000ms
				goto disable_limiter
			}
		} else {
			if (t_power_on_complete != 0) {
				.t16_chk t16_1ms, t_power_on_complete, <goto limiter_enabled>
				goto loop
			}

			// we're about to switch it on: yank it high
			PA.PIN_LIMITER = 1
			PAC.PIN_LIMITER = 1
			.delay 10*8 // wait 10us
			// switch it to input (with pull high)
			PAPH.PIN_LIMITER = 1 // pullup on limiter
			PAC.PIN_LIMITER = 0

			// assume it takes ~10ms for the limiter to ramp up
			.t16_set t16_1ms, t_power_on_complete, 10
			ifset ZF
				inc t_power_on_complete
			goto loop
		}
	} else {
	disable_limiter:
		PAPH.PIN_LIMITER = 0
		PA.PIN_LIMITER = 0
		PAC.PIN_LIMITER = 1
	}
limiter_enabled:
	clear t_power_on_complete
	mov a, pwr_status
	if (a != prev_pwr_status) {
		mov prev_pwr_status, a
		goto ev_send
	}
	.t16_chk t16_16ms, t_next_shutdown, <goto send_shutdown>
	.t16_chk t16_262ms, t_re_enable, <goto try_re_enable>

	.ev_process
	goto loop

send_shutdown:
	.callnoint rng_next
	and a, 0xf
	add a, 24
	.t16_set_a t16_16ms, t_next_shutdown
	mov a, pwr_status
	ifset ZF
		goto loop // state==disallowed

	if (a == JD_POWER_POWER_STATUS_OVERPROVISION) {
		dzsn switch_cnt
			goto loop
		goto try_re_enable
	}

	// state is powering or overload
	set1 txp_pwr_shutdown
	goto loop

try_re_enable:
	.t16_set t16_262ms, t_re_enable, 50 // do it again in distant future
	mov a, pwr_status
	ifset ZF	// if Disallowed, don't re-enable
		goto loop
	pwr_status = JD_POWER_POWER_STATUS_POWERING
	// shedule shutdown to be sent ASAP
	t_next_shutdown = t16_16ms
	goto loop
ENDM

.serv_prep_tx EXPAND
	ifset txp_event
		goto ev_prep_tx

	if (txp_pwr_status) {
		set0 txp_pwr_status
		inc pkt_size // ==1
		.mova pkt_payload[0], pwr_status
		pkt_service_command_l = JD_POWER_REG_RO_POWER_STATUS
		ret
	}

	if (txp_pwr_allowed) {
		set0 txp_pwr_allowed
		inc pkt_size // ==1
		// data[0] = (pwr_status != Disallowed)
		mov a, pwr_status
		ifclear ZF
			mov a, 1
		mov pkt_payload[0], a
		pkt_service_command_l = JD_POWER_REG_RW_ALLOWED
reg_rw:
		dec pkt_service_command_h // JD_HIGH_REG_RW_GET
		ret
	}

#ifdef MAX_POWER
	if (txp_pwr_max) {
		set0 txp_pwr_max
		pkt_size = 2
		pkt_payload[0] = MAX_POWER & 0xff
		pkt_payload[1] = MAX_POWER >> 8
		pkt_service_command_l = JD_REG_RW_MAX_POWER
		goto reg_rw
	}
#endif

	if (txp_pwr_shutdown) {
		set0 txp_pwr_shutdown

		crc_l = 0x15
		crc_h = 0x59

		// frm_sz = 4 - done elsewhere
		frm_flags = (1 << JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS) | (1 << JD_FRAME_FLAG_COMMAND)

		.forc x, <0123>
		mov a, (SERVICE_CLASS >> (x * 8)) & 0xff
		mov pkt_device_id[x], a
		.endm
		mov a, 0xAA
		.forc x, <0123>
		mov pkt_device_id[4+x], a
		.endm

		// pkt_size already set to 0
		pkt_service_number = JD_SERVICE_INDEX_BROADCAST
		pkt_service_command_l = JD_POWER_CMD_SHUTDOWN
		clear pkt_service_command_h

		ret
	}
ENDM

serv_rx:
	mov a, pkt_service_command_h
	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l
		if (a == JD_POWER_REG_RO_POWER_STATUS) {
			set1 txp_pwr_status
		}
		goto rx_process_end	
	}
	if (a == JD_HIGH_REG_RW_GET) {
		mov a, pkt_service_command_l
#ifdef MAX_POWER
		if (a == JD_REG_RW_MAX_POWER) {
			set1 txp_pwr_max
			goto rx_process_end
		}
#endif
		if (a == JD_POWER_REG_RW_ALLOWED) {
			set1 txp_pwr_allowed
		}
		goto rx_process_end	
	}
	if (a == JD_HIGH_REG_RW_SET) {
		mov a, pkt_service_command_l
		if (a == JD_POWER_REG_RW_ALLOWED) {
			mov a, pkt_payload[0]
			if (ZF) {
				clear pwr_status
			} else {
				// if pwr==disabled then pwr := powering
				mov a, pwr_status
				ifset ZF
					inc pwr_status
			}
		}
		goto rx_process_end	
	}
	if (a == JD_HIGH_CMD) {
		mov a, pkt_service_command_l
		if (a == JD_POWER_CMD_SHUTDOWN) {
			mov a, pwr_status
			sub a, 1
			ifset ZF
			    mov a, 1
			ifset txp_pwr_shutdown
				mov a, 0
			if (a == 1) {
				// (pwr_status == JD_POWER_POWER_STATUS_POWERING || pwr_status == JD_POWER_POWER_STATUS_OVERLOAD) && !txp_pwr_shutdown
				pwr_status = JD_POWER_POWER_STATUS_OVERPROVISION
				switch_cnt = 20 // how many "shutdown" cycles before we try to take over powering
			}
			.t16_set t16_262ms, t_re_enable, 5 // can re-enable after ~1300ms
		}
		goto rx_process_end
	}
	goto rx_process_end

.serv_ev_payload EXPAND
	inc pkt_size // == 1
	.mova pkt_service_command_l, JD_POWER_EV_POWER_STATUS_CHANGED
	.mova pkt_payload[0], pwr_status
ENDM

	.ev_impl
