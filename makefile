.SECONDARY:
.PRECIOUS:

nbits=64
nffs=5

# synthesis at max freq
syn/%.v : syn.tcl 
	genus -files syn.tcl -log syn/$*.log -overwrite -no_gui \
		-execute "set LBLL 0; set CIRCUIT $*"

# locking
locked/%.v : syn.tcl lbll.tcl syn/%.v
	genus -files syn.tcl -log locked/$*.log -overwrite -no_gui \
		-execute "set LBLL 1; set CIRCUIT $*; set nbits $(nbits); set nffs $(nffs)"

# equivalence between locked and syn
locked/%.equiv : syn/%.v locked/%.v jg.tcl
	jg -fpv jg.tcl -acquire_proj -no_gui -define CIRCUIT $* \
		-proj locked/$*_equiv

clean :
	rm -rf jgproject fv *.cmd *.log *.v *.key
