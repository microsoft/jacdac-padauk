
; require hardware app timer?
#define APP_TIMER	1

#define UDID0 		0x11
#define UDID1 		0x22
#define UDID2 		0x33
#define UDID3 		0x44
#define UDID4 		0x55
#define UDID5 		0x66
#define UDID6 		0x77
#define UDID7 		0x88


#define JD_HEADER_SIZE			12
#define JD_CMD_EVENT 			0x01

; 0x1473a263
#define BUTTON_SERVICE_NUMBER0 		0x63
#define BUTTON_SERVICE_NUMBER1 		0xa2
#define BUTTON_SERVICE_NUMBER2 		0x73
#define BUTTON_SERVICE_NUMBER3 		0x14

#define BUTTON_EVT_DOWN                	1
#define BUTTON_EVT_UP                  	2
#define BUTTON_EVT_CLICK               	3
#define BUTTON_EVT_LONG_CLICK          	4
#define BUTTON_EVT_HOLD                	5
#define BUTTON_EVT_DOUBLE_CLICK        	6


#define SERVICE_NUMBER_CONTROL		0
#define SERVICE_NUMBER_BUTTON		1

#define CTRL_FRAME_CRCL			0xF1
#define CTRL_FRAME_CRCH			0x95
#define CTRL_FRAME_SIZE			12		; payload size only
#define CTRL_FRAME_FLAGS		0x00
#define CTRL_SERVICE_NUMBER		0x00
#define CTRL_SERVICE_COMMANDL		0x00
#define CTRL_SERVICE_COMMANDH		0x00
#define CTRL_SERVICE_SIZE		8
#define CTRL_COMMAND_IDENTIFY		0x81
#define CTRL_COMMAND_RESET		0x82


#define BUTTON_FRAME_CRCL		0x41
#define BUTTON_FRAME_CRCH		0x9b
#define BUTTON_FRAME_SIZE		8		; payload size only
#define BUTTON_FRAME_FLAGS		0x00
#define BUTTON_SERVICE_NUMBER		0x01
#define BUTTON_SERVICE_COMMANDL		JD_CMD_EVENT
#define BUTTON_SERVICE_COMMANDH		0x00

#define BUTTON_SERVICE_SIZE		4

;python crc_check.py 080011223344556677880401010002000000
#define BUTTON_UP_ONLY_CRCL		0xD9
#define BUTTON_UP_ONLY_CRCH		0xD7

;python crc_check.py 1000112233445566778804010100020000000401010003000000
#define BUTTON_UP_CLICK_CRCL		0xD8
#define BUTTON_UP_CLICK_CRCH		0xA6

;python crc_check.py 1000112233445566778804010100020000000401010004000000
#define BUTTON_UP_LONG_CLICK_CRCL	0xF5
#define BUTTON_UP_LONG_CLICK_CRCH	0xF7


#define JD_LINE		3
#define BUTTON		4
#define JD_LED		6
#define	JD_LED_MSK	0x40



; each idle detect loop takes 10 ins. (1.25 us). Idle period is 100 microseconds.
#define IDLE_COUNTER	80

#define	JD_MAX_PACKET_SIZE	0x20
#define JD_MAX_PACKET_SIZE_TB	6

; prog state register defines
#define CTRL_PACKET		0
#define BUTTON_CHECK		1
#define BUTTON_DOWN		2
#define BUTTON_HELD		3

; button_state register defines
#define BUTTON_LO		0
#define BUTTON_HI		1
#define BUTTON_HOLD		2
#define BUTTON_CLICK		3
#define BUTTON_LONG_CLICK	4

#define BUTTON_SIGMA_THRESH_START      6

#define BUTTON_THRESH_LO         	12
#define BUTTON_THRESH_HI         	6

#define BUTTON_THRESH_LONG        	250	; 250 *  4 ms = 1 second
#define BUTTON_THRESH_HOLD        	120	; 255 + 120 = (375 * 4 ms) = 1500 ms for a hold

.CHIP   PMS150C
; Give package map to writer	pcount	VDD	PA0	PA3	PA4	PA5	PA6	PA7	GND	SHORTC_MSK1	SHORTC_MASK1	SHIFT
.writer package 		6, 	5, 	0,	6, 	1, 	4,	3, 	0,	2, 	0x0007, 	0x0007, 	0
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable		// Security 7/8 words Enable
	.Code_Option	LVR		3.0V
	.Code_Option	Bootup_Time	Slow
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
	WORD	crc
	BYTE	interrupt_counter
	BYTE	period_counter		; sl'd each time interrupt_counter is reached
	BYTE	app_counter
	BYTE	sigma
	BYTE	button_state

	.ramadr	0x10
	WORD	button_counter
	WORD	main_st [0x03];
	WORD	timer_reset

	; words can be used up until 0x1e
	.ramadr	0x20
	byte 	packet_buffer[JD_MAX_PACKET_SIZE]

	goto	main


	.romadr	0x10            // interrupt vector
interrupt:
	pushaf

	stt16	timer_reset
	set0	intrq.T16
	inc 	interrupt_counter

	inc 	lb@button_counter
	t0sn	FLAG.1
	inc	hb@button_counter

	set1	prog_state.BUTTON_CHECK

	t1sn	interrupt_counter.6
	goto	exit_interrupt	
	
	clear	interrupt_counter
	sl 	period_counter
	
	t1sn	period_counter.2
	goto	exit_interrupt

	clear 	period_counter
	set1	period_counter.0
	set1	prog_state.CTRL_PACKET

exit_interrupt:
	popaf
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

	set0	prog_state.CTRL_PACKET

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

	mov	a, BUTTON_SERVICE_NUMBER0
	mov	packet_buffer[20], a

	mov	a, BUTTON_SERVICE_NUMBER1
	mov	packet_buffer[21], a

	mov	a, BUTTON_SERVICE_NUMBER2
	mov	packet_buffer[22], a

	mov	a, BUTTON_SERVICE_NUMBER3
	mov	packet_buffer[23], a

	; precompute crc for CTRL packets
	mov 	a, CTRL_FRAME_CRCL
	mov	packet_buffer[0], a
	mov	a, CTRL_FRAME_CRCH
	mov	packet_buffer[1], a

	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us

	call	jd_send
	engint
	goto	app

load_button_packet:
	mov	a, BUTTON_FRAME_SIZE
	mov	packet_buffer[2], a

	mov	a, BUTTON_FRAME_FLAGS
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

	mov	a, BUTTON_SERVICE_SIZE
	mov	packet_buffer[12], a

	mov	a, BUTTON_SERVICE_NUMBER
	mov	packet_buffer[13], a

	mov	a, BUTTON_SERVICE_COMMANDL
	mov	packet_buffer[14], a

	mov	a, BUTTON_SERVICE_COMMANDH
	mov	packet_buffer[15], a

	ret

send_down:
	disgint
	set0	button_state.BUTTON_LO
	call	jd_send_start_pulse
	ceqsn	a, 0x0
	goto	jd_receive

	call	load_button_packet

	mov	a, BUTTON_EVT_DOWN
	mov	packet_buffer[16], a

	clear 	packet_buffer[17]
	clear 	packet_buffer[18]
	clear 	packet_buffer[19]

	call 	crc16
	call 	delay_10_us

	call	jd_send
	engint
	goto	app

send_hold:
	disgint
	set0	button_state.BUTTON_HOLD
	call	jd_send_start_pulse
	ceqsn	a, 0x0
	goto	jd_receive

	call	load_button_packet

	mov	a, BUTTON_EVT_HOLD
	mov	packet_buffer[16], a

	clear 	packet_buffer[17]
	clear 	packet_buffer[18]
	clear 	packet_buffer[19]

	call 	crc16
	call 	delay_10_us

	call	jd_send
	engint
	goto	app

send_up:
	disgint
	call	jd_send_start_pulse
	ceqsn	a, 0x0
	goto	jd_receive

	call	load_button_packet

	mov	a, BUTTON_EVT_UP
	mov	packet_buffer[16], a

	clear 	packet_buffer[17]
	clear 	packet_buffer[18]
	clear 	packet_buffer[19]

	t0sn	button_state.BUTTON_CLICK
	goto	append_click

	t0sn	button_state.BUTTON_LONG_CLICK
	goto	append_long_click

	call	delay_10_us

	; precompute crc for up packets
	mov 	a, BUTTON_UP_ONLY_CRCL
	mov	packet_buffer[0], a
	mov	a, BUTTON_UP_ONLY_CRCH
	mov	packet_buffer[1], a

	; only sending up
	goto	send_up_cont

append_click:
	; multi-frame packet
	mov	a, 8
	add	packet_buffer[2], a

	mov	a, BUTTON_SERVICE_SIZE
	mov	packet_buffer[20], a

	mov	a, BUTTON_SERVICE_NUMBER
	mov	packet_buffer[21], a

	mov	a, BUTTON_SERVICE_COMMANDL
	mov	packet_buffer[22], a

	mov	a, BUTTON_SERVICE_COMMANDH
	mov	packet_buffer[23], a

	mov	a, BUTTON_EVT_CLICK
	mov	packet_buffer[24], a

	clear 	packet_buffer[25]
	clear 	packet_buffer[26]
	clear 	packet_buffer[27]

	; precompute crc for up + click packets
	mov 	a, BUTTON_UP_CLICK_CRCL
	mov	packet_buffer[0], a
	mov	a, BUTTON_UP_CLICK_CRCH
	mov	packet_buffer[1], a

	goto	send_up_cont

append_long_click:
	; multi-frame packet
	mov	a, 8
	add	packet_buffer[2], a

	mov	a, BUTTON_SERVICE_SIZE
	mov	packet_buffer[20], a

	mov	a, BUTTON_SERVICE_NUMBER
	mov	packet_buffer[21], a

	mov	a, BUTTON_SERVICE_COMMANDL
	mov	packet_buffer[22], a

	mov	a, BUTTON_SERVICE_COMMANDH
	mov	packet_buffer[23], a

	mov	a, BUTTON_EVT_LONG_CLICK
	mov	packet_buffer[24], a

	clear 	packet_buffer[25]
	clear 	packet_buffer[26]
	clear 	packet_buffer[27]

	; precompute crc for up + click packets
	mov 	a, BUTTON_UP_LONG_CLICK_CRCL
	mov	packet_buffer[0], a
	mov	a, BUTTON_UP_LONG_CLICK_CRCH
	mov	packet_buffer[1], a

send_up_cont:
	clear 	button_state

	call	delay_10_us
	call	delay_10_us
	call	delay_10_us
	call	delay_10_us

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

; generated using python crc_gen.py 12,8,16 0 1122334455667788
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
	goto	load_crc_8
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	load_crc_12
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	crc_jmp_err
	goto	load_crc_16
load_crc_8:
	mov	a, 0xc7
	mov	lb@crc, a
	mov	a, 0xf9
	mov	hb@crc, a
	goto	crc16_l
load_crc_12:
	mov	a, 0x6a
	mov	lb@crc, a
	mov	a, 0xcc
	mov	hb@crc, a
	goto	crc16_l
load_crc_16:
	mov	a, 0x19
	mov	lb@crc, a
	mov	a, 0x24
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
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V;

	SP	=	main_st	;

	clear 	gp_counter
	clear 	interrupt_counter
	clear	app_counter
	clear	prog_state
	clear 	lb@indirect_addr
	clear	hb@indirect_addr
	clear	lb@timer_reset
	clear	hb@timer_reset
	clear	sigma
	clear	button_state

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

	; configure button as input
	PAPH.BUTTON	=	1	; enable pull up (default hi for now)
	PAC.BUTTON	=	0	; set input

wait_till_high:
	t1sn	PA.JD_LINE
	goto	wait_till_high

	mov	a, 0x00
	mov	INTRQ, a
	mov	INTEN, a
	set1		INTEN.T16	
	engint
	$ T16M   	IHRC, /16, BIT12;	; 1 mhz timer, 4 096 us period

reset_prog_state:
	set0	prog_state.BUTTON_DOWN
	set0	prog_state.BUTTON_HELD

app:
	disgint
	t1sn	PA.JD_LINE
	goto	jd_receive
	engint

	t0sn	button_state.BUTTON_LO
	goto	send_down

	t0sn	button_state.BUTTON_HOLD
	goto	send_hold

	t0sn	button_state.BUTTON_HI
	goto	send_up

	t0sn	prog_state.CTRL_PACKET	
	goto	send_control_packet

	t1sn	prog_state.BUTTON_CHECK
	goto	app

	set0	prog_state.BUTTON_CHECK
check_button:
check_sig_min:
	mov	a, sigma
	ceqsn	a, 0x00
	goto	check_sig_max
	goto	button_inc

check_sig_max:
	mov	a, sigma
	ceqsn	a, 0x0f
	goto	button_inc_dec
	goto	button_dec

button_dec:
	; button high?
	t0sn	PA.BUTTON
	dec 	sigma
	goto 	check_button_cont

button_inc_dec:
	; button high?
	t0sn	PA.BUTTON
	dec 	sigma

button_inc:
	; button low?
	t1sn	PA.BUTTON
	inc	sigma

check_button_cont:
	; less than? greater than?
	mov	a, sigma
	sub	a, BUTTON_THRESH_HI + 1
	
	t0sn	FLAG.1
	goto	button_up

	mov	a, sigma
	sub	a, BUTTON_THRESH_LO - 1

	; we have not got a strong weighting either way...
	t0sn	FLAG.1
	goto	app

	; our sigma has trended to low...
	; is this our first time?
	t0sn	prog_state.BUTTON_DOWN
	goto	button_dwn_cont

button_dwn:
	clear 	lb@button_counter
	clear 	hb@button_counter

	set1	prog_state.BUTTON_DOWN
	set1 	button_state.BUTTON_LO
	goto	app

button_dwn_cont:
	mov	a, hb@button_counter
	ceqsn	a, 0x01
	goto	app

button_is_held:
	mov	a, lb@button_counter
	ceqsn	a, BUTTON_THRESH_HOLD 	; 1500 ms
	goto	app
	set1	button_state.BUTTON_HOLD
	set1	prog_state.BUTTON_HELD
	goto	app

button_up:
	t1sn	prog_state.BUTTON_DOWN
	goto	app

	set1	button_state.BUTTON_HI

	t0sn	prog_state.BUTTON_HELD
	goto	reset_prog_state

	mov 	a, hb@button_counter
	ceqsn	a, 0x00
	goto	button_long

	;mov	a, lb@button_counter
	;sub	a, 

	set1	button_state.BUTTON_CLICK
	goto	reset_prog_state

button_long:
	set1	button_state.BUTTON_LONG_CLICK
	goto	reset_prog_state
	
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
	goto	app

handle_control_packet:
	mov	a, packet_buffer[15]
	ceqsn	a, 0x0
	goto 	app

check_control_identify:
	mov 	a, packet_buffer[14]
	ceqsn	a, CTRL_COMMAND_IDENTIFY
	goto	check_control_reset

	mov	a, 0x10
	mov	app_counter, a
	;set1	prog_state.CTRL_BLINK_LED
	goto	app

check_control_reset:
	ceqsn	a, CTRL_COMMAND_RESET
	goto	app
	reset

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