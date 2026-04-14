module activation (
    input wire clk,
	 input wire reset,
	 input wire enable,   			   // era act_enable na FSM
    input wire [15:0] acc_in,  	  // Q4.12, 16 bits
    output wire [15:0] result     // Q4.12, 16 bits
);

// Constantes em Q4.12
localparam V_0_5      = 16'h0800;  // 0.5
localparam V_0_625    = 16'h0A00;  // 0.625
localparam V_0859375  = 16'h0DC0;  // 0.859375
localparam V_1_0      = 16'h1000;  // 1.0
localparam LIMIT_1_0  = 16'h1000;  // 1.0
localparam LIMIT_2_5  = 16'h2800;  // 2.5
localparam LIMIT_4_5  = 16'h4800;  // 4.5

reg [15:0] d_out_comb;
reg        e_negativo;
reg [15:0] valor_absoluto;

    always @(*) begin
        e_negativo     = acc_in[15];
        valor_absoluto = e_negativo ? (~acc_in + 1'b1) : acc_in;
 
        d_out_comb = V_1_0;
        if      (valor_absoluto < LIMIT_1_0) d_out_comb = (valor_absoluto >> 2) + V_0_5;
        else if (valor_absoluto < LIMIT_2_5) d_out_comb = (valor_absoluto >> 3) + V_0_625;
        else if (valor_absoluto < LIMIT_4_5) d_out_comb = (valor_absoluto >> 5) + V_0859375;
        else                                 d_out_comb = V_1_0;
 
        if (e_negativo) d_out_comb = V_1_0 - d_out_comb;
    end
 
    assign result = enable ? d_out_comb : 16'b0;
 
endmodule