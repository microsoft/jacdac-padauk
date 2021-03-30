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

.clear_memory MACRO
	.mova lb@memidx, _SYS(SIZE.RAM)-1
	clear hb@memidx
	mov a, 0x00
clear_loop:
	idxm memidx, a
	dzsn lb@memidx
	goto clear_loop
ENDM
