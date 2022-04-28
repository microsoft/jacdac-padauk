.CHIP   PFS122
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable
	.Code_Option	Bootup_Time	Fast
	.Code_Option	LVR		3.0V
	.Code_Option	Comparator_Edge	All_Edge
	.Code_Option	TMx_Bit		6BIT
	.Code_Option	TMx_Source	16MHz
	.Code_Option	GPC_PWM		Disable
	.Code_Option	Interrupt_Src1	PB.0
	.Code_Option	Interrupt_Src0	PA.0
	.Code_Option	PB4_PB7_Drive	Strong
//}}PADAUK_CODE_OPTION

//#define RELEASE 1

#define NUM_LEDS 8
#define LED_VARIANT 2 // ring

#define CFG_TXP2 1
// #define STACK_SIZE 4
#define PIXEL_BUFFER_SIZE (3 * NUM_LEDS)
// payload_size has to be divisible by 4!
#if PIXEL_BUFFER_SIZE > 8
#define PAYLOAD_SIZE PIXEL_BUFFER_SIZE
#endif

// all pins on PA
#define PIN_LED	5
#define PIN_JACDAC 6
#define LED_SINK 1
//#define PIN_LOG 3

// Cost given in comment: words of flash/bytes of RAM
#define CFG_FW_ID 0x3a7e069d // 24/0

.include ../jd/jdheader.asm

#define PIN_WS2812 4
.include ../services/led.asm


main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V
	PADIER = (1 << PIN_JACDAC)
	PBDIER = 0

.include ../jd/jdmain.asm
