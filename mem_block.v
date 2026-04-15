// =============================================================================
// mem_block.v — Bloco de memorias do acelerador ELM
//
// Memorias:
//   ram_img  — 784  x 16b — pixels da imagem
//   ram_win  — 100352 x 16b — pesos W_in (Q4.12), inicializado com W_in_q.mif
//   ram_bias — 128  x 16b — bias (Q4.12), inicializado com b_q.mif
//   ram_beta — 1280 x 16b — pesos beta (Q4.12), inicializado com beta_q.mif
//   ram_h    — 128  x 16b — saidas camada oculta (escrita pela FSM)
//   mem_y    — registradores simples (argmax embutido na FSM)
//
// Todas as RAMs sao RAM 1-PORT (M10K, sem q output port)
// Escrita e leitura nunca ocorrem no mesmo ciclo por design
// =============================================================================

module mem_block (
    input  wire        clk,

    // --- MEM_IMG ---
    input  wire [9:0]  img_addr_w,
    input  wire [7:0]  img_data_w,
    input  wire        img_wr_en,
    input  wire [9:0]  img_addr_r,
    output wire [15:0] img_data_r,

    // --- MEM_WIN ---
    input  wire [16:0] win_addr_w,
    input  wire [15:0] win_data_w,
    input  wire        win_wr_en,
    input  wire [16:0] win_addr_r,
    output wire [15:0] win_data_r,

    // --- MEM_BIAS ---
    input  wire [6:0]  b_addr_w,
    input  wire [15:0] b_data_w,
    input  wire        b_wr_en,
    input  wire [6:0]  b_addr_r,
    output wire [15:0] b_data_r,

    // --- MEM_BETA ---
    input  wire [10:0] beta_addr_w,
    input  wire [15:0] beta_data_w,
    input  wire        beta_wr_en,
    input  wire [10:0] beta_addr_r,
    output wire [15:0] beta_data_r,

    // --- MEM_H ---
    input  wire [6:0]  h_addr_w,
    input  wire [15:0] h_data_w,
    input  wire        h_wr_en,
    input  wire [6:0]  h_addr_r,
    output wire [15:0] h_data_r,

    // --- MEM_Y (registradores, mantido para compatibilidade) ---
    input  wire [3:0]  y_addr_w,
    input  wire [15:0] y_data_w,
    input  wire        y_wr_en,
    input  wire [3:0]  y_addr_r,
    output wire [15:0] y_data_r
);

// MUX de endereco: prioridade para escrita
wire [9:0]  img_addr  = img_wr_en  ? img_addr_w  : img_addr_r;
wire [16:0] win_addr  = win_wr_en  ? win_addr_w  : win_addr_r;
wire [6:0]  b_addr    = b_wr_en    ? b_addr_w    : b_addr_r;
wire [10:0] beta_addr = beta_wr_en ? beta_addr_w : beta_addr_r;
wire [6:0]  h_addr    = h_wr_en    ? h_addr_w    : h_addr_r;

wire [15:0] img_data_in = {8'b0, img_data_w};

// ----------------------------------------------------------
// MEM_IMG — 784 x 16b
// ----------------------------------------------------------
ram_img u_img (
    .clock   (clk),
    .address (img_addr),
    .data    (img_data_in),
    .wren    (img_wr_en),
    .q       (img_data_r)
);

// ----------------------------------------------------------
// MEM_WIN — 100352 x 16b (pesos W_in, inicializado com W_in_q.mif)
// ----------------------------------------------------------
ram_win u_win (
    .clock   (clk),
    .address (win_addr),
    .data    (win_data_w),
    .wren    (win_wr_en),
    .q       (win_data_r)
);

// ----------------------------------------------------------
// MEM_BIAS — 128 x 16b (bias, inicializado com b_q.mif)
// ----------------------------------------------------------
ram_bias u_bias (
    .clock   (clk),
    .address (b_addr),
    .data    (b_data_w),
    .wren    (b_wr_en),
    .q       (b_data_r)
);

// ----------------------------------------------------------
// MEM_BETA — 1280 x 16b (pesos beta, inicializado com beta_q.mif)
// ----------------------------------------------------------
ram_beta u_beta (
    .clock   (clk),
    .address (beta_addr),
    .data    (beta_data_w),
    .wren    (beta_wr_en),
    .q       (beta_data_r)
);

// ----------------------------------------------------------
// MEM_H — 128 x 16b (saidas camada oculta)
// ----------------------------------------------------------
ram_h u_h (
    .clock   (clk),
    .address (h_addr),
    .data    (h_data_w),
    .wren    (h_wr_en),
    .q       (h_data_r)
);

// ----------------------------------------------------------
// MEM_Y — registradores simples (argmax embutido na FSM)
// ----------------------------------------------------------
reg [15:0] mem_y [0:9];
always @(posedge clk)
    if (y_wr_en)
        mem_y[y_addr_w] <= y_data_w;
assign y_data_r = mem_y[y_addr_r];

endmodule