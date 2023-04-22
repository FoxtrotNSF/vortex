variable myLocation [file normalize [info script]]
set current_dir [file dirname $myLocation]
set build_dir $current_dir
set src_dir [set build_dir]/../../rtl
create_project vortex_axi $build_dir/vortex_axi -part xczu7ev-ffvc1156-2-e
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]
set_property simulator_language Verilog [current_project]

add_files -scan_for_includes -norecurse [list $src_dir $src_dir/cache $src_dir/fp_cores $src_dir/interfaces $src_dir/libs]

set_property top Vortex_axi [current_fileset]
set_property FILE_TYPE Verilog [get_files -all $src_dir/Vortex_axi.sv]
set_property verilog_define [list XILINX SYNTHESIS] [current_fileset]

source $build_dir/script_generate_fu.tcl -notrace
update_compile_order -fileset [current_fileset]


create_bd_design "fpga_design"
create_bd_cell -type module -reference Vortex_axi Vortex_axi_0
create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0

set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_pins /Vortex_axi_0/reset]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {ddr4_sdram ( DDR4 SDRAM ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_DDR4]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {clk_300mhz ( Programmable Differential Clock (300MHz) ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
set_property CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {200} [get_bd_cells ddr4_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/ddr4_0/addn_ui_clkout1 (200 MHz)} Clk_slave {/ddr4_0/c0_ddr4_ui_clk (266 MHz)} Clk_xbar {Auto} Master {/Vortex_axi_0/m_axi} Slave {/ddr4_0/C0_DDR4_S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( FPGA Reset ) } Manual_Source {New External Port (ACTIVE_HIGH)}}  [get_bd_pins ddr4_0/sys_rst]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( FPGA Reset ) } Manual_Source {Auto}}  [get_bd_pins rst_ddr4_0_200M/ext_reset_in]

set design_file [get_property FILE_NAME [current_bd_design]]
#set_property synth_checkpoint_mode Hierarchical [get_files $design_file]
set_property synth_checkpoint_mode None [get_files $design_file]
generate_target synthesis [get_files  $design_file]

make_wrapper -files [get_files $design_file] -top
add_files -norecurse [get_property BD_OUTPUT_DIR [current_bd_design]]/hdl/fpga_design_wrapper.v
set_property top fpga_design_wrapper [current_fileset]
update_compile_order -fileset sources_1
