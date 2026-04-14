// =============================================================================
// top_de1soc.v — Interface com a placa DE1-SoC (TOP LEVEL)
//
// Mapeamento:
//   SW[3:0] = opcode (4 bits)
//   SW[9:4] = endereco parcial (6 bits, completado com zeros para 12 bits)
//   KEY[0]  = reset
//   KEY[1]  = envia instrucao (instr_valid)
//   KEY[2]  = captura e exibe status nos displays
//
// Instrucoes:
//   SW[3:0]=0001 + KEY[1] → STORE_IMG     → LEDR[0] acende
//   SW[3:0]=0010 + KEY[1] → STORE_WEIGHTS → LEDR[1] acende
//   SW[3:0]=0011 + KEY[1] → STORE_BIAS    → LEDR[2] acende
//   SW[3:0]=0100 + KEY[1] → START         → inferencia comeca
//   SW[3:0]=0101 + KEY[2] → STATUS        → display mostra estado
//
// LEDs:
//   LEDR[0] = img_ready
//   LEDR[1] = w_ready
//   LEDR[2] = b_ready
//   LEDR[6] = READY
//   LEDR[7] = DONE
//   LEDR[8] = BUSY
//   LEDR[9] = ERROR
//
// Displays:
//   HEX5        = pred (0..9), apagado ate ter resultado
//   HEX4..HEX0  = estado (capturado pelo KEY[2]):
//     READY: HEX4=r HEX3=E HEX2=A HEX1=d HEX0=Y
//     BUSY:  HEX4=apag HEX3=b HEX2=U HEX1=S HEX0=Y
//     DONE:  HEX4=apag HEX3=d HEX2=o HEX1=n HEX0=E
//     ERROR: HEX4=apag HEX3=E HEX2=r HEX1=r HEX0=o
// =============================================================================

module top_de1soc (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [9:0]  SW,
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,
    output wire [9:0]  LEDR
);

// ============================================================
// Reset e botoes
// ============================================================
wire reset    = ~KEY[0];
wire btn_send = ~KEY[1];
wire btn_stat = ~KEY[2];
wire btn_mem  = ~KEY[3];

// ============================================================
// Deteccao de borda dos botoes
// ============================================================
reg btn_send_prev, btn_stat_prev, btn_mem_prev; 
always @(posedge CLOCK_50 or posedge reset) begin
    if (reset) begin
        btn_send_prev <= 1'b0;
        btn_stat_prev <= 1'b0;
		  btn_mem_prev  <= 1'b0; 
    end else begin
        btn_send_prev <= btn_send;
        btn_stat_prev <= btn_stat;
		  btn_mem_prev  <= btn_mem; 
    end
end

wire btn_send_pulse = btn_send & ~btn_send_prev;
wire btn_stat_pulse = btn_stat & ~btn_stat_prev;
wire btn_mem_pulse  = btn_mem  & ~btn_mem_prev; 

// ============================================================
// Monta instrucao de 32 bits:
//   [31:28] = opcode  = SW[3:0]
//   [27:16] = endereco = {6'b0, SW[9:4]} (12 bits)
//   [15:0]  = dado zerado (Marco 1: dado via .mif)
// ============================================================
wire [31:0] instruction = {SW[3:0], {6'b0, SW[9:4]}, 16'b0};

reg instr_valid;
always @(posedge CLOCK_50 or posedge reset) begin
    if (reset)
        instr_valid <= 1'b0;
    else
        instr_valid <= btn_send_pulse;
end

// ============================================================
// Instrucao de escrita manual (KEY[3]):
//   [31:28] = opcode  = SW[3:0]  (1=img, 2=win, 3=bias, etc.)
//   [14:12] = endereco = SW[6:4] (3 bits, zero-extendido)
//   [11:9]  = valor    = SW[9:7] (3 bits, zero-extendido)
//   bit [28] setado para sinalizar modo "mem_write"
// ============================================================
wire [31:0] mem_write_instr = {SW[3:0], 2'b0, {7'b0, SW[6:4]}, 8'b0, {5'b0, SW[9:7]}};
// Reutilizamos o mesmo formato, mas num sinal separado

reg mem_write_valid;
always @(posedge CLOCK_50 or posedge reset) begin
    if (reset)
        mem_write_valid <= 1'b0;
    else
        mem_write_valid <= btn_mem_pulse;
end

// ============================================================
// Sinais do elm_accel
// ============================================================
wire [1:0]  status;
wire [3:0]  pred;
wire        img_ready;
wire        w_ready;
wire        b_ready;
wire [31:0] cycles;

// ============================================================
// Instancia elm_accel
// ============================================================
elm_accel u_elm (
    .clk         (CLOCK_50),
    .reset       (reset),
    .instruction (instruction),
    .instr_valid (instr_valid),
	 .mem_write_instr  (mem_write_instr),
    .mem_write_valid  (mem_write_valid),  
    .status      (status),
    .pred        (pred),
    .img_ready   (img_ready),
    .w_ready     (w_ready),
    .b_ready     (b_ready),
    .cycles      (cycles)
);

// ============================================================
// result_valid: acende HEX5 so apos primeira inferencia
// ============================================================
reg result_valid;
always @(posedge CLOCK_50 or posedge reset) begin
    if (reset)
        result_valid <= 1'b0;
    else if (status == 2'b10)  // ST_DONE
        result_valid <= 1'b1;
end

// ============================================================
// Registrador de estado para display (capturado pelo KEY[2])
// ============================================================
reg [1:0] display_state;
reg       display_valid;
always @(posedge CLOCK_50 or posedge reset) begin
    if (reset) begin
        display_state <= 2'b00;
        display_valid <= 1'b0;
    end
    else if (btn_stat_pulse) begin
        display_state <= status;
        display_valid <= 1'b1;
    end
end

// ============================================================
// LEDs
// ============================================================
assign LEDR[0]   = img_ready;
assign LEDR[1]   = w_ready;
assign LEDR[2]   = b_ready;
assign LEDR[5:3] = 3'b0;
assign LEDR[6]   = (status == 2'b00);  // READY
assign LEDR[7]   = (status == 2'b10);  // DONE
assign LEDR[8]   = (status == 2'b01);  // BUSY
assign LEDR[9]   = (status == 2'b11);  // ERROR

// ============================================================
// HEX5 — pred (apagado ate ter resultado)
// ============================================================
wire [6:0] hex5_raw;
decod_pred u_hex5 (.in(pred), .out(hex5_raw));
assign HEX5 = result_valid ? hex5_raw : 7'b1111111;

// ============================================================
// status localparam
// ============================================================
localparam ST_READY = 2'b00;
localparam ST_BUSY  = 2'b01;
localparam ST_DONE  = 2'b10;
localparam ST_ERROR = 2'b11;

// ============================================================
// HEX4 — r(READY) ou apagado
// ============================================================
reg [6:0] hex4_val;
always @(*) begin
    if (!display_valid) hex4_val = 7'b1111111;
    else case (display_state)
        ST_READY: hex4_val = 7'b0101111; // r
        default:  hex4_val = 7'b1111111;
    endcase
end
assign HEX4 = hex4_val;

// ============================================================
// HEX3 — E(READY) / b(BUSY) / d(DONE) / E(ERROR)
// ============================================================
reg [6:0] hex3_val;
always @(*) begin
    if (!display_valid) hex3_val = 7'b1111111;
    else case (display_state)
        ST_READY: hex3_val = 7'b0000110; // E
        ST_BUSY:  hex3_val = 7'b0000011; // b
        ST_DONE:  hex3_val = 7'b0100001; // d
        ST_ERROR: hex3_val = 7'b0000110; // E
        default:  hex3_val = 7'b1111111;
    endcase
end
assign HEX3 = hex3_val;

// ============================================================
// HEX2 — A(READY) / U(BUSY) / o(DONE) / r(ERROR)
// ============================================================
reg [6:0] hex2_val;
always @(*) begin
    if (!display_valid) hex2_val = 7'b1111111;
    else case (display_state)
        ST_READY: hex2_val = 7'b0001000; // A
        ST_BUSY:  hex2_val = 7'b1000001; // U
        ST_DONE:  hex2_val = 7'b0100011; // o
        ST_ERROR: hex2_val = 7'b0101111; // r
        default:  hex2_val = 7'b1111111;
    endcase
end
assign HEX2 = hex2_val;

// ============================================================
// HEX1 — d(READY) / S(BUSY) / n(DONE) / r(ERROR)
// ============================================================
reg [6:0] hex1_val;
always @(*) begin
    if (!display_valid) hex1_val = 7'b1111111;
    else case (display_state)
        ST_READY: hex1_val = 7'b0100001; // d
        ST_BUSY:  hex1_val = 7'b0010010; // S
        ST_DONE:  hex1_val = 7'b0101011; // n
        ST_ERROR: hex1_val = 7'b0101111; // r
        default:  hex1_val = 7'b1111111;
    endcase
end
assign HEX1 = hex1_val;

// ============================================================
// HEX0 — Y(READY) / Y(BUSY) / E(DONE) / o(ERROR)
// ============================================================
reg [6:0] hex0_val;
always @(*) begin
    if (!display_valid) hex0_val = 7'b1111111;
    else case (display_state)
        ST_READY: hex0_val = 7'b0010001; // Y
        ST_BUSY:  hex0_val = 7'b0010001; // Y
        ST_DONE:  hex0_val = 7'b0000110; // E
        ST_ERROR: hex0_val = 7'b0100011; // o
        default:  hex0_val = 7'b1111111;
    endcase
end
assign HEX0 = hex0_val;

endmodule