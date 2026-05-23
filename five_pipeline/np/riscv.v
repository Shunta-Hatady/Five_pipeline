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

  //==========================================================
  // ステージ1: IF (Instruction Fetch)
  //==========================================================
  reg  [31:0] PC;
  wire [31:0] PC4;
  wire [31:0] IDATA;
  wire [31:0] IF_IR;

  assign PC4   = PC + 4;
  assign IDATA = imem[PC[31:2]];

`ifdef LITTLE_ENDIAN
  assign IF_IR = {IDATA[7:0], IDATA[15:8], IDATA[23:16], IDATA[31:24]};
`endif
`ifdef BIG_ENDIAN
  assign IF_IR = IDATA;
`endif

  //--------------------------------------------------
  // IF/ID パイプラインレジスタ
  //--------------------------------------------------
  reg [31:0] IF_ID_PC;
  reg [31:0] IF_ID_PC4;
  reg [31:0] IF_ID_IR;

  //==========================================================
  // ステージ2: ID (Instruction Decode)
  //==========================================================

  // IF_ID_IR からフィールド抽出
  wire [ 6:0] ID_OP  = IF_ID_IR[ 6: 0];
  wire [ 4:0] ID_RD  = IF_ID_IR[11: 7];
  wire [ 2:0] ID_F3  = IF_ID_IR[14:12];
  wire [ 4:0] ID_RS1 = IF_ID_IR[19:15];
  wire [ 4:0] ID_RS2 = IF_ID_IR[24:20];
  wire [ 6:0] ID_F7  = IF_ID_IR[31:25];

  // デコード出力
  reg  [ 2:0] ID_FT;
  reg  [ 4:0] ID_IALU;
  reg         ID_RS1_PC;
  reg         ID_RS1_Z;
  reg  [31:0] ID_IMM;
  reg  [ 1:0] ID_DMWE;
  reg  [ 1:0] ID_DMRE;
  reg         ID_DMSE;
  reg         ID_PC_E;
  reg  [ 1:0] ID_WB_MUX;
  reg  [ 4:0] ID_D_RD;

  // 命令デコーダ
  always @(*) begin
    ID_FT     = 3'b000;
    ID_IALU   = `IADD;
    ID_WB_MUX = 2'b00;
    ID_DMWE   = 2'b00;
    ID_DMRE   = 2'b00;
    ID_DMSE   = 1'b0;
    ID_RS1_PC = 1'b0;
    ID_RS1_Z  = 1'b0;
    ID_PC_E   = 1'b0;
    case(ID_OP)
      `OP_LUI   : begin ID_FT = `FT_U; ID_RS1_Z  = 1'b1; end
      `OP_AUIPC : begin ID_FT = `FT_U; ID_RS1_PC = 1'b1; end
      `OP_JAL   : begin ID_FT = `FT_J; ID_RS1_PC = 1'b1; ID_PC_E = 1'b1; ID_WB_MUX = 2'b10; end
      `OP_JALR  : begin ID_FT = `FT_I; ID_PC_E   = 1'b1; ID_WB_MUX = 2'b10; end
      `OP_BR    : begin
        ID_FT   = `FT_B;
        ID_PC_E = 1'b1;
        case(ID_F3)
          3'b000: ID_IALU = `IEQ;
          3'b001: ID_IALU = `INE;
          3'b100: ID_IALU = `ILT;
          3'b101: ID_IALU = `IGE;
          3'b110: ID_IALU = `ILTU;
          3'b111: ID_IALU = `IGEU;
        endcase
      end
      `OP_LOAD  : begin
        ID_FT     = `FT_I;
        ID_WB_MUX = 2'b01;
        case(ID_F3)
          3'b000: begin ID_DMRE = 2'b01; ID_DMSE = 1'b1; end
          3'b001: begin ID_DMRE = 2'b10; ID_DMSE = 1'b1; end
          3'b010: begin ID_DMRE = 2'b11; ID_DMSE = 1'b1; end
          3'b100: begin ID_DMRE = 2'b01; end
          3'b101: begin ID_DMRE = 2'b10; end
          3'b110: begin ID_DMRE = 2'b11; end
        endcase
      end
      `OP_STORE : begin
        ID_FT = `FT_S;
        case(ID_F3)
          3'b000: ID_DMWE = 2'b01;
          3'b001: ID_DMWE = 2'b10;
          3'b010: ID_DMWE = 2'b11;
        endcase
      end
      `OP_FUNC1 : begin
        ID_FT = `FT_I;
        case(ID_F3)
          3'b000: ID_IALU = `IADD;
          3'b001: if(ID_F7 == 7'b0000000) ID_IALU = `ISLL;
          3'b010: ID_IALU = `ILT;
          3'b011: ID_IALU = `ILTU;
          3'b100: ID_IALU = `IXOR;
          3'b101: if(ID_F7 == 7'b0000000)     ID_IALU = `ISRL;
                  else if(ID_F7 == 7'b0100000) ID_IALU = `ISRA;
          3'b110: ID_IALU = `IOR;
          3'b111: ID_IALU = `IAND;
        endcase
      end
      `OP_FUNC2 : begin
        ID_FT = `FT_R;
        case(ID_F3)
          3'b000: if(ID_F7 == 7'b0000000)     ID_IALU = `IADD;
                  else if(ID_F7 == 7'b0100000) ID_IALU = `ISUB;
                  else if(ID_F7 == 7'b0000001) ID_IALU = `IMUL;
          3'b001: if(ID_F7 == 7'b0000000)     ID_IALU = `ISLL;
                  else if(ID_F7 == 7'b0000001) ID_IALU = `IMULH;
          3'b010: if(ID_F7 == 7'b0000000)     ID_IALU = `ILT;
                  else if(ID_F7 == 7'b0100001) ID_IALU = `IMULHSU;
          3'b011: if(ID_F7 == 7'b0000000)     ID_IALU = `ILTU;
                  else if(ID_F7 == 7'b0000001) ID_IALU = `IMULHU;
          3'b100: if(ID_F7 == 7'b0000000)     ID_IALU = `IXOR;
                  else if(ID_F7 == 7'b0000001) ID_IALU = `IDIV;
          3'b101: if(ID_F7 == 7'b0000000)     ID_IALU = `ISRL;
                  else if(ID_F7 == 7'b0100000) ID_IALU = `ISRA;
                  else if(ID_F7 == 7'b0000001) ID_IALU = `IDIVU;
          3'b110: if(ID_F7 == 7'b0000000)     ID_IALU = `IOR;
                  else if(ID_F7 == 7'b0000001) ID_IALU = `IREM;
          3'b111: if(ID_F7 == 7'b0000000)     ID_IALU = `IAND;
                  else if(ID_F7 == 7'b0000001) ID_IALU = `IREMU;
        endcase
      end
      `OP_FENCEX: begin end
      `OP_FUNC3 : begin end
    endcase
  end

  // デスティネーションレジスタ番号
  always @(*) begin
    ID_D_RD = 5'b0;
    case(ID_FT)
      `FT_R, `FT_I, `FT_U, `FT_J: ID_D_RD = ID_RD;
    endcase
  end

  // 即値生成
  always @(*) begin
    ID_IMM = {{20{IF_ID_IR[31]}}, IF_ID_IR[31:20]};
    case(ID_FT)
      `FT_S: ID_IMM = {{20{IF_ID_IR[31]}}, ID_F7, ID_RD};
      `FT_B: ID_IMM = {{20{IF_ID_IR[31]}}, IF_ID_IR[7], IF_ID_IR[30:25], IF_ID_IR[11:8], 1'b0};
      `FT_U: ID_IMM = {IF_ID_IR[31:12], 12'h000};
      `FT_J: ID_IMM = {{11{IF_ID_IR[31]}}, IF_ID_IR[31], IF_ID_IR[19:12], IF_ID_IR[20], IF_ID_IR[30:21], 1'b0};
    endcase
  end

  // M拡張命令検出（MUL/DIV/REM: IALU[4:3] == 2'b11）MEMステージで実行するため
  wire ID_IS_MUL = (ID_IALU[4:3] == 2'b11);

  //--------------------------------------------------
  // レジスタファイル（IDステージで読み出し、WBステージで書き込み）
  //--------------------------------------------------
  wire [31:0] ID_RF_DATA1, ID_RF_DATA2;

  // WBステージのライトバック信号（後述）
  wire [ 4:0] WB_D_RD;

  rf rf(
    .CLK(CLK),
    .RNUM1(ID_RS1), .RDATA1(ID_RF_DATA1),
    .RNUM2(ID_RS2), .RDATA2(ID_RF_DATA2),
    .WNUM(WB_D_RD),  .WDATA(WB_RD_VAL)
  );

  //--------------------------------------------------
  // WB→ID フォワーディング
  // Verilog シミュレーションではレジスタファイルへの非ブロッキング書き込みは
  // 同クロックの組み合わせ読み出しに反映されないため、
  // WBステージがIDステージと同じレジスタを書き込む場合（3命令差ハザード）に
  // WB値を直接転送する。
  //--------------------------------------------------
  wire [31:0] ID_RS1_FWD;
  wire [31:0] ID_RS2_FWD;

  assign ID_RS1_FWD = (WB_D_RD != 5'b0 && WB_D_RD == ID_RS1 && !ID_RS1_PC && !ID_RS1_Z)
                      ? WB_RD_VAL : ID_RF_DATA1;
  assign ID_RS2_FWD = (WB_D_RD != 5'b0 && WB_D_RD == ID_RS2)
                      ? WB_RD_VAL : ID_RF_DATA2;

  //--------------------------------------------------
  // ID/EX パイプラインレジスタ
  //--------------------------------------------------
  reg [31:0] ID_EX_PC;
  reg [31:0] ID_EX_PC4;
  reg [ 2:0] ID_EX_FT;
  reg [ 4:0] ID_EX_D_RD;
  reg [ 4:0] ID_EX_IALU;
  reg        ID_EX_RS1_PC;
  reg        ID_EX_RS1_Z;
  reg [31:0] ID_EX_IMM;
  reg [ 1:0] ID_EX_DMWE;
  reg [ 1:0] ID_EX_DMRE;
  reg        ID_EX_DMSE;
  reg        ID_EX_PC_E;
  reg [ 1:0] ID_EX_WB_MUX;
  reg [31:0] ID_EX_RF_DATA1;
  reg [31:0] ID_EX_RF_DATA2;
  reg [ 4:0] ID_EX_RS1_NUM;  // フォワーディング判定用にRS1/RS2番号を保持
  reg [ 4:0] ID_EX_RS2_NUM;
  reg        ID_EX_IS_MUL;  // EXステージがMUL命令か

  //==========================================================
  // ステージ3: EX (Execute)
  //==========================================================

  //--------------------------------------------------
  // データフォワーディング
  // ① EX/MEM → EX フォワーディングパス
  // ② MEM/WB → EX フォワーディングパス
  //--------------------------------------------------

  // EX/MEMのライトバック値（WB_MUXに応じてPC4またはALU結果）
  wire [31:0] EX_MEM_WB_VAL;
  assign EX_MEM_WB_VAL = (EX_MEM_WB_MUX == 2'b10) ? EX_MEM_PC4 : EX_MEM_ALU_RESULT;

  // RS1フォワーディング選択（EX/MEM優先、ただしMULは結果未確定のため除外）
  wire [1:0] FWD_A_SEL;
  assign FWD_A_SEL =
    (EX_MEM_D_RD != 5'b0 && EX_MEM_D_RD == ID_EX_RS1_NUM && EX_MEM_WB_MUX != 2'b01 && !EX_MEM_IS_MUL) ? 2'b01 :
    (MEM_WB_D_RD != 5'b0 && MEM_WB_D_RD == ID_EX_RS1_NUM)                                              ? 2'b10 :
    2'b00;

  // RS2フォワーディング選択（EX/MEM優先、ただしMULは結果未確定のため除外）
  wire [1:0] FWD_B_SEL;
  assign FWD_B_SEL =
    (EX_MEM_D_RD != 5'b0 && EX_MEM_D_RD == ID_EX_RS2_NUM && EX_MEM_WB_MUX != 2'b01 && !EX_MEM_IS_MUL) ? 2'b01 :
    (MEM_WB_D_RD != 5'b0 && MEM_WB_D_RD == ID_EX_RS2_NUM)                                              ? 2'b10 :
    2'b00;

  wire [31:0] EX_FWD_A;
  wire [31:0] EX_FWD_B;

  assign EX_FWD_A = (FWD_A_SEL == 2'b01) ? EX_MEM_WB_VAL :
                    (FWD_A_SEL == 2'b10) ? WB_RD_VAL      :
                                           ID_EX_RF_DATA1;

  assign EX_FWD_B = (FWD_B_SEL == 2'b01) ? EX_MEM_WB_VAL :
                    (FWD_B_SEL == 2'b10) ? WB_RD_VAL      :
                                           ID_EX_RF_DATA2;

  // ALU入力セレクト
  wire [31:0] EX_RS1_VAL;
  wire [31:0] EX_RS2_IMM_VAL;

  assign EX_RS1_VAL = (ID_EX_RS1_PC) ? ID_EX_PC :
                      (ID_EX_RS1_Z)  ? 32'h0    :
                                       EX_FWD_A;

  // R型・B型はRS2、それ以外は即値
  assign EX_RS2_IMM_VAL = (ID_EX_FT == `FT_R || ID_EX_FT == `FT_B) ? EX_FWD_B : ID_EX_IMM;

  wire [31:0] EX_ALU_RESULT;
  wire [31:0] EX_SFT_RESULT;
  wire [31:0] EX_E_RD_VAL;

  alu   e_alu(.C(ID_EX_IALU), .Y(EX_ALU_RESULT), .A(EX_RS1_VAL),  .B(EX_RS2_IMM_VAL));
  shift e_sft(.C(ID_EX_IALU), .Y(EX_SFT_RESULT), .A(EX_RS1_VAL),  .B(EX_RS2_IMM_VAL[4:0]));

  // IALU[4:2] == 3'b100 はシフト命令
  assign EX_E_RD_VAL = (ID_EX_IALU[4:2] == 3'b100) ? EX_SFT_RESULT : EX_ALU_RESULT;

  // 分岐先アドレス
  // JALR: rs1+imm（ALU結果）、それ以外: PC+imm
  wire [31:0] EX_BR_ADDR;
  assign EX_BR_ADDR = (ID_EX_FT == `FT_I) ? EX_ALU_RESULT : (ID_EX_PC + ID_EX_IMM);

  // 分岐成立判定
  // B型は ALU_RESULT[0] が1のとき成立（IEQ/INE/ILT/IGE/ILTU/IGEUのフラグ出力）
  wire EX_BRANCH_TAKEN;
  assign EX_BRANCH_TAKEN = ID_EX_PC_E && !((ID_EX_FT == `FT_B) && !EX_ALU_RESULT[0]);

  // FLUSH: 分岐成立 → IFとIDの命令をキャンセル（2サイクルペナルティ）
  wire FLUSH;
  assign FLUSH = EX_BRANCH_TAKEN;

  //--------------------------------------------------
  // EX/MEM パイプラインレジスタ
  //--------------------------------------------------
  reg [31:0] EX_MEM_PC4;
  reg [ 4:0] EX_MEM_D_RD;
  reg [ 1:0] EX_MEM_WB_MUX;
  reg [31:0] EX_MEM_ALU_RESULT;
  reg [ 1:0] EX_MEM_DMWE;
  reg [ 1:0] EX_MEM_DMRE;
  reg        EX_MEM_DMSE;
  reg [31:0] EX_MEM_STORE_VAL;
  reg        EX_MEM_IS_MUL;   // MEMステージでMUL演算するか
  reg [ 4:0] EX_MEM_IALU;     // MUL種別（IMUL/IMULH/IMULHSU/IMULHU）
  reg [31:0] EX_MEM_RS1_VAL;  // MULオペランドA（ラッチ済み）

  //==========================================================
  // ステージ4: MEM (Memory)
  //==========================================================
  wire [31:0] MEM_DATAI;
  wire [31:2] MEM_MADDR;
  wire [31:0] MEM_MDATAI, MEM_MDATAI_DMEM, MEM_MDATAO;
  wire [ 3:0] MEM_MWSTB;

  daligner daligner(
    .CLK(CLK),
    .ADDRI(EX_MEM_ALU_RESULT),
    .DATAI(EX_MEM_STORE_VAL),
    .DATAO(MEM_DATAI),
    .WE(EX_MEM_DMWE),
    .RE(EX_MEM_DMRE),
    .SE(EX_MEM_DMSE),
    .MADDR(MEM_MADDR),
    .MDATAO(MEM_MDATAO),
    .MDATAI(MEM_MDATAI),
    .MWSTB(MEM_MWSTB)
  );

  wire MEM_CEM;
  assign MEM_CEM  = ((|EX_MEM_DMWE || |EX_MEM_DMRE) && (MEM_MADDR[31:20] == DMEM_BASE[31:20]));
  assign MEM_MDATAI = MEM_MDATAI_DMEM;

  dmem #(.DMEM_SIZE(DMEM_SIZE), .INIT_FILE(DMEM_FILE)) dmem(
    .CLK(CLK),
    .ADDR(MEM_MADDR),
    .DATAI(MEM_MDATAO),
    .DATAO(MEM_MDATAI_DMEM),
    .CE(MEM_CEM),
    .WSTB(MEM_MWSTB)
  );

  //--------------------------------------------------
  // MEMステージ: MUL演算（EX/MEMラッチ済みオペランドから計算）
  // クリティカルパス: FF出力 → 乗算組み合わせ回路 → FF入力（EXステージと独立）
  //--------------------------------------------------
  // DSP48E1推論のため $signed() による 32bit×32bit として記述
  wire signed [63:0] MEM_MUL_SS = $signed(EX_MEM_RS1_VAL) * $signed(EX_MEM_STORE_VAL);
  wire signed [64:0] MEM_MUL_SU_FULL = $signed(EX_MEM_RS1_VAL) * $signed({1'b0, EX_MEM_STORE_VAL});
  wire signed [63:0] MEM_MUL_SU = MEM_MUL_SU_FULL[63:0];
  wire        [63:0] MEM_MUL_UU = {32'b0, EX_MEM_RS1_VAL} * {32'b0, EX_MEM_STORE_VAL};

  reg [31:0] MEM_MUL_RESULT;
  always @(*) begin
    case(EX_MEM_IALU)
      `IMUL    : MEM_MUL_RESULT = MEM_MUL_SS[31:0];
      `IMULH   : MEM_MUL_RESULT = MEM_MUL_SS[63:32];
      `IMULHSU : MEM_MUL_RESULT = MEM_MUL_SU[63:32];
      `IMULHU  : MEM_MUL_RESULT = MEM_MUL_UU[63:32];
      // DIV/REMは組み合わせ実装では周波数未達のため未実装（マルチサイクル化が必要）
      default  : MEM_MUL_RESULT = 32'h0;
    endcase
  end

  //--------------------------------------------------
  // MEM/WB パイプラインレジスタ
  //--------------------------------------------------
  reg [ 4:0] MEM_WB_D_RD;
  reg [ 1:0] MEM_WB_WB_MUX;
  reg [31:0] MEM_WB_ALU_RESULT;
  reg [31:0] MEM_WB_MEM_DATA;
  reg [31:0] MEM_WB_PC4;
  reg        MEM_WB_IS_MUL;
  reg [31:0] MEM_WB_MUL_RESULT;

  //==========================================================
  // ステージ5: WB (Write Back)
  //==========================================================
  assign WB_D_RD = MEM_WB_D_RD;

  always @(*) begin
    case(MEM_WB_WB_MUX)
      2'b01:   WB_RD_VAL = MEM_WB_MEM_DATA;
      2'b10:   WB_RD_VAL = MEM_WB_PC4;
      default: WB_RD_VAL = MEM_WB_IS_MUL ? MEM_WB_MUL_RESULT : MEM_WB_ALU_RESULT;
    endcase
  end

  //==========================================================
  // ハザード制御
  //==========================================================

  // ロードユーズハザード検出:
  //   EXステージがLOAD（ID_EX_WB_MUX==01）かつ
  //   IDステージの命令がそのデスティネーションレジスタを参照する場合、1サイクルストール
  wire LOAD_USE_HAZARD;
  assign LOAD_USE_HAZARD =
    (ID_EX_WB_MUX == 2'b01) && (ID_EX_D_RD != 5'b0) &&
    (
      (ID_EX_D_RD == ID_RS1 && !ID_RS1_PC && !ID_RS1_Z) ||
      (ID_EX_D_RD == ID_RS2 && (ID_FT == `FT_R || ID_FT == `FT_S || ID_FT == `FT_B))
    );

  // MULユーズハザード検出:
  //   EXステージがMUL命令かつIDステージがそのRDを使う場合、1サイクルストール
  //   （MUL結果はMEMステージで計算されMEM/WBに入るため、EX/MEMからの転送不可）
  wire MUL_USE_HAZARD;
  assign MUL_USE_HAZARD =
    ID_EX_IS_MUL && (ID_EX_D_RD != 5'b0) &&
    (
      (ID_EX_D_RD == ID_RS1 && !ID_RS1_PC && !ID_RS1_Z) ||
      (ID_EX_D_RD == ID_RS2 && (ID_FT == `FT_R || ID_FT == `FT_S || ID_FT == `FT_B))
    );

  wire STALL;
  assign STALL = LOAD_USE_HAZARD || MUL_USE_HAZARD;

  //==========================================================
  // パイプラインレジスタ更新（クロック同期）
  //==========================================================

  // PC（同期リセット: FLUSH/STALLのCLR誤マッピングを防ぐ）
  always @(posedge CLK) begin
    if(RST)
      PC <= 32'h0000_0000;
    else if(!STALL) begin
      if(FLUSH) PC <= EX_BR_ADDR;
      else      PC <= PC4;
    end
    // STALL時: PCを保持
  end

  // IF/ID レジスタ（同期リセット）
  // FLUSH時: NOPを挿入、STALL時: 保持、通常: 更新
  always @(posedge CLK) begin
    if(RST) begin
      IF_ID_PC  <= 32'h0;
      IF_ID_PC4 <= 32'h0;
      IF_ID_IR  <= 32'h0000_0013; // NOP (addi x0,x0,0)
    end else if(FLUSH) begin
      IF_ID_PC  <= 32'h0;
      IF_ID_PC4 <= 32'h0;
      IF_ID_IR  <= 32'h0000_0013;
    end else if(!STALL) begin
      IF_ID_PC  <= PC;
      IF_ID_PC4 <= PC4;
      IF_ID_IR  <= IF_IR;
    end
    // STALL時: 保持（何もしない）
  end

  // ID/EX レジスタ（同期リセット）
  // FLUSH・STALL時: NOPバブルを挿入、通常: IDステージの値を転送
  always @(posedge CLK) begin
    if(RST || FLUSH || STALL) begin
      ID_EX_PC       <= 32'h0;
      ID_EX_PC4      <= 32'h0;
      ID_EX_FT       <= 3'b000;
      ID_EX_D_RD     <= 5'b0;
      ID_EX_IALU     <= `IADD;
      ID_EX_RS1_PC   <= 1'b0;
      ID_EX_RS1_Z    <= 1'b0;
      ID_EX_IMM      <= 32'h0;
      ID_EX_DMWE     <= 2'b00;
      ID_EX_DMRE     <= 2'b00;
      ID_EX_DMSE     <= 1'b0;
      ID_EX_PC_E     <= 1'b0;
      ID_EX_WB_MUX   <= 2'b00;
      ID_EX_RF_DATA1 <= 32'h0;
      ID_EX_RF_DATA2 <= 32'h0;
      ID_EX_RS1_NUM  <= 5'b0;
      ID_EX_RS2_NUM  <= 5'b0;
      ID_EX_IS_MUL   <= 1'b0;
    end else begin
      ID_EX_PC       <= IF_ID_PC;
      ID_EX_PC4      <= IF_ID_PC4;
      ID_EX_FT       <= ID_FT;
      ID_EX_D_RD     <= ID_D_RD;
      ID_EX_IALU     <= ID_IALU;
      ID_EX_RS1_PC   <= ID_RS1_PC;
      ID_EX_RS1_Z    <= ID_RS1_Z;
      ID_EX_IMM      <= ID_IMM;
      ID_EX_DMWE     <= ID_DMWE;
      ID_EX_DMRE     <= ID_DMRE;
      ID_EX_DMSE     <= ID_DMSE;
      ID_EX_PC_E     <= ID_PC_E;
      ID_EX_WB_MUX   <= ID_WB_MUX;
      ID_EX_RF_DATA1 <= ID_RS1_FWD;
      ID_EX_RF_DATA2 <= ID_RS2_FWD;
      ID_EX_RS1_NUM  <= ID_RS1;
      ID_EX_RS2_NUM  <= ID_RS2;
      ID_EX_IS_MUL   <= ID_IS_MUL;
    end
  end

  // EX/MEM レジスタ（同期リセット）
  always @(posedge CLK) begin
    if(RST) begin
      EX_MEM_PC4        <= 32'h0;
      EX_MEM_D_RD       <= 5'b0;
      EX_MEM_WB_MUX     <= 2'b00;
      EX_MEM_ALU_RESULT <= 32'h0;
      EX_MEM_DMWE       <= 2'b00;
      EX_MEM_DMRE       <= 2'b00;
      EX_MEM_DMSE       <= 1'b0;
      EX_MEM_STORE_VAL  <= 32'h0;
      EX_MEM_IS_MUL     <= 1'b0;
      EX_MEM_IALU       <= `IADD;
      EX_MEM_RS1_VAL    <= 32'h0;
    end else begin
      EX_MEM_PC4        <= ID_EX_PC4;
      EX_MEM_D_RD       <= ID_EX_D_RD;
      EX_MEM_WB_MUX     <= ID_EX_WB_MUX;
      EX_MEM_ALU_RESULT <= EX_E_RD_VAL;
      EX_MEM_DMWE       <= ID_EX_DMWE;
      EX_MEM_DMRE       <= ID_EX_DMRE;
      EX_MEM_DMSE       <= ID_EX_DMSE;
      EX_MEM_STORE_VAL  <= EX_FWD_B; // フォワーディング済みRS2値（STORE用 兼 MUL RS2）
      EX_MEM_IS_MUL     <= ID_EX_IS_MUL;
      EX_MEM_IALU       <= ID_EX_IALU;
      EX_MEM_RS1_VAL    <= EX_RS1_VAL; // MUL RS1（フォワーディング・PC/Z選択済み）
    end
  end

  // MEM/WB レジスタ（同期リセット）
  always @(posedge CLK) begin
    if(RST) begin
      MEM_WB_D_RD        <= 5'b0;
      MEM_WB_WB_MUX      <= 2'b00;
      MEM_WB_ALU_RESULT  <= 32'h0;
      MEM_WB_MEM_DATA    <= 32'h0;
      MEM_WB_PC4         <= 32'h0;
      MEM_WB_IS_MUL      <= 1'b0;
      MEM_WB_MUL_RESULT  <= 32'h0;
    end else begin
      MEM_WB_D_RD        <= EX_MEM_D_RD;
      MEM_WB_WB_MUX      <= EX_MEM_WB_MUX;
      MEM_WB_ALU_RESULT  <= EX_MEM_ALU_RESULT;
      MEM_WB_MEM_DATA    <= MEM_DATAI;
      MEM_WB_PC4         <= EX_MEM_PC4;
      MEM_WB_IS_MUL      <= EX_MEM_IS_MUL;
      MEM_WB_MUL_RESULT  <= MEM_MUL_RESULT;
    end
  end

endmodule