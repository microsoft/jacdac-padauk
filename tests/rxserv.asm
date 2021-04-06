#define JD_REG_RW_STREAMING_SAMPLES 0x03
#define JD_REG_RW_STREAMING_INTERVAL 0x04

#define JD_REG_RO_READING 0x01

#define SENSOR_SIZE 1

	BYTE streaming_samples
	BYTE streaming_interval
	BYTE t_streaming
	BYTE sensor_state[SENSOR_SIZE]

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
			sl a
			ifset CF
				goto streaming_int_ovf
			mov a, pkt_payload[0]
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

.sensor_stream EXPAND
	mov a, streaming_samples
	ifset ZF
	  goto skip_stream
	.t16_chk t16_1ms, t_streaming, <goto do_stream>
	goto skip_stream
do_stream:
	disgint
		mov a, streaming_samples
		ifclear ZF
			dec streaming_samples
	engint
	.t16_set t16_1ms, t_streaming, streaming_interval
	set1 tx_pending.txp_reading
	goto loop
skip_stream:
ENDM
