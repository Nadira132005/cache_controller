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
    output cpu_res_ready,
    input cpu_req_rw,  // r = 0, w = 1
    input cpu_req_enable,

    // Cache controller to main memory signals
    input [WORD_SIZE-1:0] mem_req_addr, // BLOCK_OFFSET bits should be always 0 to align to 16 bytes
    input [BLOCK_DATA_WIDTH-1:0] mem_req_datain, // the 64 byte block extracted from main memory (on read miss)
    output [BLOCK_DATA_WIDTH-1:0] mem_req_dataout, // the 64 byte block to be written to main memory (on write back)
    output mem_req_rw,  // r = 0, w = 1
    output mem_req_enable,  // when reading/writing to main memory do not forget to activate

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

  
  //CPU Address = tag + index + block offset + byte offset
  assign cpu_addr_block_offset = cpu_req_addr_reg[BLOCK_OFFSET-1:0];
  assign cpu_addr_index        = cpu_req_addr_reg[BLOCK_OFFSET+SETS_BITS-1:BLOCK_OFFSET];
  assign cpu_addr_tag          = cpu_req_addr_reg[WORD_SIZE-1:BLOCK_OFFSET+SETS_BITS];

parameter TAG_START = BLOCK_DATA_WIDTH;
parameter AGE_START = TAG_START + TAG_BITS;
parameter DIRTY_BIT_START = AGE_START + AGE_BITS;
parameter VALID_BIT_START = DIRTY_BIT_START + DIRTY_BIT;

wire [TAG_BITS-1:0] candidate_1_tag;
wire [AGE_BITS-1:0] candidate_1_age;
wire [DIRTY_BIT-1:0] candidate_1_dirty;
wire [VALID_BIT-1:0] candidate_1_valid;
assign candidate_1_age = candidate_1[AGE_START + AGE_BITS - 1:AGE_START];
assign candidate_1_dirty = candidate_1[DIRTY_BIT_START + DIRTY_BIT - 1:DIRTY_BIT_START];
assign candidate_1_valid = candidate_1[VALID_BIT_START + VALID_BIT - 1:VALID_BIT_START];
assign candidate_1_tag = candidate_1[TAG_START + TAG_BITS - 1:TAG_START];


wire [TAG_BITS-1:0] candidate_2_tag;
wire [AGE_BITS-1:0] candidate_2_age;
wire [DIRTY_BIT-1:0] candidate_2_dirty;
wire [VALID_BIT-1:0] candidate_2_valid;
assign candidate_2_age = candidate_2[AGE_START + AGE_BITS - 1:AGE_START];
assign candidate_2_dirty = candidate_2[DIRTY_BIT_START + DIRTY_BIT - 1:DIRTY_BIT_START];
assign candidate_2_valid = candidate_2[VALID_BIT_START + VALID_BIT - 1:VALID_BIT_START];
assign candidate_2_tag = candidate_2[TAG_START + TAG_BITS - 1:TAG_START];

wire [TAG_BITS-1:0] candidate_3_tag;
wire [AGE_BITS-1:0] candidate_3_age;
wire [DIRTY_BIT-1:0] candidate_3_dirty;
wire [VALID_BIT-1:0] candidate_3_valid;
assign candidate_3_age = candidate_3[AGE_START + AGE_BITS - 1:AGE_START];
assign candidate_3_dirty = candidate_3[DIRTY_BIT_START + DIRTY_BIT - 1:DIRTY_BIT_START];
assign candidate_3_valid = candidate_3[VALID_BIT_START + VALID_BIT - 1:VALID_BIT_START];
assign candidate_3_tag = candidate_3[TAG_START + TAG_BITS - 1:TAG_START];

wire [TAG_BITS-1:0] candidate_4_tag;
wire [AGE_BITS-1:0] candidate_4_age;
wire [DIRTY_BIT-1:0] candidate_4_dirty;
wire [VALID_BIT-1:0] candidate_4_valid;
assign candidate_4_age = candidate_4[AGE_START + AGE_BITS - 1:AGE_START];
assign candidate_4_dirty = candidate_4[DIRTY_BIT_START + DIRTY_BIT - 1:DIRTY_BIT_START];
assign candidate_4_valid = candidate_4[VALID_BIT_START + VALID_BIT - 1:VALID_BIT_START];
assign candidate_4_tag = candidate_4[TAG_START + TAG_BITS - 1:TAG_START];

wire hit, hit_1, hit_2, hit_3, hit_4, miss;
assign hit_1 = (candidate_1_tag == cpu_addr_tag && candidate_1[VALID_BIT_START] == 1'b1);
assign hit_2 = (candidate_2_tag == cpu_addr_tag && candidate_2[VALID_BIT_START] == 1'b1);
assign hit_3 = (candidate_3_tag == cpu_addr_tag && candidate_3[VALID_BIT_START] == 1'b1);
assign hit_4 = (candidate_4_tag == cpu_addr_tag && candidate_4[VALID_BIT_START] == 1'b1);
assign hit = hit_1 | hit_2 | hit_3 | hit_4;
assign miss = ~hit;

// Implement LRU policy
wire [BANK-1:0] bank_selector_miss = {
    (candidate_1[AGE_START + AGE_BITS - 1:AGE_START] == 2'b11),
    (candidate_2[AGE_START + AGE_BITS - 1:AGE_START] == 2'b11),
    (candidate_3[AGE_START + AGE_BITS - 1:AGE_START] == 2'b11),
    (candidate_4[AGE_START + AGE_BITS - 1:AGE_START] == 2'b11)
};

// Bank selector is a one-hot encoding of the hit candidates
// and must be chosen by LRU policy (TODO)
assign bank_selector = hit ? {hit_1, hit_2, hit_3, hit_4} : bank_selector_miss;

// If there is a WRITE HIT we want to know which block we will put the data in
wire [BLOCK_DATA_WIDTH-1:0] candidate_hit_data;
always @(*) begin
    if(hit_1) candidate_hit_data = candidate_1[BLOCK_DATA_WIDTH-1:0];
    if(hit_2) candidate_hit_data = candidate_2[BLOCK_DATA_WIDTH-1:0];
    if(hit_3) candidate_hit_data = candidate_3[BLOCK_DATA_WIDTH-1:0];
    if(hit_4) candidate_hit_data = candidate_4[BLOCK_DATA_WIDTH-1:0];
end 

wire evict_1, evict_2, evict_3, evict_4;
assign evict_1 = (candidate_1[VALID_BIT_START] == 1'b1 && candidate_1[DIRTY_BIT_START] == 1'b1);
assign evict_2 = (candidate_2[VALID_BIT_START] == 1'b1 && candidate_2[DIRTY_BIT_START] == 1'b1);
assign evict_3 = (candidate_3[VALID_BIT_START] == 1'b1 && candidate_3[DIRTY_BIT_START] == 1'b1);
assign evict_4 = (candidate_4[VALID_BIT_START] == 1'b1 && candidate_4[DIRTY_BIT_START] == 1'b1); 

// TODO: Implement as multiplexer instead of ternary operator
assign mem_req_dataout = (evict_1 & miss ? candidate_1[BLOCK_DATA_WIDTH-1:0] : 
                          (evict_2 & miss ? candidate_2[BLOCK_DATA_WIDTH-1:0] : 
                          (evict_3 & miss ? candidate_3[BLOCK_DATA_WIDTH-1:0] : 
                          (evict_4 & miss ? candidate_4[BLOCK_DATA_WIDTH-1:0] : 32'd0))));
                          
assign mem_req_enable = (evict_1 | evict_2 | evict_3 | evict_4) & (current_state == EVICT);
assign mem_req_rw = (evict_1 | evict_2 | evict_3 | evict_4) & (current_state == EVICT);

wire [BLOCK_DATA_WIDTH-1:0] modified_mem_block;
replacer R (
    .data_in(mem_req_dataout),
    .block_offset(cpu_addr_block_offset),
    .data_write(cpu_req_datain),
    .data_out(modified_cache_line), 
    .enable(cache_rw & miss)  // write miss
);

wire [BLOCK_DATA_WIDTH-1:0] modified_candidate_block;
replacer R (
    .data_in(candidate_hit_data),
    .block_offset(cpu_addr_block_offset),
    .data_write(cpu_req_datain),
    .data_out(modified_candidate_block),
    enable(cache_rw & hit) // write hit
);

assign candidate_write[BLOCK_DATA_WIDTH-1:0] = 
    (miss) ? 
        // If there is a cache MISS either:
                    // WRITE: bring the block from main memory and write the cpu data word at the correct block offset
        (cache_rw ? modified_mem_block 
                    // READ: just bring the block from main memory 
                  : mem_req_dataout) 
        : 
        // If there is a cache HIT either: 
                    // WRITE: take the hit block and write the cpu data word at the correct block offset
        (cache_rw ? modified_candidate_block 
                    // READ: shouldn't reach this because cache_rw disables HIT READ
                  : 512'dz);

assign cache_rw = cpu_rw | miss; // only write to cahce when cpu is writing or there was a cache miss 

assign candidate_write[TAG_START+TAG_BITS-1:TAG_START] = hit ? 
    (hit_1 ? candidate_1_tag : 
     (hit_2 ? candidate_2_tag : 
     (hit_3 ? candidate_3_tag : candidate_4_tag))) : cpu_addr_tag; // write the tag of the hit candidate or the current cpu address tag

assign candidate_write[AGE_START + AGE_BITS - 1:AGE_START] = 2'b00;

assign LRU_prev_age = hit_1 ? candidate_1[AGE_START + AGE_BITS - 1:AGE_START] :
                      hit_2 ? candidate_2[AGE_START + AGE_BITS - 1:AGE_START] :
                      hit_3 ? candidate_3[AGE_START + AGE_BITS - 1:AGE_START] :
                      hit_4 ? candidate_4[AGE_START + AGE_BITS - 1:AGE_START] : 2'b00;

assign age_1 = hit_1 ? 2'b00 : candidate_1_age < LRU_prev_age ? candidate_1_age + 1 : candidate_1_age;
assign age_2 = hit_2 ? 2'b00 : candidate_2_age < LRU_prev_age ? candidate_2_age + 1 : candidate_2_age;
assign age_3 = hit_3 ? 2'b00 : candidate_3_age < LRU_prev_age ? candidate_3_age + 1 : candidate_3_age;
assign age_4 = hit_4 ? 2'b00 : candidate_4_age < LRU_prev_age ? candidate_4_age + 1 : candidate_4_age;

assign candidate_write[DIRTY_BIT_START + DIRTY_BIT - 1:DIRTY_BIT_START] = 
    // Set dirty on WRITE (either hit or miss)
    cpu_req_rw ? 1'b1 :
    // If READ MISS set dirty bit to 0 because we have fresh data from memory
    (miss ? 1'b0 : 
    // If READ HIT the dirty bit should not CHANGE!
    1'bz);

assign candidate_write[VALID_BIT_START + VALID_BIT - 1:VALID_BIT_START] = 1'b1;


  reg [2:0] current_state, next_state;
    always @(*) begin
        cache_enable = 1'b0;
        cache_rw = 1'b0;
        mem_req_enable = 1'b0;
        mem_req_rw = 1'b0;
        mem_req_addr = 32'd0;
        mem_req_datain = 512'd0;
        cpu_res_dataout = 32'd0;
        cpu_res_ready = 1'b0;
            
        if(current_state == IDLE) begin
            cache_rw = 0; // always read from cache in IDLE state
            if(cpu_req_enable) begin
                next_state = CHECK_HIT; // move to CHECK_HIT state
                cache_enable = 1'b1; // enable cache when CPU requests
            end else begin
                cache_enable = 1'b0; // disable cache when no CPU request
            end 
        end else if(current_state == CHECK_HIT) begin
            if(cache_ready) begin
                if(evict) begin
                    next_state = EVICT; // if dirty, go to EVICT state
                end else begin
                    if(hit) begin
                        next_state = IDLE;
                        cpu_res_ready = 1'b1; // signal that CPU can read the data
                        cpu_res_dataout = candidate_hit_data[cpu_addr_block_offset * WORD_SIZE + WORD_SIZE - 1 : cpu_addr_block_offset * WORD_SIZE]; // output the data to CPU
                    end else begin
                        next_state = ALLOCATE; // if miss, go to ALLOCATE state
                    end
                end
            end
            else next_state = CHECK_HIT; // remain here if not ready
        end 
        else if(current_state == ALLOCATE) begin
            if(mem_req_ready) begin
                cache_enable = 1'b1;
                cache_rw = 1'b1; // write to cache if memory is ready
            end else begin
                cache_enable = 1'b0;
                cache_rw = 1'b0;
            end
        end else if(current_state == SEND_TO_CACHE) begin
            // The CPU want to WRITE to cache
            if(cpu_req_rw) begin 
                cache_enable <= 1'b1;
                cache_rw <= 1'b1;
            end 
        end
    end   

    always @(*) begin
        next_state = current_state; // default next state is the current state
        case(current_state)
            IDLE: begin
                if(cpu_req_enable) begin
                    next_state = CHECK_HIT;
                end
            end
            CHECK_HIT: begin
                if(cache_ready) begin
                    if(!dirty) begin
                        if(valid) begin
                            next_state = SEND_TO_CACHE; // hit
                        end else begin
                            next_state = ALLOCATE; // miss, but no eviction needed
                        end
                    end else begin
                        // here dirty = 1, so we need to evict
                        next_state = EVICT;
                    end
                end
            end
            EVICT: begin
                mem_req_addr = {cpu_addr_tag, cpu_addr_index, {BLOCK_OFFSET{1'b0}}}; // align to block size 
                mem_req_datain = candidate_hit_data; // data to be written back to memory
                mem_req_enable = 1'b1; // enable memory request
                mem_req_rw = 1'b1; // write back to memory 

                if(mem_req_ready) begin
                    next_state = ALLOCATE;
                end
            end
            ALLOCATE: begin
                if(mem_req_ready) begin
                    next_state = SEND_TO_CACHE;
                end else begin
                    next_state = IDLE; // go back to IDLE if memory is not ready for allocation
                end
            end
            SEND_TO_CACHE: begin
                if(cache_ready) begin
                    next_state = IDLE; // go back to IDLE after sending data to cache
                end else begin
                    next_state = SEND_TO_CACHE; // stay in SEND_TO_CACHE until cache is ready
                end
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

endmodule