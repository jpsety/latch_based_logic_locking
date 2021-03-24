//************************************************************************
// Copyright (C) 2020 Massachusetts Institute of Technology
// SPDX License Identifier: MIT
//
// File Name:       aes_192_mock_tss.sv
// Program:         Common Evaluation Platform (CEP)
// Description:     
// Notes:           
//************************************************************************
`timescale 1ns/1ns

typedef enum {
	IDLE,
	SCAN,
	LOADED,
	PARTIAL_LOAD
} TSS_STATE_TYPE;

module gps_tss (

    // Clock and Reset
    input clk,
    input rst, 

    // Core I/O
	input [5:0] sv_num,
	input startRound,
	output [12:0] ca_code,
	output [127:0] p_code,
	output [127:0] l_code,
	output l_code_valid,

    // LLKI Discrete I/O
    input [63:0]          llkid_key_data,
    input                 llkid_key_valid,
    output logic          llkid_key_ready,
    output logic          llkid_key_complete,
    input                 llkid_clear_key,
    output logic          llkid_clear_key_ack

);

  logic [63:0]           llkid_key_register;
  logic [256:0]          key;
  logic [5:0]            scan_i; //scan index
  logic [2:0]            scan_n; //number of scans
  TSS_STATE_TYPE         current_state;

  always @(posedge clk or posedge rst)
  begin
    if (rst) begin
      llkid_key_ready         <= '1;
      llkid_key_complete      <= '0;
      llkid_clear_key_ack     <= '0;
      llkid_key_register      <= '0;
      scan_i                  <= '0;
      scan_n                  <= '0;
	  key					  <= '0;
      current_state           <= IDLE;
    end else begin
      case (current_state)
        IDLE : begin
          llkid_key_ready         <= '1;
          llkid_key_complete      <= '0;
          llkid_clear_key_ack     <= '0;
          llkid_key_register      <= '0;
		  scan_i                  <= '0;
		  scan_n                  <= '0;
	  	  key					  <= '0;
          current_state           <= IDLE;

          if (llkid_clear_key) begin
            current_state         <= IDLE;
          	llkid_clear_key_ack   <= '1;
          	key 				  <= '0;
          end else if (llkid_key_valid) begin
			// copy in data and start scan
            llkid_key_ready       <= '0;
            llkid_key_register    <= llkid_key_data;
            current_state         <= SCAN;
          end

        end

        SCAN : begin
          llkid_key_ready         <= '0;
          llkid_key_complete      <= '0;
          llkid_clear_key_ack     <= '0;
          llkid_key_register      <= llkid_key_register;
          current_state           <= SCAN;

          // Incr the scan index
          scan_i <= scan_i + 1;
          scan_n <= scan_n;

		  // shift the data
		  key <= {llkid_key_register[scan_i],key[256:1]};

          if (scan_i == 63 && scan_n == 3) begin
			// key is ready
          	llkid_key_ready         <= '1;
          	llkid_key_complete      <= '1;
            current_state         <= LOADED;
			scan_i <= 0;
			scan_n <= 0;
		  end else if (scan_i == 63) begin
			// wait for next key part
          	llkid_key_ready         <= '1;
            current_state         <= PARTIAL_LOAD;
			scan_i <= 0;
			scan_n <= scan_n + 1;
          end else if (llkid_clear_key) begin
			// clear
            current_state         <= IDLE;
          	llkid_clear_key_ack   <= '1;
          	key 				  <= '0;
          end
        end

        PARTIAL_LOAD : begin
          llkid_key_ready         <= '1;
          llkid_key_complete      <= '0;
          llkid_clear_key_ack     <= '0;
          llkid_key_register      <= llkid_key_register;
		  scan_i                  <= '0;
		  scan_n                  <= scan_n;
		  key 					  <= key;
          current_state           <= PARTIAL_LOAD;

          if (llkid_clear_key) begin
            current_state         <= IDLE;
          	llkid_clear_key_ack   <= '1;
          	key 				  <= '0;
          end else if (llkid_key_valid) begin
            llkid_key_ready       <= '0;
            llkid_key_register    <= llkid_key_data;
            current_state         <= SCAN;
		  end
        end

        LOADED : begin
          llkid_key_ready         <= '1;
          llkid_key_complete      <= '1;
          llkid_clear_key_ack     <= '0;
          llkid_key_register      <= llkid_key_register;
		  scan_i                  <= '0;
		  scan_n                  <= '0;
		  key 					  <= key;
          current_state           <= LOADED;

          if (llkid_clear_key) begin
            current_state         <= IDLE;
          	llkid_clear_key_ack   <= '1;
          	key 				  <= '0;
          end else if (llkid_key_valid) begin
            llkid_key_ready       <= '0;
            llkid_key_register    <= llkid_key_data;
            current_state         <= SCAN;
		  end
        end

        default                   : begin
          llkid_key_ready         <= '1;
          llkid_key_complete      <= '0;
          llkid_clear_key_ack     <= '0;
          llkid_key_register      <= '0;
		  scan_i                  <= '0;
		  scan_n                  <= '0;
		  key 					  <= '0;
          current_state           <= IDLE;
        end
      endcase
    end
  end

  // Instantiate the gps core
  gps gps_inst (
	  .sys_clk_50(clk),
	  .sync_rst_in(rst),
	  .sv_num,
	  .startRound,
	  .ca_code,
	  .p_code,
	  .l_code,
	  .l_code_valid,
	  .lbll_key
  );

endmodule

