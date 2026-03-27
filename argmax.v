module argmax (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire [15:0] y_in,
    input  wire [3:0]  k,
    output reg  [3:0]  pred,
    output reg         done
);

reg [15:0] maior;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        maior <= 16'h0000;
        pred  <= 4'd0;
        done  <= 1'b0;
    end
    else if (enable) begin
        if (k == 4'd0) begin
            maior <= y_in;
            pred  <= 4'd0;
            done  <= 1'b0;
        end
        else if (y_in > maior) begin
            maior <= y_in;
            pred  <= k;
        end
        if (k == 4'd9)
            done <= 1'b1;
    end
end

endmodule