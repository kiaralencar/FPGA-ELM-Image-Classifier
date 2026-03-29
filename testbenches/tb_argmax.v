`timescale 1ns/1ps
// ============================================================
// Testbench: argmax
// O que testa:
//   1. reset correto
//   2. sequência y[0..9] onde y[3] é o maior → pred deve ser 3
//   3. sequência onde y[0] é o maior → pred deve ser 0
//   4. sequência onde y[9] é o maior → pred deve ser 9
// ============================================================
module tb_argmax;

reg        clk, reset, enable;
reg [15:0] y_in;
reg [3:0]  k;
wire [3:0] pred;
wire       done;

argmax uut (
    .clk(clk), .reset(reset), .enable(enable),
    .y_in(y_in), .k(k), .pred(pred), .done(done)
);

always #5 clk = ~clk;

// valores de y para o teste (10 entradas)
reg [15:0] y_vals [0:9];
integer i, erro;

task run_argmax;
    input [3:0] esperado;
    begin
        enable=1;
        for (i=0; i<10; i=i+1) begin
            k    = i[3:0];
            y_in = y_vals[i];
            @(posedge clk); #1;
        end
        enable=0;
        @(posedge clk); #1;
        if (pred !== esperado) begin
            $display("FALHOU: pred=%0d esperado=%0d", pred, esperado);
            erro=erro+1;
        end else
            $display("OK: pred=%0d", pred);
        // reset para proxima rodada
        reset=1; @(posedge clk); #1; reset=0;
    end
endtask

initial begin
    clk=0; reset=1; enable=0; k=0; y_in=0; erro=0;
    @(posedge clk); #1; reset=0;

    // --- Teste 1: maior no meio (k=3) ---
    $display("--- Teste 1: maior em k=3 ---");
    y_vals[0]=16'h0100; y_vals[1]=16'h0200; y_vals[2]=16'h0300;
    y_vals[3]=16'h0F00; // MAIOR
    y_vals[4]=16'h0400; y_vals[5]=16'h0300; y_vals[6]=16'h0200;
    y_vals[7]=16'h0100; y_vals[8]=16'h0050; y_vals[9]=16'h0020;
    run_argmax(4'd3);

    // --- Teste 2: maior no inicio (k=0) ---
    $display("--- Teste 2: maior em k=0 ---");
    y_vals[0]=16'h0F00; // MAIOR
    y_vals[1]=16'h0100; y_vals[2]=16'h0200; y_vals[3]=16'h0300;
    y_vals[4]=16'h0400; y_vals[5]=16'h0300; y_vals[6]=16'h0100;
    y_vals[7]=16'h0080; y_vals[8]=16'h0040; y_vals[9]=16'h0020;
    run_argmax(4'd0);

    // --- Teste 3: maior no fim (k=9) ---
    $display("--- Teste 3: maior em k=9 ---");
    y_vals[0]=16'h0020; y_vals[1]=16'h0040; y_vals[2]=16'h0080;
    y_vals[3]=16'h0100; y_vals[4]=16'h0200; y_vals[5]=16'h0300;
    y_vals[6]=16'h0400; y_vals[7]=16'h0500; y_vals[8]=16'h0600;
    y_vals[9]=16'h0F00; // MAIOR
    run_argmax(4'd9);

    // --- Teste 4: todos iguais → pred=0 (primeiro vence) ---
    $display("--- Teste 4: todos iguais, pred deve ser 0 ---");
    for (i=0; i<10; i=i+1) y_vals[i] = 16'h0800;
    run_argmax(4'd0);

    $display("=== %0d erro(s) ===", erro);
    $finish;
end
endmodule
