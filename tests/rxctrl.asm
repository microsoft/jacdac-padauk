#define JD_HIGH_CMD 0x00
#define JD_HIGH_REG_RW_SET 0x20
#define JD_HIGH_REG_RW_GET 0x10
#define JD_HIGH_REG_RO_GET 0x11

#define JD_CONTROL_CMD_IDENTIFY 0x81
#define JD_CONTROL_CMD_RESET 0x82
#define JD_CONTROL_CMD_SET_STATUS_LIGHT 0x84

#define JD_CONTROL_REG_RW_RESET_IN 0x80

	mov a, pkt_service_number
	ifneq a, 0
		goto not_ctrl
	mov a, pkt_service_command_h

	if (a == JD_HIGH_CMD) {
		mov a, pkt_service_command_l

		if (a == JD_CONTROL_CMD_RESET) {
			reset
		}
		if (a == JD_CONTROL_CMD_IDENTIFY) {
			.mova blink, 0x0f
		}

		goto rx_process_end
	}

	if (a == JD_HIGH_REG_RW_SET) {
		mov a, pkt_service_command_l

		if (a == JD_CONTROL_REG_RW_RESET_IN) {
			set0 flags.f_reset_in // first disable reset-in
			mov a, pkt_payload[3]
			ifneq a, 0
				goto pkt_invalid // they ask us to wait too long
			mov a, pkt_payload[2]
			sr a
			sr a
			ifset ZF
				goto rx_process_end // keep disabled - timer was 0
			set1 flags.f_reset_in // enable
			add a, t16_262ms
			mov t_reset, a // set timer
		}
	}

	goto rx_process_end

not_ctrl:
	ifneq a, 1
		goto not_serv1

.include rxserv.asm

not_serv1:
rx_process_end:
