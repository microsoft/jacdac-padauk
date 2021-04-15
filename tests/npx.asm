#define SERVICE_CLASS 0x1e3048f8
#define JD_LED_CMD_ANIMATE 0x80
#define JD_LED_REG_RO_COLOR 0x80
#define JD_LED_REG_RO_LED_COUNT 0x83

txp_color equ 3
txp_led_count equ 4
txp_variant equ 5

	BYTE    color_r
	BYTE    color_g
	BYTE    color_b

.serv_init EXPAND
	PAC.PIN_NPX = 1 // output
ENDM

.serv_process EXPAND
	// TODO
ENDM

.serv_prep_tx EXPAND
	if (tx_pending.txp_color) {
		set0 tx_pending.txp_color
		.set_ro_reg JD_LED_REG_RO_COLOR
		.mova pkt_payload[0], color_r
		.mova pkt_payload[1], color_g
		.mova pkt_payload[2], color_b
		.mova pkt_size, 3
		ret
	}

	if (tx_pending.txp_led_count) {
		set0 tx_pending.txp_led_count
		.set_ro_reg JD_LED_REG_RO_LED_COUNT
		.mova pkt_payload[0], 1 // 1 LED
		.mova pkt_size, 1
		ret
	}

	if (tx_pending.txp_variant) {
		set0 tx_pending.txp_variant
		.set_ro_reg JD_LED_REG_RO_LED_COUNT
		.mova pkt_payload[0], 0x2 // Variant - SMD
		.mova pkt_size, 1
		ret
	}
ENDM

serv_rx:
	mov a, pkt_service_command_h

	if (a == JD_HIGH_CMD) {
		mov a, pkt_service_command_l

		if (a == JD_LED_CMD_ANIMATE) {
			// TODO
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

