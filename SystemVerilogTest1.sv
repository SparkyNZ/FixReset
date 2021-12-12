//`timescale 1ns/100ps
module SystemVerilogTest1( input  logic sw1,
                           input  logic clk, 
                           
                          
                           output logic oLED1,
                           output logic oLED2,
                           output logic oLED3,
                           output logic oLED4,

                           output logic oLED5,
                           output logic oLED6,
                           output logic oLED7,
                           output logic oLED8,

                           output logic oD1,        // 7-segment array 1 select digit 1-4
                           output logic oD2,
                           output logic oD3,
                           output logic oD4,

                          
                           output logic[0:6] oDig,  // 7-segments
                           
                           output logic clkDup,
                           
             
//
output logic tdi_dup, 
output logic tdo_dup, 
output logic cdr_dup, 
//output logic eldr_dup, 
//output logic e2dr_dup, 
//output logic pdr_dup, 
output logic sdr_dup, 
output logic udr_dup, 
output logic uir_dup, 
//output logic cir_dup, 
//output logic e1dr_dup, 
//output logic bypass_reg_dup,
output logic [3:0] ir_in_dup,
//output logic ir_out_dup,

//             
output logic tckDup
                           
                           
);

 
// These signals are required for the vJTAG module
logic tck, tdi, tdo, cdr, eldr, e2dr, pdr; 
logic sdr, udr, uir, cir, e1dr, bypass_reg;
logic [3:0] ir_in;
logic [3:0] ir_in_copy;
logic ir_out;
 

logic clk2; 
 
Clock2 clock2(
	.areset ( ! notReset ),
	.inclk0( clk ),
	.c0( clk2 ) 
  );
 
//assign clkDup = clk;
assign clkDup = clk2;

// Debug outputs for logic analyser
assign tckDup = tck;
assign tdi_dup = tdi;
assign tdo_dup = tdo;
assign cdr_dup = cdr;
assign sdr_dup = sdr;
assign udr_dup = udr;
assign uir_dup = uir;
assign ir_in_dup = ir_in;

 
 
logic notReset;

//assign oLED8 = 1;
//assign oLED7 = 1;
assign oLED6 = 1;
assign oLED5 = notReset;


logic [3:0]  registeraddress;
logic [3:0]  last_opco;
logic [3:0]  opco;
logic [31:0] shift_buffer = 32'h0;
logic [31:0] active_register = 0;
logic [31:0] test_buffer = 0;
logic [31:0] registers [7:0];
logic [31:0] srRegisters [15:0];


// JTAG OPCODES 
localparam BYPASS =     4'b1111;
localparam IDCODE =     4'b0001;
localparam READREG =    4'b0010;
localparam SETREGISTER =   4'b0011;
localparam RUNTEST    = 4'b0100; 
localparam PRESENCE   = 4'b0101;
localparam SETTEST    = 4'b0110;
localparam WRITEREG   = 4'b0111;
localparam READTXT    = 4'b1000;
localparam SETTXTIDX  = 4'b1001;
localparam WRITETXT   = 4'b1010;

localparam RESETHI    = 4'b1011;
localparam RESETLO    = 4'b1100;

localparam READREG2   = 4'b1101;
localparam SELTEST    = 4'b1110;

localparam NIL	      = 4'b1111;

localparam REG_0_CURRSTATE   = 0;
localparam REG_1_ADDRESS     = 1;
localparam REG_2_WRITE_VAL   = 2;
localparam REG_3_WRITE_COUNT = 3;
localparam REG_4_READ_VAL    = 4;
localparam REG_5_PROMPTID    = 5;
localparam REG_6_CHAROFFSET  = 6;
localparam REG_7_LAST_REQ    = 7;


// Test signals
logic [3:0] SelectedTest = 0;
logic [3:0] LastSelectedTest = 0;
logic [4:0] StageCounter = 0;
logic run = 0;

logic[31:0] jTagCommandRequested = 0;
logic[31:0] jTagCommandDone = 0;


logic[31:0] temp_register;
logic[31:0] text_offset; // 32bit offset but only 32 chars in the text buffer!
logic[7:0] text[ 31 : 0 ];
byte tempChar;

longint debounceCounter = 0;

// Instantiation of the JTAG module.
vJTAG v(
 .tdo (tdo),
 .tck (tck),
 .tdi (tdi),
 .ir_in(ir_in),
 .ir_out(ir_out),
 .virtual_state_cdr (cdr),
 .virtual_state_e1dr(e1dr),
 .virtual_state_e2dr(e2dr),
 .virtual_state_pdr (pdr),
 .virtual_state_sdr (sdr),
 .virtual_state_udr (udr),
 .virtual_state_uir (uir),
 .virtual_state_cir (cir)
);

assign ir_out = ir_in[0]; //Assignment for passthrough.

//--------------------------------------------------------------------------------
// TCKSTATE
//--------------------------------------------------------------------------------
typedef enum
{
  tckIdle,
  tckNewInstruction,
  tckReturnToIdle
  
} TCKSTATE;  
  
  
TCKSTATE tckState = tckIdle;  

task DoCheckToTransmit;
	if (sdr) begin				
		shift_buffer <= {tdi, shift_buffer[31:1]}; //VJ State is Shift DR, so we shift using tdi and the existing bits.		
	end	
	if (cdr) begin //Capture DR is asserted. This means we lookup the current instruction and plop stuff here.
		case (opco)
			IDCODE: shift_buffer <= 32'h100011d3;
			READREG: shift_buffer <= registers[active_register];
			READREG2: shift_buffer <= srRegisters[active_register];
			READTXT: shift_buffer <= text[text_offset];
		endcase
	end
	if (udr) begin
		case (opco)						
			SETREGISTER: active_register <= shift_buffer;	
			SETTEST: test_buffer <= shift_buffer;		
			SETTXTIDX: text_offset <= shift_buffer;
		endcase		
	end
endtask

//--------------------------------------------------------------------------------
//--------------------------------------------------------------------------------
//always_ff @ (posedge tck) begin
task DoCheckVJTAGIncoming;

  DoCheckToTransmit();

  // PDS> tck clock is not regular! cannot depend upon it
  // PDS> Logic analyzer also shows that TCK is HI most of the time and only bounces low when data comes in
  
  case (tckState)
    tckIdle :
      begin
        if( uir ) begin
          // PDS: uir drops LO when serial bits are being read. It goes back to HI when instruction is present
          if (ir_in != last_opco) begin
            ir_in_copy <= ir_in;
            tckState <= tckNewInstruction;
          end
        end
      end
    
    tckNewInstruction : 
      begin
        last_opco <= ir_in_copy;
          
        if( ( ir_in_copy[3:0] == RESETLO ) || ( ir_in_copy[3:0] == RESETHI ) )
        begin   // notReset
          jTagCommandRequested <= 0;
        end
        else if( ir_in_copy[3:0] != 0 )
        begin
          // Increment for any opcode but ignore the JTAGBypass opcode (zero) which is sent after every instruction
          jTagCommandRequested <= jTagCommandRequested + 1;
        end

        tckState <= tckReturnToIdle;  
      end
      
    tckReturnToIdle:
      begin
        // The all important change. For every "cycle' of uir, notReset must be assigned to one value
        // or the other. If only set in a few of the below case conditions, the output of the notReset
        // flipflop is fed back into it's input to maintain it's state and weird shit happens. Using the
        // ternary operator below, it's always held high unless that one condition occurs. Check RTL Viewer
        // if in doubt. The previous behaviour resulted in oscillation - LED2 flickering - stuff going
        // wrong and possibly because different clock boundaries between uir and clk in the main state machine
        if( ir_in_copy[3:0] == RESETLO)
        begin
          notReset <= 0;
          oLED1 <= 0;
          oLED8 <= ~ oLED8;
        end
        else 
        if( ir_in_copy[3:0] == RESETHI)
        begin
          notReset <= 1;
          oLED1 <= 1;
          oLED7 <= ~ oLED7;
        end
        else
        begin
          // Leave notReset in whatever state it's in
        end

      
        opco <= ir_in_copy;
        
        tckState <= tckIdle;  
      end
      
  endcase
  
endtask


//--------------------------------------------------------------------------------
//--------------------------------------------------------------------------------
always_comb begin
	if (ir_in == BYPASS) tdo <= tdi;
	else tdo <= shift_buffer[0];	
end


// PDS> Tests moved to my state machine/main loop




logic debounceCounterActive = 0;
  
  
//--------------------------------------------------------------------------------
// TRIGGERSTATE
//--------------------------------------------------------------------------------
typedef enum
{
  trigReset,
  trigCheckManual,
  trigManualRun,
  trigManualDebounce,
  trigCheckCommand,
  trigGotNewCommand,
  trigCheckForRun,
  trigResetRun
  
} TRIGGERSTATE;  
  
  
TRIGGERSTATE triggerState = trigReset;  

//--------------------------------------------------------------------------------  
task DoTriggerStateMachine;
//-------------------------------------------------------------------------------- 
  // Trigger test must be done exclusively to avoid collision in setting 'run' signal
  unique case ( triggerState )
    trigReset          : DoTriggerReset();
    trigCheckManual    : DoTriggerCheckManual();
    trigManualRun      : DoManualRun();
    trigManualDebounce : DoManualDebounce();
    trigCheckCommand   : DoTriggerCheckCommand();
    trigGotNewCommand  : DoTriggerGotNewCommand();
    trigCheckForRun    : DoTriggerCheckForRun();
    trigResetRun       : DoResetRun();
  endcase
endtask

//--------------------------------------------------------------------------------  
task DoTriggerReset;
//--------------------------------------------------------------------------------  
  jTagCommandDone <= 0;
  debounceCounterActive <= 0;
  debounceCounter <= 0;
  
  triggerState <= trigCheckManual;  
  //oLED8 <= 1;
endtask

//--------------------------------------------------------------------------------  
task DoTriggerCheckManual;  
//--------------------------------------------------------------------------------
  //oLED7 <= sw1;

  if( debounceCounterActive ) 
  begin
    // Ignore switch for a bit once pressed
    triggerState <= trigManualDebounce;
  end
  else  
  if( sw1 == 0 ) 
  begin
    triggerState <= trigManualRun;
  end
  else  
  begin
    triggerState <= trigCheckCommand;
  end
	
endtask

//--------------------------------------------------------------------------------
task DoManualRun;
//--------------------------------------------------------------------------------
  debounceCounterActive <= 1;
  //oLED8 <= 0;
  run <= 1;
  
  triggerState <= trigCheckCommand;
endtask

//--------------------------------------------------------------------------------
task DoManualDebounce;
//--------------------------------------------------------------------------------
  
  //if( debounceCounter > 100000000 ) begin // For 50Mhz
  //if( debounceCounter > 10000000 ) begin  // Running at 2MHz now ~ 4 seconds
  //if( debounceCounter >  2500000 ) begin  // Running at 2MHz now ~ 1 second
  if( debounceCounter   >  1250000 ) begin  // Running at 2MHz now ~ 0.5 second
    debounceCounterActive <= 0;
    debounceCounter <= 0;
    
    // Show debounce is over
    //oLED8 <= 1;
  end
  else
  begin
    debounceCounter <= debounceCounter + 1;  
  end
  
  
  triggerState <= trigCheckCommand;
endtask

//--------------------------------------------------------------------------------
task DoTriggerCheckCommand;
//--------------------------------------------------------------------------------
  // Only process jTag commands when a new one is received..
  if (jTagCommandRequested > jTagCommandDone)
  begin
    triggerState <= trigGotNewCommand;
  end
  else
  begin
    triggerState <= trigCheckManual;
  end
endtask

//--------------------------------------------------------------------------------
task DoTriggerGotNewCommand;
//--------------------------------------------------------------------------------
  // Only process jTag commands when a new one is received..
  jTagCommandDone <= jTagCommandRequested;
  
  //---------------------------
  case (opco)						
    WRITEREG: begin
      registers[active_register] <= shift_buffer;					
    end
    
    WRITETXT: begin
      text[text_offset] <= shift_buffer;					
    end
    
    SELTEST : begin
      // Select but don't run
      SelectedTest <= test_buffer[3:0];
      LastSelectedTest <= test_buffer[3:0];
      StageCounter <= 0;
    end

    RUNTEST: begin
      //Set the test as selected.
      run <= 1;
      SelectedTest <= test_buffer[3:0];
      LastSelectedTest <= test_buffer[3:0];
      StageCounter <= 0;
    end

  endcase
  
  triggerState <= trigCheckForRun;
  
endtask
  
//--------------------------------------------------------------------------------
task DoTriggerCheckForRun;
//--------------------------------------------------------------------------------
  
  if( run )
  begin
    // Used to use SelectedTest to kick off main state machine sequence/test
    triggerState <= trigResetRun;
  end
  else
  begin
    triggerState <= trigCheckManual;
  end

  
endtask
  
//--------------------------------------------------------------------------------
task DoResetRun;
//--------------------------------------------------------------------------------
  run <= 0;  
  triggerState <= trigCheckManual;
  SelectedTest <= 0;
endtask

logic [56:0] toggle = 0;

logic [3:0] numLedValue;
NumericLED numericLed( numLedValue, clkDup, oDig );  

//--------------------------------------------------------------------------------
// 50Mhz clock
always_ff @( posedge clk )
//--------------------------------------------------------------------------------
begin
  DoCheckVJTAGIncoming();
end
  
//--------------------------------------------------------------------------------
// MAIN
//--------------------------------------------------------------------------------
always_ff @( posedge clkDup )
begin

  // This will NOT work at 2MHz!
  //DoCheckVJTAGIncoming();

  oLED4 <= ! run;
  oLED3 <= ! debounceCounterActive;
 
  
  // BEGIN 7 seg
  toggle <= toggle + 1;
  
  oD1 <= 1;
  
  if( toggle < 16384 ) 
  begin
    oD2 <= 1;  
    oD3 <= 1;
    oD4 <= 0;
    
    // LED DIGIT #1 - Closest to DIGIT pair divider, closest to D connectors
    numLedValue <= LastSelectedTest[3:0];
  end
  else if( toggle < 32768 ) 
  begin
    oD2 <= 1;
    oD3 <= 0;
    oD4 <= 1;
    
    
    // LED DIGIT #2 - right of #1
    
    //jTagCommandDone jTagCommandRequested
    numLedValue <= jTagCommandDone[3:0];
  end
  else if( toggle < 49152 )
  begin
    oD2 <= 0;  
    oD3 <= 1;
    oD4 <= 1;
  
    // LED DIGIT #3 - right of #2
    numLedValue <= jTagCommandRequested[3:0];
    //case( jTagCommandDone[3:0])
  end
  else
  begin
    toggle <= 0;
  end

  
  // END 7 seg
  
  if( notReset == 0 ) 
  begin
    jTagCommandDone <= 0;
    triggerState <= trigReset;
    
    LastSelectedTest <= 0;
    
    oLED2 <= 0;                    /// WTF!?!?!? WHY WON'T THIS WORK???!
  end
  else
  begin
    oLED2 <= 1;

    DoTriggerStateMachine();
  end

end

endmodule
