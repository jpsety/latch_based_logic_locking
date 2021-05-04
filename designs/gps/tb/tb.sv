
module tb;

	logic sys_clk_50, sync_rst_in, startRound;
	logic [5:0] sv_num;
	logic [191:0] aes_key;
	logic [30:0] pcode_speeds;
	logic [47:0] pcode_initializers;

	logic [12:0] ca_code;
	logic [127:0] p_code, l_code;
	logic l_code_valid;

	logic [12:0] dut_ca_code;
	logic [127:0] dut_p_code, dut_l_code;
	logic dut_l_code_valid;

	logic [`NBITS-1:0] lbll_key;
	logic reset;

	gps gold (sys_clk_50, sync_rst_in, sv_num, startRound, aes_key, pcode_speeds, pcode_initializers,
			   ca_code, p_code, l_code, l_code_valid);

	gps_lbll dut (sys_clk_50, sync_rst_in, sv_num, startRound, aes_key, pcode_speeds,pcode_initializers,
				   dut_ca_code, dut_p_code, dut_l_code, dut_l_code_valid, lbll_key);

	integer f;
	string key;

	always #500 sys_clk_50 = !sys_clk_50;

	initial begin
		f = $fopen("locked/gps.key","r");
		$fscanf(f, "256'b%b",lbll_key);
		
		reset = 0;
		sys_clk_50 = 0;
		sync_rst_in = 0;
		sv_num = 0;
		aes_key = 0;
		pcode_speeds = 0;
		pcode_initializers = 0;
		startRound = 0;

		#1100
		sync_rst_in = 1;

		#3000
		sync_rst_in = 0;
		reset = 1;

		repeat(100) begin
			#10000
	//		sync_rst_in = $random;
			sv_num = $random;
			startRound = $random;
		end

		#1000
		reset = 0;
		std::randomize(lbll_key);
		//lbll_key = {$random,$random,$random,$random,$random,$random,$random,$random};

		repeat(100) begin
			#10000
			sv_num = $random;
			startRound = $random;
		end

		$finish;

	end

	assert property (@(posedge sys_clk_50) reset |-> p_code==dut_p_code);
	assert property (@(posedge sys_clk_50) reset |-> l_code==dut_l_code);
	assert property (@(posedge sys_clk_50) reset |-> l_code_valid==dut_l_code_valid);
	assert property (@(posedge sys_clk_50) reset |-> ca_code==dut_ca_code);

endmodule

