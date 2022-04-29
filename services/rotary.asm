#define SERVICE_CLASS 0x10fa29c9
#define SENSOR_SIZE 4

#define JD_ROTARY_ENCODER_REG_RO_CLICKS_PER_TURN 0x80
#define JD_ROTARY_ENCODER_REG_RO_CLICKER 0x81

#ifndef CLICKS_PER_TURN
#define CLICKS_PER_TURN 20
#endif

txp_clicks_per_turn equ txp_serv0
txp_clicker equ txp_serv1

	BYTE	rot_state
	BYTE    t_sample

	BYTE    int_state[4]
	
	.sensor_impl

.serv_init EXPAND
	PIN_ROT_A_PH = 1
	PIN_ROT_B_PH = 1
	.mova streaming_interval, 100
ENDM

.serv_process EXPAND
	.t16_chk t16_4us, t_sample, <goto do_sample>
	.sensor_process
ENDM

.serv_prep_tx EXPAND
	if (txp_clicker) {
		set0 txp_clicker
		clear pkt_payload[0]
		.mova pkt_size, 1
		.set_ro_reg JD_ROTARY_ENCODER_REG_RO_CLICKER
		ret
	}

	if (txp_clicks_per_turn) {
		set0 txp_clicks_per_turn
		.mova pkt_payload[0], CLICKS_PER_TURN
		.mova pkt_size, 2
		.set_ro_reg JD_ROTARY_ENCODER_REG_RO_CLICKS_PER_TURN
		ret
	}

	.sensor_prep_tx
ENDM

.asl4 MACRO m
	// move sign bit to CF
	mov a, m[3]
	sl a
	// shift
	src m[3]
	src m[2]
	src m[1]
	src m[0]
ENDM

do_sample:
	.t16_set t16_4us, t_sample, 50

	mov a, rot_state
	and a, 3
	ifset PIN_ROT_A
		or a, 4
	ifset PIN_ROT_B
		or a, 8
	mov rot_state, a
	sr rot_state
	sr rot_state
	sl a
	add a, 1
	pcadd a
.for v, <0, +1, -1, +2, -1, 0, -2, +1, +1, -2, 0, -1, +2, -1, +1, 0>
	mov a, v
	goto sel_done
.endm
sel_done:
	add int_state[0], a
	and a, 0x80
	ifclear ZF
		mov a, 0xff
	addc int_state[1], a
	addc int_state[2], a
	addc int_state[3], a

	// sensor_state = int_state >> 2 (signed)
	.disint
		.mova sensor_state[0], int_state[0]
		.mova sensor_state[1], int_state[1]
		.mova sensor_state[2], int_state[2]
		.mova sensor_state[3], int_state[3]
		.asl4 sensor_state
		.asl4 sensor_state
	engint

	goto loop

serv_rx:
	mov a, pkt_service_command_h
	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l
		.reg_cmp JD_ROTARY_ENCODER_REG_RO_CLICKS_PER_TURN, txp_clicks_per_turn
		.reg_cmp JD_ROTARY_ENCODER_REG_RO_CLICKER, txp_clicker
	}
	.sensor_rx

