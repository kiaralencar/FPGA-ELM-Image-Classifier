`timescale 1ns/1ps
// ============================================================
// Testbench: mac
// O que testa:
//   1. reset zera o acumulador
//   2. clear_acc zera sem reset
//   3. acumulação de pixel * peso por 3 ciclos
//   4. enable=0 não acumula
// Resultado esperado (manual):
//   pixel=10 (0x0A), peso=0x0100 (Q4.12 = 0.0625)
//   produto = 10 * 256 = 2560 = 0xA00
//   após 3 ciclos: acc = 3 * 2560 = 7680 = 0x1E00
// ============================================================
module tb_mac;

reg        clk, reset, enable, clear_acc;
reg  [7:0] pixel;
reg  [15:0] peso;
wire [33:0] acumulador;

mac uut (
    .clk(clk), .reset(reset), .enable(enable),
    .clear_acc(clear_acc), .pixel(pixel),
    .peso(peso), .acumulador(acumulador)
);

// clock 10ns
always #5 clk = ~clk;

task check;
    input [33:0] esperado;
    input [63:0] descricao; // apenas para waveform
    begin
        if (acumulador !== esperado)
            $display("FALHOU: acc=%0h esperado=%0h", acumulador, esperado);
        else
            $display("OK:     acc=%0h", acumulador);
    end
endtask

integer erro = 0;

initial begin
    clk=0; reset=1; enable=0; clear_acc=0;
    pixel=0; peso=0;
    @(posedge clk); #1;

    // --- Teste 1: reset zera ---
    reset=0;
    $display("--- Teste 1: reset zera acumulador ---");
    if (acumulador !== 0) begin $display("FALHOU reset"); erro=erro+1; end
    else $display("OK: acc=0 apos reset");

    // --- Teste 2: acumula 3x pixel=10, peso=256 ---
    $display("--- Teste 2: 3 acumulacoes pixel=10 peso=256 ---");
    pixel=8'd10; peso=16'd256; enable=1;
    @(posedge clk); #1; // acc = 2560
    @(posedge clk); #1; // acc = 5120
    @(posedge clk); #1; // acc = 7680
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

    // --- Teste 5: produto maximo (sem overflow) ---
    $display("--- Teste 5: produto maximo pixel=255 peso=0x7FFF ---");
    pixel=8'd255; peso=16'h7FFF; enable=1;
    @(posedge clk); #1; enable=0;
    // 255 * 32767 = 8355585 = 0x7F7F81
    if (acumulador !== 34'd8355585) begin
        $display("FALHOU: acc=%0d esperado=8355585", acumulador); erro=erro+1;
    end else $display("OK: produto maximo sem overflow");

    $display("=== %0d erro(s) ===", erro);
    $finish;
end
endmodule
