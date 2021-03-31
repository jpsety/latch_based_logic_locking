// a wrapper for sha256 that runs a test flow on chip

module sha256_ctrl(clk, rst, ld, key, text_in);

input clk, rst;
output logic init, next;
output logic [511:0] block;
logic [511:0] lfsr_block;

logic [4:0] cycle_count;

LFSR lfsr [63:0] (.in(block), .out(lfsr_block));

always @(posedge clk) begin
	if (rst==1) begin
		cycle_count <= 0;
		init <= 0;
		next <= 0;
		block <= 0;
	end else if (cycle_count>=30) begin //go to next input
		cycle_count <= 0;
		init <= 1;
		next <= 0;
		block <= lfsr_block;
	end else if (cycle_count==0) begin // first cycle
		cycle_count <= cycle_count+1;
		init <= 0;
		next <= 1;
	end else if (cycle_count==1) begin // second cycle
		cycle_count <= cycle_count+1;
		init <= 0;
		next <= 0;
	end else if (cycle_count<30) begin // others
		cycle_count <= cycle_count+1;
	end
end

endmodule

