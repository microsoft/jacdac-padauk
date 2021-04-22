.CHIP   PMS150C
// Give package map to writer	pcount	VDD	PA0	PA3	PA4	PA5	PA6	PA7	GND	SHORTC_MSK1	SHORTC_MASK1	SHIFT
//.writer package 		6, 	1, 	0,	4, 	27, 	25,	26, 	0,	28, 	0x0007, 	0x0007, 	0
//{{PADAUK_CODE_OPTION
	.Code_Option	Security	Disable
	.Code_Option	Bootup_Time	Fast
	.Code_Option	Drive		Normal
	.Code_Option	LVR		3.0V
//}}PADAUK_CODE_OPTION

// all pins on PA
#define PIN_LED	3
#define PIN_JACDAC 6
#define PIN_LOG 7

// Cost given in comment: words of flash/bytes of RAM
// #define CFG_T16_32BIT 1 // 1/1
#define CFG_BROADCAST 1 // 20/0
#define CFG_RESET_IN 1 // 24/1
#define CFG_FW_ID 0x3646ae27 // 24/0

.include jdheader.asm

//#define PIN_BTN 4
//.include button.asm // 214/11 (incl. events and sensor)

#define PIN_NPX 4
.include npx.asm


main:
	.ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V

.include jdmain.asm
