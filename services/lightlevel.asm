#define SERVICE_CLASS 0x17dc9a1c
#define SENSOR_SIZE 2

#define JD_LIGHT_LEVEL_VARIANT_PHOTO_RESISTOR 0x1
#define JD_LIGHT_LEVEL_VARIANT_REVERSE_BIASED_LED 0x2

#ifndef VARIANT
#define VARIANT JD_LIGHT_LEVEL_VARIANT_PHOTO_RESISTOR
#endif

.serv_init EXPAND
	.mova streaming_interval, 100
ENDM

.analog_reading EXPAND
	mov sensor_state[1], a
	.mova sensor_state[0], ADC_L
ENDM

.include analog.asm
