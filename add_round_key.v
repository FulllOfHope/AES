`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.04.2026 11:24:13
// Design Name: 
// Module Name: add_round_key
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


module add_round_key(
input[127:0] data_in,
input[127:0] round_key,
output[127:0] data_out
    );
    
    assign data_out = data_in ^ round_key;
    
endmodule
