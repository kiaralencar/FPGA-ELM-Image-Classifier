`timescale 1ns/1ps
// ============================================================
// Testbench: mem_block (versão corrigida)
// Mudança: beta_addr_r agora é 11 bits (era 14) — corrigido.
// ============================================================
module tb_mem_block;

reg        clk;
reg  [9:0]  img_addr_w; reg [7:0]  img_data_w; reg img_wr_en;
reg  [9:0]  img_addr_r; wire [15:0] img_data_r;
reg  [16:0] win_addr_r; wire [15:0] win_data_r;
reg  [6:0]  b_addr_r;   wire [15:0] b_data_r;
reg  [10:0] beta_addr_r; wire [15:0] beta_data_r; // 11 bits agora
reg  [6:0]  h_addr_w; reg [15:0] h_data_w; reg h_wr_en;
reg  [6:0]  h_addr_r; wire [15:0] h_data_r;
reg  [3:0]  y_addr_w; reg [15:0] y_data_w; reg y_wr_en;
reg  [3:0]  y_addr_r; wire [15:0] y_data_r;

mem_block uut (
    .clk(clk),
    .img_addr_w(img_addr_w), .img_data_w(img_data_w), .img_wr_en(img_wr_en),
    .img_addr_r(img_addr_r), .img_data_r(img_data_r),
    .win_addr_r(win_addr_r), .win_data_r(win_data_r),
    .b_addr_r(b_addr_r),     .b_data_r(b_data_r),
    .beta_addr_r(beta_addr_r),.beta_data_r(beta_data_r),
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

    // === MEM_IMG: escreve pixels 0..9 com valor=indice+1 ===
    $display("--- MEM_IMG: escrita ---");
    for (i=0; i<10; i=i+1) begin
        img_addr_w=i[9:0]; img_data_w=i[7:0]+8'd1; img_wr_en=1;
        @(posedge clk); #1;
    end
    img_wr_en=0;

    // Leitura sincrona: dado aparece 1 ciclo apos endereco
    $display("--- MEM_IMG: leitura ---");
    for (i=0; i<10; i=i+1) begin
        img_addr_r=i[9:0]; @(posedge clk); #1;
        if (img_data_r !== {8'b0, i[7:0]+8'd1}) begin
            $display("FALHOU IMG[%0d]: got=%0h esp=%0h",
                     i, img_data_r, {8'b0,i[7:0]+8'd1}); erro=erro+1;
        end else $display("OK IMG[%0d]=%0h", i, img_data_r);
    end

    // === MEM_H ===
    $display("--- MEM_H: escrita e leitura ---");
    for (i=0; i<8; i=i+1) begin
        h_addr_w=i[6:0]; h_data_w=16'h0100*(i[3:0]+4'd1); h_wr_en=1;
        @(posedge clk); #1;
    end
    h_wr_en=0;
    for (i=0; i<8; i=i+1) begin
        h_addr_r=i[6:0]; @(posedge clk); #1;
        if (h_data_r !== 16'h0100*(i[3:0]+4'd1)) begin
            $display("FALHOU H[%0d]: got=%0h", i, h_data_r); erro=erro+1;
        end else $display("OK H[%0d]=%0h", i, h_data_r);
    end

    // === MEM_Y ===
    $display("--- MEM_Y: escrita e leitura ---");
    for (i=0; i<10; i=i+1) begin
        y_addr_w=i[3:0]; y_data_w=16'h0100*(i[3:0]+4'd1); y_wr_en=1;
        @(posedge clk); #1;
    end
    y_wr_en=0;
    for (i=0; i<10; i=i+1) begin
        y_addr_r=i[3:0]; @(posedge clk); #1;
        if (y_data_r !== 16'h0100*(i[3:0]+4'd1)) begin
            $display("FALHOU Y[%0d]: got=%0h", i, y_data_r); erro=erro+1;
        end else $display("OK Y[%0d]=%0h", i, y_data_r);
    end

    // === MEM_IMG: sobrescrita (verifica que escrita posterior vale) ===
    $display("--- MEM_IMG: sobrescrita ---");
    img_addr_w=10'd3; img_data_w=8'hEE; img_wr_en=1;
    @(posedge clk); #1; img_wr_en=0;
    img_addr_r=10'd3; @(posedge clk); #1;
    if (img_data_r !== {8'b0, 8'hEE}) begin
        $display("FALHOU sobrescrita: got=%0h", img_data_r); erro=erro+1;
    end else $display("OK sobrescrita IMG[3]=0x00EE");

    $display("=== %0d erro(s) ===", erro);
    $finish;
end
endmodule
