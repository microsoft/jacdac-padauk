#define SERVICE_CLASS 0x1fa4c95a

#define JD_POWER_POWER_STATUS_DISALLOWED 0x0
#define JD_POWER_POWER_STATUS_POWERING 0x1
#define JD_POWER_POWER_STATUS_OVERLOAD 0x2
#define JD_POWER_POWER_STATUS_OVERPROVISION 0x3
#define JD_POWER_POWER_STATUS_STARTUP 0x4

#define JD_POWER_REG_RW_ALLOWED JD_REG_RW_INTENSITY
#define JD_POWER_REG_RO_POWER_STATUS 0x81
#define JD_POWER_CMD_SHUTDOWN 0x80
#define JD_POWER_EV_POWER_STATUS_CHANGED JD_EV_CHANGE

	BYTE	t_next_shutdown
	BYTE	t_re_enable
	BYTE    pwr_status
	BYTE    prev_pwr_status

txp_pwr_shutdown equ txp_serv0
txp_pwr_allowed equ txp_serv1
txp_pwr_status equ txp_serv2

#define SERV_BLINK .serv_blink

.serv_blink EXPAND
	if (pwr_status == JD_POWER_POWER_STATUS_POWERING) {
		mov a, t16_16ms
		and a, 0xf
		ifset ZF
			.led_on // 1/16 duty LED on
	}
ENDM

.serv_init EXPAND
	PAC.PIN_SWITCH = 1
	PA.PIN_SWITCH = 1
	PAPH.PIN_LIMITER =   1 // pullup on limiter
	call rng_next
	and a, 0xf // 0-240ms
	mov t_next_shutdown, a
	.mova pwr_status, JD_POWER_POWER_STATUS_STARTUP
ENDM

.serv_process EXPAND
	if (pwr_status == JD_POWER_POWER_STATUS_POWERING) {
		if (prev_pwr_status == JD_POWER_POWER_STATUS_POWERING) {
			// already in steady state
			if (!PA.PIN_LIMITER) {
				// fault!
				.mova pwr_status JD_POWER_POWER_STATUS_OVERLOAD
				.t16_set t16_262ms, t_re_enable, 4 // can re-enable after ~1000ms
				goto disable_limiter
			}
		} else {
			// we're about to switch it on: yank it high
			PA.PIN_LIMITER = 1
			PAC.PIN_LIMITER = 1
			.delay 10*8 // wait 10us
			// switch it to input (with pull high)
			PAC.PIN_LIMITER = 0
		}
	} else {
	disable_limiter:
		PA.PIN_LIMITER = 0
		PAC.PIN_LIMITER = 1
	}
	if (a != prev_pwr_status) {
		mov prev_pwr_status, a
		if (a == JD_POWER_POWER_STATUS_POWERING) {
			// if we switched to Powering, shedule shutdown to be sent ASAP
			.mova t_next_shutdown, t16_16ms
		}
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
	if (a == JD_POWER_POWER_STATUS_STARTUP) {
		goto try_re_enable
	} else if (a == JD_POWER_POWER_STATUS_POWERING) {
		set1 txp_pwr_shutdown
	}
	goto loop

try_re_enable:
	.t16_set t16_262ms, t_re_enable, 50 // do it again in distant future
	mov a, pwr_status
	ifset ZF	// if Disallowed, don't re-enable
		goto loop
	.mova pwr_status, JD_POWER_POWER_STATUS_POWERING
	goto loop
ENDM

.serv_prep_tx EXPAND
	ifset txp_event
		goto ev_prep_tx

	if (txp_pwr_status) {
		set0 txp_pwr_status
		inc pkt_size // ==1
		.mova pkt_payload[0], pwr_status
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
		ret
	}

	if (txp_pwr_shutdown) {
		set0 txp_pwr_shutdown

		crc_l = 0x15
		crc_h = 0x59

		frm_sz = 4
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
			if (!ZF) { // don't change status if Disallowed
				mov a, JD_POWER_POWER_STATUS_OVERPROVISION
				// if not in grace period, disable limiter
				ifclear txp_pwr_shutdown
					mov pwr_status, a
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
