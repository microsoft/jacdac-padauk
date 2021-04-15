	.clear_memory
	.rng_init
	.t16_init
	.rx_init

pin_init:
	PAC.PIN_LED 	= 	1 // output
#ifdef PIN_LOG
	PAC.PIN_LOG 	= 	1 // output
#endif

	// TODO add random delay here, so that not all modules start at once?

	call t16_sync
	.serv_init

loop:
	.assert_not PAC.PIN_JACDAC // we should be in input mode here
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

#ifdef CFG_RESET_IN
	if (flags.f_reset_in) {
		.t16_chk t16_262ms, t_reset, reset
	}
#endif

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

	.serv_prep_tx

	// ~20 cycles until here + ~30 here
	if (tx_pending.txp_announce) {
		set0 tx_pending.txp_announce
		// reset_cnt maxes out at 0xf	
		mov a, t16_262ms
		sr a
		add a, 1
		and a, 0xf
		ifset ZF
			set1 flags.f_announce_rst_cnt_max
		ifset flags.f_announce_rst_cnt_max
			mov a, 0xf
		mov pkt_payload[0], a
#ifdef CFG_BROADCAST
		.mova pkt_payload[1], JD_AD0_ACK_SUPPORTED|JD_AD0_IDENTIFIER_IS_SERVICE_CLASS_SUPPORTED
#else
		.mova pkt_payload[1], JD_AD0_ACK_SUPPORTED
#endif
		// [2] and [3] already cleared
		.forc x, <0123>
		mov a, (SERVICE_CLASS >> (x * 8)) & 0xff
		mov pkt_payload[x+4], a
		.endm
		.mova pkt_size, 8
		clear pkt_service_number
		clear pkt_service_command_l
		clear pkt_service_command_h
		ret
	}

	ret

#ifdef CFG_BROADCAST
check_service_class:
	.forc x, <0123>
	mov a, pkt_device_id[x]
	ifneq a, (SERVICE_CLASS >> (x * 8)) & 0xff
		goto not_interested
	.endm
	goto check_size
#endif

	.t16_impl
	.blink_impl
