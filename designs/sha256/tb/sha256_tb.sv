
`timescale 1ns/1ps

module sha256_tb ();

logic clk, rst, init, next;
logic [511:0] block;
logic [127:0] digest_orig, digest_lbll;
logic ready_orig, ready_lbll, digest_valid_orig, digest_valid_lbll;
logic [NBITS-1:0] lbll_key;

sha256 orig (clk, rst, init, next, block, ready_orig, digest_orig, digest_valid_orig);
sha256_MODE_NBITS_NFLOPS lbll (clk, rst, init, next, block, ready_lbll, digest_lbll, digest_valid_lbll, lbll_key);

integer f, g, s;
always #HALF_PERIOD clk = ~clk;

initial begin
clk = 0;
rst = 0;
init = 0;
next = 0;
block = {$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random};

f = $fopen("syn/sha256_MODE_NBITS_NFLOPS/sha256_MODE_NBITS_NFLOPS_sim_equiv.log","w");
g = $fopen("syn/sha256_MODE_NBITS_NFLOPS/sha256_MODE_NBITS_NFLOPS.key","r");
s = $fscanf(g,"%b\n",lbll_key);

@(negedge clk)
rst = 1;
@(negedge clk)
rst = 0;
@(negedge clk);

repeat (30) begin
	@(negedge clk) begin
		init = 1;
		next = 0;
		block = {$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random,$random};
	end
	repeat (50) begin
		@(negedge clk);
	end
	@(negedge clk) begin
		init = 0;
		next = 1;
	end
	repeat (50) begin
		@(negedge clk);
	end
	if (digest_orig !== digest_lbll) begin
		$fwrite(f, "error");
		$display("gold: %b, mod: %b\n", digest_orig, digest_lbll);
	end else begin 
		$display("PASS");
	end
end

$fclose(f);
$finish();
end

endmodule

