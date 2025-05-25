module replacer #(
    parameter WORD_SIZE  = 32,  // Size of each word
    parameter BLOCK_SIZE = 512,  // Total block size,
    parameter NUM_SEGMENTS = 16,  // Number of segments to write
    parameter NUM_SEGMENTS_LOG = 4  // Log2 of NUM_SEGMENTS
) (
    input wire [BLOCK_SIZE-1:0] data_in,
    input wire [NUM_SEGMENTS_LOG-1:0] block_offset,  // block_offset signal to select the segment
    input wire [WORD_SIZE-1:0] data_write,  // Data to overwrite
    input wire enable,
    output reg [BLOCK_SIZE-1:0] data_out  // Data output
);

  always @(*) begin
    data_out = data_in;
    if (enable) begin
      case (block_offset)
        0: data_out[0*WORD_SIZE+:WORD_SIZE] = data_write;
        1: data_out[1*WORD_SIZE+:WORD_SIZE] = data_write;
        2: data_out[2*WORD_SIZE+:WORD_SIZE] = data_write;
        3: data_out[3*WORD_SIZE+:WORD_SIZE] = data_write;
        4: data_out[4*WORD_SIZE+:WORD_SIZE] = data_write;
        5: data_out[5*WORD_SIZE+:WORD_SIZE] = data_write;
        6: data_out[6*WORD_SIZE+:WORD_SIZE] = data_write;
        7: data_out[7*WORD_SIZE+:WORD_SIZE] = data_write;
        8: data_out[8*WORD_SIZE+:WORD_SIZE] = data_write;
        9: data_out[9*WORD_SIZE+:WORD_SIZE] = data_write;
        10: data_out[10*WORD_SIZE+:WORD_SIZE] = data_write;
        11: data_out[11*WORD_SIZE+:WORD_SIZE] = data_write;
        12: data_out[12*WORD_SIZE+:WORD_SIZE] = data_write;
        13: data_out[13*WORD_SIZE+:WORD_SIZE] = data_write;
        14: data_out[14*WORD_SIZE+:WORD_SIZE] = data_write;
        15: data_out[15*WORD_SIZE+:WORD_SIZE] = data_write;
        default: ;
      endcase
    end
  end

endmodule
