// Modulo responsavel por ler o vetor dos digitos e determinar o maior indice
module argmax (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire signed [15:0] y_in,
    input wire [3:0] k,  
    output reg [3:0] pred,
    output reg done
);

reg signed [15:0] maior; // Registrador que armazena o maior valor de y visto até agora durante a varredura dos 10 valores

// Compara a entrada com o "maior" atual e atualiza para ao final determinar o maior valor do vetor
always @(posedge clk or posedge reset) begin
    if (reset) begin
        maior <= -16'sd32768; // Inicia com o menor valor possivel (negativo)
        pred  <= 4'd0;
        done  <= 1'b0;
    end
    else if (enable) begin
        if (k == 4'd0) begin
            maior <= y_in;
            pred  <= 4'd0;
            done  <= 1'b0;
        end
        else if (y_in > maior) begin
            maior <= y_in;
            pred  <= k;
        end
        if (k == 4'd9)
            done <= 1'b1;
    end
end

endmodule