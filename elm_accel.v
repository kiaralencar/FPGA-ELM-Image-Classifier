module elm_accel (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] instruction,
    input  wire        instr_valid,
    output wire [1:0]  status,
    output wire [3:0]  pred
);

// fios entre uc e mem_block
wire [9:0]  img_addr_w;
wire [7:0]  img_data_w;
wire        img_wr_en;
wire [16:0] win_addr_w;
wire [15:0] win_data_w;
wire        win_wr_en;
wire [6:0]  b_addr_w;
wire [15:0] b_data_w;
wire        b_wr_en;
wire [13:0] beta_addr_w;
wire [15:0] beta_data_w;
wire        beta_wr_en;

// fios entre fsm_infer e mem_block
wire [9:0]  img_addr_r;
wire [15:0] img_data_r;
wire [16:0] win_addr_r;
wire [15:0] win_data_r;
wire [6:0]  b_addr_r;
wire [15:0] b_data_r;
wire [10:0] beta_addr_r;
wire [15:0] beta_data_r;
wire [6:0]  h_addr_w;
wire [15:0] h_data_w;
wire        h_wr_en;
wire [6:0]  h_addr_r;
wire [15:0] h_data_r;
wire [3:0]  y_addr_w;
wire [15:0] y_data_w;
wire        y_wr_en;
wire [3:0]  y_addr_r;
wire [15:0] y_data_r;

// fios entre fsm_infer e mac
wire        mac_enable;
wire        mac_clear;
wire [33:0] mac_acc;
wire mac_add_bias;

// fios entre fsm_infer e activation
wire        act_enable;
wire [15:0] act_result;

// fios entre fsm_infer e argmax
wire        argmax_enable;
wire [3:0]  argmax_k;
wire [3:0]  argmax_pred;
wire        argmax_done;

// fios entre uc e fsm_infer
wire        start_infer;
wire        infer_done;
wire        infer_busy;
wire [3:0]  infer_pred;

// instancia UC
uc u_uc (
    .clk         (clk),
    .reset       (reset),
    .instruction (instruction),
    .instr_valid (instr_valid),
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
    .start_infer (start_infer),
    .status      (status)
);

// instancia FSM inferencia
fsm_infer u_fsm (
    .clk          (clk),
    .reset        (reset),
    .start        (start_infer),
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
    .act_enable   (act_enable),
    .argmax_enable(argmax_enable),
    .argmax_k     (argmax_k),
    .pred         (infer_pred),
    .done         (infer_done),
    .busy         (infer_busy),
	 .act_result  (act_result),
	 .mac_acc     (mac_acc),
	 .add_bias (mac_add_bias),
	 .argmax_pred (argmax_pred)
);

// instancia mem_block
mem_block u_mem (
    .clk          (clk),
    .img_addr_w   (img_addr_w),
    .img_data_w   (img_data_w),
    .img_wr_en    (img_wr_en),
    .img_addr_r   (img_addr_r),
    .img_data_r   (img_data_r),
    .win_addr_r   (win_addr_r),
    .win_data_r   (win_data_r),
    .b_addr_r     (b_addr_r),
    .b_data_r     (b_data_r),
    .beta_addr_r  (beta_addr_r),
    .beta_data_r  (beta_data_r),
    .h_addr_w     (h_addr_w),
    .h_data_w     (h_data_w),
    .h_wr_en      (h_wr_en),
    .h_addr_r     (h_addr_r),
    .h_data_r     (h_data_r),
    .y_addr_w     (y_addr_w),
    .y_data_w     (y_data_w),
    .y_wr_en      (y_wr_en),
    .y_addr_r     (y_addr_r),
    .y_data_r     (y_data_r)
);

// instancia MAC
mac u_mac (
    .clk       (clk),
    .reset     (reset),
    .enable    (mac_enable),
    .clear_acc (mac_clear),
    .pixel     (img_data_r[7:0]),
    .peso      (win_data_r),
    .acumulador(mac_acc),
	 .add_bias  (mac_add_bias),
	 .bias      (b_data_r)
);

// instancia activation
activation u_act (
    .clk    (clk),
    .acc_in (mac_acc),
    .result (act_result)
);

// instancia argmax
argmax u_argmax (
    .clk    (clk),
    .reset  (reset),
    .enable (argmax_enable),
    .y_in   (y_data_r),
    .k      (argmax_k),
    .pred   (argmax_pred),
    .done   (argmax_done)
);

// conecta pred direto da fsm_infer
assign pred = infer_pred;

endmodule