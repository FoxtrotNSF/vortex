
variable myLocation [file normalize [info script]]
set current_dir [file dirname $myLocation]
set out_dir $current_dir/floating_point
#set param_name TUSER_WIDTH
file mkdir $out_dir

dict set fp_ips acl_fdiv [list \
	CONFIG.Operation_Type {Divide} \
  	CONFIG.C_Mult_Usage {No_Usage} \
	CONFIG.C_Has_DIVIDE_BY_ZERO {true} \
	CONFIG.C_Has_OVERFLOW {true} \
	CONFIG.C_Has_UNDERFLOW {true} \
	]

dict set fp_ips acl_fmadd [list \
	CONFIG.Operation_Type {FMA} \
  	CONFIG.C_Mult_Usage {Full_Usage} \
  	CONFIG.Add_Sub_Value {Add} \
	CONFIG.C_Has_OVERFLOW {true} \
	CONFIG.C_Has_UNDERFLOW {true} \
	]
	
dict set fp_ips acl_fsqrt [list \
	CONFIG.Operation_Type {Square_root} \
  	CONFIG.C_Mult_Usage {No_Usage} \
	]

foreach {id params_list} $fp_ips {
	set filename [create_ip -dir $out_dir -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $id -force]
	set_property -dict [list \
	  CONFIG.A_Precision_Type {Single} \
	  CONFIG.A_TUSER_Width {3} \
	  CONFIG.C_A_Exponent_Width {8} \
	  CONFIG.C_A_Fraction_Width {24} \
	  CONFIG.C_Rate {1} \
	  CONFIG.C_Result_Exponent_Width {8} \
	  CONFIG.C_Result_Fraction_Width {24} \
	  CONFIG.Flow_Control {NonBlocking} \
	  CONFIG.Has_ACLKEN {true} \
	  CONFIG.Has_ARESETn {true} \
	  CONFIG.Has_A_TUSER {true} \
	  CONFIG.Has_RESULT_TREADY {false} \
	  CONFIG.Result_Precision_Type {Single} \
	  CONFIG.C_Has_INVALID_OP {true} \
	] [get_ips $id]
	set_property -dict $params_list [get_ips $id]
	set_property generate_synth_checkpoint false [get_files $filename]
	generate_target {synthesis} [get_files $filename]
	#set module_file $out_dir/$id/synth/[set id].v
	#set n [exec awk /input.*s_axis_a_tuser/\{gsub(/.*\\\[|\\:.*/,\"\")\;x=\$0\}/output.*m_axis_result_tuser/\{gsub(/.*\\\[|\\:.*/,\"\")\;n=\$0-x-1\}END\{print\ n\} $module_file]
	#exec sed -i /m_axis_result_tuser/s/\\\[.*\\\]/\\\[$param_name+$n\ :\ 0\\\]/ $module_file
	#exec sed -i /s_axis_a_tuser/s/\\\[.*\\\]/\\\[$param_name-1\ :\ 0\\\]/ $module_file
	#exec sed -i /C_A_TUSER_WIDTH/s/(.*)/\\($param_name\\)/ $module_file
	#exec sed -i /C_RESULT_TUSER_WIDTH/s/(.*)/\\($param_name+$n\\)/ $module_file
	#exec sed -i /\ *)\;/\{s//)\;\\nparameter\ $param_name\ =\ 1\;/\;:a\;n\;ba\} $module_file
	#exec sed -i /DO\ NOT\ MODIFY\ THIS\ FILE/a//\ FILE\ MODIFIED\ AUTOMATICALLY\ TO\ ADD\ $param_name\ GENERIC\ PARAMETER,\ SORRY\ XILINX $module_file
}

#n=$(awk '/input.* s_axis_a_tuser/ {gsub(/.*\[|\:.*/, ""); x=$0} /output.* m_axis_result_tuser/ {gsub(/.*\[|\:.*/, ""); n=$0-x} END{print n}' acl_div_test.v)
#sed -i -e "/m_axis_result_tuser/s/\[.*\]/\[$param_name+$n : 0\]/" -e "/s_axis_a_tuser/s/\[.*\]/\[$param_name : 0\]/" -e "/C_A_TUSER_WIDTH/s/(.*)/\($param_name\)/" -e "/C_RESULT_TUSER_WIDTH/s/(.*)/\($param_name+$n\)/" acl_div_test.v
#sed -i "/ *);/{s//);\nparameter $param_name;/;:a;n;ba}" acl_div_test.v

