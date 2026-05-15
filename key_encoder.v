`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2026 01:27:04
// Design Name: 
// Module Name: key_encoder
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


module key_encoder(
	input wire [1:0] row_idx,
	input wire [3:0] col_idx,
	output wire [5:0] keycode
    );
    
    assign keycode = (row_idx * 6'd15) + col_idx; 
endmodule
