# Latch Based Logic Locking
This repo contains a Genus implementation of a version of latch-based logic locking along with a set of example circuits. The locking process is outlined in our [paper](https://arxiv.org/abs/2005.10649).

## Running Examples

```make locked/<circuit>.sec``` will synthesize the original circuit and its locked counter-part, then will run a sequential equivalence check to verify the functionality is maintained. The example names correspond to the name of the directories under ```designs```. See the ```makefile``` for more explicit usage. For example ```make locked/s27.lec``` will run the locking and then use a logic equivalence check for verification. 
In this flow, the ```nffs``` (# of flip-flops from the original circuit to convert) and `nbits` (total key bits) parameters can be easily set via ```make```:
```
make locked/gps.v nbits=256 nffs=10
```

## Code Overview

The synthesis script, ```syn.tcl```, is used to run a normal synthesis roughly targeting the maximum frequency for the design. This maximum frequency is found by first targeting a unattainably low period, then relaxing the period to the critical path delay and re-optimizing. 

All locking code is in ```src/lbll.tcl```.  The main function is ```lbll``` which takes in a description of the library gates, a clock to lock, and parameters that specify the amount of locking. This function can be called after the ```syn_map``` command in Genus. 

The ```lbll``` function selects an interconnected set of flip-flops to convert to latches and retime. This is handled by the ```select_ffs``` and ```latch_convert_retime``` sub-functions. The retiming is done using flip-flops as Genus does not support latch retiming out of the box. Subsequently, the function adds two types of decoy latches: delay and logic. The logic decoys will be held at reset under the correct key, enabling the addition of arbitrary logic upstream. The delay decoys will be held open under the correct, enabling further uncertainty to the circuit's function. The decoys are added in the ```insert_logic_decoys``` and ```insert_delay_decoys``` respectively. Finally, to each latch key logic is added that enables controlling of its clock and reset pins using ```connect_latch_clk_rst```.  

## Using Different Libraries and Designs

Currently the repo is set up to use a generic library (```designs/example.lib```). 
To use a different library, change the library path in the synthesis script ```syn.tcl``` and pass ```lbll``` a dictionary that describes the library elements. An example, ```lbll_lib_example```, is shown in ```lbll.tcl```. Additional designs can easily be locked by adding a directory under ```designs``` with the RTL. Make sure the top module name matches the directory name. Also it should be noted that the scripts currently are set up to use a clock named ```clk```. 
