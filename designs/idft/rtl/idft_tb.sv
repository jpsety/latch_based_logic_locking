`timescale 1ns/1ps

module idft_tb ();

logic clk, rst, next, next_out_orig, next_out_lbll;
logic [15:0] X0, X1, X2, X3, Y0_orig, Y0_lbll, Y1_orig, Y1_lbll, Y2_orig, Y2_lbll, Y3_orig, Y3_lbll;
logic [NBITS-1:0] lbll_key;

idft orig (.clk, .rst, .next, .next_out(next_out_orig), .X0, .Y0(Y0_orig), .X1, .Y1(Y1_orig), .X2, .Y2(Y2_orig), .X3, .Y3(Y3_orig));
idft_MODE_NBITS_NFLOPS lbll (.clk, .rst, .next, .next_out(next_out_lbll), .X0, .Y0(Y0_lbll), .X1, .Y1(Y1_lbll), .X2, .Y2(Y2_lbll), .X3, .Y3(Y3_lbll), .lbll_key);

integer f, g, s;
always #HALF_PERIOD clk = ~clk;

initial begin
clk = 0;
rst = 0;
next = 0;
X0 = $random;
X1 = $random;
X2 = $random;
X3 = $random;


f = $fopen("syn/idft_MODE_NBITS_NFLOPS/idft_MODE_NBITS_NFLOPS_sim_equiv.log","w");
g = $fopen("syn/idft_MODE_NBITS_NFLOPS/idft_MODE_NBITS_NFLOPS.key","r");
s = $fscanf(g,"%b\n",lbll_key);

@(posedge clk)
#0.1 rst = 1;
@(posedge clk)
#0.1 rst = 0;
@(posedge clk);

repeat (30) begin
	@(posedge clk) begin
		#0.1 next = 1;
		X0 = $random;
		X1 = $random;
		X2 = $random;
		X3 = $random;
	end
	@(posedge clk)
		#0.1 next = 0;
	repeat (500) begin
		@(posedge clk);
	end
	if ({Y0_orig,Y1_orig,Y2_orig,Y3_orig,next_out_orig} !== {Y0_lbll,Y1_lbll,Y2_lbll,Y3_lbll,next_out_lbll}) begin
		$fwrite(f, "error");
		$display("gold: %b, mod: %b\n", {Y0_orig,Y1_orig,Y2_orig,Y3_orig,next_out_orig}, {Y0_lbll,Y1_lbll,Y2_lbll,Y3_lbll,next_out_lbll});
	end else begin 
		$display("PASS");
	end
end

$fclose(f);
$finish();
end

endmodule



