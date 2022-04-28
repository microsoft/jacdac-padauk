#define SERVICE_CLASS 0x1f274746
#define SENSOR_SIZE 2

#define JD_POTENTIOMETER_VARIANT_SLIDER 0x1
#define JD_POTENTIOMETER_VARIANT_ROTARY 0x2

#ifndef VARIANT
#define VARIANT JD_POTENTIOMETER_VARIANT_SLIDER
#endif

.serv_init EXPAND
	.mova streaming_interval, 20
ENDM

.analog_reading EXPAND
	mov sensor_state[1], a
	.mova sensor_state[0], ADC_L
ENDM

.include analog.asm
