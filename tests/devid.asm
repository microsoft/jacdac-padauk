IDSIZE equ 8

.fill_id MACRO
	a = pkt_addr+4+IDSIZE-1
	mov memidx$0, a
	.mova isr0, IDSIZE
@@:
	mov a, isr0
	call get_id
	idxm memidx, a
	dec memidx$0
	dzsn isr0
	goto @B
ENDM

.check_id MACRO fail_lbl
	a = pkt_addr+4+IDSIZE-1
	mov memidx$0, a
	.mova isr0, IDSIZE
@@:
	mov a, isr0
	call get_id
	mov isr1, a
	idxm a, memidx
	ifneq a, isr1
	  goto fail_lbl
	dec memidx$0
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
	ret 0x59 // crc of 0400 0123456789abcdef
	ret 0xe5
	ret 0x27 // crc of 0800 0123456789abcdef
	ret 0x02
	ret 0x12 // crc of 0c00 0123456789abcdef
	ret 0xaf
.ENDIF
