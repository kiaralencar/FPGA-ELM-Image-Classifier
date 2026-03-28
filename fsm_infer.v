module fsm_infer (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
	 input  wire [15:0] act_result,   // resultado do sigmoid
	 input  wire [33:0] mac_acc,      // acumulador do MAC
    input wire [3:0] argmax_pred,
	 
    // saidas para mem_block
    output reg  [9:0]  img_addr_r,
    output reg  [16:0] win_addr_r,
    output reg  [6:0]  b_addr_r,
    output reg  [13:0] beta_addr_r,
    output reg  [6:0]  h_addr_w,
    output reg  [15:0] h_data_w,
    output reg         h_wr_en,
    output reg  [3:0]  y_addr_w,
    output reg  [15:0] y_data_w,
    output reg         y_wr_en,
    output reg  [6:0]  h_addr_r,
    output reg  [3:0]  y_addr_r,

    // saidas para mac
    output reg mac_enable,
    output reg mac_clear,
	 output reg add_bias,

    // saidas para activation
    output reg act_enable,

    // saidas para argmax
    output reg         argmax_enable,
    output reg  [3:0]  argmax_k,

    // resultado final
    output reg  [3:0]  pred,
    output reg         done,
    output reg         busy
);

// estados
localparam READY  = 3'd0;
localparam MAC_H  = 3'd1;
localparam ACTIV  = 3'd2;
localparam SAVE_H = 3'd3;
localparam MAC_Y  = 3'd4;
localparam SAVE_Y = 3'd5;
localparam DO_ARG = 3'd6;
localparam DONE   = 3'd7;

reg [2:0] state;

// contadores
reg [9:0]  i;   // 0...783 pixels
reg [6:0]  n;   // 0...127 neurônios
reg [3:0]  k;   // 0...9 dígitos

// logica de transicao de estados
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state        <= READY;
        i            <= 10'd0;
        n            <= 7'd0;
        k            <= 4'd0;
        mac_enable   <= 1'b0;
        mac_clear    <= 1'b0;
        act_enable   <= 1'b0;
        argmax_enable <= 1'b0;
        argmax_k     <= 4'd0;
        h_wr_en      <= 1'b0;
        y_wr_en      <= 1'b0;
        done         <= 1'b0;
        busy         <= 1'b0;
    end
    else begin
        case (state)
            READY: begin
                done  <= 1'b0;
                busy  <= 1'b0;
                if (start) begin
                    state <= MAC_H;
                    busy  <= 1'b1;
                    i     <= 10'd0;
                    n     <= 7'd0;
                    k     <= 4'd0;
                    mac_clear <= 1'b1;
                end
            end

            MAC_H: begin
                mac_clear      <= 1'b0;
                mac_enable     <= 1'b1;
                img_addr_r     <= i[9:0];
                win_addr_r <= ({7'b0, n} * 17'd784) + {7'b0, i};
                b_addr_r       <= n;
                if (i == 10'd783) begin
                    i          <= 10'd0;
                    mac_enable <= 1'b0;
						  add_bias   <= 1'b1;  // soma o bias no ultimo ciclo
                    state      <= ACTIV;
                end
                else
                    i <= i + 10'd1;
            end

            ACTIV: begin
					 add_bias   <= 1'b0;  // desliga add_bias
                act_enable <= 1'b1;
                state      <= SAVE_H;
            end

            SAVE_H: begin
                act_enable <= 1'b0;
                h_wr_en    <= 1'b1;
                h_addr_w   <= n;
					 h_data_w   <= act_result; 
                if (n == 7'd127) begin
                    n       <= 7'd0;
                    h_wr_en <= 1'b0;
                    state   <= MAC_Y;
                    mac_clear <= 1'b1;
                end
                else begin
                    n <= n + 7'd1;
                    state <= MAC_H;
                    mac_clear <= 1'b1;
                end
            end

            MAC_Y: begin
                mac_clear    <= 1'b0;
                mac_enable   <= 1'b1;
                h_addr_r     <= n;
                beta_addr_r <= {4'b0, k} * 14'd128 + {7'b0, n};
                if (n == 7'd127) begin
                    n          <= 7'd0;
                    mac_enable <= 1'b0;
                    state      <= SAVE_Y;
                end
                else
                    n <= n + 7'd1;
            end

            SAVE_Y: begin
                y_wr_en  <= 1'b1;
                y_addr_w <= k;
					 y_data_w <= mac_acc[27:12];
                if (k == 4'd9) begin
                    k       <= 4'd0;
                    y_wr_en <= 1'b0;
                    state   <= DO_ARG;
                end
                else begin
                    k <= k + 4'd1;
                    state <= MAC_Y;
                    mac_clear <= 1'b1;
                end
            end

            DO_ARG: begin
                argmax_enable <= 1'b1;
                argmax_k      <= k;
                y_addr_r      <= k;
                if (k == 4'd9) begin
                    argmax_enable <= 1'b0;
                    state         <= DONE;
                end
                else
                    k <= k + 4'd1;
            end

            DONE: begin
                done <= 1'b1;
                busy <= 1'b0;
					 pred <= argmax_pred;
                state <= READY;
            end

        endcase
    end
end

endmodule