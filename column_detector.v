`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.01.2026 03:34:57
// Design Name: 
// Module Name: column_detector
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


module column_detector(
    input wire  [14:0]col_sync_out,
    output wire col_valid,
    output reg [3:0]col_idx
    );
    
 //OR Reduction : any key is pressed   
  assign col_valid = |col_sync_out;
  
 //Priority Encoder: lowest index wins
 always @(*) begin
    col_idx=4'd0;
    
    if(col_sync_out[0])  col_idx=4'd0;
    else if(col_sync_out[1])    col_idx=4'd1;
    else if(col_sync_out[2])    col_idx=4'd2;
    else if(col_sync_out[3])    col_idx=4'd3;
    else if(col_sync_out[4])    col_idx=4'd4;
    else if(col_sync_out[5])    col_idx=4'd5;
    else if(col_sync_out[6])    col_idx=4'd6;
    else if(col_sync_out[7])    col_idx=4'd7;
    else if(col_sync_out[8])    col_idx=4'd8;
    else if(col_sync_out[9])    col_idx=4'd9;
    else if(col_sync_out[10])   col_idx=4'd10;
    else if(col_sync_out[11])   col_idx=4'd11;
    else if(col_sync_out[12])   col_idx=4'd12;
    else if(col_sync_out[13])   col_idx=4'd13;
    else if(col_sync_out[14])   col_idx=4'd14;
    
end
endmodule
