#define rx_buflimit isr0

.rx_init MACRO
	PAPH.JD_D = 1
	$ TM2S 8BIT, /1, /1
	TM2B = 64 // irq every 64 instructions, 8us
	$ TM2C SYSCLK
	INTRQ = 0x00
	$ INTEN = TM2
ENDM

	// TODO we have about 14 instructions free here

	.romadr	0x10            // interrupt vector
interrupt:
	INTRQ.TM2 = 0
	ifset flags.f_in_rx
	  goto timeout
	ifset PA.JD_D
	  reti

	pushaf

	PA.JD_TM = 1
	PA.JD_TM = 0

	// seed the PRNG with reception time of each packet
	.rng_add_entropy

	set1 flags.f_in_rx
	$ TM2S 8BIT, /1, /17 // ~136us
	.mova TM2CT, 0
	engint

	// wait for end of lo pulse
@@:
	ifclear PA.JD_D
	  goto @b

	.mova memidx$0, pkt_addr
	.mova rx_buflimit, buffer_size+1

	clear rx_data

	// wait for serial transmission to start
rx_wait_start:
.repeat 20
	ifclear PA.JD_D
	  goto rx_start
.endm
	goto rx_wait_start

    .include devid.asm

rx_start:
	$ TM2S 8BIT, /1, /3	 // 2T
	nop
	nop
	nop
	mov a, 0x01
rx_next_bit:
	ifset PA.JD_D
		or rx_data, a
	sl a
	ifset ZF
		goto rx_lastbit
	nop
	goto rx_next_bit
rx_lastbit:
	// a==0 here
	mov TM2CT, a
	xch rx_data    		// this clears rx_data for next round
	idxm memidx, a   	// 2T
	dzsn rx_buflimit    // rx_buflimit--
	inc memidx$0    	// when rx_buflimit reaches 0, we stop incrementing memidx
	ifset ZF          	// if rx_buflimit==0
	  inc rx_buflimit   //     rx_buflimit++ -> keep rx_buflimit at 0
	nop
	goto rx_wait_start


timeout:
	// this is nested IRQ; we want to return to original code, not outer interrupt
	// TODO: try fake popaf
	mov a, SP
	sub a, 2
	mov SP, a
leave_irq:
	// save crc_l/h for future comparison
	.mova rx_byte, crc_l
	.mova isr2, crc_h
	mov a, 0xff
	mov crc_l, a
	mov crc_h, a
	.mova memidx$0, pkt_addr+2
	mov a, frm_sz
	add a, 10
	call crc16 // uses isr0,1

	call t16_sync

	mov a, crc_l
	ifneq a, rx_byte
	  goto pkt_error
	mov a, crc_h
	ifneq a, isr2
	  goto pkt_error

	.mova isr0, frm_flags
	ifclear isr0.JD_FRAME_FLAG_COMMAND
	  goto not_interested // this is a report
	ifset isr0.JD_FRAME_FLAG_VNEXT
	  goto pkt_error

    .check_id not_interested // uses isr0, isr1

	mov a, frm_sz
	sub a, buffer_size-frame_header_size+1
	ifclear CF
	  goto pkt_error // it was a packet for us, but it was too large


.include rxctrl.asm

	ifclear isr0.JD_FRAME_FLAG_ACK_REQUESTED
	  goto no_ack_needed
	set1 tx_pending.txp_ack
	.mova ack_crc_l, crc_l
	.mova ack_crc_h, crc_h

no_ack_needed:

// JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS

not_interested:
_do_leave:
	set0 flags.f_in_rx
	.mova TM2CT, 0
	$ TM2S 8BIT, /1, /1
	set1 flags.f_set_tx
	popaf
	reti

pkt_overflow:
pkt_invalid:
pkt_error:
	PA.JD_TM = 1
	PA.JD_TM = 0
	goto _do_leave

