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
	.mova memidx$0, _SYS(SIZE.RAM)-1
	clear memidx$1
	mov a, 0x00
clear_loop:
	idxm memidx, a
	dzsn memidx$0
	goto clear_loop
ENDM

.disint MACRO
	// apparently when you get INT during disgint execution, it may not work
	.disgint
ENDM

.assert_not MACRO cond
	ifset cond
		call panic
ENDM

.assert MACRO cond
	ifclear cond
		call panic
ENDM


/*
The if* macros below are used to resemble 'if' statements:

  ifset some.bit
    do_something

the do_something is exactly one instruction.
 */
 
ifset MACRO flag
	t0sn flag
ENDM

ifclear MACRO flag
	t1sn flag
ENDM

ifneq MACRO x, y
	ceqsn x, y
ENDM
