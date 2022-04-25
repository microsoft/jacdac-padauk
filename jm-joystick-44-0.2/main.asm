.CHIP   PMS171B
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable
	.Code_Option	Bootup_Time	Fast
	.Code_Option	LVR		3.0V
	.Code_Option	Comparator_Edge	All_Edge
	.Code_Option	GPC_PWM		Disable
	.Code_Option	TM2_Out1	PB2
	.Code_Option	TMx_Bit		6BIT
	.Code_Option	TMx_Source	16MHz
	.Code_Option	Interrupt_Src1	PB.0
	.Code_Option	Interrupt_Src0	PA.0
	.Code_Option	PB4_PB5_Drive	Strong
//}}PADAUK_CODE_OPTION

#define RELEASE 1

/*
Assignment (S8 package, or lower pins of S14/S16):

VDD                           | GND
PA7 - sink of potentiometer   | PA0 - Jacdac
PA6 - BTN of joystick         | PA4 - X wiper
PA5 - sink of status LED      | PA3 - Y wiper
*/

// all pins on PA
#define PIN_LED	5
#define LED_SINK 1
#define PIN_JACDAC 0
// #define PIN_LOG 1

// Cost given in comment: words of flash/bytes of RAM
#define CFG_FW_ID 0x3a3320ac // 24/0

.include ../jd/jdheader.asm

#define PIN_BTN_A 6

.joystick_button_probe EXPAND
	mov a, 0x00
	ifclear PA.PIN_BTN_A
		or a, JD_JOYSTICK_BUTTONS_A
	mov sensor_state[0], a
ENDM

#define PIN_JOY_SINK 7
#define JOY_X_OFF_NEG 2
#define PIN_JOY_X_ADC PA4
#define JOY_Y_OFF_NEG 5
#define PIN_JOY_Y_ADC PA3

#define JOYSTICK_X_POLARITY_NEGATIVE
#define JOYSTICK_Y_POLARITY_POSITIVE

.include ../services/joystick.asm

main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V
	PADIER = (1 << PIN_JACDAC) | (1 << PIN_BTN_A)
	PAPH = (1 << PIN_BTN_A)
	PBDIER = 0

.include ../jd/jdmain.asm
