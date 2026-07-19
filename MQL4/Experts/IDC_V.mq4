//+------------------------------------------------------------------+
//| IDC_V.mq4                                                         |
//| Spec lock: docs/IDC_V_전략서.md v1.0                               |
//+------------------------------------------------------------------+
#property copyright "IDC_V"
#property link      ""
#property version   "2.00"
#property strict
#property description "IDC_V — XAUUSD M5 BuyStop/SellStop straddle. Spec: docs/IDC_V_전략서.md v1.0"

//==================== INPUTS (전략서 §7) ====================
input string InpSecLot                 = "=== Lot ===";                 // 
input bool   InpUseAutoLot             = true;                          // Auto lot ON/OFF
input double InpRiskPercent            = 1.0;                           // Auto lot risk % of balance
input double InpFixedLot               = 0.01;                          // Fixed lot
input double InpMaxLot                 = 5.0;                           // Max lot

input string InpSecEntry               = "=== Entry / SL (points) ==="; // 
input int    InpStopLineGapPts         = 200;                           // BuyStop↔SellStop gap (points)
input int    InpSLPoints               = 150;                           // Initial SL (points)
input int    InpMinEntryGapPts         = 20;                            // Extra min gap pad (points)

input string InpSecTrail               = "=== Trailing (points) ===";   // 
input int    InpTrailStartPts          = 200;                           // Trail start from entry (points)
input int    InpTrailStepPts           = 10;                            // Trail step (points)

input string InpSecGuard               = "=== SL Guardian ===";         // 
input bool   InpUseSLGuardian          = true;                          // SL Guardian master switch
input int    InpMaxSpreadPts           = 80;                            // Max spread (points)
input int    InpSpreadBufferPts        = 15;                            // Spread/stop buffer (points)
input int    InpSLPadPts               = 5;                             // SL pad over StopLevel (points)
input bool   InpCancelOnWideSprd       = true;                          // Cancel pendings if spread wide

input string InpSecSession             = "=== Session / Daily Loss ==="; // 
input bool   InpUseTimeFilter          = true;                          // Use session filter
input int    InpStartHourGMT           = 13;                            // Session start hour GMT
input int    InpStartMinuteGMT         = 0;                             // Session start minute GMT
input int    InpEndHourGMT             = 16;                            // Session end hour GMT
input int    InpEndMinuteGMT           = 0;                             // Session end minute GMT
input bool   InpCloseOutsideHrs        = false;                         // Close position outside session
input double InpDailyLossPercent       = 5.0;                           // Daily loss % of day-start equity
input bool   InpStopOnDailyLoss        = true;                          // Block new entries on daily loss
input bool   InpCloseOnDailyLoss       = false;                         // Close position on daily loss

input string InpSecSys                 = "=== System ===";              // 
input bool   InpAutoDetectSymbol       = true;                          // Auto-detect gold symbol
input string InpForcedSymbol           = "";                            // Force symbol (blank=auto/chart)
input int    InpMagic                  = 260719;                        // Magic number
input int    InpSlippagePts            = 30;                            // Slippage (points)
input bool   InpShowPanel              = true;                          // Show Comment panel
input string InpTradeComment           = "IDC_V";                       // Order comment

//==================== RUNTIME ====================
string   g_symbol;
double   g_point;            // unified 1-point price
int      g_digits;
int      g_gmt_offset_sec;   // server - GMT (seconds)
datetime g_day_stamp;
double   g_day_start_equity;
bool     g_daily_loss_hit;
datetime g_last_place_bar;   // M5 bar when straddle was newly placed
datetime g_last_entry_bar;   // M5 bar when position filled
bool     g_trail_armed;
int      g_buy_stop_ticket;
int      g_sell_stop_ticket;

//+------------------------------------------------------------------+
int OnInit()
{
   if(Period() != PERIOD_M5)
   {
      Alert("IDC_V: M5 only. Current TF=", Period());
      return INIT_FAILED;
   }

   g_symbol = ResolveSymbol();
   if(g_symbol == "" || !IsGoldSymbol(g_symbol))
   {
      Alert("IDC_V: gold symbol not resolved. Attach to XAUUSD/GOLD or set InpForcedSymbol.");
      return INIT_FAILED;
   }
   if(!SymbolSelect(g_symbol, true))
   {
      Alert("IDC_V: SymbolSelect failed: ", g_symbol);
      return INIT_FAILED;
   }

   if(InpStopLineGapPts < 2)
   {
      Alert("IDC_V: InpStopLineGapPts must be >= 2");
      return INIT_FAILED;
   }
   if(InpSLPoints < 1 || InpTrailStartPts < 1 || InpTrailStepPts < 1)
   {
      Alert("IDC_V: SL/TrailStart/TrailStep must be >= 1");
      return INIT_FAILED;
   }

   g_digits = (int)MarketInfo(g_symbol, MODE_DIGITS);
   g_point  = NormalizedPoint(g_symbol);
   RefreshGmtOffset();

   g_day_stamp = 0;
   g_day_start_equity = AccountEquity();
   g_daily_loss_hit = false;
   g_last_place_bar = 0;
   g_last_entry_bar = 0;
   g_trail_armed = false;
   g_buy_stop_ticket = -1;
   g_sell_stop_ticket = -1;

   Print("IDC_V v2.00 init | ", g_symbol,
         " point=", DoubleToStr(g_point, g_digits),
         " gmt_off_sec=", g_gmt_offset_sec,
         " gap=", InpStopLineGapPts, " sl=", InpSLPoints);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsConnected() || !IsTradeAllowed())
      return;
   if(Period() != PERIOD_M5)
      return;

   RefreshRates();
   RefreshGmtOffsetHourly();
   UpdateDayState();
   SyncTicketsFromMarket();

   //--- IN POSITION
   if(CountOurPositions() > 0)
   {
      EnforceOCO();                 // R02
      if(InpUseSLGuardian)
         GuardOpenPositionSL();     // G04 G05
      ManageTrailing();             // §3.3

      if(g_daily_loss_hit && InpCloseOnDailyLoss)
         CloseOurPosition();

      if(!IsWithinTradingHours() && InpCloseOutsideHrs)
         CloseOurPosition();

      DrawPanel();
      return;                       // R03: no new entries
   }

   //--- FLAT
   g_trail_armed = false;

   bool in_session = IsWithinTradingHours();
   if(!in_session)
   {
      CancelAllPendings();
      DrawPanel();
      return;
   }

   if(g_daily_loss_hit && InpStopOnDailyLoss)
   {
      CancelAllPendings();
      DrawPanel();
      return;
   }

   if(InpUseSLGuardian && SpreadPoints() > InpMaxSpreadPts)
   {
      if(InpCancelOnWideSprd)
         CancelAllPendings();
      DrawPanel();
      return;
   }

   datetime bar = CurrentM5Bar();
   int pend = CountOurPendings();

   if(pend == 0)
   {
      // R01: new place only if this bar has no entry yet and no place yet
      if(bar != g_last_entry_bar && bar != g_last_place_bar)
      {
         if(PlaceStraddle())
            g_last_place_bar = bar;
      }
   }
   else
   {
      // §1.4 re-anchor same setup (not a new entry)
      ReanchorStraddle();
      EnforceOCO(); // safety if somehow a fill raced
   }

   DrawPanel();
}

//+------------------------------------------------------------------+
//| A01–A03 Symbol                                                    |
//+------------------------------------------------------------------+
string ResolveSymbol()
{
   if(StringLen(InpForcedSymbol) > 0)
      return InpForcedSymbol;

   string chart_sym = Symbol();
   if(IsGoldSymbol(chart_sym))
      return chart_sym;

   if(!InpAutoDetectSymbol)
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

//+------------------------------------------------------------------+
//| P02 Point normalize                                               |
//+------------------------------------------------------------------+
double NormalizedPoint(const string sym)
{
   double p = MarketInfo(sym, MODE_POINT);
   int d = (int)MarketInfo(sym, MODE_DIGITS);
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

//+------------------------------------------------------------------+
//| A04 GMT offset                                                    |
//+------------------------------------------------------------------+
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

datetime CurrentM5Bar()
{
   return iTime(g_symbol, PERIOD_M5, 0);
}

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Spread / stop level (unified points)                              |
//+------------------------------------------------------------------+
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

// Effective half-gap each side (points)
int EffectiveHalfGapPts()
{
   int half = InpStopLineGapPts / 2;
   if(half < 1) half = 1;

   if(!InpUseSLGuardian)
      return half;

   // G02: ensure each side clears stop+spread+buffers
   int need = BrokerMinDistancePts() + SpreadPoints() + InpSpreadBufferPts + InpMinEntryGapPts;
   if(half < need)
      half = need;
   return half;
}

int EffectiveSLPts()
{
   int sl = InpSLPoints;
   if(!InpUseSLGuardian)
      return sl;
   // G03
   int need = BrokerMinDistancePts() + SpreadPoints() + InpSLPadPts;
   if(sl < need)
      sl = need;
   return sl;
}

//+------------------------------------------------------------------+
//| Lots                                                              |
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
//| Order inventory                                                   |
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

int CountOurPendings()
{
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurSelected()) continue;
      int t = OrderType();
      if(t == OP_BUYSTOP || t == OP_SELLSTOP) c++;
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

void SyncTicketsFromMarket()
{
   g_buy_stop_ticket = -1;
   g_sell_stop_ticket = -1;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurSelected()) continue;
      if(OrderType() == OP_BUYSTOP)  g_buy_stop_ticket  = OrderTicket();
      if(OrderType() == OP_SELLSTOP) g_sell_stop_ticket = OrderTicket();
   }

   // detect new fill → stamp entry bar (R01)
   static int last_pos_count = 0;
   int now_pos = CountOurPositions();
   if(now_pos > 0 && last_pos_count == 0)
   {
      int tk = FindPositionTicket();
      if(tk >= 0 && OrderSelect(tk, SELECT_BY_TICKET))
      {
         // entry bar = M5 bar of open time
         datetime ot = OrderOpenTime();
         int shift = iBarShift(g_symbol, PERIOD_M5, ot, true);
         if(shift < 0) shift = 0;
         g_last_entry_bar = iTime(g_symbol, PERIOD_M5, shift);
         g_trail_armed = false;
      }
   }
   last_pos_count = now_pos;
}

//+------------------------------------------------------------------+
//| R02 OCO                                                           |
//+------------------------------------------------------------------+
void EnforceOCO()
{
   bool has_buy = false, has_sell = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurSelected()) continue;
      if(OrderType() == OP_BUY)  has_buy = true;
      if(OrderType() == OP_SELL) has_sell = true;
   }
   if(!has_buy && !has_sell)
      return;

   // cancel all pendings
   CancelAllPendings();

   // R04: if both buy and sell somehow open, close the newer one
   if(has_buy && has_sell)
   {
      int newer = -1;
      datetime newest = 0;
      for(int j = OrdersTotal() - 1; j >= 0; j--)
      {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
         if(!IsOurSelected()) continue;
         if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
         if(OrderOpenTime() >= newest)
         {
            newest = OrderOpenTime();
            newer = OrderTicket();
         }
      }
      if(newer >= 0)
         CloseTicket(newer);
   }
}

void CancelAllPendings()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurSelected()) continue;
      int t = OrderType();
      if(t == OP_BUYSTOP || t == OP_SELLSTOP)
      {
         if(!OrderDelete(OrderTicket()))
            Print("IDC_V: OrderDelete fail #", OrderTicket(), " err=", GetLastError());
      }
   }
   g_buy_stop_ticket = -1;
   g_sell_stop_ticket = -1;
}

//+------------------------------------------------------------------+
//| Build straddle prices                                             |
//+------------------------------------------------------------------+
bool BuildStraddlePrices(double &buy_px, double &sell_px, double &buy_sl, double &sell_sl, int &sl_pts, int &half_pts)
{
   double bid = MarketInfo(g_symbol, MODE_BID);
   double ask = MarketInfo(g_symbol, MODE_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   // 전략서 §1.2: mid 대칭, BuyStop−SellStop = 2*half (= Gap, Guardian 시 확대 가능)
   half_pts = EffectiveHalfGapPts();
   sl_pts   = EffectiveSLPts();

   double mid = (ask + bid) * 0.5;
   buy_px  = NormalizeDouble(mid + PtsPrice(half_pts), g_digits);
   sell_px = NormalizeDouble(mid - PtsPrice(half_pts), g_digits);

   // BuyStop must be > Ask, SellStop < Bid (broker-legal floor)
   {
      int lift = 1;
      if(InpUseSLGuardian)
         lift = MathMax(1, BrokerMinDistancePts() + InpSLPadPts);
      if(buy_px <= ask)
         buy_px = NormalizeDouble(ask + PtsPrice(lift), g_digits);
      if(sell_px >= bid)
         sell_px = NormalizeDouble(bid - PtsPrice(lift), g_digits);
   }

   buy_sl  = NormalizeDouble(buy_px  - PtsPrice(sl_pts), g_digits);
   sell_sl = NormalizeDouble(sell_px + PtsPrice(sl_pts), g_digits);

   if(InpUseSLGuardian)
   {
      int min_pts = BrokerMinDistancePts() + InpSLPadPts;
      double min_d = PtsPrice(min_pts);
      if(buy_px - ask < min_d) return false;
      if(bid - sell_px < min_d) return false;
      if(buy_px - buy_sl < min_d) return false;
      if(sell_sl - sell_px < min_d) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool PlaceStraddle()
{
   if(CountOurPositions() > 0 || CountOurPendings() > 0)
      return false;
   if(CurrentM5Bar() == g_last_entry_bar)
      return false;
   if(InpUseSLGuardian && SpreadPoints() > InpMaxSpreadPts)
      return false;

   double buy_px, sell_px, buy_sl, sell_sl;
   int sl_pts, half_pts;
   if(!BuildStraddlePrices(buy_px, sell_px, buy_sl, sell_sl, sl_pts, half_pts))
      return false;

   double lots = CalcLot(sl_pts);
   int slip = SlippageRaw();

   ResetLastError();
   int bt = OrderSend(g_symbol, OP_BUYSTOP, lots, buy_px, slip, buy_sl, 0,
                      InpTradeComment, InpMagic, 0, clrDodgerBlue);
   if(bt < 0)
   {
      Print("IDC_V: BuyStop fail err=", GetLastError(), " px=", buy_px, " sl=", buy_sl);
      return false;
   }

   ResetLastError();
   int st = OrderSend(g_symbol, OP_SELLSTOP, lots, sell_px, slip, sell_sl, 0,
                      InpTradeComment, InpMagic, 0, clrOrangeRed);
   if(st < 0)
   {
      Print("IDC_V: SellStop fail err=", GetLastError(), " px=", sell_px, " sl=", sell_sl);
      if(OrderSelect(bt, SELECT_BY_TICKET))
         OrderDelete(bt);
      return false;
   }

   g_buy_stop_ticket = bt;
   g_sell_stop_ticket = st;
   Print("IDC_V: straddle OK buy#", bt, "@", buy_px, " sell#", st, "@", sell_px,
         " half=", half_pts, " gap~", half_pts * 2, " sl=", sl_pts, " lot=", lots);
   return true;
}

//+------------------------------------------------------------------+
//| §1.4 Re-anchor pending to current price (same setup)              |
//+------------------------------------------------------------------+
void ReanchorStraddle()
{
   if(CountOurPositions() > 0)
      return;
   if(g_buy_stop_ticket < 0 || g_sell_stop_ticket < 0)
      SyncTicketsFromMarket();
   if(g_buy_stop_ticket < 0 || g_sell_stop_ticket < 0)
      return;

   double buy_px, sell_px, buy_sl, sell_sl;
   int sl_pts, half_pts;
   if(!BuildStraddlePrices(buy_px, sell_px, buy_sl, sell_sl, sl_pts, half_pts))
      return;

   // modify buy stop
   if(OrderSelect(g_buy_stop_ticket, SELECT_BY_TICKET, MODE_TRADES))
   {
      if(OrderType() == OP_BUYSTOP)
      {
         if(MathAbs(OrderOpenPrice() - buy_px) >= g_point ||
            MathAbs(OrderStopLoss() - buy_sl) >= g_point)
         {
            if(!OrderModify(g_buy_stop_ticket, buy_px, buy_sl, 0, 0, clrDodgerBlue))
            {
               int err = GetLastError();
               if(err != 0 && err != 1) // 1 = no-change / unknown result on some builds
                  Print("IDC_V: reanchor buy fail err=", err);
            }
         }
      }
   }

   // modify sell stop
   if(OrderSelect(g_sell_stop_ticket, SELECT_BY_TICKET, MODE_TRADES))
   {
      if(OrderType() == OP_SELLSTOP)
      {
         if(MathAbs(OrderOpenPrice() - sell_px) >= g_point ||
            MathAbs(OrderStopLoss() - sell_sl) >= g_point)
         {
            if(!OrderModify(g_sell_stop_ticket, sell_px, sell_sl, 0, 0, clrOrangeRed))
            {
               int err = GetLastError();
               if(err != 0 && err != 1)
                  Print("IDC_V: reanchor sell fail err=", err);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| §3.3 Trailing                                                     |
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

   if(profit_pts < InpTrailStartPts)
      return;

   double extra = profit_pts - InpTrailStartPts;
   int steps = (int)MathFloor(extra / InpTrailStepPts + 1e-8);
   int lock_pts = InpTrailStartPts + steps * InpTrailStepPts;

   double desired_sl;
   if(type == OP_BUY)
      desired_sl = NormalizeDouble(open_price + PtsPrice(lock_pts), g_digits);
   else
      desired_sl = NormalizeDouble(open_price - PtsPrice(lock_pts), g_digits);

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
      Print("IDC_V: trail modify fail #", ticket, " err=", GetLastError());
   else
      g_trail_armed = true;
}

//+------------------------------------------------------------------+
//| G04 G05                                                           |
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
         Print("IDC_V: guardian set SL fail err=", GetLastError());
      return;
   }

   if(g_trail_armed)
      return;

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
            Print("IDC_V: guardian widen fail err=", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
bool CloseTicket(const int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return false;
   double price = (OrderType() == OP_BUY) ? MarketInfo(g_symbol, MODE_BID)
                                          : MarketInfo(g_symbol, MODE_ASK);
   ResetLastError();
   bool ok = OrderClose(ticket, OrderLots(), price, SlippageRaw(), clrAqua);
   if(!ok)
      Print("IDC_V: close fail #", ticket, " err=", GetLastError());
   return ok;
}

bool CloseOurPosition()
{
   int ticket = FindPositionTicket();
   if(ticket < 0) return false;
   return CloseTicket(ticket);
}

//+------------------------------------------------------------------+
void DrawPanel()
{
   if(!InpShowPanel)
   {
      Comment("");
      return;
   }
   int tf = Period();
   string tf_s = (tf == PERIOD_M5) ? "M5" : ("TF?" + IntegerToString(tf));
   int half = EffectiveHalfGapPts();
   string s = "";
   s += "IDC_V v2.00 | " + g_symbol + " " + tf_s + "\n";
   s += "GMT offset(sec): " + IntegerToString(g_gmt_offset_sec) + "\n";
   s += "Point: " + DoubleToStr(g_point, g_digits) + " | Spread: " + IntegerToString(SpreadPoints()) + " pts\n";
   s += "Session: " + (IsWithinTradingHours() ? "OPEN" : "CLOSED");
   s += " | DailyLoss: " + (g_daily_loss_hit ? "HIT" : "ok") + "\n";
   s += "Gap set: " + IntegerToString(InpStopLineGapPts) + " | half now: " + IntegerToString(half);
   s += " | SL: " + IntegerToString(EffectiveSLPts()) + " pts\n";
   s += "Trail: " + IntegerToString(InpTrailStartPts) + "/" + IntegerToString(InpTrailStepPts);
   s += " | Pos: " + IntegerToString(CountOurPositions());
   s += " Pending: " + IntegerToString(CountOurPendings()) + "\n";
   s += "Lot: " + (InpUseAutoLot ? "AUTO" : "FIXED");
   s += " | Guardian: " + (InpUseSLGuardian ? "ON" : "OFF");
   s += " | TrailArmed: " + (g_trail_armed ? "Y" : "N");
   Comment(s);
}

//+------------------------------------------------------------------+
