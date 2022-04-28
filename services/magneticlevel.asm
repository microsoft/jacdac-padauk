#ifndef THR_LO
#define THR_LO 20
#define THR_HI 25
#endif

#ifndef MIN_VAL
#define MIN_VAL 57
#endif

#define SERVICE_CLASS 0x12fe180f
#define SENSOR_SIZE 2

#define JD_MAGNETIC_FIELD_LEVEL_VARIANT_ANALOG_NS 0x1
#define JD_MAGNETIC_FIELD_LEVEL_VARIANT_ANALOG_N 0x2
#define JD_MAGNETIC_FIELD_LEVEL_VARIANT_ANALOG_S 0x3
#define JD_MAGNETIC_FIELD_LEVEL_VARIANT_DIGITAL_NS 0x4
#define JD_MAGNETIC_FIELD_LEVEL_VARIANT_DIGITAL_N 0x5
#define JD_MAGNETIC_FIELD_LEVEL_VARIANT_DIGITAL_S 0x6

#define JD_MAGNETIC_FIELD_LEVEL_REG_DETECTED 0x181

#define JD_MAGNETIC_FIELD_LEVEL_EV_ACTIVE JD_EV_ACTIVE
#define JD_MAGNETIC_FIELD_LEVEL_EV_INACTIVE JD_EV_INACTIVE

#ifndef VARIANT
#define VARIANT JD_MAGNETIC_FIELD_LEVEL_VARIANT_ANALOG_NS
#endif

#define EVENTS 1

#define f_detected f_serv0

.serv_init EXPAND
	.mova streaming_interval, 100
ENDM

#define s_l sensor_state[0]
#define s_h sensor_state[1]
BYTE abs_v

.analog_reading EXPAND
	.mova s_h, ADC_H
	.mova s_l, ADC_L
	mov a, MIN_VAL
	sub s_h, a
	if (CF) {
		clear s_h
		clear s_l
	}
	sl s_l
	slc s_h
	if (CF) {
		mov a, 0xff
		mov s_h, a
		mov s_l, a
	}
	mov a, 0x80
	sub s_h, a

	mov a, s_h
	sl a
	mov a, s_h
	ifset CF
		neg a
	mov abs_v, a
	if (f_detected) {
		mov a, THR_LO
	} else {
		mov a, THR_HI
	}
	sub a, abs_v
	if (CF) {
		if (!f_detected) {
			set1 f_detected
			mov a, JD_EV_ACTIVE
			goto ev_send_ex
		}
	} else {
		if (f_detected) {
			set0 f_detected
			mov a, JD_EV_INACTIVE
			goto ev_send_ex
		}
	}
ENDM

.include analog.asm
