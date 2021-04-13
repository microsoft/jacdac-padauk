blink_identify equ 3
blink_identify_was0 equ 4
blink_disconnected equ 5
blink_status_on equ 6

.blink_process EXPAND
	PA.JD_LED = 0
	if (blink.blink_identify) {
		if (!blink.blink_identify_was0) {
			ifclear t16_16ms.6
				set1 blink.blink_identify_was0
		} else {
			PA.JD_LED = 1
			if (t16_16ms.6) {
				dec blink
				set0 blink.blink_identify_was0
				if (!blink.blink_identify) {
					.disint
					call got_client_announce
					engint
				}
			}
		}
	} else {
		if (t16_262ms.3) {
			set0 blink.blink_identify_was0
		} else {
			if (!blink.blink_identify_was0) {
				set1 blink.blink_identify_was0
				set0 blink.blink_status_on
			}
		}
		if (blink.blink_disconnected) {
			ifset t16_262ms.2
				PA.JD_LED = 1
		} else {
			mov a, t16_262ms
			sr a
			sub a, blink
			and a, 0x02
			ifclear ZF
				set1 blink.blink_disconnected
			if (blink.blink_status_on) {
				PA.JD_LED = 1
			}
		}
	}
ENDM

.blink_rx EXPAND
	// this checks for announce packets
	// note that we do that before checking for size or CRC - the announce from the client may be bigger than we support
	// however, the flag bits we're interested in are at the beginning
	mov a, frm_flags
	// if any of these flags is set, we don't want it
	and a, (1 << JD_FRAME_FLAG_VNEXT)|(1 << JD_FRAME_FLAG_COMMAND)|(1 << JD_FRAME_FLAG_ACK_REQUESTED)|(1 << JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS)
	// service number and cmd must be all 0
	or a, pkt_service_number
	or a, pkt_service_command_h
	or a, pkt_service_command_l
	if (ZF) {
		mov a, pkt_payload[1]
		and a, JD_AD0_IS_CLIENT_MSK
		if (!ZF) {
			call got_client_announce
			PA.JD_LED = 1
			.delay 250
			PA.JD_LED = 0
			goto _do_leave
		}
	}
ENDM

.blink_impl EXPAND
got_client_announce:
	set0 blink.blink_disconnected
	mov a, t16_262ms
	sr a
	and a, 0x3
	set0 blink.0
	set0 blink.1
	or blink, a
	ret
ENDM