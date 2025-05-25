module block_selector #(
    parameter WORD_SIZE = 32,
    parameter BLOCK_DATA_WIDTH = 512
) (
    input wire [BLOCK_DATA_WIDTH-1:0] block_data,
    input wire [3:0] block_offset,  // 4 bits for 16 possible words (16 * 32 = 512)
    output reg [WORD_SIZE-1:0] selected_word
);

always @(*) begin
    case (block_offset)
        4'd0:  selected_word = block_data[31:0];
        4'd1:  selected_word = block_data[63:32];
        4'd2:  selected_word = block_data[95:64];
        4'd3:  selected_word = block_data[127:96];
        4'd4:  selected_word = block_data[159:128];
        4'd5:  selected_word = block_data[191:160];
        4'd6:  selected_word = block_data[223:192];
        4'd7:  selected_word = block_data[255:224];
        4'd8:  selected_word = block_data[287:256];
        4'd9:  selected_word = block_data[319:288];
        4'd10: selected_word = block_data[351:320];
        4'd11: selected_word = block_data[383:352];
        4'd12: selected_word = block_data[415:384];
        4'd13: selected_word = block_data[447:416];
        4'd14: selected_word = block_data[479:448];
        4'd15: selected_word = block_data[511:480];
        default: selected_word = 32'd0;
    endcase
end

endmodule
