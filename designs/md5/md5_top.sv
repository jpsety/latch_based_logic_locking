// a wrapper for md5 that runs a test flow on chip

module md5_ctrl(clk, rst, msg_in_valid, msg_padded);

input clk, rst;
output logic msg_in_valid;
output logic [511:0] msg_padded;
logic [511:0] lfsr_msg_padded;

logic [4:0] cycle_count;

LFSR lfsr [63:0] (.in(msg_padded), .out(lfsr_msg_padded));

always @(posedge clk) begin
	if (rst==1) begin
		cycle_count <= 0;
		msg_in_valid <= 0;
		msg_padded <= 0;
	end else if (cycle_count>=30) begin //go to next input
		cycle_count <= 0;
		msg_padded <= lfsr_msg_padded;
	end else if (cycle_count==0) begin // first cycle
		cycle_count <= cycle_count+1;
		msg_in_valid <= 1;
	end else if (cycle_count==1) begin // second cycle
		cycle_count <= cycle_count+1;
		msg_in_valid <= 0;
	end else if (cycle_count<30) begin // others
		cycle_count <= cycle_count+1;
	end
end

endmodule

