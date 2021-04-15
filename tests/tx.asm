#define tx_data isr1
#define tx_cntdown isr2

switch_to_rx:
	call interrupt
	goto loop

try_tx:
	.disint
	// if f_set_tx is set, it means there was a reception interrupt very recently
	// in that case we shall try tx later
	if (flags.f_set_tx) {
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
