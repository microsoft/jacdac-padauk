.CHIP   PFS122
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable
	.Code_Option	Bootup_Time	Fast
	.Code_Option	LVR		3.0V
	.Code_Option	Comparator_Edge	All_Edge
	.Code_Option	GPC_PWM		Disable
	.Code_Option	TMx_Bit		6BIT
	.Code_Option	TMx_Source	16MHz
	.Code_Option	Interrupt_Src1	PB.0
	.Code_Option	Interrupt_Src0	PA.0
	.Code_Option	PB4_PB7_Drive	Strong
//}}PADAUK_CODE_OPTION

//#define RELEASE 1

/*
Assignment (S8 package):

VDD                           | GND
PA6 - Jacdac                  | PA4
PA5 - sink of status LED      | PA3
PB7 - pot                     | PB1
*/

#define ADC_12BIT 1

// all pins on PA
#define PIN_LED	5
// #define LED_SINK 1
#define PIN_JACDAC 6
// #define PIN_LOG 1

// Cost given in comment: words of flash/bytes of RAM
#define CFG_FW_ID 0x33e1f282 // 24/0

.include ../jd/jdheader.asm

#define PIN_ADC PB7
// #define PIN_ANALOG_PWR 7 // ???

.include ../services/potentiometer.asm

main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V
	PADIER = (1 << PIN_JACDAC)
	PBDIER = 0

.include ../jd/jdmain.asm
