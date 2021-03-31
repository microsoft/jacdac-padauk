/*
Brilliant ideas:
- 'addpc mode' statement at the beginning of irq
 */

JD_LED	equ	6
JD_TM 	equ	4
JD_D 	equ	7
f_in_rx equ 0
buffer_size equ 24

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
	BYTE	uart_data, tmp0, tmp1

	.ramadr	0x10
	WORD	main_st[5]
	WORD	button_counter

	.ramadr	0x20
	byte 	packet_buffer[buffer_size+1] // needs one more byte for "the rest of the packet"

	goto	main


	.romadr	0x10            // interrupt vector
interrupt:
	INTRQ.TM2 = 0
	t0sn flags.f_in_rx
	goto timeout
	t0sn PA.JD_D
	reti
		
	pushaf

	set1 flags.f_in_rx
	$ TM2S 8BIT, /1, /14 // ~140us
	.mova TM2CT, 0
	engint
	
	// wait for end of lo pulse
@@:
	t1sn PA.JD_D
	goto @b

	a = packet_buffer
	mov lb@memidx, a
	.mova tmp0, buffer_size+1
	clear uart_data

	// wait for serial transmission to start
@@:
.repeat 20
	t1sn PA.JD_D
	goto uart_rx_lo_first
.endm
	goto @b

timeout:
	// this is nested IRQ; we want to return to original code, not outer interrupt
	// TODO: try fake popaf
	mov a, SP
	sub a, 2
	mov SP, a
leave_irq:
	set0 flags.f_in_rx
	.mova TM2CT, 0
	$ TM2S 8BIT, /1, /1
	
	PA.JD_TM = 1
	PA.JD_TM = 0
	PA.JD_TM = 1
	PA.JD_TM = 0

	popaf
	reti


uart_rx_lo_first:
	$ TM2S 8BIT, /1, /2	 // 2T
	nop
	nop
	goto uart_rx_lo_skip // 2T

uart_rx:
.repeat 10
	t1sn PA.JD_D
	goto uart_rx_lo
.endm
	goto uart_rx

uart_rx_lo:
	xch uart_data    // a==0 here, so this clears uart_data for next round
	idxm memidx, a   // 2T
	dzsn tmp0        // tmp0--
	inc lb@memidx    // when tmp0 reaches 0, we stop incrementing memidx
	t0sn ZF          // if tmp0==0
	inc tmp0         //     tmp0++ -> keep tmp0 at 0

uart_rx_lo_skip:
	t0sn PA.JD_D
	set1 uart_data.0
	nop
	nop
	nop

	nop
	nop
	nop
	t0sn PA.JD_D
	set1 uart_data.1
	nop
	nop
	nop

	nop
	nop
	nop
	t0sn PA.JD_D
	set1 uart_data.2
	nop
	nop
	nop

	nop
	nop
	nop
	t0sn PA.JD_D
	set1 uart_data.3
	nop
	nop
	nop

	nop
	nop
	nop
	t0sn PA.JD_D
	set1 uart_data.4
	nop
	nop
	nop

	nop
	nop
	nop
	t0sn PA.JD_D
	set1 uart_data.5
	nop
	nop
	nop

	nop
	nop
	nop
	t0sn PA.JD_D
	set1 uart_data.6
	nop
	nop
	nop

	nop
	PA.JD_LED = 1 // bit marking
	nop
	t0sn PA.JD_D
	set1 uart_data.7
	PA.JD_LED = 0 // bit marking
	nop
	nop

	nop
	nop
	nop

	nop
	mov a, 0
	mov TM2CT, a
	goto uart_rx

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
	PA.JD_TM = 1
	PA.JD_TM = 0
	.t16_set t16_1ms, freq1, 10
 	ret

// Module implementations
	.t16_impl

.include crc16.asm
.include devid.asm
.include rng.asm

