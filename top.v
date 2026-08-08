`timescale 1ns / 1ps

module top(
    input clk,
    input rst,
    input valid_in,
    input[127:0] input_data,
    input[127:0] key,
    output[127:0] output_data,
    output valid_out
    );
    
    wire[1407:0] round_keys;
    
    key_expansions ke(
        .key_initial(key),
        .round_keys(round_keys)
    );
    
    wire [127:0] K0  = round_keys[1407:1280];
    wire [127:0] K1  = round_keys[1279:1152];
    wire [127:0] K2  = round_keys[1151:1024];
    wire [127:0] K3  = round_keys[1023:896];
    wire [127:0] K4  = round_keys[895:768];
    wire [127:0] K5  = round_keys[767:640];
    wire [127:0] K6  = round_keys[639:512];
    wire [127:0] K7  = round_keys[511:384];
    wire [127:0] K8  = round_keys[383:256];
    wire [127:0] K9  = round_keys[255:128];
    wire [127:0] K10 = round_keys[127:0];
    
    reg [127:0] s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10;
    
    reg[10:0]valid_pipe;
    
    wire [127:0] r0_out, r1_out, r2_out, r3_out, r4_out, r5_out, r6_out, r7_out, r8_out, r9_out, r10_out;
    
    add_round_key rr(
        .data_in(input_data),
        .round_key(K0),
        .data_out(r0_out)
    );
    
    aes_round r1 (.data_in(s0), .round_key(K1), .data_out(r1_out));
    aes_round r2 (.data_in(s1), .round_key(K2), .data_out(r2_out));
    aes_round r3 (.data_in(s2), .round_key(K3), .data_out(r3_out));
    aes_round r4 (.data_in(s3), .round_key(K4), .data_out(r4_out));
    aes_round r5 (.data_in(s4), .round_key(K5), .data_out(r5_out));
    aes_round r6 (.data_in(s5), .round_key(K6), .data_out(r6_out));
    aes_round r7 (.data_in(s6), .round_key(K7), .data_out(r7_out));
    aes_round r8 (.data_in(s7), .round_key(K8), .data_out(r8_out));
    aes_round r9 (.data_in(s8), .round_key(K9), .data_out(r9_out));
    
    aes_final_round r10 (.data_in(s9), .round_key(K10), .data_out(r10_out));
    
    always @(posedge clk or posedge rst)
    begin
        if (rst) begin
            s0  <= 0; s1  <= 0; s2  <= 0; s3  <= 0; s4  <= 0;
            s5  <= 0; s6  <= 0; s7  <= 0; s8  <= 0; s9  <= 0; s10 <= 0;
            valid_pipe <= 0;
        end
        else
        begin
            valid_pipe <= {valid_pipe[9:0], valid_in};
            
            s0 <= r0_out;
            s1 <= r1_out;
            s2 <= r2_out;
            s3 <= r3_out;
            s4 <= r4_out;
            s5 <= r5_out;
            s6 <= r6_out;
            s7 <= r7_out;
            s8 <= r8_out;
            s9 <= r9_out;
            s10 <= r10_out;
        end
    end
    
    assign output_data = s10;
    assign valid_out = valid_pipe[10];
endmodule
