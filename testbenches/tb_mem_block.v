`timescale 1ns/1ps
// ============================================================
// Testbench: mem_block
// O que testa (memórias que não dependem de arquivo .hex):
//   1. Escrita e leitura em MEM_IMG (sincrona: dado aparece 1 ciclo depois)
//   2. Escrita e leitura em MEM_H
//   3. Escrita e leitura em MEM_Y
// Nota: MEM_WIN, MEM_BIAS, MEM_BETA dependem dos arquivos .hex
//   Para simular sem os arquivos, basta ignorar win/b/beta outputs
//   ou criar arquivos dummy com zeros.
// ============================================================
module tb_mem_block;

reg        clk;

// IMG
reg  [9:0]  img_addr_w; reg [7:0]  img_data_w; reg img_wr_en;
reg  [9:0]  img_addr_r; wire [15:0] img_data_r;

// W_in (apenas leitura — depende de .hex)
reg  [16:0] win_addr_r; wire [15:0] win_data_r;

// BIAS
reg  [6:0]  b_addr_r; wire [15:0] b_data_r;

// BETA
reg  [13:0] beta_addr_r; wire [15:0] beta_data_r;

// H
reg  [6:0]  h_addr_w; reg [15:0] h_data_w; reg h_wr_en;
reg  [6:0]  h_addr_r; wire [15:0] h_data_r;

// Y
reg  [3:0]  y_addr_w; reg [15:0] y_data_w; reg y_wr_en;
reg  [3:0]  y_addr_r; wire [15:0] y_data_r;

mem_block uut (
    .clk(clk),
    .img_addr_w(img_addr_w), .img_data_w(img_data_w), .img_wr_en(img_wr_en),
    .img_addr_r(img_addr_r), .img_data_r(img_data_r),
    .win_addr_r(win_addr_r), .win_data_r(win_data_r),
    .b_addr_r(b_addr_r), .b_data_r(b_data_r),
    .beta_addr_r(beta_addr_r), .beta_data_r(beta_data_r),
    .h_addr_w(h_addr_w), .h_data_w(h_data_w), .h_wr_en(h_wr_en),
    .h_addr_r(h_addr_r), .h_data_r(h_data_r),
    .y_addr_w(y_addr_w), .y_data_w(y_data_w), .y_wr_en(y_wr_en),
    .y_addr_r(y_addr_r), .y_data_r(y_data_r)
);

always #5 clk = ~clk;

integer i, erro;

initial begin
    clk=0; erro=0;
    img_wr_en=0; h_wr_en=0; y_wr_en=0;
    win_addr_r=0; b_addr_r=0; beta_addr_r=0;

    @(posedge clk); #1;

    // === MEM_IMG: escreve pixels 0..9 com valor = indice+1 ===
    $display("--- MEM_IMG: escrita sequencial ---");
    for (i=0; i<10; i=i+1) begin
        img_addr_w = i[9:0]; img_data_w = i[7:0]+8'd1; img_wr_en=1;
        @(posedge clk); #1;
    end
    img_wr_en=0;

    // leitura: dado aparece 1 ciclo apos o endereco (BRAM sincrona)
    $display("--- MEM_IMG: leitura e verificacao ---");
    for (i=0; i<10; i=i+1) begin
        img_addr_r = i[9:0];
        @(posedge clk); #1; // ciclo de leitura
        // [15:8] = 0 (zero-pad), [7:0] = i+1
        if (img_data_r !== {8'b0, i[7:0]+8'd1}) begin
            $display("FALHOU IMG[%0d]: got=%0h esp=%0h",
                     i, img_data_r, {8'b0, i[7:0]+8'd1}); erro=erro+1;
        end else
            $display("OK IMG[%0d]=%0h", i, img_data_r);
    end

    // === MEM_H: escreve h[0..7] = Q4.12 de valores conhecidos ===
    $display("--- MEM_H: escrita e leitura ---");
    for (i=0; i<8; i=i+1) begin
        h_addr_w=i[6:0]; h_data_w=16'h0100*i[3:0]+16'h0100; h_wr_en=1;
        @(posedge clk); #1;
    end
    h_wr_en=0;
    for (i=0; i<8; i=i+1) begin
        h_addr_r=i[6:0]; @(posedge clk); #1;
        if (h_data_r !== 16'h0100*i[3:0]+16'h0100) begin
            $display("FALHOU H[%0d]: got=%0h", i, h_data_r); erro=erro+1;
        end else
            $display("OK H[%0d]=%0h", i, h_data_r);
    end

    // === MEM_Y: escreve y[0..9] ===
    $display("--- MEM_Y: escrita e leitura ---");
    for (i=0; i<10; i=i+1) begin
        y_addr_w=i[3:0]; y_data_w=16'h0F00-i[15:0]*16'h0100; y_wr_en=1;
        @(posedge clk); #1;
    end
    y_wr_en=0;
    for (i=0; i<10; i=i+1) begin
        y_addr_r=i[3:0]; @(posedge clk); #1;
        if (y_data_r !== 16'h0F00-i[15:0]*16'h0100) begin
            $display("FALHOU Y[%0d]: got=%0h", i, y_data_r); erro=erro+1;
        end else
            $display("OK Y[%0d]=%0h", i, y_data_r);
    end

    $display("=== %0d erro(s) ===", erro);
    $finish;
end
endmodule
