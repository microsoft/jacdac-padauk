
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

ev_prep_tx:
	set0 tx_pending.txp_event
	.serv_ev_payload
	mov a, ev_cnt
	or a, 0x80
	mov pkt_service_command_h, a
	ret
