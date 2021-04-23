#define SERVICE_CLASS 0x1e3048f8
#define JD_LED_CMD_ANIMATE 0x80
#define JD_LED_REG_RO_COLOR 0x80
#define JD_LED_REG_RO_LED_COUNT 0x83

txp_color equ 3
txp_led_count equ 4
txp_variant equ 5

f_do_frame equ 7

	BYTE    value_h[3]
	BYTE    value_l[3]
	BYTE    speed_h[3]
	BYTE    speed_l[3]
	BYTE    target[3]
	BYTE    tmp

.serv_init EXPAND
	PAC.PIN_WS2812 = 1 // output
ENDM

.serv_process EXPAND
	.on_rising flags.f_do_frame, t16_1ms.5, <goto do_frame>
ENDM

.serv_prep_tx EXPAND
	if (tx_pending.txp_color) {
		set0 tx_pending.txp_color
		.set_ro_reg JD_LED_REG_RO_COLOR
		.forc i, <012>
		.mova pkt_payload[i], value_h[i]
		.endm
		.mova pkt_size, 3
		ret
	}

	if (tx_pending.txp_led_count) {
		set0 tx_pending.txp_led_count
		.set_ro_reg JD_LED_REG_RO_LED_COUNT
		.mova pkt_payload[0], 1 // 1 LED
		.mova pkt_size, 2
		ret
	}

	if (tx_pending.txp_variant) {
		set0 tx_pending.txp_variant
		.set_ro_reg JD_REG_RO_VARIANT
		.mova pkt_payload[0], 0x2 // Variant - SMD
		.mova pkt_size, 1
		ret
	}
ENDM

do_frame:
	.forc i, <012>
		.mova tmp, value_h[i]
		mov a, speed_l[i]
		add value_l[i], a
		mov a, speed_h[i]
		addc value_h[i], a
		if (a == 0) {
			mov a, speed_l[i]
			ifset ZF
				goto @f.target
			mov a, speed_h[i]
		}
		sl a
		if (CF) {
			// speed < 0
			mov a, value_h[i]
			sub tmp, a
			ifset CF
				goto @f.target // underflow
			sub a, target[i]
			ifset CF
				goto @f.target
		} else {
			mov a, target[i]
			sub a, value_h[i]
			ifset CF
				goto @f.target
		}
		goto @f.quit
	@@.target:
		clear speed_h[i]
		clear speed_l[i]
		.mova value_h[i], target[i]
		clear value_l[i]
	@@.quit:
	.endm

// Measured as:
// 0.37us / 0.89us for 0
// 0.62us / 0.63us for 1
.ws2812_byte MACRO
@@:
	set1 PA.PIN_WS2812
	sl a
	ifclear CF
	   set0 PA.PIN_WS2812
	nop
	set0 PA.PIN_WS2812
	nop
	dzsn isr0
		goto @b
	set1 isr0.3
	set1 PA.PIN_WS2812
	sl a
	ifclear CF
	   set0 PA.PIN_WS2812
	dec isr0
	set0 PA.PIN_WS2812
	ifclear PA.PIN_JACDAC
		set1 isr1.0
	nop
ENDM

	.disint
		.mova isr1, 0
		.mova isr0, 7
		// assume GRB order (102)
		.forc i, <102>
		mov a, value_h[i]
		.ws2812_byte
		.endm
		ifset isr1.0
			goto switch_to_rx
	engint

	goto loop

handle_channel:
	sr isr0
	sr isr1
	mov a, isr1
	sub isr0, a
	set0 frm_flags.6
	if (CF) {
		// result is negative
		neg isr0
		set1 frm_flags.6	
	}
	.mul_8x8 rx_data, isr1, isr2, isr0, pkt_payload[3]
	if (frm_flags.6) {
		// isr1:isr2 = -isr1:isr2
		not isr2 // negate high bits first
		neg isr1
		ifset ZF // isr1 was 0, so there was "carry" to isr2
			inc isr2
	}
	ret

serv_rx:
	mov a, pkt_service_command_h

	if (a == JD_HIGH_CMD) {
		mov a, pkt_service_command_l

		if (a == JD_LED_CMD_ANIMATE) {
			// ch->speed = ((to[i] - (ch->value >> 8)) * anim->speed) >> 1;
			.forc i, <012>
				mov a, pkt_payload[i]
				mov target[i], a
				mov isr0, a
				.mova isr1, value_h[i]
				call handle_channel
				.mova speed_h[i], isr2
				.mova speed_l[i], isr1
			.endm
		}

		goto rx_process_end
	}

	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l

		if (a == JD_LED_REG_RO_COLOR) {
			set1 tx_pending.txp_color
			goto rx_process_end
		}

		if (a == JD_REG_RO_VARIANT) {
			set1 tx_pending.txp_variant
			goto rx_process_end
		}

		if (a == JD_LED_REG_RO_LED_COUNT) {
			set1 tx_pending.txp_led_count
		}
	}

	goto rx_process_end

