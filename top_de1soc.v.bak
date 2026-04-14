module top_de1soc (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [9:0]  SW,
    output wire [6:0]  HEX0,
    output wire [9:0]  LEDR
);

wire [1:0]  status;
wire [3:0]  pred;
wire [31:0] cycles;

// reset ativo em LOW (botao KEY inverte logica)
wire reset      = ~KEY[0];
wire instr_valid = ~KEY[1];

// instrução de START hardcoded
wire [31:0] instruction = {4'd4, 28'b0};

elm_accel u_elm (
    .clk         (CLOCK_50),
    .reset       (reset),
    .instruction (instruction),
    .instr_valid (instr_valid),
    .status      (status),
    .pred        (pred),
    .cycles      (cycles)
);

// LEDs de status
assign LEDR[0] = (status == 2'b01); // BUSY
assign LEDR[1] = (status == 2'b10); // DONE
assign LEDR[2] = (status == 2'b11); // ERROR
assign LEDR[9:3] = 7'b0;

// display HEX0 mostra pred (decodificador 7 segmentos)
hex7seg u_hex (
    .in  (pred),
    .out (HEX0)
);

endmodule

// decodificador 7 segmentos
module hex7seg (
    input  wire [3:0] in,
    output reg  [6:0] out
);
always @(*) begin
    case (in)
        4'd0: out = 7'b1000000;
        4'd1: out = 7'b1111001;
        4'd2: out = 7'b0100100;
        4'd3: out = 7'b0110000;
        4'd4: out = 7'b0011001;
        4'd5: out = 7'b0010010;
        4'd6: out = 7'b0000010;
        4'd7: out = 7'b1111000;
        4'd8: out = 7'b0000000;
        4'd9: out = 7'b0010000;
        default: out = 7'b1111111;
    endcase
end
endmodule