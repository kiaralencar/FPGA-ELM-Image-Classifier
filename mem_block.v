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
always @(posedge clk)
    if (img_wr_en)
        mem_img[img_addr_w] <= {8'b0, img_data_w};

reg [15:0] img_data_r_reg;
always @(posedge clk)
    img_data_r_reg <= mem_img[img_addr_r];
assign img_data_r = img_data_r_reg;

// MEM_WIN (BRAM)
reg [15:0] mem_win [0:100351];
initial $readmemh("W_in_q.hex", mem_win);

reg [15:0] win_data_r_reg;
always @(posedge clk)
    win_data_r_reg <= mem_win[win_addr_r];
assign win_data_r = win_data_r_reg;

// MEM_BIAS (BRAM)
reg [15:0] mem_bias [0:127];
initial $readmemh("b_q.hex", mem_bias);

reg [15:0] b_data_r_reg;
always @(posedge clk)
    b_data_r_reg <= mem_bias[b_addr_r];
assign b_data_r = b_data_r_reg;

// MEM_BETA (BRAM)
reg [15:0] mem_beta [0:1279];
initial $readmemh("beta_q.hex", mem_beta);

reg [15:0] beta_data_r_reg;
always @(posedge clk)
    beta_data_r_reg <= mem_beta[beta_addr_r];
assign beta_data_r = beta_data_r_reg;

// MEM_H
reg [15:0] mem_h [0:127];
always @(posedge clk)
    if (h_wr_en)
        mem_h[h_addr_w] <= h_data_w;

reg [15:0] h_data_r_reg;
always @(posedge clk)
    h_data_r_reg <= mem_h[h_addr_r];
assign h_data_r = h_data_r_reg;

// MEM_Y
reg [15:0] mem_y [0:9];
always @(posedge clk)
    if (y_wr_en)
        mem_y[y_addr_w] <= y_data_w;

reg [15:0] y_data_r_reg;
always @(posedge clk)
    y_data_r_reg <= mem_y[y_addr_r];
assign y_data_r = y_data_r_reg;

endmodule