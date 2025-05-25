module cache_controller_tb();

    // Parameters
    parameter WORD_SIZE = 32;
    parameter BLOCK_OFFSET = 4;  // 16 words per block
    parameter SETS = 128;
    parameter SETS_BITS = 7;
    parameter AGE_BITS = 2;
    parameter TAG_BITS = 21;
    parameter BLOCK_DATA_WIDTH = 512;
    parameter DIRTY_BIT = 1;
    parameter VALID_BIT = 1;
    parameter BANK = 4;

    // Inputs
    reg clk;
    reg rst_n;
    reg [WORD_SIZE-1:0] cpu_req_addr;
    reg [WORD_SIZE-1:0] cpu_req_datain;
    reg cpu_req_rw;
    reg cpu_req_enable;
    reg [WORD_SIZE-1:0] mem_req_datain;
    reg [BLOCK_DATA_WIDTH-1:0] candidate_1;
    reg [BLOCK_DATA_WIDTH-1:0] candidate_2;
    reg [BLOCK_DATA_WIDTH-1:0] candidate_3;
    reg [BLOCK_DATA_WIDTH-1:0] candidate_4;
    reg mem_req_ready;
    reg cache_ready;

    // Outputs
    wire [WORD_SIZE-1:0] cpu_res_dataout;
    wire cpu_res_ready;
    wire [WORD_SIZE-1:0] mem_req_addr;
    wire mem_req_rw;
    wire mem_req_enable;
    wire [BLOCK_DATA_WIDTH-1:0] mem_req_dataout;
    wire [BLOCK_DATA_WIDTH-1:0] candidate_write;
    wire [BANK-1:0] bank_selector;
    wire [BANK-1:0] bank_selector_miss;
    wire [AGE_BITS-1:0] age_1;
    wire [AGE_BITS-1:0] age_2;
    wire [AGE_BITS-1:0] age_3;
    wire [AGE_BITS-1:0] age_4;
    wire [WORD_SIZE-1:0] cpu_addr_block_offset;
    wire [WORD_SIZE-1:0] cpu_addr_index;
    wire [WORD_SIZE-1:0] cpu_addr_tag;
    wire cahce_rw;
    wire cache_enable;

    // Instantiate the cache_controller module
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
        .mem_req_datain(mem_req_datain),
        .mem_req_dataout(mem_req_dataout),
        .mem_req_addr(mem_req_addr),
        .mem_req_rw(mem_req_rw),
        .mem_req_enable(mem_req_enable),
        .candidate_1(candidate_1),
        .candidate_2(candidate_2),
        .candidate_3(candidate_3),
        .candidate_4(candidate_4),
        .bank_selector(bank_selector),
        .age_1(age_1),
        .age_2(age_2),
        .age_3(age_3),
        .age_4(age_4),
        .cache_ready(cache_ready),
        .cache_rw(cache_rw),
        .cache_enable(cache_enable),
        .candidate_write(candidate_write)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Reset generation
    task reset_system;
    begin
        rst_n = 1'b0;
        #20 rst_n = 1'b1;
    end
    endtask

    // Test memory data
    reg [BLOCK_DATA_WIDTH-1:0] test_memory [0:31];
    reg [BLOCK_DATA_WIDTH-1:0] expected_cache_write;

    // Main test process
    initial begin
        // Initialize test memory
        test_memory[0] = 512'hDEADBEEF_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
        test_memory[1] = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
        test_memory[2] = 512'hCAFEFACE_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
        test_memory[3] = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000;

        // Initialize cache_read
        cache_read = 1'b1;

        // Initialize inputs
        cpu_req_addr = 0;
        cpu_req_datain = 0;
        cpu_req_rw = 0;
        cpu_req_enable = 0;
        mem_req_datain = 0;
        candidate_1 = 0;
        candidate_2 = 0;
        candidate_3 = 0;
        candidate_4 = 0;
        mem_req_ready = 0;

        // Start with reset
        reset_system();
        #20;

        // Test case 1: Read hit
        $display("Test 1: Read hit");
        // Set up cache with valid data
        cpu_req_addr = 32'h00000000;  // Address in block 0
        {candidate_1, candidate_2, candidate_3, candidate_4} = {
            {1'b1, 1'b0, 2'b00, 21'h00000, 512'hDEADBEEF_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b0, 2'b00, 21'h00000, 512'hB16B00B5_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b0, 2'b00, 21'h00000, 512'hFA11FA11_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b0, 2'b00, 21'h00000, 512'hB0B0B0B0_00000000_00000000_00000000_00000000_00000000_00000000_00000000}
        };
        #10;  // Wait for cache_read to register
        cpu_req_rw = 0;  // Read operation
        cpu_req_enable = 1;
        #10;
        cpu_req_enable = 0;
        #10;
        if (cpu_res_ready && cpu_res_dataout == 32'hDEADBEEF) begin
            $display("PASS: Read hit returned correct data");
        end else begin
            $display("FAIL: Read hit didn't return correct data");
        end
        #10;

        // Test case 2: Read miss with valid write back
        $display("Test 2: Read miss with valid write back");
        // Set up cache with dirty data
        {candidate_1, candidate_2, candidate_3, candidate_4} = {
            {1'b1, 1'b1, 2'b11, 21'h00001, 512'hDEADBEEF_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b1, 2'b10, 21'h00002, 512'hB16B00B5_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b1, 2'b01, 21'h00003, 512'hFA11FA11_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b1, 2'b00, 21'h00004, 512'hB0B0B0B0_00000000_00000000_00000000_00000000_00000000_00000000_00000000}
        };
        #10;  // Wait for cache_read to register

        // Request data that is not in cache
        cpu_req_addr = 32'h00000010;  // Block offset 0, different tag
        cpu_req_rw = 0;  // Read operation
        cpu_req_enable = 1;
        #10;
        cpu_req_enable = 0;
        #20;

        // Check if we're in EVICT state
        if (uut.current_state == EVICT) begin
            $display("PASS: Read miss triggered eviction");
        end else begin
            $display("FAIL: Read miss didn't trigger eviction when needed");
        end
        #10;

        // Test case 3: Write hit
        $display("Test 3: Write hit");
        // Use same address as test case 1
        cpu_req_addr = 32'h00000000;  // Address in block 0
        cpu_req_datain = 32'h12345678;
        cpu_req_rw = 1;  // Write operation
        cpu_req_enable = 1;
        #10;
        cpu_req_enable = 0;
        #10;

        if (uut.current_state == SEND_TO_CACHE) begin
            $display("PASS: Write hit moved to SEND_TO_CACHE state");
        end else begin
            $display("FAIL: Write hit didn't move to SEND_TO_CACHE state");
        end

        #10;
        // Check if the dirty bit was set
        if (uut.candidate_write[DIRTY_BIT_START+DIRTY_BIT-1:DIRTY_BIT_START] == 1'b1) begin
            $display("PASS: Dirty bit set on write hit");
        end else begin
            $display("FAIL: Dirty bit not set on write hit");
        end

        // Test case 4: Write miss with no eviction needed
        $display("Test 4: Write miss with no eviction needed");
        // Set up cache with invalid data
        {candidate_1, candidate_2, candidate_3, candidate_4} = {
            {1'b0, 1'b0, 2'b00, 21'h00000, 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b0, 1'b0, 2'b00, 21'h00000, 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b0, 1'b0, 2'b00, 21'h00000, 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b0, 1'b0, 2'b00, 21'h00000, 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000}
        };
        #10;  // Wait for cache_read to register

        // Write to an address that needs allocation
        cpu_req_addr = 32'h00000000;
        cpu_req_datain = 32'h87654321;
        cpu_req_rw = 1;  // Write operation
        cpu_req_enable = 1;
        #10;
        cpu_req_enable = 0;
        #20;

        if (uut.current_state == ALLOCATE) begin
            $display("PASS: Write miss transitioned to ALLOCATE state");
        end else begin
            $display("FAIL: Write miss didn't transition to ALLOCATE state");
        end

        // Test case 5: Read miss with no write back needed
        $display("Test 5: Read miss with no write back needed");
        // Set up cache with clean data
        {candidate_1, candidate_2, candidate_3, candidate_4} = {
            {1'b1, 1'b0, 2'b11, 21'h00005, 512'hDEADBEEF_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b0, 2'b10, 21'h00006, 512'hB16B00B5_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b0, 2'b01, 21'h00007, 512'hFA11FA11_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b0, 2'b00, 21'h00008, 512'hB0B0B0B0_00000000_00000000_00000000_00000000_00000000_00000000_00000000}
        };
        #10;  // Wait for cache_read to register

        // Request data that is not in cache
        cpu_req_addr = 32'h00000020;  // Different tag
        cpu_req_rw = 0;  // Read operation
        cpu_req_enable = 1;
        #10;
        cpu_req_enable = 0;
        #20;

        if (uut.current_state == ALLOCATE) begin
            $display("PASS: Read miss transitioned to ALLOCATE state");
        end else begin
            $display("FAIL: Read miss didn't transition to ALLOCATE state");
        end

        // Test case 6: LRU age updates
        $display("Test 6: LRU age updates");
        // Read a series of addresses to test LRU behavior
        integer i;
        for (i = 0; i < 4; i = i + 1) begin
            cpu_req_addr = {3'b0, i[1:0], 4'b0};  // Different indices
            cpu_req_rw = 0;  // Read operation
            cpu_req_enable = 1;
            #10;
            cpu_req_enable = 0;
            #20;
        end

        // Check age values
        $display("Final ages: %b %b %b %b", age_1, age_2, age_3, age_4);
        if (age_1 == 2'b00 && age_2 == 2'b00 && age_3 == 2'b00 && age_4 == 2'b00) begin
            $display("FAIL: Ages not updated correctly");
        end else begin
            $display("PASS: Age updates observed");
        end

        // Test case 7: Write miss with eviction
        $display("Test 7: Write miss with eviction");
        // Fill cache with dirty data
        {candidate_1, candidate_2, candidate_3, candidate_4} = {
            {1'b1, 1'b1, 2'b11, 21'h00001, 512'hDEADBEEF_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b1, 2'b10, 21'h00002, 512'hB16B00B5_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b1, 2'b01, 21'h00003, 512'hFA11FA11_00000000_00000000_00000000_00000000_00000000_00000000_00000000},
            {1'b1, 1'b1, 2'b00, 21'h00004, 512'hB0B0B0B0_00000000_00000000_00000000_00000000_00000000_00000000_00000000}
        };
        #10;  // Wait for cache_read to register

        // Try to write to a block that's not in cache
        cpu_req_addr = 32'h00000100;  // Different tag
        cpu_req_datain = 32'h11223344;
        cpu_req_rw = 1;  // Write operation
        cpu_req_enable = 1;
        #10;
        cpu_req_enable = 0;
        #20;

        if (uut.current_state == EVICT) begin
            $display("PASS: Write miss triggered eviction");
        end else begin
            $display("FAIL: Write miss didn't trigger eviction");
        end

        // Finish
        $display("Cache controller testbench completed");
        $finish;
    end
endmodule
