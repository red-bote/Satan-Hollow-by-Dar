# Build the bitstream from the tracked project (SPEC.md section 4).
#
# Usage: vivado -mode batch -source build.tcl -tclargs <xpr>

if { [llength $argv] != 1 } {
    puts "ERROR: usage: -tclargs <xpr>"
    exit 2
}
set xpr [lindex $argv 0]

open_project $xpr
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set progress [get_property PROGRESS [get_runs impl_1]]
close_project
if { $progress ne "100%" } {
    puts "ERROR: implementation/bitstream failed (PROGRESS $progress)"
    exit 1
}
