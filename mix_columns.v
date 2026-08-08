`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.04.2026 10:35:35
// Design Name: 
// Module Name: mix_columns
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


module mix_columns(
input [127:0] data_in,
output [127:0] data_out
);
    
function [7:0] mul2;
    input [7:0] x;
    begin
        mul2 = (x[7]) ? ((x << 1) ^ 8'h1b) : (x << 1);
    end
endfunction
    
function [7:0] mul3;
    input [7:0] x;
    begin
        mul3 = mul2(x) ^ x;
    end
endfunction
    
    // Extract bytes (column-major)
    wire [7:0] b0  = data_in[127:120];
    wire [7:0] b1  = data_in[119:112];
    wire [7:0] b2  = data_in[111:104];
    wire [7:0] b3  = data_in[103:96];
    
    wire [7:0] b4  = data_in[95:88];
    wire [7:0] b5  = data_in[87:80];
    wire [7:0] b6  = data_in[79:72];
    wire [7:0] b7  = data_in[71:64];
    
    wire [7:0] b8  = data_in[63:56];
    wire [7:0] b9  = data_in[55:48];
    wire [7:0] b10 = data_in[47:40];
    wire [7:0] b11 = data_in[39:32];
    
    wire [7:0] b12 = data_in[31:24];
    wire [7:0] b13 = data_in[23:16];
    wire [7:0] b14 = data_in[15:8];
    wire [7:0] b15 = data_in[7:0];
    
    // Column 0
    wire [7:0] c0 = mul2(b0) ^ mul3(b1) ^ b2 ^ b3;
    wire [7:0] c1 = b0 ^ mul2(b1) ^ mul3(b2) ^ b3;
    wire [7:0] c2 = b0 ^ b1 ^ mul2(b2) ^ mul3(b3);
    wire [7:0] c3 = mul3(b0) ^ b1 ^ b2 ^ mul2(b3);
    
    // Column 1
    wire [7:0] c4 = mul2(b4) ^ mul3(b5) ^ b6 ^ b7;
    wire [7:0] c5 = b4 ^ mul2(b5) ^ mul3(b6) ^ b7;
    wire [7:0] c6 = b4 ^ b5 ^ mul2(b6) ^ mul3(b7);
    wire [7:0] c7 = mul3(b4) ^ b5 ^ b6 ^ mul2(b7);
    
    // Column 2
    wire [7:0] c8  = mul2(b8) ^ mul3(b9) ^ b10 ^ b11;
    wire [7:0] c9  = b8 ^ mul2(b9) ^ mul3(b10) ^ b11;
    wire [7:0] c10 = b8 ^ b9 ^ mul2(b10) ^ mul3(b11);
    wire [7:0] c11 = mul3(b8) ^ b9 ^ b10 ^ mul2(b11);
    
    // Column 3
    wire [7:0] c12 = mul2(b12) ^ mul3(b13) ^ b14 ^ b15;
    wire [7:0] c13 = b12 ^ mul2(b13) ^ mul3(b14) ^ b15;
    wire [7:0] c14 = b12 ^ b13 ^ mul2(b14) ^ mul3(b15);
    wire [7:0] c15 = mul3(b12) ^ b13 ^ b14 ^ mul2(b15);
    
    // Reassemble
    assign data_out = {
        c0, c1, c2, c3,
        c4, c5, c6, c7,
        c8, c9, c10, c11,
        c12, c13, c14, c15
    };
    
endmodule
