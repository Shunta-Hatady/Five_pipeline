`include "riscv.vh"
`include "inst.vh"
`include "alu.vh"

module riscv
  #(
    parameter IMEM_BASE = 32'h0000_0000,
    parameter IMEM_SIZE = 32768,
    parameter IMEM_FILE = "prog.mif",
    parameter DMEM_BASE = 32'h0010_0000,
    parameter DMEM_SIZE = 32768,
    parameter DMEM_FILE = "data.mif"
    )
  (
   input        CLK,
   input        RSTN,
   output reg [31:0] WB_RD_VAL
   );

  wire RST;
  assign RST = ~RSTN;

  //--------------------------------------------------
  // 命令メモリ
  //--------------------------------------------------
  reg [31:0] imem[0:IMEM_SIZE-1];
  initial begin
    $readmemh(IMEM_FILE, imem);
  end

  //--------------------------------------------------
  // FDステージのレジスタ
  //--------------------------------------------------
  reg  [31:0] PC;
  wire [31:0] PC4;
  wire [31:0] IDATA;
  wire [31:0] IR;

  // EMWステージへ渡すパイプラインレジスタ
  reg  [31:0] EMW_PC;
  reg  [31:0] EMW_PC4;
  reg  [31:0] EMW_IR;
  reg  [ 2:0] EMW_FT;
  reg  [ 4:0] EMW_D_RD;
  reg  [ 4:0] EMW_IALU;
  reg         EMW_RS1_PC;
  reg         EMW_RS1_Z;
  reg  [31:0] EMW_IMM;
  reg  [ 1:0] EMW_DMWE;
  reg  [ 1:0] EMW_DMRE;
  reg         EMW_DMSE;
  reg         EMW_PC_E;
  reg  [ 1:0] EMW_WB_MUX;
  reg  [31:0] EMW_RF_DATA1;
  reg  [31:0] EMW_RF_DATA2;

  //--------------------------------------------------
  // FDステージ：デコード信号（組み合わせ回路）
  //--------------------------------------------------
  reg  [ 2:0] FT;
  reg  [ 4:0] IALU;
  reg         RS1_PC;
  reg         RS1_Z;
  reg  [31:0] IMM;
  reg  [ 1:0] DMWE;
  reg  [ 1:0] DMRE;
  reg         DMSE;
  reg         PC_E;
  reg  [ 1:0] WB_MUX;
  reg  [ 4:0] D_RD;

  assign PC4   = PC + 4;
  assign IDATA = imem[PC[31:2]];

`ifdef LITTLE_ENDIAN
  assign IR = {IDATA[7:0], IDATA[15:8], IDATA[23:16], IDATA[31:24]};
`endif
`ifdef BIG_ENDIAN
  assign IR = IDATA;
`endif

  // 命令デコーダ（FDステージ）
  always @(IR) begin
    FT     <= 3'b000;
    IALU   <= `IADD;
    WB_MUX <= 2'b00;
    DMWE   <= 2'b00;
    DMRE   <= 2'b00;
    DMSE   <= 1'b0;
    RS1_PC <= 1'b0;
    RS1_Z  <= 1'b0;
    PC_E   <= 1'b0;
    case(`IR_OP)
      `OP_LUI   : begin FT <= `FT_U; RS1_Z  <= 1'b1; end
      `OP_AUIPC : begin FT <= `FT_U; RS1_PC <= 1'b1; end
      `OP_JAL   : begin FT <= `FT_J; RS1_PC <= 1'b1; PC_E <= 1'b1; WB_MUX <= 2'b10; end
      `OP_JALR  : begin FT <= `FT_I; PC_E   <= 1'b1; WB_MUX <= 2'b10; end
      `OP_BR    : begin
        FT   <= `FT_B;
        PC_E <= 1'b1;
        case(`IR_F3)
          3'b000: IALU <= `IEQ;
          3'b001: IALU <= `INE;
          3'b100: IALU <= `ILT;
          3'b101: IALU <= `IGE;
          3'b110: IALU <= `ILTU;
          3'b111: IALU <= `IGEU;
        endcase
      end
      `OP_LOAD  : begin
        FT     <= `FT_I;
        WB_MUX <= 2'b01;
        case(`IR_F3)
          3'b000: begin DMRE <= 2'b01; DMSE <= 1'b1; end
          3'b001: begin DMRE <= 2'b10; DMSE <= 1'b1; end
          3'b010: begin DMRE <= 2'b11; DMSE <= 1'b1; end
          3'b100: begin DMRE <= 2'b01; end
          3'b101: begin DMRE <= 2'b10; end
          3'b110: begin DMRE <= 2'b11; end
        endcase
      end
      `OP_STORE : begin
        FT <= `FT_S;
        case(`IR_F3)
          3'b000: DMWE <= 2'b01;
          3'b001: DMWE <= 2'b10;
          3'b010: DMWE <= 2'b11;
        endcase
      end
      `OP_FUNC1 : begin
        FT <= `FT_I;
        case(`IR_F3)
          3'b000: IALU <= `IADD;
          3'b001: if(`IR_F7 == 7'b0000000) IALU <= `ISLL;
          3'b010: IALU <= `ILT;
          3'b011: IALU <= `ILTU;
          3'b100: IALU <= `IXOR;
          3'b101: if(`IR_F7 == 7'b0000000) IALU <= `ISRL;
                  else if(`IR_F7 == 7'b0100000) IALU <= `ISRA;
          3'b110: IALU <= `IOR;
          3'b111: IALU <= `IAND;
        endcase
      end
      `OP_FUNC2 : begin
        FT <= `FT_R;
        case(`IR_F3)
          3'b000: if(`IR_F7 == 7'b0000000) IALU <= `IADD;
                  else if(`IR_F7 == 7'b0100000) IALU <= `ISUB;
          3'b001: if(`IR_F7 == 7'b0000000) IALU <= `ISLL;
          3'b010: if(`IR_F7 == 7'b0000000) IALU <= `ILT;
          3'b011: if(`IR_F7 == 7'b0000000) IALU <= `ILTU;
          3'b100: if(`IR_F7 == 7'b0000000) IALU <= `IXOR;
          3'b101: if(`IR_F7 == 7'b0000000) IALU <= `ISRL;
                  else if(`IR_F7 == 7'b0100000) IALU <= `ISRA;
          3'b110: if(`IR_F7 == 7'b0000000) IALU <= `IOR;
          3'b111: if(`IR_F7 == 7'b0000000) IALU <= `IAND;
        endcase
      end
      `OP_FENCEX: begin end
      `OP_FUNC3 : begin end
    endcase
  end

  // D_RD（デスティネーションレジスタ番号）
  always @(*) begin
    D_RD <= 5'b0;
    case(FT)
      `FT_R, `FT_I, `FT_U, `FT_J: D_RD <= `IR_RD;
    endcase
  end

  // 即値生成
  always @(*) begin
    IMM <= {{20{IR[31]}}, IR[31:20]};
    case(FT)
      `FT_S: IMM <= {{20{IR[31]}}, `IR_F7, `IR_RD};
      `FT_B: IMM <= {{20{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};
      `FT_U: IMM <= {IR[31:12], 12'h000};
      `FT_J: IMM <= {{11{IR[31]}}, IR[31], IR[19:12], IR[20], IR[30:21], 1'b0};
    endcase
  end

  //--------------------------------------------------
  // レジスタファイル読み出し（FDステージ）
  //--------------------------------------------------
  wire [31:0] RF_DATA1, RF_DATA2;

  rf rf(
    .CLK(CLK),
    .RNUM1(`IR_RS1), .RDATA1(RF_DATA1),
    .RNUM2(`IR_RS2), .RDATA2(RF_DATA2),
    .WNUM(EMW_D_RD), .WDATA(WB_RD_VAL)
  );

  //--------------------------------------------------
  // データフォワーディング
  // EMWステージの結果をFDステージのRS1/RS2に転送
  //--------------------------------------------------
  wire [31:0] FWD_RS1, FWD_RS2;

  // WB_RD_VALはEMWステージの書き込みデータ（組み合わせ回路で確定）
  assign FWD_RS1 = ( EMW_D_RD != 5'b0 && EMW_D_RD == `IR_RS1 ) ? WB_RD_VAL : RF_DATA1;
  assign FWD_RS2 = ( EMW_D_RD != 5'b0 && EMW_D_RD == `IR_RS2 ) ? WB_RD_VAL : RF_DATA2;

  //--------------------------------------------------
  // パイプラインレジスタ（FD→EMW）
  // 分岐成立時はNOPを挿入
  //--------------------------------------------------
  wire FLUSH; // 分岐ハザード：NOPをEMWに挿入

  always @(posedge CLK or posedge RST) begin
    if(RST) begin
      EMW_PC      <= 32'h0;
      EMW_PC4     <= 32'h0;
      EMW_IR      <= 32'h0000_0013; // NOP (addi x0,x0,0)
      EMW_FT      <= 3'b000;
      EMW_D_RD    <= 5'b0;
      EMW_IALU    <= `IADD;
      EMW_RS1_PC  <= 1'b0;
      EMW_RS1_Z   <= 1'b0;
      EMW_IMM     <= 32'h0;
      EMW_DMWE    <= 2'b00;
      EMW_DMRE    <= 2'b00;
      EMW_DMSE    <= 1'b0;
      EMW_PC_E    <= 1'b0;
      EMW_WB_MUX  <= 2'b00;
      EMW_RF_DATA1<= 32'h0;
      EMW_RF_DATA2<= 32'h0;
    end
    else if(FLUSH) begin
      // 分岐ハザード：NOPを挿入
      EMW_IR      <= 32'h0000_0013;
      EMW_FT      <= 3'b000;
      EMW_D_RD    <= 5'b0;
      EMW_IALU    <= `IADD;
      EMW_RS1_PC  <= 1'b0;
      EMW_RS1_Z   <= 1'b0;
      EMW_IMM     <= 32'h0;
      EMW_DMWE    <= 2'b00;
      EMW_DMRE    <= 2'b00;
      EMW_DMSE    <= 1'b0;
      EMW_PC_E    <= 1'b0;
      EMW_WB_MUX  <= 2'b00;
      EMW_RF_DATA1<= 32'h0;
      EMW_RF_DATA2<= 32'h0;
    end
    else begin
      EMW_PC      <= PC;
      EMW_PC4     <= PC4;
      EMW_IR      <= IR;
      EMW_FT      <= FT;
      EMW_D_RD    <= D_RD;
      EMW_IALU    <= IALU;
      EMW_RS1_PC  <= RS1_PC;
      EMW_RS1_Z   <= RS1_Z;
      EMW_IMM     <= IMM;
      EMW_DMWE    <= DMWE;
      EMW_DMRE    <= DMRE;
      EMW_DMSE    <= DMSE;
      EMW_PC_E    <= PC_E;
      EMW_WB_MUX  <= WB_MUX;
      EMW_RF_DATA1<= FWD_RS1;
      EMW_RF_DATA2<= FWD_RS2;
    end
  end

  //--------------------------------------------------
  // EMWステージ：実行・メモリ・ライトバック
  //--------------------------------------------------

  // ALU入力
  wire [31:0] EMW_RS1_VAL;
  wire [31:0] EMW_RS2_IMM_VAL;

  assign EMW_RS1_VAL = ( EMW_RS1_PC ) ? EMW_PC :
                       ( EMW_RS1_Z  ) ? 32'h0  :
                                        EMW_RF_DATA1;

  assign EMW_RS2_IMM_VAL = ( EMW_FT == `FT_R || EMW_FT == `FT_B ) 
                           ? EMW_RF_DATA2 : EMW_IMM;

  wire [31:0] ALU_RD_VAL;
  wire [31:0] SFT_RD_VAL;
  wire [31:0] E_RD_VAL;

  alu   e_alu(.C(EMW_IALU), .Y(ALU_RD_VAL), .A(EMW_RS1_VAL), .B(EMW_RS2_IMM_VAL));
  shift e_sft(.C(EMW_IALU), .Y(SFT_RD_VAL), .A(EMW_RS1_VAL), .B(EMW_RS2_IMM_VAL[4:0]));

  assign E_RD_VAL = (EMW_IALU[4:2] == 3'b100) ? SFT_RD_VAL : ALU_RD_VAL;

  // 分岐アドレス
  wire [31:0] BR_ADDR;
  assign BR_ADDR = (EMW_FT == `FT_I) ? ALU_RD_VAL : EMW_PC + EMW_IMM;

  // 分岐成立判定
  wire E_PC_E;
  assign E_PC_E = EMW_PC_E && !((EMW_FT == `FT_B) && !ALU_RD_VAL[0]);

  // FLUSH信号（分岐成立時に次のサイクルでNOPを挿入）
  assign FLUSH = E_PC_E;

  // PC更新
  always @(posedge CLK or posedge RST) begin
    if(RST)
      PC <= 32'h0000_0000;
    else begin
      if(E_PC_E)
        PC <= BR_ADDR;
      else
        PC <= PC4;
    end
  end

  // データメモリ
  wire [31:0] DATAI;
  wire [31:2] MADDR;
  wire [31:0] MDATAI, MDATAI_DMEM, MDATAO;
  wire [ 3:0] MWSTB;

  daligner daligner(
    .CLK(CLK),
    .ADDRI(E_RD_VAL),
    .DATAI(EMW_RF_DATA2),
    .DATAO(DATAI),
    .WE(EMW_DMWE),
    .RE(EMW_DMRE),
    .SE(EMW_DMSE),
    .MADDR(MADDR),
    .MDATAO(MDATAO),
    .MDATAI(MDATAI),
    .MWSTB(MWSTB)
  );

  wire CEM;
  assign CEM = ((|EMW_DMWE || |EMW_DMRE) && (MADDR[31:20] == DMEM_BASE[31:20]));
  assign MDATAI = MDATAI_DMEM;

  dmem #(.DMEM_SIZE(DMEM_SIZE), .INIT_FILE(DMEM_FILE)) dmem(
    .CLK(CLK),
    .ADDR(MADDR),
    .DATAI(MDATAO),
    .DATAO(MDATAI_DMEM),
    .CE(CEM),
    .WSTB(MWSTB)
  );

  // ライトバック
  always @(EMW_WB_MUX or DATAI or EMW_PC4 or E_RD_VAL) begin
    case(EMW_WB_MUX)
      2'b01:   WB_RD_VAL <= DATAI;
      2'b10:   WB_RD_VAL <= EMW_PC4;
      default: WB_RD_VAL <= E_RD_VAL;
    endcase
  end

endmodule
