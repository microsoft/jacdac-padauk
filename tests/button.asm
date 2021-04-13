#define SENSOR_SIZE 1

	.include sensor.asm
	.include events.asm

#define JD_BUTTON_EV_DOWN 0x01
#define JD_BUTTON_EV_UP 0x02
#define JD_BUTTON_EV_HOLD 0x81

	BYTE	t_sample
	BYTE    btn_down_l
	BYTE    btn_down_h
	BYTE    t_btn_hold

.serv_init EXPAND
	PAPH.JD_BTN =   1 // pullup on btn
ENDM

.serv_process EXPAND
	.ev_process
	.t16_chk t16_1ms, t_sample, <goto do_sample>
	.sensor_process
ENDM

.serv_prep_tx MACRO
	.ev_prep_tx
	.sensor_prep_tx
ENDM

do_sample:
	.t16_set t16_1ms, t_sample, 20
	mov a, sensor_state[0]
	ifclear PA.JD_BTN
		goto button_active
button_inactive:
	ifset ZF // state==0
		goto loop // just keep going
	clear sensor_state[0]
		// snapshot duration
		mov a, t16_1ms
		sub a, btn_down_l
		mov btn_down_l, a
		mov a, t16_262ms
		subc a, btn_down_h
		mov btn_down_h, a

	mov a, JD_BUTTON_EV_UP
	goto ev_send
button_active:
	ifset ZF
		goto button_down
	.t16_chk t16_16ms, t_btn_hold, <goto button_hold>
	goto loop
button_hold:
	.t16_set t16_16ms, t_btn_hold, 31
	mov a, JD_BUTTON_EV_HOLD
	goto ev_send
button_down:
	.mova sensor_state[0], 1
	.disint
		.mova btn_down_l, t16_1ms
		.mova btn_down_h, t16_262ms
	engint
	.t16_set t16_16ms, t_btn_hold, 31
	mov a, JD_BUTTON_EV_DOWN
	goto ev_send

serv_rx:
	.sensor_rx
