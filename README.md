# Problem-84-Memory-Initializer-Clear-FSM-Wrapper
## Overview 
A Memory Initializer / Clear FSM Wrapper is a protective gatekeeper around a RAM block (SRAM).

When a hardware system powers on or resets, the memory cells in an SRAM contain completely random, unpredictable binary data (1s and 0s). If your processor or digital system tries to read from the memory before writing to it, it can process garbage data, triggering unexpected bugs, security risks, or software crashes.

The Memory Initializer wrapper prevents this by seizing control of the SRAM during reset, systematically overwriting every single memory address with zero (0x00), and only handing control back to your main system once the memory is clean.

## Initialization Strategy & Trade-offs

A common architectural question regarding memory wrappers is whether memory should be cleared **upfront during boot** or **on-demand per address access**. This design implements an **upfront 256-cycle sweep**.

---

### Why Upfront Sweep Over On-Demand Clearing?

#### 1. On-Demand Clearing (Not Used)
An on-demand scheme clears a memory address only when a user issued a read/write to that specific address. 
* **Complexity:** Requires a 256-bit tracking register array (one valid/dirty bit per address) to record which locations have been cleared.
* **Latency Overhead:** Every user memory request must pass through tracking lookup logic. Uninitialized reads incur variable-delay wait states.
* **Area Penalty:** Storing state flags for every memory row significantly increases flip-flop count and logic utilization.

#### 2. Upfront Boot-Time Sweep (Implemented)
The wrapper locks user access immediately upon reset release and iterates through every address (`0x00` to `0xFF`) sequentially before asserting `init_done`.
* **Minimal Hardware:** Requires only a single 8-bit counter and a 1-bit FSM state register.
* **Zero Latency Penalty:** Once initialized, user access experiences **0 clock cycles of latency penalty**—read and write signals connect directly through multiplexers.
* **Instantaneous Boot Time:** On a standard system running at 100 MHz, a 256-cycle sweep completes in **2.56 microseconds** ($\mu\text{s}$), finishing long before the main processor completes its own power-on reset (POR) sequence.

---

### Startup Execution Flow

```text
[ Power-On / System Reset (rst_n = 0) ]
                   │
                   ▼
[ Sequential Sweep: 256 Clock Cycles ] ──► Overwrites 0x0000 to addresses 0x00..0xFF
                   │                       User access blocked (init_done = 0)
                   ▼
[ Handover Control (init_done = 1) ]  ──► All memory addresses guaranteed clean
                   │                       User granted full-speed access
                   ▼
[ Normal Operation Phase ]
```
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

# Internal Regs 
1. States 2. clear_addr [7:0] 
## Finite State Machine (FSM) States

The module utilizes a 1-bit State Register (`state`) to transition between initialization and normal user operation:

```text
                  +-----------------------------------+
                  |          STATE 0 (CLEAR)          |
                  | - Blocks user access              |
                  | - Sweeps addresses 0x00 to 0xFF   |
                  | - Writes 0x0000 to every location |
                  | - Holds init_done = 0             |
                  +-----------------+-----------------+
                                    |
                                    | (clear_addr == 0xFF)
                                    v
                  +-----------------------------------+
                  |          STATE 1 (DONE)           |
                  | - Handover control to user system |
                  | - Routes user_addr & user_din     |
                  | - Asserts init_done = 1           |
                  | - Holds state until next rst_n    |
                  +-----------------------------------+
```
---

### Option 2: ASCII Text Block Diagram

A traditional plain-text schematic that works inside any standard Markdown code block without needing renderer extensions.

```text
                     +-----------------------+
                     |                       |
   clk  ------------>|                       |------------> user_dout[15:0]
   rst_n ----------->|                       |------------> init_done
user_addr[7:0] ----->|   sram_init_wrapper   |------------> sram_addr[7:0]
user_din[15:0] ----->|                       |------------> sram_din[15:0]
 user_we ------------>|                       |------------> sram_we
sram_dout[15:0] ---->|                       |
                     |                       |
                     +-----------------------+
```
## clear_address
The memory clear operation runs **sequentially, address by address, automatically upon reset**. It does **not** happen all at once in a single clock cycle, nor is it triggered on-demand when a user requests an address.

### Step-by-Step Operation

#### 1. Sequential Sweeping (1 Address per Clock Cycle)
Physical SRAM hardware possesses a single set of address and write-control lines, making it physically impossible to write to all 256 addresses simultaneously in one clock cycle. 

The wrapper operates as an automated hardware counter loop:

* **Clock Cycle 1:** FSM targets Address `0x00` and writes `0x0000`.
* **Clock Cycle 2:** Counter increments to Address `0x01` and writes `0x0000`.
* **Clock Cycle 3:** Counter increments to Address `0x02` and writes `0x0000`.
* **...**
* **Clock Cycle 256:** Counter reaches final Address `0xFF` and writes `0x0000`.

> **Note:** For a 256-word memory array, initialization takes exactly **256 consecutive clock cycles** to complete the full sweep.

#### 2. Automatic Power-On / Reset Trigger
The clearing process initiates automatically as soon as the active-low reset signal (`rst_n`) is released (`0` → `1`). No external intervention or user address request is required to start the process.

#### 3. Blind Zero-Write
The wrapper does not execute a "read-before-write" check. Instead, it systematically and forcibly overwrites every location with `0x0000`, eliminating power-on garbage data.

#### 4. Hardware Access Interlock
During the 256-cycle sweep:
* `init_done` remains driven LOW (`0`).
* The internal multiplexers **isolate and block** all incoming user signals (`user_addr`, `user_din`, `user_we`).
* Any external attempt by the user system to read or write memory during this phase is safely ignored.

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
<img width="959" height="328" alt="image" src="https://github.com/user-attachments/assets/3eef9ade-c60c-4a26-b63d-051e8d14c9fe" />

### Simulation Terminal
<img width="820" height="416" alt="image" src="https://github.com/user-attachments/assets/e6af9da4-0261-4579-b843-3b3dabe8e82f" />

<img width="815" height="330" alt="image" src="https://github.com/user-attachments/assets/b9bde643-8925-4b15-9da9-75cd28a270cd" />


