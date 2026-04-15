// Modulo de ativação — tanh aproximada por 20 segmentos lineares em Q4.12

module activation (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire signed [15:0] acc_in, // Q4.12
    output wire signed [15:0] result // Q4.12, entre -1 e +1
);
    // Saturacao
    localparam signed [15:0] SAT_POS = 16'sd4095; // +0.9998
    localparam signed [15:0] SAT_NEG = -16'sd4095; // -0.9998

    // Valores tanh nos breakpoints em Q4.12
    localparam signed [15:0] Y00 = 16'sd0; // tanh(0.00)
    localparam signed [15:0] Y01 = 16'sd1003; // tanh(0.25)
    localparam signed [15:0] Y02 = 16'sd1893; // tanh(0.50)
    localparam signed [15:0] Y03 = 16'sd2602; // tanh(0.75)
    localparam signed [15:0] Y04 = 16'sd3119; // tanh(1.00)
    localparam signed [15:0] Y05 = 16'sd3475; // tanh(1.25)
    localparam signed [15:0] Y06 = 16'sd3707; // tanh(1.50)
    localparam signed [15:0] Y07 = 16'sd3856; // tanh(1.75)
    localparam signed [15:0] Y08 = 16'sd3949; // tanh(2.00)
    localparam signed [15:0] Y09 = 16'sd4041; // tanh(2.50)
    localparam signed [15:0] Y10 = 16'sd4076; // tanh(3.00)
    localparam signed [15:0] Y11 = 16'sd4089; // tanh(3.50)
    localparam signed [15:0] Y12 = 16'sd4093; // tanh(4.00)
    localparam signed [15:0] Y13 = 16'sd4095; // tanh(4.50) — satura

    // Breakpoints em Q4.12
    localparam signed [15:0] L01 = 16'h0400; // 0.25
    localparam signed [15:0] L02 = 16'h0800; // 0.50
    localparam signed [15:0] L03 = 16'h0C00; // 0.75
    localparam signed [15:0] L04 = 16'h1000; // 1.00
    localparam signed [15:0] L05 = 16'h1400; // 1.25
    localparam signed [15:0] L06 = 16'h1800; // 1.50
    localparam signed [15:0] L07 = 16'h1C00; // 1.75
    localparam signed [15:0] L08 = 16'h2000; // 2.00
    localparam signed [15:0] L09 = 16'h2800; // 2.50
    localparam signed [15:0] L10 = 16'h3000; // 3.00
    localparam signed [15:0] L11 = 16'h3800; // 3.50
    localparam signed [15:0] L12 = 16'h4000; // 4.00
    localparam signed [15:0] L13 = 16'h4800; // 4.50 — a partir daqui satura

    // Slopes em Q4.12 (slope * 4096, arredondado)
    // slope aplicado como: dy = (dx * slope_q) >>> 12
    localparam signed [15:0] S00 = 16'sd4013; // [0.00, 0.25]
    localparam signed [15:0] S01 = 16'sd3559; // [0.25, 0.50]
    localparam signed [15:0] S02 = 16'sd2835; // [0.50, 0.75]
    localparam signed [15:0] S03 = 16'sd2072; // [0.75, 1.00]
    localparam signed [15:0] S04 = 16'sd1420; // [1.00, 1.25]
    localparam signed [15:0] S05 = 16'sd932; // [1.25, 1.50]
    localparam signed [15:0] S06 = 16'sd594; // [1.50, 1.75]
    localparam signed [15:0] S07 = 16'sd371; // [1.75, 2.00]
    localparam signed [15:0] S08 = 16'sd185; // [2.00, 2.50]
    localparam signed [15:0] S09 = 16'sd69; // [2.50, 3.00]
    localparam signed [15:0] S10 = 16'sd26; // [3.00, 3.50]
    localparam signed [15:0] S11 = 16'sd9; // [3.50, 4.00]
    localparam signed [15:0] S12 = 16'sd3; // [4.00, 4.50]

    // Logica combinacional
    reg sign_neg;
    reg [15:0] x_abs;
    reg signed [15:0] x0_seg;
    reg signed [15:0] y0_seg;
    reg signed [15:0] slope_seg;
    reg signed [31:0] delta_x;
    reg signed [31:0] interp;
    reg signed [15:0] y_abs;
    reg signed [15:0] d_out_comb;

    always @(*) begin
        sign_neg = acc_in[15];
        // Valor absoluto
        if (sign_neg) 
            x_abs = (~acc_in + 16'd1); // Caso o MSB seja 1, faz o comp de 2. 
        else
            x_abs = acc_in; // Caso seja zero mantem.

        // Defaults
        x0_seg = 16'sd0;
        y0_seg = Y00;
        slope_seg = S00;

        // Seleciona segmento
        if (x_abs < L01) begin x0_seg = 16'sd0; y0_seg = Y00; slope_seg = S00; end
        else if (x_abs < L02) begin x0_seg = L01; y0_seg = Y01; slope_seg = S01; end
        else if (x_abs < L03) begin x0_seg = L02; y0_seg = Y02; slope_seg = S02; end
        else if (x_abs < L04) begin x0_seg = L03; y0_seg = Y03; slope_seg = S03; end
        else if (x_abs < L05) begin x0_seg = L04; y0_seg = Y04; slope_seg = S04; end
        else if (x_abs < L06) begin x0_seg = L05; y0_seg = Y05; slope_seg = S05; end
        else if (x_abs < L07) begin x0_seg = L06; y0_seg = Y06; slope_seg = S06; end
        else if (x_abs < L08) begin x0_seg = L07; y0_seg = Y07; slope_seg = S07; end
        else if (x_abs < L09) begin x0_seg = L08; y0_seg = Y08; slope_seg = S08; end
        else if (x_abs < L10) begin x0_seg = L09; y0_seg = Y09; slope_seg = S09; end
        else if (x_abs < L11) begin x0_seg = L10; y0_seg = Y10; slope_seg = S10; end
        else if (x_abs < L12) begin x0_seg = L11; y0_seg = Y11; slope_seg = S11; end
        else if (x_abs < L13) begin x0_seg = L12; y0_seg = Y12; slope_seg = S12; end
        else begin
            // |x| >= 4.5 — satura
            x0_seg = 16'sd0;
            y0_seg = Y13;
            slope_seg = 16'sd0;
        end

        // Interpolacao: y = y0 + (x - x0) * slope >>> 12
        delta_x = $signed({16'd0, x_abs}) - $signed({16'd0, x0_seg});
        interp = (delta_x * $signed(slope_seg)) >>> 12;
        y_abs = y0_seg + interp[15:0];

        // Clamp positivo
        if (y_abs > SAT_POS) y_abs = SAT_POS;
        if (y_abs < 16'sd0) y_abs = 16'sd0;

        // Aplica sinal (tanh e impar: tanh(-x) = -tanh(x))
        if (sign_neg)
            d_out_comb = -y_abs;
        else
            d_out_comb = y_abs;

        // Saturacao final
        if (d_out_comb > SAT_POS) d_out_comb = SAT_POS;
        else if (d_out_comb < SAT_NEG) d_out_comb = SAT_NEG;
    end

    assign result = enable ? d_out_comb : 16'sd0;

endmodule