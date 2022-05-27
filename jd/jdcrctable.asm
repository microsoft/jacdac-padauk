crc_offset:
    add a, 1
    pcadd a
    ret 0x00  // 0
    ret 0x00
    ret 0x45  // 1
    ret 0x6f
    ret 0x8a  // 2
    ret 0xde
    ret 0xcf  // 3
    ret 0xb1
    ret 0x7e  // 4
    ret 0xe7
    ret 0x3b  // 5
    ret 0x88
    ret 0xf4  // 6
    ret 0x39
    ret 0xb1  // 7
    ret 0x56
    ret 0x4b  // 8
    ret 0x4a
#if PAYLOAD_SIZE > 8
    ret 0x0e  // 9
    ret 0x25
    ret 0xc1  // 10
    ret 0x94
    ret 0x84  // 11
    ret 0xfb
    ret 0xa3  // 12
    ret 0x39
#endif
#if PAYLOAD_SIZE > 12
    ret 0xe6  // 13
    ret 0x56
    ret 0x29  // 14
    ret 0xe7
    ret 0x6c  // 15
    ret 0x88
    ret 0x96  // 16
    ret 0x94
#endif
#if PAYLOAD_SIZE > 16
    ret 0xd3  // 17
    ret 0xfb
    ret 0x1c  // 18
    ret 0x4a
    ret 0x59  // 19
    ret 0x25
    ret 0xe8  // 20
    ret 0x73
#endif
#if PAYLOAD_SIZE > 20
    ret 0xad  // 21
    ret 0x1c
    ret 0x62  // 22
    ret 0xad
    ret 0x27  // 23
    ret 0xc2
    ret 0xdd  // 24
    ret 0xde
#endif
#if PAYLOAD_SIZE > 24
    ret 0x98  // 25
    ret 0xb1
    ret 0x57  // 26
    ret 0x00
    ret 0x12  // 27
    ret 0x6f
    ret 0x38  // 28
    ret 0x94
#endif
#if PAYLOAD_SIZE > 28
    ret 0x7d  // 29
    ret 0xfb
    ret 0xb2  // 30
    ret 0x4a
    ret 0xf7  // 31
    ret 0x25
    ret 0x0d  // 32
    ret 0x39
#endif
#if PAYLOAD_SIZE > 32
    ret 0x48  // 33
    ret 0x56
    ret 0x87  // 34
    ret 0xe7
    ret 0xc2  // 35
    ret 0x88
    ret 0x73  // 36
    ret 0xde
#endif
#if PAYLOAD_SIZE > 36
    ret 0x36  // 37
    ret 0xb1
    ret 0xf9  // 38
    ret 0x00
    ret 0xbc  // 39
    ret 0x6f
    ret 0x46  // 40
    ret 0x73
#endif
#if PAYLOAD_SIZE > 40
#error "more CRC needed!"
#endif
