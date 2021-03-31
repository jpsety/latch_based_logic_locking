# simple synthesis script
# Joe Sweeney, CMU

# circuit/lib
set_db / .library src/example.lib
read_hdl -sv [glob "designs/$CIRCUIT/rtl/*"]
elaborate $CIRCUIT
source designs/$CIRCUIT/vars.tcl
ungroup -flatten -all -force

# synthesis at max freq
if {$LBLL==0} {

	# constrain 
	set init_period 0.001
	create_clock -period $init_period $CLK
	set_input_delay 0 -clock $CLK [all_inputs -no_clocks]
	set_output_delay 0 -clock $CLK [all_outputs]

	# synthesis
	syn_generic
	syn_map
	syn_opt

	# opt at max freq
	set period [expr $init_period - ([get_db [get_db designs $CIRCUIT] .slack]/1000)]
	create_clock -period $period $CLK
	syn_opt

	# output
	echo $period > syn/$CIRCUIT.period
	write_hdl -generic $CIRCUIT > syn/$CIRCUIT.v


# lock design, use prev found freq
} else {
	# constrain 
	set period [gets [open syn/$CIRCUIT.period r]]
	create_clock -period $period $CLK
	set_input_delay 0 -clock $CLK [all_inputs -no_clocks]
	set_output_delay 0 -clock $CLK [all_outputs]

	# syn through mapping
	syn_generic
	syn_map

	# lock
	source src/lbll.tcl
	set result [lbll $lbll_lib_example $CLK $nbits $nffs]	
	set key [lindex $result 0]
	set sdc [lindex $result 1]

	# opt
	syn_opt

	# output
	update_names -map [list [list $CIRCUIT ${CIRCUIT}_lbll]] -design
	echo $sdc > locked/$CIRCUIT.sdc
	echo $key > locked/$CIRCUIT.key
	write_hdl -generic ${CIRCUIT}_lbll > locked/$CIRCUIT.v

}

report_timing
report_power
report_area

exit

