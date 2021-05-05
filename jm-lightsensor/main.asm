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

//#define RELEASE 1

/*
Assignment (S8 package, or lower pins of S14/S16):

VDD                           | GND
PA7 -                         | PA0 - Jacdac
PA6 -                         | PA4 - sensor
PA5 - sink of status LED      | PA3
*/

// all pins on PA
#define PIN_LED	5
#define LED_SINK 1
#define PIN_JACDAC 0
// #define PIN_LOG 1

// Cost given in comment: words of flash/bytes of RAM
// #define CFG_T16_32BIT 1 // 1/1
#define CFG_BROADCAST 1 // 20/0
#define CFG_RESET_IN 1 // 24/1
#define CFG_FW_ID 0x3a093c97 // 24/0

.include ../jd/jdheader.asm

#define PIN_ADC PA4

.include ../services/joystick.asm


main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V
	PADIER = (1 << PIN_JACDAC)
	PBDIER = 0

.include ../jd/jdmain.asm
