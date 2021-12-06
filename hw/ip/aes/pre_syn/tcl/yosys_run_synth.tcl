# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

source ./tcl/yosys_common.tcl

if { $lr_synth_flatten } {
  set flatten_opt "-flatten"
} else {
  set flatten_opt ""
}

if { $lr_synth_timing_run } {
  write_sdc_out $lr_synth_sdc_file_in $lr_synth_sdc_file_out
}

yosys "read_verilog -sv $lr_synth_out_dir/generated/*.v"

# Set top-module parameters.
# When synthesizing a sub module such as an individual S-Box, some parameters might not exist.
# You can use
#    yosys "chparam -list $lr_synth_top_module"
# To print the available parameters.
if { $lr_synth_top_module != "aes_sbox" && $lr_synth_top_module != "aes_sub_bytes" && $lr_synth_top_module != "aes_reduced_round"} {
  yosys "chparam -set AES192Enable $lr_synth_aes_192_enable $lr_synth_top_module"
  yosys "chparam -set Masking $lr_synth_masking $lr_synth_top_module"
}
yosys "chparam -set SBoxImpl $lr_synth_s_box_impl $lr_synth_top_module"

# Remap Xilinx Vivado "keep" attributes to Yosys style.
yosys "attrmap -tocase keep -imap keep=\"true\" keep=1 -imap keep=\"false\" keep=0 -remove keep=0"

# Synthesize.
yosys "synth -nofsm $flatten_opt -top $lr_synth_top_module"
yosys "opt -purge"

yosys "write_verilog $lr_synth_pre_map_out"

yosys "dfflibmap -liberty $lr_synth_cell_library_path"
yosys "opt"

set yosys_abc_clk_period [expr $lr_synth_clk_period - $lr_synth_abc_clk_uprate]

if { $lr_synth_timing_run } {
  yosys "abc -liberty $lr_synth_cell_library_path -constr $lr_synth_abc_sdc_file_in -D $yosys_abc_clk_period"
} else {
  yosys "abc -liberty $lr_synth_cell_library_path"
}

yosys "clean"
yosys "write_verilog $lr_synth_netlist_out"

if { $lr_synth_timing_run } {
  # Produce netlist that OpenSTA can use
  yosys "setundef -zero"
  yosys "splitnets"
  yosys "clean"
  yosys "write_verilog -noattr -noexpr -nohex -nodec $lr_synth_sta_netlist_out"
}

yosys "check"
yosys "log ======== Yosys Stat Report ========"
yosys "tee -o $lr_synth_out_dir/reports/area.rpt stat -liberty $lr_synth_cell_library_path"
yosys "log ====== End Yosys Stat Report ======"

