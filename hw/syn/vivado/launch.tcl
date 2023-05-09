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
create_bd_cell -type module -reference Vortex_axi vortex_gpu_axi

create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ps
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ps]
set_property -dict [list \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {220} \
  CONFIG.PSU__USE__M_AXI_GP0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {0} \
] [get_bd_cells zynq_ps]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ps/pl_clk0 (214 MHz)} Clk_slave {Auto} Clk_xbar {Auto} Master {/vortex_gpu_axi/m_axi} Slave {/zynq_ps/S_AXI_HP0_FPD} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins zynq_ps/S_AXI_HP0_FPD]
exclude_bd_addr_seg [get_bd_addr_segs zynq_ps/SAXIGP2/HP0_LPS_OCM] -target_address_space [get_bd_addr_spaces vortex_gpu_axi/m_axi]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uart
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ps/pl_clk0 (214 MHz)} Clk_slave {Auto} Clk_xbar {/zynq_ps/pl_clk0 (214 MHz)} Master {/vortex_gpu_axi/m_axi} Slave {/axi_uart/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_uart/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {uart2_pl ( UART ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_uart/UART]
set_property offset 0xFF000000 [get_bd_addr_segs {vortex_gpu_axi/m_axi/SEG_axi_uart_Reg}]
set_property range 128 [get_bd_addr_segs {vortex_gpu_axi/m_axi/SEG_axi_uart_Reg}]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bootrom
set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells axi_bootrom]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ps/pl_clk0 (214 MHz)} Clk_slave {Auto} Clk_xbar {/zynq_ps/pl_clk0 (214 MHz)} Master {/vortex_gpu_axi/m_axi} Slave {/axi_bootrom/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_bootrom/S_AXI]
set_property offset 0x80000000 [get_bd_addr_segs {vortex_gpu_axi/m_axi/SEG_axi_bootrom_Mem0}]


create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 bootrom_data
set_property -dict [list \
  CONFIG.EN_SAFETY_CKT {false} \
  CONFIG.EN_SLEEP_PIN {false} \
  CONFIG.Load_Init_File {false} \
  CONFIG.Memory_Type {Single_Port_ROM} \
] [get_bd_cells bootrom_data]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bootrom/BRAM_PORTA]


set design_file [get_property FILE_NAME [current_bd_design]]
#set_property synth_checkpoint_mode Hierarchical [get_files $design_file]
set_property synth_checkpoint_mode None [get_files $design_file]
generate_target synthesis [get_files  $design_file]

make_wrapper -files [get_files $design_file] -top
add_files -norecurse [get_property BD_OUTPUT_DIR [current_bd_design]]/hdl/fpga_design_wrapper.v
set_property top fpga_design_wrapper [current_fileset]
update_compile_order -fileset sources_1
