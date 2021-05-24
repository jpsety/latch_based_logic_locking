//************************************************************************
// Copyright 2021 Massachusetts Institute of Technology
// SPDX License Identifier: MIT
//
// File Name:       gps_mock_tss.sv
// Program:         Common Evaluation Platform (CEP)
// Description:     
// Notes:           
//************************************************************************
`timescale 1ns/1ns

module gps_lbll_tss import llki_pkg::*; (

    // Clock and Reset
    input wire            sys_clk_50,
    input wire            sync_rst_in,
    input wire            sync_rst_in_dut, // tony duong: from registers
    
    // Core I/O
    input wire [5 : 0]    sv_num,
    input wire [191 : 0]  aes_key,
    input wire [30 : 0]   pcode_speeds,
    input wire [47 : 0]   pcode_initializers,
    input wire            startRound,
    output wire [12 : 0]  ca_code,
    output wire [127 : 0]  p_code,
    output wire [127 : 0]  l_code,
    output wire           l_code_valid,

    // LLKI Discrete I/O
    input [63:0]          llkid_key_data,
    input                 llkid_key_valid,
    output reg            llkid_key_ready,
    output reg            llkid_key_complete,
    input                 llkid_clear_key,
    output reg            llkid_clear_key_ack

);

  // Internal signals & localparams
  localparam KEY_WORDS          = 4;
  reg [(64*KEY_WORDS) - 1:0]    llkid_key_register;

  //------------------------------------------------------------------
  // Instantiate the Mock TSS Finite State Machine
  //------------------------------------------------------------------
  mock_tss_fsm #(
    .KEY_WORDS            (KEY_WORDS)
  ) mock_tss_fsm_inst (
    .clk                  (sys_clk_50),
    .rst                  (sync_rst_in),
    .llkid_key_data       (llkid_key_data),
    .llkid_key_valid      (llkid_key_valid),
    .llkid_key_ready      (llkid_key_ready),
    .llkid_key_complete   (llkid_key_complete),
    .llkid_clear_key      (llkid_clear_key),
    .llkid_clear_key_ack  (llkid_clear_key_ack),
    .llkid_key_register   (llkid_key_register)
  );
  //------------------------------------------------------------------


  //------------------------------------------------------------------
  // Instantiate the original core
  //------------------------------------------------------------------
  gps_lbll gps_inst (
    .sys_clk_50         (sys_clk_50),
    .sync_rst_in        (sync_rst_in || sync_rst_in_dut),
    .sv_num             (sv_num),
    .aes_key            (aes_key),
    .pcode_speeds       (pcode_speeds),
    .pcode_initializers (pcode_initializers),
    .startRound         (startRound),
    .ca_code            (ca_code),
    .p_code             (p_code),
    .l_code             (l_code),
    .l_code_valid       (l_code_valid),
	.lbll_key			(llkid_key_register)
  );
  //------------------------------------------------------------------

endmodule

