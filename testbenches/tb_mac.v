`timescale 1ns/1ps
// ============================================================
// Testbench: mac (versão corrigida)
// Conecta add_bias e bias corretamente.
// Novo teste 5 usa peso=0x00FF (menor) para evitar confusão
// com overflow — e testa add_bias separadamente.
// ============================================================
module tb_mac;

reg        clk, reset, enable, clear_acc;
reg        add_bias;
reg  [7:0] pixel;
reg  [15:0] peso;
reg  [15:0] bias;
wire [33:0] acumulador;

mac uut (
    .clk       (clk),
    .reset     (reset),
    .enable    (enable),
    .clear_acc (clear_acc),
    .pixel     (pixel),
    .peso      (peso),
    .acumulador(acumulador),
    .add_bias  (add_bias),
    .bias      (bias)
);

always #5 clk = ~clk;

integer erro;

initial begin
    clk=0; reset=1; enable=0; clear_acc=0; add_bias=0;
    pixel=0; peso=0; bias=0; erro=0;
    @(posedge clk); #1;

    // --- Teste 1: reset zera ---
    reset=0;
    $display("--- Teste 1: reset zera acumulador ---");
    if (acumulador !== 0) begin
        $display("FALHOU reset: acc=%0h", acumulador); erro=erro+1;
    end else $display("OK: acc=0 apos reset");

    // --- Teste 2: 3 acumulacoes pixel=10 peso=256 ---
    // 10 * 256 = 2560; x3 = 7680
    $display("--- Teste 2: 3 acumulacoes pixel=10 peso=256 ---");
    pixel=8'd10; peso=16'd256; enable=1;
    @(posedge clk); #1;
    @(posedge clk); #1;
    @(posedge clk); #1;
    enable=0;
    if (acumulador !== 34'd7680) begin
        $display("FALHOU: acc=%0d esperado=7680", acumulador); erro=erro+1;
    end else $display("OK: acc=7680");

    // --- Teste 3: enable=0 nao acumula ---
    $display("--- Teste 3: enable=0 nao acumula ---");
    @(posedge clk); #1;
    if (acumulador !== 34'd7680) begin
        $display("FALHOU: acc mudou sem enable"); erro=erro+1;
    end else $display("OK: acc mantido sem enable");

    // --- Teste 4: clear_acc zera ---
    $display("--- Teste 4: clear_acc ---");
    clear_acc=1; @(posedge clk); #1; clear_acc=0;
    if (acumulador !== 0) begin
        $display("FALHOU: clear nao zerou"); erro=erro+1;
    end else $display("OK: acc=0 apos clear");

    // --- Teste 5: add_bias soma o bias ao acumulador ---
    // Acumula pixel=4, peso=1000 por 2 ciclos → acc=8000
    // Depois add_bias com bias=0x0200 (512) → acc=8512
    $display("--- Teste 5: add_bias ---");
    pixel=8'd4; peso=16'd1000; enable=1;
    @(posedge clk); #1; // acc=4000
    @(posedge clk); #1; // acc=8000
    enable=0;
    bias=16'h0200; add_bias=1;
    @(posedge clk); #1;
    add_bias=0;
    if (acumulador !== 34'd8512) begin
        $display("FALHOU add_bias: acc=%0d esperado=8512", acumulador); erro=erro+1;
    end else $display("OK: add_bias somou bias corretamente, acc=8512");

    // --- Teste 6: produto com peso moderado sem overflow ---
    // pixel=200, peso=0x00FF=255  → 200*255=51000
    $display("--- Teste 6: produto moderado sem overflow ---");
    clear_acc=1; @(posedge clk); #1; clear_acc=0;
    pixel=8'd200; peso=16'h00FF; enable=1;
    @(posedge clk); #1; enable=0;
    if (acumulador !== 34'd51000) begin
        $display("FALHOU: acc=%0d esperado=51000", acumulador); erro=erro+1;
    end else $display("OK: acc=51000");

    // --- Teste 7: acumulacao negativa (peso com sinal negativo Q4.12) ---
    // peso=0xF000 = -4096 em complemento de 2 (16 bits com sinal)
    // pixel=1 → produto signed = 1 * (-4096) = -4096
    // acc deve acumular corretamente em 34 bits com sinal
    $display("--- Teste 7: peso negativo (signed) ---");
    clear_acc=1; @(posedge clk); #1; clear_acc=0;
    pixel=8'd1; peso=16'hF000; enable=1;
    @(posedge clk); #1; enable=0;
    // 1 * 0xF000 interpretado como signed = -4096
    // Em 34 bits complemento de 2: 34'h3_FFFFF000
    if ($signed(acumulador) !== -34'sd4096) begin
        $display("FALHOU peso neg: acc=%0d esperado=-4096", $signed(acumulador));
        erro=erro+1;
    end else $display("OK: acumulacao com peso negativo correta");

    $display("=== %0d erro(s) ===", erro);
    $finish;
end
endmodule
