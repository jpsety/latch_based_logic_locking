
module aes(clk, rst, ld, done, key, text_in, text_out);

input clk, rst, ld;
input [127:0] key, text_in;
output logic [127:0] text_out;
output logic done;

aes_cipher_top dut (clk, ~rst, ld, done, key, text_in, text_out);

endmodule
