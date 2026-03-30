`timescale 1ns/1ps
// ============================================================
// Testbench: fsm_infer (versão corrigida)
// Mudanças refletidas:
//   - beta_addr_r agora é 11 bits
//   - cycles é saída — verificamos que incrementa durante exec
//   - add_bias é saída — verificamos que pulsa na transição
//     MAC_H→ACTIV
// Estratégia: stubs fixos para act_result e argmax_pred.
// ============================================================
module tb_fsm_infer;

reg        clk, reset, start;
reg [15:0] act_result;
reg [33:0] mac_acc;
reg [3:0]  argmax_pred;

wire [9:0]  img_addr_r;
wire [16:0] win_addr_r;
wire [6:0]  b_addr_r;
wire [10:0] beta_addr_r;   // 11 bits
wire [6:0]  h_addr_w, h_addr_r;
wire [15:0] h_data_w;
wire        h_wr_en;
wire [3:0]  y_addr_w, y_addr_r;
wire [15:0] y_data_w;
wire        y_wr_en;
wire        mac_enable, mac_clear, add_bias;
wire        act_enable;
wire        argmax_enable;
wire [3:0]  argmax_k;
wire [3:0]  pred;
wire        done, busy;
wire [31:0] cycles;

fsm_infer uut (
    .clk(clk), .reset(reset), .start(start),
    .act_result(act_result), .mac_acc(mac_acc),
    .argmax_pred(argmax_pred),
    .img_addr_r(img_addr_r), .win_addr_r(win_addr_r),
    .b_addr_r(b_addr_r),     .beta_addr_r(beta_addr_r),
    .h_addr_w(h_addr_w), .h_data_w(h_data_w), .h_wr_en(h_wr_en),
    .y_addr_w(y_addr_w), .y_data_w(y_data_w), .y_wr_en(y_wr_en),
    .h_addr_r(h_addr_r), .y_addr_r(y_addr_r),
    .mac_enable(mac_enable), .mac_clear(mac_clear), .add_bias(add_bias),
    .act_enable(act_enable),
    .argmax_enable(argmax_enable), .argmax_k(argmax_k),
    .pred(pred), .done(done), .busy(busy),
    .cycles(cycles)
);

always #5 clk = ~clk;

integer erro, ciclos_espera;
reg add_bias_visto;

initial begin
    clk=0; reset=1; start=0; erro=0; add_bias_visto=0;
    act_result=16'h0800; // tanh(0) stub
    mac_acc=34'd0;
    argmax_pred=4'd5;    // digito que o argmax "encontrou"

    @(posedge clk); #1; reset=0;

    // --- Teste 1: estado inicial ---
    $display("--- Teste 1: estado inicial ---");
    if (busy!==0 || done!==0 || cycles!==0) begin
        $display("FALHOU: busy=%b done=%b cycles=%0d", busy, done, cycles);
        erro=erro+1;
    end else $display("OK: READY, busy=0 done=0 cycles=0");

    // --- Teste 2: start sobe busy e zera cycles ---
    $display("--- Teste 2: start dispara inferencia ---");
    start=1; @(posedge clk); #1; start=0;
    if (busy!==1) begin
        $display("FALHOU: busy nao subiu"); erro=erro+1;
    end else $display("OK: busy=1");

    // --- Teste 3: mac_enable ativo em MAC_H ---
    $display("--- Teste 3: mac_enable em MAC_H ---");
    @(posedge clk); #1;
    if (mac_enable!==1) begin
        $display("FALHOU: mac_enable=%b", mac_enable); erro=erro+1;
    end else $display("OK: mac_enable=1");

    // --- Teste 4: cycles incrementa ---
    $display("--- Teste 4: cycles incrementa ---");
    begin : blk_cycles
        reg [31:0] c_antes;
        c_antes = cycles;
        repeat(5) @(posedge clk); #1;
        if (cycles <= c_antes) begin
            $display("FALHOU: cycles nao incrementou (%0d->%0d)", c_antes, cycles);
            erro=erro+1;
        end else $display("OK: cycles incrementando (%0d)", cycles);
    end

    // --- Teste 5: add_bias pulsa na transicao MAC_H->ACTIV ---
    // Monitoramos add_bias por até 800 ciclos (cobre os 784 pixels)
    $display("--- Teste 5: add_bias pulsa ---");
    begin : blk_bias
        integer j;
        add_bias_visto = 0;
        for (j=0; j<800; j=j+1) begin
            @(posedge clk); #1;
            if (add_bias) add_bias_visto=1;
        end
        if (!add_bias_visto) begin
            $display("FALHOU: add_bias nunca pulsou nos primeiros 800 ciclos");
            erro=erro+1;
        end else $display("OK: add_bias pulsou");
    end

    // --- Teste 6: aguarda done com timeout ---
    $display("--- Teste 6: aguarda done (timeout 250000 ciclos) ---");
    ciclos_espera=0;
    while (done!==1 && ciclos_espera<250000) begin
        @(posedge clk); #1; ciclos_espera=ciclos_espera+1;
    end

    if (done!==1) begin
        $display("FALHOU: timeout sem done (%0d ciclos)", ciclos_espera);
        erro=erro+1;
    end else begin
        $display("OK: done=1 em ~%0d ciclos totais", cycles);
        // --- Teste 7: pred captura argmax_pred ---
        if (pred!==4'd5) begin
            $display("FALHOU: pred=%0d esperado=5", pred); erro=erro+1;
        end else $display("OK: pred=5");
        // --- Teste 8: busy cai com done ---
        if (busy!==0) begin
            $display("FALHOU: busy ainda=1 junto com done"); erro=erro+1;
        end else $display("OK: busy=0 quando done=1");
        // --- Teste 9: cycles > 0 ao terminar ---
        if (cycles==0) begin
            $display("FALHOU: cycles=0 ao fim"); erro=erro+1;
        end else $display("OK: cycles=%0d ao fim", cycles);
    end

    $display("=== %0d erro(s) ===", erro);
    $finish;
end

initial begin #4000000; $display("TIMEOUT GLOBAL"); $finish; end
endmodule
