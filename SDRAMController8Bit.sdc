#**************************************************************
# Time Information
#**************************************************************
set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************
#derive_clock_uncertainty
#create_clock   -name data_clk   -period 200Mhz [get_ports data_clk ]
#create_clock   -name sdram_clk  -period 130Mhz [get_ports sdram_clk]


#**************************************************************
# Create Generated Clock
#**************************************************************
 # create_generated_clock -name DRAM_CLK  -invert -source  [get_ports {sdram_clk}]  [get_ports {DRAM_CLK}]  
 #create_generated_clock -name DRAM_CLK  -source  [get_ports {sdram_clk}]  [get_ports {DRAM_CLK}]  

#**************************************************************
# Set Clock Latency
#**************************************************************

#**************************************************************
# Set Clock Uncertainty 
#**************************************************************
derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************
#set_input_delay   -clock [get_clocks {DRAM_CLK}] -max 5.400 [get_ports {DRAM_DQ[*]}]
#set_input_delay   -clock [get_clocks {DRAM_CLK}] -min 2.500 [get_ports {DRAM_DQ[*]}]


create_clock -period 50MHz -name sd_CLK [get_ports {clk}]
set_input_delay   -clock [get_clocks {sd_CLK}] -max 5.400 [get_ports {sd_D[*]}]
set_input_delay   -clock [get_clocks {sd_CLK}] -min 2.000 [get_ports {sd_D[*]}]

#**************************************************************
# Set Output Delay
#**************************************************************

set sdram_outputs [get_ports {
  sd_A[*]
  sd_BS0
  sd_BS1
  sd_RAS_NOT
  sd_CAS_NOT
  sd_WE_NOT
  sd_D[*]
}]

#set_output_delay   -clock DRAM_CLK -max  1.500   $sdram_outputs
#set_output_delay   -clock DRAM_CLK -min  0.800   $sdram_outputs
set_output_delay   -clock sd_CLK -max  1.500   $sdram_outputs
set_output_delay   -clock sd_CLK -min  0.800   $sdram_outputs

#**************************************************************
# Set Clock Groups
#**************************************************************
#set_clock_groups   -exclusive                      \
#				   -group {clkA sdram_clk DRAM_CLK}\
#				   -group {clkB data_clk          }
# set_clock_groups -exclusive -group {sdram_clk} -group {DRAM_CLK}

#**************************************************************
# Set False Path
#**************************************************************
set_false_path -from [get_clocks {sd_CLK}] -to [get_ports {
	sd_BS0 
	sd_BS1 
	sd_CKE 
	sd_CKE
	led1
	led2
	led3
	led4
	led5
	led6
	led7
	led8
	sd_UDQM
	sd_LDQM
}]


#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************
