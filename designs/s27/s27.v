//# 4 inputs
//# 1 outputs
//# 3 D-type flipflops
//# 2 inverters
//# 8 gates (1 ANDs + 1 NANDs + 2 ORs + 4 NORs)


module DFFQ (CK,Q,D);
input CK,D;
output Q;
reg Q;
always @(posedge CK) Q <= D;
endmodule

module s27(clk,rst,G0,G1,G17,G2,G3);
input clk,G0,G1,G2,G3,rst;
output G17;

  wire G5,G10,G6,G11,G7,G13,G14,G8,G15,G12,G16,G9,ff_in_0,ff_in_1,ff_in_2;

  DFFQ DFF_0(.CK(clk),.Q(G5),.D(ff_in_0));
  DFFQ DFF_1(.CK(clk),.Q(G6),.D(ff_in_1));
  DFFQ DFF_2(.CK(clk),.Q(G7),.D(ff_in_2));
  not NOT_r(rst_b,rst);
  and AND2_r0(ff_in_0,rst_b,G10);
  and AND2_r1(ff_in_1,rst_b,G11);
  and AND2_r2(ff_in_2,rst_b,G13);
  not NOT_0(G14,G0);
  not NOT_1(G17,G11);
  and AND2_0(G8,G14,G6);
  or OR2_0(G15,G12,G8);
  or OR2_1(G16,G3,G8);
  nand NAND2_0(G9,G16,G15);
  nor NOR2_0(G10,G14,G11);
  nor NOR2_1(G11,G5,G9);
  nor NOR2_2(G12,G1,G7);
  nor NOR2_3(G13,G2,G12);

endmodule
