// a wrapper for aes that runs a test flow on chip

module aes_ctrl(clk, rst, ld, key, text_in);

input clk, rst;
output logic ld;
output logic [127:0] key, text_in;
logic [127:0] lfsr_key, lfsr_text_in;

logic [4:0] cycle_count;

LFSR lfsr [31:0] (.in({key,text_in}), .out({lfsr_key, lfsr_text_in}));

always @(posedge clk or posedge rst) begin
	if (rst==1) begin
		cycle_count <= 0;
		ld <= 0;
		key <= 0;
		text_in <= 0;
	end else if (cycle_count>=30) begin //go to next input
		cycle_count <= 0;
		key <= lfsr_key;
		text_in <= lfsr_text_in;
	end else if (cycle_count==0) begin // first cycle
		cycle_count <= cycle_count+1;
		ld <= 1;
	end else if (cycle_count==1) begin // second cycle
		cycle_count <= cycle_count+1;
		ld <= 0;
	end else if (cycle_count<30) begin // others
		cycle_count <= cycle_count+1;
	end
end

endmodule
