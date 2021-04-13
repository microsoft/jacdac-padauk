
txp_streaming_samples equ 3
txp_streaming_interval equ 4
txp_reading equ 5

	BYTE streaming_samples
	BYTE streaming_interval
	BYTE t_streaming
	BYTE sensor_state[SENSOR_SIZE]

.sensor_rx EXPAND
	mov a, pkt_service_command_h

	if (a == JD_HIGH_REG_RW_SET) {
		mov a, pkt_service_command_l

		if (a == JD_REG_RW_STREAMING_SAMPLES) {
			.mova streaming_samples, pkt_payload[0]
			goto rx_process_end
		}

		if (a == JD_REG_RW_STREAMING_INTERVAL) {
			mov a, pkt_payload[1]
			ifneq a, 0
				goto streaming_int_ovf
			mov a, pkt_payload[0]
			and a, 0xf0
			ifset ZF
				goto streaming_int_undf
			sl a
			ifset CF
				goto streaming_int_ovf
			mov a, pkt_payload[0]
			goto streaming_int_set

		streaming_int_undf:
			mov a, 16
			goto streaming_int_set
		streaming_int_ovf:
			mov a, 127
		streaming_int_set:
			mov streaming_interval, a
			add a, t16_1ms
			mov t_streaming, a
			// goto rx_process_end
		}

		goto rx_process_end
	}

	if (a == JD_HIGH_REG_RW_GET) {
		mov a, pkt_service_command_l

		if (a == JD_REG_RW_STREAMING_SAMPLES) {
			set1 tx_pending.txp_streaming_samples
		}

		if (a == JD_REG_RW_STREAMING_INTERVAL) {
			set1 tx_pending.txp_streaming_interval
		}

		goto rx_process_end
	}


	if (a == JD_HIGH_REG_RO_GET) {
		mov a, pkt_service_command_l

		if (a == JD_REG_RO_READING) {
			set1 tx_pending.txp_reading
			// goto rx_process_end
		}
		
		// goto rx_process_end
	}

	goto rx_process_end
ENDM

.sensor_process EXPAND
	mov a, streaming_samples
	ifset ZF
	  goto skip_stream
	.t16_chk t16_1ms, t_streaming, <goto do_stream>
	goto skip_stream
do_stream:
	.disint
		mov a, streaming_samples
		ifclear ZF
			dec streaming_samples
	engint
	.t16_set t16_1ms, t_streaming, streaming_interval
	set1 tx_pending.txp_reading
	goto loop
skip_stream:
ENDM

.sensor_prep_tx EXPAND
	if (tx_pending.txp_streaming_samples) {
		set0 tx_pending.txp_streaming_samples
		.setcmd JD_HIGH_REG_RW_GET, JD_REG_RW_STREAMING_SAMPLES
		.mova pkt_payload[0], streaming_samples
		.mova pkt_size, 1
		ret
	}

	if (tx_pending.txp_streaming_interval) {
		set0 tx_pending.txp_streaming_interval
		.setcmd JD_HIGH_REG_RW_GET, JD_REG_RW_STREAMING_INTERVAL
		.mova pkt_payload[0], streaming_interval
		.mova pkt_size, 4
		ret
	}

	if (tx_pending.txp_reading) {
		set0 tx_pending.txp_reading
		_cnt => 0
	.repeat SENSOR_SIZE
		.mova pkt_payload[_cnt], sensor_state[_cnt]
		_cnt => _cnt + 1
	.endm
		.mova pkt_size, SENSOR_SIZE
		.setcmd JD_HIGH_REG_RO_GET, JD_REG_RO_READING
		ret
	}
ENDM

