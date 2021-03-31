	BYTE rng_x, rng_y, rng_z, rng_a

	// we init a==0
	// the only init with a==0 that results in 127-cycle is 63,45,24,0
	// we also avoid 0,0,0,0
.rng_init MACRO
	call _rng_hw_byte
	cneqsn a, 63
	add a, 1
	mov rng_x, a
	call _rng_hw_byte
	cneqsn a, 0
	add a, 1
	mov rng_y, a
	call _rng_hw_byte
	mov rng_z, a
	clear rng_a
ENDM

_rng_hw_byte:
	$ TM2S 8BIT, /1, /1
	TM2B = 2
	$ TM2C ILRC
	INTRQ = 0x00
	clear tmp1
	.mova tmp0, 37
_rng_byte:
	mov a, 0
	INTRQ.TM2 = 0
@@:
	add a, 1
	t1sn INTRQ.TM2
	goto @b
	xor a, tmp1
	sl a
	t0sn CF
	or a, 0x01
	mov tmp1, a
	dzsn tmp0
	goto _rng_byte
	mov a, tmp1
	ret

	// based on https://github.com/edrosten/8bit_rng/blob/master/rng-4261412736.c
rng_next:
	mov a, rng_x
	mov tmp0, a
	swap a
	and a, 0xf0
	xor tmp0, a
	.mova rng_x, rng_y
	.mova rng_y, rng_z
	.mova rng_z, rng_a
	// a==rng_z==rng_a here
	sr a
	xor rng_a, a // rng_a=z^(z>>1)
	mov a, tmp0
	xor rng_a, a
	sl a
	xor rng_a, a
	mov a, rng_a
	ret
