#define SERVICE_CLASS 0x1e6ecaf2
#define SENSOR_SIZE 4

#define READING_ERROR 1

	BYTE	tmp, adc_rd, lx_mul

.serv_init EXPAND
	.mova streaming_interval, 20
ENDM

.analog_reading_error EXPAND
	pkt_payload[0] = 0
	pkt_payload[1] = LX_ERROR & 0xff
	pkt_payload[2] = (LX_ERROR >> 8) & 0xff
	pkt_size = 4
ENDM


.analog_reading EXPAND
	mov adc_rd, a
	.mova lx_mul, LX_MULT
	.mul_8x8 tmp, sensor_state[1], sensor_state[2], adc_rd, lx_mul
ENDM

.include analog.asm