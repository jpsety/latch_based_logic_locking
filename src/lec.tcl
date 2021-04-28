# logical equivalence script for lbll
# Joe Sweeney, CMU

# load design
source designs/$CIRCUIT/vars.tcl
clear -all
check_sec -setup \
	-spec_top $CIRCUIT \
	-spec_analyze_opts {-verilog syn/$CIRCUIT.v} \
	-spec_elaborate_opts {-bbox 1} \
	-imp_top ${CIRCUIT}_lbll \
	-imp_analyze_opts {-verilog locked/$CIRCUIT.v} \
	-imp_elaborate_opts {-bbox 1}

#clock $CLK -factor 1 -phase 1 -both_edges
clock -none
reset -none

# tie/comp flops
foreach l [check_sec -list -signal -signal_type flop -imp] {
	set f [string map [list "${CIRCUIT}_lbll_imp." ""] $l]
	stopat [list $l]
	stopat [list $f]
	assume "([list $f] == [list $l])"
	assert "([string map {"qi" "D"} [list $f]] == [string map {"qi" "D"} [list $l]])"
}

# tie/comp L0
foreach l [check_sec -list -signal -signal_type latch -imp -name .*L0.* -regexp] {
	set f [string map [list "${CIRCUIT}_lbll_imp." "" "_L0" ""] $l]
	stopat [list $l]
	stopat [list $f]
	assume "([list $f] == [list $l])"
	assert "([string map {"qi" "D"} [list $f]] == [string map {"qi" "D"} [list $l]])"
}

# tie inputs
foreach l [concat [get_design_info -list input] [get_design_info -list bbox_out]] {
	set f "${CIRCUIT}_lbll_imp.$l"
	assume "([list $f] == [list $l])"
}

# compare outputs
foreach l [concat [get_design_info -list output] [get_design_info -list bbox_in]] {
	set f "${CIRCUIT}_lbll_imp.$l"
	assert "([list $f] == [list $l])"
}

assume $CLK==1'b1

# set key
set f [open locked/$CIRCUIT.key r]
set key [gets $f]
if {[llength $key]>0} {
	assume ${CIRCUIT}_lbll_imp.lbll_key==$key
}

check_sec -generate_verification
set result [prove -all]
set fp [open locked/$CIRCUIT.lec w]
puts $fp $result
close $fp
exit

