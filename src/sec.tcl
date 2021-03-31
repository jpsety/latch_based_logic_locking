# sequential equivalence script for lbll
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

check_sec -auto_map_reset_x_values on
clock $CLK -factor 1 -phase 1 -both_edges

if {[lsearch -exact [get_design_info -list input] $RST]>-1} {
	reset $RST -formal -bound 2

	# map latches
	foreach l [check_sec -list -signal -signal_type latch -imp -name .*L0.* -regexp] {
		set f [string map [list "${CIRCUIT}_lbll_imp." "" "_L0" ""] $l]
		check_sec -map -spec [list $f] -imp [list $l] -helper -imp_condition $CLK -speculative off
	}

	# map flops
	foreach l [check_sec -list -signal -signal_type flop -imp] {
		set f [string map [list "${CIRCUIT}_lbll_imp." ""] $l]
		check_sec -map -spec [list $f] -imp [list $l] -helper -speculative off
	}

} else {
	reset -none
	# map latches
	foreach l [check_sec -list -signal -signal_type latch -imp -name .*L0.* -regexp] {
		set f [string map [list "${CIRCUIT}_lbll_imp." "" "_L0" ""] $l]
		check_sec -map -spec [list $f] -imp [list $l] -init
	}

	# map flops
	foreach l [check_sec -list -signal -signal_type flop -imp] {
		set f [string map [list "${CIRCUIT}_lbll_imp." ""] $l]
		check_sec -map -spec [list $f] -imp [list $l] -init
	}
}


# additional helper assertions
#foreach l [check_sec -list -signal -signal_type latch -imp -name .delay_decoy_*.* -regexp] {
#	set d [string map [list ".qi" ".D"] $l]
#	assert -helper "[list $d]==[list $l]"
#}
#foreach l [check_sec -list -signal -signal_type latch -imp -name .logic_decoy_*.* -regexp] {
#	assert -helper "1'b0==[list $l]"
#}


# set key
set f [open locked/$CIRCUIT.key r]
set key [gets $f]
assume ${CIRCUIT}_lbll_imp.lbll_key==$key
assume ${CIRCUIT}_lbll_imp.lbll_key==$key -reset
#dict for {k v} $key {
#	lappend key_eq "(${CIRCUIT}_lbll_imp.$k==1'b$v)"
#}
#assume [join $key_eq "&&"]
#assume [join $key_eq "&&"] -reset

# run sec
check_sec -set_context -signal_type output -spec_delay 0 -imp_delay 0 -spec_condition_delay 0 -imp_condition_delay 0 -clock [list posedge $CLK] -global
check_sec -generate_verification
set result [check_sec -prove -cex_threshold 1]

set fp [open locked/$CIRCUIT.sec w]
puts $fp $result
close $fp
exit

