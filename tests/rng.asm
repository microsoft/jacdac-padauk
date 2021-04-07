.rng_init EXPAND
	$ TM2S 8BIT, /1, /1
	TM2B = 2
	$ TM2C ILRC
	INTRQ = 0x00
	mov a, 7
	call get_id
	mov rng_x, a // start seeding with 7th byte of device ID
	.mova isr0, 37
_rng_byte:
	mov a, 0
	INTRQ.TM2 = 0
@@:
	add a, 1
	ifclear INTRQ.TM2
	  goto @b
	xor a, rng_x
	sl a
	ifset CF
	  or a, 0x01
	mov rng_x, a
	dzsn isr0
	goto _rng_byte
	mov a, rng_x
	mov rng_x, a
ENDM

.rng_add_entropy EXPAND
	mov a, t16_4us
	xor rng_x, a
ENDM

/*
This has period of 255 (so  we just exclude 0)
	x ^= x << 1
	x ^= x >> 1
	x ^= x << 2
*/
.rng_next EXPAND
	mov a, rng_x
	ifset ZF // this can happen when we "add entropy"
		mov a, 42
	sl x
	xor rng_x, a
	mov a, rng_x
	sr a
	xor rng_x, a
	mov a, rng_x
	sl a
	sl a
	xor rng_x, a
	mov a, rng_x
ENDM