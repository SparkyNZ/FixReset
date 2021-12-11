module NumericLED( input  logic[3:0] value,
                   input  logic clk, 
                          
                          
                   output logic[0:6] oDig  // 7-segments
);


always_ff @( posedge clk )
begin
   case( value[3:0])
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
 
 
 endmodule