`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2026 01:34:15
// Design Name: 
// Module Name: control_fsm
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


module control_fsm(
	input wire 	clk,
	input wire	rst_n,
	input wire 	col_valid,
	input wire	debounced_press,
	input wire 	debounced_release,
	
	output reg 	row_scan_en,
	output reg 	debounce_en,
	output reg 	key_latch_en,
	output reg  key_valid
    );
    
localparam 	IDLE=3'b000, SCAN_ROW=3'b001, SAMPLE_COL= 3'b010, 
			DEBOUNCE=3'b011, KEY_VALID= 3'b100, WAIT_RELEASE=3'b101;

reg [2:0] state,next_state;

//State Register			
always @(posedge clk or negedge rst_n)begin
if(!rst_n)
	state<=IDLE;
else
	state<=next_state;
end

//Next State Logic (all blocking assignments in combinational block)
always @(*) begin
	next_state = state;	// default: hold current state
	case(state)
		IDLE:
			next_state = SCAN_ROW;
		
		SCAN_ROW:
			if(col_valid)
				next_state = SAMPLE_COL;
			else
				next_state = SCAN_ROW;
				
		SAMPLE_COL:
			next_state = DEBOUNCE;
		
		DEBOUNCE: begin
			if(debounced_press)	
				next_state = KEY_VALID;
			else
				next_state = DEBOUNCE;
		end
		
		KEY_VALID:
			next_state = WAIT_RELEASE;
			
		WAIT_RELEASE: begin
			if(debounced_release)
				next_state = SCAN_ROW;
			else
				next_state = WAIT_RELEASE;
		end
		
		default:
			next_state = IDLE;
	endcase
end	

//Output Control Logic
always @(*) begin
	row_scan_en  = 1'b0;
	debounce_en  = 1'b0;
	key_latch_en = 1'b0;
	key_valid    = 1'b0;
	
	case(state)
		IDLE:
			row_scan_en = 1'b1;
			
		SCAN_ROW:
			row_scan_en = 1'b1;
		
		SAMPLE_COL: begin
			row_scan_en  = 1'b0;	// freeze Row
			key_latch_en = 1'b1;	// latch row/col now while they are stable
		end
				
		DEBOUNCE:
			debounce_en = 1'b1;
			
		KEY_VALID:
			key_valid = 1'b1;
		
		WAIT_RELEASE:
			key_valid = 1'b1;	// hold valid until release
	endcase
end
endmodule
