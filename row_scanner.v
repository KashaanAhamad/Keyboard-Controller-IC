`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 01:25:03
// Design Name: 
// Module Name: row_scanner
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


module row_scanner(
    input wire clk,
    input wire rst_n,
    output reg [1:0]row_idx,
    output wire [3:0]row_out
    );
  
//2 bit row counter  
always @(posedge clk or negedge rst_n)
begin
   if(!rst_n)
    row_idx<=2'b0;
   else
    row_idx<=row_idx +1;
end

//one-Hot Decoder
one_hot_decoder HOT_decoder(.row_idx(row_idx),.row_out(row_out));
endmodule
