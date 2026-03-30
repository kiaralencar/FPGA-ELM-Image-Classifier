`timescale 1ns/1ps
// ============================================================
// Testbench: uc (versão corrigida)
// Problema anterior: campos de bits da instrução montados
// nas posições erradas. Corrigido montando bit a bit conforme
// o uc.v real:
//   STORE_IMG  (op=1): [31:28]=op [25:16]=img_addr [15:8]=pixel
//   STORE_W    (op=2): [31:28]=op [27:11]=win_addr  [15:0]=data
//   STORE_BIAS (op=3): [31:28]=op [22:16]=b_addr    [15:0]=data
//   START      (op=4): [31:28]=op [27:0]=zeros
//   STATUS     (op=5): [31:28]=op
// ============================================================
module tb_uc;

reg        clk, reset, instr_valid, infer_done, infer_busy;
reg [31:0] instruction;
reg [3:0]  infer_pred;

wire [9:0]  img_addr_w; wire [7:0]  img_data_w; wire img_wr_en;
wire [16:0] win_addr_w; wire [15:0] win_data_w; wire win_wr_en;
wire [6:0]  b_addr_w;   wire [15:0] b_data_w;   wire b_wr_en;
wire [13:0] beta_addr_w;wire [15:0] beta_data_w;wire beta_wr_en;
wire        start_infer;
wire [1:0]  status;
wire [3:0]  pred;

uc uut (
    .clk(clk), .reset(reset),
    .instruction(instruction), .instr_valid(instr_valid),
    .infer_done(infer_done), .infer_busy(infer_busy), .infer_pred(infer_pred),
    .img_addr_w(img_addr_w), .img_data_w(img_data_w), .img_wr_en(img_wr_en),
    .win_addr_w(win_addr_w), .win_data_w(win_data_w), .win_wr_en(win_wr_en),
    .b_addr_w(b_addr_w),     .b_data_w(b_data_w),     .b_wr_en(b_wr_en),
    .beta_addr_w(beta_addr_w),.beta_data_w(beta_data_w),.beta_wr_en(beta_wr_en),
    .start_infer(start_infer),
    .status(status)
);

always #5 clk = ~clk;

integer erro;

task send;
    input [31:0] instr;
    begin
        instruction=instr; instr_valid=1;
        @(posedge clk); #1;
        instr_valid=0;
        @(posedge clk); #1; // ciclo extra para sinais se propagarem
    end
endtask

initial begin
    clk=0; reset=1; instr_valid=0; infer_done=0; infer_busy=0;
    instruction=0; infer_pred=0; erro=0;
    @(posedge clk); #1; reset=0; @(posedge clk); #1;

    // --- Teste 1: STORE_IMG addr=5 pixel=0xAB ---
    // [31:28]=1  [27:26]=00  [25:16]=addr=5  [15:8]=pixel=0xAB  [7:0]=00
    $display("--- Teste 1: STORE_IMG addr=5 pixel=0xAB ---");
    send({4'd1, 2'b00, 10'd5, 8'hAB, 8'h00});
    if (img_wr_en && img_addr_w==10'd5 && img_data_w==8'hAB)
        $display("OK: img_wr_en=1 addr=5 pixel=0xAB");
    else begin
        $display("FALHOU: wr_en=%b addr=%0d pixel=%0h",
                 img_wr_en, img_addr_w, img_data_w); erro=erro+1;
    end

    // --- Teste 2: STORE_IMG addr=0 pixel=0x00 (borda inferior) ---
    $display("--- Teste 2: STORE_IMG addr=0 pixel=0 ---");
    send({4'd1, 2'b00, 10'd0, 8'h00, 8'h00});
    if (img_wr_en && img_addr_w==10'd0 && img_data_w==8'h00)
        $display("OK: addr=0 pixel=0");
    else begin
        $display("FALHOU: wr_en=%b addr=%0d pixel=%0h",
                 img_wr_en, img_addr_w, img_data_w); erro=erro+1;
    end

    // --- Teste 3: STORE_BIAS addr=3 data=0x0C00 ---
    // [31:28]=3  [27:23]=00000  [22:16]=addr=3  [15:0]=0x0C00
    $display("--- Teste 3: STORE_BIAS addr=3 data=0x0C00 ---");
    send({4'd3, 5'b00000, 7'd3, 16'h0C00});
    if (b_wr_en && b_addr_w==7'd3 && b_data_w==16'h0C00)
        $display("OK: b_wr_en=1 addr=3 data=0x0C00");
    else begin
        $display("FALHOU BIAS: wr_en=%b addr=%0d data=%0h",
                 b_wr_en, b_addr_w, b_data_w); erro=erro+1;
    end

    // --- Teste 4: STORE_BIAS addr=127 (borda) → seta b_ready ---
    $display("--- Teste 4: STORE_BIAS addr=127 seta b_ready ---");
    send({4'd3, 5'b00000, 7'd127, 16'h0001});
    if (b_wr_en && b_addr_w==7'd127)
        $display("OK: addr=127 escrito (b_ready setado internamente)");
    else begin
        $display("FALHOU: b_wr_en=%b addr=%0d", b_wr_en, b_addr_w); erro=erro+1;
    end

    // --- Teste 5: START sem todos flags → ERROR ---
    $display("--- Teste 5: START sem dados prontos ---");
    send({4'd4, 28'b0});
    if (status == 2'b11)
        $display("OK: status=ERROR");
    else begin
        $display("FALHOU: status=%0b esperado=11", status); erro=erro+1;
    end

    // --- Teste 6: STORE_IMG addr=783 → seta img_ready ---
    $display("--- Teste 6: STORE_IMG addr=783 seta img_ready ---");
    send({4'd1, 2'b00, 10'd783, 8'hFF, 8'h00});
    if (img_wr_en && img_addr_w==10'd783)
        $display("OK: addr=783 escrito");
    else begin
        $display("FALHOU: addr=%0d", img_addr_w); erro=erro+1;
    end

    // --- Teste 7: infer_done externo → status=DONE pred=7 ---
    $display("--- Teste 7: infer_done => status=DONE pred=7 ---");
    infer_pred=4'd7; infer_done=1;
    @(posedge clk); #1; infer_done=0;
    @(posedge clk); #1;
    if (status==2'b10 && pred==4'd7)
        $display("OK: status=DONE pred=7");
    else begin
        $display("FALHOU: status=%0b pred=%0d", status, pred); erro=erro+1;
    end

    // --- Teste 8: instrucao invalida → ERROR ---
    $display("--- Teste 8: opcode invalido ---");
    send({4'd15, 28'hFFFFFFF});
    if (status==2'b11)
        $display("OK: opcode invalido gerou ERROR");
    else begin
        $display("FALHOU: status=%0b esperado=11", status); erro=erro+1;
    end

    $display("=== %0d erro(s) ===", erro);
    $finish;
end
endmodule
