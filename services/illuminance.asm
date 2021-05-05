#define SERVICE_CLASS 0x1e6ecaf2
#define SENSOR_SIZE 4

txp_reading_error equ 6

	BYTE	t_sample
	BYTE	tmp, adc_rd, lx_mul

	.sensor_impl

.serv_init EXPAND
	.mova streaming_interval, 20
ENDM

.serv_process EXPAND
	.t16_chk t16_1ms, t_sample, <goto do_light_sample>
	.sensor_process
ENDM

.serv_prep_tx MACRO
	if (tx_pending.txp_reading_error) {
		set0 tx_pending.txp_reading_error
		// this assumes error is 1/256 of reading
		.mova pkt_payload[0], sensor_state[1]
		.mova pkt_payload[1], sensor_state[2]
		.mova pkt_payload[2], sensor_state[3]
		// which is unlikely, so we quadruple it
		.forc x, <01>
			sl pkt_payload[0]
			slc pkt_payload[1]
			slc pkt_payload[2]
			slc pkt_payload[3]
		.endm
		.mova pkt_size, 4
		.mova pkt_service_command_l, JD_REG_RO_READING_ERROR
		ret
	}

	.sensor_prep_tx
ENDM

do_light_sample:
	.t16_set t16_1ms, t_sample, 20

	$ ADCM 8BIT, /16

	$ ADCC Enable, PIN_ADC
	AD_START = 1
	while (!AD_DONE) {}
	mov a, ADCR

	mov adc_rd, a
	.mova lx_mul, LX_MULT
	.mul_8x8 tmp, sensor_state[1], sensor_state[2], adc_rd, lx_mul

	$ ADCC Disable

	goto loop

serv_rx:
	mov a, pkt_service_command_h
	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l
		if (a == JD_REG_RO_READING_ERROR) {
			set1 tx_pending.txp_reading_error
		}
	}
	.sensor_rx

