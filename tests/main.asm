/*

Brilliant ideas:
- after initial lo-pulse, during loop waiting for first bit of first character, set up timer and hope for nested interrupt on timeout
- 'addpc mode' statement at the beginning of irq
- keep uart reception running over the max size of packet
- uart: swapc pa.JD; src uartch - not available on PMS150 or whatever

 */

JD_LED	equ	6
JD_TM 	equ	4

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
	BYTE	uart_data, tmp0, tmp1
	WORD	indirect_addr

	.ramadr	0x10
	WORD	main_st[5]

	WORD	button_counter

	.ramadr	0x20
	byte 	packet_buffer[32]

	goto	main


	.romadr	0x10            // interrupt vector
interrupt:
	//pushaf

	INTRQ.TM3 = 0
	PA.JD_TM = 1
	PA.JD_TM = 0

	//popaf
	reti


main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.85V
	SP	=	main_st

clear_memory:
	mov a, _SYS(SIZE.RAM)-1
	mov lb@memidx, a
	clear hb@memidx
	mov a, 0x00
clear_loop:
	idxm memidx, a
	dzsn lb@memidx
	goto clear_loop

t2_init:
	$ TM2S 8BIT, /1, /2
	TM2B = 75 ; irq every 75 instructions, ~9.5us
	$ TM2C IHRC
	INTRQ = 0x00
	$ INTEN = TM2

	t16_init

pin_init:
	PAC.JD_LED 	= 	1 ; output
	PAC.JD_TM 	= 	1 ; output

	clear 	uart_data
	clear   lb@indirect_addr
	clear   hb@indirect_addr
	engint


	BYTE freq1

loop:
	call t16_sync
	t16_chk t16_v1, freq1, freq1_hit
	goto loop

freq1_hit:
	t16_set t16_v1, freq1, 10
	PA.JD_LED = 1
	PA.JD_LED = 0
 	ret

	t16_impl
