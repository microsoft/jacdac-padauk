#define SERVICE_CLASS 0x17dc9a1c
#define SENSOR_SIZE 2

txp_variant equ 6

	BYTE	t_sample

	.sensor_impl

.serv_init EXPAND
	.mova streaming_interval, 20
ENDM

.serv_process EXPAND
	.t16_chk t16_1ms, t_sample, <goto do_light_sample>
	.sensor_process
ENDM

.serv_prep_tx MACRO
	if (tx_pending.txp_variant) {
		set0 tx_pending.txp_variant
		.mova pkt_payload[0], 3 // Ambient
		.mova pkt_size, 1
		.mova pkt_service_command_l, JD_REG_RO_VARIANT
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

	mov sensor_state[0], a

	$ ADCC Disable

	goto loop

serv_rx:
	mov a, pkt_service_command_h
	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l
		if (a == JD_REG_RO_VARIANT) {
			set1 tx_pending.txp_variant
		}
	}
	.sensor_rx

