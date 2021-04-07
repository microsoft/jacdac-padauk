#define tx_data isr1
#define tx_cntdown isr2

try_tx:
	disgint
	ifclear PA.JD_D
	  goto interrupt // we got conflict on initial break - try rx in irq handler
	PA.JD_D = 0 // set lo
	PAC.JD_D = 1 // set to output

	.delay 90

	PA.JD_D = 1

	call prep_tx // ~20-~50 cycles

	.fill_id // uses isr0

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

	.mova memidx$0, pkt_addr+12
	mov a, frm_sz // len
	call crc16 // uses isr0, isr1

	.delay 150 // TODO - use t16 or tm2 to wait the right amount always

	.mova memidx$0, pkt_addr
	mov a, 12
	add a, frm_sz
	mov tx_cntdown, a
	goto _stop

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
	.delay 10
	PA.JD_D = 0 // set lo
	dzsn tx_cntdown
		goto tx_not_last
	.delay 90
	PA.JD_D = 1
	PAC.JD_D = 0 // set to input
	PAPH.JD_D = 1
	set1 flags.f_set_tx
	engint
	goto loop

tx_not_last:
	mov a, 8
	goto _nextbit
