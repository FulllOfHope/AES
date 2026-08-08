`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.04.2026 20:31:56
// Design Name: 
// Module Name: key_expansions
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module key_expansions(
    input[127:0] key_initial,
    output[1407:0] round_keys
    );
    
    wire [127:0] K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10;

    assign K0 = key_initial;
    
    key_expansion_round r1 (.input_key(K0),.round(4'd1),.output_key(K1));
    key_expansion_round r2 (.input_key(K1),.round(4'd2),.output_key(K2));
    key_expansion_round r3 (.input_key(K2),.round(4'd3),.output_key(K3));
    key_expansion_round r4 (.input_key(K3),.round(4'd4),.output_key(K4));
    key_expansion_round r5 (.input_key(K4),.round(4'd5),.output_key(K5));
    key_expansion_round r6 (.input_key(K5),.round(4'd6),.output_key(K6));
    key_expansion_round r7 (.input_key(K6),.round(4'd7),.output_key(K7));
    key_expansion_round r8 (.input_key(K7),.round(4'd8),.output_key(K8));
    key_expansion_round r9 (.input_key(K8),.round(4'd9),.output_key(K9));
    key_expansion_round r10 (.input_key(K9),.round(4'd10),.output_key(K10));
    
    assign round_keys = {K0,K1,K2,K3,K4,K5,K6,K7,K8,K9,K10};
    
endmodule
