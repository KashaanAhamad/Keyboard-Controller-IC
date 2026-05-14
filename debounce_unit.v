`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.01.2026 13:12:12
// Design Name: 
// Module Name: debounce_unit
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


module debounce_unit #(parameter DEBOUNCE_CNT_MAX=20_000)(
	input wire clk,
	input wire rst_n,
	input wire en,
	input wire key_detected,
	output reg debounced_press,
	output reg debounced_release
    );
    
  // auto-scale counter width based on DEBOUNCE_CNT_MAX
  reg [$clog2(DEBOUNCE_CNT_MAX)-1:0] debounce_cnt;
  reg [1:0] state;
    
  localparam 	IDLE          = 2'b00,
  				PRESS_CHECK   = 2'b01,
  				PRESSED       = 2'b10,
  				RELEASE_CHECK = 2'b11;
  
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state           <= IDLE;
      debounce_cnt    <= 0;
      debounced_press <= 0;
      debounced_release <= 0;
    end else begin
      // Default: single-cycle pulses auto-deassert
      debounced_press   <= 0;
      debounced_release <= 0;
      
      if(en) begin  // only run when FSM enables debounce
        case(state)
          IDLE: begin 
            if(key_detected) begin
              state        <= PRESS_CHECK;
              debounce_cnt <= 0;
            end
          end
          
          PRESS_CHECK: begin
            if(key_detected) begin
              if(debounce_cnt == DEBOUNCE_CNT_MAX) begin
                state           <= PRESSED;
                debounced_press <= 1;
              end else begin
                debounce_cnt <= debounce_cnt + 1;
              end
            end else begin
              state <= IDLE;
            end
          end
          
          PRESSED: begin
            if(!key_detected) begin
              state        <= RELEASE_CHECK;
              debounce_cnt <= 0;
            end
          end
          
          RELEASE_CHECK: begin
            if(!key_detected) begin
              if(debounce_cnt == DEBOUNCE_CNT_MAX) begin
                state             <= IDLE;
                debounced_release <= 1;
              end else begin
                debounce_cnt <= debounce_cnt + 1;
              end
            end else begin
              state <= PRESSED;
            end
          end
        endcase
      end // if(en)
    end // else (not reset)
  end	 
endmodule
