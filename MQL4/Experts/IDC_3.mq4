//+------------------------------------------------------------------+
//| IDC_3.mq4                                                         |
//| GOLD M1 Inside Bar System — Spec lock: docs/IDC_3_전략서.md v1.03  |
//+------------------------------------------------------------------+
#property copyright "IDC_3"
#property link      ""
#property version   "1.03"
#property strict
#property description "IDC_3 — GOLD M1 Inside Bar. Close breakout of bar#2. No TP. SL+Trailing."

enum ENUM_IDC3_LINE_STYLE
  {
   IDC3_LS_SOLID      = STYLE_SOLID,      // Solid
   IDC3_LS_DASH       = STYLE_DASH,       // Dash
   IDC3_LS_DOT        = STYLE_DOT,        // Dot
   IDC3_LS_DASHDOT    = STYLE_DASHDOT,    // Dash-Dot
   IDC3_LS_DASHDOTDOT = STYLE_DASHDOTDOT  // Dash-Dot-Dot
  };

//==================== INPUTS ====================
input string InpSecSym                 = "=== Symbol / Broker ==="; // 
input bool   InpAutoDetectGold         = true;                      // Auto-detect gold symbol
input string InpManualSymbol           = "";                        // Manual symbol (blank=auto/chart)

input string InpSecRisk                = "=== SL / Trailing (points) ==="; // 
input int    InpStopLossPoints         = 500;                       // Initial SL (points, mandatory)
input int    InpTrailingStartPts       = 200;                       // 수익 Start 도달 → SL을 진입가(본전)로
input int    InpTrailingStepPts        = 10;                        // 본전 이후 가격 추종 스텝 (points)

input string InpSecLot                 = "=== Lot ===";             // 
input bool   InpUseAutoLot             = false;                     // Auto lot ON/OFF
input double InpFixedLot               = 0.01;                      // Fixed lot
input double InpRiskPercent            = 1.0;                       // Auto lot risk % of balance
input double InpMaxLot                 = 5.0;                       // Max lot cap

input string InpSecGuard               = "=== SL Guardian ===";     // 
input bool   InpUseSLGuardian          = true;                      // SL Guardian master switch
input int    InpMaxSpreadPts           = 80;                        // Max spread to allow entry (points)
input int    InpSpreadBufferPts        = 15;                        // Spread buffer (points)
input int    InpSLPadPts               = 5;                         // SL pad over StopLevel (points)

input string InpSecSession             = "=== Session / Daily Loss ==="; // 
input bool   InpUseTimeFilter          = false;                     // Use session filter
input int    InpStartHourGMT           = 0;                         // Session start hour GMT
input int    InpStartMinuteGMT         = 0;                         // Session start minute GMT
input int    InpEndHourGMT             = 23;                        // Session end hour GMT
input int    InpEndMinuteGMT           = 59;                        // Session end minute GMT
input bool   InpCloseOutsideHrs        = false;                     // Close position outside session
input double InpDailyLossPercent       = 5.0;                       // Daily loss % of day-start equity
input bool   InpStopOnDailyLoss        = true;                      // Block new entries on daily loss
input bool   InpCloseOnDailyLoss       = false;                     // Close position on daily loss

input string InpSecLines               = "=== Setup Lines (#1 / #2) ==="; // 
input bool   InpDrawSetupLines         = true;                      // Draw setup H/L lines
input color  InpLine1Color             = clrDodgerBlue;             // #1 (mother) line color
input ENUM_IDC3_LINE_STYLE InpLine1Style = IDC3_LS_DASH;           // #1 line style
input color  InpLine2Color             = clrRed;                    // #2 (inside) line color
input ENUM_IDC3_LINE_STYLE InpLine2Style = IDC3_LS_DASH;           // #2 line style
input int    InpLineWidth              = 1;                         // Line width (1-5)

input string InpSecSys                 = "=== System ===";          // 
input int    InpMagic                  = 300301;                    // Magic number
input int    InpSlippagePts            = 30;                        // OrderSend slippage (points)
input string InpTradeComment           = "IDC_3";                   // Order comment
input bool   InpShowPanel              = true;                      // Show Comment panel
input bool   InpDebugLog               = false;                     // Experts tab debug log

//==================== RUNTIME ====================
string   g_symbol;
double   g_point;              // unified 1-point price
int      g_digits;
int      g_gmt_offset_sec;
datetime g_day_stamp;
double   g_day_start_equity;
bool     g_daily_loss_hit;
datetime g_last_m1_bar;
datetime g_last_eval_bar1;     // shift-1 bar time already evaluated
bool     g_trail_armed;
string   g_last_signal;        // NONE / BUY / SELL / CANCEL
string   g_last_block;         // human reason

#define OBJ_PFX "IDC3_"

bool IsBodyLargerThanWicks(const double o, const double h, const double l, const double c);
bool IsCloseBreakBuy (const double c3, const double h2);
bool IsCloseBreakSell(const double c3, const double l2);

//+------------------------------------------------------------------+
int OnInit()
{
   if(Period() != PERIOD_M1)
   {
      Alert("IDC_3: M1 only. Current TF=", Period());
      return INIT_FAILED;
   }

   g_symbol = ResolveSymbol();
   if(g_symbol == "" || !IsGoldSymbol(g_symbol))
   {
      Alert("IDC_3: gold symbol not resolved. Attach to XAUUSD/GOLD or set InpManualSymbol.");
      return INIT_FAILED;
   }
   if(!SymbolSelect(g_symbol, true))
   {
      Alert("IDC_3: SymbolSelect failed: ", g_symbol);
      return INIT_FAILED;
   }

   if(InpStopLossPoints < 1)
   {
      Alert("IDC_3: InpStopLossPoints must be >= 1");
      return INIT_FAILED;
   }
   if(InpTrailingStartPts < 1 || InpTrailingStepPts < 1)
   {
      Alert("IDC_3: TrailingStart/TrailingStep must be >= 1");
      return INIT_FAILED;
   }
   if(InpLineWidth < 1 || InpLineWidth > 5)
   {
      Alert("IDC_3: InpLineWidth must be 1..5");
      return INIT_FAILED;
   }
   if(InpFixedLot <= 0.0 || InpMaxLot <= 0.0)
   {
      Alert("IDC_3: lot inputs must be > 0");
      return INIT_FAILED;
   }
   if(InpUseAutoLot && InpRiskPercent <= 0.0)
   {
      Alert("IDC_3: InpRiskPercent must be > 0 when auto lot ON");
      return INIT_FAILED;
   }

   g_digits = (int)MarketInfo(g_symbol, MODE_DIGITS);
   g_point  = NormalizedPoint(g_symbol);
   RefreshGmtOffset();

   g_day_stamp = 0;
   g_day_start_equity = AccountEquity();
   g_daily_loss_hit = false;
   g_last_m1_bar = 0;
   g_last_eval_bar1 = 0;
   g_trail_armed = false;
   g_last_signal = "NONE";
   g_last_block = "init";

   // restart: if already in position, mark trail state fresh
   if(CountOurPositions() > 0)
      g_trail_armed = false;

   Print("IDC_3 v1.03 init | ", g_symbol,
         " point=", DoubleToStr(g_point, g_digits),
         " gmt_off_sec=", g_gmt_offset_sec,
         " SL=", InpStopLossPoints,
         " Trail=", InpTrailingStartPts, "/", InpTrailingStepPts);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   DeleteSetupObjects();
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsConnected() || !IsTradeAllowed())
      return;
   if(Period() != PERIOD_M1)
      return;

   RefreshRates();
   RefreshGmtOffsetHourly();
   UpdateDayState();

   //--- IN POSITION: manage only, no new entries (R05)
   if(CountOurPositions() > 0)
   {
      if(InpUseSLGuardian)
         GuardOpenPositionSL();
      ManageTrailing();

      if(g_daily_loss_hit && InpCloseOnDailyLoss)
         CloseOurPosition();

      if(!IsWithinTradingHours() && InpCloseOutsideHrs)
         CloseOurPosition();

      DrawPanel();
      return;
   }

   g_trail_armed = false;

   //--- FLAT: new-bar evaluation only
   datetime bar0 = iTime(g_symbol, PERIOD_M1, 0);
   if(bar0 <= 0)
   {
      DrawPanel();
      return;
   }
   if(bar0 == g_last_m1_bar)
   {
      DrawPanel();
      return;
   }
   g_last_m1_bar = bar0;

   // evaluate just-closed bars: #3=shift1, #2=shift2, #1=shift3
   EvaluateInsideBarSetup();
   DrawPanel();
}

//+------------------------------------------------------------------+
//| Core strategy — docs/IDC_3_전략서.md §2                            |
//+------------------------------------------------------------------+
void EvaluateInsideBarSetup()
{
   datetime t1 = iTime(g_symbol, PERIOD_M1, 1);
   if(t1 <= 0)
   {
      g_last_block = "no bar1";
      return;
   }
   if(t1 == g_last_eval_bar1)
   {
      g_last_block = "already eval";
      return;
   }
   g_last_eval_bar1 = t1;

   if(!IsWithinTradingHours())
   {
      g_last_signal = "NONE";
      g_last_block = "session closed";
      return;
   }
   if(g_daily_loss_hit && InpStopOnDailyLoss)
   {
      g_last_signal = "NONE";
      g_last_block = "daily loss hit";
      return;
   }
   if(CountOurPositions() > 0)
   {
      g_last_signal = "NONE";
      g_last_block = "in position";
      return;
   }
   if(InpUseSLGuardian && SpreadPoints() > InpMaxSpreadPts)
   {
      g_last_signal = "NONE";
      g_last_block = "spread wide";
      return;
   }

   // Need mother(#1)=shift3, inside(#2)=shift2, trigger(#3)=shift1
   if(iBars(g_symbol, PERIOD_M1) < 4)
   {
      g_last_block = "not enough bars";
      return;
   }

   double h1 = iHigh(g_symbol, PERIOD_M1, 3);
   double l1 = iLow (g_symbol, PERIOD_M1, 3);
   double h2 = iHigh(g_symbol, PERIOD_M1, 2);
   double l2 = iLow (g_symbol, PERIOD_M1, 2);
   double o3 = iOpen (g_symbol, PERIOD_M1, 1);
   double c3 = iClose(g_symbol, PERIOD_M1, 1);
   double h3 = iHigh (g_symbol, PERIOD_M1, 1);
   double l3 = iLow  (g_symbol, PERIOD_M1, 1);

   // Sanity: invalid OHLC → no trade
   if(h1 <= 0.0 || l1 <= 0.0 || h2 <= 0.0 || l2 <= 0.0 ||
      h3 <= 0.0 || l3 <= 0.0 || o3 <= 0.0 || c3 <= 0.0 ||
      h1 < l1 || h2 < l2 || h3 < l3)
   {
      g_last_signal = "NONE";
      g_last_block = "invalid OHLC";
      return;
   }

   // R01: #2 completely inside #1 AND smaller. Candle colors IGNORED.
   bool is_inside = (h2 < h1 && l2 > l1);
   if(!is_inside)
   {
      g_last_signal = "NONE";
      g_last_block = "no inside bar";
      if(InpDrawSetupLines)
         DeleteSetupObjects();
      return;
   }

   // Visual: #1 / #2 levels (span #1..#3 only)
   if(InpDrawSetupLines)
      DrawSetupHL(h1, l1, h2, l2, iTime(g_symbol, PERIOD_M1, 3), iTime(g_symbol, PERIOD_M1, 2), t1);

   // R03/R04: 종가 돌파만 인정. 심지(고저)만 돌파하고 종가 미돌파 = 무효.
   // 절대 High/Low로 진입 방향 결정하지 않음.
   bool wick_only_buy  = (h3 > h2 && c3 <= h2);
   bool wick_only_sell = (l3 < l2 && c3 >= l2);
   bool buy_break      = IsCloseBreakBuy (c3, h2);
   bool sell_break     = IsCloseBreakSell(c3, l2);

   if(wick_only_buy || wick_only_sell)
   {
      g_last_signal = "CANCEL";
      g_last_block = wick_only_buy ? "wick-only BUY (no close break)" : "wick-only SELL (no close break)";
      Print("IDC_3: CANCEL wick-only. C3=", DoubleToStr(c3, g_digits),
            " H3=", DoubleToStr(h3, g_digits), " L3=", DoubleToStr(l3, g_digits),
            " H2=", DoubleToStr(h2, g_digits), " L2=", DoubleToStr(l2, g_digits));
      return;
   }

   if(!buy_break && !sell_break)
   {
      g_last_signal = "CANCEL";
      g_last_block = "bar3 no CLOSE break of #2";
      Print("IDC_3: CANCEL no close break. C3=", DoubleToStr(c3, g_digits),
            " H2=", DoubleToStr(h2, g_digits), " L2=", DoubleToStr(l2, g_digits));
      return;
   }

   if(buy_break && sell_break)
   {
      g_last_signal = "CANCEL";
      g_last_block = "dual break impossible";
      return;
   }

   // R03c: 돌파 마감봉 #3 — 몸통이 위·아래 심지(합)보다 무조건 커야 함
   // body > upper + lower  (등호 불허). 각 심지보다도 커야 함.
   if(!IsBodyLargerThanWicks(o3, h3, l3, c3))
   {
      double body = MathAbs(c3 - o3);
      double up_w = h3 - MathMax(o3, c3);
      double dn_w = MathMin(o3, c3) - l3;
      if(up_w < 0.0) up_w = 0.0;
      if(dn_w < 0.0) dn_w = 0.0;
      g_last_signal = "CANCEL";
      g_last_block = "bar3 body<=wicks";
      Print("IDC_3: CANCEL #3 body filter. body=", DoubleToStr(body, g_digits),
            " upW=", DoubleToStr(up_w, g_digits),
            " dnW=", DoubleToStr(dn_w, g_digits),
            " sumW=", DoubleToStr(up_w + dn_w, g_digits),
            " O=", DoubleToStr(o3, g_digits), " C=", DoubleToStr(c3, g_digits));
      return;
   }

   int dir = buy_break ? OP_BUY : OP_SELL;
   g_last_signal = buy_break ? "BUY" : "SELL";
   g_last_block = "entry";

   Print("IDC_3: SIGNAL ", g_last_signal,
         " | #2 H/L=", DoubleToStr(h2, g_digits), "/", DoubleToStr(l2, g_digits),
         " | #3 O=", DoubleToStr(o3, g_digits),
         " H=", DoubleToStr(h3, g_digits),
         " L=", DoubleToStr(l3, g_digits),
         " C=", DoubleToStr(c3, g_digits),
         " | CLOSE break OK + body>wicks OK");

   // 진입 직전 재검증 (OpenMarket 내부에서도 재확인)
   if(!OpenMarket(dir, h2, l2, o3, h3, l3, c3))
      return;
}

//+------------------------------------------------------------------+
//| 종가 돌파만 — High/Low(심지) 돌파는 진입 근거가 아님                 |
//+------------------------------------------------------------------+
bool IsCloseBreakBuy(const double c3, const double h2)
{
   // 종가가 #2 High를 반드시 위로 돌파. High(심지)는 진입조건 아님.
   return (c3 > h2);
}

bool IsCloseBreakSell(const double c3, const double l2)
{
   return (c3 < l2);
}

//+------------------------------------------------------------------+
//| #3 돌파봉: body > (upper+lower) AND body > upper AND body > lower  |
//| "몸통이 위아래 심지보다 무조건 커야" = 심지 합보다 커야 함(엄격)      |
//+------------------------------------------------------------------+
bool IsBodyLargerThanWicks(const double o, const double h, const double l, const double c)
{
   double body = MathAbs(c - o);
   double upper = h - MathMax(o, c);
   double lower = MathMin(o, c) - l;
   if(upper < 0.0) upper = 0.0;
   if(lower < 0.0) lower = 0.0;
   // 합보다 큼 + 각 심지보다 큼 (등호 불허)
   if(body <= upper)
      return false;
   if(body <= lower)
      return false;
   if(body <= (upper + lower))
      return false;
   return true;
}

//+------------------------------------------------------------------+
bool OpenMarket(const int dir, const double h2, const double l2,
                const double o3, const double h3, const double l3, const double c3)
{
   if(CountOurPositions() > 0)
      return false;

   // 진입 직전 최종 락: 종가 돌파 + 몸통>심지 재확인 (우회 금지)
   if(dir == OP_BUY)
   {
      if(!IsCloseBreakBuy(c3, h2))
      {
         g_last_block = "OpenMarket reject: no CLOSE buy break";
         Print("IDC_3: OpenMarket BLOCKED buy — C3=", DoubleToStr(c3, g_digits),
               " H2=", DoubleToStr(h2, g_digits));
         return false;
      }
   }
   else if(dir == OP_SELL)
   {
      if(!IsCloseBreakSell(c3, l2))
      {
         g_last_block = "OpenMarket reject: no CLOSE sell break";
         Print("IDC_3: OpenMarket BLOCKED sell — C3=", DoubleToStr(c3, g_digits),
               " L2=", DoubleToStr(l2, g_digits));
         return false;
      }
   }
   else
      return false;

   if(!IsBodyLargerThanWicks(o3, h3, l3, c3))
   {
      g_last_block = "OpenMarket reject: body filter";
      Print("IDC_3: OpenMarket BLOCKED body filter");
      return false;
   }

   int sl_pts = EffectiveSLPts();
   double lots = CalcLot(sl_pts);
   int slip = SlippageRaw();

   double ask = MarketInfo(g_symbol, MODE_ASK);
   double bid = MarketInfo(g_symbol, MODE_BID);
   if(ask <= 0.0 || bid <= 0.0)
   {
      g_last_block = "no quotes";
      return false;
   }

   double entry, sl;
   color  clr;
   if(dir == OP_BUY)
   {
      entry = ask;
      sl = NormalizeDouble(entry - PtsPrice(sl_pts), g_digits);
      clr = clrDodgerBlue;
   }
   else
   {
      entry = bid;
      sl = NormalizeDouble(entry + PtsPrice(sl_pts), g_digits);
      clr = clrOrangeRed;
   }

   if(InpUseSLGuardian)
   {
      int min_pts = BrokerMinDistancePts() + InpSLPadPts;
      double min_d = PtsPrice(min_pts);
      if(dir == OP_BUY)
      {
         double floor_sl = NormalizeDouble(bid - min_d, g_digits);
         if(sl > floor_sl) sl = floor_sl;
      }
      else
      {
         double ceil_sl = NormalizeDouble(ask + min_d, g_digits);
         if(sl < ceil_sl) sl = ceil_sl;
      }
   }

   // TP always 0 — strategy has no take-profit
   ResetLastError();
   int ticket = OrderSend(g_symbol, dir, lots, entry, slip, sl, 0,
                          InpTradeComment, InpMagic, 0, clr);
   if(ticket < 0)
   {
      int err = GetLastError();
      g_last_block = "OrderSend fail " + IntegerToString(err);
      Print("IDC_3: OrderSend fail dir=", dir, " err=", err,
            " entry=", entry, " sl=", sl, " lot=", lots,
            " H2=", h2, " L2=", l2);
      return false;
   }

   g_trail_armed = false;
   Print("IDC_3: OPEN ", (dir == OP_BUY ? "BUY" : "SELL"),
         " #", ticket, " @", entry, " SL=", sl, " TP=0 lot=", lots,
         " | C3=", DoubleToStr(c3, g_digits),
         " break H2=", DoubleToStr(h2, g_digits),
         " L2=", DoubleToStr(l2, g_digits));
   return true;
}

//+------------------------------------------------------------------+
//| Trailing — 원본전략: Start 도달 시 SL→진입가(본전), 이후 Step 추종   |
//| BUY: profit>=Start → SL=Open(BE); 추가수익 Step마다 SL += Step     |
//| lock_from_BE = floor((profit-Start)/Step)*Step  (Start 시 0=본전)  |
//+------------------------------------------------------------------+
void ManageTrailing()
{
   int ticket = FindPositionTicket();
   if(ticket < 0) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return;

   int type = OrderType();
   double open_price = OrderOpenPrice();
   double cur_sl = OrderStopLoss();
   double bid = MarketInfo(g_symbol, MODE_BID);
   double ask = MarketInfo(g_symbol, MODE_ASK);

   double profit_pts = 0.0;
   if(type == OP_BUY)       profit_pts = (bid - open_price) / g_point;
   else if(type == OP_SELL) profit_pts = (open_price - ask) / g_point;
   else return;

   if(profit_pts < InpTrailingStartPts)
      return;

   // 원본: Start 도달 → 본전(진입가). 이후 Step 단위로 추종.
   double extra = profit_pts - InpTrailingStartPts;
   int steps = (int)MathFloor(extra / InpTrailingStepPts + 1e-8);
   if(steps < 0) steps = 0;
   int lock_from_be = steps * InpTrailingStepPts; // 0 = 진입가 본전

   double desired_sl;
   if(type == OP_BUY)
      desired_sl = NormalizeDouble(open_price + PtsPrice(lock_from_be), g_digits);
   else
      desired_sl = NormalizeDouble(open_price - PtsPrice(lock_from_be), g_digits);

   if(InpUseSLGuardian)
   {
      int min_pts = BrokerMinDistancePts() + InpSLPadPts;
      double min_d = PtsPrice(min_pts);
      if(type == OP_BUY)
      {
         double max_sl = NormalizeDouble(bid - min_d, g_digits);
         if(desired_sl > max_sl) desired_sl = max_sl;
      }
      else
      {
         double min_sl = NormalizeDouble(ask + min_d, g_digits);
         if(desired_sl < min_sl) desired_sl = min_sl;
      }
   }

   bool improve = false;
   if(type == OP_BUY)
      improve = (cur_sl <= 0.0 || desired_sl > cur_sl + g_point * 0.1);
   else
      improve = (cur_sl <= 0.0 || desired_sl < cur_sl - g_point * 0.1);

   if(!improve) return;
   if(type == OP_BUY  && desired_sl >= bid) return;
   if(type == OP_SELL && desired_sl <= ask) return;

   ResetLastError();
   if(!OrderModify(ticket, open_price, desired_sl, 0, 0, clrYellow))
      Print("IDC_3: trail modify fail #", ticket, " err=", GetLastError());
   else
      g_trail_armed = true;
}

//+------------------------------------------------------------------+
void GuardOpenPositionSL()
{
   int ticket = FindPositionTicket();
   if(ticket < 0) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return;

   int type = OrderType();
   double open_price = OrderOpenPrice();
   double cur_sl = OrderStopLoss();
   double bid = MarketInfo(g_symbol, MODE_BID);
   double ask = MarketInfo(g_symbol, MODE_ASK);
   int sl_pts = EffectiveSLPts();
   double sl_dist = PtsPrice(sl_pts);

   // G04: missing SL → restore initial SL
   if(cur_sl <= 0.0)
   {
      double new_sl = (type == OP_BUY)
         ? NormalizeDouble(open_price - sl_dist, g_digits)
         : NormalizeDouble(open_price + sl_dist, g_digits);

      int min_pts = BrokerMinDistancePts() + InpSLPadPts;
      double min_d = PtsPrice(min_pts);
      if(type == OP_BUY)
      {
         double floor_sl = NormalizeDouble(bid - min_d, g_digits);
         if(new_sl > floor_sl) new_sl = floor_sl;
      }
      else
      {
         double ceil_sl = NormalizeDouble(ask + min_d, g_digits);
         if(new_sl < ceil_sl) new_sl = ceil_sl;
      }

      if(!OrderModify(ticket, open_price, new_sl, 0, 0, clrRed))
         Print("IDC_3: guardian set SL fail err=", GetLastError());
      return;
   }

   if(g_trail_armed)
      return;

   // G05: widen SL if broker stop-level requires more distance (pre-trail only)
   int cur_sl_pts = 0;
   if(type == OP_BUY)  cur_sl_pts = PricePts(open_price - cur_sl);
   if(type == OP_SELL) cur_sl_pts = PricePts(cur_sl - open_price);

   int need = BrokerMinDistancePts() + InpSLPadPts;
   if(cur_sl_pts > 0 && cur_sl_pts < need)
   {
      double new_sl = (type == OP_BUY)
         ? NormalizeDouble(open_price - PtsPrice(need), g_digits)
         : NormalizeDouble(open_price + PtsPrice(need), g_digits);
      bool widen = (type == OP_BUY && new_sl < cur_sl) || (type == OP_SELL && new_sl > cur_sl);
      if(widen)
      {
         if(!OrderModify(ticket, open_price, new_sl, 0, 0, clrRed))
            Print("IDC_3: guardian widen fail err=", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Symbol / point / time                                              |
//+------------------------------------------------------------------+
string ResolveSymbol()
{
   if(StringLen(InpManualSymbol) > 0)
      return InpManualSymbol;

   string chart_sym = Symbol();
   if(IsGoldSymbol(chart_sym))
      return chart_sym;

   if(!InpAutoDetectGold)
      return "";

   string candidates[] =
   {
      "XAUUSD","XAUUSDm","XAUUSD.a","XAUUSD.i","XAUUSD.r","XAUUSD.pro",
      "XAUUSDmicro","GOLD","GOLDm","GOLD.a","XAUUSD#","XAU/USD"
   };
   for(int i = 0; i < ArraySize(candidates); i++)
   {
      if(SymbolSelect(candidates[i], true) && MarketInfo(candidates[i], MODE_BID) > 0)
         return candidates[i];
   }

   int total = SymbolsTotal(false);
   for(int s = 0; s < total; s++)
   {
      string name = SymbolName(s, false);
      if(IsGoldSymbol(name))
      {
         if(SymbolSelect(name, true) && MarketInfo(name, MODE_BID) > 0)
            return name;
      }
   }
   return "";
}

bool IsGoldSymbol(const string sym)
{
   string u = sym;
   StringToUpper(u);
   return (StringFind(u, "XAU") >= 0 || StringFind(u, "GOLD") >= 0);
}

double NormalizedPoint(const string sym)
{
   double p = MarketInfo(sym, MODE_POINT);
   int d = (int)MarketInfo(sym, MODE_DIGITS);
   // 3/5-digit brokers: unify so 1 "point" == 10 raw points
   if(d == 3 || d == 5)
      return p * 10.0;
   return p;
}

double PtsPrice(const int pts) { return pts * g_point; }

int PricePts(const double dist)
{
   if(g_point <= 0.0) return 0;
   return (int)MathRound(MathAbs(dist) / g_point);
}

int SlippageRaw()
{
   double raw = MarketInfo(g_symbol, MODE_POINT);
   if(raw <= 0.0) return 3;
   return (int)MathMax(1, MathRound(PtsPrice(InpSlippagePts) / raw));
}

void RefreshGmtOffset()
{
   g_gmt_offset_sec = (int)(TimeCurrent() - TimeGMT());
}

void RefreshGmtOffsetHourly()
{
   static datetime last = 0;
   datetime now = TimeCurrent();
   if(last == 0 || now - last >= 3600)
   {
      RefreshGmtOffset();
      last = now;
   }
}

datetime BrokerFromGmtHMS(const int gh, const int gm)
{
   datetime gmt_now = TimeCurrent() - g_gmt_offset_sec;
   MqlDateTime dt;
   TimeToStruct(gmt_now, dt);
   dt.hour = gh;
   dt.min  = gm;
   dt.sec  = 0;
   datetime gmt_target = StructToTime(dt);
   return gmt_target + g_gmt_offset_sec;
}

bool IsWithinTradingHours()
{
   if(!InpUseTimeFilter)
      return true;
   datetime start = BrokerFromGmtHMS(InpStartHourGMT, InpStartMinuteGMT);
   datetime end   = BrokerFromGmtHMS(InpEndHourGMT, InpEndMinuteGMT);
   datetime now   = TimeCurrent();
   if(end == start)
      return true;
   if(end < start)
      return (now >= start || now < end);
   return (now >= start && now < end);
}

void UpdateDayState()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime day = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
   if(day != g_day_stamp)
   {
      g_day_stamp = day;
      g_day_start_equity = AccountEquity();
      g_daily_loss_hit = false;
   }
   if(InpDailyLossPercent <= 0.0)
      return;
   if(g_day_start_equity <= 0.0)
      return;
   double dd = (g_day_start_equity - AccountEquity()) / g_day_start_equity * 100.0;
   if(dd >= InpDailyLossPercent)
      g_daily_loss_hit = true;
}

int SpreadPoints()
{
   return PricePts(MarketInfo(g_symbol, MODE_ASK) - MarketInfo(g_symbol, MODE_BID));
}

int BrokerMinDistancePts()
{
   int stop_level = (int)MarketInfo(g_symbol, MODE_STOPLEVEL);
   int freeze     = (int)MarketInfo(g_symbol, MODE_FREEZELEVEL);
   int raw = MathMax(stop_level, freeze);
   double raw_pt = MarketInfo(g_symbol, MODE_POINT);
   if(raw_pt <= 0.0 || g_point <= 0.0)
      return raw;
   return (int)MathCeil((raw * raw_pt) / g_point);
}

int EffectiveSLPts()
{
   int sl = InpStopLossPoints;
   if(!InpUseSLGuardian)
      return sl;
   int need = BrokerMinDistancePts() + SpreadPoints() + InpSLPadPts;
   // SpreadBuffer used at entry gate / SL floor padding awareness
   need += InpSpreadBufferPts;
   if(sl < need)
      sl = need;
   return sl;
}

//+------------------------------------------------------------------+
//| Lots                                                               |
//+------------------------------------------------------------------+
double NormalizeVolume(double lots)
{
   double minlot  = MarketInfo(g_symbol, MODE_MINLOT);
   double maxlot  = MarketInfo(g_symbol, MODE_MAXLOT);
   double steplot = MarketInfo(g_symbol, MODE_LOTSTEP);
   if(steplot <= 0.0) steplot = 0.01;
   if(lots < minlot) lots = minlot;
   if(lots > maxlot) lots = maxlot;
   if(lots > InpMaxLot) lots = InpMaxLot;
   lots = MathFloor(lots / steplot + 1e-8) * steplot;
   int ld = 2;
   if(steplot < 0.01 - 1e-12) ld = 3;
   if(steplot >= 0.1 - 1e-12) ld = 1;
   return NormalizeDouble(lots, ld);
}

double CalcLot(const int sl_pts)
{
   if(!InpUseAutoLot)
      return NormalizeVolume(InpFixedLot);

   double risk_money = AccountBalance() * InpRiskPercent / 100.0;
   double tick_val  = MarketInfo(g_symbol, MODE_TICKVALUE);
   double tick_size = MarketInfo(g_symbol, MODE_TICKSIZE);
   if(tick_val <= 0.0 || tick_size <= 0.0 || sl_pts <= 0)
      return NormalizeVolume(InpFixedLot);

   double sl_price = PtsPrice(sl_pts);
   double money_per_lot = (sl_price / tick_size) * tick_val;
   if(money_per_lot <= 0.0)
      return NormalizeVolume(InpFixedLot);
   return NormalizeVolume(risk_money / money_per_lot);
}

//+------------------------------------------------------------------+
//| Orders                                                             |
//+------------------------------------------------------------------+
bool IsOurSelected()
{
   return (OrderMagicNumber() == InpMagic && OrderSymbol() == g_symbol);
}

int CountOurPositions()
{
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurSelected()) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL) c++;
   }
   return c;
}

int FindPositionTicket()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurSelected()) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         return OrderTicket();
   }
   return -1;
}

bool CloseTicket(const int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return false;
   double price = (OrderType() == OP_BUY) ? MarketInfo(g_symbol, MODE_BID)
                                          : MarketInfo(g_symbol, MODE_ASK);
   ResetLastError();
   bool ok = OrderClose(ticket, OrderLots(), price, SlippageRaw(), clrAqua);
   if(!ok)
      Print("IDC_3: close fail #", ticket, " err=", GetLastError());
   return ok;
}

bool CloseOurPosition()
{
   int ticket = FindPositionTicket();
   if(ticket < 0) return false;
   return CloseTicket(ticket);
}

//+------------------------------------------------------------------+
//| Chart lines: #1/#2 custom color+style                               |
//| 시간 범위 = 캔들#1 시각 ~ 캔들#3 시각 (RAY_LEFT=false)               |
//| → #1보다 1캔들 이전(왼쪽)에는 선이 그려지지 않음                       |
//+------------------------------------------------------------------+
void DeleteSetupObjects()
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, OBJ_PFX) == 0)
         ObjectDelete(name);
   }
}

void DrawLevelSegment(const string name, const datetime t_from, const datetime t_to,
                      const double price, const color clr, const int style, const int width)
{
   // OBJ_TREND segment — no left ray ⇒ invisible before t_from (#1)
   if(ObjectFind(name) < 0)
      ObjectCreate(name, OBJ_TREND, 0, t_from, price, t_to, price);
   else
     {
      ObjectSet(name, OBJPROP_TIME1, t_from);
      ObjectSet(name, OBJPROP_PRICE1, price);
      ObjectSet(name, OBJPROP_TIME2, t_to);
      ObjectSet(name, OBJPROP_PRICE2, price);
     }
   ObjectSet(name, OBJPROP_COLOR, clr);
   ObjectSet(name, OBJPROP_STYLE, style);
   ObjectSet(name, OBJPROP_WIDTH, width);
   ObjectSet(name, OBJPROP_RAY_RIGHT, false);
   ObjectSet(name, OBJPROP_RAY_LEFT, false);
   ObjectSet(name, OBJPROP_BACK, true);
   ObjectSet(name, OBJPROP_SELECTABLE, false);
}

void DrawSetupHL(const double h1, const double l1,
                 const double h2, const double l2,
                 const datetime t_mother, const datetime t_inside, const datetime t_trigger)
{
   // 표시 시작 = 캔들#1 시각. 그 이전(1캔들 전 포함 왼쪽)에는 미표시.
   datetime t_from = t_mother;
   datetime t_to   = t_trigger;
   if(t_to < t_from)
      t_to = t_from;

   int w = InpLineWidth;
   if(w < 1) w = 1;
   if(w > 5) w = 5;

   int st1 = (int)InpLine1Style;
   int st2 = (int)InpLine2Style;

   // #1 mother — user color/style
   DrawLevelSegment(OBJ_PFX + "H1", t_from, t_to, h1, InpLine1Color, st1, w);
   DrawLevelSegment(OBJ_PFX + "L1", t_from, t_to, l1, InpLine1Color, st1, w);
   // #2 inside — user color/style
   DrawLevelSegment(OBJ_PFX + "H2", t_from, t_to, h2, InpLine2Color, st2, w);
   DrawLevelSegment(OBJ_PFX + "L2", t_from, t_to, l2, InpLine2Color, st2, w);

   string n1 = OBJ_PFX + "LBL1";
   if(ObjectFind(n1) < 0)
      ObjectCreate(n1, OBJ_TEXT, 0, t_mother, h1);
   ObjectSetText(n1, "1", 8, "Arial", InpLine1Color);
   ObjectSet(n1, OBJPROP_TIME1, t_mother);
   ObjectSet(n1, OBJPROP_PRICE1, h1);

   string n2 = OBJ_PFX + "LBL2";
   if(ObjectFind(n2) < 0)
      ObjectCreate(n2, OBJ_TEXT, 0, t_inside, h2);
   ObjectSetText(n2, "2", 8, "Arial", InpLine2Color);
   ObjectSet(n2, OBJPROP_TIME1, t_inside);
   ObjectSet(n2, OBJPROP_PRICE1, h2);

   string n3 = OBJ_PFX + "LBL3";
   if(ObjectFind(n3) < 0)
      ObjectCreate(n3, OBJ_TEXT, 0, t_trigger, iHigh(g_symbol, PERIOD_M1, 1));
   ObjectSetText(n3, "3", 8, "Arial", clrOrange);
   ObjectSet(n3, OBJPROP_TIME1, t_trigger);
   ObjectSet(n3, OBJPROP_PRICE1, iHigh(g_symbol, PERIOD_M1, 1));
}

//+------------------------------------------------------------------+
void DrawPanel()
{
   if(!InpShowPanel)
   {
      Comment("");
      return;
   }

   string s = "";
   s += "IDC_3 v1.03 | GOLD M1 Inside Bar\n";
   s += g_symbol + " M1 | point=" + DoubleToStr(g_point, g_digits);
   s += " | spread=" + IntegerToString(SpreadPoints()) + " pts\n";
   s += "GMT offset(sec): " + IntegerToString(g_gmt_offset_sec) + "\n";
   s += "Session: " + (IsWithinTradingHours() ? "OPEN" : "CLOSED");
   s += " | DailyLoss: " + (g_daily_loss_hit ? "HIT" : "ok") + "\n";
   s += "SL: " + IntegerToString(EffectiveSLPts()) + " pts (set " + IntegerToString(InpStopLossPoints) + ")";
   s += " | Trail: BE@" + IntegerToString(InpTrailingStartPts) + " step " + IntegerToString(InpTrailingStepPts) + "\n";
   s += "TP: NONE | Pos: " + IntegerToString(CountOurPositions());
   s += " | Lot: " + (InpUseAutoLot ? "AUTO" : "FIXED") + "\n";
   s += "Guardian: " + (InpUseSLGuardian ? "ON" : "OFF");
   s += " | TrailArmed: " + (g_trail_armed ? "Y" : "N") + "\n";
   s += "LastSignal: " + g_last_signal + " | " + g_last_block + "\n";
   s += "Lines: #1/#2 custom | span #1..#3 only | #3 body>wicks\n";
   Comment(s);
}

//+------------------------------------------------------------------+
