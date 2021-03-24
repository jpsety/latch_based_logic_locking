
module tb;

logic clk, sync_rst_in, startRound;
logic [5:0] sv_num;

logic [12:0] ca_code;
logic [127:0] p_code, l_code;
logic l_code_valid;

logic [12:0] dut_ca_code;
logic [127:0] dut_p_code, dut_l_code;
logic dut_l_code_valid;

logic [255:0] lbll_key;
logic reset;

gps gold (clk, sync_rst_in, sv_num, startRound, ca_code,
     p_code, l_code, l_code_valid);

gps_lbll dut (clk, sync_rst_in, sv_num, startRound, dut_ca_code,
     dut_p_code, dut_l_code, dut_l_code_valid, lbll_key);


always #5 clk = !clk;

initial begin
	lbll_key = 256'b1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110101010000000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010101010101010101010101010101010101010101010101010101010101010101;
	reset = 0;
	clk = 0;
	sync_rst_in = 0;
	sv_num = 0;
	startRound = 0;

	#11
	sync_rst_in = 1;

	#30
	sync_rst_in = 0;
	reset = 1;

	repeat(100) begin
		#100
//		sync_rst_in = $random;
		sv_num = $random;
		startRound = $random;
	end

	$finish;

end

assert property (@(posedge clk) reset |-> p_code==dut_p_code);
assert property (@(posedge clk) reset |-> l_code==dut_l_code);
assert property (@(posedge clk) reset |-> l_code_valid==dut_l_code_valid);
assert property (@(posedge clk) reset |-> ca_code==dut_ca_code);

endmodule

