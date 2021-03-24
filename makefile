.SECONDARY:
.PRECIOUS:

nbits=64
nffs=5

# synthesis at max freq
syn/%.v : src/syn.tcl 
	genus -files src/syn.tcl -log syn/$*.log -overwrite -no_gui \
		-execute "set LBLL 0; set CIRCUIT $*"

# locking
locked/%.v : src/syn.tcl src/lbll.tcl syn/%.v
	genus -files src/syn.tcl -log locked/$*.log -overwrite -no_gui \
		-execute "set LBLL 1; set CIRCUIT $*; set nbits $(nbits); set nffs $(nffs)"

# logic equivalence between locked and syn
locked/%.lec : syn/%.v locked/%.v src/lec.tcl
	jg -fpv src/lec.tcl -acquire_proj -no_gui -define CIRCUIT $* \
		-proj locked/$*_lec

# sequential equivalence between locked and syn
locked/%.sec : syn/%.v locked/%.v src/sec.tcl
	jg -sec src/sec.tcl -acquire_proj -no_gui -define CIRCUIT $* \
		-proj locked/$*_sec

# gps sim
sim_gps :
	xrun -top tb generic_gps/tb.sv generic_gps/gps.v generic_gps/gps_lbll.v -ALLOWREDEFINITION -debug -gui

clean :
	rm -rf jgproject fv *.cmd *.log *.v *.key INCA_libs irun.key waves.shm irun.log
