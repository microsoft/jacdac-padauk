
	BYTE ev_code
	BYTE ev_cnt
	BYTE t_ev

.ev_process EXPAND
	if (flags.f_ev1) {
		.t16_chk t16_1ms, t_ev, <goto ev_flush>
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
