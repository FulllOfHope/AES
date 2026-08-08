`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.04.2026 11:27:10
// Design Name: 
// Module Name: aes_round
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


module aes_round(
input[127:0] data_in,
input[127:0] round_key,
output[127:0] data_out
    );
    
    wire[127:0] sub_bytes_out;
    wire[127:0] shift_rows_out;
    wire[127:0] mix_columns_out;
    
    sub_bytes u1(
    .data_in(data_in),
    .data_out(sub_bytes_out)
    );
    
    shift_rows u2(
    .data_in(sub_bytes_out),
    .data_out(shift_rows_out)
    );
    
    mix_columns u3(
    .data_in(shift_rows_out),
    .data_out(mix_columns_out)
    );
    
    add_round_key u4(
    .data_in(mix_columns_out),
    .round_key(round_key),
    .data_out(data_out)
    );
    
endmodule
