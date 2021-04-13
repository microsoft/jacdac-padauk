	.clear_memory
	.rng_init
	.t16_init
	.rx_init

pin_init:
	PAC.JD_LED 	= 	1 // output
	PAC.JD_TM 	= 	1 // output

	.mova streaming_interval, 20

	// TODO add random delay here, so that not all modules start at once?

	call t16_sync
	.serv_init

loop:
	.assert_not PAC.JD_D // we should be in input mode here
	.disint
	call t16_sync
	engint

	.blink_process

	// this sends first announce after 263ms, and each subsequent one every 526ms
	if (flags.f_announce_t16_bit) {
		ifclear t16_262ms.0
			set0 flags.f_announce_t16_bit
	} else {
		if (t16_262ms.0) {
			set1 flags.f_announce_t16_bit
			set1 tx_pending.txp_announce
		}
	}

	if (flags.f_reset_in) {
		.t16_chk t16_262ms, t_reset, reset
	}

	if (flags.f_set_tx) {
		set0 flags.f_set_tx
		.rng_next
		and a, 31
		add a, 12
		mov t_tx, a
		mov a, t16_4us
		add t_tx, a
	}

	mov a, tx_pending
	if (!ZF) {
		.t16_chk t16_4us, t_tx, <goto try_tx>
	}

	.serv_process

	goto loop

panic:
	nop
	goto panic

.setcmd MACRO x, y
	.mova pkt_service_command_h, x
	.mova pkt_service_command_l, y
ENDM

prep_tx:
	.mova pkt_service_number, 1
	.mova pkt_service_command_h, JD_HIGH_REG_RO_GET
	clear pkt_size
	clear pkt_payload[1]
	clear pkt_payload[2]
	clear pkt_payload[3]
	clear frm_flags

	if (tx_pending.txp_ack) {
		set0 tx_pending.txp_ack
		.mova pkt_service_number, 0x3f
		.setcmd ack_crc_h, ack_crc_l
		ret
	}

.ev_prep_tx EXPAND
	if (tx_pending.txp_event) {
		set0 tx_pending.txp_event

		.mova pkt_size, 4
		mov a, ev_code
		mov pkt_service_command_l, a
		if (a == JD_BUTTON_EV_DOWN) {
			clear pkt_size // down event doesn't have payload
		} else if (a == JD_BUTTON_EV_UP) {
			// we snapshot final duration when emitting up
			.mova pkt_payload[0], btn_down_l
			.mova pkt_payload[1], btn_down_h
		} else {
			// hold events have duration computed on the fly
			mov a, t16_1ms
			sub a, btn_down_l
			mov pkt_payload[0], a
			mov a, t16_262ms
			subc a, btn_down_h
			mov pkt_payload[1], a
		}

		mov a, ev_cnt
		or a, 0x80
		mov pkt_service_command_h, a
		ret
	}
ENDM


ev_flush:
	set1 tx_pending.txp_event
	if (flags.f_ev2) {
		set0 flags.f_ev1
		set0 flags.f_ev2
		goto loop
	}
	set1 flags.f_ev2
	.t16_set t16_1ms, t_ev, 100
	goto loop
	
ev_send:
	mov ev_code, a
	inc ev_cnt
	set1 tx_pending.txp_event
	set1 flags.f_ev1
	set0 flags.f_ev2
	.t16_set t16_1ms, t_ev, 20
	goto loop