#define tx_idx isr0
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
	.mova crc_len, frm_sz
	call crc16_loop // uses isr0, isr1

	.delay 150 // TODO - use t16 to wait the right amount always

	clear tx_idx
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
	mov a, tx_idx
	sr a
	sr a
	add a, 1
	PA.JD_D = 1
	pcadd a
	goto tx_hd
	goto tx_id
	goto tx_id
	goto tx_hd
	goto tx_hd

tx_hd:
	mov a, tx_idx
	add a, pkt_addr
	mov memidx$0, a
	idxm a, memidx
	// -- 9
	goto tx_hd_id

tx_id:
	mov a, tx_idx
	sub a, 3
	call get_id
	// -- 12
tx_hd_id:
	inc tx_idx
	dzsn tx_cntdown
	goto tx_not_last
	goto tx_last

tx_not_last:
	mov tx_data, a
	PA.JD_D = 0
	mov a, 8
	goto _nextbit

tx_last:
	PA.JD_D = 0 // set lo
	.delay 90
	PA.JD_D = 1
	PAC.JD_D = 0 // set to input
	PAPH.JD_D = 1
	set1 flags.f_set_tx
	engint
	goto loop
