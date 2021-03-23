
module adder(
	input clk,
	input [5:0] a_in,
	input [5:0] b_in,
	output logic [5:0] y_out
);

logic [5:0] a, b, c, y;
always @(posedge clk) begin
	a <= a_in;
	b <= b_in;
	c <= a+b;
	y <= c+b;
end
assign y_out = y;

endmodule
