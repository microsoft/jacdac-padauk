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

// all pins on PA
#define PIN_LED	3
#define PIN_JACDAC 6
#define PIN_LOG 7

// Cost given in comment: words of flash/bytes of RAM
// #define CFG_T16_32BIT 1 // 1/1
#define CFG_BROADCAST 1 // 20/0
#define CFG_RESET_IN 1 // 24/1
#define CFG_FW_ID 0x328d0f9d // 24/0

.include ../jd/jdheader.asm

#define JOY_X_OFF_POS 9
#define PIN_JOY_X 4
#define PIN_JOY_X_ADC PA4
#define JOY_Y_OFF_POS 5
#define PIN_JOY_Y 0
#define PIN_JOY_Y_ADC PA0
.include ../services/joystick.asm


main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V
	PADIER = (1 << PIN_JACDAC)
	PBDIER = 0

.include ../jd/jdmain.asm
