module mem_block (
    input  wire        clk,
    
    // interface imagem
    input  wire [9:0]  img_addr_w,
    input  wire [7:0]  img_data_w,
    input  wire        img_wr_en,
    input  wire [9:0]  img_addr_r,
    output wire [15:0] img_data_r,

    // interface W_in
    input  wire [16:0] win_addr_r,
    output wire [15:0] win_data_r,

    // interface bias
    input  wire [6:0]  b_addr_r,
    output wire [15:0] b_data_r,

    // interface beta
    input  wire [13:0] beta_addr_r,
    output wire [15:0] beta_data_r,

    // interface MEM_H
    input  wire [6:0]  h_addr_w,
    input  wire [15:0] h_data_w,
    input  wire        h_wr_en,
    input  wire [6:0]  h_addr_r,
    output wire [15:0] h_data_r,

    // interface MEM_Y
    input  wire [3:0]  y_addr_w,
    input  wire [15:0] y_data_w,
    input  wire        y_wr_en,
    input  wire [3:0]  y_addr_r,
    output wire [15:0] y_data_r
);

// MEM_IMG
reg [15:0] mem_img [0:783];
always @(posedge clk) // a escrita só acontece sincronizada com o clock
    if (img_wr_en)
        mem_img[img_addr_w] <= {8'b0, img_data_w}; // concatenação:
assign img_data_r = mem_img[img_addr_r];

// MEM_WIN (inicializada com .mif)
reg [15:0] mem_win [0:100351]; // declara a memória, cada posição tem 16 bits (Q4.12) e temos 100.352 posições
initial $readmemh("W_in_q.hex", mem_win); // carrega o arquivo .hex na memória no momento que o chip "liga"
assign win_data_r = mem_win[win_addr_r]; // quando a FSM pede um endereço, o dado aparece na saída imediatamente

// MEM_BIAS (inicializada com .mif)
reg [15:0] mem_bias [0:127];
initial $readmemh("b_q.hex", mem_bias);
assign b_data_r = mem_bias[b_addr_r];

// MEM_BETA (inicializada com .mif)
reg [15:0] mem_beta [0:1279];
initial $readmemh("beta_q.hex", mem_beta);
assign beta_data_r = mem_beta[beta_addr_r];

// MEM_H
reg [15:0] mem_h [0:127];
always @(posedge clk)
    if (h_wr_en)
        mem_h[h_addr_w] <= h_data_w;
assign h_data_r = mem_h[h_addr_r];

// MEM_Y
reg [15:0] mem_y [0:9];
always @(posedge clk)
    if (y_wr_en)
        mem_y[y_addr_w] <= y_data_w;
assign y_data_r = mem_y[y_addr_r];

endmodule