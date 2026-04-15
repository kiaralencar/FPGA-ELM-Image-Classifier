// =============================================================================
// elm_accel.v — IP do acelerador ELM
//
// Hierarquia:
//   elm_accel
//     ├── uc         (decodifica ISA, gerencia flags, dispara inferencia)
//     ├── fsm_infer  (FSM de inferencia com argmax embutido)
//     ├── mem_block  (BRAMs: img, win, bias, beta, h)
//     ├── mac        (multiplicador-acumulador)
//     └── activation (tanh aproximada por segmentos lineares)
// =============================================================================

module elm_accel (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] instruction,
    input  wire        instr_valid,
	 input  wire [31:0] mem_write_instr,
    input  wire        mem_write_valid,  
    output wire [1:0]  status,
    output wire [3:0]  pred,
    output wire        img_ready,
    output wire        w_ready,
    output wire        b_ready,
    output wire [31:0] cycles
);

// ============================================================
// Fios UC -> mem_block (escrita)
// ============================================================
wire [9:0]  img_addr_w;
wire [7:0]  img_data_w;
wire        img_wr_en;
wire [16:0] win_addr_w;
wire [15:0] win_data_w;
wire        win_wr_en;
wire [6:0]  b_addr_w;
wire [15:0] b_data_w;
wire        b_wr_en;
wire [10:0] beta_addr_w;
wire [15:0] beta_data_w;
wire        beta_wr_en;

// ============================================================
// Fios UC -> FSM
// ============================================================
wire        start_infer;
wire        infer_done;
wire        infer_busy;
wire [3:0]  infer_pred;

// ============================================================
// Fios FSM -> mem_block (leitura)
// ============================================================
wire [9:0]  img_addr_r;
wire [16:0] win_addr_r;
wire [6:0]  b_addr_r;
wire [10:0] beta_addr_r;
wire [6:0]  h_addr_r;
wire [3:0]  y_addr_r;

// ============================================================
// Fios mem_block -> MAC/FSM
// ============================================================
wire [15:0] img_data_r;
wire signed [15:0] win_data_r;
wire signed [15:0] b_data_r;
wire signed [15:0] beta_data_r;
wire signed [15:0] h_data_r;
wire [15:0] y_data_r;

// ============================================================
// Fios FSM -> mem_block (escrita MEM_H e MEM_Y)
// ============================================================
wire [6:0]  h_addr_w;
wire [15:0] h_data_w;
wire        h_wr_en;
wire [3:0]  y_addr_w;
wire [15:0] y_data_w;
wire        y_wr_en;

// ============================================================
// Fios FSM -> MAC
// ============================================================
wire        mac_enable;
wire        mac_clear;
wire        mac_add_bias;
wire        mac_use_h;
wire signed [33:0] mac_acc;

// ============================================================
// Fios FSM -> activation
// ============================================================
wire        act_enable;
wire signed [15:0] act_result;

// sinais argmax externo (nao usados — argmax embutido na FSM)
wire        argmax_enable;
wire [3:0]  argmax_k;

// ============================================================
// Instancias
// ============================================================

uc u_uc (
    .clk         (clk),
    .reset       (reset),
    .instruction (instruction),
    .instr_valid (instr_valid),
	 .mem_write_instr  (mem_write_instr),
    .mem_write_valid  (mem_write_valid),
    .infer_done  (infer_done),
    .infer_busy  (infer_busy),
    .infer_pred  (infer_pred),
    .img_addr_w  (img_addr_w),
    .img_data_w  (img_data_w),
    .img_wr_en   (img_wr_en),
    .win_addr_w  (win_addr_w),
    .win_data_w  (win_data_w),
    .win_wr_en   (win_wr_en),
    .b_addr_w    (b_addr_w),
    .b_data_w    (b_data_w),
    .b_wr_en     (b_wr_en),
    .beta_addr_w (beta_addr_w),
    .beta_data_w (beta_data_w),
    .beta_wr_en  (beta_wr_en),
    .img_ready   (img_ready),
    .w_ready     (w_ready),
    .b_ready     (b_ready),
    .start_infer (start_infer),
    .status      (status),
    .pred        (pred)
);

fsm_infer u_fsm (
    .clk          (clk),
    .reset        (reset),
    .start        (start_infer),
    .act_result   (act_result),
    .mac_acc      (mac_acc),
    .img_addr_r   (img_addr_r),
    .win_addr_r   (win_addr_r),
    .b_addr_r     (b_addr_r),
    .beta_addr_r  (beta_addr_r),
    .h_addr_w     (h_addr_w),
    .h_data_w     (h_data_w),
    .h_wr_en      (h_wr_en),
    .y_addr_w     (y_addr_w),
    .y_data_w     (y_data_w),
    .y_wr_en      (y_wr_en),
    .h_addr_r     (h_addr_r),
    .y_addr_r     (y_addr_r),
    .mac_enable   (mac_enable),
    .mac_clear    (mac_clear),
    .add_bias     (mac_add_bias),
    .use_h        (mac_use_h),
    .act_enable   (act_enable),
    .argmax_enable(argmax_enable),
    .argmax_k     (argmax_k),
    .pred         (infer_pred),
    .done         (infer_done),
    .busy         (infer_busy),
    .cycles       (cycles)
);

mem_block u_mem (
    .clk         (clk),
    .img_addr_w  (img_addr_w),
    .img_data_w  (img_data_w),
    .img_wr_en   (img_wr_en),
    .img_addr_r  (img_addr_r),
    .img_data_r  (img_data_r),
    .win_addr_w  (win_addr_w),
    .win_data_w  (win_data_w),
    .win_wr_en   (win_wr_en),
    .win_addr_r  (win_addr_r),
    .win_data_r  (win_data_r),
    .b_addr_w    (b_addr_w),
    .b_data_w    (b_data_w),
    .b_wr_en     (b_wr_en),
    .b_addr_r    (b_addr_r),
    .b_data_r    (b_data_r),
    .beta_addr_w (beta_addr_w),
    .beta_data_w (beta_data_w),
    .beta_wr_en  (beta_wr_en),
    .beta_addr_r (beta_addr_r),
    .beta_data_r (beta_data_r),
    .h_addr_w    (h_addr_w),
    .h_data_w    (h_data_w),
    .h_wr_en     (h_wr_en),
    .h_addr_r    (h_addr_r),
    .h_data_r    (h_data_r),
    .y_addr_w    (y_addr_w),
    .y_data_w    (y_data_w),
    .y_wr_en     (y_wr_en),
    .y_addr_r    (y_addr_r),
    .y_data_r    (y_data_r)
);

mac u_mac (
    .clk       (clk),
    .reset     (reset),
    .enable    (mac_enable),
    .clear_acc (mac_clear),
    .add_bias  (mac_add_bias),
    .use_h     (mac_use_h),
    .pixel     (img_data_r[7:0]),
    .peso      (win_data_r),
    .h_in      (h_data_r),
    .beta      (beta_data_r),
    .bias      (b_data_r),
    .acumulador(mac_acc)
);

activation u_act (
    .clk    (clk),
    .reset  (reset),
    .enable (act_enable),
    .acc_in (mac_acc[27:12]),
    .result (act_result)
);

endmodule