`timescale 1ns / 1ps

module add_round_key(
input[127:0] data_in,
input[127:0] round_key,
output[127:0] data_out
    );
    
    assign data_out = data_in ^ round_key;
    
endmodule
