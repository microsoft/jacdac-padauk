#define t16_v0 lb@t16_low
#define t16_v1 hb@t16_low
#define t16_v2 lb@t16_high
#define t16_v3 hb@t16_high

t16_chk MACRO t16_v, tim, handler
	mov a, t16_v
	sub a, tim
	and a, 0x80
	cneqsn a, 0x00
	call handler
ENDM

t16_set MACRO t16_v, tim, num
	mov a, t16_v
	add a, num
	mov tim, a
ENDM

t16_init MACRO
	WORD    t16_low
	WORD    t16_high
t16_init_:
	stt16 t16_low
	$ INTEGS BIT_F ; falling edge on T16
	$ T16M IHRC, /64, BIT15
ENDM


t16_impl MACRO
t16_sync:
	ldt16 t16_low
	t1sn INTRQ.T16
	ret
	INTRQ.T16 = 0
	inc lb@t16_high
	addc hb@t16_high
	ret
ENDM
