`timescale 1ns/1ps
// ============================================================
// Testbench: activation (LUT tanh)
// O que testa:
//   A LUT usa acc_in[19:12] como índice (8 bits).
//   Montamos acc_in para que [19:12] = índice desejado.
//   Valores conhecidos da LUT:
//     idx=0   → 0x000A  (tanh ≈ 0 para entrada muito negativa)
//     idx=128 → 0x0818  (tanh ≈ 0 para z=0, ponto médio da LUT)
//     idx=255 → 0x0FF6  (tanh ≈ 1 para entrada muito positiva)
// ============================================================
module tb_activation;

reg        clk;
reg [33:0] acc_in;
wire [15:0] result;

activation uut (
    .clk(clk), .acc_in(acc_in), .result(result)
);

always #5 clk = ~clk;

// monta acc_in colocando o indice nos bits [19:12]
function [33:0] make_acc;
    input [7:0] idx;
    begin make_acc = {14'b0, idx, 12'b0}; end
endfunction

integer erro;

task check_lut;
    input [7:0]  idx;
    input [15:0] esperado;
    begin
        acc_in = make_acc(idx);
        @(posedge clk); #1; // LUT registrada
        if (result !== esperado) begin
            $display("FALHOU idx=%0d: result=%0h esperado=%0h",
                     idx, result, esperado);
            erro=erro+1;
        end else
            $display("OK idx=%0d: result=%0h", idx, result);
    end
endtask

initial begin
    clk=0; acc_in=0; erro=0;
    @(posedge clk); #1;

    $display("--- Verificando entradas conhecidas da LUT ---");
    check_lut(8'd0,   16'h000A);
    check_lut(8'd128, 16'h0818);
    check_lut(8'd255, 16'h0FF6);
    check_lut(8'd64,  16'h00C4);
    check_lut(8'd192, 16'h0F44);

    $display("--- Verificando default (indice invalido nao ocorre pois 8b cobre tudo) ---");
    // todos 256 indices sao cobertos; nao ha default atingivel, mas
    // podemos verificar que a saida nunca fica em X
    begin : blk
        integer j;
        for (j=0; j<256; j=j+1) begin
            acc_in = make_acc(j[7:0]);
            @(posedge clk); #1;
            if (result === 16'hXXXX) begin
                $display("FALHOU: saida X para idx=%0d", j); erro=erro+1;
            end
        end
        $display("OK: todos 256 indices produzem saida valida");
    end

    $display("=== %0d erro(s) ===", erro);
    $finish;
end
endmodule
