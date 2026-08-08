# AES-128 Hardware Accelerator with AXI4-Lite Interface

## Overview
This project is a fully custom, 11-stage pipelined AES-128 encryption accelerator written in Verilog. It is designed to be integrated into an SoC (like a Xilinx Zynq-7000) where an ARM processor can easily offload heavy cryptography tasks to the FPGA fabric.

Instead of just writing the AES math, I built a complete **AXI4-Lite memory-mapped wrapper** around the core so a C programmer can control the hardware simply by reading and writing to memory addresses.

## How the Architecture Flows
If you are looking at the source code, here is the high-level flow of how a block of data actually moves from software, through the hardware, and back.

### 1. The "Loading Dock" (AXI4-Lite Wrapper)
The ARM CPU runs on a 32-bit architecture, but AES requires 128-bit blocks. The CPU cannot send 128 bits at once. To solve this, the `aes_axi4lite_wrapper.v` acts as a translator:
*   The CPU makes four separate 32-bit writes to hand over the secret key, and four more to hand over the plaintext.
*   The wrapper safely latches these 32-bit chunks into holding registers.
*   Once the CPU writes the final piece of the key (`KEY_3`), a `key_valid` flag unlocks the core.
*   When the CPU writes to the Control register (`0x00`), the wrapper tapes those 32-bit chunks into massive 128-bit wires and fires a 1-clock-cycle `start_pulse` into the AES pipeline.

### 2. The 11-Stage Pipeline
Once the `start_pulse` fires, the data enters the `top.v` module.
*   The datapath is fully pipelined with 11 hardware stages (Initial AddRoundKey + 10 standard AES rounds).
*   I placed arrays of D-Flip Flops between every single round. This means the core can accept a new 128-bit block of plaintext on every single clock cycle without waiting for the previous block to finish.
*   To track when the data is ready, I used an 11-bit shift register (`inflight_pipe`). A `1` travels down this pipe alongside the data. When the `1` pops out the other side, the AXI wrapper knows the ciphertext is ready.

### 3. The Key Scheduler Trade-off (Fully Combinational)
One of the biggest design decisions I made was leaving the Key Expansion unit **fully combinational**. Instead of pipelining the key generation, the `key_expansions.v` module takes the initial 128-bit key and instantly explodes it into a 1408-bit bus containing all 11 round keys in cycle 0.

**The Trade-off:**
*   **Pros:** Zero-latency key switching. If the CPU changes the key, all 11 round keys are ready instantly without needing a multi-cycle state machine to generate them.
*   **Cons:** Massive critical path. Synthesizing 10 consecutive rounds of S-Boxes in a single clock cycle dropped the maximum clock frequency ($F_{max}$) to ~36 MHz. If pure throughput was the only goal, I would have pipelined the key scheduler to match the datapath, which would push the clock speed well past 150 MHz.

## Memory Map (Software Interface)
If you want to write a C driver for this IP, here are the byte offsets:

| Offset | Name | Type | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | CTRL | Write | Write `1` to bit 0 to start encryption. |
| `0x04` | STATUS | Read | Bit 0 = Busy, Bit 1 = Idle, Bit 2 = Done. |
| `0x08` - `0x14` | KEY_0 to KEY_3 | Write | 128-bit Key (Must write KEY_3 last to validate). |
| `0x18` - `0x24` | DATA_IN_0 to _3 | Write | 128-bit Plaintext block. |
| `0x28` - `0x34` | DATA_OUT_0 to _3 | Read | 128-bit Ciphertext output. |

