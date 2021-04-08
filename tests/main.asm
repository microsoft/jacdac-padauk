JD_LED	equ	3
JD_D 	equ	6
JD_BTN 	equ	4

JD_TM 	equ	7 // logging
	
frame_header_size equ 12
crc_size equ 2
payload_size equ 8
buffer_size equ (frame_header_size + 4 + payload_size)

f_in_rx equ 0
f_set_tx equ 1
f_identify equ 2
f_reset_in equ 3
f_ev1 equ 4
f_ev2 equ 5

txp_announce equ 0
txp_ack equ 1
txp_streaming_samples equ 2
txp_streaming_interval equ 3
txp_reading equ 4
txp_event equ 5

pkt_addr equ 0x10

#define JD_FRAME_FLAG_COMMAND 1
#define JD_FRAME_FLAG_ACK_REQUESTED 2
#define JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS 3
#define JD_FRAME_FLAG_VNEXT 7

.include utils.asm
.include t16.asm
.include rng.asm

.CHIP   PMS150C
// Give package map to writer	pcount	VDD	PA0	PA3	PA4	PA5	PA6	PA7	GND	SHORTC_MSK1	SHORTC_MASK1	SHIFT
//.writer package 		6, 	1, 	0,	4, 	27, 	25,	26, 	0,	28, 	0x0007, 	0x0007, 	0
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable
	.Code_Option	Bootup_Time	Fast
	.Code_Option	Drive		Normal
	.Code_Option	LVR		3.0V
//}}PADAUK_CODE_OPTION

	// possible program variable memory allocations (PMC150C)
	//		   srt	end
	// 	BIT	    0	16
	//	WORD	0	30
	//	BYTE	0	64

	.ramadr 0x00
	WORD    memidx
	BYTE    flags
	BYTE    tx_pending
	BYTE	isr0, isr1, isr2
	BYTE    reset_cnt
	BYTE    rng_x

	BYTE    t_announce
	BYTE    t_tx

	BYTE	t16_16ms
	WORD    t16_low
	WORD    t16_high

	.ramadr pkt_addr
	BYTE	crc_l, crc_h
	BYTE	frm_sz
	BYTE    frm_flags

	BYTE    pkt_device_id[8]

	// actual tx packet
	BYTE	pkt_size
	BYTE	pkt_service_number
	BYTE	pkt_service_command_l
	BYTE	pkt_service_command_h
	BYTE	pkt_payload[payload_size]
	BYTE	rx_data // this is overwritten during rx if packet too long (but that's fine)

	BYTE    ack_crc_l, ack_crc_h
	BYTE	t_sample

	// so far:
	// application is not using stack when IRQ enabled
	// rx ISR can do up to 3
	WORD	main_st[3]

	BYTE    t_reset

	BYTE ev_code
	BYTE ev_cnt
	BYTE t_ev

	BYTE btn_down_l
	BYTE btn_down_h
	BYTE t_btn_hold

#define JD_BUTTON_EV_DOWN 0x01
#define JD_BUTTON_EV_UP 0x02
#define JD_BUTTON_EV_HOLD 0x81

.ev_check EXPAND
	if (flags.f_ev1) {
		.t16_chk t16_1ms, t_ev, <goto ev_flush>
	}
ENDM


	// more data defined in rxserv.asm

	goto	main

	.include rx.asm
	.include crc16.asm
	.include tx.asm

main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V
	SP	=	main_st

	.clear_memory
	.rng_init
	.t16_init
	.rx_init

pin_init:
	PAPH.JD_BTN =   1 // pullup on btn

	PAC.JD_LED 	= 	1 // output
	PAC.JD_TM 	= 	1 // output

	call t16_sync
	.t16_set t16_16ms, t_announce, 31
	goto do_sample

loop:
	disgint
	call t16_sync
	engint

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
		goto loop // if tx is full, no point trying announce etc
	}

	.t16_chk t16_1ms, t_sample, <goto do_sample>
	.ev_check

	.sensor_stream
	.t16_chk t16_16ms, t_announce, <goto do_announce>
	goto loop

do_announce:
	.t16_set t16_16ms, t_announce, 31
	set1 tx_pending.txp_announce
	goto loop

.setcmd MACRO x, y
.ifidni x, JD_HIGH_REG_RO_GET
.ifz x
	clear pkt_service_command_h
.else
	.mova pkt_service_command_h, x
.endif
.endif
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

	if (tx_pending.txp_streaming_samples) {
		set0 tx_pending.txp_streaming_samples
		.setcmd JD_HIGH_REG_RW_GET, JD_REG_RW_STREAMING_SAMPLES
		.mova pkt_payload[0], streaming_samples
		.mova pkt_size, 1
		ret
	}

	if (tx_pending.txp_streaming_interval) {
		set0 tx_pending.txp_streaming_interval
		.setcmd JD_HIGH_REG_RW_GET, JD_REG_RW_STREAMING_INTERVAL
		.mova pkt_payload[0], streaming_interval
		.mova pkt_size, 4
		ret
	}

	if (tx_pending.txp_reading) {
		set0 tx_pending.txp_reading
		_cnt => 0
	.repeat SENSOR_SIZE
		.mova pkt_payload[_cnt], sensor_state[_cnt]
		_cnt => _cnt + 1
	.endm
		.mova pkt_size, SENSOR_SIZE
		.setcmd JD_HIGH_REG_RO_GET, JD_REG_RO_READING
		ret
	}

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

	// ~20 cycles until here + ~30 here
	if (tx_pending.txp_announce) {
		set0 tx_pending.txp_announce
		// reset_cnt maxes out at 0xf	
		mov a, 0xf
		inc reset_cnt
		ifset reset_cnt.4
			mov reset_cnt, a
		.mova pkt_payload[0], reset_cnt
		.mova pkt_payload[1], 0x01 // ACK-supported
		// [2] and [3] already cleared
		.mova pkt_payload[4], 0x63
		.mova pkt_payload[5], 0xa2
		.mova pkt_payload[6], 0x73
		.mova pkt_payload[7], 0x14
		.mova pkt_size, 8
		clear pkt_service_number
		clear pkt_service_command_l
		clear pkt_service_command_h
		ret
	}
	ret

// Module implementations
	.t16_impl

do_sample:
	.t16_set t16_1ms, t_sample, 20
	mov a, sensor_state[0]
	ifclear PA.JD_BTN
		goto button_active
button_inactive:
	ifset ZF // state==0
		goto loop // just keep going
	clear sensor_state[0]
		// snapshot duration
		mov a, t16_1ms
		sub a, btn_down_l
		mov btn_down_l, a
		mov a, t16_262ms
		subc a, btn_down_h
		mov btn_down_h, a

	mov a, JD_BUTTON_EV_UP
	goto ev_send
button_active:
	ifset ZF
		goto button_down
	.t16_chk t16_16ms, t_btn_hold, <goto button_hold>
	goto loop
button_hold:
	.t16_set t16_16ms, t_btn_hold, 31
	mov a, JD_BUTTON_EV_HOLD
	goto ev_send
button_down:
	.mova sensor_state[0], 1
	disgint
		.mova btn_down_l, t16_1ms
		.mova btn_down_h, t16_262ms
	engint
	.t16_set t16_16ms, t_btn_hold, 31
	mov a, JD_BUTTON_EV_DOWN
	goto ev_send

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