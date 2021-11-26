//`timescale 1ns/100ps
module SystemVerilogTest1( input  logic sw1,
                           input  logic clk, 
                           

                           inout  wire  [7:0] sr_D,
                           output logic sr_CE_NOT,
                           output logic sr_OE_NOT,
                           output logic sr_WE_NOT,
                           
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
                           output logic tckDup
                           
                           
 );


logic clk2; 
 
Clock2 clock2(
	.areset ( ! notReset ),
	.inclk0( clk ),
	.c0( clk2 ) 
  );
 
//assign clkDup = clk;
assign clkDup = clk2;
assign tckDup = tck;
 
 
logic notReset;

assign oLED8 = notReset;
assign oLED7 = 1;
assign oLED6 = 1;
assign oLED5 = 1;

 
int  promptCharOffset;
byte promptCharsOut;
byte promptLen;
byte promptValLen;

logic promptEnabled;


//================================== BEGIN: JTAG STUFF =====================

// These signals are required for the vJTAG module
logic tck, tdi, tdo, cdr, eldr, e2dr, pdr; 
logic sdr, udr, uir, cir, e1dr, bypass_reg;
logic [4:0] ir_in;
logic [4:0] ir_in_copy;
logic ir_out;

logic [3:0] registeraddress;
logic [4:0] opco;
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



//--------------------------------------------------------------------------------
//--------------------------------------------------------------------------------
always_ff @ (posedge tck) begin	
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

  
  case (tckState)
    tckIdle :
      begin
        // PDS> BEGIN NEW BLOCK
        if( uir ) begin
          ir_in_copy <= ir_in;
          tckState <= tckNewInstruction;
        end
      end
    
    tckNewInstruction : 
      begin
        if (opco != ir_in_copy) begin
          
          if( ( ir_in_copy[3:0] == RESETLO ) || ( ir_in_copy[3:0] == RESETHI ) )
          begin   // notReset
            jTagCommandRequested <= 0;
          end
          else if( ir_in_copy[3:0] != 0 )
          begin
            // Increment for any opcode but ignore the JTAGBypass opcode (zero) which is sent after every instruction
            jTagCommandRequested <= jTagCommandRequested + 1;
          end
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
        end
        else 
        if( ir_in_copy[3:0] == RESETHI)
        begin
          notReset <= 1;
          oLED1 <= 1;
        end
        else
        begin
          // Leave notReset in whatever state it's in
        end

      
        // PDS> THIS IS IT! The assignment is happening in parallel with the test
        opco <= ir_in_copy;
        
        tckState <= tckIdle;  
      end
      
  endcase
  // PDS> END   NEW BLOCK
  
end


//--------------------------------------------------------------------------------
//--------------------------------------------------------------------------------
always_comb begin
	if (ir_in == BYPASS) tdo <= tdi;
	else tdo <= shift_buffer[0];	
end


// PDS> Tests moved to my state machine/main loop


//================================== END: JTAG STUFF =====================
 
byte  promptId;


logic stringTxReadyForData;
 
`define prompt_MENU      0
`define prompt_OK        1 
`define prompt_ERROR     2
`define prompt_WORD_VAL  3
`define prompt_BYTE_VAL  4


// Byte 0 - number of prompts
// Byte 1,2 - 1st prompt offset BIG ENDIAN
// Byte 3,4 - 2nd prompt offset BIG ENDIAN
//
// Byte (2n-1) - nth prompt offset
//
// Each prompt will consist of:
// Offset + 0 : length (2bytes BIG ENDIAN)
// Offset + 2 : prompt

byte unsigned baBlock[ 0:59 ] = '
{
  8'h05, 8'h00, 8'h0b, 8'h00, 8'h1d, 8'h00, 8'h23, 8'h00, 8'h2c, 8'h00, 8'h34, 8'h00, 8'h10, 8'h53, 8'h65, 8'h6c, 
  8'h65, 8'h63, 8'h74, 8'h20, 8'h6f, 8'h70, 8'h74, 8'h69, 8'h6f, 8'h6e, 8'h3a, 8'h0d, 8'h0a, 8'h00, 8'h04, 8'h4f, 
  8'h4b, 8'h0d, 8'h0a, 8'h00, 8'h07, 8'h45, 8'h52, 8'h52, 8'h4f, 8'h52, 8'h0d, 8'h0a, 8'h00, 8'h06, 8'h57, 8'h4f, 
  8'h52, 8'h44, 8'h3a, 8'h20, 8'h00, 8'h06, 8'h42, 8'h59, 8'h54, 8'h45, 8'h3a, 8'h20
};



//--------------------------------------------------------------------------------
// Shared buses
//--------------------------------------------------------------------------------
wire  [7 : 0 ] dataBusToRAM;
wire  [7 : 0 ] dataBusFromRAM;
//--------------------------------------------------------------------------------
// Registers to be switched onto the bus
//--------------------------------------------------------------------------------
logic [7 : 0 ] dataOut;
logic [7 : 0 ] dataIn;
//--------------------------------------------------------------------------------

logic           iSRAMReadRequest;
logic           iSRAMWriteRequest;
logic           oSRAMReadGranted;
logic           oSRAMWriteGranted;
logic           oSRAMReadDataValid;
logic           oSRAMDataWritten;

logic dummy;


assign dataBusToRAM = ( iSRAMWriteRequest   ) ? dataOut        : 8'bZZZZZZZZ;
assign dataIn       = ( ! iSRAMWriteRequest ) ? dataBusFromRAM : 8'bZZZZZZZZ;


logic oRAMReadRequest;

assign iSRAMReadRequest     = oRAMReadRequest;

logic ramReset;
logic combinedNotRamReset;
assign combinedNotRamReset = ( ramReset ) ? 0 : notReset;


SRAMController8Bit sramController(

  .notReset(       notReset ),
  .iClk(           clkDup ), 
  .iData(          dataBusToRAM ),
  .oData(          dataBusFromRAM ),

  .iReadRequest(   iSRAMReadRequest ),
  .iWriteRequest(  iSRAMWriteRequest ),
  .oReadGranted(   oSRAMReadGranted ),
  .oWriteGranted(  oSRAMWriteGranted ),
  .oReadDataValid( oSRAMReadDataValid ),
  .oDataWritten(   oSRAMDataWritten ),
  
  .sr_D(           sr_D ),

  .sr_CE_NOT(     sr_CE_NOT ),
  .sr_OE_NOT(     sr_OE_NOT ),
  .sr_WE_NOT(     sr_WE_NOT ),
  
  .debugRegisters( srRegisters[15:0] )
);
 

//--------------------------------------------------------------------------------
// States
//--------------------------------------------------------------------------------
typedef enum
{
  DUMMY,    // Make IDLE state 1
  
  // 1
  IDLE,
  SEND_PROMPT,
  SEND_PROMPT_2,
  SEND_PROMPT_3,
  SEND_PROMPT_4,
  SEND_PROMPT_5,
  SEND_PROMPT_DONE,
  SEND_PROMPT_VAL_1,
  SEND_PROMPT_VAL_2,
  SEND_PROMPT_VAL_DONE,
  
  // 11
  DISPLAY_RESULT,
  INIT,
  RETURN_TO_IDLE,
  WAIT_CYCLES,
  WAIT_WRITE_DONE,
  
  // 16
  WAIT_READ_DONE,
  PROMPT_WAIT_CYCLES,
  TEST_WRITE,
  TEST_READ
  
} STATE;



// SignalTap
// NOTE!!! I don't know why but if I change all of the below values to bit[4:0], I won't be able to see the currState[4:0] in SignalTap
// For some reason it creates seperate currState.IDLE signals and then mnemonic table cannot be used.
STATE currState              = IDLE;
STATE nextState;
STATE promptDoneState        = RETURN_TO_IDLE;
STATE displayResultDoneState = RETURN_TO_IDLE;
STATE waitCyclesDoneState    = IDLE;
STATE promptWaitCyclesDoneState = IDLE;
STATE waitReadDoneState      = IDLE;
STATE waitWriteDoneState     = IDLE;
STATE writeCharRowDoneState  = IDLE;
STATE printCharDoneState     = IDLE;
STATE printStringDoneState   = IDLE;
STATE resetRAMDoneState      = IDLE;

byte  delayCount; 
byte  promptDelayCount;
logic fReadDataValid;

logic debounceCounterActive = 0;
  
task DoStateMachine;
  
  unique case ( currState )
  
    TEST_WRITE : begin
      oRAMReadRequest  <= 0;
      iSRAMWriteRequest <= 1;	

      promptId        <= `prompt_OK;          
      waitWriteDoneState <= RETURN_TO_IDLE;
      currState <= WAIT_WRITE_DONE; 
    end    

    
    TEST_READ : begin
      oRAMReadRequest  <= 1;
      iSRAMWriteRequest <= 0;		

      // Clear out previous result
      registers[ REG_4_READ_VAL ] <= 0;
      
      waitReadDoneState <= RETURN_TO_IDLE;
      
      currState <= WAIT_READ_DONE; 
    end

    //----------------------------------------------------------------------------
    IDLE           : begin
    //----------------------------------------------------------------------------
      if( oSRAMDataWritten )
      begin
        iSRAMWriteRequest <= 0;
      end
      
    end
    
    //----------------------------------------------------------------------------
    SEND_PROMPT    : begin
    //----------------------------------------------------------------------------
      
      // Copy prompt for promptId into text      
      promptCharOffset <= ( baBlock[ 1 + (promptId<<1) ] << 8 ) | baBlock[ 2 + (promptId<<1) ];
      currState <= SEND_PROMPT_2;
    end
    
    SEND_PROMPT_2: begin
      
      // Should this line be moved to another clock/state?
      promptLen        <= ( baBlock[ promptCharOffset ] << 8 ) | baBlock[ promptCharOffset + 1 ] + 1;

      registers[ REG_5_PROMPTID   ] <= promptId;
      registers[ REG_6_CHAROFFSET ] <= promptCharOffset;
      currState <= SEND_PROMPT_3;
    end   
    
    SEND_PROMPT_3 : begin
      
      text[ 0 ] <= promptLen;
      
      promptCharOffset <= promptCharOffset + 2;
      
      currState   <= SEND_PROMPT_4;
    end

    
    SEND_PROMPT_4 : begin
    
      // Posn 0 is length so increment first
      promptCharsOut <= promptCharsOut + 1;
      
      currState <= SEND_PROMPT_5;
    end
    
    
    SEND_PROMPT_5 : begin
      text[ promptCharsOut ] <= baBlock[ promptCharOffset ];
      
      promptCharOffset <= promptCharOffset + 1;
      
      if( promptCharsOut >= promptLen )
      begin
        currState <= SEND_PROMPT_DONE;
      end
      else
      begin
        currState <= SEND_PROMPT_4;
      end
    end

    SEND_PROMPT_DONE : begin
      promptCharsOut <= 0;
      promptCharOffset <= 0;

      currState <= promptDoneState;
    end
    
    //----------------------------------------------------------------------------
    // This displays the SECOND part of the result which is just the hex. The BYTE
    // or WORD text is done by SEND_PROMPT
    DISPLAY_RESULT : begin
    //----------------------------------------------------------------------------
      if( fReadDataValid )
      begin
        fReadDataValid <= 0;
        
        // NOW we display just the hexadecimal part of the result           
        promptValLen  <= 8;
        
        // Resume where we left off..
        promptCharsOut <= text[ 0 ];
        currState <= SEND_PROMPT_VAL_1;

        // Must load before using..
        temp_register <= registers[ REG_4_READ_VAL ];          
      end
    end
    

    //----------------------------------------------------------------------------
    SEND_PROMPT_VAL_1 : begin
    //----------------------------------------------------------------------------

      unique case ( promptValLen )
         8: tempChar <= ( temp_register & 16'h0080 ) ? 8'h31 : 8'h30;
         7: tempChar <= ( temp_register & 16'h0040 ) ? 8'h31 : 8'h30;
         6: tempChar <= ( temp_register & 16'h0020 ) ? 8'h31 : 8'h30;
         5: tempChar <= ( temp_register & 16'h0010 ) ? 8'h31 : 8'h30;
         4: tempChar <= ( temp_register & 16'h0008 ) ? 8'h31 : 8'h30;
         3: tempChar <= ( temp_register & 16'h0004 ) ? 8'h31 : 8'h30;
         2: tempChar <= ( temp_register & 16'h0002 ) ? 8'h31 : 8'h30;
         1: tempChar <= ( temp_register & 16'h0001 ) ? 8'h31 : 8'h30;
         0: ;
      endcase 
      
      text[ promptCharsOut ] <= tempChar;
      
      currState <= SEND_PROMPT_VAL_2;
    end
      
    SEND_PROMPT_VAL_2 : begin
      promptCharsOut <= promptCharsOut + 1;
      promptValLen   <= promptValLen   - 1;
      
      if( promptValLen <= 0 ) 
      begin
        currState <= SEND_PROMPT_VAL_DONE;
      end
      else
      begin
        // Otherwise do next character..
        currState <= SEND_PROMPT_VAL_1;
      end
    end
    
    SEND_PROMPT_VAL_DONE : begin
      text[ 0 ] <= promptCharsOut;
      currState <= displayResultDoneState;
    end
    
    //----------------------------------------------------------------------------
    RETURN_TO_IDLE : begin
    //----------------------------------------------------------------------------      

      fReadDataValid <= 0;
      
      oRAMReadRequest   <= 0;
      iSRAMWriteRequest <= 0;		

      
      currState     <= IDLE;
      promptEnabled <= 1;
      // PDS> I want to see what it is before doing w0 255..
      //promptId      <= `prompt_OK;          
    end
    
    //----------------------------------------------------------------------------
    // Testbench states
    //----------------------------------------------------------------------------
    
    WAIT_CYCLES : begin
      delayCount <= delayCount - 1;
              
      if( delayCount == 0 )
      begin
        currState <= waitCyclesDoneState;
      end		
    end

    PROMPT_WAIT_CYCLES: begin
      promptDelayCount <= promptDelayCount - 1;
              
      if( promptDelayCount == 0 )
      begin
        currState <= promptWaitCyclesDoneState;
      end		
    end
    
  
    WAIT_WRITE_DONE: begin
      if( oSRAMWriteGranted && iSRAMWriteRequest )
      begin
        iSRAMWriteRequest <= 0;      
      end
      
      if( oSRAMDataWritten )
      begin
        if( promptEnabled )
        begin
          // No delay, straight onto sending OK prompt
          promptId        <= `prompt_OK;          
          currState       <= SEND_PROMPT;
          promptDoneState <= waitWriteDoneState;
        end
        else
        begin
          currState       <= waitWriteDoneState;
        end
      end    
    end


    WAIT_READ_DONE: begin
      if( oSRAMReadGranted && oRAMReadRequest )
      begin
        oRAMReadRequest <= 0;
      end
      
      
      if( oSRAMReadDataValid )
      begin
        // Remember that data is valid for next few clock cyles..
        fReadDataValid <= 1;        

        registers[ REG_4_READ_VAL ] <= dataIn;
        

        // SEND_PROMPT is called first to set WORD or BYTE text. DISPLAY_RESULT will append to it

        promptId        <= `prompt_BYTE_VAL;          
        currState       <= SEND_PROMPT;
        
        promptDoneState <= DISPLAY_RESULT;
        
        displayResultDoneState <= waitReadDoneState;
      end    
    end

  endcase
				 
endtask
  
  
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
    
    // This section will replace HANDLE_INPUT where I used to get keypresses
    case (SelectedTest)
      4: begin
          dataOut     <= registers[ REG_2_WRITE_VAL ];

          currState        <= TEST_WRITE;
          registers[REG_7_LAST_REQ] <= currState;
          
          // Should I add a state stack?
          //SelectedTest <= 0;
      end

      5: begin
          currState        <= TEST_READ;
          
          registers[REG_7_LAST_REQ] <= currState;
          //SelectedTest <= 0;
      end
      
      6: begin
          if( registers[ REG_2_WRITE_VAL ] > 0 ) begin
            promptId <= registers[ REG_2_WRITE_VAL ];
          end
          promptCharsOut <= 0;
          promptCharOffset <= 0;
          
          promptDoneState <= RETURN_TO_IDLE;
          currState <= SEND_PROMPT;
          //SelectedTest <= 0;
      end

    endcase

    // PDS> I suspect conflicting assignment after condition - splitting into separate state
    //run <= 0;
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

  
//--------------------------------------------------------------------------------
// MAIN
//--------------------------------------------------------------------------------
always_ff @( posedge clkDup )
begin

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
    
    //case( jTagCommandRequested[3:0])
    case( LastSelectedTest[3:0])
      4'b0000: oDig <= 7'b0000001; // "0"  
      4'b0001: oDig <= 7'b1001111; // "1" 
      4'b0010: oDig <= 7'b0010010; // "2" 
      4'b0011: oDig <= 7'b0000110; // "3" 
      4'b0100: oDig <= 7'b1001100; // "4" 
      4'b0101: oDig <= 7'b0100100; // "5" 
      4'b0110: oDig <= 7'b0100000; // "6" 
      4'b0111: oDig <= 7'b0001111; // "7" 
      4'b1000: oDig <= 7'b0000000; // "8"  
      4'b1001: oDig <= 7'b0000100; // "9" 
      default: oDig <= 7'b0000001; // "0"
    endcase
  end
  else if( toggle < 32768 ) 
  begin
    oD2 <= 1;
    oD3 <= 0;
    oD4 <= 1;
    
    
    // LED DIGIT #2 - right of #1
    
    //jTagCommandDone jTagCommandRequested
    case( jTagCommandDone[3:0])
    //case( ir_in[3:0])
      4'b0000: oDig <= 7'b0000001; // "0"  
      4'b0001: oDig <= 7'b1001111; // "1" 
      4'b0010: oDig <= 7'b0010010; // "2" 
      4'b0011: oDig <= 7'b0000110; // "3" 
      4'b0100: oDig <= 7'b1001100; // "4" 
      4'b0101: oDig <= 7'b0100100; // "5" 
      4'b0110: oDig <= 7'b0100000; // "6" 
      4'b0111: oDig <= 7'b0001111; // "7" 
      4'b1000: oDig <= 7'b0000000; // "8"  
      4'b1001: oDig <= 7'b0000100; // "9" 
      
      4'b1010: oDig <= 7'b0001000; // "A"  77 01110111 -> 1 0001000
      4'b1011: oDig <= 7'b1100000; // "B"  1f 00011111 -> 1 1100000
      4'b1100: oDig <= 7'b0110001; // "C"  4e 01001110 -> 1 0110001
      4'b1101: oDig <= 7'b1000010; // "D"  3d 00111101 -> 1 1000010
      4'b1110: oDig <= 7'b0110000; // "E"  4f 01001111 -> 1 0110000
      4'b1111: oDig <= 7'b0111000; // "F"  47 01000111 -> 1 0111000
      
      default: oDig <= 7'b0000001; // "0"
    endcase  
  end
  else if( toggle < 49152 )
  begin
    oD2 <= 0;  
    oD3 <= 1;
    oD4 <= 1;
  
     // LED DIGIT #3 - right of #2
  
    //case( jTagCommandDone[3:0])
    case( jTagCommandRequested[3:0])
      4'b0000: oDig <= 7'b0000001; // "0"  
      4'b0001: oDig <= 7'b1001111; // "1" 
      4'b0010: oDig <= 7'b0010010; // "2" 
      4'b0011: oDig <= 7'b0000110; // "3" 
      4'b0100: oDig <= 7'b1001100; // "4" 
      4'b0101: oDig <= 7'b0100100; // "5" 
      4'b0110: oDig <= 7'b0100000; // "6" 
      4'b0111: oDig <= 7'b0001111; // "7" 
      4'b1000: oDig <= 7'b0000000; // "8"  
      4'b1001: oDig <= 7'b0000100; // "9" 
      
      4'b1010: oDig <= 7'b0001000; // "A"  77 01110111 -> 1 0001000
      4'b1011: oDig <= 7'b1100000; // "B"  1f 00011111 -> 1 1100000
      4'b1100: oDig <= 7'b0110001; // "C"  4e 01001110 -> 1 0110001
      4'b1101: oDig <= 7'b1000010; // "D"  3d 00111101 -> 1 1000010
      4'b1110: oDig <= 7'b0110000; // "E"  4f 01001111 -> 1 0110000
      4'b1111: oDig <= 7'b0111000; // "F"  47 01000111 -> 1 0111000
      
      default: oDig <= 7'b0000001; // "0"
    endcase  
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
    
    promptCharOffset <= 0;
    promptCharsOut <= 0;
    promptLen <= 0;
    promptValLen <= 0;
    ramReset <= 0;
    fReadDataValid <= 0;
    
    promptEnabled <= 1;
    promptId   <= `prompt_MENU;
    
    oLED2 <= 0;
    
    currState <= SEND_PROMPT;
    promptDoneState <= RETURN_TO_IDLE;
    displayResultDoneState <= RETURN_TO_IDLE;
  end
  else
  begin
    oLED2 <= 1;
    registers[REG_0_CURRSTATE] <= currState;

    DoTriggerStateMachine();
    
    // PDS> I don't care about tihs right now!
    //DoStateMachine();
  end

end

endmodule
