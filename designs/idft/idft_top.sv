// a wrapper for idft that runs a test flow on chip

module idft_ctrl(clk, rst, ld, key, text_in);

input clk, rst;
output logic next;
output logic [15:0] X0, X1, X2, X3;
logic [15:0] lfsr_X0, lfsr_X1, lfsr_X2, lfsr_X3;

logic [4:0] cycle_count;

LFSR lfsr [7:0] (.in({X0, X1, X2, X3}), .out({lfsr_X0, lfsr_X1, lfsr_X2, lfsr_X3}));

always @(posedge clk) begin
	if (rst==1) begin
		cycle_count <= 0;
		X0 <= 0;
		X1 <= 0;
		X2 <= 0;
		X3 <= 0;
		next <= 0;
	end else if (cycle_count>=30) begin //go to next input
		X0 <= lfsr_X0;
		X1 <= lfsr_X1;
		X2 <= lfsr_X2;
		X3 <= lfsr_X3;
		next <= 1;
	end else if (cycle_count==0) begin // first cycle
		cycle_count <= cycle_count+1;
		next <= 0;
	end else if (cycle_count<30) begin // others
		cycle_count <= cycle_count+1;
	end
end

endmodule


