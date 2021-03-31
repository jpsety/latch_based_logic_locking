
`timescale 1ns/1ps

module des3_tb ();

logic [63:0] desOut_orig;
logic [63:0] desOut_lbll;
logic out_valid_orig;
logic out_valid_lbll;
logic [63:0] desIn;
logic [55:0] key1,key2,key3;
logic decrypt, clk, rst;
logic [NBITS-1:0] lbll_MODE_key;

des3 orig (.desOut(desOut_orig), .out_valid(out_valid_orig), .rst, .desIn, .key1, .key2, .key3, .decrypt, .clk);
des3_MODE_NBITS lbll (.desOut(desOut_lbll), .out_valid(out_valid_lbll), .rst, .desIn, .key1, .key2, .key3, .decrypt, .clk, .lbll_MODE_key);

integer f, g, s;
always #10 clk = ~clk;

initial begin
clk = 0;
key1 = {$random, $random};
key2 = {$random, $random};
key3 = {$random, $random};
desIn = {$random, $random};
rst=0;
decrypt=0;

f = $fopen("syn/des3_MODE_NBITS/des3_MODE_NBITS_sim_equiv.log","w");
g = $fopen("syn/des3_MODE_NBITS/des3_MODE_NBITS.key","r");
s = $fscanf(g,"%b\n",lbll_MODE_key);

@(posedge clk)
#0.1 rst = 1;
@(posedge clk)
#0.1 rst = 0;
@(posedge clk);

repeat (30) begin

	@(posedge clk) begin
		#0.1 decrypt=~decrypt;
		key1 = {$random, $random};
		key2 = {$random, $random};
		key3 = {$random, $random};
		desIn = {$random, $random};
	end

	repeat (50) begin
		@(posedge clk);
	end

	if ({out_valid_orig,desOut_orig} !== {out_valid_lbll,desOut_lbll}) begin
		$fwrite(f, "error");
		$display("gold: %b, mod: %b\n", desOut_orig, desOut_lbll);
	end else begin 
		$display("PASS");
	end

end

$fclose(f);
$finish();

end

endmodule

