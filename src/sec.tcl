# sequential equivalence script for lbll
# Joe Sweeney, CMU

# load design
clear -all
check_sec -setup \
	-spec_top $CIRCUIT \
	-spec_analyze_opts {-verilog syn/$CIRCUIT.v} \
	-imp_top ${CIRCUIT}_lbll \
	-imp_analyze_opts {-verilog locked/$CIRCUIT.v} 

check_sec -auto_map_reset_x_values on
clock clk -factor 1 -phase 1 -both_edges
reset -none

# map latches
foreach l [check_sec -list -signal -signal_type latch -imp -name .*L0.* -regexp] {
	set f [string map [list "${CIRCUIT}_lbll_imp." "" "_L0" ""] $l]
	check_sec -map -spec $f -imp $l -init
}

# map flops
foreach l [check_sec -list -signal -signal_type flop -imp] {
	set f [string map [list "${CIRCUIT}_lbll_imp." ""] $l]
	check_sec -map -spec $f -imp $l -init
}

# set key
set f [open locked/$CIRCUIT.key r]
set key [gets $f]
dict for {k v} $key {
	lappend key_eq "(${CIRCUIT}_lbll_imp.$k==1'b$v)"
}
assume [join $key_eq "&&"]

# run sec
check_sec -set_context -signal_type output -spec_delay 0 -imp_delay 0 -spec_condition_delay 0 -imp_condition_delay 0 -clock {posedge clk} -global
check_sec -generate_verification
set result [check_sec -prove -cex_threshold 1]

set fp [open locked/$CIRCUIT.sec w]
if {$result ne "proven"} {
	puts $fp "error"
} else {
	puts $fp "equiv"
}
exit

