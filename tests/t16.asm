#define t16_4us t16_low$0
#define t16_1ms t16_low$1

.t16_chk MACRO t16_v, tim, handler
	mov a, t16_v
	sub a, tim
	and a, 0x80
	ifset ZF
		handler
ENDM

.t16_set MACRO t16_v, tim, num
	mov a, t16_v
	add a, num
	mov tim, a
ENDM

.t16_init EXPAND
t16_init_:
	stt16 t16_low
	$ INTEGS BIT_F // falling edge on T16
	$ T16M IHRC, /64, BIT15
ENDM


.t16_impl EXPAND
t16_sync:
	ldt16 t16_low
	if (INTRQ.T16) {
		INTRQ.T16 = 0
		inc t16_262ms
#ifdef CFG_T16_32BIT
		addc t16_67s
#endif
	}
	mov a, t16_1ms
	swap a
	and a, 0x0f
	mov t16_16ms, a
	mov a, t16_262ms
	swap a
	and a, 0xf0
	or t16_16ms, a
	ret
ENDM
