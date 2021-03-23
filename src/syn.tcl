# simple synthesis script
# Joe Sweeney, CMU

# circuit/lib
set_db / .library designs/example.lib
read_hdl [glob "designs/$CIRCUIT/*.v"]
elaborate $CIRCUIT
ungroup -flatten -all -force

# synthesis at max freq
if {$LBLL==0} {

	# constrain 
	set init_period 0.001
	create_clock -period $init_period clk
	set_input_delay 0 -clock clk [all_inputs -no_clocks]
	set_output_delay 0 -clock clk [all_outputs]

	# synthesis
	syn_generic
	syn_map
	syn_opt

	# opt at max freq
	set period [expr $init_period - ([get_db [get_db designs $CIRCUIT] .slack]/1000)]
	create_clock -period $period clk
	syn_opt

	# output
	echo $period > syn/$CIRCUIT.period
	write_hdl -generic $CIRCUIT > syn/$CIRCUIT.v


# lock design, use prev found freq
} else {
	# constrain 
	set period [gets [open syn/$CIRCUIT.period r]]
	create_clock -period $period clk
	set_input_delay 0 -clock clk [all_inputs -no_clocks]
	set_output_delay 0 -clock clk [all_outputs]

	# syn through mapping
	syn_generic
	syn_map

	# lock
	source src/lbll.tcl
	set key [lbll $lbll_lib_example clk $nbits $nffs]	

	# opt
	syn_opt

	# output
	update_names -map [list [list $CIRCUIT ${CIRCUIT}_lbll]] -design
	echo $key > locked/$CIRCUIT.key
	write_hdl -generic ${CIRCUIT}_lbll > locked/$CIRCUIT.v

}

report_timing
report_power
report_area

exit

