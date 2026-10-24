# Generate the clk_wiz_0 MMCM (100 MHz in, one output) in a scratch project
# (SPEC.md section 3, step 7.4). project.sh copies clk_wiz_0.v and
# clk_wiz_0_clk_wiz.v from <work_dir>/clk_wiz_0/ into the project.
#
# Usage: vivado -mode batch -source clk_wiz.tcl -tclargs <work_dir> <part> <out_mhz>

if { [llength $argv] != 3 } {
    puts "ERROR: usage: -tclargs <work_dir> <part> <out_mhz>"
    exit 2
}
lassign $argv work_dir part out_mhz

create_project clk_wiz_gen $work_dir -part $part -force
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_wiz_0 -dir $work_dir
set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $out_mhz \
    CONFIG.USE_PHASE_ALIGNMENT {true} \
] [get_ips clk_wiz_0]
generate_target all [get_ips clk_wiz_0]
close_project
