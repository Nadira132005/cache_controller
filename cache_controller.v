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

    // CPU to cache controller signals
    input [WORD_SIZE-1:0] cpu_req_addr,  // 1 word address
    input [WORD_SIZE-1:0] cpu_req_datain,  // 1 word data input to write
    output [WORD_SIZE-1:0] cpu_res_dataout,  // 1 word response data output to cpu
    output reg cpu_res_ready,
    input cpu_req_rw,  // r = 0, w = 1
    input cpu_req_enable,

    // Cache controller to main memory signals
    output reg [WORD_SIZE-1:0] mem_req_addr, // BLOCK_OFFSET bits should be always 0 to align to 16 bytes
    output [BLOCK_DATA_WIDTH-1:0] mem_req_dataout, // the 64 byte block to be written to main memory (on write back)
    input [BLOCK_DATA_WIDTH-1:0] mem_req_datain, // the 64 byte block extracted from main memory (on read miss)
    output reg mem_req_rw,  // r = 0, w = 1
    output reg mem_req_enable,  // when reading/writing to main memory do not forget to activate

    input mem_req_ready,  // main memory has valid data at mem_req_dataout

    // Physical cache to cache controller signals
    output reg cache_enable,  // indicates that the cache should do a write/read
    output reg cache_rw,  // r = 0, w = 1,
    input cache_ready,  // indicates that the cache has valid data at candidates

    input [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_1, // candidate from cache line 1
    input [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_2, // candidate from cache line 2
    input [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_3, // candidate from cache line 3
    input [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_4, // candidate from cache line 4

    // assign CACHE_BANKS[0][INDEX][AGE_BITS_START + AGE_BITS - 1:AGE_BITS_START] = age_1 (when cache_enable = 1)
    // assign CACHE_BANKS[1][INDEX][AGE_BITS_START + AGE_BITS - 1:AGE_BITS_START] = age_2 (when cache_enable = 1)
    // assign CACHE_BANKS[2][INDEX][AGE_BITS_START + AGE_BITS - 1:AGE_BITS_START] = age_3 (when cache_enable = 1)
    // assign CACHE_BANKS[3][INDEX][AGE_BITS_START + AGE_BITS - 1:AGE_BITS_START] = age_4 (when cache_enable = 1)
    output [AGE_BITS-1:0] age_1,
    output [AGE_BITS-1:0] age_2,
    output [AGE_BITS-1:0] age_3,
    output [AGE_BITS-1:0] age_4,

    output [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_write, // data to be written to the cache line when hit occurs
    output [BANK-1:0] bank_selector // one hot encoding of the bank the candidate_write must be written to
);

  parameter IDLE = 3'b000;
  parameter CHECK_HIT = 3'b001;
  parameter EVICT = 3'b010;
  parameter ALLOCATE = 3'b011;
  parameter SEND_TO_CACHE = 3'b100;

  // Registered candidates as registers
  wire [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0]
      candidate_1_reg, candidate_2_reg, candidate_3_reg, candidate_4_reg;

  // Register candidate data when cache_ready is active
  flipflop_d #(
      .WIDTH(VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH)
  ) candidate_1_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .load(cache_ready & ~cache_rw),  // Only load when cache_ready is active
      .d(candidate_1),
      .q(candidate_1_reg)
  );

  flipflop_d #(
      .WIDTH(VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH)
  ) candidate_2_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .load(cache_ready & ~cache_rw),
      .d(candidate_2),
      .q(candidate_2_reg)
  );

  flipflop_d #(
      .WIDTH(VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH)
  ) candidate_3_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .load(cache_ready & ~cache_rw),
      .d(candidate_3),
      .q(candidate_3_reg)
  );

  flipflop_d #(
      .WIDTH(VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH)
  ) candidate_4_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .load(cache_ready & ~cache_rw),
      .d(candidate_4),
      .q(candidate_4_reg)
  );


  wire [WORD_SIZE-1:0] cpu_req_addr_reg;
  // Instantiate flipflop_d module for cpu_req_addr_reg
  flipflop_d #(
      .WIDTH(WORD_SIZE)
  ) cpu_req_addr_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .load(cpu_req_enable),
      .d(cpu_req_addr),
      .q(cpu_req_addr_reg)
  );

  wire cpu_req_rw_reg;
  // Instantiate flipflop_d module for cpu_req_rw_reg
  flipflop_d #(
      .WIDTH(1)
  ) cpu_req_rw_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .load(cpu_req_enable),
      .d(cpu_req_rw),
      .q(cpu_req_rw_reg)
  );

  wire [BLOCK_OFFSET-1:0] cpu_addr_block_offset;
  wire [SETS_BITS-1:0] cpu_addr_index;
  wire [TAG_BITS-1:0] cpu_addr_tag;

  //CPU Address = tag + index + block offset + byte offset
  assign cpu_addr_block_offset = cpu_req_addr_reg[BLOCK_OFFSET-1:0];
  assign cpu_addr_index        = cpu_req_addr_reg[BLOCK_OFFSET+SETS_BITS-1:BLOCK_OFFSET];
  assign cpu_addr_tag          = cpu_req_addr_reg[WORD_SIZE-1:BLOCK_OFFSET+SETS_BITS];

  parameter TAG_START = BLOCK_DATA_WIDTH;
  parameter AGE_START = TAG_START + TAG_BITS;
  parameter DIRTY_BIT_START = AGE_START + AGE_BITS;
  parameter VALID_BIT_START = DIRTY_BIT_START + DIRTY_BIT;

  wire [ TAG_BITS-1:0] candidate_1_tag;
  wire [ AGE_BITS-1:0] candidate_1_age;
  wire [DIRTY_BIT-1:0] candidate_1_dirty;
  wire [VALID_BIT-1:0] candidate_1_valid;
  assign candidate_1_age   = candidate_1_reg[AGE_START+AGE_BITS-1:AGE_START];
  assign candidate_1_dirty = candidate_1_reg[DIRTY_BIT_START+DIRTY_BIT-1:DIRTY_BIT_START];
  assign candidate_1_valid = candidate_1_reg[VALID_BIT_START+VALID_BIT-1:VALID_BIT_START];
  assign candidate_1_tag   = candidate_1_reg[TAG_START+TAG_BITS-1:TAG_START];


  wire [ TAG_BITS-1:0] candidate_2_tag;
  wire [ AGE_BITS-1:0] candidate_2_age;
  wire [DIRTY_BIT-1:0] candidate_2_dirty;
  wire [VALID_BIT-1:0] candidate_2_valid;
  assign candidate_2_age   = candidate_2_reg[AGE_START+AGE_BITS-1:AGE_START];
  assign candidate_2_dirty = candidate_2_reg[DIRTY_BIT_START+DIRTY_BIT-1:DIRTY_BIT_START];
  assign candidate_2_valid = candidate_2_reg[VALID_BIT_START+VALID_BIT-1:VALID_BIT_START];
  assign candidate_2_tag   = candidate_2_reg[TAG_START+TAG_BITS-1:TAG_START];

  wire [ TAG_BITS-1:0] candidate_3_tag;
  wire [ AGE_BITS-1:0] candidate_3_age;
  wire [DIRTY_BIT-1:0] candidate_3_dirty;
  wire [VALID_BIT-1:0] candidate_3_valid;
  assign candidate_3_age   = candidate_3_reg[AGE_START+AGE_BITS-1:AGE_START];
  assign candidate_3_dirty = candidate_3_reg[DIRTY_BIT_START+DIRTY_BIT-1:DIRTY_BIT_START];
  assign candidate_3_valid = candidate_3_reg[VALID_BIT_START+VALID_BIT-1:VALID_BIT_START];
  assign candidate_3_tag   = candidate_3_reg[TAG_START+TAG_BITS-1:TAG_START];

  wire [ TAG_BITS-1:0] candidate_4_tag;
  wire [ AGE_BITS-1:0] candidate_4_age;
  wire [DIRTY_BIT-1:0] candidate_4_dirty;
  wire [VALID_BIT-1:0] candidate_4_valid;
  assign candidate_4_age   = candidate_4_reg[AGE_START+AGE_BITS-1:AGE_START];
  assign candidate_4_dirty = candidate_4_reg[DIRTY_BIT_START+DIRTY_BIT-1:DIRTY_BIT_START];
  assign candidate_4_valid = candidate_4_reg[VALID_BIT_START+VALID_BIT-1:VALID_BIT_START];
  assign candidate_4_tag   = candidate_4_reg[TAG_START+TAG_BITS-1:TAG_START];

  wire hit, hit_1, hit_2, hit_3, hit_4, miss;
  assign hit_1 = (candidate_1_tag == cpu_addr_tag && candidate_1[VALID_BIT_START] == 1'b1);
  assign hit_2 = (candidate_2_tag == cpu_addr_tag && candidate_2[VALID_BIT_START] == 1'b1);
  assign hit_3 = (candidate_3_tag == cpu_addr_tag && candidate_3[VALID_BIT_START] == 1'b1);
  assign hit_4 = (candidate_4_tag == cpu_addr_tag && candidate_4[VALID_BIT_START] == 1'b1);
  assign hit   = hit_1 | hit_2 | hit_3 | hit_4;
  assign miss  = ~hit;

  // The least recently used (LRU) candidate is the one with the highest age (one hot encoding)
  wire [BANK-1:0] LRU_candidate;
  assign LRU_candidate = {
    (candidate_4_reg[AGE_START+AGE_BITS-1:AGE_START] == 2'b11),
    (candidate_3_reg[AGE_START+AGE_BITS-1:AGE_START] == 2'b11),
    (candidate_2_reg[AGE_START+AGE_BITS-1:AGE_START] == 2'b11),
    (candidate_1_reg[AGE_START+AGE_BITS-1:AGE_START] == 2'b11)
  };

  // Bank selector is a one-hot encoding of the hit candidates
  // and must be chosen by LRU policy
  assign bank_selector = hit ? {hit_4, hit_3, hit_2, hit_1} : LRU_candidate;

  // If there is a WRITE HIT we want to know which block we will put the data in
  reg [BLOCK_DATA_WIDTH-1:0] candidate_hit_data;
  always @(*) begin
    if (hit_1) candidate_hit_data = candidate_1_reg[BLOCK_DATA_WIDTH-1:0];
    if (hit_2) candidate_hit_data = candidate_2_reg[BLOCK_DATA_WIDTH-1:0];
    if (hit_3) candidate_hit_data = candidate_3_reg[BLOCK_DATA_WIDTH-1:0];
    if (hit_4) candidate_hit_data = candidate_4_reg[BLOCK_DATA_WIDTH-1:0];
  end

  wire evict_1, evict_2, evict_3, evict_4, evict;
  assign evict_1 = (candidate_1_reg[VALID_BIT_START] == 1'b1 && candidate_1_reg[DIRTY_BIT_START] == 1'b1);
  assign evict_2 = (candidate_2_reg[VALID_BIT_START] == 1'b1 && candidate_2_reg[DIRTY_BIT_START] == 1'b1);
  assign evict_3 = (candidate_3_reg[VALID_BIT_START] == 1'b1 && candidate_3_reg[DIRTY_BIT_START] == 1'b1);
  assign evict_4 = (candidate_4_reg[VALID_BIT_START] == 1'b1 && candidate_4_reg[DIRTY_BIT_START] == 1'b1);

  // If there is a cache MISS and the LRU candidate is dirty, we need to evict it
  assign evict = miss && (
      (LRU_candidate[0] && evict_1) ||
      (LRU_candidate[1] && evict_2) ||
      (LRU_candidate[2] && evict_3) ||
      (LRU_candidate[3] && evict_4)
  );

  // Send the evicted block to main memory
  assign mem_req_dataout = evict ? (
      LRU_candidate[0] ? candidate_1_reg[BLOCK_DATA_WIDTH-1:0] :
      LRU_candidate[1] ? candidate_2_reg[BLOCK_DATA_WIDTH-1:0] :
      LRU_candidate[2] ? candidate_3_reg[BLOCK_DATA_WIDTH-1:0] :
      LRU_candidate[3] ? candidate_4_reg[BLOCK_DATA_WIDTH-1:0] : 32'd0
  ) : 32'dz;

  // On WRITE MISS, take the block from main memory (mem_req_datain) and write the cpu data word at the correct block offset
  // to prepare it for writing it to cache
  wire [BLOCK_DATA_WIDTH-1:0] modified_mem_block;
  replacer R_WRITE_MISS (
      .data_in(mem_req_datain),
      .block_offset(cpu_addr_block_offset),
      .data_write(cpu_req_datain),
      .data_out(modified_mem_block),
      .enable(cache_rw & miss)
  );

  // On WRITE HIT, take the hit block and write the cpu data word at the correct block offset
  wire [BLOCK_DATA_WIDTH-1:0] modified_candidate_block;
  replacer R_WRITE_HIT (
      .data_in(candidate_hit_data),
      .block_offset(cpu_addr_block_offset),
      .data_write(cpu_req_datain),
      .data_out(modified_candidate_block),
      .enable(cache_rw & hit)
  );

  assign candidate_write[BLOCK_DATA_WIDTH-1:0] = (miss) ?
      // If there is a cache MISS try:
      // on WRITE: bring the block from main memory and write the cpu data word at the correct block offset
      (cache_rw ? modified_mem_block
      // on READ: just bring the block from main memory 
      : mem_req_dataout) :
      // If there is a cache HIT try: 
      // on WRITE: take the hit block and write the cpu data word at the correct block offset
      (cache_rw ? modified_candidate_block
      // on READ: shouldn't reach this because cache_rw disables HIT READ
      : 512'dz);


  // write the tag of the hit candidate or the current cpu address tag
  assign candidate_write[TAG_START+TAG_BITS-1:TAG_START] = 
      hit ? 
      (hit_1 ? candidate_1_tag : 
      (hit_2 ? candidate_2_tag : 
     (hit_3 ? candidate_3_tag : candidate_4_tag))) : cpu_addr_tag;

  assign candidate_write[AGE_START+AGE_BITS-1:AGE_START] = 2'b00;


  assign hit_element_age = hit_1 ? candidate_1_age :
                      hit_2 ? candidate_2_age :
                      hit_3 ? candidate_3_age :
                      hit_4 ? candidate_4_age : 2'b00;


  // Age calculation for cache candidates
  // On HIT: Reset age of accessed candidate to 0, and increment ages of valid candidates that were less than hit_element_age
  // On MISS: Increment age of all valid candidates (allow overflow since LRU will be replaced)

  // Age calculation when there is a hit
  // For the accessed candidate: reset to 0
  // For other valid candidates: increment only if their age was less than the hit element's age
  wire [AGE_BITS-1:0] age_1_hit = hit_1 ? 2'b00 : candidate_1_valid ? (candidate_1_age < hit_element_age ? candidate_1_age + 1 : candidate_1_age) : candidate_1_age;
  wire [AGE_BITS-1:0] age_2_hit = hit_2 ? 2'b00 : candidate_2_valid ? (candidate_2_age < hit_element_age ? candidate_2_age + 1 : candidate_2_age) : candidate_2_age;
  wire [AGE_BITS-1:0] age_3_hit = hit_3 ? 2'b00 : candidate_3_valid ? (candidate_3_age < hit_element_age ? candidate_3_age + 1 : candidate_3_age) : candidate_3_age;
  wire [AGE_BITS-1:0] age_4_hit = hit_4 ? 2'b00 : candidate_4_valid ? (candidate_4_age < hit_element_age ? candidate_4_age + 1 : candidate_4_age) : candidate_4_age;

  // Age calculation when there is a miss
  // For valid candidates: increment age (allow overflow back to 00)
  // For invalid candidates: keep current age
  wire [AGE_BITS-1:0] age_1_miss = candidate_1_valid ? candidate_1_age + 1 : candidate_1_age;
  wire [AGE_BITS-1:0] age_2_miss = candidate_2_valid ? candidate_2_age + 1 : candidate_2_age;
  wire [AGE_BITS-1:0] age_3_miss = candidate_3_valid ? candidate_3_age + 1 : candidate_3_age;
  wire [AGE_BITS-1:0] age_4_miss = candidate_4_valid ? candidate_4_age + 1 : candidate_4_age;

  // Select between hit and miss age calculations based on whether there was a hit
  assign age_1 = hit ? age_1_hit : age_1_miss;
  assign age_2 = hit ? age_2_hit : age_2_miss;
  assign age_3 = hit ? age_3_hit : age_3_miss;
  assign age_4 = hit ? age_4_hit : age_4_miss;

  assign candidate_write[DIRTY_BIT_START+DIRTY_BIT-1:DIRTY_BIT_START] =
      // Set dirty on WRITE (either hit or miss)
      cpu_req_rw ? 1'b1 :
      // If READ MISS set dirty bit to 0 because we have fresh data from memory
      (miss ? 1'b0 :
      // If READ HIT the dirty bit SHOULD NOT CHANGE!
      1'bz);

  assign candidate_write[VALID_BIT_START+VALID_BIT-1:VALID_BIT_START] = 1'b1;
  block_selector #(
    .WORD_SIZE(WORD_SIZE),
    .BLOCK_DATA_WIDTH(BLOCK_DATA_WIDTH)
  ) data_selector (
    .block_data(candidate_hit_data),
    .block_offset(cpu_addr_block_offset),
    .selected_word(cpu_res_dataout)
  );

  reg [3:0] current_state, next_state;

  // State transition logic
  always @(*) begin
    // Default: stay in current state if there are no conditions to change!
    next_state = current_state;

    case (current_state)
      IDLE: begin
        if (cpu_req_enable) begin
          next_state = CHECK_HIT;
        end
      end

      CHECK_HIT: begin
        if (cache_ready) begin
          if (hit) begin
            next_state = SEND_TO_CACHE;  // Cache hit, send data to CPU or write to cache
          end else begin
            // Miss: check if we need to evict
            if (evict) begin
              next_state = EVICT;  // Need to evict before allocating
            end else begin
              next_state = ALLOCATE;  // No eviction needed
            end
          end
        end
      end

      EVICT: begin
        if (mem_req_ready) begin
          next_state = ALLOCATE;
        end
      end

      ALLOCATE: begin
        if (mem_req_ready) begin
          next_state = SEND_TO_CACHE;
        end
      end

      SEND_TO_CACHE: begin
        if (cache_ready || cpu_res_ready) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  always @(*) begin
    // Default assignments
    cache_enable = 1'b0;

    case (current_state)
      IDLE: begin
        if (cpu_req_enable) begin
          cache_enable = 1'b1;  // Enable cache when CPU requests
          cache_rw = 1'b0;  // Always read from cache in IDLE state
        end
      end

      EVICT: begin
        // Write back to memory
        mem_req_enable = 1'b1;
        mem_req_rw = 1'b1;  // Write to memory
        mem_req_addr = {cpu_addr_tag, cpu_addr_index, {BLOCK_OFFSET{1'b0}}};  // Align to block size
      end

      ALLOCATE: begin
        // Read from memory on allocate
        mem_req_enable = 1'b1;
        mem_req_rw = 1'b0;
      end

      SEND_TO_CACHE: begin
        if (cpu_req_addr_reg) begin
          // Write to cache
          cache_enable = 1'b1;
          cache_rw = 1'b1;
        end else begin
          // Write to CPU
          cpu_res_ready = 1'b1;
        end
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end
endmodule
