
# simple synthesis script
set_db / .library $::env(GENUS_DIR)/../share/synth/tutorials/tech/tutorial.lib
set CIRCUIT s9234
read_hdl -v $CIRCUIT.v
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
syn_opt

write_hdl -generic $CIRCUIT > syn_netlist.v
exit

