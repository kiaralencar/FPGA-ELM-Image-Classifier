module mac (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire clear_acc,
    input wire add_bias,

    // Camada oculta: pixel 8b (sem sinal) * peso 16b (com sinal) - formato Q4.12
    input wire [7:0] pixel,
    input wire [15:0] peso,

    // Camada de saida: h 16b (com sinal) Q4.12 * beta 16b (com sinal) - formato Q4.12
    input wire signed [15:0] h_in,
    input wire signed [15:0] beta,

    // 0 = camada oculta, 1 = camada de saida
    input wire use_h,

    input  wire [15:0] bias,
    output reg signed [33:0] acumulador
);

// Produto camada oculta: 8b * 16b = 24b (com sinal)
wire signed [23:0] produto_oculta = $signed({1'b0, pixel}) * $signed(peso);

// Produto camada saida: 16b * 16b = 32b (com sinal - precisao completa)
wire signed [31:0] produto_saida = $signed(h_in) * $signed(beta);

always @(posedge clk or posedge reset) begin
    if (reset)
        acumulador <= 34'sd0; // Zera o acumulador quando reset pressionado
    else if (clear_acc)
        acumulador <= 34'sd0; // Zera o acumulador para o calculo de um novo neuronio
    else if (add_bias)
        acumulador <= acumulador + {{18{bias[15]}}, bias}; // Estende o bias e o soma ao produto
    else if (enable) begin
        if (use_h)
            acumulador <= acumulador + {{2{produto_saida[31]}}, produto_saida}; // Acumula 128 produtos (128 neuronios ocultos)
        else
            acumulador <= acumulador + {{10{produto_oculta[23]}}, produto_oculta}; // Acumula 784 produtos (784 pixels)
    end
end

endmodule