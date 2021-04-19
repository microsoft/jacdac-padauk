#define JD_FRAME_FLAG_COMMAND 0
#define JD_FRAME_FLAG_ACK_REQUESTED 1
#define JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS 2
#define JD_FRAME_FLAG_VNEXT 7

#define JD_AD0_ACK_SUPPORTED 0x01
#define JD_AD0_IDENTIFIER_IS_SERVICE_CLASS_SUPPORTED 0x02
#define JD_AD0_FRAMES_SUPPORTED 0x04
#define JD_AD0_IS_CLIENT 0x08

#define JD_AD0_IS_CLIENT_MSK 0x08

#define JD_HIGH_CMD 0x00
#define JD_HIGH_REG_RW_SET 0x20
#define JD_HIGH_REG_RW_GET 0x10
#define JD_HIGH_REG_RO_GET 0x11

#define JD_CONTROL_CMD_IDENTIFY 0x81
#define JD_CONTROL_CMD_RESET 0x82
#define JD_CONTROL_CMD_SET_STATUS_LIGHT 0x84

#define JD_CONTROL_REG_RW_RESET_IN 0x80

#define JD_REG_RW_STREAMING_SAMPLES 0x03
#define JD_REG_RW_STREAMING_INTERVAL 0x04
#define JD_REG_RO_READING 0x01
#define JD_REG_RO_VARIANT 0x07

frame_header_size equ 12
crc_size equ 2
payload_size equ 8
buffer_size equ (frame_header_size + 4 + payload_size)

f_in_rx equ 0
f_set_tx equ 1
f_reset_in equ 2
f_ev1 equ 3
f_ev2 equ 4
f_announce_t16_bit equ 5
f_announce_rst_cnt_max equ 6
// 7 free for services

txp_announce equ 0
txp_ack equ 1
txp_event equ 2
// 3-5 used by sensor.asm

pkt_addr equ 12

.include utils.asm
.include t16.asm
.include rng.asm
.include blink.asm

	.ramadr 0x00
	WORD    memidx
	BYTE    flags
	BYTE    tx_pending
	BYTE	isr0, isr1, isr2

	BYTE    blink

	WORD    t16_low
	BYTE	t16_16ms
	BYTE    t16_262ms

	.ramadr pkt_addr
	BYTE	crc_l, crc_h
	BYTE	frm_sz
	BYTE    frm_flags

	BYTE    pkt_device_id[8]

	// actual tx packet
	BYTE	pkt_size
	BYTE	pkt_service_number
	BYTE	pkt_service_command_l
	BYTE	pkt_service_command_h
	BYTE	pkt_payload[payload_size]
	BYTE	rx_data // this is overwritten during rx if packet too long (but that's fine)
	BYTE    rng_x

	// so far:
	// application is not using stack when IRQ enabled
	// rx ISR can do up to 3
	WORD	main_st[3]

	BYTE    ack_crc_l, ack_crc_h
	BYTE    t_tx

#ifdef CFG_T16_32BIT
	BYTE    t16_67s
#endif

#ifdef CFG_RESET_IN
	BYTE    t_reset
#endif

	// more data defined in rxserv.asm

	goto	main

	.include rx.asm
	.include crc16.asm
	.include tx.asm
