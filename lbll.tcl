
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

proc con_check {} {
	foreach p [get_db pins] {
		if {[get_db $p .constant] eq "no_constant"} {
			if {[get_db $p .net] eq ""} {
				echo "unconnected pin $p"
				suspend
			}
		}
	}
}

##################### lbll #####################
# args
set nffs 10
set nlogic 3
set ndelay 3
set max_fio 3

# lib args
set lat_type "latchdrs"
set lat_d "D"
set lat_q "Q"
set lat_clk "ENA"
set lat_r "R"
set lat_s "S"

set ff_type "fflopd"
set ff_d "D"
set ff_q "Q"
set ff_clk "CK"

set inv_type "inv1"
set inv_i "A"
set inv_o "Y"

set xor_type "xor2"
set xor_i0 "A"
set xor_i1 "B"
set xor_o "Y"

set nand_type "nand2"
set nand_i0 "A"
set nand_i1 "B"
set nand_o "Y"

set nor_type "nor2"
set nor_i0 "A"
set nor_i1 "B"
set nor_o "Y"

#### select flops
set largest_cone_size 0
set selected_ffs {}
foreach inst [get_db insts] {
	# pass if inputs
	set start_points [get_db [all_fanin -to [get_db $inst .pins -if .direction==in] -startpoints_only]]
	if {[llength [get_db $start_points -if .obj_type==port]]>0} {continue}

	# pass if flops > nflops
	set start_ffs [get_db [all_fanin -to [get_db $inst .pins -if .direction==in] -startpoints_only -only_cells]]
	if {[llength $start_ffs]>$nffs} {continue}

	# record cone size
	set cone_size [llength [get_db [all_fanin -to [get_db $inst .pins -if .direction==in] -only_cells]]]
	if {$cone_size>$largest_cone_size} {
		set largest_cone_size $cone_size
		set selected_ffs $start_ffs
	}
}

## retime ffs
# duplicate ffs
foreach ff $selected_ffs {
	echo "Duplicating: ${ff}"

	#names
	set ff_name_0 [get_db $ff .name]
	append ff_name_0 "_F0"
	set ff_name_1 [get_db $ff .name]
	append ff_name_1 "_F1"

	#create second ff
	set ff_0 $ff
	set ff_1 [create_inst $ff_type -name $ff_name_1 $CIRCUIT]

	#connect second ff
	set clk_ff_0 [get_db $ff_0 .pins -if .base_name==$ff_clk]
	set clk_ff_1 [get_db $ff_1 .pins -if .base_name==$ff_clk]
	set q_ff_0 [get_db $ff_0 .pins -if .base_name==$ff_q]
	set q_ff_1 [get_db $ff_1 .pins -if .base_name==$ff_q]
	set d_ff_1 [get_db $ff_1 .pins -if .base_name==$ff_d]
	set net [get_db $q_ff_0 .net]
	set net_load [lindex [get_db $net .loads] 0]
	disconnect $q_ff_0
	connect $q_ff_0 $d_ff_1 
	connect $q_ff_1 $net_load
	connect $clk_ff_1 $clk_ff_0
	rename_obj $ff_0 $ff_name_0
}

# retime F1 ffs
set retime_period [expr $period/2]
create_clock -period $retime_period clk

set_db [get_db design:$CIRCUIT] .retime true
::legacy::set_attribute retime_reg_naming_suffix _retimed_reg_F1 /
set_db [get_db insts] .dont_retime true -quiet
set_db [get_db insts *_F1] .dont_retime false 

retime -min_delay
create_clock -period $period clk

# delete state points
set_db [get_db hinsts *state_point] .preserve false
foreach sp [get_db hinsts *state_point] {
	set dr [lindex [get_db [get_db $sp .hpins -if .base_name==in] .drivers] 0]
	set ld [lindex [get_db [get_db $sp .hpins -if .base_name==out] .loads] 0]
	delete_obj $sp
	connect $dr $ld
}

## switch to latches
set key [dict create]
set i 0
set retimed_ffs [concat [get_db insts *_F1*] [get_db insts *_F0*]]
foreach ff $retimed_ffs {
	echo "replacing: [get_db $ff .base_cell.name] with $lat_type"

	# create instances
	if {[string first "_F0" $ff] != -1} {
		set lat_name [string map {"_F0" "_L0"} [get_db $ff .base_name]] 
	} else {
		set lat_name orig_lat_L1_$i
	}
	set lat [create_inst $lat_type -name $lat_name $CIRCUIT]
	set xor [create_inst $xor_type -name "lbll_xor_$i" $CIRCUIT]
	set nand [create_inst $nand_type -name "lbll_nand_$i" $CIRCUIT]
	set nor [create_inst $nor_type -name "lbll_nor_$i" $CIRCUIT]
	set inv [create_inst $inv_type -name "lbll_inv_$i" $CIRCUIT]

	# create key ports
	set key0 [get_db [create_port_bus -input -name lbll_key_$i] .bits]
	set key1 [get_db [create_port_bus -input -name lbll_key_[expr $i+1]] .bits]

	# connect latch
	connect [get_db $lat .pins -if .base_name==$lat_q] [get_db $ff .pins -if .base_name==$ff_q]
	connect [get_db $lat .pins -if .base_name==$lat_d] [get_db $ff .pins -if .base_name==$ff_d]
	connect [get_db $lat .pins -if .base_name==$lat_s] 1
	connect [get_db $xor .pins -if .base_name==$xor_i0] [get_db $ff .pins -if .base_name==$ff_clk]
	connect [get_db $xor .pins -if .base_name==$xor_i1] $key1
	connect [get_db $xor .pins -if .base_name==$xor_o] [get_db $nand .pins -if .base_name==$nand_i0]
	connect [get_db $lat .pins -if .base_name==$lat_clk] [get_db $nand .pins -if .base_name==$nand_o]
	connect [get_db $nand .pins -if .base_name==$nand_i1] $key0
	connect [get_db $nor .pins -if .base_name==$nor_i0] $key0
	connect [get_db $nor .pins -if .base_name==$nor_i1] $key1
	connect [get_db $nor .pins -if .base_name==$nor_o] [get_db $inv .pins -if .base_name==$inv_i]
	connect [get_db $lat .pins -if .base_name==$lat_r] [get_db $inv .pins -if .base_name==$inv_o]
	delete_obj $ff

	# set the appropriate key bit based on latch order
	if {[string first "L0" $lat_name]!=-1} {
		set_case_analysis 1 $key0
		set_case_analysis 0 $key1
		dict set key [get_db $key0 .base_name] 1
		dict set key [get_db $key1 .base_name] 0
	} else {
		set_case_analysis 1 $key0
		set_case_analysis 1 $key1
		dict set key [get_db $key0 .base_name] 1
		dict set key [get_db $key1 .base_name] 1
	}
	incr i 2
	con_check
}

#### insert logic decoys
# helper funcs
proc linter {la lb} {
	set len 0
	foreach a $la {
		if {[lsearch -exact $lb $a]>-1} {incr len}
	}
	return $len
}

for {set di 0} {$di<$nlogic} {incr di} {
	set lats [get_db insts -if .is_latch]

	# select number of fanin/out for logic decoy latch
	set nfo [expr int(ceil($max_fio*rand()))]
	set nfi [expr int(ceil($max_fio*rand()))]

	# get locked subcircuit start/endpoints
	set lat_ds [get_db $lats .pins -if .base_name==$lat_d]
	set locked_sp [concat [get_db [all_fanin -to $lat_ds -startpoints_only] -if .base_name!=$lat_clk&&.base_name!=$ff_clk] $lat_ds]
	set locked_ep [concat [get_db [all_fanout -from $lat_ds -endpoints_only]] $lat_ds]

	# calculate the number of endpoints per startpoint
	set len_ep {}
	foreach sp $locked_sp {
		set eps [get_db [all_fanout -from $sp -endpoints_only]]
		lappend len_ep [linter $eps $locked_ep]
	}	

	# get the startpoints w/ lowest endpoint count
	set decoy_sp {}
	foreach spi [lrange [lsort -indices -integer $len_ep] 0 $nfi] {
		lappend decoy_sp [lindex $locked_sp $spi]
	}

	# calculate the number of startpoints per endpoint
	set len_sp {}
	foreach ep $locked_ep {
		set sps [get_db [all_fanin -to $ep -startpoints_only] -if .base_name!=$lat_clk&&.base_name!=$ff_clk]
		lappend len_sp [linter $sps $locked_sp]
	}	

	# get the endpoints w/ lowest startpoint count
	set decoy_ep {}
	foreach epi [lrange [lsort -indices -integer $len_sp] 0 $nfo-1] {
		lappend decoy_ep [lindex $locked_ep $epi]
	}

	# build random truth table
	set tt {}
	for {set tti 0} {$tti<[expr 2**$nfi]} {incr tti} {
		lappend tt [expr rand()>0.5]
	}

	# ensure not constant
	if {[lsearch -exact $tt 0] < 0} {
		lset tt [expr int(rand()*[llength $tt])] 0
	} elseif {[lsearch -exact $tt 1] < 0} {
		lset tt [expr int(rand()*[llength $tt])] 1
	}

	# connect to mux
	set nmuxin [expr $nfi + 2**$nfi] 
	set mux [create_primitive -function bmux -inside $CIRCUIT -inputs $nmuxin]
	set mux_name [get_db $mux .base_name]
	for {set tti 0} {$tti<[expr 2**$nfi]} {incr tti} {
		connect [lindex $tt $tti] $mux_name/data$tti
	}
	for {set spi 0} {$spi<$nfi} {incr spi} {
		set sp [lindex $decoy_sp $spi]
		if {[get_db $sp .obj_type] eq "pin"} {
			set driver [get_db $sp .inst.pins -if .base_name==$lat_q||.base_name==$ff_q]
		} else {
			set driver $sp
		}
		connect $driver $mux_name/sel$spi
	}

	# add latch
	set i [expr 2*[llength $lats]]
	set lat [create_inst $lat_type -name logic_decoy_lat_$i $CIRCUIT]
	set xor [create_inst $xor_type -name "lbll_xor_$i" $CIRCUIT]
	set nand [create_inst $nand_type -name "lbll_nand_$i" $CIRCUIT]
	set nor [create_inst $nor_type -name "lbll_nor_$i" $CIRCUIT]
	set inv [create_inst $inv_type -name "lbll_inv_$i" $CIRCUIT]

	# create key ports
	set key0 [get_db [create_port_bus -input -name lbll_key_$i] .bits]
	set key1 [get_db [create_port_bus -input -name lbll_key_[expr $i+1]] .bits]

	# connect latch
	connect [get_db $lat .pins -if .base_name==$lat_d] [get_db $mux .pins -if .base_name==z]
	connect [get_db $lat .pins -if .base_name==$lat_s] 1
	connect [get_db $xor .pins -if .base_name==$xor_i0] [get_db [get_clocks] .sources]
	connect [get_db $xor .pins -if .base_name==$xor_i1] $key1
	connect [get_db $xor .pins -if .base_name==$xor_o] [get_db $nand .pins -if .base_name==$nand_i0]
	connect [get_db $lat .pins -if .base_name==$lat_clk] [get_db $nand .pins -if .base_name==$nand_o]
	connect [get_db $nand .pins -if .base_name==$nand_i1] $key0
	connect [get_db $nor .pins -if .base_name==$nor_i0] $key0
	connect [get_db $nor .pins -if .base_name==$nor_i1] $key1
	connect [get_db $nor .pins -if .base_name==$nor_o] [get_db $inv .pins -if .base_name==$inv_i]
	connect [get_db $lat .pins -if .base_name==$lat_r] [get_db $inv .pins -if .base_name==$inv_o]

	# from the fanin of selected endpoints, find gates not in fanin of non-locked endpoints
	# non-locked endpoints
	set pot_nonlocked_ep [concat [get_db ports -if .direction==out] [get_db [get_db insts -if .is_flop] .pins -if .base_name==$ff_d]]
	set nonlocked_fi [dict create]
	foreach ep $pot_nonlocked_ep {
		if {[lsearch -exact $locked_ep $ep]<0} {
			foreach g [get_db [all_fanin -to $ep]] {
				dict set nonlocked_fi $g 1
			}
		}
	}

	set fo_pins {}
	foreach ep $decoy_ep {
		set pot_fanin {}
		# get fanin
		foreach g [get_db [all_fanin -to $ep]] {
			if {[dict exists $nonlocked_fi $g]==0} {
				lappend pot_fanin $g
			}
		}
		# select random pin
		lappend fo_pins [lindex $pot_fanin [expr int([llength $pot_fanin]*rand())]]
	}

	# connect output of latch
	foreach fo_pin $fo_pins {
		set r [expr rand()]
		if {$r<0.33} {
			set g [create_primitive -function or -name "lbll_decoy_or_$i" -inside $CIRCUIT -inputs 2]
			connect [get_db $lat .pins -if .base_name==$lat_q] [get_db $g .pins -if .base_name==in_0]
			set in_pin [get_db $g .pins -if .base_name==in_1]
			set out_pin [get_db $g .pins -if .base_name==z]
		} elseif {$r<0.66} {
			set g [create_primitive -function xor -name "lbll_decoy_xor_$i" -inside $CIRCUIT -inputs 2]
			connect [get_db $lat .pins -if .base_name==$lat_q] [get_db $g .pins -if .base_name==in_0]
			set in_pin [get_db $g .pins -if .base_name==in_1]
			set out_pin [get_db $g .pins -if .base_name==z]
		} else {
			set g [create_primitive -function bmux -name "lbll_decoy_mux_$i" -inside $CIRCUIT -inputs 3]
			connect [get_db $lat .pins -if .base_name==$lat_q] [get_db $g .pins -if .base_name==sel0]
			connect [lindex $decoy_sp end] [get_db $g .pins -if .base_name==data1]
			set in_pin [get_db $g .pins -if .base_name==data0]
			set out_pin [get_db $g .pins -if .base_name==z]
		}

		if {[get_db $fo_pin .net.drivers] eq $fo_pin} {
			set loads [get_db $fo_pin .net.loads]
			if {$loads eq ""} {suspend}
			disconnect $fo_pin
			connect $in_pin $fo_pin
			connect $out_pin [lindex $loads 0]
		} else {
			set driver [get_db $fo_pin .net.drivers]
			if {$driver eq ""} {suspend}
			disconnect $fo_pin
			connect $in_pin $driver
			connect $out_pin $fo_pin
		}
	}

	# set the key bits
	set_case_analysis 0 $key0
	set_case_analysis 0 $key1
	dict set key [get_db $key0 .base_name] 0
	dict set key [get_db $key1 .base_name] 0
	con_check
}
syn_map

#### insert delay decoys
set lats [get_db insts -if .is_latch]

# get locked subcircuit start/endpoints
set lat_ds [get_db $lats .pins -if .base_name==$lat_d]
set locked_sp [concat [get_db [all_fanin -to $lat_ds -startpoints_only] -if .base_name!=$lat_clk&&.base_name!=$ff_clk] $lat_ds]
set locked_ep [concat [get_db [all_fanout -from $lat_ds -endpoints_only]] $lat_ds]

# from the fanin of selected endpoints, find gates not in fanin of non-locked endpoints
# non-locked endpoints
set potential_pins {}
set sp_fanout [dict create]
foreach sp $locked_sp {
	foreach p [get_db [all_fanout -from $sp]] {
		dict set sp_fanout $p 1
	}
}
foreach ep $locked_ep {
	foreach p [get_db [all_fanin -to $ep]] {
		if {[dict exists $sp_fanout $p]} {
			lappend potential_pins $p
		}
	}
}

# select random pins
for {set di 0} {$di<$ndelay} {incr di} {
	set pin_i [expr int([llength $potential_pins]*rand())]
	set decoy_pin [lindex $potential_pins $pin_i]
	set potential_pins [lremove $potential_pins $pin_i]

	# add latch
	set i [expr 2*[llength $lats]]
	set lat [create_inst $lat_type -name delay_decoy_lat_$i $CIRCUIT]
	set xor [create_inst $xor_type -name "lbll_xor_$i" $CIRCUIT]
	set nand [create_inst $nand_type -name "lbll_nand_$i" $CIRCUIT]
	set nor [create_inst $nor_type -name "lbll_nor_$i" $CIRCUIT]
	set inv [create_inst $inv_type -name "lbll_inv_$i" $CIRCUIT]

	# create key ports
	set key0 [get_db [create_port_bus -input -name lbll_key_$i] .bits]
	set key1 [get_db [create_port_bus -input -name lbll_key_[expr $i+1]] .bits]

	# connect latch
	if {[get_db $decoy_pin .net.drivers] eq $decoy_pin} {
		set loads [get_db $decoy_pin .net.loads]
		if {$loads eq ""} {suspend}
		disconnect $decoy_pin
		connect [get_db $lat .pins -if .base_name==$lat_d] $decoy_pin
		connect [get_db $lat .pins -if .base_name==$lat_q] [lindex $loads 0]
	} else {
		set driver [get_db $decoy_pin .net.drivers]
		if {$driver eq ""} {suspend}
		disconnect $decoy_pin
		connect [get_db $lat .pins -if .base_name==$lat_d] $driver
		connect [get_db $lat .pins -if .base_name==$lat_q] $decoy_pin
	}
	connect [get_db $lat .pins -if .base_name==$lat_s] 1
	connect [get_db $xor .pins -if .base_name==$xor_i0] [get_db [get_clocks] .sources]
	connect [get_db $xor .pins -if .base_name==$xor_i1] $key1
	connect [get_db $xor .pins -if .base_name==$xor_o] [get_db $nand .pins -if .base_name==$nand_i0]
	connect [get_db $lat .pins -if .base_name==$lat_clk] [get_db $nand .pins -if .base_name==$nand_o]
	connect [get_db $nand .pins -if .base_name==$nand_i1] $key0
	connect [get_db $nor .pins -if .base_name==$nor_i0] $key0
	connect [get_db $nor .pins -if .base_name==$nor_i1] $key1
	connect [get_db $nor .pins -if .base_name==$nor_o] [get_db $inv .pins -if .base_name==$inv_i]
	connect [get_db $lat .pins -if .base_name==$lat_r] [get_db $inv .pins -if .base_name==$inv_o]

	# set the key bits
	set_case_analysis 0 $key0
	set_case_analysis 1 $key1
	dict set key [get_db $key0 .base_name] 0
	dict set key [get_db $key1 .base_name] 1
	con_check
}

# single opt
syn_opt

update_names -map [list [list $CIRCUIT ${CIRCUIT}_lbll]] -design
write_hdl -generic ${CIRCUIT}_lbll > locked_netlist.v
echo $key > locked_netlist.key

exit

