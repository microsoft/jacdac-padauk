#define tx_data isr1
#define tx_cntdown isr2

try_tx:
	disgint
	ifclear PA.JD_D
	  goto interrupt // we got conflict on initial break - try rx in irq handler
	PA.JD_D = 0 // set lo
	PAC.JD_D = 1 // set to output

	.fill_id // uses isr0

	PA.JD_D = 1

	call reset_tm2
	$ TM2S 8BIT, /1, /6 // ~50us

	call prep_tx // ~20-~50 cycles

	mov a, pkt_size
	add a, 3+4 // add pkt-header size + round up to word
	and a, 0b1111_1100
	mov frm_sz, a // frm_sz == 4 || 8 || 12
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

	.mova memidx$0, pkt_addr
	mov a, frame_header_size+1
	add a, frm_sz
	mov tx_cntdown, a

@@:
	t1sn INTRQ.TM2
	goto @b

	goto _stop

tx_not_last:
	PA.JD_D = 0
	mov a, 8
	nop
_nextbit:	
	sr tx_data
	ifset CF
	  goto _bit1
	nop
	PA.JD_D = 0
	dzsn a
	goto _nextbit
	goto _stop

_bit1:
	PA.JD_D = 1
	dzsn a
	goto _nextbit
	goto _stop

_stop:
	idxm a, memidx // 2T
	mov tx_data, a
	inc memidx$0
	PA.JD_D = 1
	nop
	nop
	nop
	nop
	dzsn tx_cntdown
		goto tx_not_last
tx_last:
	PA.JD_D = 0
	.delay 90
	PA.JD_D = 1
	PAC.JD_D = 0 // set to input
	PAPH.JD_D = 1
	call reset_tm2
	engint
	goto loop
