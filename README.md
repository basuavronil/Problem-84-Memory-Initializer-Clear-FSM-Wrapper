# Problem-84-Memory-Initializer-Clear-FSM-Wrapper
## Overview 
A Memory Initializer / Clear FSM Wrapper is a protective gatekeeper around a RAM block (SRAM).

When a hardware system powers on or resets, the memory cells in an SRAM contain completely random, unpredictable binary data (1s and 0s). If your processor or digital system tries to read from the memory before writing to it, it can process garbage data, triggering unexpected bugs, security risks, or software crashes.

The Memory Initializer wrapper prevents this by seizing control of the SRAM during reset, systematically overwriting every single memory address with zero (0x00), and only handing control back to your main system once the memory is clean.

## Input and Output Port 
## Pinout / Interface Ports

### Clock & Reset
- `clk` *(Input, 1-bit)*: System Clock.
- `rst_n` *(Input, 1-bit)*: Asynchronous Active-Low Reset.

### User / System Interface
- `user_addr` *(Input, `ADDR_WIDTH` bits)*: Target memory address requested by the user system.
- `user_din` *(Input, `DATA_WIDTH` bits)*: Data payload requested to be written by the user system.
- `user_we` *(Input, 1-bit)*: User write enable signal (`1` = Write, `0` = Read).
- `user_dout` *(Output, `DATA_WIDTH` bits)*: Data output read back to the user system.
- `init_done` *(Output, 1-bit)*: Initialization status flag (`0` = Memory reset in progress, `1` = Ready for user access).

### SRAM Hardware Interface
- `sram_addr` *(Output, `ADDR_WIDTH` bits)*: Multiplexed address line connected directly to physical SRAM.
- `sram_din` *(Output, `DATA_WIDTH` bits)*: Multiplexed write data line connected directly to physical SRAM.
- `sram_we` *(Output, 1-bit)*: Multiplexed write enable control connected directly to physical SRAM.
- `sram_dout` *(Input, `DATA_WIDTH` bits)*: Direct data output line from physical SRAM.
# Interface & Interconnect Diagram

Below is the pinout and connection structure for the **Memory Initializer / Clear FSM Wrapper**, showing how the user logic, the wrapper module, and the target physical SRAM interface with one another.

---

## 1. Top-Level System Interconnect

```text
+-------------------+                      +---------------------------------------+                      +-------------------+
|                   |                      |    MEMORY INITIALIZER / FSM WRAPPER   |                      |                   |
|                   | ------ user_addr --->| [Input]                       [Output] | ------ sram_addr --->|                   |
|                   | ------ user_din  --->| [Input]                       [Output] | ------ sram_din  --->|                   |
|                   | ------ user_we   --->| [Input]                       [Output] | ------ sram_we   --->|                   |
|    USER LOGIC     |                      |                                       |                      |   PHYSICAL SRAM   |
|   / SYSTEM BUS    | <----- user_dout ----| [Output]                       [Input] | <----- sram_dout ----|      MEMORY       |
|                   |                      |                                       |                      |                   |
|                   | <----- init_done ----| [Output]                              |                      |                   |
|                   |                      |                                       |                      |                   |
|                   | ------ clk --------->| [Input]                               |                      |                   |
|                   | ------ rst_n -------->| [Input]                               |                      |                   |
+-------------------+                      +---------------------------------------+                      +-------------------+
```
## Outputs 
### Waveforms 
### Simulation Terminal
