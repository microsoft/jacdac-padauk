#ifndef SAMPLING_MS
#define SAMPLING_MS 20
#endif

#ifdef VARIANT
txp_variant equ txp_serv0
#endif

#ifdef READING_ERROR
txp_reading_error equ txp_serv1
#endif

	BYTE	t_sample

	.sensor_impl

.serv_process EXPAND
	.t16_chk t16_1ms, t_sample, <goto do_analog_sample>
	.sensor_process
ENDM

.serv_prep_tx EXPAND
#ifdef VARIANT
	if (txp_variant) {
		set0 txp_variant
		.mova pkt_payload[0], VARIANT
		.mova pkt_size, 1
		.set_ro_reg JD_REG_RO_VARIANT
		ret
	}
#endif

#ifdef READING_ERROR
	if (txp_reading_error) {
		set0 txp_reading_error
		.analog_reading_error
		.set_ro_reg JD_REG_RO_READING_ERROR
		ret
	}
#endif

	.sensor_prep_tx
ENDM

do_analog_sample:
	.t16_set t16_1ms, t_sample, SAMPLING_MS

#ifdef PIN_ANALOG_PWR
	PAC.PIN_ANALOG_PWR = 1
	PA.PIN_ANALOG_PWR = 1
	.delay 1000
#endif

	$ ADCM 8BIT, /16

	$ ADCC Enable, PIN_ADC
	AD_START = 1
	while (!AD_DONE) {}
	mov a, ADCR

	.analog_reading

	$ ADCC Disable

#ifdef PIN_ANALOG_PWR
	PAC.PIN_ANALOG_PWR = 0
	PA.PIN_ANALOG_PWR = 0
#endif


	goto loop

serv_rx:
	mov a, pkt_service_command_h
	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l
#ifdef VARIANT
		if (a == JD_REG_RO_VARIANT) {
			set1 txp_variant
			goto rx_process_end
		}
#endif
#ifdef READING_ERROR
		if (a == JD_REG_RO_READING_ERROR) {
			set1 txp_reading_error
			goto rx_process_end
		}
#endif
	}
	.sensor_rx

