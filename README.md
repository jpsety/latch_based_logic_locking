# latch_based_logic_locking
This repo contains a Genus implementation of a version of latch-based logic locking along with an example circuit.

```make equiv``` will synthesize the original circuit and its locked counter-part, then will run an equivalence check
to verify the functionality is maintained. 

All locking code is in ```lbll.tcl```. Currently the repo is set up to use a generic library (```designs/example.lib```). 
To use a different library, change the library path in the synthesis script ```syn.tcl``` and pass ```lbll``` a dictionary that describes the library elements. An example, ```lbll_lib_example```, is shown in ```lbll.tcl```. 
