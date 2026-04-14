module mac (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire        clear_acc,
    input  wire        add_bias,

    // camada oculta: pixel 8b unsigned * peso 16b signed Q4.12
    input  wire [7:0]  pixel,
    input  wire [15:0] peso,

    // camada de saida: h 16b signed Q4.12 * beta 16b signed Q4.12
    input  wire signed [15:0] h_in,
    input  wire signed [15:0] beta,

    // 0 = camada oculta, 1 = camada de saida
    input  wire        use_h,

    input  wire [15:0] bias,
    output reg  signed [33:0] acumulador
);

// produto camada oculta: 8b * 16b = 24b signed
wire signed [23:0] produto_oculta = $signed({1'b0, pixel}) * $signed(peso);

// produto camada saida: 16b * 16b = 32b signed (precisao completa)
wire signed [31:0] produto_saida = $signed(h_in) * $signed(beta);

always @(posedge clk or posedge reset) begin
    if (reset)
        acumulador <= 34'sd0;
    else if (clear_acc)
        acumulador <= 34'sd0;
    else if (add_bias)
        acumulador <= acumulador + {{18{bias[15]}}, bias};
    else if (enable) begin
        if (use_h)
            acumulador <= acumulador + {{2{produto_saida[31]}}, produto_saida};
        else
            acumulador <= acumulador + {{10{produto_oculta[23]}}, produto_oculta};
    end
end

endmodule