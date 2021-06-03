#define JD_FRAME_FLAG_COMMAND 0
#define JD_FRAME_FLAG_ACK_REQUESTED 1
#define JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS 2
#define JD_FRAME_FLAG_VNEXT 7

#define JD_AD0_ACK_SUPPORTED 0x01
#define JD_AD0_IDENTIFIER_IS_SERVICE_CLASS_SUPPORTED 0x02
#define JD_AD0_FRAMES_SUPPORTED 0x04
#define JD_AD0_IS_CLIENT 0x08

#define JD_SERVICE_INDEX_CONTROL 0x00
#define JD_SERVICE_INDEX_MY_SERVICE 0x01
#define JD_SERVICE_INDEX_BROADCAST 0x3d
#define JD_SERVICE_INDEX_PIPE 0x3e
#define JD_SERVICE_INDEX_ACK 0x3f

#define JD_AD0_IS_CLIENT_MSK 0x08

#define JD_HIGH_CMD 0x00
#define JD_HIGH_REG_RW_SET 0x20
#define JD_HIGH_REG_RW_GET 0x10
#define JD_HIGH_REG_RO_GET 0x11

// #define JD_CONTROL_CMD_IDENTIFY 0x81 - not supported anymore
#define JD_CONTROL_CMD_RESET 0x82
#define JD_CONTROL_CMD_SET_STATUS_LIGHT 0x84

#define JD_CONTROL_REG_RW_RESET_IN 0x80
#define JD_CONTROL_REG_RO_FIRMWARE_IDENTIFIER 0x81

#define JD_REG_RW_STREAMING_SAMPLES 0x03
#define JD_REG_RW_STREAMING_INTERVAL 0x04
#define JD_REG_RO_READING 0x01
#define JD_REG_RO_VARIANT 0x07
#define JD_REG_RO_READING_ERROR 0x06

#define JD_REG_RW_INTENSITY 0x01
#define JD_REG_RW_VALUE 0x02

#define JD_EV_ACTIVE 0x1
#define JD_EV_INACTIVE 0x2
#define JD_EV_CHANGE 0x3
#define JD_EV_STATUS_CODE_CHANGED 0x4

frame_header_size equ 12
crc_size equ 2
payload_size equ 8
buffer_size equ (frame_header_size + 4 + payload_size)

#define f_in_rx flags.0
#define f_set_tx flags.1
#define f_announce_rst_cnt_max flags.2
#define f_ev1 flags.3
#define f_ev2 flags.4
#define f_announce_t16_bit flags.5
#define f_serv0 flags.6
#define f_serv1 flags.7

#define txp_serv0 tx_pending.0
#define txp_serv1 tx_pending.1
#define txp_serv2 tx_pending.2
#define txp_serv3 tx_pending.3
#define txp_serv4 tx_pending.4
#define txp_serv5_sensor tx_pending.5
#define txp_serv6_sensor tx_pending.6
#define txp_serv7_sensor tx_pending.7

pkt_addr equ 12

//
// Module: utils
//

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

.swapm MACRO x, y
	mov a, x
	xch y
	mov x, a
ENDM

.clear_memory MACRO
	.mova memidx$0, _SYS(SIZE.RAM)-1
	clear memidx$1
	mov a, 0x00
clear_loop:
	idxm memidx, a
	dzsn memidx$0
	goto clear_loop
ENDM

.disint MACRO
	// apparently when you get INT during disgint execution, it may not work
	.disgint
ENDM

// we can't call anything from the main app code with INT enabled - we could run out of stack
// if we get hit by an RX INT
.callnoint MACRO lbl
	.disint
	call lbl
	engint
ENDM

.assert_not MACRO cond
	ifset cond
		call panic
ENDM

.assert MACRO cond
	ifclear cond
		call panic
ENDM

.set_log MACRO v
#ifdef PIN_LOG
	PA.PIN_LOG = v
#endif
ENDM

.pulse_log MACRO
	.set_log 1
	.set_log 0
ENDM

/*
The if* macros below are used to resemble 'if' statements:

  ifset some.bit
      do_something

the do_something is exactly one instruction.

You can also write:

  if (some.bit) {
	  do_something
  }

but it's not optimal when do_something is a single instruction.
 */

#define ifset t0sn
#define ifclear t1sn
#define ifneq ceqsn

// t0:t1 = x * y (unsigned); doesn't change y
// ~12 instr.; ~90T
.mul_8x8 EXPAND tmp, t0, t1, x, y 
	clear t1
	.mova tmp, 8
@@:
	sr x
	if (CF) {
		mov a, y
		add t1, a
	}
	src t1
	src t0
	dzsn tmp
	goto @b
ENDM

.on_rising MACRO shadow, test, trg
	if (shadow) {
		ifclear test
			set0 shadow
	} else {
		if (test) {
			set1 shadow
			trg
		}
	}
ENDM

//
// Module: t16
//

#define t16_4us t16_low$0
#define t16_1ms t16_low$1

.t16_chk MACRO t16_v, tim, handler
	mov a, t16_v
	sub a, tim
	and a, 0x80
	ifset ZF
		handler
ENDM

.t16_chk_nz MACRO t16_v, tim, handler
	mov a, tim
	if (!ZF) {
		sub a, t16_v
		and a, 0x80
		ifclear ZF
			handler
	}
ENDM

.t16_set MACRO t16_v, tim, num
	mov a, t16_v
	add a, num
	mov tim, a
ENDM

.t16_set_a MACRO t16_v, tim
	add a, t16_v
	mov tim, a
ENDM

.t16_init EXPAND
t16_init_:
	stt16 t16_low
	$ INTEGS BIT_F // falling edge on T16
	$ T16M IHRC, /64, BIT15
ENDM


.t16_impl EXPAND
t16_sync:
	ldt16 t16_low
	if (INTRQ.T16) {
		INTRQ.T16 = 0
		inc t16_262ms
#ifdef CFG_T16_32BIT
		addc t16_67s
#endif
	}
	mov a, t16_1ms
	swap a
	and a, 0x0f
	mov t16_16ms, a
	mov a, t16_262ms
	swap a
	and a, 0xf0
	or t16_16ms, a
	ret
ENDM

//
// Module: rng
//

.rng_init EXPAND
	$ TM2S 8BIT, /1, /1
	TM2B = 2
	$ TM2C ILRC
	INTRQ = 0x00
	mov a, 7
	call get_id
	mov rng_x, a // start seeding with 7th byte of device ID
	.mova isr0, 37
_rng_byte:
	mov a, 0
	INTRQ.TM2 = 0
@@:
	add a, 1
	ifclear INTRQ.TM2
	  goto @b
	xor a, rng_x
	sl a
	ifset CF
	  or a, 0x01
	mov rng_x, a
	dzsn isr0
	goto _rng_byte
	mov a, rng_x
	mov rng_x, a
ENDM

.rng_add_entropy EXPAND
	mov a, t16_4us
	xor rng_x, a
ENDM

.rng_next MACRO
	.callnoint rng_next
ENDM


/*
This has period of 255 (so we just exclude 0)
	x ^= x << 1
	x ^= x >> 1
	x ^= x << 2
*/
.rng_impl EXPAND
rng_next:
	mov a, rng_x
	ifset ZF // this can happen when we "add entropy"
		mov a, 42
	sl rng_x
	xor rng_x, a
	mov a, rng_x
	sr a
	xor rng_x, a
	mov a, rng_x
	sl a
	sl a
	xor rng_x, a
	mov a, rng_x
	ret
ENDM


//
// Module: blink
//

#ifdef LED_SINK
.led_on MACRO
	PA.PIN_LED = 0
ENDM
.led_off MACRO
	PA.PIN_LED = 1
ENDM
#else
.led_on MACRO
	PA.PIN_LED = 1
ENDM
.led_off MACRO
	PA.PIN_LED = 0
ENDM
#endif

#define blink_cnt0 blink.0
#define blink_cnt1 blink.1
#define blink_disconnected blink.2
#define blink_status_on blink.3

#define txp_announce blink.4
#define txp_ack blink.5
#define txp_fw_id blink.6
#define txp_event blink.7

.blink_process EXPAND
	.led_off
	if (blink_disconnected) {
		ifclear t16_262ms.2
			.led_on
	} else {
		ifset blink_status_on
			.led_on
		mov a, t16_262ms
		sr a
		sub a, blink
		and a, 0x02
		ifclear ZF
			set1 blink_disconnected
	}
ENDM

.blink_rx EXPAND
	// this checks for announce packets
	// note that we do that before checking for size or CRC - the announce from the client may be bigger than we support
	// however, the flag bits we're interested in are at the beginning
	mov a, frm_flags
	// if any of these flags is set, we don't want it
	and a, (1 << JD_FRAME_FLAG_VNEXT)|(1 << JD_FRAME_FLAG_COMMAND)|(1 << JD_FRAME_FLAG_ACK_REQUESTED)|(1 << JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS)
	// service number and cmd must be all 0
	or a, pkt_service_number
	or a, pkt_service_command_h
	or a, pkt_service_command_l
	if (ZF) {
		mov a, pkt_payload[1]
		and a, JD_AD0_IS_CLIENT_MSK
		if (!ZF) {
			set0 blink_disconnected
			mov a, t16_262ms
			sr a
			and a, 0x3
			set0 blink_cnt0
			set0 blink_cnt1
			or blink, a

			.led_on
			.delay 250
			.led_off

			goto _do_leave
		}
	}
ENDM

//
// Module: RAM
//

	.ramadr 0x00
	WORD    memidx
	BYTE    flags
	BYTE    tx_pending
	BYTE	isr0, isr1
	BYTE    rx_data

	BYTE    blink

	WORD    t16_low
	BYTE	t16_16ms
	BYTE    t16_262ms

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
	BYTE	isr2 // this is overwritten during rx if packet too long (but that's fine)
	BYTE    rng_x

	// so far:
	// application is not using stack when IRQ enabled
	// rx ISR can do up to 3
	WORD	main_st[3]

	BYTE    ack_crc_l, ack_crc_h
	BYTE    t_tx

#ifdef CFG_T16_32BIT
	BYTE    t16_67s
#endif

#ifdef CFG_RESET_IN
	BYTE    t_reset
#endif
	goto	main

//
// Module: rx
//

#define rx_buflimit isr0

#ifdef PWR_SERVICE
#define rx_flags isr1
#define rx_prev_data isr2
#define rx_pwr_neq rx_flags.0
#define rx_pwr_flip_sw rx_flags.1
#endif

.rx_init EXPAND
	PAPH.PIN_JACDAC = 1
	call reset_tm2
	TM2B = 64 // irq every 64 instructions, 8us
	$ TM2C SYSCLK
	$ INTEN = TM2
ENDM

reset_tm2:
	mov a, 0
	mov TM2CT, a
	INTRQ.TM2 = 0
	$ TM2S 8BIT, /1, /1
	set1 f_set_tx
	ret

	// TODO we have about 8 instructions free here

	.romadr	0x10            // interrupt vector
interrupt:
	INTRQ.TM2 = 0
	ifset f_in_rx
	  goto timeout
	ifset PA.PIN_JACDAC
	  reti // 8 cycles to here

	pushaf

	.pulse_log

	// seed the PRNG with reception time of each packet
	.rng_add_entropy

	set1 f_in_rx
	$ TM2S 8BIT, /1, /25 // ~200us
	.mova TM2CT, 0
	engint

	// wait for end of lo pulse
@@:
	ifclear PA.PIN_JACDAC
	  goto @b

	.mova memidx$0, pkt_addr
	.mova rx_buflimit, buffer_size+1

	clear frm_sz // make sure packet is invalid, if we do not recv anything
	mov a, 0
#ifdef PWR_SERVICE
	clear rx_flags
#endif
	goto rx_wait_start

IDSIZE equ 8

.fill_id EXPAND
	a = pkt_addr+4+IDSIZE-1
	mov memidx$0, a
	.mova isr0, IDSIZE
@@:
	mov a, isr0
	call get_id
	idxm memidx, a
	dec memidx$0
	dzsn isr0
	goto @B
ENDM

.check_id EXPAND fail_lbl
	a = pkt_addr+4+IDSIZE-1
	mov memidx$0, a
	.mova isr0, IDSIZE
@@:
	mov a, isr0
	call get_id
	mov isr1, a
	idxm a, memidx
	ifneq a, isr1
	  goto fail_lbl
	dec memidx$0
	dzsn isr0
	goto @B
ENDM

// requires a=1...8
get_id:
	pcadd a
.IFDEF RELEASE
	.User_Roll 14 BYTE, "genid.exe", "rolling.txt"
.ELSE
	ret 0x01
	ret 0x23
	ret 0x45
	ret 0x67
	ret 0x89
	ret 0xab
	ret 0xcd
	ret 0xef

	// note that these two CRCs always differ by XOR 0xe77e regardless of device id
	// this can possibly be used in future to only store one of them
	ret 0x59 // crc of 0400 0123456789abcdef
	ret 0xe5
	ret 0x27 // crc of 0800 0123456789abcdef
	ret 0x02
	ret 0x12 // crc of 0c00 0123456789abcdef
	ret 0xaf
.ENDIF

rx_start:
	mov TM2CT, a // a is 0 here
	// setup TM2 to expire in 16us
	$ TM2S 8BIT, /1, /2

#ifdef PWR_SERVICE
pwr_test_size equ 8
	.mova rx_prev_data, rx_data
	clear rx_data
	// ----------------------------------------------------
	ifset PA.PIN_JACDAC
		set1 rx_data.0
	ifset rx_pwr_flip_sw
		set0 PA.PIN_SWITCH
	set0 rx_pwr_flip_sw
	nop
	nop
	mov a, memidx$0
	// ----------------------------------------------------
	ifset PA.PIN_JACDAC
		set1 rx_data.1
	nop
	sub a, pkt_addr + (pwr_test_size + 2)
	ifclear CF
	  mov a, -(pwr_test_size + 2)
	add a, (pwr_test_size + 3)
	sl a
	// ----------------------------------------------------
	ifset PA.PIN_JACDAC
		set1 rx_data.2
	nop
	pcadd a
	// a is always even - so this is unreachable
	nop
	// case of memidx==0 or memidx>9; we want the match to always succeed
	mov a, rx_prev_data
	goto _bit3
	// cases of memidx==1,...,8
.for v, <0x15, 0x59, 0x04, 0x05, 0x5A, 0xC9, 0xA4, 0x1F>
	mov a, v
	goto _bit3
.endm
	// cases of memidx==9 - i.e., we are just past the first 8 bytes, now is time to flip the switch if they match
	set1 rx_pwr_flip_sw
	goto _bit3
	
_bit3:
	// ----------------------------------------------------
	ifset PA.PIN_JACDAC
		set1 rx_data.3
	ifset rx_pwr_neq // if no match
	    set0 rx_pwr_flip_sw // do not flip switch
	sub a, rx_prev_data
	ifclear ZF
	   set1 rx_pwr_neq	// if no match, clear the match flag
	nop
	// ----------------------------------------------------
	ifset PA.PIN_JACDAC
		set1 rx_data.4
	nop
	nop
	nop
	nop
	nop
	mov a, 0x20 // use regular loop reception from bit 5 on
#else
	clear rx_data
	nop
	mov a, 0x01
#endif

rx_next_bit:
	// ----------------------------------------------------
	ifset PA.PIN_JACDAC
		or rx_data, a
	nop
	sl a
	nop
	ceqsn a, 0x80
		goto rx_next_bit
rx_lastbit:
#ifdef PWR_SERVICE
	// re-enable switch; it was disabled (if any) for 7 out of 8 bits, and this is a convienient place to re-enable it
	set1 PA.PIN_SWITCH
#else
	nop
#endif
	ifset PA.PIN_JACDAC
		or rx_data, a
	mov a, rx_data
	idxm memidx, a   	// 2T
	dzsn rx_buflimit    // rx_buflimit--
		inc memidx$0    // when rx_buflimit reaches 0, we stop incrementing memidx
	ifset ZF          	// if rx_buflimit==0
		inc rx_buflimit //     rx_buflimit++ -> keep rx_buflimit at 0
	mov a, 0
	mov TM2CT, a		// clear TM2CT before the wait (of 16us before start bit)

// wait for serial transmission to start
rx_wait_start:
.repeat 20
	ifclear PA.PIN_JACDAC
	  goto rx_start
.endm
	goto rx_wait_start

timeout:
	INTEN = 0 // for reasons unknown the interrupts are not disabled here, at least when single-stepping in ICE

	.set_log 1

	// this is nested IRQ; we want to return to original code, not outer interrupt
	popaf // this is really popping the address; we hope there's no problem writing junk to flags register
	//mov a, SP
	//sub a, 2
	//mov SP, a

leave_irq:
	.blink_rx

#ifdef CFG_BROADCAST
	ifset frm_flags.JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS
		goto check_service_class
#endif
    .check_id not_interested // uses isr0, isr1

check_size:
	// we have to check size before checking CRC
	mov a, frm_sz
	sub a, buffer_size-frame_header_size+1
	ifclear CF
	  goto pkt_error // it was a packet for us, but it was too large

	// save crc_l/h for future comparison
	.mova rx_data, crc_l
	.mova isr2, crc_h
	mov a, 0xff
	mov crc_l, a
	mov crc_h, a
	.mova memidx$0, pkt_addr+2
	mov a, frm_sz
	add a, 10
	call crc16 // uses isr0,1

	mov a, crc_l
	ifneq a, rx_data
	  goto pkt_error
	mov a, crc_h
	ifneq a, isr2
	  goto pkt_error

	ifclear frm_flags.JD_FRAME_FLAG_COMMAND
	  goto not_interested // this is a report
	ifset frm_flags.JD_FRAME_FLAG_VNEXT
	  goto pkt_error

#ifdef CFG_BROADCAST
	mov a, pkt_device_id[3]
	ifclear ZF
	    mov a, 1
	ifset frm_flags.JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS
		mov pkt_service_number, a
#endif

	if (frm_flags.JD_FRAME_FLAG_ACK_REQUESTED) {
		set1 txp_ack
		.mova ack_crc_l, crc_l
		.mova ack_crc_h, crc_h
	}

	// sync the timer before packet processing - it may need the current value
	call t16_sync

	//
	// Control service
	//

	mov a, pkt_service_number
	ifneq a, 0
		goto not_ctrl

handle_ctrl_service:
	mov a, pkt_service_command_h

	if (a == JD_HIGH_CMD) {
		mov a, pkt_service_command_l

		if (a == JD_CONTROL_CMD_RESET) {
			reset
		}
		if (a == JD_CONTROL_CMD_SET_STATUS_LIGHT) {
			// first turn off LED
			set0 blink_status_on
			// if any of rgb is non-zero
			mov a, pkt_payload[0]
			or a, pkt_payload[1]
			or a, pkt_payload[2]
			ifclear ZF
				// we enable LED
				set1 blink_status_on
		}

		goto rx_process_end
	}

#ifdef CFG_RESET_IN
	if (a == JD_HIGH_REG_RW_SET) {
		mov a, pkt_service_command_l

		if (a == JD_CONTROL_REG_RW_RESET_IN) {
			clear t_reset // first disable reset-in
			mov a, pkt_payload[3]
			ifneq a, 0
				goto pkt_invalid // they ask us to wait too long
			mov a, pkt_payload[2]
			sr a
			sr a
			ifset ZF
				goto rx_process_end // keep disabled - timer was 0
			add a, t16_262ms
			ifset ZF
			  mov a, 1 // t_reset==0 means disabled; avoid that
			mov t_reset, a // set timer
		}
		goto rx_process_end
	}
#endif

#ifdef CFG_FW_ID
	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l
		if (a == JD_CONTROL_REG_RO_FIRMWARE_IDENTIFIER) {
			set1 txp_fw_id
		}
	}
#endif

	goto rx_process_end

not_ctrl:
	ifneq a, 1
		goto not_serv1
	goto serv_rx

not_serv1:
rx_process_end:

not_interested:
_do_leave:
	// sync the timer, in case we interrupted the main loop just before it checks for f_set_tx
	call t16_sync
	set0 f_in_rx
	call reset_tm2
	$ INTEN = TM2
	popaf
	.set_log 0
	reti

pkt_overflow:
pkt_invalid:
pkt_error:
	.pulse_log
	.pulse_log
	goto _do_leave

//
// Module: tx
//

#define tx_data isr1
#define tx_cntdown isr2

switch_to_rx:
	call interrupt
	goto loop

try_tx:
	.disint
	// if f_set_tx is set, it means there was a reception interrupt very recently
	// in that case we shall try tx later
	if (f_set_tx) {
		engint
		goto loop
	}
	ifclear PA.PIN_JACDAC
		goto switch_to_rx
	PA.PIN_JACDAC = 0 // set lo
	PAC.PIN_JACDAC = 1 // set to output

	.fill_id // uses isr0

	PA.PIN_JACDAC = 1

	call reset_tm2
	$ TM2S 8BIT, /1, /6 // ~50us

	call prep_tx // ~20-~50 cycles

#ifdef PWR_SERVICE
	ifset frm_flags.JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS
	    goto _skip_crc
#endif

	mov a, pkt_size
	add a, 3+4 // add pkt-header size + round up to word
	and a, 0b1111_1100
	mov frm_sz, a // frm_sz == 4 || 8 || 12
	// initialize crc_l/h from the burned-in values, depending on packet size
	sr a
	add a, 7
	mov isr0, a
	call get_id
	mov crc_l, a
	mov a, isr0
	add a, 1
	call get_id
	mov crc_h, a

	.mova memidx$0, pkt_addr+frame_header_size
	mov a, frm_sz // len
	call crc16 // uses isr0, isr1

_skip_crc:
	.mova memidx$0, pkt_addr
	mov a, frame_header_size+1
	add a, frm_sz
	mov tx_cntdown, a

@@:
	t1sn INTRQ.TM2
	goto @b

	goto _stop

tx_not_last:
	PA.PIN_JACDAC = 0
	mov a, 8
	nop
_nextbit:	
	sr tx_data
	ifset CF
	  goto _bit1
	nop
	PA.PIN_JACDAC = 0
	dzsn a
	goto _nextbit
	goto _stop

_bit1:
	PA.PIN_JACDAC = 1
	dzsn a
	goto _nextbit
	goto _stop

_stop:
	idxm a, memidx // 2T
	mov tx_data, a
	inc memidx$0
	PA.PIN_JACDAC = 1
	nop
	nop
	nop
	nop
	dzsn tx_cntdown
		goto tx_not_last
tx_last:
	nop
	PA.PIN_JACDAC = 0
	.delay 90
	PA.PIN_JACDAC = 1
	PAC.PIN_JACDAC = 0 // set to input
	PAPH.PIN_JACDAC = 1
	call reset_tm2
	engint
	goto loop

//
// Module: crc16
//

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

#define crc_len isr0
#define crc_tmp isr1

// ~27 cycles per byte
crc16:
	mov crc_len, a
crc16_loop:
	// uint8_t data = *ptr++;
	idxm a, memidx
	inc memidx$0
	// uint8_t x = (crc >> 8) ^ data;
	xor a, crc_h
	mov crc_tmp, a
	// x ^= x >> 4;
	swap a
	and a, 0x0f
	xor crc_tmp, a // crc_tmp==x	
	// crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x; =>
	// crc_h = crc_l ^ (x << 4) ^ (x >> 3)
	mov a, crc_tmp
	swap a
	and a, 0xf0
	xor a, crc_l
	mov crc_h, a
	mov a, crc_tmp
	sr a
	sr a
	sr a
	xor crc_h, a
	// crc_l = (x << 5) ^ x
	.mova crc_l, crc_tmp
	swap a
	and a, 0xf0
	sl a
	xor crc_l, a
	// loop back
	dzsn crc_len
	goto crc16_loop
	ret

//
// Module: sensor
//


#define txp_streaming_samples txp_serv5_sensor
#define txp_streaming_interval txp_serv6_sensor
#define txp_reading txp_serv7_sensor

.sensor_impl EXPAND
	BYTE streaming_samples
	BYTE streaming_interval
	BYTE t_streaming
	BYTE sensor_state[SENSOR_SIZE]
ENDM

.sensor_rx EXPAND
	mov a, pkt_service_command_h

	if (a == JD_HIGH_REG_RW_SET) {
		mov a, pkt_service_command_l

		if (a == JD_REG_RW_STREAMING_SAMPLES) {
			.mova streaming_samples, pkt_payload[0]
			goto rx_process_end
		}

		if (a == JD_REG_RW_STREAMING_INTERVAL) {
			mov a, pkt_payload[1]
			ifneq a, 0
				goto streaming_int_ovf
			mov a, pkt_payload[0]
			and a, 0xf0
			ifset ZF
				goto streaming_int_undf
			sl a
			ifset CF
				goto streaming_int_ovf
			mov a, pkt_payload[0]
			goto streaming_int_set

		streaming_int_undf:
			mov a, 16
			goto streaming_int_set
		streaming_int_ovf:
			mov a, 127
		streaming_int_set:
			mov streaming_interval, a
			.t16_set_a t16_1ms, t_streaming
			// goto rx_process_end
		}

		goto rx_process_end
	}

	if (a == JD_HIGH_REG_RW_GET) {
		mov a, pkt_service_command_l

		if (a == JD_REG_RW_STREAMING_SAMPLES) {
			set1 txp_streaming_samples
		}

		if (a == JD_REG_RW_STREAMING_INTERVAL) {
			set1 txp_streaming_interval
		}

		goto rx_process_end
	}


	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l

		if (a == JD_REG_RO_READING) {
			set1 txp_reading
			// goto rx_process_end
		}
		
		// goto rx_process_end
	}

	goto rx_process_end
ENDM

.sensor_process EXPAND
	mov a, streaming_samples
	ifset ZF
	  goto skip_stream
	.t16_chk t16_1ms, t_streaming, <goto do_stream>
	goto skip_stream
do_stream:
	.disint
		mov a, streaming_samples
		ifclear ZF
			dec streaming_samples
	engint
	.t16_set t16_1ms, t_streaming, streaming_interval
	set1 txp_reading
	goto loop
skip_stream:
ENDM

.sensor_prep_tx EXPAND
	if (txp_streaming_samples) {
		set0 txp_streaming_samples
		.setcmd JD_HIGH_REG_RW_GET, JD_REG_RW_STREAMING_SAMPLES
		.mova pkt_payload[0], streaming_samples
		.mova pkt_size, 1
		ret
	}

	if (txp_streaming_interval) {
		set0 txp_streaming_interval
		.setcmd JD_HIGH_REG_RW_GET, JD_REG_RW_STREAMING_INTERVAL
		.mova pkt_payload[0], streaming_interval
		.mova pkt_size, 4
		ret
	}

	if (txp_reading) {
		set0 txp_reading
		_cnt => 0
	.repeat SENSOR_SIZE
		.mova pkt_payload[_cnt], sensor_state[_cnt]
		_cnt => _cnt + 1
	.endm
		.mova pkt_size, SENSOR_SIZE
		.set_ro_reg JD_REG_RO_READING
		ret
	}
ENDM

//
// Module: events
//

.ev_process EXPAND
	if (f_ev1) {
		.t16_chk t16_1ms, t_ev, <goto ev_flush>
	}
ENDM

.ev_impl EXPAND
	BYTE ev_cnt
	BYTE t_ev

// ev_send has to be first
ev_send:
	inc ev_cnt
	set1 txp_event
	set1 f_ev1
	set0 f_ev2
	.t16_set t16_1ms, t_ev, 20
	goto loop

ev_flush:
	set1 txp_event
	if (f_ev2) {
		set0 f_ev1
		set0 f_ev2
		goto loop
	}
	set1 f_ev2
	.t16_set t16_1ms, t_ev, 100
	goto loop
	
ev_prep_tx:
	set0 txp_event
	.serv_ev_payload
	mov a, ev_cnt
	or a, 0x80
	mov pkt_service_command_h, a
	ret
ENDM
