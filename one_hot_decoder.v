`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 01:40:20
// Design Name: 
// Module Name: one_hot_decoder
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


module one_hot_decoder(
    input wire [1:0]row_idx,
    output reg [3:0]row_out
    );
 
 //Another approach
 //   assign row_out= 4'b0001 << row_idx;  [Shifting the single one bit using left_shift operator based on row_idx value]
    
always @(*)
  case(row_idx)
    2'b00: row_out =4'b0001;
    2'b01: row_out =4'b0010;
    2'b10: row_out =4'b0100;
    2'b11: row_out =4'b1000;
    default: row_out =4'b0000;
  endcase

endmodule
