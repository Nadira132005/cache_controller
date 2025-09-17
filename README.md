# Cache Controller Implementation

[![Verilog](https://img.shields.io/badge/Verilog-EDA-blue?style=flat&logo=verilog)](https://www.verilog.com/)

This project implements a **4-way set-associative cache controller** in Verilog as part of a Computer Networks (CN) course project. The design supports read and write operations from the CPU, handles cache hits and misses, eviction using a pseudo-LRU policy, and interaction with main memory and physical cache banks. It features a 32-bit address space with 64-byte blocks (16 words per block) and 128 sets across 4 banks.

## Overview

The cache controller manages data between the CPU and main memory, reducing access latency by storing frequently used blocks in cache lines. Key functionalities include:

- **Address Decoding**: Splits CPU address into tag (21 bits), set index (7 bits), and block offset (4 bits).
- **Hit/Miss Detection**: Checks 4 candidate lines per set for tag matches.
- **Replacement Policy**: Pseudo-LRU using 2-bit age counters per line (oldest selected on miss).
- **Write Policy**: Write-back (dirty bit tracks modifications; evict only if dirty on replacement).
- **Eviction Handling**: Writes back dirty blocks to memory before allocating new ones.
- **Data Alignment**: Selects specific words from blocks and replaces words on writes.

The design is modular, with separate components for block selection, word replacement, and D flip-flops for synchronization.

## Architecture

### Key Parameters
| Parameter       | Value | Description |
|-----------------|-------|-------------|
| `WORD_SIZE`     | 32    | Bits per word |
| `BLOCK_OFFSET`  | 4     | Bits for word offset (16 words/block) |
| `SETS`          | 128   | Number of sets per bank |
| `SETS_BITS`     | 7     | Bits for set index |
| `AGE_BITS`      | 2     | Bits for pseudo-LRU age (4 states) |
| `TAG_BITS`      | 21    | Bits for tag |
| `BLOCK_DATA_WIDTH` | 512 | Bits per block (64 bytes) |
| `DIRTY_BIT`     | 1     | Dirty flag per line |
| `VALID_BIT`     | 1     | Valid flag per line |
| `BANK`          | 4     | Ways/associativity |

### Cache Line Structure
Each candidate (line) consists of:
- Valid bit (1 bit)
- Dirty bit (1 bit)
- Age (2 bits)
- Tag (21 bits)
- Data block (512 bits)

Total: 536 bits per candidate.

### State Machine
The controller uses a 5-state FSM:
1. **IDLE**: Wait for CPU request.
2. **CHECK_HIT**: Read candidates from cache; detect hit/miss.
3. **EVICT**: Write back dirty LRU line to memory (if needed).
4. **ALLOCATE**: Fetch block from memory on miss.
5. **SEND_TO_CACHE**: Write to cache (on write) or return data to CPU (on read).

On hit: Directly service read/write. On miss: Evict if necessary, allocate, then service.

### Modules
- **`cache_controller.v`**: Core FSM, hit/miss logic, age updates, bank selection.
- **`block_selector.v`**: Multiplexes a word from the block based on offset.
- **`replacer.v`**: Replaces a word in a block for write operations.
- **`flipflop_d.v`**: Parameterized D flip-flop for registering signals.

### Interfaces
- **CPU Side**: `cpu_req_addr`, `cpu_req_datain`, `cpu_res_dataout`, `cpu_res_ready`, `cpu_req_rw` (0=read,1=write), `cpu_req_enable`.
- **Memory Side**: `mem_req_addr`, `mem_req_dataout`, `mem_req_datain`, `mem_req_rw`, `mem_req_enable`, `mem_req_ready`.
- **Cache Side**: `cache_enable`, `cache_rw`, `cache_ready`, 4x `candidate_*` inputs, `age_*` outputs, `candidate_write`, `bank_selector` (one-hot).

Age updates:
- **Hit**: Reset accessed line to 0; increment younger valid lines.
- **Miss**: Increment all valid lines.

## Setup and Simulation

### Prerequisites
- Icarus Verilog (`iverilog`, `vvp`) for compilation and simulation.
- GTKWave for waveform viewing (optional).
- Linux/Unix environment.

### Build and Run
1. Clone or navigate to the project directory:
   ```
   cd /path/to/cache_controller
   ```

2. Run the simulation script:
   ```bash
   ./start_sim.sh
   ```
   This compiles the design (`iverilog -g2012`) and runs the testbench (`vvp`).

3. View waveforms (uncomment in `start_sim.sh`):
   ```bash
   gtkwave cache_controller_tb.vcd &
   ```

To stop the simulation forcefully:
```bash
./kill_sim.sh  # Assumes it kills the process
```

### Testbench (`cache_controller_tb.sv`)
The SystemVerilog testbench includes 8 test cases covering:
1. Read hit.
2. Read miss (no eviction).
3. Write hit.
4. Write miss (no eviction).
5. Write miss with eviction.
6. Read miss with eviction.
7. Read miss with empty slots.
8. Write miss with empty slots.

It generates a VCD dump (`cache_controller_tb.vcd`) for verification. Monitors state transitions, hits/misses, and data flows.

### Expected Behavior
- Hits: Immediate response (~1-2 cycles).
- Misses without eviction: Memory access + allocate (~4-5 cycles).
- Misses with eviction: Evict + allocate + service (~6-8 cycles).
- Age counters update correctly; dirty bits set on writes.