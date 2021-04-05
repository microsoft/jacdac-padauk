IDSIZE equ 8

.fill_id MACRO
	a = packet_buffer+4+IDSIZE-1
	mov lb@memidx, a
	.mova isr0, IDSIZE
@@:
	mov a, isr0
	call get_id
	idxm memidx, a
	dec lb@memidx
	dzsn isr0
	goto @B
	ret
ENDM

.check_id MACRO fail_lbl
	a = packet_buffer+4+IDSIZE-1
	mov lb@memidx, a
	.mova isr0, IDSIZE
@@:
	mov a, isr0
	call get_id
	mov isr1, a
	idxm a, memidx
	ceqsn a, isr1
	goto fail_lbl
	dec lb@memidx
	dzsn isr0
	goto @B
ENDM

// requires a=1...8
get_id:
	pcadd a
.IFDEF RELEASE
	.User_Roll 12 BYTE, "genid.bat", "ids.txt"
.ELSE
	ret 0x01
	ret 0x23
	ret 0x45
	ret 0x67
	ret 0x89
	ret 0xab
	ret 0xcd
	ret 0xef

	// note that these two CRCs always differ by XOR 0xe77e regardless of device id
	// this can possibly be used in future to only store one of them
	ret 0x16 // crc of 0400 0123456780abcdef
	ret 0x2e
	ret 0xf1 // crc of 0800 0123456780abcdef
	ret 0x50
	ret 0x65 // crc of 0c00 ...
	ret 0x5c
.ENDIF
