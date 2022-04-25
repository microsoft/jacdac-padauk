.CHIP   PMS150C
// Give package map to writer	pcount VDD PA0 PA3 PA4 PA5 PA6 PA7 GND SHORTC_MSK1 SHORTC_MASK1 SHIFT
.writer package                 8,     1,  7,  5,  6,  4,  3,  2,  8,  0x000D,     0x000D,      4
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable
	.Code_Option	Bootup_Time	Fast
	.Code_Option	Drive		Normal
	.Code_Option	LVR		3.0V
//}}PADAUK_CODE_OPTION

#define RELEASE 1

// all pins on PA
#define PIN_LED	5
#define PIN_JACDAC 6
//#define PIN_LOG 7

#define LED_SINK 1

// Cost given in comment: words of flash/bytes of RAM
#define CFG_FW_ID 0x3592dcb4 // 24/0

#define PWR_SERVICE 1

#define PIN_SWITCH 4

.include ../jd/jdheader.asm

#define PIN_LIMITER 3
.include ../services/power.asm

main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V
	PADIER = (1 << PIN_JACDAC) | (1 << PIN_LIMITER)	

.include ../jd/jdmain.asm
