//+------------------------------------------------------------------+
//|                                               IDC_Assistant.mq4  |
//|     SL/Trailing 전용 MT4 화면 패널 EA (TP 없음) — SPEC 1:1 구현   |
//|     Spec: docs/IDC_Assistant_SPEC.txt                            |
//+------------------------------------------------------------------+
#property copyright "IDC_Assistant"
#property link      ""
#property version   "1.00"
#property strict

//====================================================================
// 1) INPUT PARAMETERS — SPEC §2
//====================================================================
input string InpSepPanel         = "=== Panel UI ==="; // -
input int    InpPanelX           = 20;                 // 패널 X
input int    InpPanelY           = 30;                 // 패널 Y
input int    InpPanelWidth       = 280;                // 패널 가로(px)
input int    InpPanelHeight      = 360;                // 패널 세로(px)
input color  InpColorBg          = C'24,28,36';         // 배경색
input color  InpColorBorder      = C'70,80,95';         // 테두리색
input color  InpColorText        = C'230,235,240';     // 텍스트색
input color  InpColorEditBg      = C'40,46,58';         // 입력칸 배경
input color  InpColorBuy         = C'30,140,90';        // BUY 버튼
input color  InpColorSell        = C'180,55,55';        // SELL 버튼
input color  InpColorClose       = C'160,110,30';       // 일괄청산 버튼
input color  InpColorAccent      = C'80,140,200';       // 강조/AUTO 버튼
input int    InpFontSize         = 10;                 // 글자 크기

input string InpSepTrade         = "=== Trade Defaults (Points) ==="; // -
input int    InpSLPoints         = 200;                // SL(포인트)
input int    InpTrailingStartPts = 200;                // 트레일 시작(포인트)
input int    InpTrailingStepPts  = 10;                 // 트레일 스텝(포인트)
input double InpLots             = 0.10;               // 수동 랏
input bool   InpLotModeAuto      = false;              // true=자동랏 / false=수동
input double InpRiskPercent      = 1.0;                // 자동랏 위험%(잔고)
input int    InpMagicNumber      = 90001;              // 매직넘버
input int    InpSlippagePts      = 30;                 // 슬리피지(포인트)
input string InpTradeComment     = "IDC_A";            // 주문 코멘트 접두

input string InpSepSymbol        = "=== Symbol / Time ==="; // -
input bool   InpAutoDetectSymbol = true;               // 브로커 심볼 스펙 자동감지
input string InpManualSymbol     = "";                 // 수동 심볼(비우면 차트)

input string InpSepGuard         = "=== SL Guardian ==="; // -
input bool   InpSLGuardianOn     = true;               // SL 가디언 ON/OFF
input int    InpSLGuardianRetryMs = 250;               // Modify 실패 재시도(ms)

//====================================================================
// 2) GLOBAL RUNTIME STATE
//====================================================================
string   g_TradeSymbol        = "";
bool     g_SymbolReady        = false;
int      g_DetectedPeriod     = 0;
int      g_BrokerGmtOffsetMin = 0;

// 패널 런타임 값 (§11-3) — Edit에서 갱신
int      g_SLPoints           = 200;
int      g_TrailStartPts      = 200;
int      g_TrailStepPts       = 10;
double   g_Lots               = 0.10;
bool     g_LotModeAuto        = false;

string   g_StatusLine         = "INIT";
string   g_GuardStatus        = "IDLE";
string   g_LastAction         = "-";
string   g_ModeTag            = "MANUAL";

#define PANEL_PREFIX   "IDC_A_PNL_"
#define OBJ_BG         PANEL_PREFIX "BG"
#define OBJ_TITLE      PANEL_PREFIX "TITLE"
#define OBJ_INFO       PANEL_PREFIX "INFO"
#define OBJ_LBL_SL     PANEL_PREFIX "LBL_SL"
#define OBJ_EDT_SL     PANEL_PREFIX "EDT_SL"
#define OBJ_LBL_TS     PANEL_PREFIX "LBL_TS"
#define OBJ_EDT_TS     PANEL_PREFIX "EDT_TS"
#define OBJ_LBL_STEP   PANEL_PREFIX "LBL_STEP" // Trailing Step 라벨 (TP 아님)
#define OBJ_EDT_STEP   PANEL_PREFIX "EDT_STEP"
#define OBJ_LBL_LOT    PANEL_PREFIX "LBL_LOT"
#define OBJ_EDT_LOT    PANEL_PREFIX "EDT_LOT"
#define OBJ_BTN_AUTO   PANEL_PREFIX "BTN_AUTO"
#define OBJ_BTN_BUY    PANEL_PREFIX "BTN_BUY"
#define OBJ_BTN_SELL   PANEL_PREFIX "BTN_SELL"
#define OBJ_BTN_CLOSE  PANEL_PREFIX "BTN_CLOSE"
#define OBJ_STATUS     PANEL_PREFIX "STATUS"
#define OBJ_GUARD      PANEL_PREFIX "GUARD"

#define CLOSE_MAX_PASSES 8

//====================================================================
// 3) FORWARD DECLARATIONS
//====================================================================
bool   ResolveTradeSymbol();
bool   AutoDetectSymbolSpec();
bool   TrySymbolVariant(const string base, string &outSymbol);
void   DetectTimeframeAndBrokerTime();
void   InitRuntimeFromInputs();
void   SyncPanelEditsToRuntime();
void   SyncRuntimeToPanelEdits();
double NormalizeLots(double lots);
double CalcAutoLots();
double GetTradeLots();
bool   IsOurOrder();
int    CountOurOrders(const int typeFilter);
bool   FindBaseOrder(const int type, int &outTicket, double &outOpenPrice, datetime &outOpenTime);
int    ClassifyAddMode(const int type, const double entryPrice);
// returns: 0=BASE(first/equal), 1=DCA(물타기), 2=PYRAMID(불타기)
double ResolveBasePriceForTicket(const int ticket);
double CalcInitialSLPrice(const int type, const double basePrice);
void   ManageTrailingStops();
void   SLGuardianTick();
bool   EnsureInitialSL(const int ticket);
bool   ModifySLSafe(const int ticket, const double newSL);
bool   ExecuteMarketEntry(const int type);
int    CloseAllOurOrdersFast();
double GetPointSize();
double PointsToPrice(const int pts);
int    PriceToPoints(const double priceDiff);
double BidP();
double AskP();
int    DigitsSym();
double NormalizeP(const double price);
void   CreatePanel();
void   DestroyPanel();
void   UpdatePanelStatus();
void   SetRect(const string name, const int x, const int y, const int w, const int h,
               const color bg, const color border);
void   SetLabel(const string name, const int x, const int y, const string text,
                const color clr, const int fontSz);
void   SetEdit(const string name, const int x, const int y, const int w, const int h,
               const string text);
void   SetButton(const string name, const int x, const int y, const int w, const int h,
                 const string text, const color bg);

//====================================================================
// 4) INIT / DEINIT / TICK / EVENTS
//====================================================================
int OnInit()
{
   InitRuntimeFromInputs();

   if(!ResolveTradeSymbol())
   {
      Print("IDC_A|INIT|symbol resolve failed");
      g_StatusLine = "SYMBOL FAIL";
   }
   else
   {
      g_SymbolReady = true;
      if(InpAutoDetectSymbol)
         AutoDetectSymbolSpec();
      DetectTimeframeAndBrokerTime();
      Print("IDC_A|INIT|symbol=", g_TradeSymbol,
            " digits=", DigitsSym(),
            " point=", DoubleToStr(GetPointSize(), DigitsSym()),
            " TF=", g_DetectedPeriod,
            " GMT_min=", g_BrokerGmtOffsetMin);
   }

   CreatePanel();
   SyncRuntimeToPanelEdits();
   UpdatePanelStatus();
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, false);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DestroyPanel();
}

void OnTick()
{
   if(!g_SymbolReady)
   {
      if(ResolveTradeSymbol())
      {
         g_SymbolReady = true;
         if(InpAutoDetectSymbol)
            AutoDetectSymbolSpec();
      }
   }

   DetectTimeframeAndBrokerTime();

   // 패널 Edit → 런타임 동기화 (매 틱 경량)
   SyncPanelEditsToRuntime();

   if(g_SymbolReady)
   {
      if(InpSLGuardianOn)
         SLGuardianTick();
      ManageTrailingStops();
   }

   UpdatePanelStatus();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   // 클릭 후 버튼 눌림 상태 해제
   if(ObjectFind(0, sparam) >= 0)
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

   SyncPanelEditsToRuntime();

   if(sparam == OBJ_BTN_BUY)
   {
      bool ok = ExecuteMarketEntry(OP_BUY);
      g_LastAction = ok ? "BUY OK" : "BUY FAIL";
   }
   else if(sparam == OBJ_BTN_SELL)
   {
      bool ok = ExecuteMarketEntry(OP_SELL);
      g_LastAction = ok ? "SELL OK" : "SELL FAIL";
   }
   else if(sparam == OBJ_BTN_CLOSE)
   {
      int n = CloseAllOurOrdersFast();
      g_LastAction = "CLOSE " + IntegerToString(n);
   }
   else if(sparam == OBJ_BTN_AUTO)
   {
      g_LotModeAuto = !g_LotModeAuto;
      g_ModeTag = g_LotModeAuto ? "AUTO" : "MANUAL";
      ObjectSetString(0, OBJ_BTN_AUTO, OBJPROP_TEXT, g_LotModeAuto ? "AUTO" : "MANUAL");
      if(g_LotModeAuto)
      {
         double al = CalcAutoLots();
         g_Lots = al;
         ObjectSetString(0, OBJ_EDT_LOT, OBJPROP_TEXT, DoubleToStr(al, 2));
      }
      g_LastAction = "LOT " + g_ModeTag;
   }

   UpdatePanelStatus();
   ChartRedraw(0);
}

//====================================================================
// 5) SYMBOL / TIME — SPEC §1-4, §1-5
//====================================================================
void InitRuntimeFromInputs()
{
   g_SLPoints      = InpSLPoints;
   g_TrailStartPts = InpTrailingStartPts;
   g_TrailStepPts  = InpTrailingStepPts;
   g_Lots          = InpLots;
   g_LotModeAuto   = InpLotModeAuto;
   g_ModeTag       = g_LotModeAuto ? "AUTO" : "MANUAL";
}

bool ResolveTradeSymbol()
{
   string manual = InpManualSymbol;
   StringTrimLeft(manual);
   StringTrimRight(manual);

   if(StringLen(manual) > 0)
   {
      if(SymbolSelect(manual, true) && MarketInfo(manual, MODE_BID) > 0.0)
      {
         g_TradeSymbol = manual;
         return(true);
      }
      Print("IDC_A|SYMBOL|manual not tradable: ", manual);
   }

   string chartSym = Symbol();
   if(SymbolSelect(chartSym, true) && MarketInfo(chartSym, MODE_BID) > 0.0)
   {
      g_TradeSymbol = chartSym;
      return(true);
   }

   // 접미사 변형 스캔 (브로커 심볼 자동감지)
   string found = "";
   if(TrySymbolVariant(chartSym, found))
   {
      g_TradeSymbol = found;
      return(true);
   }

   g_TradeSymbol = "";
   return(false);
}

bool TrySymbolVariant(const string base, string &outSymbol)
{
   outSymbol = "";
   string roots[6];
   roots[0] = base;
   // 접미사 제거 시도
   string stripped = base;
   int len = StringLen(stripped);
   if(len > 6)
   {
      // 흔한 접미사 길이 1~3 제거 후보
      roots[1] = StringSubstr(base, 0, len - 1);
      roots[2] = StringSubstr(base, 0, len - 2);
      roots[3] = StringSubstr(base, 0, len - 3);
   }
   else
   {
      roots[1] = base;
      roots[2] = base;
      roots[3] = base;
   }
   roots[4] = base;
   roots[5] = base;

   string suffixes[12];
   suffixes[0]  = "";
   suffixes[1]  = ".";
   suffixes[2]  = "m";
   suffixes[3]  = ".m";
   suffixes[4]  = "pro";
   suffixes[5]  = ".pro";
   suffixes[6]  = "i";
   suffixes[7]  = "#";
   suffixes[8]  = ".a";
   suffixes[9]  = "c";
   suffixes[10] = "micro";
   suffixes[11] = ".raw";

   int total = SymbolsTotal(false);
   for(int r = 0; r < 4; r++)
   {
      if(roots[r] == "") continue;
      for(int s = 0; s < 12; s++)
      {
         string cand = roots[r] + suffixes[s];
         if(!SymbolSelect(cand, true)) continue;
         if(MarketInfo(cand, MODE_BID) <= 0.0) continue;
         outSymbol = cand;
         return(true);
      }
   }

   // 전체 심볼 중 base 포함 검색
   string baseUp = base;
   StringToUpper(baseUp);
   for(int i = 0; i < total; i++)
   {
      string nm = SymbolName(i, false);
      if(nm == "") continue;
      string up = nm;
      StringToUpper(up);
      if(StringFind(up, baseUp) < 0) continue;
      if(!SymbolSelect(nm, true)) continue;
      if(MarketInfo(nm, MODE_BID) <= 0.0) continue;
      outSymbol = nm;
      return(true);
   }
   return(false);
}

bool AutoDetectSymbolSpec()
{
   if(g_TradeSymbol == "")
      return(false);

   double point  = MarketInfo(g_TradeSymbol, MODE_POINT);
   int    digits = (int)MarketInfo(g_TradeSymbol, MODE_DIGITS);
   double stopL  = MarketInfo(g_TradeSymbol, MODE_STOPLEVEL);
   double freeze = MarketInfo(g_TradeSymbol, MODE_FREEZELEVEL);
   double minLot = MarketInfo(g_TradeSymbol, MODE_MINLOT);
   double maxLot = MarketInfo(g_TradeSymbol, MODE_MAXLOT);
   double lotStep= MarketInfo(g_TradeSymbol, MODE_LOTSTEP);
   double tickSz = MarketInfo(g_TradeSymbol, MODE_TICKSIZE);
   double tickVal= MarketInfo(g_TradeSymbol, MODE_TICKVALUE);
   int    trade  = (int)MarketInfo(g_TradeSymbol, MODE_TRADEALLOWED);

   Print("IDC_A|SPEC|", g_TradeSymbol,
         " dig=", digits,
         " pt=", DoubleToStr(point, digits),
         " stop=", stopL,
         " freeze=", freeze,
         " lot=", DoubleToStr(minLot, 2), "-", DoubleToStr(maxLot, 2),
         "/", DoubleToStr(lotStep, 2),
         " tickSz=", DoubleToStr(tickSz, digits),
         " tickVal=", DoubleToStr(tickVal, 4),
         " trade=", trade);

   if(point <= 0.0 || digits < 0)
      return(false);
   return(true);
}

void DetectTimeframeAndBrokerTime()
{
   g_DetectedPeriod = Period();
   datetime server = TimeCurrent();
   datetime gmt    = TimeGMT();
   g_BrokerGmtOffsetMin = (int)((server - gmt) / 60);
}

//====================================================================
// 6) LOTS — SPEC §4-3
//====================================================================
double NormalizeLots(double lots)
{
   double minLot  = MarketInfo(g_TradeSymbol, MODE_MINLOT);
   double maxLot  = MarketInfo(g_TradeSymbol, MODE_MAXLOT);
   double lotStep = MarketInfo(g_TradeSymbol, MODE_LOTSTEP);
   if(lotStep <= 0.0) lotStep = 0.01;
   if(minLot  <= 0.0) minLot  = lotStep;
   if(maxLot  <= 0.0) maxLot  = 100.0;

   lots = MathFloor(lots / lotStep + 1e-8) * lotStep;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   int lotDigits = 2;
   if(lotStep < 0.01 - 1e-12) lotDigits = 3;
   if(lotStep >= 0.1 - 1e-12) lotDigits = 1;
   if(lotStep >= 1.0 - 1e-12) lotDigits = 0;
   return(NormalizeDouble(lots, lotDigits));
}

double CalcAutoLots()
{
   // lots = (Balance * Risk%/100) / money_per_lot_for_SL
   // money_per_lot = (SL_points * Point / TickSize) * TickValue
   if(g_SLPoints <= 0)
      return(NormalizeLots(g_Lots));

   double balance  = AccountBalance();
   double riskMoney = balance * InpRiskPercent / 100.0;
   if(riskMoney <= 0.0)
      return(NormalizeLots(MarketInfo(g_TradeSymbol, MODE_MINLOT)));

   double point   = GetPointSize();
   double tickSz  = MarketInfo(g_TradeSymbol, MODE_TICKSIZE);
   double tickVal = MarketInfo(g_TradeSymbol, MODE_TICKVALUE);
   if(point <= 0.0 || tickSz <= 0.0 || tickVal <= 0.0)
      return(NormalizeLots(g_Lots));

   double slPrice     = (double)g_SLPoints * point;
   double moneyPerLot = (slPrice / tickSz) * tickVal;
   if(moneyPerLot <= 0.0)
      return(NormalizeLots(g_Lots));

   double lots = riskMoney / moneyPerLot;
   return(NormalizeLots(lots));
}

double GetTradeLots()
{
   if(g_LotModeAuto)
      return(CalcAutoLots());
   return(NormalizeLots(g_Lots));
}

//====================================================================
// 7) ORDER HELPERS / DCA·PYRAMID 분류 — SPEC §6, §7, §8
//====================================================================
bool IsOurOrder()
{
   if(OrderMagicNumber() != InpMagicNumber) return(false);
   if(OrderSymbol() != g_TradeSymbol) return(false);
   int t = OrderType();
   if(t != OP_BUY && t != OP_SELL) return(false);
   return(true);
}

int CountOurOrders(const int typeFilter)
{
   // typeFilter: -1=all, OP_BUY, OP_SELL
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;
      if(typeFilter >= 0 && OrderType() != typeFilter) continue;
      n++;
   }
   return(n);
}

bool FindBaseOrder(const int type, int &outTicket, double &outOpenPrice, datetime &outOpenTime)
{
   // 최초 = OpenTime 최소 (동률 시 티켓 최소)
   outTicket = -1;
   outOpenPrice = 0.0;
   outOpenTime = 0;
   bool found = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;
      if(OrderType() != type) continue;

      datetime ot = OrderOpenTime();
      int tk = OrderTicket();
      if(!found || ot < outOpenTime || (ot == outOpenTime && tk < outTicket))
      {
         found = true;
         outTicket = tk;
         outOpenPrice = OrderOpenPrice();
         outOpenTime = ot;
      }
   }
   return(found);
}

int ClassifyAddMode(const int type, const double entryPrice)
{
   // 기존 포지션 없으면 BASE(0)
   int baseTk;
   double basePx;
   datetime baseTm;
   if(!FindBaseOrder(type, baseTk, basePx, baseTm))
      return(0); // BASE — 신규 최초

   double point = GetPointSize();
   double eps = point * 0.5;

   if(type == OP_BUY)
   {
      if(entryPrice < basePx - eps) return(1); // DCA 물타기
      if(entryPrice > basePx + eps) return(2); // PYRAMID 불타기
      return(0);
   }
   else // OP_SELL
   {
      if(entryPrice > basePx + eps) return(1); // DCA 물타기
      if(entryPrice < basePx - eps) return(2); // PYRAMID 불타기
      return(0);
   }
}

double ResolveBasePriceForTicket(const int ticket)
{
   // §6: 물타기·최초 → 최초 OpenPrice
   // §7: 불타기 → 자기 OpenPrice
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return(0.0);

   int type = OrderType();
   double ownOpen = OrderOpenPrice();

   int baseTk;
   double basePx;
   datetime baseTm;
   if(!FindBaseOrder(type, baseTk, basePx, baseTm))
      return(ownOpen);

   if(ticket == baseTk)
      return(basePx);

   int mode = ClassifyAddMode(type, ownOpen);
   if(mode == 1) // DCA → 공통 최초가
      return(basePx);
   // mode 2 PYRAMID or 0 equal → 자기 진입가
   return(ownOpen);
}

double CalcInitialSLPrice(const int type, const double basePrice)
{
   if(g_SLPoints <= 0)
      return(0.0);

   if(type == OP_BUY)
      return(NormalizeP(basePrice - PointsToPrice(g_SLPoints)));
   if(type == OP_SELL)
      return(NormalizeP(basePrice + PointsToPrice(g_SLPoints)));
   return(0.0);
}

//====================================================================
// 8) ENTRY — SPEC §4
//====================================================================
bool ExecuteMarketEntry(const int type)
{
   if(!g_SymbolReady || g_TradeSymbol == "")
   {
      Print("IDC_A|ENTRY|symbol not ready");
      return(false);
   }
   if(type != OP_BUY && type != OP_SELL)
      return(false);

   RefreshRates();
   double lots = GetTradeLots();
   if(lots <= 0.0)
   {
      Print("IDC_A|ENTRY|invalid lots");
      return(false);
   }

   double price = (type == OP_BUY) ? AskP() : BidP();
   if(price <= 0.0)
   {
      Print("IDC_A|ENTRY|no price");
      return(false);
   }

   // 분류: 기존 포지션 대비 물타기/불타기 → SL 기준가 결정
   int mode = ClassifyAddMode(type, price);
   double baseForSL = price;
   if(mode == 1) // DCA: 최초가 기준 동일 SL
   {
      int btk; double bpx; datetime btm;
      if(FindBaseOrder(type, btk, bpx, btm))
         baseForSL = bpx;
   }
   // mode 0 BASE / mode 2 PYRAMID → 자기 진입가(체결 후 open으로 가디언이 보정)

   double sl = CalcInitialSLPrice(type, baseForSL);
   double tp = 0.0; // §1-3 TP 없음

   string modeTag = "BASE";
   if(mode == 1) modeTag = "DCA";
   else if(mode == 2) modeTag = "PYR";

   string cmt = InpTradeComment + "|" + modeTag;
   color  clr = (type == OP_BUY) ? InpColorBuy : InpColorSell;

   int slip = InpSlippagePts;
   ResetLastError();
   int ticket = OrderSend(g_TradeSymbol, type, lots, price, slip, sl, tp, cmt, InpMagicNumber, 0, clr);
   if(ticket < 0)
   {
      int err = GetLastError();
      Print("IDC_A|ENTRY|OrderSend fail err=", err, " type=", type, " lots=", lots, " price=", price, " sl=", sl);
      // SL 거절 시 SL=0으로 재시도 후 가디언 주입
      ResetLastError();
      ticket = OrderSend(g_TradeSymbol, type, lots, price, slip, 0.0, 0.0, cmt, InpMagicNumber, 0, clr);
      if(ticket < 0)
      {
         Print("IDC_A|ENTRY|OrderSend retry fail err=", GetLastError());
         return(false);
      }
      EnsureInitialSL(ticket);
   }
   else
   {
      // DCA면 신규 체결 직후 SL을 공통 절대가로 재정렬
      if(mode == 1)
         EnsureInitialSL(ticket);
   }

   g_StatusLine = modeTag + " #" + IntegerToString(ticket);
   Print("IDC_A|ENTRY|ok ticket=", ticket, " mode=", modeTag, " lots=", lots, " sl=", sl);
   return(true);
}

//====================================================================
// 9) TRAILING — SPEC §5 (+ §6/§7 BasePrice)
//====================================================================
void ManageTrailingStops()
{
   double point = GetPointSize();
   if(point <= 0.0) return;
   if(g_TrailStartPts <= 0) return;
   if(g_TrailStepPts <= 0) return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;

      int ticket = OrderTicket();
      int type   = OrderType();
      double curSL = OrderStopLoss();

      double basePrice = ResolveBasePriceForTicket(ticket);
      if(basePrice <= 0.0) continue;

      // §5-1 profitPts from BasePrice (포인트 반올림 — float 오차 방지)
      double profitPts = 0.0;
      if(type == OP_BUY)
         profitPts = (double)PriceToPoints(BidP() - basePrice);
      else
         profitPts = (double)PriceToPoints(basePrice - AskP());

      // §5-2
      if(profitPts < (double)g_TrailStartPts)
         continue;

      // §5-3 / §5-4 Floor steps
      int steps = (int)MathFloor((profitPts - (double)g_TrailStartPts) / (double)g_TrailStepPts);
      if(steps < 0) steps = 0;

      double newSL = 0.0;
      if(type == OP_BUY)
      {
         newSL = basePrice
                 + PointsToPrice(g_TrailStartPts)
                 + PointsToPrice(steps * g_TrailStepPts);
      }
      else
      {
         newSL = basePrice
                 - PointsToPrice(g_TrailStartPts)
                 - PointsToPrice(steps * g_TrailStepPts);
      }
      newSL = NormalizeP(newSL);

      // §5-5 유리 방향만
      bool improve = false;
      if(type == OP_BUY)
         improve = (curSL == 0.0 || newSL > curSL + point * 0.5);
      else
         improve = (curSL == 0.0 || newSL < curSL - point * 0.5);

      if(!improve) continue;

      ModifySLSafe(ticket, newSL);
   }
}

//====================================================================
// 10) SL GUARDIAN — SPEC §9
//====================================================================
void SLGuardianTick()
{
   int missing = 0;
   int fixed   = 0;

   // SLPoints<=0 이면 사용자 SL 비활성 — 누락 주입 생략
   if(g_SLPoints > 0)
   {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;

      int ticket = OrderTicket();
      if(OrderStopLoss() == 0.0)
      {
         missing++;
         if(EnsureInitialSL(ticket))
            fixed++;
      }
   }
   }

   // DCA 그룹: SL이 있어도 최초가 기준과 어긋난 초기SL을 동일가로 재정렬
   // (트레일 가동 전에는 공통 초기SL 절대가 유지)
   if(g_SLPoints > 0)
   {
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;

      int ticket = OrderTicket();
      int type   = OrderType();
      double ownOpen = OrderOpenPrice();
      double curSL = OrderStopLoss();
      if(curSL == 0.0) continue;

      int mode = ClassifyAddMode(type, ownOpen);
      // 최초 자신(mode 판별용 자기가격=base) 또는 DCA만 대상
      int baseTk; double basePx; datetime baseTm;
      if(!FindBaseOrder(type, baseTk, basePx, baseTm)) continue;

      bool inDcaGroup = (ticket == baseTk) || (mode == 1);
      if(!inDcaGroup) continue;

      // 트레일 가동 여부: 기준가 대비 수익이 Start 미만이면 초기SL로 정렬
      double point = GetPointSize();
      if(point <= 0.0) continue;
      double profitPts = (type == OP_BUY) ? (double)PriceToPoints(BidP() - basePx)
                                          : (double)PriceToPoints(basePx - AskP());
      if(profitPts >= (double)g_TrailStartPts)
         continue; // 트레일 구간은 ManageTrailingStops가 동일가 처리

      double wantSL = CalcInitialSLPrice(type, basePx);
      if(wantSL <= 0.0) continue;
      if(MathAbs(curSL - wantSL) > point * 0.5)
         ModifySLSafe(ticket, wantSL);
   }
   }

   if(g_SLPoints <= 0)
      g_GuardStatus = "SL OFF";
   else if(missing > 0)
      g_GuardStatus = "FIX " + IntegerToString(fixed) + "/" + IntegerToString(missing);
   else
      g_GuardStatus = "OK";
}

bool EnsureInitialSL(const int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return(false);

   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL)
      return(false);

   // §6/§7: BasePrice 규칙으로 초기 SL
   double basePrice = ResolveBasePriceForTicket(ticket);
   double newSL = CalcInitialSLPrice(type, basePrice);
   if(newSL <= 0.0)
      return(false);

   // 이미 동일하면 OK
   double curSL = OrderStopLoss();
   double point = GetPointSize();
   if(curSL != 0.0 && MathAbs(curSL - newSL) <= point * 0.5)
      return(true);

   return(ModifySLSafe(ticket, newSL));
}

bool ModifySLSafe(const int ticket, const double newSL)
{
   // §9-4: 실패 티켓만 재시도 간격
   static int  s_lastFailTicket = -1;
   static uint s_lastFailMs     = 0;
   uint now = GetTickCount();
   if(s_lastFailTicket == ticket && s_lastFailMs != 0 &&
      (now - s_lastFailMs) < (uint)InpSLGuardianRetryMs)
      return(false);

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return(false);

   double openPrice = OrderOpenPrice();
   double tp        = 0.0; // §5-6 / §1-3 TP 항상 0
   int    type      = OrderType();
   double point     = GetPointSize();
   double curSL     = OrderStopLoss();
   bool   initialFill = (curSL == 0.0);

   // §9-2 STOPLEVEL / FREEZELEVEL
   double stopLvl = MarketInfo(g_TradeSymbol, MODE_STOPLEVEL) * point;
   double freeze  = MarketInfo(g_TradeSymbol, MODE_FREEZELEVEL) * point;
   double minDist = MathMax(stopLvl, freeze);

   double sl = NormalizeP(newSL);
   RefreshRates(); // §9-3

   if(type == OP_BUY)
   {
      double maxSL = BidP() - minDist;
      if(minDist > 0.0 && sl > maxSL)
         sl = NormalizeP(maxSL);
      if(sl <= 0.0) return(false);
      // §9-5 불리 후퇴 금지 (초기 주입 제외)
      if(!initialFill && sl <= curSL)
         return(false);
   }
   else if(type == OP_SELL)
   {
      double minSL = AskP() + minDist;
      if(minDist > 0.0 && sl < minSL)
         sl = NormalizeP(minSL);
      if(sl <= 0.0) return(false);
      if(!initialFill && sl >= curSL)
         return(false);
   }
   else
      return(false);

   // DCA 동일가 강제 시 기존 SL과 같아도 스킵(불필요 modify)
   if(!initialFill && MathAbs(sl - curSL) <= point * 0.1)
      return(true);

   ResetLastError();
   bool ok = OrderModify(ticket, openPrice, sl, tp, 0, clrYellow);
   if(!ok)
   {
      int err = GetLastError();
      Print("IDC_A|SL|OrderModify fail ticket=", ticket, " err=", err, " sl=", sl);
      g_GuardStatus = "ERR " + IntegerToString(err);
      s_lastFailTicket = ticket;
      s_lastFailMs = now;
      return(false);
   }
   s_lastFailTicket = -1;
   s_lastFailMs = 0;
   return(true);
}

//====================================================================
// 11) CLOSE ALL FAST — SPEC §10
//====================================================================
int CloseAllOurOrdersFast()
{
   int closed = 0;
   for(int pass = 0; pass < CLOSE_MAX_PASSES; pass++)
   {
      int remain = 0;
      // 역순 청산
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(!IsOurOrder()) continue;

         int ticket = OrderTicket();
         int type   = OrderType();
         double lots = OrderLots();
         RefreshRates();
         double price = (type == OP_BUY) ? BidP() : AskP();
         ResetLastError();
         bool ok = OrderClose(ticket, lots, price, InpSlippagePts, clrOrange);
         if(ok)
            closed++;
         else
         {
            remain++;
            Print("IDC_A|CLOSE|fail ticket=", ticket, " err=", GetLastError(), " pass=", pass);
         }
      }
      if(remain == 0)
         break;
   }
   return(closed);
}

//====================================================================
// 12) PRICE UTILS — 포인트 통일 SPEC §1-2
//====================================================================
double GetPointSize()
{
   double p = MarketInfo(g_TradeSymbol, MODE_POINT);
   if(p <= 0.0) p = Point;
   return(p);
}

double PointsToPrice(const int pts)
{
   return((double)pts * GetPointSize());
}

int PriceToPoints(const double priceDiff)
{
   double p = GetPointSize();
   if(p <= 0.0) return(0);
   return((int)MathRound(priceDiff / p));
}

double BidP()
{
   RefreshRates();
   double b = MarketInfo(g_TradeSymbol, MODE_BID);
   if(b <= 0.0) b = Bid;
   return(b);
}

double AskP()
{
   RefreshRates();
   double a = MarketInfo(g_TradeSymbol, MODE_ASK);
   if(a <= 0.0) a = Ask;
   return(a);
}

int DigitsSym()
{
   int d = (int)MarketInfo(g_TradeSymbol, MODE_DIGITS);
   if(d < 0) d = Digits;
   return(d);
}

double NormalizeP(const double price)
{
   return(NormalizeDouble(price, DigitsSym()));
}

//====================================================================
// 13) PANEL UI — SPEC §3, §2 크기/컬러
//====================================================================
void SetRect(const string name, const int x, const int y, const int w, const int h,
             const color bg, const color border)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SetLabel(const string name, const int x, const int y, const string text,
              const color clr, const int fontSz)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSz);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SetEdit(const string name, const int x, const int y, const int w, const int h,
             const string text)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorText);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, InpColorEditBg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, InpColorBorder);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SetButton(const string name, const int x, const int y, const int w, const int h,
               const string text, const color bg)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize + 1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, InpColorBorder);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreatePanel()
{
   int x = InpPanelX;
   int y = InpPanelY;
   int w = InpPanelWidth;
   int h = InpPanelHeight;
   if(w < 220) w = 220;
   if(h < 300) h = 300;

   int pad = 10;
   int rowH = 24;
   int editW = w - pad * 2 - 100;
   int btnW = (w - pad * 3) / 2;
   int fs = InpFontSize;

   SetRect(OBJ_BG, x, y, w, h, InpColorBg, InpColorBorder);

   int cy = y + pad;
   SetLabel(OBJ_TITLE, x + pad, cy, "IDC_Assistant", InpColorAccent, fs + 3);
   cy += rowH + 2;
   SetLabel(OBJ_INFO, x + pad, cy, "SYM - | GMT -", InpColorText, fs);
   cy += rowH + 4;

   // SL
   SetLabel(OBJ_LBL_SL, x + pad, cy + 4, "SL (pts)", InpColorText, fs);
   SetEdit(OBJ_EDT_SL, x + pad + 100, cy, editW, rowH, IntegerToString(g_SLPoints));
   cy += rowH + 6;

   // Trailing Start
   SetLabel(OBJ_LBL_TS, x + pad, cy + 4, "Trail Start", InpColorText, fs);
   SetEdit(OBJ_EDT_TS, x + pad + 100, cy, editW, rowH, IntegerToString(g_TrailStartPts));
   cy += rowH + 6;

   // Trailing Step
   SetLabel(OBJ_LBL_STEP, x + pad, cy + 4, "Trail Step", InpColorText, fs);
   SetEdit(OBJ_EDT_STEP, x + pad + 100, cy, editW, rowH, IntegerToString(g_TrailStepPts));
   cy += rowH + 6;

   // Lots + AUTO toggle
   SetLabel(OBJ_LBL_LOT, x + pad, cy + 4, "Lots", InpColorText, fs);
   int lotEditW = editW - 70;
   if(lotEditW < 50) lotEditW = 50;
   SetEdit(OBJ_EDT_LOT, x + pad + 100, cy, lotEditW, rowH, DoubleToStr(g_Lots, 2));
   SetButton(OBJ_BTN_AUTO, x + pad + 100 + lotEditW + 4, cy, 66, rowH,
             g_LotModeAuto ? "AUTO" : "MANUAL", InpColorAccent);
   cy += rowH + 12;

   // BUY / SELL
   SetButton(OBJ_BTN_BUY,  x + pad, cy, btnW, 32, "BUY", InpColorBuy);
   SetButton(OBJ_BTN_SELL, x + pad * 2 + btnW, cy, btnW, 32, "SELL", InpColorSell);
   cy += 40;

   // CLOSE ALL
   SetButton(OBJ_BTN_CLOSE, x + pad, cy, w - pad * 2, 32, "CLOSE ALL", InpColorClose);
   cy += 40;

   SetLabel(OBJ_STATUS, x + pad, cy, "Status: -", InpColorText, fs);
   cy += rowH;
   SetLabel(OBJ_GUARD, x + pad, cy, "Guard: -", InpColorText, fs);
}

void DestroyPanel()
{
   ObjectsDeleteAll(0, PANEL_PREFIX);
}

void SyncPanelEditsToRuntime()
{
   string s;

   s = ObjectGetString(0, OBJ_EDT_SL, OBJPROP_TEXT);
   if(s != "")
   {
      int v = (int)StringToInteger(s);
      if(v >= 0) g_SLPoints = v;
   }

   s = ObjectGetString(0, OBJ_EDT_TS, OBJPROP_TEXT);
   if(s != "")
   {
      int v = (int)StringToInteger(s);
      if(v >= 0) g_TrailStartPts = v;
   }

   s = ObjectGetString(0, OBJ_EDT_STEP, OBJPROP_TEXT);
   if(s != "")
   {
      int v = (int)StringToInteger(s);
      if(v > 0) g_TrailStepPts = v;
   }

   s = ObjectGetString(0, OBJ_EDT_LOT, OBJPROP_TEXT);
   if(s != "" && !g_LotModeAuto)
   {
      double v = StringToDouble(s);
      if(v > 0.0) g_Lots = v;
   }
}

void SyncRuntimeToPanelEdits()
{
   ObjectSetString(0, OBJ_EDT_SL, OBJPROP_TEXT, IntegerToString(g_SLPoints));
   ObjectSetString(0, OBJ_EDT_TS, OBJPROP_TEXT, IntegerToString(g_TrailStartPts));
   ObjectSetString(0, OBJ_EDT_STEP, OBJPROP_TEXT, IntegerToString(g_TrailStepPts));
   ObjectSetString(0, OBJ_EDT_LOT, OBJPROP_TEXT, DoubleToStr(g_Lots, 2));
   ObjectSetString(0, OBJ_BTN_AUTO, OBJPROP_TEXT, g_LotModeAuto ? "AUTO" : "MANUAL");
}

void UpdatePanelStatus()
{
   string sym = (g_TradeSymbol == "") ? "-" : g_TradeSymbol;
   string info = sym
                 + " | TF:" + IntegerToString(g_DetectedPeriod)
                 + " | GMT:" + IntegerToString(g_BrokerGmtOffsetMin)
                 + "m";
   ObjectSetString(0, OBJ_INFO, OBJPROP_TEXT, info);

   int buys = CountOurOrders(OP_BUY);
   int sells = CountOurOrders(OP_SELL);
   string st = "Pos B" + IntegerToString(buys) + "/S" + IntegerToString(sells)
               + " | " + g_ModeTag
               + " | " + g_LastAction
               + " | " + g_StatusLine;
   ObjectSetString(0, OBJ_STATUS, OBJPROP_TEXT, st);

   string gd = "Guard: " + g_GuardStatus
               + (InpSLGuardianOn ? " [ON]" : " [OFF]")
               + " | SL=" + IntegerToString(g_SLPoints)
               + " TS=" + IntegerToString(g_TrailStartPts)
               + "/" + IntegerToString(g_TrailStepPts);
   ObjectSetString(0, OBJ_GUARD, OBJPROP_TEXT, gd);

   // AUTO 모드면 랏 표시 갱신
   if(g_LotModeAuto)
   {
      double al = CalcAutoLots();
      ObjectSetString(0, OBJ_EDT_LOT, OBJPROP_TEXT, DoubleToStr(al, 2));
   }
}

//+------------------------------------------------------------------+
