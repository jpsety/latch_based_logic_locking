
# simple synthesis script
set_db / .library designs/example.lib
set CIRCUIT gps
set CLK sys_clk_50
read_hdl "designs/cacode.v designs/gps.v designs/pcode.v designs/aes_192.v designs/table.v designs/round.v"
elaborate $CIRCUIT
ungroup -flatten -all -force

# constrain 
set period 2.5
create_clock -period $period $CLK
set_input_delay 0 -clock $CLK [all_inputs -no_clocks]
set_output_delay 0 -clock $CLK [all_outputs]

# synthesis
syn_generic
syn_map
if {$LBLL} {
	source lbll.tcl
	set key [lbll $lbll_lib_example $CLK 64 5]	
	update_names -map [list [list $CIRCUIT ${CIRCUIT}_lbll]] -design
	echo $key > locked_netlist.key
}

syn_opt

if {$LBLL} {
	write_hdl -generic ${CIRCUIT}_lbll > locked_netlist.v
} else {
	write_hdl -generic $CIRCUIT > syn_netlist.v
}

report_timing
report_power
report_area

exit

