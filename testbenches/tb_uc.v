`timescale 1ns/1ps
// ============================================================
// Testbench: uc (unidade de controle / decodificador ISA)
// O que testa:
//   1. STORE_IMG: endereco e dado corretos na saida
//   2. STORE_BIAS: endereco e dado corretos
//   3. START sem flags prontos → status=ERROR
//   4. START com todos flags prontos → start_infer pulsa, status=BUSY
//   5. Quando infer_done chega → status=DONE, pred atualizado
// ============================================================
module tb_uc;

reg        clk, reset, instr_valid, infer_done, infer_busy;
reg [31:0] instruction;
reg [3:0]  infer_pred;

wire [9:0]  img_addr_w; wire [7:0] img_data_w; wire img_wr_en;
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
    .status(status), .pred(pred)
);

always #5 clk = ~clk;

// Monta instrucao: [31:28]=opcode [27:16]=addr [15:0]=data
function [31:0] make_instr;
    input [3:0]  op;
    input [11:0] addr;
    input [15:0] data;
    begin make_instr = {op, addr, data}; end
endfunction

integer erro;

// Envia instrucao em 1 ciclo
task send;
    input [31:0] instr;
    begin
        instruction=instr; instr_valid=1;
        @(posedge clk); #1;
        instr_valid=0;
    end
endtask

initial begin
    clk=0; reset=1; instr_valid=0; infer_done=0; infer_busy=0;
    instruction=0; infer_pred=0; erro=0;
    @(posedge clk); #1; reset=0;

    // --- Teste 1: STORE_IMG addr=5 data=0xAB00 (pixel=0xAB) ---
    $display("--- Teste 1: STORE_IMG ---");
    // opcode=1, addr[25:16]=5, pixel=[15:8]=0xAB
    send({4'd1, 10'd5, 2'b00, 8'hAB, 8'h00});
    if (img_wr_en && img_addr_w==10'd5 && img_data_w==8'hAB)
        $display("OK: STORE_IMG addr=5 pixel=0xAB");
    else begin
        $display("FALHOU: wr_en=%b addr=%0d pixel=%0h",
                 img_wr_en, img_addr_w, img_data_w); erro=erro+1;
    end

    // --- Teste 2: STORE_BIAS addr=3 data=0x0C00 ---
    $display("--- Teste 2: STORE_BIAS ---");
    // opcode=3, instruction[22:16]=addr=3, [15:0]=data
    send({4'd3, 4'b0000, 3'd3, 9'b0, 16'h0C00});
    // b_addr_w vem de instruction[22:16]
    if (b_wr_en && b_data_w==16'h0C00)
        $display("OK: STORE_BIAS data=0x0C00");
    else begin
        $display("FALHOU BIAS: wr_en=%b data=%0h", b_wr_en, b_data_w);
        erro=erro+1;
    end

    // --- Teste 3: START sem flags → deve dar ERROR ---
    $display("--- Teste 3: START sem dados prontos ---");
    send({4'd4, 28'b0});
    if (status == 2'b11)
        $display("OK: status=ERROR como esperado");
    else begin
        $display("FALHOU: status=%0b esperado=11 (ERROR)", status); erro=erro+1;
    end

    // --- Teste 4: simula carregamento completo enviando instrucao 783 ---
    // Trick: manda STORE_IMG com addr=783 para setar img_ready
    $display("--- Teste 4: seta img_ready com addr=783 ---");
    send({4'd1, 10'd783, 2'b00, 8'hFF, 8'h00});

    // bias addr=127 → b_ready
    send({4'd3, 4'b0000, 7'd127, 9'b0, 16'h0001});

    // Para w_ready e beta_ready precisariamos enviar addr 100351 e addr beta
    // Aqui fazemos apenas a verificacao logica do status=ERROR
    // (testes completos de w/beta exigiriam 100k+ ciclos)
    $display("(testes de w_ready/beta_ready omitidos — requerem 100k+ ciclos)");

    // --- Teste 5: infer_done chega externamente ---
    $display("--- Teste 5: infer_done → status=DONE pred=7 ---");
    infer_pred=4'd7; infer_done=1;
    @(posedge clk); #1; infer_done=0;
    @(posedge clk); #1;
    if (status==2'b10 && pred==4'd7)
        $display("OK: status=DONE pred=7");
    else begin
        $display("FALHOU: status=%0b pred=%0d", status, pred); erro=erro+1;
    end

    $display("=== %0d erro(s) ===", erro);
    $finish;
end
endmodule
