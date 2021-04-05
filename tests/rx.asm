#define rx_buflimit isr0
#define rx_crc_range isr2
#define rx_crc_tmp isr1

#define crc_l0 frm_sz
#define crc_h0 frm_flags

.rx_init MACRO
	$ TM2S 8BIT, /1, /1
	TM2B = 75 ; irq every 75 instructions, ~9.5us
	$ TM2C SYSCLK
	INTRQ = 0x00
	$ INTEN = TM2
ENDM


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
	.mova rx_buflimit, buffer_size+1
	clear rx_data
	.mova rx_crc_range, -crc_size-1

	mov a, 0xff
	mov crc_l, a
	mov crc_h, a

	// wait for serial transmission to start
@@:
.repeat 20
	t1sn PA.JD_D
	goto rx_lo_first
.endm
	goto @b

    .include devid.asm

rx_lo_first:
	$ TM2S 8BIT, /1, /3	 // 2T
	nop
	nop
	goto rx_lo_skip // 2T

rx_byte:
.repeat 10
	t1sn PA.JD_D
	goto rx_lo
.endm
	goto rx_byte

rx_lo:
	xch rx_data    		// a==0 here, so this clears rx_data for next round
	idxm memidx, a   	// 2T
	dzsn rx_buflimit    // rx_buflimit--
	inc lb@memidx    	// when rx_buflimit reaches 0, we stop incrementing memidx
	t0sn ZF          	// if rx_buflimit==0
	inc rx_buflimit     //     rx_buflimit++ -> keep rx_buflimit at 0

rx_lo_skip:
		t0sn PA.JD_D
		set1 rx_data.0

	// uint8_t x = (crc >> 8) ^ data;
	mov a, crc_d
	xor a, crc_h
	mov rx_crc_tmp, a
	// x ^= x >> 4;
	swap a
	and a, 0x0f
	xor rx_crc_tmp, a // rx_crc_tmp==x	

		t0sn PA.JD_D
		set1 rx_data.1

	// crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x; =>
	// crc_h = crc_l ^ (x << 4) ^ (x >> 3)
	mov a, rx_crc_tmp
	swap a
	and a, 0xf0
	xor a, crc_l
	mov crc_h0, a
	mov a, rx_crc_tmp

		t0sn PA.JD_D
		set1 rx_data.2

	sr a
	sr a
	sr a
	xor crc_h0, a
	nop
	nop

		t0sn PA.JD_D
		set1 rx_data.3

	// crc_l = (x << 5) ^ x
	mov a, rx_crc_tmp
	mov crc_l0, a
	swap a
	and a, 0xf0
	sl a
	xor crc_l0, a

		t0sn PA.JD_D
		set1 rx_data.4

	// check if we're in CRC range - after first two bytes of stored crc, and before the end of the whole packet
	mov a, packet_buffer[2]
	add a, frame_header_size-crc_size-1
	sub a, rx_crc_range

	// if in CRC range, store into crc_l
	mov a, crc_l0
	t1sn CF
	mov crc_l, a

		t0sn PA.JD_D
		set1 rx_data.5

	// if in CRC range, store into crc_h
	mov a, crc_h0
	t1sn CF
	mov crc_h, a

	nop
	nop
	nop
	
		t0sn PA.JD_D
		set1 rx_data.6

	nop
	nop
	nop
	nop
	
		PA.JD_LED = 1 // bit marking
		nop
		t0sn PA.JD_D
		set1 rx_data.7 // 9T excluding goto rx_byte
		PA.JD_LED = 0 // bit marking

	inc rx_crc_range
	mov a, rx_data
	mov crc_d, a

	nop
	nop
	nop

	mov a, 0
	mov TM2CT, a
	goto rx_byte


timeout:
	// this is nested IRQ; we want to return to original code, not outer interrupt
	// TODO: try fake popaf
	mov a, SP
	sub a, 2
	mov SP, a
leave_irq:
	mov a, crc_l
	ceqsn a, packet_buffer[0]
	goto pkt_error
	mov a, crc_h
	ceqsn a, packet_buffer[1]
	goto pkt_error

	.mova isr0, packet_buffer[3]
	t1sn isr0.JD_FRAME_FLAG_COMMAND
	goto not_interested // this is a report
	t0sn isr0.JD_FRAME_FLAG_VNEXT
	goto pkt_error

    .check_id not_interested // uses isr0, isr1

	mov a, packet_buffer[2]
	sub a, buffer_size-frame_header_size+1
	t1sn CF
	goto pkt_error // it was a packet for us, but it was too large

// JD_FRAME_FLAG_ACK_REQUESTED
// JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS

not_interested:
_do_leave:
	set0 flags.f_in_rx
	.mova TM2CT, 0
	$ TM2S 8BIT, /1, /1
	set1 flags.f_set_tx
	popaf
	reti

pkt_error:
	PA.JD_TM = 1
	PA.JD_TM = 0
	goto _do_leave

