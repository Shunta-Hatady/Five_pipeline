`include "alu.vh"

module alu ( A,B,C,Y );
   input  [31:0] A;
   input  [31:0] B;
   input  [4:0] C;
   output [31:0] Y;

   reg    [31:0] Y;           // redefinition for non-blocking assignment 

   // internal wire
   reg    [32:0] tmp;         // temporary result
   wire          V;           // overflow flag
   wire          Z;           // zero flag
   wire          LTU;         // less than unsigned flag
   wire          LT;          // less than flag

   // Arithmetical and Logical operation
   always @( A or B or C )
     begin
        case( C )
          `IADD :  tmp <= { 1'b0, A } + { 1'b0, B };
          `ISUB :  tmp <= { 1'b0, A } - { 1'b0, B };
          `IAND :  tmp <= { 1'b0, A & B };
          `IOR  :  tmp <= { 1'b0, A | B };
          default: tmp <= { 1'b0, A } - { 1'b0, B }; // sub and compare
        endcase
     end
   
   // flags
   assign V    = (A[31] != B[31]) && (tmp[31] != A[31]);
   assign Z    = (tmp[31:0] == 32'b0); 
   assign LTU  = tmp[32];
   assign LT   = tmp[31] ^ V;

   // output multiplexer
   always @( C or A or B or tmp or LT or LTU or Z)
     begin
        case( C )
          `IADD  : Y <= tmp[31:0];
          `ISUB  : Y <= tmp[31:0];
          `IAND  : Y <= tmp[31:0];
          `IOR   : Y <= tmp[31:0];
          `IXOR  : Y <= A ^ B;
          `ILT   : Y <= {31'b0, LT};
          `ILTU  : Y <= {31'b0, LTU};
          `IEQ   : Y <= {31'b0, Z};
          `INE   : Y <= {31'b0, ~Z};
          `IGE   : Y <= {31'b0, ~LT};
          `IGEU  : Y <= {31'b0, ~LTU};
          default: Y <= 32'b0;
        endcase
     end

endmodule

