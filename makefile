
# run
syn_netlist.v : syn.tcl 
	genus -files syn.tcl -log syn.log -overwrite -no_gui

locked_netlist.v : lbll.tcl syn_netlist.v
	genus -files lbll.tcl -log lbll.log -overwrite -no_gui

equiv : syn_netlist.v locked_netlist.v jg.tcl
	jg -fpv jg.tcl -acquire_proj -no_gui
