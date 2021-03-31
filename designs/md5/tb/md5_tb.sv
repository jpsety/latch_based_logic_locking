`timescale 1ns/1ps

module md5_tb ();

logic clk, rst, msg_in_valid, ready_orig, ready_lbll, msg_out_valid_orig, msg_out_valid_lbll;
logic [511:0] msg_padded;
logic [127:0] msg_output_orig, msg_output_lbll;
logic [NBITS-1:0] lbll_MODE_key;

md5 orig (.clk, .rst, .msg_padded, .msg_in_valid, .msg_output(msg_output_orig), .msg_out_valid(msg_out_valid_orig), .ready(ready_orig));
md5_MODE_NBITS lbll (.clk, .rst, .msg_padded, .msg_in_valid, .msg_output(msg_output_lbll), .msg_out_valid(msg_out_valid_lbll), .ready(ready_lbll), .lbll_MODE_key);

integer f, g, s;
always #10 clk = ~clk;

initial begin
clk = 0;
msg_padded = {$random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random};
msg_in_valid = 0;
rst = 0;

f = $fopen("syn/md5_MODE_NBITS/md5_MODE_NBITS_sim_equiv.log","w");
g = $fopen("syn/md5_MODE_NBITS/md5_MODE_NBITS.key","r");
s = $fscanf(g,"%b\n",lbll_MODE_key);

@(posedge clk)
#0.1 rst = 1;
@(posedge clk)
#0.1 rst = 0;
@(posedge clk);

repeat (30) begin
	@(posedge clk)
		#0.1 msg_in_valid = 0;
	@(posedge clk) begin
		#0.1 msg_in_valid = 1;
		msg_padded = {$random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random, $random};
	end
	repeat (50) begin
		@(posedge clk);
	end
	if ({msg_output_orig,msg_out_valid_orig,ready_orig} !== {msg_output_lbll,msg_out_valid_lbll,ready_lbll}) begin
		$fwrite(f, "error");
		$display("gold: %b, mod: %b\n", {msg_output_orig,msg_out_valid_orig,ready_orig}, {msg_output_lbll,msg_out_valid_lbll,ready_lbll});
	end else begin 
		$display("PASS");
	end
end

$fclose(f);
$finish();
end

endmodule

