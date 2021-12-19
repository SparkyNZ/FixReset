package require Tcl 8.3
##############################################################################################
############################# Basic vJTAG Interface ##########################################
##############################################################################################


set PRESENCE_TESTNO 5 

set BYPASS     15
set IDCODE      1
set READREG     2
set SETREGISTER 3
set RUNTEST     4
set PRESENCE    5
set SETTEST     6
set WRITEREG    7
set READTXT     8
set SETTXTIDX   9
set WRITETXT   10
set RESET_HI_CMD 11
set RESET_LO_CMD 12
set READREG2     13
set SELTEST      14

# My register indices
set REG_CURRSTATE   0
set REG_ADDRESS     1
set REG_WRITE_VAL   2
set REG_WRITE_COUNT 3
set REG_READ_VAL    4
set REG_LAST_REQ    5


set SKIPRUN 0


#This portion of the script is derived from some of the examples from Altera, and from the 
#rather nice writeup by Chris on the DE0 at http://idlelogiclabs.com
#http://idlelogiclabs.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/
 
global usbblaster_name
global test_device

# List all available programming hardwares, and select the USBBlaster.
# (Note: this example assumes only one USBBlaster connected.)
# Programming Hardwares:
foreach hardware_name [get_hardware_names] {
#   puts $hardware_name
    if { [string match "USB-Blaster*" $hardware_name] } {
        set usbblaster_name $hardware_name
    }
}
 
puts "Using JTAG chain from $usbblaster_name.";
 
foreach device_name [get_device_names -hardware_name $usbblaster_name] {
    if { [string match "@1*" $device_name] } {
        set test_device $device_name
    }
}
puts "Connecting to FPGA JTAG fabric: $test_device.\n";
 
proc openport {} {
    global usbblaster_name
        global test_device
    open_device -hardware_name $usbblaster_name -device_name $test_device
}
 
proc closeport { } {
    catch {device_unlock}
    catch {close_device}
}

proc userinput {} {
  global SKIPRUN
  
	help
    while {1 == 1} {	
	puts -nonewline "\n> "
		set cmd [string toupper [gets stdin]]
		set items [split $cmd " "]
		switch [lindex $items 0] {
			IDCODE {
				idcode
			}
			BASICRW {
				basicrw
			}
			BASICRWP {
				basicrwp
			}
			READ {
				read [lindex $items 1]
			}
			READBULK {
				readbulk
			}
			DEADWRITE {
				deadwrite
			}
			WRITEVALUE {
				writevalue [lindex $items 1]
			}
			SEQUENCE {
				sequence
			}	
			PUSHFILE {
				pushfile [lindex $items 1]
			}				
			DUMPREG {
				dumpreg [lindex $items 1]
			}
			PRESENCE {
				presence
			}
      # PDS>
      REGS {
        #setRegister 0 7
        #setRegister 1 13
        #setRegister 2 255

        set val [readRegister 0]
        puts -nonewline [format "REG0 CURRSTATE: %s %s %s " $val [bin2hex $val] [bin2dec $val] ]
        tbState [bin2dec $val]
        
        set val [readRegister 1]
        puts [format "REG1 ADDRESS  : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readRegister 2]
        puts [format "REG2 WRITEVAL : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readRegister 3]
        puts [format "REG3 WRITE CNT: %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readRegister 4]
        puts [format "REG4 READ VAL : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readRegister 5]
        puts [format "REG5 PROMPT_ID: %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readRegister 6]
        puts [format "REG6 CHAROFSET: %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readRegister 7]
        puts [format "REG7 LAST REQ : %s %s %s" $val [bin2hex $val] [bin2dec $val]]

        set val [readSRRegister 0]
        puts [format "SRAM READ OK  : %s %s %s" $val [bin2hex $val] [bin2dec $val]]

        set val [readSRRegister 1]
        puts -nonewline [format "SRAM CSM STATE: %s %s %s " $val [bin2hex $val] [bin2dec $val]]
        csmState [bin2dec $val]

        set val [readSRRegister 2]
        puts -nonewline [format "SRAM RSM STATE: %s %s %s " $val [bin2hex $val] [bin2dec $val]]
        rsmState [bin2dec $val]
        
        set val [readSRRegister 3]
        puts [format "SRAM REPEATS  : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readSRRegister 4]
        puts [format "SRAM READS    : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readSRRegister 5]
        puts [format "SRAM CMDWRITE : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readSRRegister 6]
        puts [format "SRAM CMDADDR  : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readSRRegister 7]
        puts [format "FIFO CMD HI   : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readSRRegister 8]
        puts [format "FIFO CMD LO   : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readSRRegister 9]
        puts [format "COMMAND  HI   : %s %s %s" $val [bin2hex $val] [bin2dec $val]]
        set val [readSRRegister 10]
        puts [format "COMMAND  LO   : %s %s %s" $val [bin2hex $val] [bin2dec $val]]

      }
      TEST1 {
        # PDS>
        #set hex "00007777"
        #binary scan [binary format H* $hex] B* bits
        #puts $bits
        
        #set bin "11101010"
        #binary scan [binary format B* $bin] H* hexdigits
        #puts $hexdigits
        
        #set bin "1110101011111111"
        #binary scan [binary format B* $bin] H* hexdigits
        #puts [string toupper $hexdigits]
      
        runTest 1
        set val [readRegister 0]
        puts [format "REG0: %s %s" $val [bin2hex $val] ]
        
      }
      TEST2 {
        runTest 2
        set val [readRegister 0]
        puts [format "REG0: %s %s" $val [bin2hex $val] ]

      }
      TEST3 {
        runTest 3
        set val [readRegister 0]
        puts [format "REG0: %s %s" $val [bin2hex $val] ]
      }
      TEST4 {
        runTest 4
        set val [readRegister 0]
        puts [format "REG0: %s %s" $val [bin2hex $val] ]
      }
      TEXTO {
        setText 0 65
      }
      TEXTI {
        readAndPrintText
      }
      MANUAL {
        set SKIPRUN 1
      }
      AUTO {
        set SKIPRUN 0
      }
      SELTEST {
        seltest [lindex $items 1]
      }
      
      SETREG {
        # reg value
        setRegister [lindex $items 1] [lindex $items 2]
      }
      
      W0 {
        # Write a value to address 0
        # val
        writeMem  0 [lindex $items 1] 1
        
        if { $SKIPRUN == 0 } {
          after 500
          readAndPrintText
        }
      }
      
      WRITEMEMNORUN {
        # address val count
        writeMemNoRun [lindex $items 1] [lindex $items 2] 1
      }      
      
      WRITEMEM {
        # address val count
        writeMem  [lindex $items 1] [lindex $items 2] 1
        if { $SKIPRUN == 0 } {
          after 500
          readAndPrintText
        }
      }
      R0 {
        readMem  0
        if { $SKIPRUN == 0 } {
          after 500
          readAndPrintText
        }
      }      
      READMEM {
        readMem  [lindex $items 1]
        if { $SKIPRUN == 0 } {
          after 500
          readAndPrintText
        }
      }      
      WRITECHK {
        # address val count
        writeMem  [lindex $items 1] [lindex $items 2] 1
        after 500
        readAndPrintText
        readMem  [lindex $items 1]
        after 500
        readAndPrintText        
      }
      W0A {
          writeMem  0 255 1
      }

      BUG {
          #writeMem  0 255 1
          #readAndPrintText 
          #after 1000
          readMem  0
          after 50
          readAndPrintText                                
      }
      
      RW {
          writeMem  0 255 1
          readAndPrintText 
          after 50
          readMem  0
          after 50
          readAndPrintText                      

          writeMem  0 119 1
          readAndPrintText 
          after 50
          readMem  0
          after 50
          readAndPrintText                      
      }
      CHKALL {
        for {set i 1} {$i < 4} {incr i} {  
          writeMem  0 $i 1
          readAndPrintText 
          after 50
          readMem  0
          after 50
          readAndPrintText                
        }
      }
      PROMPT {
        prompt  [lindex $items 1]
        after 500
        readAndPrintText
      }
      RESET {
		reset
      }
      
			HELP {
				help
			}
			QUIT {
				puts "Ok. Daisy, Daisy....."
				break
			}
      SELECTONLY {
        selectonly [lindex $items 1]
      }
      
			default {				
				puts "Talk sense man - or I'll set Crem on you."
			}
		}			
	}
    closeport
}

proc selectonly testno {
  global SETTEST
  
	#Go to set instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $SETTEST
	#push in test value
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $testno 32]  
}


proc seltest testno {
  global SETTEST
  global SELTEST
  
	#Go to set instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $SETTEST
	#push in test value
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $testno 32]  
	
  device_virtual_ir_shift -instance_index 0 -ir_value $SELTEST
}


#--------------------- reset ---------------------
proc reset {} {
	# Toggle reset signal
	global RESET_LO_CMD
	global RESET_HI_CMD

	device_virtual_ir_shift -instance_index 0 -ir_value $RESET_LO_CMD
	setJTAGBypass        
	after 2000
	device_virtual_ir_shift -instance_index 0 -ir_value $RESET_HI_CMD
	setJTAGBypass        
}

#--------------------- TEXT ---------------------
proc readAndPrintText {} {
  set textLen [bin2dec [readText 0]]
  
  for {set i 1} {$i < $textLen} {incr i} {  
    set val [bin2dec [readText $i]]
    if { $val == 13 } {
      
    } elseif { $val == 10 } {
      
    } else {
      puts -nonewline [format "%c" $val ]
    }
  }
  puts ""
}

proc help {} {
	puts "************************************"	
	puts "SDRAM Test Suite Control Script v1.0"	
	puts "Valid commands:"
	puts "    IDCODE"
	#puts "    DUMPREG \[number\]"
  puts "**  REGS"
	puts "    BASICRW"
	puts "    PRESENCE"
	puts "    READ"
	puts "    READBULK"
	puts "    WRITEVALUE \[value\]"
	puts "    DEADWRITE"
	puts "    BASICRWP"
	puts "    SEQUENCE"
	puts "    HELP"
	puts "    QUIT"
	puts "************************************"
}

proc idcode {} {
    device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value
    set tdi [device_virtual_dr_shift -instance_index 0 -dr_value [dec2bin 0 32] -length 32] 	
    setJTAGBypass 
    puts "Device ID: $tdi"
}

proc pushfile { fileName } {
     # Open the file, and set up to process it in binary mode.

     set f [open $fileName r]
     fconfigure $f \
         -translation binary \
         -encoding binary \
         -buffering full -buffersize 16384

     while { 1 } {
         set s [read $f 8]
         # Convert the data to hex and to characters.
         binary scan $s c value
         puts [format {%08x} $value ]
         # Stop if we've reached end of file
         if { [string length $s] == 0 } {
             break
         }
     }
     # When we're done, close the file.
     close $f
}

proc presence {} {	
	#Light toggle instruction.
  global PRESENCE_TESTNO
	device_virtual_ir_shift -instance_index 0 -ir_value $PRESENCE_TESTNO
	setJTAGBypass
}

proc writevalue value {
	puts "Write input value $value to first address."
	puts "Mem clock @133Mhz CAS3"

	setRegister 0 0
	setRegister 1 $value
	runTest 4
	
	# Set IR back to 0, which is bypass mode
	setJTAGBypass
}

proc deadwrite {} {
	puts "Write brokenbarberpole to first address."
	puts "Mem clock @133Mhz CAS3"
		
	set tdi [readRegister 0]
	puts "REG:  $tdi"	

	runTest 2
	
	# Set IR back to 0, which is bypass mode
	setJTAGBypass
}

proc read address {
	puts "Read address $address"
	puts "Mem clock @133Mhz CAS3"
		
	setParameter 0 $address
	runTest 3	
	setJTAGBypass
	set tdi [readRegister 0]	
	puts "REG:  $tdi"
}

proc readbulk {} {
	for {set i 0} {$i < 8} {incr i} {
		setRegister 0 $i
		runTest 3	
		setJTAGBypass
		set tdi [readRegister 0]
		puts -nonewline " $tdi "
		if {$i % 2 == 1} {puts ""}
	}
}


proc sequence {} {
	puts "Whole memory write with address values, then verified with read."
	puts "Mem clock @133Mhz CAS3"
	
	set tdi [readRegister 0]
	puts "REG:  $tdi"
		
	runTest 5
	
	puts "Test run - 1 Second delay..."
	after 1000
	puts "Performing fetch, good luck."
		
	set tdi [readRegister 0]	
	set memloc [readRegister 1] 
	
	puts "Test complete."
	puts "REG0:  $tdi"
	puts "REG1:  $memloc"
	if {$tdi == "1"} {
		puts "**TEST PASSED**"
	} else {
		puts "**TEST FAILED**"
	}
	setJTAGBypass
}


proc basicrwp {} {
	puts "Basic write, followed by read. (Single address, persisted 15secs with a broken barberpole input)."
	puts "Mem clock @133Mhz CAS3"
	
	set tdi [readRegister 0]	
	puts "REG:  $tdi"
	
	#Basic write
	runTest 2 
	puts "Value written - 15 sec delay..."
	after 15000
	puts "Performing fetch, good luck."
  
	#Basic read
	runTest 3 
	
	set tdi [readRegister 0]
	puts "Test complete, value below should be 16bit broken barberpole: b00000000000000001110101110101110"
	puts "REG:  $tdi"
	if {$tdi == "00000000000000001110101110101110"} {
		puts "**TEST PASSED**"
	} else {
		puts "**TEST FAILED**"
	}
	setJTAGBypass
}

proc basicrw {} {
	puts "Two writes, followed by read of first address. (Different input patterns)"
	puts "Mem clock @133Mhz CAS4"
	
	set tdi [readRegister 0]	
	puts "REG:  $tdi"	

	runTest 1
	set tdi [readRegister 0]

	puts "Test complete, value below should be 16bit barberpole: b00000000000000001010101010101010"
	puts "REG:  $tdi"
	if {$tdi == "00000000000000001010101010101010"} {
		puts "**TEST PASSED**"
	} else {
		puts "**TEST FAILED**"
	}
	setJTAGBypass
}

#PDS>
proc bin2hex val {
    binary scan [binary format B* $val] H* hexdigits
    return [string toupper $hexdigits]
}

proc tbState val {
switch $val {
   0 { puts "DUMMY" }
   1 { puts "IDLE" }
   2 { puts "SEND_PROMPT" }
   3 { puts "SEND_PROMPT_2" }
   4 { puts "SEND_PROMPT_3" }
   5 { puts "SEND_PROMPT_4" }
   6 { puts "SEND_PROMPT_5" }
   7 { puts "SEND_PROMPT_DONE" }
   8 { puts "SEND_PROMPT_VAL_1" }
   9 { puts "SEND_PROMPT_VAL_2" }
  10 { puts "SEND_PROMPT_VAL_DONE" }
  11 { puts "DISPLAY_RESULT" }
  12 { puts "INIT" }
  13 { puts "RETURN_TO_IDLE" }
  14 { puts "WAIT_CYCLES" }
  15 { puts "WAIT_WRITE_DONE" }
  16 { puts "WAIT_READ_DONE" }
  17 { puts "PROMPT_WAIT_CYCLES" }
  18 { puts "TEST_WRITE" }
  19 { puts "TEST_READ" }
  20 { puts "WAIT_MANY_READ_GRANTED" }
  }
}

proc csmState val {
  switch $val {
     0 { puts "CMD_STATE_IDLE" }
     1 { puts "CMD_STATE_PRE_WRITE" }
     2 { puts "CMD_STATE_PRE_WRITE_DONE" }
     3 { puts "CMD_STATE_WRITE" }
     4 { puts "CMD_STATE_WRITE_PHASE_1" }
     5 { puts "CMD_STATE_WRITE_PHASE_1_AWAIT_DONE" }
     6 { puts "CMD_STATE_WRITE_PHASE_2" }
     7 { puts "CMD_STATE_WRITE_PHASE_2_COMMIT" }
     8 { puts "CMD_STATE_WRITE_PHASE_2_AWAIT_DONE" }
     9 { puts "CMD_STATE_WRITE_PHASE_3" }
    10 { puts "CMD_STATE_WRITE_PHASE_3_COMMIT" }
    11 { puts "CMD_STATE_WRITE_PHASE_3_AWAIT_DONE" }
    12 { puts "CMD_STATE_WRITE_DONE" }
    13 { puts "CMD_STATE_PRE_READ" }
    14 { puts "CMD_STATE_READ_MANY_FROM_RAM " }
    15 { puts "CMD_STATE_FIFO_READ_REQUEST " }
    16 { puts "CMD_STATE_WAIT_CYCLES " }
    17 { puts "CMD_STATE_FIFO_READ_GET_DATA " }
    18 { puts "CMD_STATE_FIFO_READ_NOP " }
    19 { puts "CMD_STATE_READ_SINGLE_FROM_RAM " }
    }
}

proc rsmState val {
  switch $val {
     0 { puts "INIT" }
     1 { puts "REQUEST_COMMAND_FROM_FIFO" }
     2 { puts "GET_COMMAND_FROM_FIFO" }
     3 { puts "RUN_COMMAND_FROM_FIFO" }
     4 { puts "WAIT_CYCLES" }
     5 { puts "IDLE" }
     6 { puts "READ" }
     7 { puts "READ_2" }
     8 { puts "WRITE" }
     9 { puts "WRITE_2" }
    10 { puts "WAIT_CYCLES_ONLY" }
    11 { puts "WRITE_PRE_SET_ADDRESS" }
    12 { puts "WRITE_SET_ADDRES" }
    }
}

proc dec2bin {i {width {}}} {
    #returns the binary representation of $i
    # width determines the length of the returned string (left truncated or added left 0)
    # use of width allows concatenation of bits sub-fields

    set res {}
    if {$i<0} {
        set sign -
        set i [expr {abs($i)}]
    } else {
        set sign {}
    }
    while {$i>0} {
        set res [expr {$i%2}]$res
        set i [expr {$i/2}]
    }
    if {$res eq {}} {set res 0}

    if {$width ne {}} {
        append d [string repeat 0 $width] $res
        set res [string range $d [string length $res] end]
    }
    return $sign$res
}

proc bin2dec bin {
    if {$bin == 0} {
        return 0
    } elseif {[string match -* $bin]} {
        set sign -
        set bin [string range $bin[set bin {}] 1 end]
    } else {
        set sign {}
    }
    return $sign[expr 0b$bin]
}

#----------------------- WRITE ------------------------
proc writeMem { address val count } {
  global REG_ADDRESS    
  global REG_WRITE_VAL  
  global REG_WRITE_COUNT

  setRegister $REG_ADDRESS     $address
  setRegister $REG_WRITE_VAL   $val
  setRegister $REG_WRITE_COUNT $count
  
	runTest 4 
}

#----------------------- WRITE ------------------------
proc writeMemNoRun { address val count } {
  global REG_ADDRESS    
  global REG_WRITE_VAL  
  global REG_WRITE_COUNT

  setRegister $REG_ADDRESS     $address
  #setRegister $REG_WRITE_VAL   $val
  #setRegister $REG_WRITE_COUNT $count
}

#----------------------- READ ------------------------
proc readMem { address } {
  global REG_ADDRESS    

  setRegister $REG_ADDRESS     $address
  
	runTest 5 
}

proc prompt { promptId } {
  global REG_WRITE_VAL    

  setRegister $REG_WRITE_VAL     $promptId
  
  runTest 6
}

proc runTest testno {
  global SETTEST
  global RUNTEST
  global SELTEST
  global SKIPRUN
  
	#Go to set instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $SETTEST
	#push in test value
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $testno 32]  
	
  if { $SKIPRUN == 0 } {
    #Run test -
    device_virtual_ir_shift -instance_index 0 -ir_value $RUNTEST
  } else {
    device_virtual_ir_shift -instance_index 0 -ir_value $SELTEST
  }
}

#----------------------- TEXT ------------------------
proc setText {textIndex charValue} {
  global SETTXTIDX
  global WRITETXT

	#Go to set test offset instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $SETTXTIDX 

	#Text offset is 32bit
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $textIndex 32]

	#Go to write register instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $WRITETXT
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $charValue 32]
	setJTAGBypass 
}

proc readText textIndex {
  global SETTXTIDX
  global READTXT

	#Text offset is 32bit
	device_virtual_ir_shift -instance_index 0 -ir_value $SETTXTIDX
  
	#Set the parameter to be the requested register
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $textIndex 32]   

	#Issue read command
	device_virtual_ir_shift -instance_index 0 -ir_value $READTXT
	return [device_virtual_dr_shift -instance_index 0 -dr_value [dec2bin 0 8] -length 8] 	
}

#--------------------- REGISTERS ---------------------
proc setRegister {register regvalue} {
  global SETREGISTER
  global WRITEREG
  
	#Go to set register instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $SETREGISTER  

	#Set the parameter to be the requested register
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $register 32]

	#Go to write register instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $WRITEREG
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $regvalue 32]
	setJTAGBypass 
}


proc readSRRegister regno {
  global SETREGISTER
  global READREG2

	#Go to set register instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $SETREGISTER  
	#Set the parameter to be the requested register
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $regno 32]   

	#Issue read command
	device_virtual_ir_shift -instance_index 0 -ir_value $READREG2
	return [device_virtual_dr_shift -instance_index 0 -dr_value [dec2bin 0 32] -length 32] 	
}


proc readRegister regno {
  global SETREGISTER
  global READREG

	#Go to set register instruction
	device_virtual_ir_shift -instance_index 0 -ir_value $SETREGISTER  
	#Set the parameter to be the requested register
	device_virtual_dr_shift -instance_index 0 -length 32 -dr_value [dec2bin $regno 32]   

	#Issue read command
	device_virtual_ir_shift -instance_index 0 -ir_value $READREG
	return [device_virtual_dr_shift -instance_index 0 -dr_value [dec2bin 0 32] -length 32] 	
}

proc setJTAGBypass {} {
    device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
}

#---------------- MAIN ----------------
openport
device_lock -timeout 10000
#presence
#reset
userinput