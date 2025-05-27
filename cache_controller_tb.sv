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
  reg clk;
  reg rst_n;

  // CPU signals                                                              
  reg [WORD_SIZE-1:0] cpu_req_addr;
  reg [WORD_SIZE-1:0] cpu_req_datain;
  wire [WORD_SIZE-1:0] cpu_res_dataout;
  wire cpu_res_ready;
  reg cpu_req_rw;
  reg cpu_req_enable;

  // Memory signals                                                           
  wire mem_req_rw;
  wire mem_req_enable;
  wire [WORD_SIZE-1:0] mem_req_addr;
  wire [BLOCK_DATA_WIDTH-1:0] mem_req_dataout;
  reg [BLOCK_DATA_WIDTH-1:0] mem_req_datain;
  reg mem_req_ready;

  // Cache signals                                                            
  wire cache_enable;
  wire cache_rw;
  reg cache_ready;
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
      .mem_req_datain(mem_req_datain),
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
  reg [BLOCK_DATA_WIDTH-1:0] test_block_data_candidates = {BLOCK_DATA_WIDTH{1'b0}};
  reg [BLOCK_DATA_WIDTH-1:0] test_block_data_mem = {BLOCK_DATA_WIDTH{1'b0}};
  reg [WORD_SIZE-1:0] test_word_data;

  initial begin
    forever begin
      // Wait for the condition to become true
      wait (cache_enable);

      // Wait 3 rising clock edges
      repeat (4) @(posedge clk);

      // Pulse cache_ready for 1 clock
      cache_ready = 1;
      @(posedge clk);
      cache_ready = 0;
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
  endtask

  // Task to apply a CPU write request                                        
  task cpu_write(input [WORD_SIZE-1:0] addr, input [WORD_SIZE-1:0] data);
    cpu_req_enable = 1;
    cpu_req_rw = 1;
    cpu_req_addr = addr;
    cpu_req_datain = data;
    @(posedge clk);
    cpu_req_enable = 0;
    cpu_req_rw = 0;
    $display("CPU WRITE request: address 0x%08x, data 0x%08x", addr, data);
  endtask

  // Task to provide cache candidates with specific data                      
  task provide_candidates(
      input [VALID_BIT + DIRTY_BIT + AGE_BITS + TAG_BITS + BLOCK_DATA_WIDTH - 1:0] _candidate1,
      _candidate2, _candidate3, _candidate4);
    // Construct each candidate with the specified age, valid, dirty bits and tag                                                                         
    candidate_1 = _candidate1;
    candidate_2 = _candidate2;
    candidate_3 = _candidate3;
    candidate_4 = _candidate4;
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
    wait (cache_ready == 1'b1);
    $display("Cache access completed at time %0t", $time);
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
    for (integer i = 0; i < 16; i++) begin
      test_block_data_candidates[i*32+:32] = 32'hDEADBEEF + i;
    end
    for (integer i = 0; i < 16; i++) begin
      test_block_data_mem[i*32+:32] = 32'hFACEB00C + i;
    end
    mem_req_datain = test_block_data_mem;

    // Dump waves for gtkwave                                               
    $dumpfile("cache_controller_tb.vcd");
    $dumpvars(0, cache_controller_tb);

    // Release reset                                                        
    #10 rst_n = 1;
    #10 rst_n = 0;
    #10 rst_n = 1;
    @(posedge clk);

    // Test case 1: Read hit in candidate 1                                 
    $display("\nTest Case 1: Read hit in candidate 1");
    provide_candidates({1'b1, 1'b1, 2'b10, {9'd0, 12'hABC}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b01, {9'd0, 12'hDEF}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b00, {9'd0, 12'h123}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b11, {9'd0, 12'h456}, test_block_data_candidates});
    @(posedge clk);
    cpu_read({{9'd0}, {12'hABC}, {7'd0}, {4'd0}});  // This should hit in candidate 1             
    wait_for_cache_access();
    wait (cpu_res_ready);
    $display("Response data: 0x%08x, new age: %b, %b, %b, %b", cpu_res_dataout, age_1, age_2,
             age_3, age_4);
    wait (uut.current_state == uut.IDLE);

    @(posedge clk);
    @(posedge clk);

    // Test case 2: Read miss without eviction                       
    $display("\nTest Case 2: Read miss without eviction");
    provide_candidates({1'b1, 1'b0, 2'b10, {9'd0, 12'hDEF}, test_block_data_candidates}, {
                       1'b1, 1'b0, 2'b11, {9'd0, 12'h123}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b01, {9'd0, 12'h456}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b00, {9'd0, 12'h789}, test_block_data_candidates});
    cpu_read(32'h000A_0000);
    wait_for_mem_req();
    wait (uut.current_state == uut.IDLE);
    $display("Response data: 0x%08x, %h, bank: %b, new age: %b, %b, %b, %b", cpu_res_dataout,
             uut.candidate_write, uut.bank_selector, age_1, age_2, age_3, age_4);

    @(posedge clk);
    @(posedge clk);

    // Test Case 3: Write hit in candidate 3
    $display("\nTest Case 3: Write hit in candidate 3");
    provide_candidates({1'b1, 1'b1, 2'b11, {9'd0, 12'hDEF}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b10, {9'd0, 12'h123}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b01, {9'd0, 12'h456}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b00, {9'd0, 12'h789}, test_block_data_candidates});
    test_word_data = 32'hCAFE_BABE;
    cpu_write({{9'd0}, {12'hDEF}, {7'd0}, {4'd1}},
              test_word_data);  // This should hit in candidate 3                                                                     
    wait_for_cache_access();
    wait (uut.current_state == uut.IDLE);
    $display("Write successful, candidate write data: %h, new ages: %b, %b, %b, %b",
             uut.candidate_write, age_1, age_2, age_3, age_4);

    @(posedge clk);
    @(posedge clk);

    // Test case 4: Write miss no eviction                      
    $display("\nTest Case 4: Write miss no eviction");
    provide_candidates({1'b1, 1'b0, 2'b11, {9'd0, 12'h123}, test_block_data_candidates}, {
                       1'b1, 1'b0, 2'b10, {9'd0, 12'h456}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b01, {9'd0, 12'h789}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b00, {9'd0, 12'hABC}, test_block_data_candidates});
    test_word_data = 32'hCAFE_BABE;
    cpu_write({{9'd0}, {12'hDEF}, {7'd0}, {4'd1}}, test_word_data);
    wait_for_cache_access();
    wait_for_mem_req();
    wait (uut.current_state == uut.IDLE);
    $display("Write successful, candidate write data: %h, new ages: %b, %b, %b, %b",
             uut.candidate_write, age_1, age_2, age_3, age_4);

    @(posedge clk);
    @(posedge clk);


    // Test case 5: Write hit with eviction
    $display("\nTest Case 5: Write hit with eviction");
    provide_candidates({1'b1, 1'b1, 2'b11, {9'd0, 12'h123}, test_block_data_candidates}, {
                       1'b1, 1'b0, 2'b10, {9'd0, 12'h456}, test_block_data_candidates}, {
                       1'b1, 1'b0, 2'b01, {9'd0, 12'h789}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b00, {9'd0, 12'hABC}, test_block_data_candidates});
    test_word_data = 32'hCAFE_BABE;
    cpu_write({{9'd0}, {12'hDEF}, {7'd0}, {4'd1}}, test_word_data);
    wait_for_cache_access();
    wait_for_mem_req();
    wait_for_mem_req();
    wait (uut.current_state == uut.IDLE);
    $display("Write successful, candidate write data: %h, new ages: %b, %b, %b, %b",
             uut.candidate_write, age_1, age_2, age_3, age_4);

    @(posedge clk);
    @(posedge clk);


    // Test case 6: Read miss with eviction
    $display("\nTest Case 6: Read miss with eviction");
    provide_candidates({1'b1, 1'b1, 2'b11, {9'd0, 12'h123}, test_block_data_candidates}, {
                       1'b1, 1'b0, 2'b10, {9'd0, 12'h456}, test_block_data_candidates}, {
                       1'b1, 1'b0, 2'b01, {9'd0, 12'h789}, test_block_data_candidates}, {
                       1'b1, 1'b1, 2'b00, {9'd0, 12'hABC}, test_block_data_candidates});
    cpu_read({{9'd0}, {12'hDEF}, {7'd0}, {4'd1}});
    wait_for_cache_access();
    wait_for_mem_req();
    wait_for_mem_req();
    wait (cpu_res_ready);
    $display(
        "Read successful, CPU data: 0x%h, candidate write data: 0x%h, new ages: %b, %b, %b, %b",
        cpu_res_dataout, uut.candidate_write, age_1, age_2, age_3, age_4);
    wait (uut.current_state == uut.IDLE);

    @(posedge clk);
    @(posedge clk);

    // Test case 7: Read miss with empty candidates
    $display("\nTest Case 7: Read miss with empty candidates");
    provide_candidates({1'b1, 1'b1, 2'b01, {9'd0, 12'h123}, test_block_data_candidates}, {
                       1'b1, 1'b0, 2'b00, {9'd0, 12'h0}, {BLOCK_DATA_WIDTH{1'b0}}}, {
                       1'b0, 1'b0, 2'b00, {9'd0, 12'h0}, {BLOCK_DATA_WIDTH{1'b0}}}, {
                       1'b0, 1'b0, 2'b00, {9'd0, 12'h0}, {BLOCK_DATA_WIDTH{1'b0}}});
    cpu_read({{9'd0}, {12'hDEF}, {7'd0}, {4'd2}});
    wait_for_cache_access();
    wait_for_mem_req();
    wait (cpu_res_ready);
    $display(
        "Read successful, CPU data: 0x%h, candidate write data: 0x%h, new ages: %b, %b, %b, %b",
        cpu_res_dataout, uut.candidate_write, age_1, age_2, age_3, age_4);
    wait (uut.current_state == uut.IDLE);

    @(posedge clk);
    @(posedge clk);

    // Test case 8: Write miss with empty candidates
    $display("\nTest Case 8: Write miss with empty candidates");
    provide_candidates({1'b1, 1'b1, 2'b01, {9'd0, 12'h123}, test_block_data_candidates}, {
                       1'b1, 1'b0, 2'b00, {9'd0, 12'h777}, {BLOCK_DATA_WIDTH{1'b0}}}, {
                       1'b0, 1'b0, 2'b00, {9'd0, 12'h0}, {BLOCK_DATA_WIDTH{1'b0}}}, {
                       1'b0, 1'b0, 2'b00, {9'd0, 12'h0}, {BLOCK_DATA_WIDTH{1'b0}}});
    test_word_data = 32'hCAFE_BABE;
    cpu_write({{9'd0}, {12'hDEF}, {7'd0}, {4'd1}}, test_word_data);
    wait_for_cache_access();
    wait_for_mem_req();

    wait (uut.current_state == uut.IDLE);
    $display("Write successful, candidate write data: %h, new ages: %b, %b, %b, %b",
             uut.candidate_write, age_1, age_2, age_3, age_4);

    // Finish simulation                                                    
    $display("\nTestbench completed. Exiting...");
    $finish;
  end

  // Monitor signals                                                          
  initial begin
    $monitor(
        "Time: %0t | State: %b | cache_enable: %b | mem_req_enable: %b | bank_selector: %b | hit: %b | miss: %b",
        $time, uut.current_state, cache_enable, mem_req_enable, bank_selector, uut.hit, uut.miss);
  end

endmodule
