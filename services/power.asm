#define SERVICE_CLASS 0x1fa4c95a

#define JD_POWER_POWER_STATUS_DISALLOWED 0x0
#define JD_POWER_POWER_STATUS_POWERING 0x1
#define JD_POWER_POWER_STATUS_OVERLOAD 0x2
#define JD_POWER_POWER_STATUS_OVERPROVISION 0x3

#define JD_POWER_REG_RW_ALLOWED JD_REG_RW_INTENSITY
#define JD_POWER_REG_RO_POWER_STATUS 0x81
#define JD_POWER_CMD_SHUTDOWN 0x80
#define JD_POWER_EV_POWER_STATUS_CHANGED JD_EV_CHANGE

	BYTE	t_sample
	BYTE    pwr_status

/*
TODO:
  send PWR packet every ~500 ms while limiter is enabled
  monitor limiter - input on PIN_LIMITER no pull
    - LED ~10% ON when providing power
	- LED normal blinking when not providing power
  on PWR cmd - disable limiter (output 0 on PIN_LIMITER) for 1000ms

*/

txp_pwr_shutdown equ 3
txp_pwr_allowed equ 4
txp_pwr_status equ 5

.serv_init EXPAND
	PAC.PIN_SWITCH = 1
	PA.PIN_SWITCH = 1
ENDM

.serv_process EXPAND
	.ev_process
ENDM

.serv_prep_tx MACRO
	ifset tx_pending.txp_event
		goto ev_prep_tx

	if (tx_pending.txp_pwr_status) {
		set0 tx_pending.txp_pwr_status
		inc pkt_size // ==1
		.mova pkt_payload[0], pwr_status
		ret
	}

	if (tx_pending.txp_pwr_allowed) {
		set0 tx_pending.txp_pwr_allowed
		inc pkt_size // ==1
		// data[0] = (pwr_status != Disallowed)
		mov a, pwr_status
		ifclear ZF
			mov a, 1
		mov pkt_payload[0], a
		ret
	}

	if (tx_pending.txp_pwr_shutdown) {
		set0 tx_pending.txp_pwr_shutdown

		// TODO
		.mova crc_l, 0xff
		.mova crc_h, 0xff

		.mova frm_sz, 4
		.mova frm_flags, (1 << JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS) | (1 << JD_FRAME_FLAG_COMMAND)

		.forc x, <0123>
		mov a, (SERVICE_CLASS >> (x * 8)) & 0xff
		mov pkt_device_id[x], a
		.endm
		mov a, 0xAA
		.forc x, <0123>
		mov pkt_device_id[4+x], a
		.endm

		// pkt_size already set to 0
		.mova pkt_service_number, JD_SERVICE_INDEX_BROADCAST
		.mova pkt_service_command_l, JD_POWER_CMD_SHUTDOWN
		clear pkt_service_command_h

		ret
	}
ENDM

serv_rx:
	mov a, pkt_service_command_h
	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l
		if (a == JD_POWER_REG_RO_POWER_STATUS) {
			set1 tx_pending.txp_pwr_status
		}
		goto rx_process_end	
	}
	if (a == JD_HIGH_REG_RW_GET) {
		mov a, pkt_service_command_l
		if (a == JD_POWER_REG_RW_ALLOWED) {
			set1 tx_pending.txp_pwr_allowed
		}
		goto rx_process_end	
	}
	if (a == JD_HIGH_REG_RW_SET) {
		mov a, pkt_service_command_l
		if (a == JD_POWER_REG_RW_ALLOWED) {
			mov a, pkt_payload[0]
			if (ZF) {
				// TODO shutdown limiter
				clear pwr_status
			} else {
				mov a, pwr_status
				// TODO
			}
			// TODO set chg ev pending
		}
		goto rx_process_end	
	}
	goto rx_process_end

.serv_ev_payload EXPAND
	inc pkt_size // == 1
	.mova pkt_service_command_l, JD_POWER_EV_POWER_STATUS_CHANGED
	.mova pkt_payload[0], pwr_status
ENDM

	.ev_impl
