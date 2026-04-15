module fsm_infer (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire signed [15:0] act_result,
    input  wire signed [33:0] mac_acc,

    // saidas para mem_block
    output reg  [9:0]  img_addr_r,
    output reg  [16:0] win_addr_r,
    output reg  [6:0]  b_addr_r,
    output reg  [10:0] beta_addr_r,
    output reg  [6:0]  h_addr_w,
    output reg  [15:0] h_data_w,
    output reg         h_wr_en,
    // MEM_Y nao e mais usada — mantidas para nao quebrar mem_block
    output reg  [3:0]  y_addr_w,
    output reg  [15:0] y_data_w,
    output reg         y_wr_en,
    output reg  [6:0]  h_addr_r,
    output reg  [3:0]  y_addr_r,

    // saidas para mac
    output reg mac_enable,
    output reg mac_clear,
    output reg add_bias,
    output reg use_h,

    // saidas para activation
    output reg act_enable,

    // saidas para argmax (nao usadas — argmax embutido)
    output reg        argmax_enable,
    output reg [3:0]  argmax_k,

    // resultado final
    output reg [3:0]  pred,
    output reg        done,
    output reg        busy,
    output reg [31:0] cycles
);

// ============================================================
// Estados
// ============================================================
localparam READY      = 4'd0;
localparam MAC_H      = 4'd1;
localparam MAC_H_W    = 4'd2;
localparam MAC_H_LAST = 4'd3;
localparam ACTIV      = 4'd4;
localparam SAVE_H     = 4'd5;
localparam MAC_Y      = 4'd6;
localparam MAC_Y_W    = 4'd7;
localparam MAC_Y_LAST = 4'd8;
localparam SAVE_Y     = 4'd9;
localparam DO_ARGMAX  = 4'd10;
localparam DONE       = 4'd11;
localparam WAIT = 4'd12;

reg [3:0] state;
reg [27:0] wait_cnt;
reg [9:0] i;
reg [6:0] n;
reg [3:0] k;

reg mac_enable_d;

// ============================================================
// 10 registradores para y[0]..y[9] — sem BRAM
// Produto h*beta reescalado: Q4.12 * Q4.12 >> 12 = Q4.12
// Usamos 32 bits para nao perder precisao nas somas
// ============================================================
reg signed [33:0] y_reg [0:9];

// ============================================================
// Argmax combinacional sobre y_reg
// ============================================================
reg [3:0]  argmax_result;
reg signed [33:0] argmax_max;
integer j;
always @(*) begin
    argmax_result = 4'd0;
    argmax_max    = y_reg[0];
    for (j = 1; j < 10; j = j + 1) begin
        if (y_reg[j] > argmax_max) begin
            argmax_max    = y_reg[j];
            argmax_result = j[3:0];
        end
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state         <= READY;
        i             <= 10'd0;
        n             <= 7'd0;
        k             <= 4'd0;
        mac_enable    <= 1'b0;
        mac_enable_d  <= 1'b0;
        mac_clear     <= 1'b0;
        add_bias      <= 1'b0;
        use_h         <= 1'b0;
        act_enable    <= 1'b0;
        argmax_enable <= 1'b0;
        argmax_k      <= 4'd0;
        h_wr_en       <= 1'b0;
        y_wr_en       <= 1'b0;
        y_addr_w      <= 4'd0;
        y_data_w      <= 16'd0;
        y_addr_r      <= 4'd0;
        done          <= 1'b0;
        busy          <= 1'b0;
        cycles        <= 32'd0;
        img_addr_r    <= 10'd0;
        win_addr_r    <= 17'd0;
        h_addr_r      <= 7'd0;
        beta_addr_r   <= 11'd0;
        b_addr_r      <= 7'd0;
        pred          <= 4'd0;
		  wait_cnt <= 28'd0;
        begin : reset_y
            integer idx;
            for (idx = 0; idx < 10; idx = idx + 1)
                y_reg[idx] <= 34'sd0;
        end
    end
    else begin
        mac_enable <= mac_enable_d;

        case (state)

            READY: begin
                done         <= 1'b0;
                busy         <= 1'b0;
                mac_enable_d <= 1'b0;
                use_h        <= 1'b0;
                if (start) begin
                    cycles    <= 32'd0;
                    state     <= MAC_H;
                    busy      <= 1'b1;
                    i         <= 10'd0;
                    n         <= 7'd0;
                    k         <= 4'd0;
                    mac_clear <= 1'b1;
                    begin : clear_y
                        integer idx;
                        for (idx = 0; idx < 10; idx = idx + 1)
                            y_reg[idx] <= 34'sd0;
                    end
                end
            end

            // ----------------------------------------------------------
            // CAMADA OCULTA
            // ----------------------------------------------------------
            MAC_H: begin
                cycles       <= cycles + 32'd1;
                mac_clear    <= 1'b0;
                mac_enable_d <= 1'b0;
                use_h        <= 1'b0;
                img_addr_r   <= i;
                win_addr_r   <= ({7'b0, n} * 17'd784) + {7'b0, i};
                b_addr_r     <= n;
                state        <= MAC_H_W;
            end

            MAC_H_W: begin
                cycles       <= cycles + 32'd1;
                mac_enable_d <= 1'b1;
                if (i == 10'd783)
                    state <= MAC_H_LAST;
                else begin
                    i     <= i + 10'd1;
                    state <= MAC_H;
                end
            end

            MAC_H_LAST: begin
                // mac_enable=1: ultimo produto pixel[783]*peso[783] acumulado
                cycles       <= cycles + 32'd1;
                mac_enable_d <= 1'b0;
                i            <= 10'd0;
                state        <= ACTIV;
            end

            ACTIV: begin
                cycles     <= cycles + 32'd1;
                add_bias   <= 1'b1;
                act_enable <= 1'b1;
                state      <= SAVE_H;
            end

            SAVE_H: begin
                cycles     <= cycles + 32'd1;
                add_bias   <= 1'b0;
                act_enable <= 1'b0;
                h_wr_en    <= 1'b1;
                h_addr_w   <= n;
                h_data_w   <= act_result;
                if (n == 7'd127) begin
                    n         <= 7'd0;
                    h_wr_en   <= 1'b0;
                    state     <= MAC_Y;
                    mac_clear <= 1'b1;
                end
                else begin
                    n         <= n + 7'd1;
                    state     <= MAC_H;
                    mac_clear <= 1'b1;
                end
            end

            // ----------------------------------------------------------
            // CAMADA DE SAIDA
            // ----------------------------------------------------------
            MAC_Y: begin
                cycles       <= cycles + 32'd1;
                mac_clear    <= 1'b0;
                mac_enable_d <= 1'b0;
                use_h        <= 1'b1;
                h_addr_r     <= n;
                beta_addr_r <= ({7'b0, n} * 11'd10) + {7'b0, k};
                state        <= MAC_Y_W;
            end

            MAC_Y_W: begin
                cycles       <= cycles + 32'd1;
                mac_enable_d <= 1'b1;
                if (n == 7'd127)
                    state <= MAC_Y_LAST;
                else begin
                    n     <= n + 7'd1;
                    state <= MAC_Y;
                end
            end

            MAC_Y_LAST: begin
                // mac_enable=1: ultimo produto h[127]*beta[k][127] acumulado
                cycles       <= cycles + 32'd1;
                mac_enable_d <= 1'b0;
                n            <= 7'd0;
                state        <= SAVE_Y;
            end

            SAVE_Y: begin
                cycles         <= cycles + 32'd1;
                // salva acumulador completo no registrador y_reg[k]
                y_reg[k]       <= mac_acc;
                if (k == 4'd9) begin
                    k     <= 4'd0;
                    state <= DO_ARGMAX;
                end
                else begin
                    k         <= k + 4'd1;
                    state     <= MAC_Y;
                    mac_clear <= 1'b1;
                end
            end

            // ----------------------------------------------------------
            // ARGMAX combinacional — resultado disponivel imediatamente
            // ----------------------------------------------------------
            DO_ARGMAX: begin
                cycles <= cycles + 32'd1;
                pred   <= argmax_result;
                state  <= WAIT;
            end

            WAIT: begin
					 cycles <= cycles + 32'd1;
					 if (wait_cnt == 28'd149_999_999) begin
						  wait_cnt <= 28'd0;
						  state    <= DONE;
					 end else begin
						  wait_cnt <= wait_cnt + 28'd1;
					 end
				end

				DONE: begin
					 done  <= 1'b1;
					 busy  <= 1'b0;
					 state <= READY;
				end

						  endcase
					 end
				end

endmodule