
# helper functions
proc lintersection {la lb} {
	set len 0
	foreach a $la {
		if {[lsearch -exact $lb $a]>-1} {incr len}
	}
	return $len
}

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

proc lbll_lib {} {
	set lib [dict create]

	dict set lib lat_type latchdrs
	dict set lib lat_d D
	dict set lib lat_q Q
	dict set lib lat_clk ENA
	dict set lib lat_r R
	dict set lib lat_s S

	dict set lib ff_type fflopd
	dict set lib ff_d D
	dict set lib ff_q Q
	dict set lib ff_qn QN
	dict set lib ff_clk CK

	dict set lib inv_type inv1
	dict set lib inv_i A
	dict set lib inv_o Y

	dict set lib xor_type xor2
	dict set lib xor_i0 A
	dict set lib xor_i1 B
	dict set lib xor_o Y

	dict set lib nand_type nand2
	dict set lib nand_i0 A
	dict set lib nand_i1 B
	dict set lib nand_o Y

	dict set lib nor_type nor2
	dict set lib nor_i0 A
	dict set lib nor_i1 B
	dict set lib nor_o Y

	return $lib
}

proc select_ffs {nffs} {
	#### select flops
	# this algorithm assesses the fanin of each gate.
	# selects the gate with the largest fanin gate count 
	# w/ no input fanin and less than nff flop startpoints.
	# This corresponds to a cone with high potential for retiming
	# as the gates all share the same input ffs.
	set largest_cone_size 0
	foreach inst [get_db insts] {
		# pass if inputs in fanin
		set start_points [get_db [all_fanin -to [get_db $inst .pins -if .direction==in] -startpoints_only]]
		if {[llength [get_db $start_points -if .obj_type==port]]>0} {continue}

		# pass if flops > nflops
		set start_ffs [get_db [all_fanin -to [get_db $inst .pins -if .direction==in] -startpoints_only -only_cells]]
		if {[llength $start_ffs]>$nffs} {continue}

		# pass if fanin flops are not supported
		if {[llength [get_db $start_ffs -if .lib_cell.is_rise_edge_triggered==false]] > 0} {continue}
		# TODO: add other conditions here!

		# record cone size
		set cone_size [llength [get_db [all_fanin -to [get_db $inst .pins -if .direction==in] -only_cells]]]
		if {$cone_size>$largest_cone_size} {
			set largest_cone_size $cone_size
			set selected_ffs $start_ffs
		}
	}
	return $selected_ffs
}

proc latch_convert_retime {lib selected_ffs} {

	# duplicate ffs
	set design [get_db designs .base_name]
	echo "duplicating ffs..."
	foreach ff $selected_ffs {

		#names
		set ff_name_0 "[get_db $ff .name]_F0"
		set ff_name_1 "[get_db $ff .name]_F1"

		# handle multi-output ff, adding an inv and disconnecting
		if {[llength [get_db $ff .pins -if .base_name==[dict get $lib ff_qn]&&.net!=""]]>0} {
			set inv [create_inst [dict get $lib inv_type] $design]
			set qn_ff [get_db $ff .pins -if .base_name==[dict get $lib ff_qn]]
			set q_ff [get_db $ff .pins -if .base_name==[dict get $lib ff_q]]
			connect $qn_ff [get_db $inv .pins -if .base_name==[dict get $lib inv_o]]
			connect $q_ff [get_db $inv .pins -if .base_name==[dict get $lib inv_i]]
			disconnect $qn_ff
		}

		#create second ff
		set ff_0 $ff
		set ff_1 [create_inst [dict get $lib ff_type] -name $ff_name_1 $design]

		#connect second ff
		set clk_ff_0 [get_db $ff_0 .pins -if .base_name==[dict get $lib ff_clk]]
		set clk_ff_1 [get_db $ff_1 .pins -if .base_name==[dict get $lib ff_clk]]
		set q_ff_0 [get_db $ff_0 .pins -if .base_name==[dict get $lib ff_q]]
		set q_ff_1 [get_db $ff_1 .pins -if .base_name==[dict get $lib ff_q]]
		set d_ff_1 [get_db $ff_1 .pins -if .base_name==[dict get $lib ff_d]]
		set net [get_db $q_ff_0 .net]
		set net_load [lindex [get_db $net .loads] 0]
		disconnect $q_ff_0
		connect $q_ff_0 $d_ff_1 
		connect $q_ff_1 $net_load
		connect $clk_ff_1 $clk_ff_0
		rename_obj $ff_0 $ff_name_0
	}

	# retime F1 ffs
	echo "retiming ffs..."
	set period [expr [get_db clocks .period]/1000]
	set retime_period [expr $period/2]
	create_clock -period $retime_period clk

	set_db [get_db design:$design] .retime true
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
	set retimed_ffs [concat [get_db insts *_F1*] [get_db insts *_F0*]]
	echo "replacing ffs..."
	set lats {}
	foreach ff $retimed_ffs {
		# create latch
		if {[string first "_F0" $ff] != -1} {
			set lat_name [string map {"_F0" "_L0"} [get_db $ff .base_name]] 
			set lat [create_inst [dict get $lib lat_type] -name $lat_name $design]
			lappend lats [list $lat "L0"]
		} else {
			set lat [create_inst [dict get $lib lat_type] $design]
			lappend lats [list $lat "L1"]
		}

		# connect latch d/q
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $ff .pins -if .base_name==[dict get $lib ff_q]]
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_d]] [get_db $ff .pins -if .base_name==[dict get $lib ff_d]]
		delete_obj $ff
	}

	return $lats

}

proc insert_logic_decoys {lib nlogic max_fio} {

	set design [get_db designs .base_name]
	set decoys {}
	for {set di 0} {$di<$nlogic} {incr di} {
		set lats [get_db insts -if .is_latch]

		# select number of fanin/out for logic decoy latch
		set nfo [expr int(ceil($max_fio*rand()))]
		set nfi [expr int(ceil($max_fio*rand()))]

		# get locked subcircuit start/endpoints
		set lat_ds [get_db $lats .pins -if .base_name==[dict get $lib lat_d]]
		set locked_sp [concat [get_db [all_fanin -to $lat_ds -startpoints_only] -if .base_name!=[dict get $lib lat_clk]&&.base_name!=[dict get $lib ff_clk]] $lat_ds]
		set locked_ep [concat [get_db [all_fanout -from $lat_ds -endpoints_only]] $lat_ds]

		# calculate the number of endpoints per startpoint
		set len_ep {}
		foreach sp $locked_sp {
			set eps [get_db [all_fanout -from $sp -endpoints_only]]
			lappend len_ep [lintersection $eps $locked_ep]
		}	

		# get the startpoints w/ lowest endpoint count
		set decoy_sp {}
		foreach spi [lrange [lsort -indices -integer $len_ep] 0 $nfi] {
			lappend decoy_sp [lindex $locked_sp $spi]
		}

		# calculate the number of startpoints per endpoint
		set len_sp {}
		foreach ep $locked_ep {
			set sps [get_db [all_fanin -to $ep -startpoints_only] -if .base_name!=[dict get $lib lat_clk]&&.base_name!=[dict get $lib ff_clk]]
			lappend len_sp [lintersection $sps $locked_sp]
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
		set mux [create_primitive -function bmux -inside $design -inputs $nmuxin]
		set mux_name [get_db $mux .base_name]
		for {set tti 0} {$tti<[expr 2**$nfi]} {incr tti} {
			connect [lindex $tt $tti] $mux_name/data$tti
		}
		for {set spi 0} {$spi<$nfi} {incr spi} {
			set sp [lindex $decoy_sp $spi]
			if {[get_db $sp .obj_type] eq "pin"} {
				set driver [get_db $sp .inst.pins -if .base_name==[dict get $lib lat_q]||.base_name==[dict get $lib ff_q]]
			} else {
				set driver $sp
			}
			connect $driver $mux_name/sel$spi
		}

		# add latch
		set lat [create_inst [dict get $lib lat_type] $design]

		# connect latch input
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_d]] [get_db $mux .pins -if .base_name==z]

		# from the fanin of selected endpoints, find gates not in fanin of non-locked endpoints
		# non-locked endpoints
		set pot_nonlocked_ep [concat [get_db ports -if .direction==out] [get_db [get_db insts -if .is_flop] .pins -if .base_name==[dict get $lib ff_d]]]
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
			set ep_fanin [get_db [all_fanin -to $ep] -if .base_name!=[dict get $lib lat_d]]
			set ep_fanin [get_db $ep_fanin -if .base_name!=[dict get $lib ff_d]]
			set ep_fanin [get_db $ep_fanin -if .base_name!=[dict get $lib lat_clk]]
			set ep_fanin [get_db $ep_fanin -if .base_name!=[dict get $lib ff_clk]]

			foreach g $ep_fanin {
				if {[dict exists $nonlocked_fi $g]==0} {
					lappend pot_fanin $g
				}
			}
			lappend pot_fanin $ep

			# select random pin
			lappend fo_pins [lindex $pot_fanin [expr int([llength $pot_fanin]*rand())]]
		}

		# connect latch output
		foreach fo_pin $fo_pins {
			set r [expr rand()]
			# choose output gate type
			if {$r<0.33} {
				set g [create_primitive -function or -inside $design -inputs 2]
				connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $g .pins -if .base_name==in_0]
				set in_pin [get_db $g .pins -if .base_name==in_1]
				set out_pin [get_db $g .pins -if .base_name==z]
			} elseif {$r<0.66} {
				set g [create_primitive -function xor -inside $design -inputs 2]
				connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $g .pins -if .base_name==in_0]
				set in_pin [get_db $g .pins -if .base_name==in_1]
				set out_pin [get_db $g .pins -if .base_name==z]
			} else {
				set g [create_primitive -function bmux -inside $design -inputs 3]
				connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $g .pins -if .base_name==sel0]
				connect [lindex $decoy_sp end] [get_db $g .pins -if .base_name==data1]
				set in_pin [get_db $g .pins -if .base_name==data0]
				set out_pin [get_db $g .pins -if .base_name==z]
			}

			# splice into net
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

		lappend decoys [list $lat "logic"]
	}

	return $decoys
}

proc insert_delay_decoys {lib ndelay} {
	#### insert delay decoys
	set design [get_db designs .base_name]
	set lats [get_db insts -if .is_latch]

	# get locked subcircuit start/endpoints
	set lat_ds [get_db $lats .pins -if .base_name==[dict get $lib lat_d]]
	set locked_sp [concat [get_db [all_fanin -to $lat_ds -startpoints_only] -if .base_name!=[dict get $lib lat_clk]&&.base_name!=[dict get $lib ff_clk]] $lat_ds]
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
	set decoys {}
	for {set di 0} {$di<$ndelay} {incr di} {
		set pin_i [expr int([llength $potential_pins]*rand())]
		set decoy_pin [lindex $potential_pins $pin_i]
		set potential_pins [lremove $potential_pins $pin_i]

		# add latch
		set lat [create_inst [dict get $lib lat_type] $design]

		# connect latch
		if {[get_db $decoy_pin .net.drivers] eq $decoy_pin} {
			set loads [get_db $decoy_pin .net.loads]
			if {$loads eq ""} {suspend}
			disconnect $decoy_pin
			connect [get_db $lat .pins -if .base_name==[dict get $lib lat_d]] $decoy_pin
			connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [lindex $loads 0]
		} else {
			set driver [get_db $decoy_pin .net.drivers]
			if {$driver eq ""} {suspend}
			disconnect $decoy_pin
			connect [get_db $lat .pins -if .base_name==[dict get $lib lat_d]] $driver
			connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] $decoy_pin
		}
		lappend decoys [list $lat "delay"]
	}

	return $decoys
}

proc connect_latch_clk_rst {lib lat_types} {
	set design [get_db designs .base_name]
	set key [dict create]
	set i 0
	foreach lat_type $lat_types {
		set lat [lindex $lat_type 0]
		set type [lindex $lat_type 1]

		# create instances
		set xor [create_inst [dict get $lib xor_type] -name "lbll_xor_$i" $design]
		set nand [create_inst [dict get $lib nand_type] -name "lbll_nand_$i" $design]
		set nor [create_inst [dict get $lib nor_type] -name "lbll_nor_$i" $design]
		set inv [create_inst [dict get $lib inv_type] -name "lbll_inv_$i" $design]

		# create key ports
		set key0 [get_db [create_port_bus -input -name lbll_key_$i] .bits]
		set key1 [get_db [create_port_bus -input -name lbll_key_[expr $i+1]] .bits]

		# connect latch
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_s]] 1
		connect [get_db $xor .pins -if .base_name==[dict get $lib xor_i0]] [get_db clocks .sources]
		connect [get_db $xor .pins -if .base_name==[dict get $lib xor_i1]] $key1
		connect [get_db $xor .pins -if .base_name==[dict get $lib xor_o]] [get_db $nand .pins -if .base_name==[dict get $lib nand_i0]]
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_clk]] [get_db $nand .pins -if .base_name==[dict get $lib nand_o]]
		connect [get_db $nand .pins -if .base_name==[dict get $lib nand_i1]] $key0
		connect [get_db $nor .pins -if .base_name==[dict get $lib nor_i0]] $key0
		connect [get_db $nor .pins -if .base_name==[dict get $lib nor_i1]] $key1
		connect [get_db $nor .pins -if .base_name==[dict get $lib nor_o]] [get_db $inv .pins -if .base_name==[dict get $lib inv_i]]
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_r]] [get_db $inv .pins -if .base_name==[dict get $lib inv_o]]

		# set the appropriate key bit based on latch order
		if {$type eq "L0"} {
			set_case_analysis 1 $key0
			set_case_analysis 0 $key1
			dict set key [get_db $key0 .base_name] 1
			dict set key [get_db $key1 .base_name] 0
		} elseif {$type eq "L1"} {
			set_case_analysis 1 $key0
			set_case_analysis 1 $key1
			dict set key [get_db $key0 .base_name] 1
			dict set key [get_db $key1 .base_name] 1
		} elseif {$type eq "logic"} {
			set_case_analysis 0 $key0
			set_case_analysis 0 $key1
			dict set key [get_db $key0 .base_name] 0
			dict set key [get_db $key1 .base_name] 0
		} else {
			set_case_analysis 0 $key0
			set_case_analysis 1 $key1
			dict set key [get_db $key0 .base_name] 0
			dict set key [get_db $key1 .base_name] 1
		}
		incr i 2
	}

	return $key
}

##################### lbll #####################
proc lbll {{nffs 10} {nlogic 3} {ndelay 3} {max_fio 3}} {

	# set up lib names
	set lib [lbll_lib]

	# select flops
	set selected_ffs [select_ffs $nffs]

	# convert flops to latches and retime
	set orig_lats [latch_convert_retime $lib $selected_ffs]
	
	# insert decoys
	set logic_decoys [insert_logic_decoys $lib $nlogic $max_fio]
	set delay_decoys [insert_delay_decoys $lib $ndelay]

	# connect latch clock/reset
	set key [connect_latch_clk_rst $lib [concat $orig_lats $logic_decoys $delay_decoys]]

	# run map for new decoy logic
	con_check
	syn_map

	# check connections
	con_check
	
	return $key
}


