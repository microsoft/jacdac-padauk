> [!IMPORTANT]
> The Jacdac project has moved to https://github.com/jacdac. 
> Support for the PADAUK is deprecated. Contact us if you have questions. 

# Jacdac PADAUK

This repository contains an implementation of Jacdac protocol and various services for the PADAUK family of microcontrollers,
in particular the PADAUK PMS150C, PMS171B, and PMS131.

* Read more about Jacdac at https://aka.ms/jacdac

## Folders

* `jd` contains implementation of Jacdac protocol
* `services` contains implementation of various Jacdac services
* `genid` contains a Win32 console application used to generate random Jacdac device identifiers (this is called by PADAUK writer software)
* `scripts` contains various utility scripts (they are not currently used in build process)
* `jm-*` contains project files and `main.asm` files for several Jacdac modules; they each include the base Jacdac implementation and a single service

If you create a new device folder, run `./check.sh` script to check for duplicate firmware IDs.

## Requirements

To run (software) UART at 1mbaud (as required by Jacdac), the MCU has to run at 8MHz (or more, but PADAUK chips only do up to 8MHz).
Most PADAUK chips require LVD setting of 3.5V to operate at 8MHz, which implies supply of ~3.7V, which is not possible to get reliably
from the Jacdac bus. Additionally, all Jacdac signalling uses 3.3V.

We thus recommend chips that can run at 8MHz and 3.3V with low voltage detector set to 3.0V.
Additionally, we require the 16-bit timer, an 8-bit timer, 64 bytes of memory, and 1kW of program memory.

This limits the chips to:
* PMS150C - $0.03; 64 bytes / 1kW - too small for many services!
* PMS171B - $0.06; x8-bit timer, 8-bit ADC; 96 bytes / 1.5kW
* PMS130 - 2x8-bit timer, 12-bit ADC; 88 bytes / 1.5kW
* PMS131 - $0.08; 2x8-bit timer, 12-bit ADC; 96 bytes / 1.5kW
* PFS172 - $0.08; 2x8-bit timer, 8-bit ADC; 128 bytes / 2kW; re-flashable
* PFS122 - $0.06; 2x8-bit timer, 12-bit ADC; 128 bytes / 2kW; re-flashable

We've had most success with PFS122.

## Basic architecture

The main loop of the program:
* captures current time (based on T16 timer, which is set to increment every 4us)
* sets "pending announce" bit every ~500ms (really 512*1024us)
* triggers transmission, when transmission timer expires (if there are pending TX bits)
* does any service-specific processing (like probing the button)

For reception,
there is TM2 (8-bit timer) interrupt triggering every 8us (64T (instructions)) which checks if the Jacdac line was pulled low.
(A pin interrupt could be possibly used instead, but the pin with interrupt is typically missing
on smallest packages.)
TM2 is the only source of interrupts ever enabled.

Once the packet is received, it is processed by service-specific code (while still in interrupt context).
There is typically a single pending TX bit allocated to each possible response to be sent from PADAUK,
and the packet processing code sets that bit upon request received.

The transmission code prepares data for outgoing packets based on pending TX bits
after the initial low-pulse has been generated.
This way, a single buffer is used for transmission and reception.

Flags for different responses are independent, meaning there can be multiple pending responses
(which may happen often when a client asks quickly for contest of several registers).

### Stack

There are 3 words of stack allocated.

The main loop never uses any stack (never calls anything) while the interrupts are enabled.

The RX process is triggered from interrupt and pushes current A/F registers, so it uses two words
of stack.
Then it sets up a nested interrupt which will eat one more word
(which is immediately popped in timeout-handling code so it can do one level of calls).

The TX code runs with interrupts disabled, so it can do 3 levels of calls (but only does 1 at the moment).

### Reception

Once the interrupt is triggered the reception process proceeds as follows:
* set flag that we're in RX
* setup TM2 to expire in ~136us
* wait for line to come high
* setup variables for reception
* wait for first start bit (*)
* setup TM2 to expire in 16T
* get 8 bits of data
* go to (*)

The reception buffer will often overflow - the additional data is discarded in that case.

When the interrupt is triggered when the RX flag is already set (timeout condition), the incoming packet is processed:
* first, we check if the packet is an announce from a client, and if so we blink the status LED for 50us
  (this is before checking size or CRC, as these packets typically exceed our buffer size, but we are only interested
  in their headers anyways)
* check if packet is addressed to current device
* check if the packet didn't overflow the reception buffer
* check CRC
* check if this is a command
* check if this is for current version of Jacdac (VNEXT flag not set)
* if some of these conditions are not met, skip the packet
* if ACK was requested, record that we need to send ACK
* process packet according to control or custom service logic, setting various pending TX flags
* reset TM2 back to the 8us period
* return from interrupt

### Transmission

The transmission code performs the following steps:
* disables interrupts
* if the line is already low (TX/RX race detected) it jumps to the interrupt handler
* pulls the line low
* fills the device id field of outgoing packet
* pull the line high
* set TM2 for ~50us
* prepare outgoing packet based on pending TX bits
* compute CRC (CRC of packet size and device id is pre-computed by genid)
* wait for TM2 to expire
* transmit bytes
* send final break
* reset TM2 back for the 8us
* enable interrupts
* go back to main loop

## Programming

To build programs you'll need to obtain the [PADAUK IDE](http://www.padauk.com.tw/en/technical/index.aspx?kind=26).
To flash the microcontroller you'll need to also download the program writer and obtain a physical hardware programmer.

The following warnings are expected:
```
...\jdheader.asm(...): The calculation of Stack maybe error !
...\jdheader.asm(...): The code is overlapped. [FPPA 0, Interrupt] : ... to ...
```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
