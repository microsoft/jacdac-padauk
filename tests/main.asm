JD_LED	equ	6
JD_TM 	equ	4
JD_D 	equ	7

buffer_size equ 20
frame_header_size equ 12
crc_size equ 2

f_in_rx equ 0
f_has_tx equ 1
f_set_tx equ 2
f_want_ack equ 3

tx_addr equ 0x10

#define JD_FRAME_FLAG_COMMAND 1
#define JD_FRAME_FLAG_ACK_REQUESTED 2
#define JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS 3
#define JD_FRAME_FLAG_VNEXT 7

.include utils.asm
.include t16.asm

.CHIP   PFS154
; Give package map to writer	pcount	VDD	PA0	PA3	PA4	PA5	PA6	PA7	GND	SHORTC_MSK1	SHORTC_MASK1	SHIFT
;.writer package 		6, 	1, 	0,	4, 	27, 	25,	26, 	0,	28, 	0x0007, 	0x0007, 	0
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable		// Security 7/8 words Enable
	.Code_Option	Bootup_Time	Fast
	.Code_Option	Drive		Normal
	.Code_Option	Comparator_Edge	All_Edge
	.Code_Option	LCD2		Disable		// At ICE, LCD always disable, PB0 PA0/3/4 are independent pins
	.Code_Option	LVR		3.5V
//}}PADAUK_CODE_OPTION

	; possible program variable memory allocations:
	;		srt	end
	; 	BIT	0	16
	;	WORD	0	30
	;	BYTE	0	64

	.ramadr 0x00
	WORD    memidx
	BYTE    flags
	BYTE	isr0
	BYTE    reset_cnt

	BYTE    ack_crc_l, ack_crc_h

	.ramadr tx_addr
	BYTE	crc_l, crc_h
	BYTE	frm_sz  // == crc_l0
	BYTE    frm_flags // == crc_h0

	// 8 bytes here; will be masked with get_id
	BYTE	tmp0, tmp1
	BYTE	crc_d, rx_data
	BYTE	isr1, isr2
	BYTE    t_announce, t_tx

	// actual tx packet
	BYTE	tx_size
	BYTE	tx_service_number
	BYTE	tx_service_command_l
	BYTE	tx_service_command_h
	BYTE	tx_payload[8]

	BYTE 	packet_buffer[buffer_size+1] // needs one more byte for "the rest of the packet"

	// so far:
	// application code can use 1 word of stack
	// rx ISR can do up to 3
	// total: 4
	WORD	main_st[4]

	goto	main

	.include rx.asm
	.include crc16.asm
	.include rng.asm
	.include tx.asm

main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.85V
	SP	=	main_st

	.clear_memory
	.rng_init
	.t16_init
	.rx_init

pin_init:
	PAC.JD_LED 	= 	1 ; output
	PAC.JD_TM 	= 	1 ; output

	call t16_sync
	.t16_set t16_262ms, t_announce, 2

	engint

loop:
	call t16_sync

	t1sn flags.f_set_tx
	goto skip_schedule_tx
	set0 flags.f_set_tx
	call rng_next // uses tmp0
	and a, 31
	add a, 12
	mov t_tx, a
	mov a, t16_4us
	add t_tx, a

skip_schedule_tx:
	t1sn flags.f_has_tx
	goto no_tx
	.t16_chk t16_4us, t_tx, try_tx
	goto loop // if tx is full, no point trying announce etc

no_tx:
	t1sn flags.f_want_ack
	goto no_ack_req
	set0 flags.f_want_ack
	set1 flags.f_has_tx
	clear tx_size
	.mova tx_service_number, 0x3f
	.mova tx_service_command_l, ack_crc_l
	.mova tx_service_command_h, ack_crc_h
	goto loop

no_ack_req:
	.t16_chk t16_262ms, t_announce, do_announce
	goto loop

do_announce:
	.t16_set t16_262ms, t_announce, 2
	set1 flags.f_has_tx
	// reset_cnt maxes out at 0xf	
	mov a, 0xf
	inc reset_cnt
	t0sn reset_cnt.4
	mov reset_cnt, a
	.mova tx_payload[0], reset_cnt
	.mova tx_payload[1], 0x01 // ACK-supported
	clear tx_payload[2] // here we could insert packet_cnt, but we don't track that yet
	clear tx_payload[3]
	.mova tx_payload[4], 0x63
	.mova tx_payload[5], 0xa2
	.mova tx_payload[6], 0x73
	.mova tx_payload[7], 0x14
	.mova tx_size, 8
	clear tx_service_number
	clear tx_service_command_l
	clear tx_service_command_h
	goto loop

// Module implementations
	.t16_impl

