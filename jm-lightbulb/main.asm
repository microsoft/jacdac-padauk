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

// all pins on PA
#define EN_DIMMEABLE 1
#define PIN_LED	5
#define PIN_JACDAC 6
//#define PIN_LOG 7


// Cost given in comment: words of flash/bytes of RAM
// #define CFG_T16_32BIT 1 // 1/1
#define CFG_BROADCAST 1 // 20/0
#define CFG_RESET_IN 1 // 24/1
#define CFG_FW_ID 0x3f44a5eb // 24/0


.include ../jd/jdheader.asm

#if EN_DIMMEABLE
// PB7 to TM3 pwm output
#define PIN_LIGHTBULB 7
#else
// PA3
#define PIN_LIGHTBULB 3
#endif

.include ../services/lightbulb.asm

main:
    .ADJUST_IC	SYSCLK=IHRC/2, IHRC=16MHz, VDD=3.3V
    PADIER = (1 << PIN_JACDAC)
    
#if EN_DIMMEABLE
    // init PWM timer
    PBC.PIN_LIGHTBULB = 1
    PB.PIN_LIGHTBULB = 0
    $ TM3S 8BIT, /1, /4 // ~32hz
    // init timer on brightness received
    // $ TM3C ILRC, PB7, PWM
    TM3B = 0
#else
    // init GPIO for toggle
    PAC.PIN_LIGHTBULB =   1 // output
    PA.PIN_LIGHTBULB  =   0 // off
#endif

.include ../jd/jdmain.asm
