proc genFPCore {corename propertyList} {
	set coredir "./u50"
	file mkdir $coredir
	if [file exists ./$coredir/$corename] {
		file delete -force ./$coredir/$corename
	}

	create_project -name local_synthesized_ip -in_memory -part xcu50-fsvh2104-2-e
	create_ip -name floating_point -version 7.1 -vendor xilinx.com -library ip -module_name $corename -dir ./$coredir
	set_property -dict $propertyList [get_ips $corename]

	generate_target {instantiation_template} [get_files ./$coredir/$corename/$corename.xci]
	generate_target all [get_files  ./$coredir/$corename/$corename.xci]
	create_ip_run [get_files -of_objects [get_fileset sources_1] ./$coredir/$corename/$corename.xci]
	generate_target {Synthesis} [get_files  ./$coredir/$corename/$corename.xci]
	read_ip ./$coredir/$corename/$corename.xci
	synth_ip [get_ips $corename]
}

genFPCore "fp_fma32" [list CONFIG.A_Precision_Type {Single} CONFIG.Add_Sub_Value {Both} CONFIG.C_A_Exponent_Width {8} CONFIG.C_A_Fraction_Width {24} CONFIG.C_Latency {17} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.C_Rate {1} CONFIG.C_Result_Exponent_Width {8} CONFIG.C_Result_Fraction_Width {24} CONFIG.Operation_Type {FMA} CONFIG.Result_Precision_Type {Single} ] 
genFPCore "fp_add32" [list CONFIG.Operation_Type {Add_Subtract} CONFIG.Add_Sub_Value {Add} CONFIG.C_Latency {12} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {Blocking} CONFIG.Has_RESULT_TREADY {true}]
genFPCore "fp_exp32" [list CONFIG.A_Precision_Type {Single} CONFIG.C_A_Exponent_Width {8} CONFIG.C_A_Fraction_Width {24} CONFIG.C_Latency {21} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.C_Rate {1} CONFIG.C_Result_Exponent_Width {8} CONFIG.C_Result_Fraction_Width {24} CONFIG.Flow_Control {Blocking} CONFIG.Has_RESULT_TREADY {true} CONFIG.Operation_Type {Exponential} CONFIG.Result_Precision_Type {Single}]
