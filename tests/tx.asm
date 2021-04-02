#define tx_idx tmp0
#define tx_data tmp1
#define tx_cntdown tmp2

// TODO we actually need to send up to 8 bytes (control announce), not up to 4

try_tx:
	disgint
	t1sn PA.JD_D
	goto interrupt // we got conflict on initial break - try rx in irq handler
	PA.JD_D = 0 // set lo
	PAC.JD_D = 1 // set to output

	// frm_sz fixed to either 4 or 8 (0 or up to 4 bytes of payload)
	mov a, tx_size
	mov a, 4
	t1sn ZF // ZF set by a:=tx_size
	mov a, 8 // if tx_size!=0 a:=8
	mov frm_sz, a
	sr a // a=2 || a=4
	add a, 7
	call get_id
	mov crc_l, a
	mov a, frm_sz
	sr a // a=2 || a=4
	add a, 8
	call get_id
	mov crc_h, a
	// -- 24 cycles

	.mova lb@memidx, tx_addr+12
	.mova tmp0, frm_sz

	.delay 90-28

	PA.JD_D = 1

	call crc16_loop // ~108 cycles for tx_size==0, ~216 otherwise

	mov a, tx_size
	mov a, 100
	t1sn ZF
	mov a, 67 // if tx_size!=0 a:=67
	// delay is 3*a cycles
@@:
	dzsn a
	goto @b
	// need around 400 cycles delay until first start bit

	clear tx_idx
	mov a, 12
	add a, frm_sz
	mov tx_cntdown, a
	goto _stop

_nextbit:	
	sr tx_data
	t0sn CF
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
	goto tx_hd
	goto tx_hd

tx_hd:
	mov a, tx_idx
	add a, tx_addr
	mov lb@memidx, a
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
	goto tx_last
	PA.JD_D = 0
	mov tx_data, a
	goto _nextbit

tx_last:
	// TODO brk
	engint
	ret