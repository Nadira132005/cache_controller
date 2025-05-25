`timescale 1ns / 1ps

module cache_controller_tb ();
  // Parameters                                                               
  parameter WORD_SIZE = 32;
  parameter BLOCK_OFFSET = 4;
  parameter SETS = 128;
  parameter SETS_BITS = 7;
  parameter AGE_BITS = 2;
  parameter TAG_BITS = 21;
  parameter BLOCK_DATA_WIDTH = 512;
  parameter DIRTY_BIT = 1;
  parameter VALID_BIT = 1;
  parameter BANK = 4;

  // Signals                                                                  
  logic clk;
  logic rst_n;

  // CPU signals                                                              
  logic [WORD_SIZE-1:0] cpu_req_addr;
  logic [WORD_SIZE-1:0] cpu_req_datain;
  wire [WORD_SIZE-1:0] cpu_res_dataout;
  wire cpu_res_ready;
  logic cpu_req_rw;
  logic cpu_req_enable;

  // Memory signals                                                           
  wire mem_req_rw;
  wire mem_req_enable;
  wire [WORD_SIZE-1:0] mem_req_addr;
  wire [BLOCK_DATA_WIDTH-1:0] mem_req_dataout;
  logic [BLOCK_DATA_WIDTH-1:0] mem_req_datain;
  logic mem_req_ready;

  // Cache signals                                                            
  wire cache_enable;
  wire cache_rw;
  logic cache_ready;
  reg [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_1;
  reg [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_2;
  reg [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_3;
  reg [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_4;
  reg [AGE_BITS-1:0] age_1;
  reg [AGE_BITS-1:0] age_2;
  reg [AGE_BITS-1:0] age_3;
  reg [AGE_BITS-1:0] age_4;
  wire [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] candidate_write;
  wire [BANK-1:0] bank_selector;

  // Instantiate the cache controller                                         
  cache_controller #(
      .WORD_SIZE(WORD_SIZE),
      .BLOCK_OFFSET(BLOCK_OFFSET),
      .SETS(SETS),
      .SETS_BITS(SETS_BITS),
      .AGE_BITS(AGE_BITS),
      .TAG_BITS(TAG_BITS),
      .BLOCK_DATA_WIDTH(BLOCK_DATA_WIDTH),
      .DIRTY_BIT(DIRTY_BIT),
      .VALID_BIT(VALID_BIT),
      .BANK(BANK)
  ) uut (
      .clk(clk),
      .rst_n(rst_n),
      .cpu_req_addr(cpu_req_addr),
      .cpu_req_datain(cpu_req_datain),
      .cpu_res_dataout(cpu_res_dataout),
      .cpu_res_ready(cpu_res_ready),
      .cpu_req_rw(cpu_req_rw),
      .cpu_req_enable(cpu_req_enable),
      .mem_req_addr(mem_req_addr),
      .mem_req_dataout(mem_req_dataout),
      .mem_req_rw(mem_req_rw),
      .mem_req_enable(mem_req_enable),
      .mem_req_ready(mem_req_ready),
      .cache_enable(cache_enable),
      .cache_rw(cache_rw),
      .cache_ready(cache_ready),
      .candidate_1(candidate_1),
      .candidate_2(candidate_2),
      .candidate_3(candidate_3),
      .candidate_4(candidate_4),
      .age_1(age_1),
      .age_2(age_2),
      .age_3(age_3),
      .age_4(age_4),
      .candidate_write(candidate_write),
      .bank_selector(bank_selector)
  );

  // Clock generation                                                         
  always begin
    #5 clk = ~clk;
  end

  // Test data                                                                
  logic [BLOCK_DATA_WIDTH-1:0] test_block_data;
  logic [WORD_SIZE-1:0] test_word_data;

  // Initialize test block data with distinct patterns for easier verification
  initial begin
    for (integer i = 0; i < 16; i++) begin
      test_block_data[i*32+:32] = 32'hDEAD_BEEF + i;
    end
  end

  // Task to apply a CPU read request                                         
  task cpu_read(input [WORD_SIZE-1:0] addr);
    cpu_req_enable = 1;
    cpu_req_rw = 0;
    cpu_req_addr = addr;
    @(posedge clk);
    cpu_req_enable = 0;
    $display("CPU READ request for address 0x%08x. Waiting for response...", addr);
    wait (cpu_res_ready);
    $display("Response data: 0x%08x", cpu_res_dataout);
  endtask

  // Task to apply a CPU write request                                        
  task cpu_write(input [WORD_SIZE-1:0] addr, input [WORD_SIZE-1:0] data);
    cpu_req_enable = 1;
    cpu_req_rw = 1;
    cpu_req_addr = addr;
    cpu_req_datain = data;
    @(posedge clk);
    cpu_req_enable = 0;
    $display("CPU WRITE request: address 0x%08x, data 0x%08x", addr, data);
  endtask

  // Task to provide cache candidates with specific data                      
  task provide_candidates(input [TAG_BITS-1:0] tag, input [BLOCK_DATA_WIDTH-1:0] block_data,
                          input [AGE_BITS-1:0] age1, input [AGE_BITS-1:0] age2,
                          input [AGE_BITS-1:0] age3, input [AGE_BITS-1:0] age4,
                          input [VALID_BIT-1:0] valid1, valid2, valid3, valid4,
                          input [DIRTY_BIT-1:0] dirty1, dirty2, dirty3, dirty4);
    // Construct each candidate with the specified age, valid, dirty bits and tag                                                                         
    candidate_1 = {valid1, dirty1, age1, tag, block_data};
    candidate_2 = {valid2, dirty2, age2, tag, block_data};
    candidate_3 = {valid3, dirty3, age3, tag, block_data};
    candidate_4 = {
      valid4, dirty4, age4, age4, tag, block_data
    };  // Note: age4 is repeated intentionally                                                  

    // Wait for cache to be accessed                                        
    if (cache_ready) begin
      $display("Cache ready asserted. Providing candidates with tag 0x%05x", tag);
    end
  endtask

  // Task to provide memory data                                              
  task provide_memory_data(input [BLOCK_DATA_WIDTH-1:0] data);
    mem_req_datain = data;
  endtask

  // Task to wait for memory request to be asserted                           
  task wait_for_mem_req();
    wait (mem_req_enable);
    $display("Memory request asserted at time %0t", $time);
    mem_req_ready = 1;  // Indicate memory has valid data
    @(posedge clk);
    mem_req_ready = 0;
  endtask

  // Task to wait for cache access to complete                                
  task wait_for_cache_access();
    wait (cache_ready == 1);
    $display("Cache access completed at time %0t", $time);
    @(posedge clk);
    cache_ready = 0;
  endtask

  // Test process                                                             
  initial begin
    // Initialize signals                                                   
    clk = 0;
    rst_n = 0;
    cpu_req_enable = 0;
    cpu_req_rw = 0;
    cpu_req_addr = 0;
    cpu_req_datain = 0;
    mem_req_ready = 0;
    cache_ready = 0;

    // Dump waves for gtkwave                                               
    $dumpfile("cache_controller_tb.vcd");
    $dumpvars(0, cache_controller_tb);

    // Release reset                                                        
    #10 rst_n = 1;
    #10 rst_n = 1;  // Release reset after a short delay

    // Test case 1: Read hit in candidate 1                                 
    $display("\nTest Case 1: Read hit in candidate 1");
    provide_candidates(12'hABC, test_block_data, 2'b00, 2'b01, 2'b10, 2'b11, 1'b1, 1'b1, 1'b1, 1'b1,
                       1'b1, 1'b1, 1'b1, 1'b1);
    cpu_read(32'h0000_0ABC);  // This should hit in candidate 1             
    wait_for_cache_access();
    #20;

    // Test case 2: Read miss requiring eviction                            
    $display("\nTest Case 2: Read miss requiring eviction");
    provide_candidates(12'hDEF, test_block_data, 2'b11, 2'b10, 2'b01, 2'b00, 1'b0, 1'b1, 1'b1, 1'b1,
                       1'b0, 1'b1, 1'b1, 1'b1);
    #10;
    cache_ready = 1;
    cpu_read(32'h0000_0ABC);  // This should be a miss                      
    wait_for_mem_req();
    #10;
    provide_memory_data(test_block_data);
    mem_req_ready = 1;
    wait_for_cache_access();
    #20;

    // Test case 3: Write hit in candidate 3                                
    $display("\nTest Case 3: Write hit in candidate 3");
    provide_candidates(12'hDEF, test_block_data, 2'b11, 2'b10, 2'b01, 2'b00, 1'b1, 1'b1, 1'b1, 1'b1,
                       1'b1, 1'b1, 1'b1, 1'b1);
    #10;
    cache_ready = 1;
    test_word_data = 32'hCAFEBABE;
    cpu_write(32'h0000_0DEF,
              test_word_data);  // This should hit in candidate 3                                                                     
    wait_for_cache_access();
    #20;

    // Test case 4: Write miss                                              
    $display("\nTest Case 4: Write miss");
    provide_candidates(12'h123, test_block_data, 2'b11, 2'b10, 2'b01, 2'b00, 1'b0, 1'b0, 1'b1, 1'b1,
                       1'b0, 1'b0, 1'b1, 1'b1);
    #10;
    cache_ready = 1;
    test_word_data = 32'hFACECAFE;
    cpu_write(32'h0000_0ABD, test_word_data);  // This should be a miss     
    wait_for_mem_req();
    #10;
    provide_memory_data(test_block_data);
    mem_req_ready = 1;
    wait_for_cache_access();
    #20;

    // Test case 5: Read hit after write                                    
    $display("\nTest Case 5: Read hit after write");
    provide_candidates(12'h00B, candidate_write[BLOCK_DATA_WIDTH-1:0], 2'b11, 2'b10, 2'b01, 2'b00,
                       1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    #10;
    cache_ready = 1;
    cpu_read(32'h0000_0ABC);  // This should hit in candidate 4             
    wait_for_cache_access();
    #20;

    // Finish simulation                                                    
    $display("\nTestbench completed. Exiting...");
    $finish;
  end

  string current_state_name = state_to_string(uut.current_state);
  // Monitor signals                                                          
  initial begin
    $monitor(
        "Time: %0t | State: %s | cache_enable: %b | mem_req_enable: %b | bank_selector: %b | hit: %b | miss: %b",
        $time, current_state_name, cache_enable, mem_req_enable, bank_selector, uut.hit, uut.miss);
  end

  function string state_to_string(input [2:0] state);
    case (state)
      uut.IDLE:          return "IDLE";
      uut.CHECK_HIT:     return "CHECK_HIT";
      uut.EVICT:         return "EVICT";
      uut.ALLOCATE:      return "ALLOCATE";
      uut.SEND_TO_CACHE: return "SEND_TO_CACHE";
      default:           return "UNKNOWN";
    endcase
  endfunction

endmodule
