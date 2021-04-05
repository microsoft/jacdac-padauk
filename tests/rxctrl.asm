#define rx_size packet_buffer[12]
#define rx_service_num packet_buffer[13]
#define rx_cmd_l packet_buffer[14]
#define rx_cmd_h packet_buffer[15]
#define rx_data_0 packet_buffer[16]
#define rx_data_1 packet_buffer[17]
#define rx_data_2 packet_buffer[18]
#define rx_data_3 packet_buffer[19]

	mov a, rx_service_num
	ceqsn a, 0
	goto not_ctrl
	mov a, rx_cmd_h
	ceqsn a, 0
	goto not_ctrl_cmd
	mov a, rx_cmd_l

	ceqsn a, 0x82
	goto @f
	reset
@@:
	ceqsn a, 0x81
	goto @f
	set1 flags.f_identify
	goto rx_process_end
@@:

	goto rx_process_end

not_ctrl_cmd:
	ceqsn a, 0x20
	goto not_ctrl_reg_set

	mov a, rx_cmd_l

	ceqsn a, 0x80
	goto not_reset_in
	set0 flags.f_reset_in // first disable reset-in
	mov a, rx_data_3
	ceqsn a, 0
	goto pkt_invalid // they ask us to wait too long
	mov a, rx_data_2
	sr a
	sr a
	t0sn ZF
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

	goto rx_process_end

not_serv1:

rx_process_end: