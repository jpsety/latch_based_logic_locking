// a wrapper for aes that runs a test flow on chip

module des3_ctrl(clk, rst, decrypt, desIn, key1, key2, key3);

input clk, rst;
output logic decrypt;
output logic [63:0] desIn;
output logic [55:0] key1, key2, key3;
logic [63:0] lfsr_desIn;
logic [55:0] lfsr_key1, lfsr_key2, lfsr_key3;

logic [4:0] cycle_count;

LFSR lfsr [28:0] (.in({key1,key2,key3,desIn}), .out({lfsr_key1,lfsr_key2,lfsr_key3,lfsr_desIn}));

always @(posedge clk) begin
	if (rst==1) begin
		cycle_count <= 0;
		key1 <= 0;
		key2 <= 0;
		key3 <= 0;
		desIn <= 0;
		decrypt <= 0;
	end else if (cycle_count>=30) begin //go to next input
		cycle_count <= 0;
		key1 <= lfsr_key1;
		key2 <= lfsr_key2;
		key3 <= lfsr_key3;
		desIn <= lfsr_desIn;
		decrypt <= ~decrypt;
	end else if (cycle_count<30) begin // others
		cycle_count <= cycle_count+1;
	end
end

endmodule

