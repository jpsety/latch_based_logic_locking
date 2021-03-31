`timescale 1ns/1ps

module adder_tb();

logic clk;
logic [5:0] a_in, b_in, y_out_orig, y_out_lbll;
logic [NBITS-1:0] lbll_key;

adder_NBITS_DEGREE lbll (clk, a_in, b_in, y_out_lbll, lbll_key);
adder orig (clk, a_in, b_in, y_out_orig);

integer f, g, s;
always #50 clk = ~clk;

initial begin

	f = $fopen("log/adder/sim_equiv_adder_NBITS_DEGREE.log","w");
	g = $fopen("netlist/adder/lbll_adder_NBITS_DEGREE.key","r");
	s = $fscanf(g,"%b\n",lbll_key);

	clk = 0;
	a_in = $random;
	b_in = $random;
	#56

	repeat (30) begin
		a_in = $random;
		b_in = $random;
		#100
		if (y_out_orig !== y_out_lbll) begin
			$fwrite(f, "error");
			$display("gold: %b, mod: %b\n", y_out_orig, y_out_lbll);
		end else begin 
			$display("daf");
		end
	end
	$finish();

end

endmodule

