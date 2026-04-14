module uc (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] instruction,
    input  wire        instr_valid,
    input  wire [31:0] mem_write_instr,
    input  wire        mem_write_valid,
    input  wire        infer_done,
    input  wire        infer_busy,
    input  wire [3:0]  infer_pred,

    output wire [9:0]  img_addr_w,
    output wire [7:0]  img_data_w,
    output wire        img_wr_en,

    output wire [16:0] win_addr_w,
    output wire [15:0] win_data_w,
    output wire        win_wr_en,

    output wire [6:0]  b_addr_w,
    output wire [15:0] b_data_w,
    output wire        b_wr_en,

    output wire [10:0] beta_addr_w,
    output wire [15:0] beta_data_w,
    output wire        beta_wr_en,

    output reg         img_ready,
    output reg         w_ready,
    output reg         b_ready,

    output reg         start_infer,
    output reg  [1:0]  status,
    output reg  [3:0]  pred
);

// opcodes fluxo normal
localparam OP_STORE_IMG     = 4'd1;
localparam OP_STORE_WEIGHTS = 4'd2;
localparam OP_STORE_BIAS    = 4'd3;
localparam OP_START         = 4'd4;
localparam OP_STATUS        = 4'd5;

// opcodes escrita manual (KEY[3])
localparam OP_MEM_IMG  = 4'd1;
localparam OP_MEM_WIN  = 4'd2;
localparam OP_MEM_BIAS = 4'd3;
localparam OP_MEM_BETA = 4'd6;

// status
localparam ST_READY = 2'b00;
localparam ST_BUSY  = 2'b01;
localparam ST_DONE  = 2'b10;
localparam ST_ERROR = 2'b11;

// ============================================================
// Registradores internos — fluxo normal (prefixo uc_)
// ============================================================
reg [9:0]  uc_img_addr_w;
reg [7:0]  uc_img_data_w;
reg        uc_img_wr_en;

reg [16:0] uc_win_addr_w;
reg [15:0] uc_win_data_w;
reg        uc_win_wr_en;

reg [6:0]  uc_b_addr_w;
reg [15:0] uc_b_data_w;
reg        uc_b_wr_en;

reg [10:0] uc_beta_addr_w;
reg [15:0] uc_beta_data_w;
reg        uc_beta_wr_en;

// ============================================================
// Registradores internos — escrita manual (prefixo mw_)
// ============================================================
reg [9:0]  mw_img_addr;
reg [7:0]  mw_img_data;
reg        mw_img_wr_en;

reg [16:0] mw_win_addr;
reg [15:0] mw_win_data;
reg        mw_win_wr_en;

reg [6:0]  mw_b_addr;
reg [15:0] mw_b_data;
reg        mw_b_wr_en;

reg [10:0] mw_beta_addr;
reg [15:0] mw_beta_data;
reg        mw_beta_wr_en;

// ============================================================
// MUX de saida: escrita manual tem prioridade se ativa
// ============================================================
assign img_wr_en   = uc_img_wr_en  | mw_img_wr_en;
assign img_addr_w  = mw_img_wr_en  ? mw_img_addr  : uc_img_addr_w;
assign img_data_w  = mw_img_wr_en  ? mw_img_data  : uc_img_data_w;

assign win_wr_en   = uc_win_wr_en  | mw_win_wr_en;
assign win_addr_w  = mw_win_wr_en  ? mw_win_addr  : uc_win_addr_w;
assign win_data_w  = mw_win_wr_en  ? mw_win_data  : uc_win_data_w;

assign b_wr_en     = uc_b_wr_en    | mw_b_wr_en;
assign b_addr_w    = mw_b_wr_en    ? mw_b_addr    : uc_b_addr_w;
assign b_data_w    = mw_b_wr_en    ? mw_b_data    : uc_b_data_w;

assign beta_wr_en  = uc_beta_wr_en  | mw_beta_wr_en;
assign beta_addr_w = mw_beta_wr_en  ? mw_beta_addr  : uc_beta_addr_w;
assign beta_data_w = mw_beta_wr_en  ? mw_beta_data  : uc_beta_data_w;

// ============================================================
// Fluxo normal — KEY[1] + opcode
// ============================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        uc_img_wr_en   <= 1'b0;
        uc_win_wr_en   <= 1'b0;
        uc_b_wr_en     <= 1'b0;
        uc_beta_wr_en  <= 1'b0;
        start_infer    <= 1'b0;
        img_ready      <= 1'b0;
        w_ready        <= 1'b0;
        b_ready        <= 1'b0;
        status         <= ST_READY;
        pred           <= 4'd0;
        uc_img_addr_w  <= 10'd0;
        uc_img_data_w  <= 8'd0;
        uc_win_addr_w  <= 17'd0;
        uc_win_data_w  <= 16'd0;
        uc_b_addr_w    <= 7'd0;
        uc_b_data_w    <= 16'd0;
        uc_beta_addr_w <= 11'd0;
        uc_beta_data_w <= 16'd0;
    end
    else begin
        uc_img_wr_en  <= 1'b0;
        uc_win_wr_en  <= 1'b0;
        uc_b_wr_en    <= 1'b0;
        uc_beta_wr_en <= 1'b0;
        start_infer   <= 1'b0;

        if (infer_done) begin
            status <= ST_DONE;
            pred   <= infer_pred;
        end

        if (instr_valid) begin
            case (instruction[31:28])

                OP_STORE_IMG: begin
                    uc_img_addr_w <= instruction[25:16];
                    uc_img_data_w <= instruction[15:8];
                    uc_img_wr_en  <= 1'b1;
                    img_ready     <= 1'b1;
                end

                OP_STORE_WEIGHTS: begin
                    uc_win_addr_w <= {5'b0, instruction[27:16]};
                    uc_win_data_w <= instruction[15:0];
                    uc_win_wr_en  <= 1'b1;
                    w_ready       <= 1'b1;
                end

                OP_STORE_BIAS: begin
                    uc_b_addr_w  <= instruction[22:16];
                    uc_b_data_w  <= instruction[15:0];
                    uc_b_wr_en   <= 1'b1;
                    b_ready      <= 1'b1;
                end

                OP_START: begin
                    if (img_ready && w_ready && b_ready) begin
                        start_infer <= 1'b1;
                        status      <= ST_BUSY;
                    end
                    else
                        status <= ST_ERROR;
                end

                OP_STATUS: begin
                    // so consulta — status ja mantido internamente
                end

                default: status <= ST_ERROR;
            endcase
        end
    end
end

// ============================================================
// Escrita manual — KEY[3], isolada, bloqueada durante inferencia
// ============================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        mw_img_wr_en  <= 1'b0;
        mw_win_wr_en  <= 1'b0;
        mw_b_wr_en    <= 1'b0;
        mw_beta_wr_en <= 1'b0;
        mw_img_addr   <= 10'd0;
        mw_img_data   <= 8'd0;
        mw_win_addr   <= 17'd0;
        mw_win_data   <= 16'd0;
        mw_b_addr     <= 7'd0;
        mw_b_data     <= 16'd0;
        mw_beta_addr  <= 11'd0;
        mw_beta_data  <= 16'd0;
    end
    else begin
        mw_img_wr_en  <= 1'b0;
        mw_win_wr_en  <= 1'b0;
        mw_b_wr_en    <= 1'b0;
        mw_beta_wr_en <= 1'b0;

        if (mem_write_valid && !infer_busy) begin
            case (mem_write_instr[31:28])

                OP_MEM_IMG: begin
                    mw_img_addr  <= mem_write_instr[25:16];
                    mw_img_data  <= mem_write_instr[7:0];
                    mw_img_wr_en <= 1'b1;
                end

                OP_MEM_WIN: begin
                    mw_win_addr  <= {5'b0, mem_write_instr[27:16]};
                    mw_win_data  <= mem_write_instr[15:0];
                    mw_win_wr_en <= 1'b1;
                end

                OP_MEM_BIAS: begin
                    mw_b_addr  <= mem_write_instr[22:16];
                    mw_b_data  <= mem_write_instr[15:0];
                    mw_b_wr_en <= 1'b1;
                end

                OP_MEM_BETA: begin
                    mw_beta_addr  <= mem_write_instr[26:16];
                    mw_beta_data  <= mem_write_instr[15:0];
                    mw_beta_wr_en <= 1'b1;
                end

                default: ;
            endcase
        end
    end
end

endmodule