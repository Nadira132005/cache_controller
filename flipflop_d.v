module flipflop_d #(
    parameter WIDTH = 32
) (
    input      clk,
    input      rst_n,
    input      load,
    input  [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= {WIDTH{1'b0}};  // Initialize all bits to 0
        end else if (load) begin
            q <= d;
        end
    end

endmodule
