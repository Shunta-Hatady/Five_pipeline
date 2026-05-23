`include "alu.vh"

module alu ( A, B, C, Y );
   input  [31:0] A;
   input  [31:0] B;
   input  [ 4:0] C;
   output [31:0] Y;

   reg    [31:0] Y;

   reg    [32:0] tmp;      // 加減算・比較用（33ビット）
   wire          V;        // オーバーフローフラグ
   wire          Z;        // ゼロフラグ
   wire          LTU;      // 符号なし未満
   wire          LT;       // 符号付き未満

   // 加減算・AND・OR
   always @(A or B or C) begin
      case(C)
        `IADD :  tmp <= {1'b0, A} + {1'b0, B};
        `ISUB :  tmp <= {1'b0, A} - {1'b0, B};
        `IAND :  tmp <= {1'b0, (A & B)};
        `IOR  :  tmp <= {1'b0, (A | B)};
        default: tmp <= {1'b0, A} - {1'b0, B}; // 比較命令は減算で判定
      endcase
   end

   assign V   = (A[31] & ~B[31] & ~tmp[31]) | (~A[31] & B[31] & tmp[31]);
   assign Z   = (tmp[31:0] == 32'b0);
   assign LTU = tmp[32];
   assign LT  = tmp[31] ^ V;

   // 出力マルチプレクサ（MUL演算はMEMステージで実行）
   always @(A or B or C or tmp or LT or LTU or Z) begin
      case(C)
        `IADD    : Y <= tmp[31:0];
        `ISUB    : Y <= tmp[31:0];
        `IAND    : Y <= tmp[31:0];
        `IOR     : Y <= tmp[31:0];
        `IXOR    : Y <= A ^ B;
        `ILT     : Y <= {31'b0, LT};
        `ILTU    : Y <= {31'b0, LTU};
        `IGE     : Y <= {31'b0, ~LT};
        `INE     : Y <= {31'b0, ~Z};
        `IEQ     : Y <= {31'b0, Z};
        `IGEU    : Y <= {31'b0, ~LTU};
        // rv32m: MUL/DIV/REM はMEMステージで実行（EXステージのクリティカルパスから除外）
        default  : Y <= tmp[31:0];
      endcase
   end

endmodule