module mac (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire        clear_acc,
    input  wire        add_bias,
    input  wire [7:0]  pixel,
    input  wire [15:0] peso,
    input  wire [15:0] bias,
    output reg  [33:0] acumulador
);

always @(posedge clk or posedge reset) begin
    if (reset)
        acumulador <= 0;
    else if (clear_acc)
        acumulador <= 0;
    else if (add_bias)
        acumulador <= acumulador + {{18{bias[15]}}, bias};
    else if (enable)
        acumulador <= acumulador + ({{26{pixel[7]}}, pixel} * {{18{peso[15]}}, peso});
end

endmodule