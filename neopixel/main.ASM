
; require hardware app timer?
#define APP_TIMER	1
#define	JACDAC_NEOPIXEL

#define UDID0 		0x11
#define UDID1 		0x22
#define UDID2 		0x33
#define UDID3 		0x44
#define UDID4 		0x55
#define UDID5 		0x66
#define UDID6 		0x77
#define UDID7 		0x88


#define JD_HEADER_SIZE			12
#define RGBLED_SERVICE_NUMBER0 		0xfc
#define RGBLED_SERVICE_NUMBER1 		0xb0
#define RGBLED_SERVICE_NUMBER2 		0xae
#define RGBLED_SERVICE_NUMBER3 		0x17
#define RGBLED_SET_COLOR_CMD		0x80

#define SERVICE_NUMBER_CONTROL		0
#define SERVICE_NUMBER_LIGHT		1

#define	NEOPIXEL_DEFAULT_BRIGHTNESS	0xff

#define CTRL_FRAME_CRCL			0x41
#define CTRL_FRAME_CRCH			0x9b
#define CTRL_FRAME_SIZE			12
#define CTRL_FRAME_FLAGS		0x00
#define CTRL_SERVICE_NUMBER		0x00
#define CTRL_SERVICE_COMMANDL		0x00
#define CTRL_SERVICE_COMMANDH		0x00

#define CTRL_SERVICE_SIZE		8
#define CTRL_COMMAND_IDENTIFY		0x81
#define CTRL_COMMAND_RESET		0x82

#define JD_LINE		3
#define NEOPIXEL	4
#define JD_LED		6
#define	JD_LED_MSK	0x40

; each idle detect loop takes 10 ins. (1.25 us). Idle period is 100 microseconds.
#define IDLE_COUNTER	80

#define	JD_MAX_PACKET_SIZE	0x20
#define JD_MAX_PACKET_SIZE_TB	6

; prog state register defines
#define TIM_TOP		0
#define CTRL_PACKET	1
#define BLINK_LED	2
#define CTRL_BLINK_LED	3	; used to indicate if brain has issued identify command

.CHIP   PMS150C
; Give package map to writer	pcount	VDD	PA0	PA3	PA4	PA5	PA6	PA7	GND	SHORTC_MSK1	SHORTC_MASK1	SHIFT
; .writer package 		6, 	5, 	0,	6, 	1, 	4,	3, 	0,	2, 	0x0007, 	0x0007, 	0
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable		// Security 7/8 words Enable
	.Code_Option	LVR		3.0V
	.Code_Option	Bootup_Time	Fast
	.Code_Option	Drive		Normal
//}}PADAUK_CODE_OPTION

	; possible program variable memory allocations:
	;		srt	end
	; 	BIT	0	16
	;	WORD	0	30
	;	BYTE	0	64

	.ramadr 0x00
	BYTE	uart_data
	BYTE 	prog_state
	WORD	indirect_addr
	BYTE	gp_counter
#ifdef	NEOPIXEL
	BYTE	green
	BYTE 	red
	BYTE	blue
#endif
	WORD	crc
	BYTE	interrupt_counter
	BYTE	period_counter		; sl'd each time interrupt_counter is reached
	BYTE	app_counter

	.ramadr	0x10
	
	WORD	main_st [0x03];
	WORD	timer_reset
#ifdef	NEOPIXEL
	BYTE	mul_y1, mul_x1;
	WORD	mul_t2;
#endif
	; words can be used up until 0x1e
	.ramadr	0x20
	byte 	packet_buffer[JD_MAX_PACKET_SIZE]

	goto	main


	.romadr	0x10            // interrupt vector
interrupt:
	stt16	timer_reset
	set0	intrq.T16
	inc 	interrupt_counter

	t1sn	interrupt_counter.6
	reti	
	
	clear	interrupt_counter
	sl 	period_counter
	

	t0sn	period_counter.1
	set1	prog_state.BLINK_LED

	t1sn	period_counter.2
	reti

	clear 	period_counter
	set1	period_counter.0
	set1	prog_state.CTRL_PACKET
	set1	prog_state.BLINK_LED
	reti

uart_tx_byte:
	mov	a, 0x80

uart_tx_start:
	set0	PA.JD_LINE
	nop
	nop
	goto	uart_test_byte

uart_tx_1:
	set1	PA.JD_LINE
	sr	a
	t0sn	FLAG.1
	goto	uart_tx_stop

uart_eval_byte:
	sr	uart_data
uart_test_byte:
	t0sn	uart_data.0	; test if bit 0 is 0, skip if it is (1/2)
	goto	uart_tx_1
	
uart_tx_0:
	sr	a
	set0	PA.JD_LINE
	t1sn	FLAG.1		; carry?
	goto	uart_eval_byte
	nop
	nop

uart_tx_stop:
	nop
	nop
	nop
	set1	PA.JD_LINE
	nop
	nop
	nop
	nop
	ret

jd_send_start_pulse:
	t1sn	PA.JD_LINE
	ret	0x1
	PAPH.JD_LINE	=	1	; disable PA3 pull up
	PAC.JD_LINE	=	1	; PA3 output
	set0	PA.JD_LINE
	call 	delay_10_us
	set1	PA.JD_LINE
	ret	0x0

jd_send:
	mov	a, 0x20
	mov	lb@indirect_addr, a
	clear	hb@indirect_addr

	add 	a, JD_HEADER_SIZE
	add	a, packet_buffer[2]
	mov	gp_counter, a

jd_send_frame_l:
	idxm	a, indirect_addr
	mov	uart_data, a
	call	uart_tx_byte

	inc 	lb@indirect_addr
	mov	a, lb@indirect_addr
	ceqsn	a, gp_counter
	goto	jd_send_frame_l

jd_send_end_pulse_end:
	call 	delay_10_us

	set0	pa.JD_LINE

	call 	delay_10_us

	set1	pa.JD_LINE

	PAPH.JD_LINE	=	1	; enable PA3 pull up
	PAC.JD_LINE 	=	0	; set PAC as input.
	ret

send_control_packet:
	disgint
	call	jd_send_start_pulse
	ceqsn	a, 0x0
	goto	jd_receive

	mov	a, CTRL_FRAME_SIZE
	mov	packet_buffer[2], a

	mov	a, CTRL_FRAME_FLAGS
	mov	packet_buffer[3], a

	mov 	a, UDID0
	mov	packet_buffer[4], a

	mov 	a, UDID1
	mov	packet_buffer[5], a

	mov 	a, UDID2
	mov	packet_buffer[6], a

	mov 	a, UDID3
	mov	packet_buffer[7], a

	mov 	a, UDID4
	mov	packet_buffer[8], a

	mov 	a, UDID5
	mov	packet_buffer[9], a

	mov 	a, UDID6
	mov	packet_buffer[10], a

	mov 	a, UDID7
	mov	packet_buffer[11], a

	mov	a, CTRL_SERVICE_SIZE
	mov	packet_buffer[12], a

	mov	a, CTRL_SERVICE_NUMBER
	mov	packet_buffer[13], a

	mov	a, CTRL_SERVICE_COMMANDL
	mov	packet_buffer[14], a

	mov	a, CTRL_SERVICE_COMMANDH
	mov	packet_buffer[15], a

	mov	a, 0
	mov	packet_buffer[16], a
	mov	packet_buffer[17], a
	mov	packet_buffer[18], a
	mov	packet_buffer[19], a

	mov	a, RGBLED_SERVICE_NUMBER0
	mov	packet_buffer[20], a

	mov	a, RGBLED_SERVICE_NUMBER1
	mov	packet_buffer[21], a

	mov	a, RGBLED_SERVICE_NUMBER2
	mov	packet_buffer[22], a

	mov	a, RGBLED_SERVICE_NUMBER3
	mov	packet_buffer[23], a

	call 	crc16
	call 	delay_10_us

	call	jd_send
	engint
	goto	app

crc16:
	mov	a, 0xff
	mov	lb@crc, a
	mov	hb@crc, a

	mov	a, (0x20 + JD_HEADER_SIZE)		; skip crc bytes
	mov	lb@indirect_addr, a
	clear	hb@indirect_addr
	add	a, packet_buffer[2]
	mov	gp_counter, a


; generated using python crc_gen.py 12 0 1122334455667788
crc_table:
	mov	a, packet_buffer[2]
	pcadd	a
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	load_crc_12
load_crc_12:
	mov	a, 0x6a
	mov	lb@crc, a
	mov	a, 0xcc
	mov	hb@crc, a
	goto	crc16_l
crc_jmp_err:
	goto	crc_jmp_err


crc16_l:
	; movf  POSTINC0,w        // load w with next databyte 
	idxm	a, indirect_addr 	; load next data byte
	inc 	lb@indirect_addr

	; xorwf CRC16.uByte[0],w  // (a^x):(b^y) 
	xor	a, lb@crc
	; movwf Index             // 
	mov	packet_buffer[0], a
	; andlw 0xf0              // W = (a^x):0 
	and	a, 0xf0
	; swapf Index,f           // Index = (b^y):(a^x) 
	mov	packet_buffer[1], a	; save working state
	mov	a, packet_buffer[0]
	swap	a
	mov	packet_buffer[0], a
	; xorwf Index,f           // Index = (a^b^x^y):(a^x) = i2:i1
	mov	a, packet_buffer[1]	; restore working state
	xor	packet_buffer[0], a

	; movf  Index,W (done above
	mov	a, packet_buffer[0]
    	; andlw 0xf0
	and 	a, 0xf0
    	; xorwf CRC16.uByte[1],W 
	xor	a, hb@crc
	; movwf CRC16.uByte[0]
	mov	lb@crc, a

	; rlcf  Index,W           // use rlf for PIC16 
	mov	a, packet_buffer[0]
	slc	a
	; rlcf  Index,W           // use rlf for PIC16
	mov	a, packet_buffer[0]
	slc	a
	
	; xorwf CRC16.uByte[0],f 
	xor	lb@crc, a
	; andlw 0xe0 
	and 	a, 0xe0
	; xorwf CRC16.uByte[0],f 
	xor	lb@crc, a
	mov	packet_buffer[1], a	; save

	; swapf Index,F 
	mov	a, packet_buffer[0]
	swap	a
	mov	packet_buffer[0], a
	mov	a, packet_buffer[1]	; restore
	; xorwf Index,W 
	xor	a, packet_buffer[0]
	; movwf CRC16.uByte[1]
	mov	hb@crc, a

	; done?
	mov	a, lb@indirect_addr
	ceqsn	a, gp_counter
	goto	crc16_l

	mov	a, hb@crc
	mov	packet_buffer[0], a
	mov	a, lb@crc
	mov	packet_buffer[1], a
	ret

main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.6V;

	SP	=	main_st	;

	clear 	gp_counter
	clear 	interrupt_counter
	clear	app_counter
	clear	prog_state
	clear 	lb@indirect_addr
	clear	hb@indirect_addr
	clear	lb@timer_reset
	clear	hb@timer_reset

	clear 	period_counter
	set1	period_counter.0

	mov	a, 0x00
	mov 	PAPH, a
	mov 	PAC, a

	; configure jd line as input with pull up
	PAPH.JD_LINE	=	1	; enable pull up
	PAC.JD_LINE	=	0	; set input

	; configure jd led as output 
	PAC.JD_LED 	= 	1	; output
	PA.JD_LED	= 	0	; high

	PAPH.NEOPIXEL	=	0
	PAC.NEOPIXEL	=	1
	PA.NEOPIXEL	= 	1

	clear 	green
	clear 	red
	clear 	blue

wait_till_high:
	t1sn	PA.JD_LINE
	goto	wait_till_high

	call set_neopixel_rgb ; reset neopixel

	; configure timer 1
	mov	a, 0x00
	mov	INTRQ, a
	mov	INTEN, a
	set1		INTEN.T16	
	engint
	$ T16M   	IHRC, /16, BIT12;	; 1 mhz timer, 4 096 us period


app:
	disgint
	t1sn	PA.JD_LINE
	goto	jd_receive
	engint

	t0sn	prog_state.CTRL_BLINK_LED
	call 	toggle_led

	t1sn	prog_state.CTRL_PACKET	
	goto	app
	set0	prog_state.CTRL_PACKET
	goto	send_control_packet

toggle_led:
	t1sn	prog_state.BLINK_LED
	ret

	set0	prog_state.BLINK_LED
	mov	a, JD_LED_MSK
	xor	PA, a

	dzsn	app_counter
	ret
	set0	prog_state.CTRL_BLINK_LED
	ret

; do we need a timer for rx timeout?
jd_receive:
jd_rx_lo:
	; low pulse
	t1sn	PA.JD_LINE
	goto	jd_rx_lo
	mov	a, (JD_MAX_PACKET_SIZE - 0x01)	; packet buffer is contained in bytes 32-64 of ram, pre-incremented (++i)
	mov	lb@indirect_addr, a

jd_rx_idle_data:
	t0sn	PA.JD_LINE
	goto	jd_rx_idle_data

	; start bit
	mov	a, 0x00 ; (8th, from goto at end of rx)
	inc 	lb@indirect_addr
	nop
	nop
	nop
	nop

jd_rx_bit_0:
	; BIT 0
	nop
	nop
	t0sn	PA.JD_LINE
	or	a, 0x01
	t0sn	PA.JD_LINE
	or	a, 0x01
	nop
	nop
	
	; BIT 1
	nop
	nop
	t0sn	PA.JD_LINE
	or	a, 0x02
	t0sn	PA.JD_LINE
	or	a, 0x02
	nop
	nop
	
	; BIT 2
	nop
	nop
	t0sn	PA.JD_LINE
	or	a, 0x04
	t0sn	PA.JD_LINE
	or	a, 0x04
	nop
	nop
	
	; BIT 3
	nop
	nop
	t0sn	PA.JD_LINE
	or	a, 0x08
	t0sn	PA.JD_LINE
	or	a, 0x08
	nop
	nop
	
	; BIT 4
	nop
	nop
	t0sn	PA.JD_LINE
	or	a, 0x10
	t0sn	PA.JD_LINE
	or	a, 0x10
	nop
	nop
	
	; BIT 5
	nop
	nop
	t0sn	PA.JD_LINE
	or	a, 0x20
	t0sn	PA.JD_LINE
	or	a, 0x20
	nop
	nop

	; BIT 6
	nop
	nop
	t0sn	PA.JD_LINE
	or	a, 0x40
	t0sn	PA.JD_LINE
	or	a, 0x40
	nop
	nop
	
	; BIT 7
	t0sn	indirect_addr.6
	goto	skip_store
	t0sn	PA.JD_LINE
	or	a, 0x80
	t0sn	PA.JD_LINE
	or	a, 0x80
	idxm	indirect_addr, a ; (8)

test_break:
	; stop bit
	nop
	nop
	t1sn	PA.JD_LINE
	goto 	break_detected
	goto	jd_rx_idle_data ; (6)

skip_store:
	; end of bit 7
	nop
	nop
	nop
	nop
	nop

	; stop bit
	nop
	nop
	t1sn	PA.JD_LINE
	goto 	break_detected
	goto	jd_rx_idle_data ; (6)

break_detected:
	t1sn	PA.JD_LINE
	goto	break_detected

	mov	a, packet_buffer[4]
	ceqsn	a, UDID0
	goto 	app

	mov	a, packet_buffer[5]
	ceqsn	a, UDID1
	goto 	app

	mov	a, packet_buffer[6]
	ceqsn	a, UDID2
	goto 	app

	mov	a, packet_buffer[7]
	ceqsn	a, UDID3
	goto 	app

	mov	a, packet_buffer[8]
	ceqsn	a, UDID4
	goto 	app

	mov	a, packet_buffer[9]
	ceqsn	a, UDID5
	goto 	app

	mov	a, packet_buffer[10]
	ceqsn	a, UDID6
	goto 	app

	mov	a, packet_buffer[11]
	ceqsn	a, UDID7
	goto 	app

check_control:
	mov	a, packet_buffer[13]
	ceqsn	a, SERVICE_NUMBER_CONTROL
	goto	check_rgb_led

handle_control_packet:
	mov	a, packet_buffer[15]
	ceqsn	a, 0x11
	goto 	check_control_identify
	goto	app; unsupported command

check_control_identify:
	mov 	a, packet_buffer[14]
	ceqsn	a, CTRL_COMMAND_IDENTIFY
	goto	check_control_reset

	mov	a, 0x10
	mov	app_counter, a
	set1	prog_state.CTRL_BLINK_LED
	goto	app

check_control_reset:
	ceqsn	a, CTRL_COMMAND_RESET
	goto	app
	reset

check_rgb_led:
	ceqsn	a, SERVICE_NUMBER_LIGHT
	goto	app

	mov	a, packet_buffer[15]
	ceqsn	a, 0x00
	goto	app

check_set_color:
	mov	a, packet_buffer[14]
	ceqsn	a, RGBLED_SET_COLOR_CMD
	goto 	app			
	mov	a, packet_buffer[16]
	and	a, NEOPIXEL_DEFAULT_BRIGHTNESS 
	mov	blue, a
	mov	a, packet_buffer[17]
	and	a, NEOPIXEL_DEFAULT_BRIGHTNESS 
	mov	green, a
	mov	a, packet_buffer[18]
	and	a, NEOPIXEL_DEFAULT_BRIGHTNESS 
	mov	red, a
	call 	set_neopixel_rgb		; should I make this call a goto??
	goto	app

set_neopixel_rgb:
	disgint
	; counter for bits (8)
	clear 	gp_counter
	set1	gp_counter.7
	mov	a, green
	sl	a
	t0sn	FLAG.1		; carry flag
	goto	neopixel_reset_into_1

neopixel_reset_into_0:
	set0	PA.NEOPIXEL
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us

	; T0H 	400 ns +/- 150 ns	(4 ins )
	set1	PA.NEOPIXEL
	nop
	sr	gp_counter
	; T0L 	850 ns +/- 150 ns (definitely 7 ins, maybe 8 ins)
	set0	PA.NEOPIXEL
	t0sn	FLAG.1		; carry flag
	goto	next_byte1_g
	sl	a
	t0sn	FLAG.1		; carry flag
	goto	neopixel_write_1_g
	goto	neopixel_write_0_g

neopixel_reset_into_1:
	set0	PA.NEOPIXEL
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us

neopixel_write_1_g:
	; T1H 	800 ns +/- 150 ns (7 ins)
	set1	PA.NEOPIXEL
	sr	gp_counter
	t0sn	FLAG.1		; carry flag
	goto	next_byte1_g
neopixel_write_1_ga:
	sl	a
	; T1L 	450 ns +/- 150 ns (4 ins)
	set0	PA.NEOPIXEL
	t1sn	FLAG.1		; if next bit is 0
	goto	neopixel_1_to_0_g
	; T1H 	800 ns +/- 150 ns (7 ins)
	set1	PA.NEOPIXEL
	sr	gp_counter
	t1sn	FLAG.1		; carry flag
	goto	neopixel_write_1_ga

next_byte1_g:
	mov	a, red
	sl	a
	set1	gp_counter.7
	; T1L 	450 ns +/- 150 ns (4 ins)
	set0	PA.NEOPIXEL
	t0sn	FLAG.1		; carry flag
	goto	neopixel_write_1_r
	goto	neopixel_write_0_r

neopixel_1_to_0_g:
	set0	PA.NEOPIXEL
	goto 	neopixel_write_0_g

neopixel_write_0_end_g:
	sl	a
	t0sn	FLAG.1		; carry flag
	goto	neopixel_write_1_g

neopixel_write_0_g:
	; T0H 	400 ns +/- 150 ns	(4 ins )
	set1	PA.NEOPIXEL
	nop
	sr	gp_counter	; decrement bit counter
	; T0L 	850 ns +/- 150 ns (definitely 7 ins, maybe 8 ins)
	set0	PA.NEOPIXEL
	t1sn	FLAG.1		; carry flag
	goto	neopixel_write_0_end_g	; load next byte!
	set1	gp_counter.7
	mov	a, red
	sl	a
	t1sn	FLAG.1		; carry flag
	goto	neopixel_write_0_r

neopixel_write_1_r:
	; T1H 	800 ns +/- 150 ns (7 ins)
	set1	PA.NEOPIXEL
	sr	gp_counter
	t0sn	FLAG.1		; carry flag
	goto	next_byte1_r
neopixel_write_1_ra:
	sl	a
	nop
	; T1L 	450 ns +/- 150 ns (4 ins)
	set0	PA.NEOPIXEL
	t1sn	FLAG.1		; if next bit is 0
	goto	neopixel_1_to_0_r
	; T1H 	800 ns +/- 150 ns (7 ins)
	set1	PA.NEOPIXEL
	sr	gp_counter
	t1sn	FLAG.1		; carry flag
	goto	neopixel_write_1_ra

next_byte1_r:
	mov	a, blue
	sl	a
	set1	gp_counter.7
	; T1L 	450 ns +/- 150 ns (4 ins)
	set0	PA.NEOPIXEL
	t0sn	FLAG.1		; carry flag
	goto	neopixel_write_1_b
	goto	neopixel_write_0_b


neopixel_1_to_0_r:
	set0	PA.NEOPIXEL
	goto 	neopixel_write_0_r

neopixel_write_0_end_r:
	sl	a
	t0sn	FLAG.1		; carry flag
	goto	neopixel_write_1_r

neopixel_write_0_r:
	; T0H 	400 ns +/- 150 ns	(4 ins )
	set1	PA.NEOPIXEL
	nop
	sr	gp_counter	; decrement bit counter
	; T0L 	850 ns +/- 150 ns (definitely 7 ins, maybe 8 ins)
	set0	PA.NEOPIXEL
	t1sn	FLAG.1		; carry flag
	goto	neopixel_write_0_end_r	; load next byte!
	set1	gp_counter.7
	mov	a, blue
	sl	a
	t1sn	FLAG.1		; carry flag
	goto	neopixel_write_0_b

neopixel_write_1_b:
	; T1H 	800 ns +/- 150 ns (7 ins)
	set1	PA.NEOPIXEL
	sr	gp_counter
	t0sn	FLAG.1		; carry flag
	goto	next_byte1_b
neopixel_write_1_ba:
	sl	a
	; T1L 	450 ns +/- 150 ns (4 ins)
	set0	PA.NEOPIXEL
	t1sn	FLAG.1		; if next bit is 0
	goto	neopixel_1_to_0_b
	; T1H 	800 ns +/- 150 ns (7 ins)
	set1	PA.NEOPIXEL
	sr	gp_counter
	t1sn	FLAG.1		; carry flag
	goto	neopixel_write_1_ba

next_byte1_b:
	nop
	nop
	; T1L 	450 ns +/- 150 ns (4 ins)
	set0	PA.NEOPIXEL
	nop
	goto	neopixel_latch


neopixel_1_to_0_b:
	set0	PA.NEOPIXEL
	goto 	neopixel_write_0_b

neopixel_write_0_end_b:
	sl	a
	t0sn	FLAG.1		; carry flag
	goto	neopixel_write_1_b

neopixel_write_0_b:
	; T0H 	400 ns +/- 150 ns	(4 ins )
	set1	PA.NEOPIXEL
	nop
	sr	gp_counter	; decrement bit counter
	; T0L 	850 ns +/- 150 ns (definitely 7 ins, maybe 8 ins)
	set0	PA.NEOPIXEL
	t1sn	FLAG.1		; carry flag
	goto	neopixel_write_0_end_b	; load next byte!

	nop
	nop
	nop
	nop
	nop
neopixel_latch:
	set0	PA.NEOPIXEL
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	set1	PA.NEOPIXEL
	engint
	ret


;void	Byte_Mul_Byte (void)
;{	//	mul_t2[W]	=	mul_x1[B] * mul_y1[B]
;	mul_t2$1	=	0;
;	BYTE	cnt;
;	cnt	=	8;

;	do
;	{
;		mul_x1	>>=	1;
;		if (CF)
;		{
;			mul_t2	+=	(mul_y1 << 8);
;		}
;		mul_t2	>>>=	1;
;	} while (--cnt);
;}




delay_ms:
	mov	a, 96
delay_ms_loop:
	call	delay_10_us
	dzsn	a
	goto	delay_ms_loop
	ret

; 80 instructions - 4 to account for goto and ret
delay_10_us:
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	ret

sleep:
	PAC.JD_LINE = 0
	paph.JD_LINE = 0
	
	$ PADIER = 0x08
	mov a, 0x20
	mov misc, a ; fast wakeup
	.CLKMD	=   0xF4;   //  -> ILRC
        .CLKMD.En_IHRC   =   0;      //  close IHRC
       	STOPEXE
        .CLKMD   =   0x34;           //  -> IHRC / 2

	ret
