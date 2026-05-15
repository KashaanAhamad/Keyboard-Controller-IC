`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.01.2026 12:02:59
// Design Name: 
// Module Name: keyboard_Top
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


module keyboard_Top(
	input  wire 	   clk,
	input  wire 	   rst_n,
	input  wire  [14:0]col_in,
	
	output wire  [3:0] row_out,
	output wire  [5:0] key_code,
	output wire		   key_valid
    );
  
 //FSM Control Signal
 wire row_scan_en;
 wire debounce_en;
 wire key_latch_en;
    
//Internal wires

//Row Scan
wire [1:0]row_idx;

//column path
wire [14:0] col_sync;
wire col_valid;
wire [3:0] col_idx;

//Debounce
wire debounced_press;
wire debounced_release;


//latch Values
reg [1:0] latched_row;
reg [3:0] latched_col;



row_scanner u_r_scanner(
						.clk(clk),
						.rst_n(rst_n),
						.en(row_scan_en),
						.row_idx(row_idx),
						.row_out(row_out)
						);
Col_Synchronizer u_c_synchronizer(
									.clk(clk),
									.rst_n(rst_n),
									.col_in(col_in),
									.col_sync_out(col_sync)
									);
column_detector u_col_detector(
								.col_sync_out(col_sync),
								.col_valid(col_valid),
								.col_idx(col_idx)
								);
debounce_unit u_deb_unit(
							.clk(clk),
							.rst_n(rst_n),
							.en(debounce_en),
							.key_detected(col_valid),
							.debounced_press(debounced_press),
							.debounced_release(debounced_release)
							);
control_fsm u_ctrl_fsm(
							.clk(clk),
							.rst_n(rst_n),
							
							.col_valid(col_valid),
							.debounced_press(debounced_press),
							.debounced_release(debounced_release),
							
							.row_scan_en(row_scan_en),
							.debounce_en(debounce_en),
							.key_latch_en(key_latch_en),
							.key_valid(key_valid));
							
//Latching Row and Col
always @(posedge clk or negedge rst_n)begin
if(!rst_n) begin
	latched_row <= 0;
	latched_col <= 0;
end else if(key_latch_en) begin
		latched_row <= row_idx;
		latched_col <= col_idx;
	end
end
							
key_encoder u_key_encoder(
							.row_idx(latched_row),
							.col_idx(latched_col),
							.keycode(key_code)
							);

endmodule
