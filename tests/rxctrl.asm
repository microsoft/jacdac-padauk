#define rx_size packet_buffer[12]
#define rx_service_num packet_buffer[13]
#define rx_cmd_l packet_buffer[14]
#define rx_cmd_h packet_buffer[15]
#define rx_data_0 packet_buffer[16]
#define rx_data_1 packet_buffer[17]
#define rx_data_2 packet_buffer[18]
#define rx_data_3 packet_buffer[19]

#define JD_HIGH_CMD 0x00
#define JD_HIGH_REG_RW_SET 0x20
#define JD_HIGH_REG_RW_GET 0x10
#define JD_HIGH_REG_RO_GET 0x11

#define JD_CONTROL_CMD_IDENTIFY 0x81
#define JD_CONTROL_CMD_RESET 0x82
#define JD_CONTROL_CMD_SET_STATUS_LIGHT 0x84

#define JD_CONTROL_REG_RW_RESET_IN 0x80

	mov a, rx_service_num
	ceqsn a, 0
	goto not_ctrl
	mov a, rx_cmd_h
	ceqsn a, JD_HIGH_CMD
	goto not_ctrl_cmd
	mov a, rx_cmd_l

	ceqsn a, JD_CONTROL_CMD_RESET
	goto @f
	reset
@@:
	ceqsn a, JD_CONTROL_CMD_IDENTIFY
	goto @f
	set1 flags.f_identify
	goto rx_process_end
@@:

	goto rx_process_end

not_ctrl_cmd:
	ceqsn a, JD_HIGH_REG_RW_SET
	goto not_ctrl_reg_set

	mov a, rx_cmd_l

	ceqsn a, JD_CONTROL_REG_RW_RESET_IN
	goto not_reset_in
	set0 flags.f_reset_in // first disable reset-in
	mov a, rx_data_3
	ceqsn a, 0
	goto pkt_invalid // they ask us to wait too long
	mov a, rx_data_2
	sr a
	sr a
	ifset ZF
	  goto rx_process_end // keep disabled - timer was 0
	set1 flags.f_reset_in // enable
	add a, t16_262ms
	mov t_reset, a // set timer

not_reset_in:
	goto rx_process_end
	
not_ctrl_reg_set:
	goto rx_process_end

not_ctrl:
	ceqsn a, 1
	goto not_serv1

.include rxserv.asm

	goto rx_process_end

not_serv1:
rx_process_end: