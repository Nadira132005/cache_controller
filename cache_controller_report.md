# Cache Controller Project: Final Report

## 1. Overview of the Design and Implementation Process

The cache controller project was developed to simulate and verify the behavior of a set-associative cache system, focusing on realistic CPU-cache-memory interactions. The design implements a 4-way set-associative cache with 128 sets, 16 words per block (512 bits), and a Least Recently Used (LRU) replacement policy. The controller manages read and write requests from the CPU, handles cache hits and misses, and coordinates with main memory for block allocation and eviction.

The implementation process began with a clear specification of the cache architecture, including parameterization for word size, block size, set count, and associativity. The main modules developed were:

- **cache_controller.v**: The core finite state machine (FSM) that orchestrates cache operations, manages candidate lines, and interfaces with both the CPU and memory.
- **replacer.v**: A utility module for updating a specific word within a cache block, used during write operations.
- **cache_controller_tb.sv**: A comprehensive SystemVerilog testbench that simulates a variety of CPU access patterns, including hits, misses, write-backs, and edge cases.

The design emphasizes modularity and parameterization, allowing for easy adaptation to different cache configurations. The FSM in the controller ensures correct sequencing of operations, including hit detection, LRU updates, dirty block eviction, and block allocation from memory.

## 2. Technical Challenges Encountered and Solutions Implemented

### a. LRU Replacement Policy

**Challenge:** Implementing an efficient and correct LRU policy for a 4-way set-associative cache, ensuring that the "oldest" line is always selected for replacement on a miss.

**Solution:** Each cache line maintains a 2-bit age field. On every access, the controller updates the ages: the accessed line is set to 0, and all valid lines with a lower age are incremented. This logic is implemented combinationally and verified in the testbench. On miss all ages are updated because the block that will be replaced is the oldest one and overflow will correctly make it the youngest. The LRU candidate is selected by finding the line with the maximum age.

### b. Handling Write-Backs and Dirty Blocks

**Challenge:** Correctly managing dirty blocks during eviction, ensuring that modified data is written back to memory before replacement.

**Solution:** The controller checks the dirty and valid bits of the LRU candidate on a miss. If eviction is required, the block is written to memory before the new block is allocated. The FSM includes explicit EVICT and ALLOCATE states to sequence these operations, and the testbench verifies correct memory transactions.

### c. Synchronization and Signal Timing

**Challenge:** Ensuring correct synchronization between the controller, cache, and memory, especially with respect to ready/enable handshakes and clocking.

**Solution:** The design uses registered signals and flip-flop modules to synchronize candidate data and control signals. The testbench provides realistic clocking and ready/enable pulses, and the controller FSM waits for appropriate ready signals before proceeding to the next state.

### d. Parameterization and Modularity

**Challenge:** Making the design flexible and reusable for different cache sizes and associativities.

**Solution:** All key parameters (word size, block size, set count, associativity, etc.) are defined as module parameters. The replacer and block_selector modules are also parameterized, supporting easy scaling and adaptation.

### e. Comprehensive Verification

**Challenge:** Creating a testbench that covers all relevant scenarios, including hits, misses, write-backs, and edge cases (e.g., empty candidates).

**Solution:** The SystemVerilog testbench (`cache_controller_tb.sv`) includes tasks for read/write requests, candidate provisioning, and memory response simulation. It runs a suite of test cases covering read/write hits, misses with and without eviction, and operations with empty or partially filled sets. The testbench also generates VCD waveforms for detailed analysis.

## 3. Analysis of Performance Data Collected During Simulations

Simulation results were collected using the testbench, which exercises the cache controller with a variety of access patterns. Key performance metrics include hit rate, miss rate, and the number of memory transactions (reads/writes).

### a. Hit and Miss Behavior

- **Read/Write Hits:** The controller correctly identifies hits in any of the four candidates, updates the LRU ages, and returns data to the CPU with minimal latency (typically within a few cycles).
- **Misses Without Eviction:** When a miss occurs and there is an invalid (empty) candidate, the controller allocates the new block without requiring a write-back, reducing memory traffic.
- **Misses With Eviction:** If all candidates are valid and the LRU candidate is dirty, the controller performs a write-back to memory before allocating the new block. This is correctly sequenced and verified in the testbench.

### b. LRU Policy Effectiveness

Waveform analysis and testbench output confirm that the LRU policy is correctly maintained. After each access, the ages of the candidates are updated as expected, and the oldest line is always selected for replacement. This ensures optimal cache utilization and minimizes unnecessary evictions.

### c. Memory Traffic

The testbench logs show that memory transactions (reads and writes) occur only on misses and evictions, as expected. Write-backs are performed only for dirty blocks, reducing unnecessary memory writes.

### d. Latency and Throughput

- **Cache Hits:** Data is returned to the CPU with low latency, typically within 1-2 cycles after the request.
- **Cache Misses:** Misses incur additional latency due to memory access and possible eviction, but the FSM ensures correct sequencing and minimal stalling.
- **Throughput:** The controller can handle back-to-back requests, with the FSM returning to the IDLE state promptly after each operation.

### e. Edge Case Handling

The testbench includes cases with empty candidates and partially filled sets. The controller correctly identifies free slots and avoids unnecessary evictions, demonstrating robust handling of all scenarios.

## 4. Conclusion

The cache controller project successfully implements a parameterized, modular, and robust set-associative cache controller with LRU replacement and write-back support. The design addresses key technical challenges, including LRU management, dirty block handling, and synchronization. Comprehensive simulation and waveform analysis confirm correct functionality, efficient memory usage, and robust handling of all edge cases. The project provides a solid foundation for further exploration of cache architectures and performance optimization.
# Cache Controller Project: Final Report

## 1. Overview of the Design and Implementation Process

The cache controller project was developed to simulate and verify the behavior of a set-associative cache system, focusing on realistic CPU-cache-memory interactions. The design implements a 4-way set-associative cache with 128 sets, 16 words per block (512 bits), and a Least Recently Used (LRU) replacement policy. The controller manages read and write requests from the CPU, handles cache hits and misses, and coordinates with main memory for block allocation and eviction.

The implementation process began with a clear specification of the cache architecture, including parameterization for word size, block size, set count, and associativity. The main modules developed were:

- **cache_controller.v**: The core finite state machine (FSM) that orchestrates cache operations, manages candidate lines, and interfaces with both the CPU and memory.
- **replacer.v**: A utility module for updating a specific word within a cache block, used during write operations.
- **cache_controller_tb.sv**: A comprehensive SystemVerilog testbench that simulates a variety of CPU access patterns, including hits, misses, write-backs, and edge cases.

The design emphasizes modularity and parameterization, allowing for easy adaptation to different cache configurations. The FSM in the controller ensures correct sequencing of operations, including hit detection, LRU updates, dirty block eviction, and block allocation from memory.

---

## 2. Code Structure and Explanation

### 2.1. `cache_controller.v` — The Main Controller

This is the heart of the project. It implements a finite state machine (FSM) to manage the cache's behavior, including hit/miss detection, LRU management, and memory interactions.

**Key Features:**
- Parameterized for word size, block size, associativity, and more.
- Receives CPU requests and determines if they are cache hits or misses.
- On a miss, checks if eviction is needed (dirty block) and handles write-back.
- Allocates new blocks from memory and updates the cache.
- Manages LRU ages for all candidates.

**Relevant Code:**
```verilog
module cache_controller #(
    parameter WORD_SIZE = 32,  // 32 bits per word
    parameter BLOCK_OFFSET = 4,  // 4 bits for block offset (16 words per block)
    parameter SETS = 128,  // 128 sets in one bank
    parameter SETS_BITS = 7,  // log2(128) = 7 bits for set index
    parameter AGE_BITS = 2,  // 2 bits to represent oldest among 4 candidates
    parameter TAG_BITS = 21,  // 21 bits for tag (32 - BLOCK_OFFSET - log2(SETS))
    parameter BLOCK_DATA_WIDTH = 512,  // 512 bits for data (64 bytes per block)
    parameter DIRTY_BIT = 1,  // 1 bit for dirty flag,
    parameter VALID_BIT = 1,  // 1 bit for valid flag
    parameter BANK = 4  // 4 banks
) (
    input clk,
    input rst_n,
    // ... (signals omitted for brevity)
);
// ... (FSM and logic as in the provided code)
endmodule
```
**Explanation:**
- The FSM transitions through states: IDLE, CHECK_HIT, EVICT, ALLOCATE, SEND_TO_CACHE.
- On a CPU request, the controller checks for a hit among the four candidates.
- If a miss and the LRU candidate is dirty, it writes back to memory before allocation.
- LRU ages are updated on every access, ensuring the oldest line is replaced on a miss.

---

### 2.2. `replacer.v` — Block Word Replacement Utility

This module is used to update a specific word within a cache block, which is essential for write operations (both on hit and miss).

**Relevant Code:**
```verilog
module replacer #(
    parameter WORD_SIZE = 32,
    parameter BLOCK_SIZE = 512,
    parameter NUM_SEGMENTS = 16,
    parameter NUM_SEGMENTS_LOG = 4
) (
    input wire [BLOCK_SIZE-1:0] data_in,
    input wire [NUM_SEGMENTS_LOG-1:0] block_offset,
    input wire [WORD_SIZE-1:0] data_write,
    input wire enable,
    output reg [BLOCK_SIZE-1:0] data_out
);
  always @(*) begin
    data_out = data_in;
    if (enable) begin
      case (block_offset)
        0: data_out[0*WORD_SIZE+:WORD_SIZE] = data_write;
        1: data_out[1*WORD_SIZE+:WORD_SIZE] = data_write;
        // ... up to 15
        15: data_out[15*WORD_SIZE+:WORD_SIZE] = data_write;
        default: ;
      endcase
    end
  end
endmodule
```
**Explanation:**
- The `replacer` module takes a block of data and overwrites the word at the specified offset with new data.
- Used for both write hits (updating a word in a cached block) and write misses (updating a word in a block fetched from memory).

---

### 2.3. `cache_controller_tb.sv` — Testbench

This SystemVerilog testbench simulates a variety of scenarios to verify the cache controller's correctness.

**Key Features:**
- Parameterized to match the cache controller.
- Generates clock and reset signals.
- Provides tasks for CPU read/write requests and candidate provisioning.
- Simulates memory responses and cache readiness.
- Runs a suite of test cases: read/write hits, misses with/without eviction, and edge cases.

**Relevant Code:**
```systemverilog
module cache_controller_tb ();
  // Parameters
  parameter WORD_SIZE = 32;
  parameter BLOCK_OFFSET = 4;
  // ... (other parameters)
  // Signals
  reg clk;
  reg rst_n;
  // ... (other signals)
  // Instantiate the cache controller
  cache_controller #(
      .WORD_SIZE(WORD_SIZE),
      .BLOCK_OFFSET(BLOCK_OFFSET),
      // ...
  ) uut (
      .clk(clk),
      .rst_n(rst_n),
      // ...
  );
  // Clock generation
  always begin
    #5 clk = ~clk;
  end
  // ... (test tasks and test cases)
endmodule
```
**Explanation:**
- The testbench initializes the cache and memory, then applies a series of read and write requests.
- It checks for correct data output, LRU age updates, and proper handling of hits, misses, and evictions.
- VCD waveform dumping is enabled for detailed analysis.

---

## 3. Technical Challenges Encountered and Solutions Implemented

### a. LRU Replacement Policy

**Challenge:** Implementing an efficient and correct LRU policy for a 4-way set-associative cache, ensuring that the "oldest" line is always selected for replacement on a miss.

**Solution:** Each cache line maintains a 2-bit age field. On every access, the controller updates the ages: the accessed line is set to 0, and all valid lines with a lower age are incremented. This logic is implemented combinationally and verified in the testbench. On miss all ages are updated because the block that will be replaced is the oldest one and overflow will correctly make it the youngest. The LRU candidate is selected by finding the line with the maximum age.

### b. Handling Write-Backs and Dirty Blocks

**Challenge:** Correctly managing dirty blocks during eviction, ensuring that modified data is written back to memory before replacement.

**Solution:** The controller checks the dirty and valid bits of the LRU candidate on a miss. If eviction is required, the block is written to memory before the new block is allocated. The FSM includes explicit EVICT and ALLOCATE states to sequence these operations, and the testbench verifies correct memory transactions.

### c. Synchronization and Signal Timing

**Challenge:** Ensuring correct synchronization between the controller, cache, and memory, especially with respect to ready/enable handshakes and clocking.

**Solution:** The design uses registered signals and flip-flop modules to synchronize candidate data and control signals. The testbench provides realistic clocking and ready/enable pulses, and the controller FSM waits for appropriate ready signals before proceeding to the next state.

### d. Parameterization and Modularity

**Challenge:** Making the design flexible and reusable for different cache sizes and associativities.

**Solution:** All key parameters (word size, block size, set count, associativity, etc.) are defined as module parameters. The replacer and block_selector modules are also parameterized, supporting easy scaling and adaptation.

### e. Comprehensive Verification

**Challenge:** Creating a testbench that covers all relevant scenarios, including hits, misses, write-backs, and edge cases (e.g., empty candidates).

**Solution:** The SystemVerilog testbench (`cache_controller_tb.sv`) includes tasks for read/write requests, candidate provisioning, and memory response simulation. It runs a suite of test cases covering read/write hits, misses with and without eviction, and operations with empty or partially filled sets. The testbench also generates VCD waveforms for detailed analysis.

---

## 4. Analysis of Performance Data Collected During Simulations

Simulation results were collected using the testbench, which exercises the cache controller with a variety of access patterns. Key performance metrics include hit rate, miss rate, and the number of memory transactions (reads/writes).

### a. Hit and Miss Behavior

- **Read/Write Hits:** The controller correctly identifies hits in any of the four candidates, updates the LRU ages, and returns data to the CPU with minimal latency (typically within a few cycles).
- **Misses Without Eviction:** When a miss occurs and there is an invalid (empty) candidate, the controller allocates the new block without requiring a write-back, reducing memory traffic.
- **Misses With Eviction:** If all candidates are valid and the LRU candidate is dirty, the controller performs a write-back to memory before allocating the new block. This is correctly sequenced and verified in the testbench.

### b. LRU Policy Effectiveness

Waveform analysis and testbench output confirm that the LRU policy is correctly maintained. After each access, the ages of the candidates are updated as expected, and the oldest line is always selected for replacement. This ensures optimal cache utilization and minimizes unnecessary evictions.

### c. Memory Traffic

The testbench logs show that memory transactions (reads and writes) occur only on misses and evictions, as expected. Write-backs are performed only for dirty blocks, reducing unnecessary memory writes.

### d. Latency and Throughput

- **Cache Hits:** Data is returned to the CPU with low latency, typically within 1-2 cycles after the request.
- **Cache Misses:** Misses incur additional latency due to memory access and possible eviction, but the FSM ensures correct sequencing and minimal stalling.
- **Throughput:** The controller can handle back-to-back requests, with the FSM returning to the IDLE state promptly after each operation.

### e. Edge Case Handling

The testbench includes cases with empty candidates and partially filled sets. The controller correctly identifies free slots and avoids unnecessary evictions, demonstrating robust handling of all scenarios.

---

## 5. Conclusion

The cache controller project successfully implements a parameterized, modular, and robust set-associative cache controller with LRU replacement and write-back support. The design addresses key technical challenges, including LRU management, dirty block handling, and synchronization. Comprehensive simulation and waveform analysis confirm correct functionality, efficient memory usage, and robust handling of all edge cases. The project provides a solid foundation for further exploration of cache architectures and performance optimization.
