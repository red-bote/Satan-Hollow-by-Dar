# Create an empty Basys3 Vivado project: the baseline the .xpr patch applies to
# (SPEC.md section 3, step 7.1).
#
# Usage: vivado -mode batch -source empty_project.tcl \
#            -tclargs <proj_dir> <name> <part>

if { [llength $argv] != 3 } {
    puts "ERROR: usage: -tclargs <proj_dir> <name> <part>"
    exit 2
}
lassign $argv proj_dir name part

create_project $name $proj_dir -part $part
set_property board_part digilentinc.com:basys3:part0:1.2 [current_project]
set_property target_language VHDL [current_project]
close_project
