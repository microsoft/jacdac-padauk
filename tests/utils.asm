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

.set_log MACRO v
#ifdef PIN_LOG
	PA.PIN_LOG = v
#endif
ENDM

.pulse_log MACRO
	.set_log 1
	.set_log 0
ENDM

/*
The if* macros below are used to resemble 'if' statements:

  ifset some.bit
      do_something

the do_something is exactly one instruction.

You can also write:

  if (some.bit) {
	  do_something
  }

but it's not optimal when do_something is a single instruction.
 */

#define ifset t0sn
#define ifclear t1sn
#define ifneq ceqsn

// t0:t1 = x * y (unsigned); doesn't change y
// ~12 instr.; ~90T
.mul_8x8 EXPAND tmp, t0, t1, x, y 
	clear t1
	.mova tmp, 8
@@:
	sr x
	if (CF) {
		mov a, y
		add t1, a
	}
	src t1
	src t0
	dzsn tmp
	goto @b
ENDM

.on_rising MACRO shadow, test, trg
	if (shadow) {
		ifclear test
			set0 shadow
	} else {
		if (test) {
			set1 shadow
			trg
		}
	}
ENDM

