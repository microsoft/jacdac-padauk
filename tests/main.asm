/*

Brilliant ideas:
- after initial lo-pulse, during loop waiting for first bit of first character, set up timer and hope for nested interrupt on timeout
- 'addpc mode' statement at the beginning of irq
- keep uart reception running over the max size of packet
- uart: swapc pa.JD; src uartch - not available on PMS150 or whatever

 */

JD_LED	equ	6
JD_TM 	equ	4
JD_D 	equ	7

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
	BYTE	uart_data, tmp0, tmp1

	.ramadr	0x10
	WORD	main_st[5]
	WORD	button_counter

	.ramadr	0x20
	byte 	packet_buffer[32]

	goto	main


	.romadr	0x10            // interrupt vector
interrupt:
	INTRQ.TM2 = 0
	t0sn PA.JD_D
	reti
	
	pushaf

	PA.JD_TM = 1
	PA.JD_TM = 0

	// wait for end of lo pulse
@@:
	t1sn PA.JD_D
	goto @b

	// wait for serial transmission to start
@@:
.repeat 40
	t1sn PA.JD_D
	goto uart_rx_lo
.endm
	goto @b


.get_bit MACRO n	
	nop
	PA.JD_LED = 1
	nop
	t0sn PA.JD_D
	set1 uart_data.n
	PA.JD_LED = 0
	nop
	nop
ENDM

uart_rx:
	PA.JD_TM = 1
.repeat 80 // 80 repetitions = 20us - max wait time
	t1sn PA.JD_D
	goto uart_rx_lo
.endm
	popaf
	reti

uart_rx_lo:
	// potentially, can add one more cycle here - measure it?
	PA.JD_TM = 0
	nop
	nop

	.forc n, <01234567>
	.get_bit n
	.endm

	nop
	nop
	nop
	nop
	nop
	goto uart_rx
	ret


main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.85V
	SP	=	main_st

	.clear_memory
	call rng_init
	.t16_init

t2_init:
	$ TM2S 8BIT, /1, /2
	TM2B = 75 ; irq every 75 instructions, ~9.5us
	$ TM2C IHRC
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
	.t16_set t16_1ms, freq1, 10
 	ret

// Module implementations
	.t16_impl

.include crc16.asm
.include devid.asm
.include rng.asm

