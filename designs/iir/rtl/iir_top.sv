// a wrapper for iir that runs a test flow on chip

module iir_ctrl(clk, rst, inData);

input clk, rst;
output logic [31:0] inData;
logic [31:0] lfsr_inData;

logic [4:0] cycle_count;

LFSR lfsr [3:0] (.in(inData), .out(lfsr_inData));

always @(posedge clk) begin
	if (rst==1) begin
		cycle_count <= 0;
		inData <= 0;
	end else if (cycle_count>=30) begin //go to next input
		cycle_count <= 0;
		inData <= lfsr_inData;
	end else if (cycle_count<30) begin // others
		cycle_count <= cycle_count+1;
	end
end

endmodule


