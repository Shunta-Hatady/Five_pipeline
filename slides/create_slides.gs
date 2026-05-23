/**
 * RISC-Vプロセッサ高速化プレゼン生成スクリプト
 * Google Apps Script (Google Slides)
 *
 * 使い方:
 *  1. https://script.google.com/ を開く
 *  2. このコード全体を貼り付けて実行
 *  3. 実行後、「表示 > 実行ログ」にスライドのURLが表示される
 */

// Google Slides デフォルトサイズ: 720 × 405 pt (10 × 5.625 inch)
// 設計座標系: 10 × 5.625 inch → 1 inch = 72 pt
const PT = 72;

// カラー定数
const DARK   = "#1A1A2E";
const MID    = "#16213E";
const ACCENT = "#0F3A5C";
const BLUE   = "#008BD4";
const CYAN   = "#00D4FF";
const WHITE  = "#FFFFFF";
const LGRAY  = "#CCDDEE";
const YELLOW = "#FFD700";
const GREEN  = "#00E676";

// ===== ヘルパー関数 =====

function newSlide(prs) {
  const sl = prs.appendSlide(SlidesApp.PredefinedLayout.BLANK);
  sl.getBackground().setSolidFill(DARK);
  return sl;
}

function rect(sl, l, t, w, h, fill, border, bw) {
  const sh = sl.insertShape(SlidesApp.ShapeType.RECTANGLE,
    l*PT, t*PT, w*PT, h*PT);
  if (fill) sh.getFill().setSolidFill(fill);
  else      sh.getFill().setTransparent();
  if (border) {
    sh.getBorder().getLineFill().setSolidFill(border);
    sh.getBorder().setWeight(bw || 1.5);
  } else {
    sh.getBorder().setTransparent();
  }
  return sh;
}

function txt(sl, text, l, t, w, h, size, bold, color, align, italic) {
  const tb = sl.insertTextBox(text, l*PT, t*PT, w*PT, h*PT);
  tb.setContentAlignment(SlidesApp.ContentAlignment.MIDDLE);
  const ts = tb.getText().getTextStyle();
  ts.setFontSize(size || 14);
  ts.setBold(bold   || false);
  ts.setItalic(italic || false);
  ts.setForegroundColor(color || WHITE);
  const pa = align === "C" ? SlidesApp.ParagraphAlignment.CENTER
           : align === "R" ? SlidesApp.ParagraphAlignment.END
           :                 SlidesApp.ParagraphAlignment.START;
  tb.getText().getParagraphs().forEach(p =>
    p.getRange().getParagraphStyle().setParagraphAlignment(pa));
  return tb;
}

function header(sl, title, sub) {
  rect(sl, 0, 0, 10, 0.82, ACCENT);
  rect(sl, 0, 0.79, 10, 0.05, BLUE);
  txt(sl, title, 0.3, 0.07, 9.4, 0.56, 20, true, WHITE);
  if (sub) txt(sl, sub, 0.3, 0.60, 9.4, 0.22, 10, false, CYAN);
}

function card(sl, l, t, w, h, fill, border) {
  rect(sl, l, t, w, h, fill || MID, border || BLUE);
}

function pnum(sl, n) {
  txt(sl, n + " / 14", 8.8, 5.33, 1.1, 0.22, 9, false, LGRAY, "R");
}

// ===================================================
// スライド 1: タイトル
// ===================================================
function createPresentation() {
  const prs = SlidesApp.create("RISC-Vプロセッサの高速化設計と評価");
  prs.getSlides()[0].remove();

  let sl = newSlide(prs);
  rect(sl, 0, 1.7, 10, 2.3, ACCENT);
  rect(sl, 0, 1.7, 10, 0.05, BLUE);
  rect(sl, 0, 3.95, 10, 0.05, BLUE);
  txt(sl, "RISC-Vプロセッサの高速化設計と評価",
      0.5, 1.9, 9.0, 0.85, 26, true, WHITE, "C");
  txt(sl, "パイプライン処理による実行時間・消費電力の比較",
      0.5, 2.8, 9.0, 0.55, 16, false, CYAN, "C");
  txt(sl, "コンピュータアーキテクチャ  グループ発表 / 2025年",
      0.5, 4.15, 9.0, 0.35, 12, false, LGRAY, "C");
  pnum(sl, 1);

  // ===================================================
  // スライド 2: 目次
  // ===================================================
  sl = newSlide(prs);
  header(sl, "目次");
  pnum(sl, 2);

  const agenda = [
    ["01","目的"],["02","高速化設計の方針"],["03","ソートアルゴリズムの比較"],
    ["04","高速化設計の詳細"],["05","評価結果"],["06","考察"],
    ["07","感想・役割分担・エフォート"],
  ];
  agenda.forEach(([n, label], i) => {
    const col = i < 4 ? 0 : 1;
    const row = i < 4 ? i : i - 4;
    const lx = 0.3 + col * 4.85;
    const ty = 0.98 + row * 1.06;
    card(sl, lx, ty, 4.55, 0.88);
    txt(sl, n,     lx+0.12, ty+0.1, 0.55, 0.45, 16, true, CYAN);
    txt(sl, label, lx+0.65, ty+0.15, 3.75, 0.45, 14, true, WHITE);
  });

  // ===================================================
  // スライド 3: 目的
  // ===================================================
  sl = newSlide(prs);
  header(sl, "目的", "01 / Purpose");
  pnum(sl, 3);

  card(sl, 0.3, 0.97, 9.4, 1.6);
  txt(sl, "FPGA上にRISC-Vプロセッサを実装し，パイプライン処理を導入することで\n実行時間・消費電力・消費エネルギを改善することを目的とする．",
      0.6, 1.05, 8.8, 1.4, 14, false, WHITE);

  const goals = [
    "▶  逐次実行CPU（選択ソート・クイックソート）を基準として定量比較する",
    "▶  2段パイプライン / 5段パイプラインの効果を実測データで評価する",
    "▶  実行時間・CPI・回路資源・消費電力・消費エネルギを評価指標とする",
  ];
  goals.forEach((t, i) => txt(sl, t, 0.5, 2.75+i*0.57, 9.0, 0.5, 13, false, WHITE));

  // ===================================================
  // スライド 4: 高速化設計の方針
  // ===================================================
  sl = newSlide(prs);
  header(sl, "高速化設計の方針", "02 / Design Policy");
  pnum(sl, 4);

  const steps = [
    ["Step 1  アルゴリズム選択",  "選択ソートとクイックソートを実装し\n実行命令数の少ない方を採用"],
    ["Step 2  動作周波数の向上",  "クリティカルパスを短縮し\nより高い周波数で動作させる"],
    ["Step 3  パイプライン化",    "命令実行を複数ステージに分割し\n複数命令を並列処理する"],
  ];
  steps.forEach(([title, body], i) => {
    const lx = 0.3 + i * 3.17;
    card(sl, lx, 0.97, 3.0, 3.7);
    rect(sl, lx, 0.97, 3.0, 0.45, BLUE);
    txt(sl, title, lx+0.1, 0.99, 2.8, 0.42, 11, true, DARK);
    txt(sl, body,  lx+0.15, 1.55, 2.7, 2.9, 13, false, WHITE);
  });
  txt(sl, "※ パイプライン段数増加 → 高周波化 vs CPI増加 のトレードオフが生じる",
      0.4, 4.9, 9.2, 0.38, 11, false, LGRAY, "L", true);

  // ===================================================
  // スライド 5: ソートアルゴリズムの比較
  // ===================================================
  sl = newSlide(prs);
  header(sl, "ソートアルゴリズムの比較", "03 / Algorithm Comparison");
  pnum(sl, 5);

  const hd5 = ["指標","選択ソート（逐次）","クイックソート（逐次）","優劣"];
  const cx5 = [0.2, 1.7, 4.35, 7.55];
  const cw5 = [1.45, 2.6, 3.15, 2.25];
  rect(sl, 0.2, 0.97, 9.6, 0.42, BLUE);
  hd5.forEach((h,j) => txt(sl, h, cx5[j], 0.99, cw5[j], 0.38, 12, true, DARK, "C"));

  [
    ["実行命令数","3,429,518","118,777","クイック 約29倍少"],
    ["動作周波数","50 MHz","50 MHz","—"],
    ["実行時間","68.59 ms","2.376 ms","クイック 約29倍高速"],
    ["消費電力","0.394 W","0.384 W","ほぼ同等"],
    ["LUT使用率","29.90%","29.90%","同等"],
  ].forEach(([a,b,c,d],i) => {
    rect(sl, 0.2, 1.39+i*0.7, 9.6, 0.65, i%2===0 ? MID : ACCENT);
    [a,b,c,d].forEach((v,j) =>
      txt(sl, v, cx5[j], 1.41+i*0.7, cw5[j], 0.6, 12, false, j===3?YELLOW:WHITE, "C"));
  });
  txt(sl, "→ 実行命令数が約29倍少ないクイックソートをパイプライン化の対象として採用",
      0.3, 5.0, 9.4, 0.42, 13, true, GREEN);

  // ===================================================
  // スライド 6: 逐次CPU
  // ===================================================
  sl = newSlide(prs);
  header(sl, "高速化設計の詳細 ① 逐次実行CPU", "04 / Sequential CPU");
  pnum(sl, 6);

  card(sl, 0.3, 0.97, 9.4, 4.1);
  txt(sl, "設計概要", 0.55, 1.05, 8.5, 0.42, 15, true, CYAN);
  [
    "●  RISC-V（RV32I）命令セットを実装したシングルサイクルCPU",
    "●  1クロックで1命令を完了（CPI ≈ 1.0）",
    "●  動作周波数：50 MHz（クリティカルパスが長く高周波化に制限あり）",
    "●  命令メモリ・データメモリを内蔵（Distributed RAM，各32kW）",
    "●  クイックソートで 118,777 命令，実行時間 2.376 ms",
  ].forEach((t,i) => txt(sl, t, 0.55, 1.58+i*0.5, 8.8, 0.44, 13, false, WHITE));
  rect(sl, 0.3, 5.3, 9.4, 0.04, BLUE);
  txt(sl, "特徴：設計がシンプルで検証しやすく，パイプライン化の基準（ベースライン）として機能",
      0.4, 5.0, 9.2, 0.35, 10, false, LGRAY, "L", true);

  // ===================================================
  // スライド 7: 2段パイプライン
  // ===================================================
  sl = newSlide(prs);
  header(sl, "高速化設計の詳細 ② 2段パイプラインCPU", "04 / 2-Stage Pipeline");
  pnum(sl, 7);

  card(sl, 0.3, 0.97, 5.55, 4.2);
  txt(sl, "設計ポイント", 0.55, 1.05, 5.1, 0.42, 14, true, CYAN);
  [
    "●  IF（命令フェッチ）と EX（実行）の2ステージ",
    "●  パイプラインレジスタで段間を分割し\n   クリティカルパスを短縮",
    "●  周期：14 ns → 71.4 MHz（逐次比 +43%）",
    "●  ハザード対策：データハザード時にストール",
    "●  CPI：1.1514（ストールにより若干増加）",
    "●  実行時間：1.914 ms（逐次比 1.24× 高速）",
  ].forEach((t,i) => txt(sl, t, 0.55, 1.57+i*0.52, 5.15, 0.48, 12, false, WHITE));

  card(sl, 6.05, 0.97, 3.7, 4.2, ACCENT);
  txt(sl, "パイプライン構造", 6.2, 1.05, 3.4, 0.4, 13, true, CYAN);
  [["Stage 1：IF", BLUE], ["Stage 2：EX/MEM/WB", GREEN]].forEach(([s,c],i) => {
    rect(sl, 6.15, 1.6+i*1.55, 3.5, 1.15, c);
    txt(sl, s, 6.15, 1.6+i*1.55+0.38, 3.5, 0.42, 12, true, DARK, "C");
    if (i===0) txt(sl, "↓", 7.55, 1.6+i*1.55+1.15, 0.7, 0.35, 16, true, WHITE, "C");
  });

  // ===================================================
  // スライド 8: 5段パイプライン
  // ===================================================
  sl = newSlide(prs);
  header(sl, "高速化設計の詳細 ③ 5段パイプラインCPU", "04 / 5-Stage Pipeline");
  pnum(sl, 8);

  card(sl, 0.3, 0.97, 5.55, 4.2);
  txt(sl, "設計ポイント", 0.55, 1.05, 5.1, 0.42, 14, true, CYAN);
  [
    "●  IF → ID → EX → MEM → WB の5ステージ構成",
    "●  各ステージ間にパイプラインレジスタを配置",
    "●  周期：12 ns → 83.3 MHz（逐次比 +67%）",
    "●  フォワーディングによるデータハザード軽減",
    "●  CPI：1.3934（ストール・フラッシュで増加）",
    "●  LUT使用率：3.65%（メモリ構成を大幅最適化）",
  ].forEach((t,i) => txt(sl, t, 0.55, 1.57+i*0.5, 5.15, 0.46, 12, false, WHITE));

  card(sl, 6.05, 0.97, 3.7, 4.2, ACCENT);
  txt(sl, "5段パイプライン構造", 6.2, 1.05, 3.4, 0.4, 12, true, CYAN);
  ["IF  命令フェッチ","ID  命令デコード","EX  演算実行","MEM メモリアクセス","WB  ライトバック"]
    .forEach((s,i) => {
      rect(sl, 6.15, 1.6+i*0.68, 3.5, 0.55, BLUE);
      txt(sl, s, 6.15, 1.6+i*0.68+0.08, 3.5, 0.4, 11, true, DARK, "C");
      if (i<4) txt(sl, "↓", 7.55, 1.6+i*0.68+0.55, 0.7, 0.25, 11, false, WHITE, "C");
    });

  // ===================================================
  // スライド 9: 評価結果（実行時間・CPI）
  // ===================================================
  sl = newSlide(prs);
  header(sl, "評価結果：実行時間・CPI・動作周波数", "05 / Performance Results");
  pnum(sl, 9);

  const hd9 = ["実装","命令数","動作周波数","実行クロック数","CPI","実行時間","高速化率"];
  const cx9 = [0.1, 1.7, 3.1, 4.6, 6.5, 7.5, 8.75];
  const cw9 = [1.55, 1.35, 1.45, 1.85, 0.95, 1.2, 1.05];
  rect(sl, 0.1, 0.97, 9.8, 0.42, BLUE);
  hd9.forEach((h,j) => txt(sl, h, cx9[j], 0.99, cw9[j], 0.38, 10, true, DARK, "C"));

  [
    ["クイック 逐次",   "118,777","50 MHz",  "118,778","1.000","2.376 ms","基準"],
    ["クイック 2段PL",  "118,777","71.4 MHz","136,760","1.151","1.914 ms","1.24×"],
    ["クイック 5段PL",  "118,777","83.3 MHz","165,507","1.393","1.986 ms","1.20×"],
  ].forEach((row,i) => {
    rect(sl, 0.1, 1.39+i*1.05, 9.8, 0.95, i%2===0?MID:ACCENT);
    row.forEach((v,j) => {
      const fc = j===6 ? [LGRAY,GREEN,CYAN][i] : WHITE;
      txt(sl, v, cx9[j], 1.39+i*1.05+0.25, cw9[j], 0.45, 11, false, fc, "C");
    });
  });
  txt(sl, "実行時間 = 実行命令数 × CPI × クロック周期",
      0.5, 4.7, 9.0, 0.38, 12, true, YELLOW, "C");
  txt(sl, "2段PL：周波数向上がCPI増加を上回り最速．5段PLはさらに高周波だがハザード増でCPI大幅増加",
      0.3, 5.1, 9.4, 0.38, 10, false, LGRAY, "L", true);

  // ===================================================
  // スライド 10: 評価結果（回路資源）
  // ===================================================
  sl = newSlide(prs);
  header(sl, "評価結果：回路資源利用状況", "05 / Resource Utilization");
  pnum(sl, 10);

  const hd10 = ["実装","Slice LUTs","（Logic）","（Memory）","Registers","LUT使用率"];
  const cx10 = [0.1, 1.85, 3.5, 5.05, 7.05, 8.6];
  const cw10 = [1.7, 1.6, 1.5, 1.95, 1.5, 1.25];
  rect(sl, 0.1, 0.97, 9.8, 0.42, BLUE);
  hd10.forEach((h,j) => txt(sl, h, cx10[j], 0.99, cw10[j], 0.38, 10, true, DARK, "C"));

  [
    ["クイック 逐次",   "18,957","2,529","16,428","64", "29.90%"],
    ["2段パイプライン", "18,888","2,460","16,428","246","29.79%"],
    ["5段パイプライン",  "2,316","1,248", "1,068","657", "3.65%"],
  ].forEach((row,i) => {
    rect(sl, 0.1, 1.39+i*1.2, 9.8, 1.1, i%2===0?MID:ACCENT);
    row.forEach((v,j) => {
      const fc = (i===2 && (j===1||j===5)) ? YELLOW : WHITE;
      txt(sl, v, cx10[j], 1.39+i*1.2+0.3, cw10[j], 0.5, 11, false, fc, "C");
    });
  });
  txt(sl, "5段パイプラインはメモリ構成を最適化 → LUT使用率が 29.90% から 3.65% へ激減（約1/8）",
      0.3, 5.0, 9.4, 0.42, 13, true, GREEN);

  // ===================================================
  // スライド 11: 評価結果（消費電力・エネルギ）
  // ===================================================
  sl = newSlide(prs);
  header(sl, "評価結果：消費電力・消費エネルギ", "05 / Power & Energy");
  pnum(sl, 11);

  // 左: 電力表
  card(sl, 0.15, 0.97, 4.8, 4.3);
  txt(sl, "消費電力 (W)", 0.35, 1.05, 4.3, 0.4, 13, true, CYAN);
  const pwX = [0.2, 1.65, 2.85, 3.95];
  const pwW = [1.4, 1.18, 1.07, 1.05];
  rect(sl, 0.2, 1.5, 4.7, 0.4, BLUE);
  ["実装","総電力","動的電力","静的電力"].forEach((h,j) =>
    txt(sl, h, pwX[j], 1.52, pwW[j], 0.36, 10, true, DARK));
  [
    ["クイック逐次",    "0.384 W","0.278 W","0.105 W"],
    ["2段パイプライン", "0.470 W","0.364 W","0.105 W"],
    ["5段パイプライン", "0.225 W","0.120 W","0.105 W"],
  ].forEach((row,i) => {
    rect(sl, 0.2, 1.9+i*0.78, 4.7, 0.72, i%2===0?ACCENT:MID);
    row.forEach((v,j) => {
      const fc = (i===2&&j>0) ? YELLOW : WHITE;
      txt(sl, v, pwX[j], 1.92+i*0.78, pwW[j], 0.65, 11, false, fc);
    });
  });

  // 右: 消費エネルギ棒グラフ
  card(sl, 5.15, 0.97, 4.7, 4.3, ACCENT);
  txt(sl, "消費エネルギ = 電力 × 実行時間", 5.3, 1.05, 4.4, 0.4, 12, true, CYAN);
  const enData = [["クイック逐次",0.384,2.376],["2段PL",0.470,1.914],["5段PL",0.225,1.986]];
  const maxE = Math.max(...enData.map(([,p,t])=>p*t));
  enData.forEach(([name,p,t],i) => {
    const e = p*t;
    const bw = 2.8*(e/maxE);
    txt(sl, name, 5.3, 1.65+i*1.05, 4.3, 0.3, 11, false, LGRAY);
    rect(sl, 5.3, 1.95+i*1.05, bw, 0.52, i===2?GREEN:BLUE);
    txt(sl, e.toFixed(3)+" mJ", 5.3+bw+0.08, 1.95+i*1.05, 1.8, 0.5,
        12, true, i===2?GREEN:WHITE);
  });
  txt(sl, "5段PLは消費電力・エネルギ両面で最も優秀",
      5.3, 5.0, 4.4, 0.38, 12, true, GREEN);

  // ===================================================
  // スライド 12: 考察
  // ===================================================
  sl = newSlide(prs);
  header(sl, "考察", "06 / Discussion");
  pnum(sl, 12);

  [
    ["実行時間の改善",
     "2段PL：周波数向上（+43%）がCPI増加（+15%）を上回り実行時間を約20%短縮（1.24×）．\n5段PL：さらに高周波（+67%）だがCPIが大幅増加（+39%）し改善幅は約20%（1.20×）にとどまった．"],
    ["消費電力・エネルギの改善",
     "5段PLはメモリ構成の最適化によりLUT使用率が約1/8に削減．動的電力を0.278→0.120 Wに大幅圧縮．\n消費エネルギは逐次比で約51%削減（0.912 mJ → 0.447 mJ）と大きな効果が得られた．"],
    ["トレードオフの整理",
     "パイプライン段数増加：① 動作周波数の向上  vs  ② CPIの増加  のトレードオフが存在．\n5段PLはメモリ削減効果が支配的で，電力・エネルギ面では最良結果を示した．"],
  ].forEach(([title,body],i) => {
    card(sl, 0.3, 0.97+i*1.48, 9.4, 1.35);
    rect(sl, 0.3, 0.97+i*1.48, 0.1, 1.35, BLUE);
    txt(sl, title, 0.55, 1.02+i*1.48, 8.8, 0.38, 13, true, CYAN);
    txt(sl, body,  0.55, 1.42+i*1.48, 8.8, 0.85, 11, false, WHITE);
  });

  // ===================================================
  // スライド 13: まとめ
  // ===================================================
  sl = newSlide(prs);
  header(sl, "まとめ", "06 / Summary");
  pnum(sl, 13);

  [
    "✓  クイックソートは選択ソートに比べ実行命令数が約29倍少なくアルゴリズムに採用",
    "✓  2段パイプライン：実行時間を約20%短縮（2.376 ms → 1.914 ms，1.24×高速化）",
    "✓  5段パイプライン：消費エネルギを約51%削減（0.912 mJ → 0.447 mJ）",
    "✓  5段パイプラインはLUT使用率を 29.90% → 3.65% に大幅削減（約1/8）",
    "✓  パイプライン化は周波数向上とCPI増加のトレードオフを伴う",
  ].forEach((t,i) => {
    rect(sl, 0.3, 0.97+i*0.82, 9.4, 0.72, i%2===0?MID:ACCENT);
    txt(sl, t, 0.55, 0.97+i*0.82+0.12, 9.0, 0.5, 13, false, WHITE);
  });
  txt(sl, "→ 目的・用途に応じてアルゴリズムとアーキテクチャを選択することが重要",
      0.5, 5.15, 9.0, 0.38, 13, true, YELLOW, "C");

  // ===================================================
  // スライド 14: 感想・役割分担・エフォート
  // ===================================================
  sl = newSlide(prs);
  header(sl, "感想・役割分担・エフォート", "07 / Impressions & Contributions");
  pnum(sl, 14);

  const mX = [0.2, 1.8, 4.65, 8.1];
  const mW = [1.55, 2.8, 3.4, 1.75];
  rect(sl, 0.2, 0.97, 9.6, 0.42, BLUE);
  ["メンバー","担当内容","感想","エフォート"].forEach((h,j) =>
    txt(sl, h, mX[j], 0.99, mW[j], 0.38, 11, true, DARK));
  [
    ["メンバー A","逐次CPUの設計・検証\nクイックソート実装","パイプライン設計の基礎を理解できた","25%"],
    ["メンバー B","2段パイプライン設計\nハザード制御実装","ストールの実装が最も難しかった","25%"],
    ["メンバー C","5段パイプライン設計\nフォワーディング実装","電力削減の効果が大きく達成感があった","25%"],
    ["メンバー D","評価・測定\nスライド・レポート作成","数値で結果を確認でき理解が深まった","25%"],
  ].forEach((row,i) => {
    rect(sl, 0.2, 1.39+i*0.95, 9.6, 0.88, i%2===0?MID:ACCENT);
    row.forEach((v,j) => txt(sl, v, mX[j], 1.41+i*0.95, mW[j], 0.82, 11, false, WHITE));
  });
  txt(sl, "※ 各メンバーの氏名・感想・エフォートは実際の内容に書き換えてください",
      0.3, 5.28, 9.4, 0.28, 9, false, LGRAY, "L", true);

  // ===================================================
  // 完了ログ
  // ===================================================
  const url = prs.getUrl();
  console.log("完了！スライドのURL: " + url);
  Logger.log("完了！スライドのURL: " + url);
}
