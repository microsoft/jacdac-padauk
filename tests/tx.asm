try_tx:
	disgint
	t1sn PA.JD_D
	goto interrupt // we got conflict on initial break - try rx in irq handler
	PA.JD_D = 0 // set lo
	PAC.JD_D = 1 // set to output

	.fill_id // this is about 100 cycles
	PA.JD_D = 1

	.mova tmp0, 8
	a = packet_buffer + 12
	mov lb@memidx, a
	a = tx_buffer
	mov lb@memidx2, a
tx_copy:
	idxm a, memidx2
	idxm memidx, a
	inc lb@memidx
	inc lb@memidx2
	dzsn tmp0
	goto tx_copy

	clear packet_buffer[3] // clear flags
	
// lb@memidx - idx
	mov a, tmp0
	sr a
	sr a
	add a, 1
	pcadd a
	goto tx_hd
	goto tx_id
	goto tx_payload
	goto tx_payload

tx_hd:
	mov a, tmp0
	add a, hd_loc
	mov lb@memidx, a
	idxm a, lb@memidx
	goto ...

tx_id:
	mov a, tmp0
	sub a, 4
	call get_id
	goto ...

// 15-18 cycles to get byte

