jd_main:
	SP = main_st
	.clear_memory
	.rng_init
	.t16_init
	.rx_init

pin_init:
	PAC.PIN_LED 	= 	1 // output
	set1 blink_disconnected // blink at start

#ifdef PIN_LOG
	PAC.PIN_LOG 	= 	1 // output
#endif

	// TODO add random delay here, so that not all modules start at once?

	call t16_sync
	.serv_init

loop:
	.assert_not PAC.PIN_JACDAC // we should be in input mode here

	.callnoint t16_sync

	.blink_process

	// this sends first announce after 263ms, and each subsequent one every 526ms
	.on_rising f_announce_t16_bit, t16_262ms.0, <set1 txp_announce>

#ifdef CFG_RESET_IN
	.t16_chk_nz t16_262ms, t_reset, reset
#endif

	if (f_set_tx) {
		set0 f_set_tx
		.rng_next
		and a, 31
		add a, 12
		mov t_tx, a
		mov a, t16_4us
		add t_tx, a
	}

	mov a, blink
	and a, 0xf0
	or a, tx_pending
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

.set_ro_reg MACRO y
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

	if (txp_ack) {
		set0 txp_ack
		.mova pkt_service_number, 0x3f
		.setcmd ack_crc_h, ack_crc_l
		ret
	}

	.serv_prep_tx

#ifdef CFG_FW_ID
	if (txp_fw_id) {
		set0 txp_fw_id
		.forc x, <0123>
		mov a, (CFG_FW_ID >> (x * 8)) & 0xff
		mov pkt_payload[x], a
		.endm
		.mova pkt_size, 4
		clear pkt_service_number
		.mova pkt_service_command_l, JD_CONTROL_REG_RO_FIRMWARE_IDENTIFIER
		ret
	}
#endif

	if (txp_announce) {
		set0 txp_announce
		// reset_cnt maxes out at 0xf	
		mov a, t16_262ms
		sr a
		add a, 1
		and a, 0xf
		ifset ZF
			set1 f_announce_rst_cnt_max
		ifset f_announce_rst_cnt_max
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

		// blink processing: every ~4s clear blink_status_on
		// t16_262ms should have lowest bit set (txp_announce is set on rising edge of lowest bit)
		// we thus only clear when the last four bits of t16_262ms is 0001, which should be every 16*262ms = ~4s
		mov a, t16_262ms
		and a, 0x0e
		ifset ZF
			set0 blink_status_on

		ret
	}

	ret

#ifdef CFG_BROADCAST
check_service_class:
	mov a, pkt_device_id[3]
	ifset ZF
		goto check_ctrl
	ifneq a, (SERVICE_CLASS >> (3 * 8)) & 0xff
		goto not_interested
	.forc x, <210>
	mov a, pkt_device_id[x]
	ifneq a, (SERVICE_CLASS >> (x * 8)) & 0xff
		goto not_interested
	.endm
	goto check_size

check_ctrl:
	or a, pkt_device_id[2]
	or a, pkt_device_id[1]
	or a, pkt_device_id[0]
	ifclear ZF
		goto not_interested
	goto check_size
#endif

//
// Module impl. if needed
//

	.t16_impl