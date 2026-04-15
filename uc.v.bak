module uc (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] instruction,
    input  wire        instr_valid,
    input  wire        infer_done,
    input  wire        infer_busy,
    input  wire [3:0]  infer_pred,

    // escrita MEM_IMG
    output reg  [9:0]  img_addr_w,
    output reg  [7:0]  img_data_w,
    output reg         img_wr_en,

    // escrita MEM_WIN
    output reg  [16:0] win_addr_w,
    output reg  [15:0] win_data_w,
    output reg         win_wr_en,

    // escrita MEM_BIAS
    output reg  [6:0]  b_addr_w,
    output reg  [15:0] b_data_w,
    output reg         b_wr_en,

    // escrita MEM_BETA
    output reg  [13:0] beta_addr_w,
    output reg  [15:0] beta_data_w,
    output reg         beta_wr_en,

    // controle FSM inferencia
    output reg         start_infer,

    // status pro mundo externo
    output reg  [1:0]  status,
    output reg  [3:0]  pred
);

// opcodes
localparam OP_STORE_IMG     = 4'd1;
localparam OP_STORE_WEIGHTS = 4'd2;
localparam OP_STORE_BIAS    = 4'd3;
localparam OP_START         = 4'd4;
localparam OP_STATUS        = 4'd5;

// status
localparam ST_IDLE  = 2'b00;
localparam ST_BUSY  = 2'b01;
localparam ST_DONE  = 2'b10;
localparam ST_ERROR = 2'b11;

// flags
reg img_ready, w_ready, b_ready, beta_ready;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        img_wr_en    <= 1'b0;
        win_wr_en    <= 1'b0;
        b_wr_en      <= 1'b0;
        beta_wr_en   <= 1'b0;
        start_infer  <= 1'b0;
        img_ready    <= 1'b0;
        w_ready      <= 1'b0;
        b_ready      <= 1'b0;
        beta_ready   <= 1'b0;
        status       <= ST_IDLE;
        pred         <= 4'd0;
        img_addr_w   <= 10'd0;
        win_addr_w   <= 17'd0;
        b_addr_w     <= 7'd0;
        beta_addr_w  <= 14'd0;
    end
    else begin
        // desliga sinais por padrao
        img_wr_en   <= 1'b0;
        win_wr_en   <= 1'b0;
        b_wr_en     <= 1'b0;
        beta_wr_en  <= 1'b0;
        start_infer <= 1'b0;

        // atualiza status quando inferencia termina
        if (infer_done) begin
            status <= ST_DONE;
            pred   <= infer_pred;
        end
        else if (instr_valid) begin
            case (instruction[31:28])
                OP_STORE_IMG: begin
                    img_data_w <= instruction[15:8];
                    img_addr_w <= instruction[25:16];
                    img_wr_en  <= 1'b1;
                    if (instruction[25:16] == 10'd783)
                        img_ready <= 1'b1;
                end

                OP_STORE_WEIGHTS: begin
                    if (instruction[27:11] <= 17'd100351) begin
                        win_data_w <= instruction[15:0];
                        win_addr_w <= instruction[27:11];
                        win_wr_en  <= 1'b1;
                        if (instruction[27:11] == 17'd100351)
                            w_ready <= 1'b1;
                    end
                    else begin
                        beta_data_w <= instruction[15:0];
                        beta_addr_w <= instruction[27:14] - 14'd1279;
                        beta_wr_en  <= 1'b1;
                        if (instruction[27:14] == 14'd1279)
                            beta_ready <= 1'b1;
                    end
                end

                OP_STORE_BIAS: begin
                    b_data_w <= instruction[15:0];
                    b_addr_w <= instruction[22:16];
                    b_wr_en  <= 1'b1;
                    if (instruction[22:16] == 7'd127)
                        b_ready <= 1'b1;
                end

                OP_START: begin
                    if (img_ready && w_ready && b_ready && beta_ready) begin
                        start_infer <= 1'b1;
                        status      <= ST_BUSY;
                    end
                    else
                        status <= ST_ERROR;
                end

                OP_STATUS: begin
                    if (infer_done)
                        status <= ST_DONE;
                    else if (infer_busy)
                        status <= ST_BUSY;
                end

                default: status <= ST_ERROR;
            endcase
        end
    end
end

endmodule