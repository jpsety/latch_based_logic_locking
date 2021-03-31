.SECONDARY:
.PRECIOUS:

nbits=256
nffs=15

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
	jg -sec src/lec.tcl -acquire_proj -define CIRCUIT $* \
		-proj locked/$*_lec
	#-no_gui

# sequential equivalence between locked and syn
locked/%.sec : syn/%.v locked/%.v src/sec.tcl
	jg -sec src/sec.tcl -acquire_proj -define CIRCUIT $* \
		-proj locked/$*_sec -no_gui

# simulation equivalence between locked and syn
locked/%.sim : syn/%.v locked/%.v
	xrun -top tb syn/$*.v locked/$*.v designs/$*/tb/* \
		-ALLOWREDEFINITION -debug -gui -define NBITS=$(nbits)

clean :
	rm -rf jgproject fv *.cmd *.log *.v *.key INCA_libs irun.key \
		waves.shm irun.log xcelium.d xrun.history *.diag
