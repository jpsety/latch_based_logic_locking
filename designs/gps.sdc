set clkp 5000
set clk_max_tran  50
set data_max_tran 75
set_case_analysis 0 [get_ports test_mode]
set_case_analysis 0 [get_ports scan_enable]
create_clock -name clk  -period $clkp -waveform "0 [expr ${clkp}/2]" [get_ports {sys_clk_50}] 
create_clock -name vclk -period $clkp -waveform "0 [expr ${clkp}/2]"


set_clock_uncertainty -setup [expr 0.1*$clkp] [all_clocks]
set_clock_uncertainty -hold   15 [all_clocks]

# ------------------------- IO Timings ---------------------
set clk_ipct 0.6
set clk_opct 0.6

set_input_delay  [expr ${clkp}*${clk_ipct}] -clock [get_clocks vclk] [all_inputs -no_clocks]
set_output_delay [expr ${clkp}*${clk_opct}] -clock [get_clocks vclk] [all_outputs]

# ------------------------- misc----------------------------
set load 50
set_load $load [all_outputs]

set_max_transition -clock_path ${clk_max_tran}  [all_clocks]
set_max_transition -data_path  ${data_max_tran} [all_clocks]
set_input_transition ${data_max_tran} [all_inputs -no_clocks]

# ------------------------- Exceptions --------------------
