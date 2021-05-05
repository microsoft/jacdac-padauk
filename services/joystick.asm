#define SERVICE_CLASS 0x108f7456
#define SENSOR_SIZE 8
#define BTN_STATE <0>

#define JD_JOYSTICK_BUTTONS_LEFT 0x1
#define JD_JOYSTICK_BUTTONS_UP 0x2
#define JD_JOYSTICK_BUTTONS_RIGHT 0x4
#define JD_JOYSTICK_BUTTONS_DOWN 0x8
#define JD_JOYSTICK_BUTTONS_A 0x10
#define JD_JOYSTICK_BUTTONS_B 0x20
#define JD_JOYSTICK_BUTTONS_MENU 0x40
#define JD_JOYSTICK_BUTTONS_SELECT 0x80

#define JD_JOYSTICK_REG_RO_BUTTONS_AVAILABLE 0x80


	BYTE	t_sample
	BYTE    adc_tmp
	BYTE    prev_btn[1]

txp_avail_buttons equ 6

	.sensor_impl

.serv_init EXPAND
	.mova streaming_interval, 20
ENDM

.serv_process EXPAND
	.ev_process
	.t16_chk t16_1ms, t_sample, <goto do_joy_sample>
	.sensor_process
ENDM

.serv_prep_tx MACRO
	if (tx_pending.txp_avail_buttons) {
		set0 tx_pending.txp_avail_buttons
		.mova pkt_payload[0], <JD_JOYSTICK_BUTTONS_A>
		.mova pkt_size, 4
		.mova pkt_service_command_l, JD_JOYSTICK_REG_RO_BUTTONS_AVAILABLE
		ret
	}

	ifset tx_pending.txp_event
		goto ev_prep_tx
	.sensor_prep_tx
ENDM

do_joy_sample:
	.t16_set t16_1ms, t_sample, 20

#ifdef PIN_JOY_SINK
	PAC.PIN_JOY_SINK = 1
	PA.PIN_JOY_SINK = 0
	.delay 100
#endif

	$ ADCM 8BIT, /16

	$ ADCC Enable, PIN_JOY_X_ADC
	AD_START = 1
	while (!AD_DONE) {}
	mov a, ADCR
#ifdef JOY_X_OFF_POS
	add a, JOY_X_OFF_POS
	ifset CF
		mov a, 255
#endif
#ifdef JOY_X_OFF_NEG
	sub a, JOY_X_OFF_NEG
	ifset CF
		mov a, 0
#endif
	sub a, 128
	mov adc_tmp, a

	$ ADCC Enable, PIN_JOY_Y_ADC
	AD_START = 1
	while (!AD_DONE) {}
	mov a, ADCR
#ifdef JOY_Y_OFF_POS
	add a, JOY_Y_OFF_POS
	ifset CF
		mov a, 255
#endif
#ifdef JOY_Y_OFF_NEG
	sub a, JOY_Y_OFF_NEG
	ifset CF
		mov a, 0
#endif
	sub a, 127
	neg a

	.disint
		mov sensor_state[3+4], a
		.mova sensor_state[1+4], adc_tmp
	engint

	$ ADCC Disable

	.forc i, BTN_STATE
		.mova prev_btn[i], sensor_state[i]
		clear sensor_state[i]
	.endm
	.joystick_button_probe

#ifdef PIN_JOY_SINK
	//PA.PIN_JOY_SINK = 1
	PAC.PIN_JOY_SINK = 0
#endif

// (128-LVL0)/128 is the threshold to activate button
// (128-LVL1)/128 is the threshold to de-activate button
// for 64/96 it's 0.5 and 0.25
#define LVL0 64
#define LVL1 96

.check_axis MACRO val, M, P
	mov a, val
	if (isr1.M) {
		sub a, LVL1
	} else {
		sub a, LVL0
	}
	ifset OV
		set1 isr0.M
	mov a, val
	if (isr1.P) {
		add a, LVL1
	} else {
		add a, LVL0
	}
	ifset OV
		set1 isr0.P
ENDM

	.disint
		clear isr0
		.mova isr1, prev_btn[0]
		.check_axis sensor_state[1+4], 0, 2
		.check_axis sensor_state[3+4], 1, 3
		mov a, isr0
		or sensor_state[0], a
	engint

	set0 blink.blink_free_flag
	.forc i, BTN_STATE
		mov a, prev_btn[i]
		ifneq a, sensor_state[i]
			set1 blink.blink_free_flag
	.endm
	mov a, JD_EV_CHANGE
	ifset blink.blink_free_flag
		goto ev_send

	goto loop

serv_rx:
	mov a, pkt_service_command_h
	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l
		if (a == JD_JOYSTICK_REG_RO_BUTTONS_AVAILABLE) {
			set1 tx_pending.txp_avail_buttons
		}
	}

	.sensor_rx

.serv_ev_payload EXPAND
	.mova pkt_size, 4
	mov a, ev_code
	mov pkt_service_command_l, a
	if (a == JD_EV_CHANGE) {
		.forc i, BTN_STATE
			.mova pkt_payload[i], sensor_state[i]
		.endm
	}
ENDM

	.ev_impl
