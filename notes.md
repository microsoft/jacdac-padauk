# Random notes

* almost all parts have 8 bit timer (in addition to 16 bit)
* thinking 2kW/128bytes as min. reqs. (these all have 2 8-bit timers)

## PFS154
* PWM0 (for RGB LED) on S8 pkg is on PA0, which is the only pin with INT
* on S14 we could use PB0 INT1 for JD
* PA5 - RGB LED PWM not supported in ICE, and max current 5mA (10mA on other RGB pins)
* sink current ~3x source current
* internal pull up 200k - need external?
* 0.9mA operating current

