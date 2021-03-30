/*
uint16_t jd_crc16(const void *data, uint32_t size) {
    const uint8_t *ptr = (const uint8_t *)data;
    uint16_t crc = 0xffff;
    while (size--) {
        uint8_t data = *ptr++;
        uint8_t x = (crc >> 8) ^ data;
        x ^= x >> 4;
        crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x;
    }
    return crc;
}
 */

	BYTE crc_l
	BYTE crc_h

// ~27 cycles per byte
crc16:
	mov tmp0, a // length
	mov a, 0xff
	mov crc_l, a
	mov crc_h, a
crc16_loop:
	// uint8_t data = *ptr++;
	idxm a, memidx
	inc lb@memidx
	// uint8_t x = (crc >> 8) ^ data;
	xor a, crc_h
	mov tmp1, a
	// x ^= x >> 4;
	swap a
	and a, 0x0f
	xor tmp1, a // tmp1==x	
	// crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x; =>
	// crc_h = crc_l ^ (x << 4) ^ (x >> 3)
	mov a, tmp1
	swap a
	and a, 0xf0
	xor a, crc_l
	mov crc_h, a
	mov a, tmp1
	sr a
	sr a
	sr a
	xor crc_h, a
	// crc_l = (x << 5) ^ x
	.mova crc_l, tmp1
	swap a
	and a, 0xf0
	sl a
	xor crc_l, a
	// loop back
	dzsn tmp0
	goto crc16_loop
	ret
