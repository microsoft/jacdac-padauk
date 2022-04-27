#ifndef LED_VAL_PER_MA
// (0,0,LED_VAL_PER_MA)/(255,255,255) = 1mA
#define LED_VAL_PER_MA 21
#endif

#ifndef LED_BASE_PWR_MA
// 1mA for Padauk, 1mA per LED
#define LED_BASE_PWR_MA (1+NUM_LEDS)
#endif

#define JD_LED_VARIANT_STRIP 0x1
#define JD_LED_VARIANT_RING 0x2
#define JD_LED_VARIANT_STICK 0x3
#define JD_LED_VARIANT_JEWEL 0x4
#define JD_LED_VARIANT_MATRIX 0x5

#define SERVICE_CLASS 0x1609d4f0

#define JD_LED_REG_RW_PIXELS JD_REG_RW_VALUE
#define JD_LED_REG_RW_BRIGHTNESS JD_REG_RW_INTENSITY
#define JD_LED_REG_RW_MAX_POWER JD_REG_RW_MAX_POWER

#define JD_LED_REG_RO_ACTUAL_BRIGHTNESS 0x80
#define JD_LED_REG_RO_NUM_PIXELS 0x82
// #define JD_LED_REG_RO_NUM_COLUMNS 0x83
// #define JD_LED_REG_RO_LEDS_PER_PIXEL 0x84
// #define JD_LED_REG_RO_WAVE_LENGTH 0x85
// #define JD_LED_REG_RO_LUMINOUS_INTENSITY 0x86
#define JD_LED_REG_RO_VARIANT JD_REG_RO_VARIANT

txp_pixels equ txp_serv0
txp_brightness equ txp_serv1
txp_max_power equ txp_serv2
txp_actual_brightness equ txp_serv3
txp_num_pixels equ tx_pending2.0
txp_variant equ tx_pending2.1

f_dirty equ f_serv0
f_recompute equ f_serv1
f_do_frame equ f_ev1


#if PIXEL_BUFFER_SIZE < 5
#define PIXEL_MUL_BUFFER_SIZE 5
#else
#define PIXEL_MUL_BUFFER_SIZE PIXEL_BUFFER_SIZE
#endif

pixels_ptr equ 0x41
	.ramadr pixels_ptr

	BYTE    pixels[PIXEL_BUFFER_SIZE]
	BYTE    pixels_mul[PIXEL_MUL_BUFFER_SIZE]
	BYTE    brightness
	BYTE    actual_brightness
	BYTE    max_power_l
	BYTE    max_power_h

	BYTE    ws_cnt
	BYTE    ws_tmp
	BYTE    ws_x
	BYTE    ws_y
	BYTE    ws_z

#define val_tmp1 ws_cnt
#define max_val_l ws_x
#define max_val_h ws_y
#define val_l ws_z
#define val_h      pixels_mul[0]
#define val_res1_l pixels_mul[1]
#define val_res1_h pixels_mul[2]
#define val_res2_l pixels_mul[3]
#define val_res2_h pixels_mul[4]


.serv_init EXPAND
	PAC.PIN_WS2812 = 1 // output
	.mova brightness, 100
	mov actual_brightness, a
	.mova max_power_l, 75
	set1 f_recompute
ENDM

.serv_process EXPAND
	ifset f_recompute
		goto recompute
	ifset f_dirty
		goto do_frame
	.on_rising f_do_frame, t16_1ms.5, <set1 f_recompute>
ENDM

.serv_prep_tx EXPAND
	if (txp_pixels) {
		set0 txp_pixels
		.set_rw_reg JD_LED_REG_RW_PIXELS
		.mova pkt_size, PIXEL_BUFFER_SIZE

		_idx => 0
		.repeat PIXEL_BUFFER_SIZE
			.mova pkt_payload[_idx], pixels[_idx]
			_idx => _idx + 1
		.endm
		ret
	}

	if (txp_brightness) {
		set0 txp_brightness
		.set_rw_reg JD_LED_REG_RW_BRIGHTNESS
		.mova pkt_payload[0], brightness
		.mova pkt_size, 1
		ret
	}

	if (txp_max_power) {
		set0 txp_max_power
		.set_rw_reg JD_LED_REG_RW_MAX_POWER
		.mova pkt_payload[0], max_power_l
		.mova pkt_payload[1], max_power_h
		.mova pkt_size, 2
		ret
	}

	if (txp_actual_brightness) {
		set0 txp_actual_brightness
		.set_ro_reg JD_LED_REG_RO_ACTUAL_BRIGHTNESS
		.mova pkt_payload[0], actual_brightness
		.mova pkt_size, 1
		ret
	}

	if (txp_num_pixels) {
		set0 txp_num_pixels
		.set_ro_reg JD_LED_REG_RO_NUM_PIXELS
		.mova pkt_payload[0], NUM_LEDS
		.mova pkt_size, 2
		ret
	}

	if (txp_variant) {
		set0 txp_variant
		.set_ro_reg JD_REG_RO_VARIANT
		.mova pkt_payload[0], LED_VARIANT
		.mova pkt_size, 1
		ret
	}
ENDM

// Measured as:
// 0.37us / 0.89us for 0
// 0.62us / 0.63us for 1
// Datasheet: 0.22-0.38us for short; 0.58-1.00us for long

#define ws_data rx_data
#define ws_count isr1
#define ws_bit_count isr0

.send_pixels EXPAND
	.mova ws_count, PIXEL_BUFFER_SIZE
	.mova memidx$0, pixels_ptr+PIXEL_BUFFER_SIZE
	.mova ws_bit_count, 6
	idxm a, memidx

ws_next_bit:
	set1 PA.PIN_WS2812
	sl a
	ifclear CF
	   set0 PA.PIN_WS2812
	nop
	set0 PA.PIN_WS2812
	nop
	dzsn ws_bit_count
		goto ws_next_bit

	mov ws_data, a
	set1 PA.PIN_WS2812
	mov a, 6
	ifclear ws_data.7
	   set0 PA.PIN_WS2812
	mov ws_bit_count, a
	set0 PA.PIN_WS2812
	ifclear PA.PIN_JACDAC
		goto switch_to_rx
	nop
	nop

	set1 PA.PIN_WS2812
	nop
	ifclear ws_data.6
	   set0 PA.PIN_WS2812
	inc memidx$0
	set0 PA.PIN_WS2812
	idxm a, memidx
	// idxm, 2T
	dzsn ws_count
		goto ws_next_bit
		// goto, 2T
ENDM

recompute:
	// clear the flag at the beginning - if we get some packets while recomputing, they will
	// set the flag again, so we re-compute with proper data
	set0 f_recompute

	// val_lh = max_power_lh - LED_BASE_PWR_MA
	.mova val_l, max_power_l
	.mova val_h, max_power_h
	mov a, LED_BASE_PWR_MA
	sub val_l, a
	subc val_h
	// if (val_lh < 0) val_lh = 0
	if (CF) {
		clear val_l
		clear val_h
	}
	// max_val_lh = val_l*LED_VAL_PER_MA
	.mova val_tmp1, LED_VAL_PER_MA
	.mul_8x8 ws_tmp, max_val_l, max_val_h, val_l, val_tmp1
	// val_res1_lh = val_h*LED_VAL_PER_MA
	.mova val_tmp1, LED_VAL_PER_MA
	.mul_8x8 ws_tmp, val_res1_l, val_res1_h, val_h, val_tmp1
	// max_val_lh += val_res1_lh << 8
	mov a, val_res1_l
	add max_val_h, a
	addc val_res1_h
	if (!ZF) {
		// if there's carry into val_res1_h, or val_res1_h was positive, the limit is above 3A
		.mova max_val_h, 0xff
	}

	.mova ws_cnt, PIXEL_BUFFER_SIZE
	clear val_l
	clear val_h

add_val_loop:
	mov a, pixels_ptr-1
	add a, ws_cnt
	.disint
		mov memidx$0, a
		idxm a, memidx
	engint

	add val_l, a
	addc val_h

	dzsn ws_cnt
		goto add_val_loop

	// val_res2_lh = (val_lh * actual_brightness) >> 8
	.mova val_tmp1, val_l
	.mul_8x8 ws_tmp, val_res1_l, val_res1_h, val_tmp1, actual_brightness
	.mova val_tmp1, val_h
	.mul_8x8 ws_tmp, val_res2_l, val_res2_h, val_tmp1, actual_brightness
	mov a, val_res1_h
	add val_res2_l, a
	addc val_res2_h

	// val_tmp1:val_res1_h = (val_lh * (actual_brightness+1)) >> 8
	.mova val_res1_h, val_res2_l
	.mova val_tmp1, val_res2_h
	mov a, val_l
	add val_res1_l, a
	mov a, val_h
	addc val_res1_h, a
	addc val_tmp1

	mov a, max_val_l
	sub val_res2_l, a
	mov a, max_val_h
	subc val_res2_h, a

	if (CF) {
		// good, we're under current limit!
		// is the actual brightness smaller than requested?
		mov a, actual_brightness
		if (a != brightness) {
			mov a, max_val_l
			sub val_res1_h, a
			mov a, max_val_h
			subc val_tmp1, a
			// can we fit ++brightness?
			ifset CF
				inc actual_brightness
		}
	} else {
		// we're over limit
		mov a, actual_brightness
		if (!ZF) {
			// if actual is not zero (not sure if that's possible)
			sr a
			sr a
			sr a
			add a, 1
			// reduce actual by 1/8th + 1
			sub actual_brightness, a
			// and try again next time
			set1 f_recompute
			goto loop
		}
	}

	// now multiply pixels
	.mova ws_cnt, PIXEL_BUFFER_SIZE

mul_loop:
	mov a, pixels_ptr-1
	add a, ws_cnt
	.disint
		mov memidx$0, a
		idxm a, memidx
	engint

	// ws_y = ((pixels[ws_cnt] * actual_brightness) + 0x80) >> 8
	mov ws_x, a
	.mul_8x8 ws_tmp, ws_z, ws_y, ws_x, actual_brightness
	mov a, 0x80
	add ws_z, a
	addc ws_y

	mov a, pixels_ptr-1+PIXEL_BUFFER_SIZE
	add a, ws_cnt
	.disint
		mov memidx$0, a
		mov a, ws_y
		idxm memidx, a
	engint

	dzsn ws_cnt
		goto mul_loop
	
	// RGB -> GRB
	_idx => 0
	.repeat NUM_LEDS
		mov a, pixels_mul[_idx]
		xch pixels_mul[_idx + 1]
		xch pixels_mul[_idx]
		_idx => _idx + 3
	.endm

	// we set dirty, so it's re-painted on next frame
	// however, if there was an incoming packet during recomputation,
	// or we max_power was exceeded, the f_recompute would have been set
	// so the next loop will recompute, and only the next one repaint
	set1 f_dirty
	goto loop

do_frame:
	// have to disable INT for bitbanging
	.disint
		.send_pixels
		// only clear f_dirty when we're done - .send_pixel might jump out to RX
		set0 f_dirty
	engint
	goto loop

.reg_cmp MACRO val, flag
		if (a == val) {
			set1 flag
			goto rx_process_end
		}
ENDM

serv_rx:
	mov a, pkt_service_command_h

	if (a == JD_HIGH_REG_RW_GET) {
		mov a, pkt_service_command_l

		.reg_cmp JD_LED_REG_RW_PIXELS, txp_pixels
		.reg_cmp JD_LED_REG_RW_BRIGHTNESS, txp_brightness
		.reg_cmp JD_LED_REG_RW_MAX_POWER, txp_max_power

		goto not_implemented
	}

	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l

		.reg_cmp JD_LED_REG_RO_ACTUAL_BRIGHTNESS, txp_actual_brightness
		.reg_cmp JD_LED_REG_RO_NUM_PIXELS, txp_num_pixels
		.reg_cmp JD_LED_REG_RO_VARIANT, txp_variant

		goto not_implemented
	}

	if (a == JD_HIGH_REG_RW_SET) {
		mov a, pkt_service_command_l

		if (a == JD_LED_REG_RW_PIXELS) {
			mov a, pkt_size
			if (a == PIXEL_BUFFER_SIZE) {
				_idx => 0
				.repeat PIXEL_BUFFER_SIZE
					.mova pixels[_idx], pkt_payload[_idx]
					_idx => _idx + 1
				.endm
				set1 f_recompute
			}
			goto rx_process_end
		}

		if (a == JD_LED_REG_RW_BRIGHTNESS) {
			mov a, pkt_size
			if (a == 1) {
				.mova brightness, pkt_payload[0]
				mov actual_brightness, a
				set1 f_recompute
			}
			goto rx_process_end
		}

		if (a == JD_LED_REG_RW_MAX_POWER) {
			mov a, pkt_size
			if (a == 2) {
				.mova max_power_l, pkt_payload[0]
				.mova max_power_h, pkt_payload[1]
				set1 f_recompute
			}
			goto rx_process_end
		}

		goto not_implemented
	}

	goto rx_process_end
