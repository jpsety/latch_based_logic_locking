
# helper functions
proc lintersection {la lb} {
	set len 0
	foreach a $la {
		if {[lsearch -exact $lb $a]>-1} {incr len}
	}
	return $len
}

proc con_check {{ignore_r_c 0} {lib {}}} {
	foreach p [get_db pins] {
		if {[get_db $p .constant] eq "no_constant"} {
			if {([get_db $p .net] eq "")||([get_db $p .net.num_loads]==0)||([get_db $p .net.num_drivers]==0)} {
				if {$ignore_r_c} {
					if {[get_db $p .base_name] eq [dict get $lib lat_r]} {continue}
					if {[get_db $p .base_name] eq [dict get $lib lat_clk]} {continue}
					if {[get_db $p .base_name] eq [dict get $lib ff_clk]} {continue}
				} 
				echo "unconnected pin $p"
				return 1
				
			}
		}
	}
	return 0
}

set lbll_lib_example [dict create]

dict set lbll_lib_example lat_type latchdr
dict set lbll_lib_example lat_d D
dict set lbll_lib_example lat_q Q
dict set lbll_lib_example lat_clk ENA
dict set lbll_lib_example lat_r R
# active reset value
dict set lbll_lib_example lat_r_val 0

dict set lbll_lib_example ff_type fflopd
dict set lbll_lib_example ff_d D
dict set lbll_lib_example ff_q Q
dict set lbll_lib_example ff_qn QN
dict set lbll_lib_example ff_clk CK

dict set lbll_lib_example inv_type inv1
dict set lbll_lib_example inv_i A
dict set lbll_lib_example inv_o Y

dict set lbll_lib_example xor_type xor2
dict set lbll_lib_example xor_i0 A
dict set lbll_lib_example xor_i1 B
dict set lbll_lib_example xor_o Y

dict set lbll_lib_example nand_type nand2
dict set lbll_lib_example nand_i0 A
dict set lbll_lib_example nand_i1 B
dict set lbll_lib_example nand_o Y

dict set lbll_lib_example nor_type nor2
dict set lbll_lib_example nor_i0 A
dict set lbll_lib_example nor_i1 B
dict set lbll_lib_example nor_o Y

proc select_ffs {nffs} {
	#### select flops
	# this algorithm assesses the fanin of each gate.
	# selects the gate with the largest fanin gate count 
	# w/ no input fanin and less than nff flop startpoints.
	# This corresponds to a cone with high potential for retiming
	# as the gates all share the same input ffs.
	set largest_cone_size 0
	set selected_ffs {}
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
		#if {[llength [get_db $start_ffs -if .base_name==*x2b*]] > 0} {continue}

		# record cone size
		set cone_size [llength [get_db [all_fanin -to [get_db $inst .pins -if .direction==in] -only_cells]]]
		if {$cone_size>$largest_cone_size} {
			set largest_cone_size $cone_size
			set selected_ffs $start_ffs
		}
	}
	return $selected_ffs
}

proc latch_convert_retime {lib clk selected_ffs} {

	if {[llength $selected_ffs]==0} return {}

	# TODO: make this safe
	set design [get_db designs .base_name]

	# duplicate ffs
	echo "duplicating ffs..."
	if {[con_check 1 $lib]} {
		echo "disconnect before duplicated flops"	
		suspend
	}
	foreach ff_0 $selected_ffs {

		# duplicate flop for each output pin
		foreach out_pin_type {ff_q ff_qn} {
			if {[llength [get_db $ff_0 .pins -if .base_name==[dict get $lib $out_pin_type]&&.net!=""]]==0} {
				continue
			}

			#create ff
			set ff_name_1 "[get_db $ff_0 .name]_[dict get $lib $out_pin_type]_F1"
			set ff_1 [create_inst [dict get $lib ff_type] -name $ff_name_1 $design]

			#connect ff
			set clk_ff_0 [get_db $ff_0 .pins -if .base_name==[dict get $lib ff_clk]]
			set clk_ff_1 [get_db $ff_1 .pins -if .base_name==[dict get $lib ff_clk]]
			set out_ff_0 [get_db $ff_0 .pins -if .base_name==[dict get $lib $out_pin_type]]
			set q_ff_1 [get_db $ff_1 .pins -if .base_name==[dict get $lib ff_q]]
			set d_ff_1 [get_db $ff_1 .pins -if .base_name==[dict get $lib ff_d]]
			set net [get_db $out_ff_0 .net]
			set net_load [lindex [get_db $net .loads] 0]
			disconnect $out_ff_0
			connect $out_ff_0 $d_ff_1 
			connect $q_ff_1 $net_load
			connect $clk_ff_1 $clk_ff_0
		}

		# change orig ff name
		set ff_name_0 "[get_db $ff_0 .name]_F0"
		rename_obj $ff_0 $ff_name_0
		if {[con_check 1 $lib]} {
			echo "disconnect during duplicated flops"	
			suspend
		}
	}

	# retime F1 ffs
	echo "retiming ffs..."
	set period [expr [get_db clocks .actual_period]/1000]
	set retime_period [expr $period/2]
	create_clock -period $retime_period $clk

	set_db [get_db design:$design] .retime true
	::legacy::set_attribute retime_reg_naming_suffix _retimed_reg_F1 /
	set_db [get_db insts] .dont_retime true -quiet
	set_db [get_db insts *_F1] .dont_retime false 

	retime -min_delay
	create_clock -period $period $clk

	# delete state points
	set_db [get_db hinsts *state_point] .preserve false
	foreach sp [get_db hinsts *state_point] {
		set dr [lindex [get_db [get_db $sp .hpins -if .base_name==in] .drivers] 0]
		set ld [lindex [get_db [get_db $sp .hpins -if .base_name==out] .loads] 0]
		delete_obj $sp
		connect $dr $ld
	}
	if {[con_check 1 $lib]} {
		echo "disconnect after delete state points"	
		suspend
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
			set lat_name [string map {"_F1" "_L1"} [get_db $ff .base_name]] 
			set lat [create_inst [dict get $lib lat_type] -name $lat_name $design]
			lappend lats [list $lat "L1"]
		}

		# connect latch q/qn
		if {[llength [get_db $ff .pins -if .base_name==[dict get $lib ff_q]&&.net!=""]]!=0} {
			connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $ff .pins -if .base_name==[dict get $lib ff_q]]
		}
		if {[llength [get_db $ff .pins -if .base_name==[dict get $lib ff_qn]&&.net!=""]]!=0} {
			set inv [create_inst [dict get $lib inv_type] $design]
			connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $inv .pins -if .base_name==[dict get $lib inv_i]]
			connect [get_db $ff .pins -if .base_name==[dict get $lib ff_qn]] [get_db $inv .pins -if .base_name==[dict get $lib inv_o]]
		}

		# connect latch d
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_d]] [get_db $ff .pins -if .base_name==[dict get $lib ff_d]]

		# remove ff
		delete_obj $ff

		if {[con_check 1 $lib]} {
			echo "disconnect durring latch conversion"	
			suspend
		}
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

		echo "endpoints: $decoy_ep"
		echo "startpoints: $decoy_sp"

		# add latch
		set lat [create_inst [dict get $lib lat_type] -name logic_decoy_$di $design]

		# temporary case analysis
		set_case_analysis [dict get $lib lat_r_val] [get_db $lat .pins -if .base_name==[dict get $lib lat_r]]
		set_case_analysis 0 [get_db $lat .pins -if .base_name==[dict get $lib lat_q]]

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
		echo "fo pins: $fo_pins"

		# connect latch output to fo pins
		foreach fo_pin $fo_pins {
			set r [expr rand()]
			# choose output gate type
			if {$r<0.33} {
				set g [create_primitive -function or -inside $design -inputs 2]
				echo "spliced with or: $g"
				connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $g .pins -if .base_name==in_0]
				set in_pin [get_db $g .pins -if .base_name==in_1]
				set out_pin [get_db $g .pins -if .base_name==z]
			} elseif {$r<0.66} {
				set g [create_primitive -function xor -inside $design -inputs 2]
				echo "spliced with xor: $g"
				connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $g .pins -if .base_name==in_0]
				set in_pin [get_db $g .pins -if .base_name==in_1]
				set out_pin [get_db $g .pins -if .base_name==z]
			} else {
				set g [create_primitive -function bmux -inside $design -inputs 3]
				echo "spliced with mux: $g"
				connect [get_db $lat .pins -if .base_name==[dict get $lib lat_q]] [get_db $g .pins -if .base_name==sel0]
				set in_pin [get_db $g .pins -if .base_name==data0]
				set out_pin [get_db $g .pins -if .base_name==z]
			}

			# splice output gate into net
			if {[lindex [get_db $fo_pin .net.drivers] 0] eq $fo_pin} {
				# pin is driver
				set loads [get_db $fo_pin .net.loads]
				if {$loads eq ""} {suspend}
				disconnect $fo_pin
				connect $in_pin $fo_pin
				connect $out_pin [lindex $loads 0]

				echo "driver"
				echo "in_pin: $in_pin"
				echo "out_pin: $out_pin"
				echo "loads: $loads"
				echo "fo_pin: $fo_pin"
			} else {
				# pin is load
				set driver [get_db $fo_pin .net.drivers]
				if {$driver eq ""} {suspend}
				disconnect $fo_pin
				connect $in_pin $driver
				connect $out_pin $fo_pin

				echo "load"
				echo "in_pin: $in_pin"
				echo "out_pin: $out_pin"
				echo "driver: $driver"
				echo "fo_pin: $fo_pin"
			}

			# hook up mux data
			if {$r>=0.66} {
				set sp [lindex $decoy_sp end]
				if {[get_db $sp .obj_type] eq "pin"} {
					set driver [get_db $sp .inst.pins -if .base_name==[dict get $lib lat_q]||.base_name==[dict get $lib ff_q]]
				} else {
					set driver $sp
				}
				echo "driver: $driver"
				connect $driver [get_db $g .pins -if .base_name==data1]
			}

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
			echo "sp: $sp, driver: $driver"
			connect $driver $mux_name/sel$spi
		}

		# connect latch input
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_d]] [get_db $mux .pins -if .base_name==z]

		# check for loops TODO: check for loops without timing
		report_timing
		report_loop
		if {[llength [get_db insts -if .base_name==*loop*]]>0} {
			suspend
		}

		lappend decoys [list $lat "logic"]

	}

	return $decoys
}

proc insert_delay_decoys {lib ndelay} {
	if {$ndelay==0} return {}
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

	# filter out hpins etc
	set potential_pins [get_db $potential_pins -if .obj_type==pin]

	# select random pins
	set decoys {}
	for {set di 0} {$di<$ndelay} {incr di} {
		set pin_i [expr int([llength $potential_pins]*rand())]
		set decoy_pin [lindex $potential_pins $pin_i]
		set potential_pins [lremove $potential_pins $pin_i]

		# add latch
		set lat [create_inst [dict get $lib lat_type] -name delay_decoy_$di $design]

		# temporary case analysis
		set_case_analysis 1 [get_db $lat .pins -if .base_name==[dict get $lib lat_clk]]

		# connect latch
		if {[lindex [get_db $decoy_pin .net.drivers] 0] eq $decoy_pin} {
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
		if {[con_check 1 $lib]} {suspend}

	}

	return $decoys
}

proc connect_latch_clk_rst {lib lat_types} {
	if {[llength $lat_types]==0} return {}
	set design [get_db designs .base_name]
	set nbits [expr [llength $lat_types]*2]
	set key_bus [lreverse [get_db [create_port_bus -input -left_bit [expr $nbits-1] -right_bit 0 -name lbll_key] .bits]]
	set key_dict [dict create]
	set i 0
	foreach lat_type $lat_types {
		set lat [lindex $lat_type 0]
		set type [lindex $lat_type 1]

		# reset temporary case analysis
		remove_case_analysis [get_db $lat .pins -if .base_name==[dict get $lib lat_r]]
		remove_case_analysis [get_db $lat .pins -if .base_name==[dict get $lib lat_clk]]

		# create instances
		set xor [create_inst [dict get $lib xor_type] -name "lbll_xor_$i" $design]
		set nand [create_inst [dict get $lib nand_type] -name "lbll_nand_$i" $design]
		set nor [create_inst [dict get $lib nor_type] -name "lbll_nor_$i" $design]
		if {[dict get $lib lat_r_val]==0} {
			set inv [create_inst [dict get $lib inv_type] -name "lbll_inv_$i" $design]
		}

		# select key ports
		set k0i [expr int(rand()*[llength $key_bus])]
		set key0 [lindex $key_bus $k0i]
		set key_bus [lreplace $key_bus $k0i $k0i]

		set k1i [expr int(rand()*[llength $key_bus])]
		set key1 [lindex $key_bus $k1i]
		set key_bus [lreplace $key_bus $k1i $k1i]

		# connect latch
		connect [get_db $xor .pins -if .base_name==[dict get $lib xor_i0]] [get_db clocks .sources]
		connect [get_db $xor .pins -if .base_name==[dict get $lib xor_i1]] $key1
		connect [get_db $xor .pins -if .base_name==[dict get $lib xor_o]] [get_db $nand .pins -if .base_name==[dict get $lib nand_i0]]
		connect [get_db $lat .pins -if .base_name==[dict get $lib lat_clk]] [get_db $nand .pins -if .base_name==[dict get $lib nand_o]]
		connect [get_db $nand .pins -if .base_name==[dict get $lib nand_i1]] $key0
		connect [get_db $nor .pins -if .base_name==[dict get $lib nor_i0]] $key0
		connect [get_db $nor .pins -if .base_name==[dict get $lib nor_i1]] $key1
		if {[dict get $lib lat_r_val]==0} {
			connect [get_db $nor .pins -if .base_name==[dict get $lib nor_o]] [get_db $inv .pins -if .base_name==[dict get $lib inv_i]]
			connect [get_db $lat .pins -if .base_name==[dict get $lib lat_r]] [get_db $inv .pins -if .base_name==[dict get $lib inv_o]]
		} else {
			connect [get_db $nor .pins -if .base_name==[dict get $lib nor_o]] [get_db $lat .pins -if .base_name==[dict get $lib lat_r]]
		}

		# set the appropriate key bit based on latch order
		if {$type eq "L0"} {
			set_case_analysis 1 $key0
			set_case_analysis 0 $key1
			dict set key_dict [get_db $key0 .base_name] 1
			dict set key_dict [get_db $key1 .base_name] 0
		} elseif {$type eq "L1"} {
			set_case_analysis 1 $key0
			set_case_analysis 1 $key1
			dict set key_dict [get_db $key0 .base_name] 1
			dict set key_dict [get_db $key1 .base_name] 1
		} elseif {$type eq "logic"} {
			set_case_analysis 0 $key0
			set_case_analysis 0 $key1
			dict set key_dict [get_db $key0 .base_name] 0
			dict set key_dict [get_db $key1 .base_name] 0
		} else {
			set_case_analysis 0 $key0
			set_case_analysis 1 $key1
			dict set key_dict [get_db $key0 .base_name] 0
			dict set key_dict [get_db $key1 .base_name] 1
		}
		incr i 2
	}

	set key ""
	for {set ki 0} {$ki<$nbits} {incr ki} {
		set key "[dict get $key_dict lbll_key\[$ki\]]$key"
	}
	set key "$nbits'b$key"

	set sdc ""
	dict for {k v} $key_dict {
		append sdc "set_case_analysis $v $k\n"
	}

	return [list $key $sdc]
}

##################### lbll #####################
proc lbll {{lib $lbll_example_lib} {clk "clk"} {nbits 256} {nffs 10} {plogic 0.5} {max_fio 3} {seed 0}} {
	# lib: a dict containing library information, example above in lbll_example_lib
	# clk: clock input to select flops from
	# nbits: total number of locking bits to insert
	# nffs: number of flip-flops to convert to latches,
	#		creates an undetermined number of key bits,
	#		remaining key bits are decoys
	# plogic: % of decoys that are logic. Thus pdelay = 1-pdecoys.
	# max_fio: maximum fanout/in for the added decoy logic
	# seed: seed for random insertion
	if {$nbits==0} return {}
	
	# set seed
	expr srand($seed)

	# select flops
	if {[con_check 1 $lib]} {suspend}
	set selected_ffs [select_ffs $nffs]

	# convert flops to latches and retime
	set orig_lats [latch_convert_retime $lib $clk $selected_ffs]

	# determine decoy counts
	set ndecoy [expr $nbits/2-[llength $orig_lats]]
	if {$ndecoy < 0} {
		echo "original latch count exceeds nbits! 
			 Reduce nff or increase nbits to allow decoys"
		set ndecoy 0
	}
	echo "inserting $ndecoy decoys..."
	set nlogic [expr int(ceil($ndecoy*$plogic))]
	set ndelay [expr int($ndecoy-$nlogic)]
	
	# insert logic decoys
	echo "inserting $nlogic logic decoys..."
	set logic_decoys [insert_logic_decoys $lib $nlogic $max_fio]

	# insert delay decoys
	echo "inserting $ndelay delay decoys..."
	if {[con_check 1 $lib]} {suspend}
	set delay_decoys [insert_delay_decoys $lib $ndelay]

	# connect latch clock/reset
	echo "adding key logic..."
	set result [connect_latch_clk_rst $lib [concat $orig_lats $logic_decoys $delay_decoys]]
	if {[con_check]} {suspend}
	if {$nlogic>0} {
		syn_map
	}

	# check connections
	if {[con_check]} {suspend}
	
	return $result
}


