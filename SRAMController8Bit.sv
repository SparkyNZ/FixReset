//--------------------------------------------------------------------------------
// MODULE: SRAMController8Bit
//
// 8bit Data SRAM Controller
//--------------------------------------------------------------------------------
module SRAMController8Bit #( DATA_WIDTH=8 )
( 
  input  logic                     notReset,
  input  logic                     iClk,
  
  
  input  wire  [DATA_WIDTH-1 : 0 ] iData,
  output wire  [DATA_WIDTH-1 : 0 ] oData,  
  
  input  logic                     iReadRequest,
  input  logic                     iWriteRequest,
  
  output logic                     oReadGranted,
  output logic                     oWriteGranted,
  
  output logic                     oReadDataValid,
  output logic                     oDataWritten,
  
  
  //------------------------------------------------------------------------------
  // Top level connections to SRAM itself
  //------------------------------------------------------------------------------
  inout  wire  [DATA_WIDTH-1:0] sr_D,

  output logic sr_CE_NOT,  // Chip #1 Enable
  output logic sr_OE_NOT,  
  output logic sr_WE_NOT,
  
  output logic[31:0] debugRegisters[15:0] // Subset of debug registers
);

wire   reset;
assign reset = ! notReset;

logic [7 : 0 ] dataIn;

localparam PROCESSING_NOTHING = 0;
localparam PROCESSING_READ    = 1;
localparam PROCESSING_WRITE   = 2;

bit [ 1 : 0 ] processing = PROCESSING_NOTHING;

localparam REG_0_READ_VALID   = 0;
localparam REG_1_CSM_STATE    = 1;
localparam REG_2_RSM_STATE    = 2;
localparam REG_3_REPEATS      = 3;
localparam REG_4_DATAREADS    = 4;
localparam REG_5_CMDWRITE     = 5;
localparam REG_6_CMDADDRESS   = 6;
localparam REG_7_FIFOCMDOUT   = 7;
localparam REG_8_FIFOCMDOUT   = 8;
localparam REG_9_COMMANDHI    = 9;
localparam REG_A_COMMANDLO    = 10;



//--------------------------------------------------------------------------------
// RSM States
//--------------------------------------------------------------------------------
typedef enum 
{
  INIT,
  REQUEST_COMMAND_FROM_FIFO,
  GET_COMMAND_FROM_FIFO,
  RUN_COMMAND_FROM_FIFO,
  WAIT_CYCLES,
  IDLE,
  READ,
  POST_READ_1,
  POST_READ_2,
  POST_READ_3,
  WRITE,
  WRITE_2,
  WAIT_CYCLES_ONLY,
  WRITE_PRE_SET_ADDRESS,
  WRITE_SET_ADDRESS
  
} STATE;


// SignalTap
STATE currState;
STATE nextState;

byte  unsigned delayCount;
byte  unsigned burstLength = 0;
logic          oddAddress = 0;


logic [DATA_WIDTH-1 : 0 ] iDataCopy;



//--------------------------------------------------------------------------------
// RSM - SRAM STATE MACHINE
//--------------------------------------------------------------------------------  
always_ff @( posedge iClk  )
begin

  debugRegisters[REG_2_RSM_STATE ] <= currState;  
  
  if( notReset == 0 )
  begin
    delayCount <= 0;
    
    oDataWritten   <= 0;
    oReadGranted   <= 0;
    oWriteGranted  <= 0;
    oReadDataValid <= 0;
    

    nextState <= IDLE;
    currState <= INIT;
  end
  else
  begin
    unique case ( currState )
      //--------------------------------------------------------------------------
      INIT                   : 
      //--------------------------------------------------------------------------
      begin
        sr_CE_NOT <= 1;
        sr_OE_NOT <= 1;
        sr_WE_NOT <= 1;
        
        currState  <= IDLE;
      end
      
      //--------------------------------------------------------------------------      
      WAIT_CYCLES :
      //--------------------------------------------------------------------------
      begin
        if( delayCount < 2 )
        begin
          currState <= nextState;
        end
        
        // No matter where you put this, it will be evaluated at the END !!
        delayCount <= delayCount - 1;        
      end
  
      
      //--------------------------------------------------------------------------
      IDLE:  // Pull a command request from the Comand FIFO
      //--------------------------------------------------------------------------
      begin
        sr_CE_NOT <= 1;
        sr_OE_NOT <= 1;
        sr_WE_NOT <= 1;        

        oDataWritten <= 0;
       
        if( iWriteRequest )
        begin
          oWriteGranted <= 1;
          
          iDataCopy <= iData;
 
          // Arduino CMD_INIT
          sr_CE_NOT <= 0;
          sr_WE_NOT <= 1;        
 
          // No output if we are writing
          sr_OE_NOT <= 1;
          sr_OE_NOT <= 1;

          // Start showing data on sr_D now..
          sr_D <= iData;

          currState <= WRITE;
        end
        else 
        if( iReadRequest )
        begin
          oReadGranted <= 1;
          oReadDataValid <= 0;
          
          sr_D <= 8'bZZZZZZZZ;  
          currState <= READ;
        end
        else
        begin
          oReadGranted  <= 0;
          oWriteGranted <= 0;
          sr_D <= 8'bZZZZZZZZ;  
        end
        
      end
     
      //--------------------------------------------------------------------------
      WRITE: 
      //--------------------------------------------------------------------------
      begin
      
        // Only high for one cycle
        oWriteGranted <= 0;
      
        // srD pins are written too with iDataCopy as soon as CMD_WRITE is set
        sr_CE_NOT <= 0; 
        sr_WE_NOT <= 0;        

        oDataWritten <= 1;
        
        delayCount <= 1;
        nextState <= IDLE;
        currState <= WAIT_CYCLES;
      end
      
      
      //--------------------------------------------------------------------------
      READ: 
      //--------------------------------------------------------------------------
      begin
        // Only high for one cycle
        oReadGranted  <= 0;
      
        sr_CE_NOT <= 0;
        sr_OE_NOT <= 0;        
        sr_WE_NOT <= 1;   
       
        currState  <= POST_READ_1;
      end
      
      POST_READ_1: begin
        currState  <= POST_READ_2;
      end
      
      POST_READ_2: begin
        oData <= sr_D;      
        oReadDataValid  <= 1;
        currState  <= POST_READ_3;
      end
      
      POST_READ_3: begin
        // Data only valid for 1 cycle
        oReadDataValid <= 0;
        currState  <= IDLE;
      end

    endcase
  end
end
                          
endmodule
