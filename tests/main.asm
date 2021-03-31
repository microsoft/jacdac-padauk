/*
Brilliant ideas:
- 'addpc mode' statement at the beginning of irq
 */

JD_LED	equ	6
JD_TM 	equ	4
JD_D 	equ	7
f_in_rx equ 0
f_in_crc equ 1
buffer_size equ 32
frame_header_size equ 12
crc_size equ 2

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
	BYTE	uart_data, tmp0, tmp1, tmp2
	BYTE	crc_l, crc_h, crc_d, crc_l0, crc_h0

	// .ramadr	0x10
	WORD	main_st[5]
	WORD	button_counter

	.ramadr	0x20
	byte 	packet_buffer[buffer_size+1] // needs one more byte for "the rest of the packet"

	goto	main

	.include rx.asm
	.include crc16.asm
	.include rng.asm

main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.85V
	SP	=	main_st

	.clear_memory
	call rng_init
	.t16_init

t2_init:
	$ TM2S 8BIT, /1, /1
	TM2B = 75 ; irq every 75 instructions, ~9.5us
	$ TM2C SYSCLK
	INTRQ = 0x00
	$ INTEN = TM2

pin_init:
	PAC.JD_LED 	= 	1 ; output
	PAC.JD_TM 	= 	1 ; output

	engint

	BYTE freq1

loop:
	call t16_sync
	.t16_chk t16_1ms, freq1, freq1_hit
	goto loop

freq1_hit:
	//PA.JD_TM = 1
	//PA.JD_TM = 0
	.t16_set t16_1ms, freq1, 10
 	ret

// Module implementations
	.t16_impl

