`timescale 1ns/1ps

module aes_tb ();

logic clk, rst, ld;
logic [127:0] key, text_in;
logic [127:0] text_out_orig, text_out_lbll;
logic done_orig, done_lbll;
logic [NBITS-1:0] lbll_MODE_key;

aes orig (.clk, .rst, .ld, .done(done_orig), .key, .text_in, .text_out(text_out_orig));
aes_MODE_NBITS lbll (.clk, .rst, .ld, .done(done_lbll), .key, .text_in, .text_out(text_out_lbll), .lbll_MODE_key);

integer f, g, s;
always #10 clk = ~clk;

initial begin
clk = 0;
key = {$random,$random,$random,$random};
text_in = {$random,$random,$random,$random};
ld = 0;
rst = 0;

f = $fopen("syn/aes_MODE_NBITS/aes_MODE_NBITS_sim_equiv.log","w");
g = $fopen("syn/aes_MODE_NBITS/aes_MODE_NBITS.key","r");
s = $fscanf(g,"%b\n",lbll_MODE_key);

@(posedge clk)
#0.1 rst = 1;
@(posedge clk)
#0.1 rst = 0;
@(posedge clk);
@(posedge clk)
#0.1 rst = 1;
@(posedge clk)
#0.1 rst = 0;
@(posedge clk);

repeat (30) begin
	@(posedge clk) begin
		#0.1 ld = 1;
		key = {$random,$random,$random,$random};
		text_in = {$random,$random,$random,$random};
	end
	@(posedge clk)
	#0.1 ld = 0;
	repeat (50) begin
		@(posedge clk);
	end
	if ({done_orig,text_out_orig} !== {done_lbll,text_out_lbll}) begin
		$fwrite(f, "error");
		$display("gold: %b, mod: %b\n", text_out_orig, text_out_lbll);
	end else begin 
		$display("PASS");
	end
end

$fclose(f);
$finish();
end

endmodule

