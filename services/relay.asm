#define SERVICE_CLASS 0x183fe656

#define JD_RELAY_VARIANT_ELECTROMECHANICAL 0x1
#define JD_RELAY_VARIANT_SOLID_STATE 0x2
#define JD_RELAY_VARIANT_REED 0x3

#define JD_RELAY_EV_ON JD_EV_ACTIVE
#define JD_RELAY_EV_OFF JD_EV_INACTIVE

#define JD_RELAY_REG_CLOSED JD_REG_RW_INTENSITY

txp_closed equ txp_serv0

    BYTE  closed
    BYTE  prev_closed

.serv_init EXPAND
    PAC.PIN_RELAY_DRIVE =   1 // output
    PAC.PIN_RELAY_LED   =   1
    PA.PIN_RELAY_DRIVE  =   0
    prev_closed = 0
    closed = 0
ENDM

.serv_process EXPAND
    mov a, closed
    if (a != prev_closed){
        mov prev_closed, a
        goto ev_send
    }
    .ev_process
ENDM

.serv_prep_tx EXPAND
    if (txp_closed){
        set0 txp_closed
        .setcmd JD_HIGH_REG_RW_GET, JD_RELAY_REG_CLOSED
        .mova pkt_payload[0], closed
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
        if (a == JD_RELAY_REG_CLOSED){
            set1 txp_closed 
        }
        goto rx_process_end    
    }
    if (a == JD_HIGH_REG_RW_SET) {
        mov a, pkt_service_command_l
        if (a == JD_RELAY_REG_CLOSED) {
            mov a, pkt_payload[0]
            if (ZF){
                closed = 0
                PA.PIN_RELAY_DRIVE = 0
            } else {
                closed = 1
                PA.PIN_RELAY_DRIVE = 1
            }
        }
        goto rx_process_end    
    }
    goto rx_process_end

.serv_ev_payload EXPAND
    if (closed){
        .mova pkt_service_command_l, JD_EV_ACTIVE
    } else {
        .mova pkt_service_command_l, JD_EV_INACTIVE
    }
ENDM

    .ev_impl