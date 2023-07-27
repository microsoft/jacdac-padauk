#define SERVICE_CLASS 0x1cab054c

#define JD_LIGHT_BULB_EV_ON JD_EV_ACTIVE
#define JD_LIGHT_BULB_EV_OFF JD_EV_INACTIVE

#define JD_LIGHT_BULB_REG_BRIGHTNESS JD_REG_RW_INTENSITY
#define JD_LIGHT_BULB_REG_DIMMEABLE  0x80

txp_brightness equ txp_serv0
txp_dimmealbe equ txp_serv1
    BYTE brightness_l
	BYTE brightness_h

.serv_init EXPAND
    brightness_l = 0
    brightness_h = 0
ENDM

.serv_process EXPAND
    .ev_process
ENDM

.serv_prep_tx EXPAND
    if (txp_brightness){
        set0 txp_brightness
        .setcmd JD_HIGH_REG_RW_GET, JD_LIGHT_BULB_REG_BRIGHTNESS
        .mova pkt_size, 2
        .mova pkt_payload[0], brightness_l
        .mova pkt_payload[1], brightness_h
        ret
    }
    if (txp_dimmealbe){
        set0 txp_dimmealbe
        .mova pkt_payload[0], EN_DIMMEABLE
        .mova pkt_size, 1
        ret
    }
    ifset txp_event
        goto ev_prep_tx
ENDM

serv_rx:
    mov a, pkt_service_command_h
    if (a == JD_HIGH_REG_RW_GET){
        mov a, pkt_service_command_l
        if (a == JD_LIGHT_BULB_REG_BRIGHTNESS){
            set1 txp_brightness
        }
        goto rx_process_end
    }
    if (a == JD_HIGH_REG_RO_GET){
        mov a, pkt_service_command_l
        if (a == JD_LIGHT_BULB_REG_DIMMEABLE){
            set1 txp_dimmealbe
        }
        goto rx_process_end
    }
    if (a == JD_HIGH_REG_RW_SET){
        mov a, pkt_service_command_l
        if (a == JD_LIGHT_BULB_REG_BRIGHTNESS){
            // lower byte is ignored
            .mova brightness_l, pkt_payload[0] 
            .mova brightness_h, pkt_payload[1]
#if EN_DIMMEABLE
            TM3B = brightness_h
            if (!ZF){
                $ TM3C ILRC, PB7, PWM
            } else {
                // disable timer
                TM3C = 0
                PB.PIN_LIGHTBULB = 0
            }
#else
            if (!ZF){
                PA.PIN_LIGHTBULB = 1
            } else {
                PA.PIN_LIGHTBULB = 0
            }
#endif
        }
    }

    goto rx_process_end

.serv_ev_payload EXPAND


ENDM


    .ev_impl