`timescale 1ns/1ps

module fir_tb ();

logic clk, rst;
logic [31:0] inData, outData_orig, outData_lbll;
logic [NBITS-1:0] lbll_MODE_key;

fir orig (.inData, .clk, .outData(outData_orig), .rst);
fir_MODE_NBITS lbll (.inData, .clk, .outData(outData_lbll), .rst, .lbll_MODE_key);

integer f, g, s;
always #10 clk = ~clk;

initial begin
clk = 0;
inData = {$random};
rst = 0;

f = $fopen("syn/fir_MODE_NBITS/fir_MODE_NBITS_sim_equiv.log","w");
g = $fopen("syn/fir_MODE_NBITS/fir_MODE_NBITS.key","r");
s = $fscanf(g,"%b\n",lbll_MODE_key);

@(posedge clk)
#0.1 rst = 1;
@(posedge clk)
#0.1 rst = 0;
@(posedge clk);

repeat (30) begin
	@(posedge clk) begin
		#0.1 inData = {$random};
	end
	repeat (50) begin
		@(posedge clk);
	end
	if (outData_orig !== outData_lbll) begin
		$fwrite(f, "error");
		$display("gold: %b, mod: %b\n", outData_orig, outData_lbll);
	end else begin 
		$display("PASS");
	end
end

$fclose(f);
$finish();
end

endmodule

