
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

##################### lbll #####################
# args
set nffs 10

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

set or_type "or2"
set or_i0 "A"
set or_i1 "B"
set or_o "Y"

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

## setup networkx graph
#set python_graph {}
#set ffs [get_db insts -if .is_flop]
#foreach ff $ffs {
#	set output [get_db $ff .pins -if .direction==out]
#	set fo_ffs [get_db [all_fanout -from $output -only_cells -endpoints_only]]
#	foreach fo_ff $fo_ffs {
#		lappend python_graph "g.add_edge(\'$ff\', \'$fo_ff\')"
#	}
#}
#
#set script "import networkx as nx
#from networkx.algorithms.community import asyn_fluidc
#
## get interconnected flops
#g = nx.Graph()
#[join $python_graph "\n"]
#
## get largest connected section
#con = max(nx.connected_components(g), key=len)
#sg = g.subgraph(con).copy()
#
## get communities
#k = int(len(sg)/$nflop)
#communities = asyn_fluidc(sg,k)
#flops = next(communities)
#min_diff = abs(len(flops)-$nflop)
#while min_diff:
#	try:
#		next_flops = next(communities)
#	except StopIteration:
#		break
#	if abs($nflop-len(next_flops)) < min_diff:
#		flops = next_flops
#		min_diff = abs($nflop-len(next_flops))
#print(flops)"
#
#set loops [exec python3 -c $script]
#set selected_ffs [lindex [string map {"\[" "\{" "\]" "\}" "," "" "'" ""} $loops] 0]
#set not_selected_ffs {}
#foreach ff $ffs {
#	if {[lsearch -exact $selected_ffs $ff] == -1} {
#		lappend not_selected_ffs $ff
#	}
#}

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
report_timing -to *F1 -nworst 100
suspend
create_clock -period $period clk

## switch to latches
set key ""
set i 0
set retimed_ffs [concat [get_db insts *_F1*] [get_db insts *_F0*]]
foreach ff $retimed_ffs {
	echo "replacing: [get_db $ff .base_cell.name] with $lat_type"

	if {[string first "_F0" $ff] != -1} {
		set lat_name orig_lat_L0_$i 
	} else {
		set lat_name orig_lat_L1_$i
	}
	
	# create instances
	set xor [create_inst $xor_type -name "lbll_key_xor_$i" $top]
	set lat [create_inst $lat_type -name $lat_name $top]
	set or_rst [create_inst $or_type -name "lbll_or_rst_$i" $top]
	set or_clk [create_inst $or_type -name "lbll_or_clk_$i" $top]
	set and [create_inst $and_type -name "lbll_and_$i" $top]
	set inv [create_inst $inv_type -name "lbll_inv_$i" $top]

	# connect latch
	set key_port [get_db ports *lbll_resetClear_key\[$i\]]
	set reset_key_port [get_db ports *lbll_resetClear_key\[[expr $i+1]\]]
	connect [get_db $lat .pins -if .base_name==Q] [get_db $ff .pins -if .base_name==Q]
	connect [get_db $lat .pins -if .base_name==D] [get_db $ff .pins -if .base_name==D]
	connect [get_db $xor .pins -if .base_name==A] [get_db $ff .pins -if .base_name==CK]
	connect [get_db $xor .pins -if .base_name==B] $key_port
	connect [get_db $xor .pins -if .base_name==Y] [get_db $or_clk .pins -if .base_name==A]
	connect [get_db $lat .pins -if .base_name==G] [get_db $or_clk .pins -if .base_name==Y]
	connect [get_db $and .pins -if .base_name==Y] [get_db $or_clk .pins -if .base_name==B]
	connect [get_db $and .pins -if .base_name==A] $key_port
	connect [get_db $and .pins -if .base_name==B] [get_db $inv .pins -if .base_name==Y]
	connect [get_db $inv .pins -if .base_name==A] $reset_key_port
	connect [get_db $lat .pins -if .base_name==RN] [get_db $or_rst .pins -if .base_name==Y]
	connect [get_db $or_rst .pins -if .base_name==A] $reset_key_port
	connect [get_db $or_rst .pins -if .base_name==B] $key_port
	delete_obj $ff

	# set the appropriate key bit based on latch order
	if {[string first "L0" $lat_name]!=-1} {
		set_case_analysis 1 $key_port
		set_case_analysis 1 $reset_key_port
		set key "1${key}"
		set key "1${key}"
	} else {
		set_case_analysis 0 $key_port
		set_case_analysis 1 $reset_key_port
		set key "0${key}"
		set key "1${key}"
	}
	incr i 2
}







#syn_map
#syn_opt


#exit

