module mac (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire        clear_acc,
    input  wire [7:0]  pixel,
    input  wire [15:0] peso,
    output reg  [33:0] acumulador
);

always @(posedge clk or posedge reset) begin
    if (reset)
        acumulador <= 0;
    else if (clear_acc)
        acumulador <= 0;
    else if (enable)
        acumulador <= acumulador + (pixel * peso);
end

endmodule