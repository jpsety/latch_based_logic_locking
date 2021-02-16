
# simple synthesis script
set_db / .library designs/example.lib
set CIRCUIT s9234
read_hdl designs/$CIRCUIT.v
elaborate $CIRCUIT
ungroup -flatten -all -force

# constrain 
set period 2.5
create_clock -period $period clk
set_input_delay 0 -clock clk [all_inputs -no_clocks]
set_output_delay 0 -clock clk [all_outputs]

# synthesis
syn_generic
syn_map
if {$LBLL} {
	source lbll.tcl
	set key [lbll $lbll_lib_example 64 5]	
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

