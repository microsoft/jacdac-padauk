#define tx_idx isr0
#define tx_data isr1
#define tx_cntdown isr2

try_tx:
	disgint
	ifclear PA.JD_D
	  goto interrupt // we got conflict on initial break - try rx in irq handler
	PA.JD_D = 0 // set lo
	PAC.JD_D = 1 // set to output

	// frm_sz fixed to either 4 or 8 (0 or up to 4 bytes of payload)
	mov a, tx_size
	add a, 3+4
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
	
	clear frm_flags

	.delay 90-20

	PA.JD_D = 1

	// ~27 cycles per byte
	.mova lb@memidx, tx_addr+12
	.mova crc_len, frm_sz
	call crc16_loop // uses isr0, isr1
	mov a, frm_sz
	sl a
	sl a
	sl a
	neg a // frm_sz*8 3cycles =~ 24 cycles per byte (less than 27 but ...)
	add a, 133 // 133 3cycles = 400 cycles

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
	set0 flags.f_has_tx
	engint
	goto loop
