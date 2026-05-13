`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.01.2026 20:33:47
// Design Name: 
// Module Name: Col_Synchronizer
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


module Col_Synchronizer #(parameter SIZE=15)(
    input wire clk,
    input wire rst_n,
    input wire [SIZE-1:0]col_in,
    output [SIZE-1:0]col_sync_out  
    );
    reg [SIZE-1:0]col_sync_ff1;
    d_ff #(.SIZE(SIZE)) FF1(clk,rst_n,col_in,col_sync_ff1);
    d_ff #(.SIZE(SIZE)) FF2(clk,rst_n,col_sync_ff1,col_sync_out);
    
endmodule

module d_ff #(parameter SIZE=15)(
    input clk,rst_n,
    input [SIZE-1:0]d_in,
    output reg [SIZE-1:0]d_out);
    
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        d_out<=0;
    else    
        d_out<=d_in;
end
endmodule
