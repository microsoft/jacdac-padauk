#define SERVICE_CLASS 0x1acb1890
#define SENSOR_SIZE 4

	BYTE	t_sample
	BYTE    adc_tmp

	.sensor_impl

.serv_init EXPAND
	.mova streaming_interval, 20
ENDM

.serv_process EXPAND
	.t16_chk t16_1ms, t_sample, <goto do_joy_sample>
	.sensor_process
ENDM

.serv_prep_tx MACRO
	.sensor_prep_tx
ENDM

do_joy_sample:
	.t16_set t16_1ms, t_sample, 20

	$ ADCM 8BIT, /16

	$ ADCC Enable, PIN_JOY_X_ADC
	AD_START = 1
	while (!AD_DONE) {}
	mov a, ADCR
	sub a, 127
	mov adc_tmp, a

	$ ADCC Enable, PIN_JOY_Y_ADC
	AD_START = 1
	while (!AD_DONE) {}
	mov a, ADCR
	sub a, 127

	.disint
		mov sensor_state[2], a
		.mova sensor_state[0], adc_tmp
	engint

	$ ADCC Disable

	goto loop

serv_rx:
	.sensor_rx
