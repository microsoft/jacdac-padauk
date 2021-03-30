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

.ldbytes MACRO dst, bytes
	_cnt => 0
	.for b, <bytes>
		mov a, b
		mov dst[_cnt], a
		_cnt => _cnt + 1
	.endm
ENDM

.mova MACRO dst, val
	mov a, val
	mov dst, a
ENDM


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

	INTRQ.TM2 = 0
	PA.JD_TM = 1
	PA.JD_TM = 0

	//popaf
	reti


main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.85V
	SP	=	main_st

clear_memory:
	.mova lb@memidx, _SYS(SIZE.RAM)-1
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

	.t16_init

pin_init:
	PAC.JD_LED 	= 	1 ; output
	PAC.JD_TM 	= 	1 ; output

	clear 	uart_data
	clear   lb@indirect_addr
	clear   hb@indirect_addr

			engint

	call fill_id
	nop
	nop
	clear packet_buffer[4+3]
	nop
	call check_id
	nop
	nop
	.ldbytes packet_buffer, <0xde, 0xad, 0xf0, 0x0d>

xloop:
	disgint
	a = packet_buffer
	mov lb@memidx, a
	mov a, 4
	PA.JD_LED = 1
	call crc16
	PA.JD_LED = 0

	a = packet_buffer
	mov lb@memidx, a
	mov a, 20
	PA.JD_LED = 1
	call crc16
	PA.JD_LED = 0
	goto xloop




	BYTE freq1

loop:
	call t16_sync
	.t16_chk t16_1ms, freq1, freq1_hit
	goto loop

freq1_hit:
	.t16_set t16_1ms, freq1, 10
	PA.JD_LED = 1
	PA.JD_LED = 0
 	ret

/*
uint16_t jd_crc16(const void *data, uint32_t size) {
    const uint8_t *ptr = (const uint8_t *)data;
    uint16_t crc = 0xffff;
    while (size--) {
        uint8_t data = *ptr++;
        uint8_t x = (crc >> 8) ^ data;
        x ^= x >> 4;
        crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x;
    }
    return crc;
}
 */

// ~27 cycles per byte
crc16:
	BYTE crc_l
	BYTE crc_h
	mov tmp0, a // length
	mov a, 0xff
	mov crc_l, a
	mov crc_h, a
crc16_loop:
	idxm a, memidx
	inc lb@memidx
	xor a, crc_h
	mov tmp1, a
	swap a
	and a, 0x0f
	xor tmp1, a // tmp1==x
	mov a, tmp1
	swap a
	and a, 0xf0
	xor a, crc_l
	mov crc_h, a
	mov a, tmp1
	sr a
	sr a
	sr a
	xor crc_h, a // crc_h done
	.mova crc_l, tmp1
	swap a
	and a, 0xf0
	sl a
	xor crc_l, a // crc_l done
	dzsn tmp0
	goto crc16_loop
	ret

// Module implementations
	.t16_impl

IDSIZE equ 8

fill_id:
	a = packet_buffer+4+IDSIZE-1
	mov lb@memidx, a
	.mova tmp0, IDSIZE
@@:
	mov a, tmp0
	call get_id
	idxm memidx, a
	dec lb@memidx
	dzsn tmp0
	goto @B
	ret

check_id:
	a = packet_buffer+4+IDSIZE-1
	mov lb@memidx, a
	.mova tmp0, IDSIZE
@@:
	mov a, tmp0
	call get_id
	mov tmp1, a
	idxm a, memidx
	ceqsn a, tmp1
	ret 0
	dec lb@memidx
	dzsn tmp0
	goto @B
	ret 1

// requires a=1...8
get_id:
	pcadd a
.IFDEF RELEASE
	.User_Roll 8 BYTE, "genid.bat", "ids.txt"
.ELSE
	ret 0x01
	ret 0x23
	ret 0x45
	ret 0x67
	ret 0x89
	ret 0xab
	ret 0xcd
	ret 0xef
.ENDIF
