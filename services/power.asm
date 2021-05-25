#define SERVICE_CLASS 0x1fa4c95a

	BYTE	t_sample

/*
TODO:
  send PWR packet every ~500 ms while limiter is enabled
  monitor limiter - input on PIN_LIMITER no pull
    - LED ~10% ON when providing power
	- LED normal blinking when not providing power
  on PWR cmd - disable limiter (output 0 on PIN_LIMITER) for 1000ms

*/

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
ENDM

serv_rx:
	goto rx_process_end

.serv_ev_payload EXPAND
	// no payloads
ENDM

	.ev_impl
