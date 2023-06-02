variable myLocation [file normalize [info script]]
set current_dir [file dirname $myLocation]
set project_dir $current_dir/../../..
set build_dir $project_dir/vortex_axi
set src_dir $current_dir/../../rtl
set verilog_sources [list $src_dir $src_dir/cache $src_dir/fp_cores $src_dir/interfaces $src_dir/libs]
set top_file $src_dir/Vortex_axi.sv

create_project vortex_axi $build_dir -part xczu7ev-ffvc1156-2-e
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]
set_property simulator_language Verilog [current_project]

add_files -scan_for_includes -norecurse $verilog_sources

set_property top Vortex_axi [current_fileset]
set_property FILE_TYPE Verilog [get_files -all $top_file]
set_property verilog_define [list XILINX SYNTHESIS] [current_fileset]

source $current_dir/script_generate_fu.tcl -notrace
update_compile_order -fileset [current_fileset]


create_bd_design "fpga_design"
create_bd_cell -type module -reference Vortex_axi vortex_gpu_axi
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_pins /vortex_gpu_axi/reset]

create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_src
set_property -dict [list \
  CONFIG.AUTO_PRIMITIVE {PLL} \
  CONFIG.CLKIN1_JITTER_PS {33.330000000000005} \
  CONFIG.CLKOUT1_DRIVES {Buffer} \
  CONFIG.CLKOUT1_JITTER {105.463} \
  CONFIG.CLKOUT1_PHASE_ERROR {107.936} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250} \
  CONFIG.CLKOUT2_DRIVES {Buffer} \
  CONFIG.CLKOUT3_DRIVES {Buffer} \
  CONFIG.CLKOUT4_DRIVES {Buffer} \
  CONFIG.CLKOUT5_DRIVES {Buffer} \
  CONFIG.CLKOUT6_DRIVES {Buffer} \
  CONFIG.CLKOUT7_DRIVES {Buffer} \
  CONFIG.CLK_IN1_BOARD_INTERFACE {clk_300mhz} \
  CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
  CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {5} \
  CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
  CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {3} \
  CONFIG.MMCM_COMPENSATION {AUTO} \
  CONFIG.MMCM_DIVCLK_DIVIDE {2} \
  CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
  CONFIG.PRIMITIVE {Auto} \
  CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
  CONFIG.USE_LOCKED {false} \
  CONFIG.USE_RESET {false} \
] [get_bd_cells clk_src]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {clk_300mhz ( Programmable Differential Clock (300MHz) ) } Manual_Source {Auto}}  [get_bd_intf_pins clk_src/CLK_IN1_D]


create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ps
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ps]
set_property -dict [list \
  CONFIG.PSU__USE__M_AXI_GP0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {0} \
  CONFIG.PSU__USE__FABRIC__RST {0} \
  CONFIG.PSU__FPGA_PL0_ENABLE {0} \
  CONFIG.PSU__USE__IRQ0 {0} \
] [get_bd_cells zynq_ps]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_src/clk_out1 (250 MHz)} Clk_slave {Auto} Clk_xbar {Auto} Master {/vortex_gpu_axi/m_axi} Slave {/zynq_ps/S_AXI_HP0_FPD} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins zynq_ps/S_AXI_HP0_FPD]
set_property CONFIG.RESET_BOARD_INTERFACE {reset} [get_bd_cells rst_clk_src_250M]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( FPGA Reset ) } Manual_Source {Auto}}  [get_bd_pins rst_clk_src_250M/ext_reset_in]

exclude_bd_addr_seg [get_bd_addr_segs zynq_ps/SAXIGP2/HP0_LPS_OCM] -target_address_space [get_bd_addr_spaces vortex_gpu_axi/m_axi]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uart

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_src/clk_out1 (250 MHz)} Clk_slave {/clk_src/clk_out1 (250 MHz)} Clk_xbar {/clk_src/clk_out1 (250 MHz)} Master {/vortex_gpu_axi/m_axi} Slave {/axi_uart/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_uart/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {uart2_pl ( UART ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_uart/UART]
set_property CONFIG.C_BAUDRATE {115200} [get_bd_cells axi_uart]

set_property offset 0xFF000000 [get_bd_addr_segs {vortex_gpu_axi/m_axi/SEG_axi_uart_Reg}]
set_property range 128 [get_bd_addr_segs {vortex_gpu_axi/m_axi/SEG_axi_uart_Reg}]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bootrom
set_property -dict [list \
    CONFIG.DATA_WIDTH {512} \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.RD_CMD_OPTIMIZATION {1} \
    CONFIG.SINGLE_PORT_BRAM {0} \
] [get_bd_cells axi_bootrom]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_src/clk_out1 (250 MHz)} Clk_slave {Auto} Clk_xbar {/zynq_ps/pl_clk0 (214 MHz)} Master {/vortex_gpu_axi/m_axi} Slave {/axi_bootrom/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_bootrom/S_AXI]
set_property offset 0x80000000 [get_bd_addr_segs {vortex_gpu_axi/m_axi/SEG_axi_bootrom_Mem0}]


create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 bootrom_data
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "/bootrom_data" }  [get_bd_intf_pins axi_bootrom/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "/bootrom_data" }  [get_bd_intf_pins axi_bootrom/BRAM_PORTB]
validate_bd_design
set_property -dict [list \
  CONFIG.Assume_Synchronous_Clk {true} \
  CONFIG.EN_SAFETY_CKT {false} \
  CONFIG.EN_SLEEP_PIN {false} \
  CONFIG.Memory_Type {Dual_Port_ROM} \
  CONFIG.PRIM_type_to_Implement {BRAM} \
  CONFIG.use_bram_block {BRAM_Controller} \
  CONFIG.Coe_File $current_dir/bootrom/bootrom.coe \
  CONFIG.Load_Init_File {true} \
] [get_bd_cells bootrom_data]

# ILA Debug
set_property HDL_ATTRIBUTE.DEBUG true [get_bd_intf_nets {vortex_gpu_axi_m_axi axi_smc_M01_AXI}]
apply_bd_automation -rule xilinx.com:bd_rule:debug -dict [list \
  [get_bd_intf_nets axi_smc_M01_AXI] {AXI_R_ADDRESS "Data and Trigger" AXI_R_DATA "Data and Trigger" AXI_W_ADDRESS "Data and Trigger" AXI_W_DATA "Data and Trigger" AXI_W_RESPONSE "Data and Trigger" CLK_SRC "/clk_src/clk_out1" SYSTEM_ILA "Auto" APC_EN "0" } \
  [get_bd_intf_nets vortex_gpu_axi_m_axi] {AXI_R_ADDRESS "Data and Trigger" AXI_R_DATA "Data and Trigger" AXI_W_ADDRESS "Data and Trigger" AXI_W_DATA "Data and Trigger" AXI_W_RESPONSE "Data and Trigger" CLK_SRC "/clk_src/clk_out1" SYSTEM_ILA "Auto" APC_EN "0" } \
]
# ILA Debug

set design_file [get_property FILE_NAME [current_bd_design]]
#set_property synth_checkpoint_mode Hierarchical [get_files $design_file]
set_property synth_checkpoint_mode None [get_files $design_file]
generate_target synthesis [get_files  $design_file]

make_wrapper -files [get_files $design_file] -top
add_files -norecurse [get_property BD_OUTPUT_DIR [current_bd_design]]/hdl/fpga_design_wrapper.v
set_property top fpga_design_wrapper [current_fileset]
update_compile_order -fileset sources_1
