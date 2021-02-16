

set CIRCUIT s9234

set_elaborate_single_run_mode off
analyze -verilog syn_netlist.v locked_netlist.v designs/empty.v
elaborate -top empty
connect -bind $CIRCUIT orig -elaborate -auto
connect -bind ${CIRCUIT}_lbll lock -elaborate -auto

clock -none
reset -none

set tie_eq {}
set comp_eq {}

# tie/comp flops
foreach flop [get_design_info -instance lock -list flop] {
	stopat $flop
	stopat [string map {"lock" "orig"} ${flop}]
	lappend tie_eq "(${flop} == [string map {"lock" "orig"} ${flop}])"
	lappend comp_eq "([string map {"qi" "D"} ${flop}] == [string map {"qi" "D" "lock" "orig"} ${flop}])"
}

# tie/comp L0
foreach latch [get_design_info -instance lock -list latch] {
	if {[string first "_L0" $latch] == -1} {continue}
	set flop [string map {"_L0" "" "lock" "orig"} $latch]
	stopat $flop
	stopat $latch
	lappend tie_eq "($flop == $latch)"
	lappend comp_eq "([string map {"qi" "D"} ${flop}] == [string map {"qi" "D"} ${latch}])"
}

# tie inputs
foreach input [get_design_info -instance orig -list input] {
	lappend tie_eq "(lock.$input == orig.$input)"
}

# compare outputs
foreach output [get_design_info -instance orig -list output] {
	lappend comp_eq "(lock.$output == orig.$output)"
}

# assume keys
set f [open locked_netlist.key r]
set key [gets $f]
dict for {k v} $key {
	lappend tie_eq "(lock.$k==1'b$v)"
}

assume [join $tie_eq "&&"]
assume lock.clk==1'b1
assume orig.clk==1'b1
assert [join $comp_eq "&&"]

# prove
if {[prove -all] ne "proven"} {
	puts "error"
} else {exit}



