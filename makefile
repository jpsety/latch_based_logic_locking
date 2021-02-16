
# run
syn_netlist.v : syn.tcl 
	genus -files syn.tcl -log syn.log -overwrite -no_gui -execute "set LBLL 0"

locked_netlist.v : syn.tcl lbll.tcl
	genus -files syn.tcl -log lbll.log -overwrite -no_gui -execute "set LBLL 1"

equiv : syn_netlist.v locked_netlist.v jg.tcl
	jg -fpv jg.tcl -acquire_proj -no_gui

clean :
	rm -rf jgproject fv *.cmd *.log *.v *.key
