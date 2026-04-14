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

// Produto intermediário: pixel (8b unsigned) * peso (16b signed) = 24b signed
// Declarado com o tamanho exato do resultado para não truncar
wire signed [23:0] produto = $signed({1'b0, pixel}) * $signed(peso);

always @(posedge clk or posedge reset) begin
    if (reset)
        acumulador <= 34'd0;
    else if (clear_acc)
        acumulador <= 34'd0;
    else if (add_bias)
        // bias é Q4.12 com sinal: extensão de sinal de 16 para 34 bits
        acumulador <= acumulador + {{18{bias[15]}}, bias};
    else if (enable)
        // produto é 24b signed: extensão de sinal de 24 para 34 bits
        acumulador <= acumulador + {{10{produto[23]}}, produto};
end

endmodule
