//+------------------------------------------------------------------+
//|                                                       IDC_V.mq4  |
//|                     BuyStop/SellStop Straddle + Trailing (MT4)   |
//|                                              Timeframe: M5/Gold  |
//+------------------------------------------------------------------+
#property copyright "IDC_V"
#property link      ""
#property version   "1.00"
#property strict
#property description "IDC_V - XAUUSD M5 BuyStop/SellStop straddle EA with OCO + trailing (no TP)"

//--- Money / Lots
input string           InpSecLots          = "=== Lot ===";
input bool             InpUseAutoLot       = true;          // Use auto lot
input double           InpRiskPercent      = 1.0;           // Auto lot risk % of balance
input double           InpFixedLot         = 0.01;          // Fixed lot (if auto off)
input double           InpMaxLot           = 5.0;           // Max lot cap

//--- Entry / Stops (ALL VALUES IN POINTS)
input string           InpSecEntry         = "=== Entry / SL (points) ===";
input int              InpEntryOffsetPts   = 95;            // Pending offset from mid price (points)
input int              InpSLPoints         = 150;           // Initial SL distance (points)
input int              InpMinEntryGapPts   = 20;            // Min gap beyond stop-level/spread (points)

//--- Trailing (NO TP) — ALL IN POINTS
input string           InpSecTrail         = "=== Trailing (points) ===";
input int              InpTrailStartPts    = 200;           // Trailing start (points from entry)
input int              InpTrailStepPts     = 10;            // Trailing step (points)

//--- SL Guardian
input string           InpSecGuard         = "=== SL Guardian ===";
input bool             InpUseSLGuardian    = true;          // Enable SL Guardian
input int              InpMaxSpreadPts     = 80;            // Max allowed spread (points)
input int              InpSpreadBufferPts  = 15;            // Extra buffer over StopLevel (points)
input int              InpSLPadPts         = 5;             // Pad SL beyond broker minimum (points)
input bool             InpCancelOnWideSprd = true;          // Cancel pendings if spread too wide

//--- Session / Risk
input string           InpSecTime          = "=== Session / Daily Loss ===";
input bool             InpUseTimeFilter    = true;          // Use trading hours
input int              InpStartHourGMT     = 13;            // Start hour (GMT) — NY open ~13:00 GMT
input int              InpStartMinuteGMT   = 0;             // Start minute (GMT)
input int              InpEndHourGMT       = 16;            // End hour (GMT)
input int              InpEndMinuteGMT     = 0;             // End minute (GMT)
input bool             InpCloseOutsideHrs  = false;         // Close open trade outside hours
input double           InpDailyLossPercent = 5.0;           // Daily loss limit (% of day-start equity)
input bool             InpStopOnDailyLoss  = true;          // Block new entries when daily loss hit

//--- Symbol / System
input string           InpSecSys           = "=== System ===";
input bool             InpAutoDetectSymbol = true;          // Auto-detect gold symbol if needed
input string           InpForcedSymbol     = "";            // Force symbol (blank = chart/auto)
input int              InpMagic            = 260719;        // Magic number
input int              InpSlippagePts      = 30;            // Slippage (points)
input bool             InpShowPanel        = true;          // Show status panel
input string           InpTradeComment     = "IDC_V";       // Order comment

//--- runtime
string   g_symbol;
double   g_point;              // normalized 1-point price size
int      g_digits;
int      g_gmt_offset_hours;   // server = GMT + offset
datetime g_day_stamp;
double   g_day_start_equity;
bool     g_daily_loss_hit;
datetime g_last_place_bar;
datetime g_last_entry_bar;
datetime g_entry_time;
double   g_entry_price;
int      g_entry_type;         // OP_BUY / OP_SELL / -1
bool     g_trail_armed;

//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = ResolveSymbol();
   if(g_symbol == "")
   {
      Print("IDC_V: gold symbol not found.");
      return INIT_FAILED;
   }

   if(!SymbolSelect(g_symbol, true))
      Print("IDC_V: SymbolSelect failed for ", g_symbol);

   g_digits = (int)MarketInfo(g_symbol, MODE_DIGITS);
   g_point  = NormalizedPoint(g_symbol);
   g_gmt_offset_hours = DetectBrokerGmtOffset();

   g_day_stamp = 0;
   g_day_start_equity = AccountEquity();
   g_daily_loss_hit = false;
   g_last_place_bar = 0;
   g_last_entry_bar = 0;
   g_entry_time = 0;
   g_entry_price = 0;
   g_entry_type = -1;
   g_trail_armed = false;

   Print("IDC_V init | symbol=", g_symbol,
         " digits=", g_digits,
         " point=", DoubleToStr(g_point, g_digits),
         " brokerGMT=", (g_gmt_offset_hours >= 0 ? "+" : ""), g_gmt_offset_hours);

   if(Period() != PERIOD_M5)
      Print("IDC_V warning: designed for M5 (current TF=", Period(), ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   ObjectDelete(0, "IDC_V_PANEL");
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsConnected() || !IsTradeAllowed())
      return;

   RefreshRates();
   UpdateDayState();

   // Sync state from actual positions/orders
   SyncPositionState();

   // SL Guardian / Trailing on open position
   if(HasOpenPosition())
   {
      if(InpUseSLGuardian)
         GuardOpenPositionSL();
      ManageTrailing();
   }

   // OCO: if one side filled, kill opposite pending
   EnforceOCO();

   // Outside hours handling
   bool in_session = IsWithinTradingHours();
   if(!in_session)
   {
      CancelAllPendings();
      if(InpCloseOutsideHrs && HasOpenPosition())
         CloseOurPosition();
      DrawPanel(in_session);
      return;
   }

   if(g_daily_loss_hit && InpStopOnDailyLoss)
   {
      CancelAllPendings();
      DrawPanel(in_session);
      return;
   }

   // While in trade: no new entries until fully closed
   if(HasOpenPosition())
   {
      DrawPanel(in_session);
      return;
   }

   // Flat: clear stale pendings if spread too wide
   if(InpUseSLGuardian && InpCancelOnWideSprd && SpreadPoints() > InpMaxSpreadPts)
   {
      CancelAllPendings();
      DrawPanel(in_session);
      return;
   }

   // One setup per bar; only if no pendings and no position
   datetime bar_time = iTime(g_symbol, PERIOD_M5, 0);
   if(CountOurPendings() == 0)
   {
      // one entry per bar: do not place again on a bar that already produced an entry
      if(bar_time != g_last_entry_bar && bar_time != g_last_place_bar)
      {
         if(PlaceStraddle())
            g_last_place_bar = bar_time;
      }
   }

   DrawPanel(in_session);
}

//+------------------------------------------------------------------+
//| Symbol / point / time helpers                                     |
//+------------------------------------------------------------------+
string ResolveSymbol()
{
   if(StringLen(InpForcedSymbol) > 0)
      return InpForcedSymbol;

   string chart_sym = Symbol();
   if(IsGoldSymbol(chart_sym))
      return chart_sym;

   if(!InpAutoDetectSymbol)
      return chart_sym; // allow non-gold if user attaches intentionally

   string candidates[] = {
      "XAUUSD","XAUUSDm","XAUUSD.a","XAUUSD.i","XAUUSD.r","XAUUSD.pro",
      "XAUUSDmicro","GOLD","GOLDm","GOLD.a","XAUUSD#","XAU/USD","Xauusd"
   };
   for(int i = 0; i < ArraySize(candidates); i++)
   {
      if(MarketInfo(candidates[i], MODE_BID) > 0 || SymbolSelect(candidates[i], true))
      {
         if(MarketInfo(candidates[i], MODE_BID) > 0)
            return candidates[i];
      }
   }

   // scan market watch
   int total = SymbolsTotal(true);
   for(int s = 0; s < total; s++)
   {
      string name = SymbolName(s, true);
      if(IsGoldSymbol(name))
         return name;
   }
   return chart_sym;
}

bool IsGoldSymbol(const string sym)
{
   string u = sym;
   StringToUpper(u);
   if(StringFind(u, "XAU") >= 0) return true;
   if(StringFind(u, "GOLD") >= 0) return true;
   return false;
}

double NormalizedPoint(const string sym)
{
   double p = MarketInfo(sym, MODE_POINT);
   int d = (int)MarketInfo(sym, MODE_DIGITS);
   // Unify "point" across 2/3-digit gold and 4/5-digit FX:
   // Digits 3 or 5 => 1 point = 10 * MODE_POINT (so 150 pts ≈ 1.50 on gold)
   if(d == 3 || d == 5)
      return p * 10.0;
   return p;
}

double PointsToPrice(const int pts)
{
   return pts * g_point;
}

int PriceToPoints(const double price_dist)
{
   if(g_point <= 0) return 0;
   return (int)MathRound(MathAbs(price_dist) / g_point);
}

int DetectBrokerGmtOffset()
{
   // Prefer TimeGMT() when available (build 600+)
   datetime server_now = TimeCurrent();
   datetime gmt_now = TimeGMT();
   int off = (int)MathRound((double)(server_now - gmt_now) / 3600.0);
   // clamp to sane range
   if(off < -12) off = -12;
   if(off > 14)  off = 14;
   return off;
}

datetime BrokerTimeFromGmtHMS(const int gh, const int gm, const int gs=0)
{
   datetime now = TimeCurrent();
   // Today's GMT midnight approximated via server time - offset
   datetime gmt_now = now - g_gmt_offset_hours * 3600;
   MqlDateTime dt;
   TimeToStruct(gmt_now, dt);
   dt.hour = gh;
   dt.min  = gm;
   dt.sec  = gs;
   datetime gmt_target = StructToTime(dt);
   return gmt_target + g_gmt_offset_hours * 3600;
}

bool IsWithinTradingHours()
{
   if(!InpUseTimeFilter)
      return true;

   datetime start = BrokerTimeFromGmtHMS(InpStartHourGMT, InpStartMinuteGMT);
   datetime end   = BrokerTimeFromGmtHMS(InpEndHourGMT, InpEndMinuteGMT);
   datetime now   = TimeCurrent();

   // overnight window support
   if(end <= start)
      return (now >= start || now < end);
   return (now >= start && now < end);
}

//+------------------------------------------------------------------+
void UpdateDayState()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime day = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(day != g_day_stamp)
   {
      g_day_stamp = day;
      g_day_start_equity = AccountEquity();
      g_daily_loss_hit = false;
   }

   if(InpDailyLossPercent <= 0)
      return;

   double eq = AccountEquity();
   double dd_pct = 0.0;
   if(g_day_start_equity > 0)
      dd_pct = (g_day_start_equity - eq) / g_day_start_equity * 100.0;

   if(dd_pct >= InpDailyLossPercent)
      g_daily_loss_hit = true;
}

//+------------------------------------------------------------------+
int SpreadPoints()
{
   double ask = MarketInfo(g_symbol, MODE_ASK);
   double bid = MarketInfo(g_symbol, MODE_BID);
   return PriceToPoints(ask - bid);
}

int BrokerStopLevelPoints()
{
   int stop_level = (int)MarketInfo(g_symbol, MODE_STOPLEVEL);
   int freeze     = (int)MarketInfo(g_symbol, MODE_FREEZELEVEL);
   // MODE_STOPLEVEL is in points of MODE_POINT (raw). Convert to our unified points.
   double raw_point = MarketInfo(g_symbol, MODE_POINT);
   int raw = MathMax(stop_level, freeze);
   if(raw_point <= 0 || g_point <= 0) return raw;
   return (int)MathCeil((raw * raw_point) / g_point);
}

int MinEntryOffsetPoints()
{
   int need = BrokerStopLevelPoints() + SpreadPoints() + InpSpreadBufferPts + InpMinEntryGapPts;
   if(need < InpEntryOffsetPts) need = InpEntryOffsetPts;
   return need;
}

int MinSLPoints()
{
   int need = BrokerStopLevelPoints() + SpreadPoints() + InpSLPadPts;
   if(need < InpSLPoints) need = InpSLPoints;
   // Guardian may force larger SL than user asked when broker requires it
   return need;
}

//+------------------------------------------------------------------+
//| Lot                                                               |
//+------------------------------------------------------------------+
double NormalizeVolume(double lots)
{
   double minlot  = MarketInfo(g_symbol, MODE_MINLOT);
   double maxlot  = MarketInfo(g_symbol, MODE_MAXLOT);
   double steplot = MarketInfo(g_symbol, MODE_LOTSTEP);
   if(steplot <= 0) steplot = 0.01;

   if(lots < minlot) lots = minlot;
   if(lots > maxlot) lots = maxlot;
   if(lots > InpMaxLot) lots = InpMaxLot;

   lots = MathFloor(lots / steplot + 1e-8) * steplot;

   int lot_digits = 2;
   if(steplot < 0.01) lot_digits = 3;
   if(steplot >= 0.1) lot_digits = 1;
   return NormalizeDouble(lots, lot_digits);
}

double CalcLot(const int sl_pts)
{
   if(!InpUseAutoLot)
      return NormalizeVolume(InpFixedLot);

   double balance = AccountBalance();
   double risk_money = balance * InpRiskPercent / 100.0;

   double tick_val  = MarketInfo(g_symbol, MODE_TICKVALUE);
   double tick_size = MarketInfo(g_symbol, MODE_TICKSIZE);
   if(tick_val <= 0 || tick_size <= 0 || sl_pts <= 0)
      return NormalizeVolume(InpFixedLot);

   double sl_price = PointsToPrice(sl_pts);
   double money_per_lot = (sl_price / tick_size) * tick_val;
   if(money_per_lot <= 0)
      return NormalizeVolume(InpFixedLot);

   double lots = risk_money / money_per_lot;
   return NormalizeVolume(lots);
}

//+------------------------------------------------------------------+
//| Position / order inventory                                        |
//+------------------------------------------------------------------+
bool IsOurOrder()
{
   // Requires OrderSelect() already performed by caller
   if(OrderMagicNumber() != InpMagic) return false;
   if(OrderSymbol() != g_symbol) return false;
   return true;
}

int CountOurPositions()
{
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         c++;
   }
   return c;
}

int CountOurPendings()
{
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;
      int t = OrderType();
      if(t == OP_BUYSTOP || t == OP_SELLSTOP || t == OP_BUYLIMIT || t == OP_SELLLIMIT)
         c++;
   }
   return c;
}

bool HasOpenPosition()
{
   return CountOurPositions() > 0;
}

int FindOurPositionTicket()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         return OrderTicket();
   }
   return -1;
}

void SyncPositionState()
{
   int ticket = FindOurPositionTicket();
   if(ticket < 0)
   {
      if(g_entry_type != -1)
      {
         // just closed
         g_entry_type = -1;
         g_entry_price = 0;
         g_entry_time = 0;
         g_trail_armed = false;
      }
      return;
   }

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;

   if(g_entry_type == -1)
   {
      // new fill detected
      g_entry_type  = OrderType();
      g_entry_price = OrderOpenPrice();
      g_entry_time  = OrderOpenTime();
      g_trail_armed = false;
      g_last_entry_bar = iTime(g_symbol, PERIOD_M5, 0);
   }
}

//+------------------------------------------------------------------+
//| OCO                                                               |
//+------------------------------------------------------------------+
void EnforceOCO()
{
   bool has_buy = false;
   bool has_sell = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;
      if(OrderType() == OP_BUY)  has_buy = true;
      if(OrderType() == OP_SELL) has_sell = true;
   }

   if(has_buy || has_sell)
   {
      // cancel all remaining pendings (opposite + any leftover)
      CancelAllPendings();
      return;
   }

   // If somehow both pendings still exist but one side invalid — nothing else
}

void CancelAllPendings()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurOrder()) continue;
      int t = OrderType();
      if(t == OP_BUYSTOP || t == OP_SELLSTOP || t == OP_BUYLIMIT || t == OP_SELLLIMIT)
      {
         if(!OrderDelete(OrderTicket()))
            Print("IDC_V: OrderDelete failed #", OrderTicket(), " err=", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Entry: BuyStop + SellStop straddle                                |
//+------------------------------------------------------------------+
bool PlaceStraddle()
{
   if(InpUseSLGuardian && SpreadPoints() > InpMaxSpreadPts)
      return false;

   // Hard rule: only one entry path — no position, no existing pendings
   if(HasOpenPosition() || CountOurPendings() > 0)
      return false;

   // One entry per bar
   datetime bar_time = iTime(g_symbol, PERIOD_M5, 0);
   if(bar_time == g_last_entry_bar)
      return false;

   double bid = MarketInfo(g_symbol, MODE_BID);
   double ask = MarketInfo(g_symbol, MODE_ASK);
   if(bid <= 0 || ask <= 0)
      return false;

   int offset_pts = MinEntryOffsetPoints();
   int sl_pts     = InpUseSLGuardian ? MinSLPoints() : InpSLPoints;
   if(sl_pts < 1) sl_pts = InpSLPoints;

   double offset = PointsToPrice(offset_pts);
   double sl_dist = PointsToPrice(sl_pts);

   // Mid-straddle around current market
   double buy_price  = NormalizeDouble(ask + offset, g_digits);
   double sell_price = NormalizeDouble(bid - offset, g_digits);

   // SL only (NO TP)
   double buy_sl  = NormalizeDouble(buy_price - sl_dist, g_digits);
   double sell_sl = NormalizeDouble(sell_price + sl_dist, g_digits);

   // Validate distances vs stop level
   if(InpUseSLGuardian)
   {
      if(!ValidatePendingDistances(OP_BUYSTOP, buy_price, buy_sl))
         return false;
      if(!ValidatePendingDistances(OP_SELLSTOP, sell_price, sell_sl))
         return false;
   }

   double lots = CalcLot(sl_pts);
   int slip = (int)MathMax(1, MathRound(PointsToPrice(InpSlippagePts) / MarketInfo(g_symbol, MODE_POINT)));

   ResetLastError();
   int buy_ticket = OrderSend(g_symbol, OP_BUYSTOP, lots, buy_price, slip, buy_sl, 0,
                              InpTradeComment, InpMagic, 0, clrDodgerBlue);
   if(buy_ticket < 0)
   {
      Print("IDC_V: BuyStop failed err=", GetLastError(),
            " price=", buy_price, " sl=", buy_sl, " lots=", lots);
      return false;
   }

   ResetLastError();
   int sell_ticket = OrderSend(g_symbol, OP_SELLSTOP, lots, sell_price, slip, sell_sl, 0,
                               InpTradeComment, InpMagic, 0, clrOrangeRed);
   if(sell_ticket < 0)
   {
      Print("IDC_V: SellStop failed err=", GetLastError(),
            " price=", sell_price, " sl=", sell_sl, " lots=", lots);
      // OCO integrity: remove the buy stop we just placed
      if(OrderSelect(buy_ticket, SELECT_BY_TICKET))
         OrderDelete(buy_ticket);
      return false;
   }

   Print("IDC_V: straddle placed | BuyStop#", buy_ticket, "@", buy_price,
         " SellStop#", sell_ticket, "@", sell_price,
         " SL_pts=", sl_pts, " offset_pts=", offset_pts, " lot=", lots);
   return true;
}

bool ValidatePendingDistances(const int type, const double price, const double sl)
{
   double bid = MarketInfo(g_symbol, MODE_BID);
   double ask = MarketInfo(g_symbol, MODE_ASK);
   int min_pts = BrokerStopLevelPoints() + InpSLPadPts;
   double min_dist = PointsToPrice(min_pts);

   if(type == OP_BUYSTOP)
   {
      if(price - ask < min_dist - g_point * 0.1) return false;
      if(price - sl  < min_dist - g_point * 0.1) return false;
   }
   if(type == OP_SELLSTOP)
   {
      if(bid - price < min_dist - g_point * 0.1) return false;
      if(sl - price  < min_dist - g_point * 0.1) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Trailing (no TP)                                                  |
//| Start: when profit >= TrailStart, SL -> entry +/- TrailStart      |
//| Then chase by TrailStep increments from that locked level         |
//+------------------------------------------------------------------+
void ManageTrailing()
{
   int ticket = FindOurPositionTicket();
   if(ticket < 0) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return;

   int type = OrderType();
   double open_price = OrderOpenPrice();
   double cur_sl = OrderStopLoss();
   double bid = MarketInfo(g_symbol, MODE_BID);
   double ask = MarketInfo(g_symbol, MODE_ASK);

   int start_pts = InpTrailStartPts;
   int step_pts  = InpTrailStepPts;
   if(start_pts <= 0 || step_pts <= 0)
      return;

   double profit_pts = 0;
   if(type == OP_BUY)
      profit_pts = (bid - open_price) / g_point;
   else if(type == OP_SELL)
      profit_pts = (open_price - ask) / g_point;
   else
      return;

   if(profit_pts < start_pts)
      return;

   // desired locked points from entry:
   // start + floor((profit-start)/step)*step
   double extra = profit_pts - start_pts;
   int steps = (int)MathFloor(extra / step_pts + 1e-8);
   int lock_pts = start_pts + steps * step_pts;

   double desired_sl = 0;
   if(type == OP_BUY)
      desired_sl = NormalizeDouble(open_price + PointsToPrice(lock_pts), g_digits);
   else
      desired_sl = NormalizeDouble(open_price - PointsToPrice(lock_pts), g_digits);

   // Guardian: keep SL at least min distance from market
   if(InpUseSLGuardian)
   {
      int min_pts = BrokerStopLevelPoints() + InpSLPadPts;
      double min_dist = PointsToPrice(min_pts);
      if(type == OP_BUY)
      {
         double max_sl = NormalizeDouble(bid - min_dist, g_digits);
         if(desired_sl > max_sl) desired_sl = max_sl;
      }
      else
      {
         double min_sl = NormalizeDouble(ask + min_dist, g_digits);
         if(desired_sl < min_sl) desired_sl = min_sl;
      }
   }

   bool improve = false;
   if(type == OP_BUY)
   {
      if(cur_sl <= 0 || desired_sl > cur_sl + g_point * 0.1)
         improve = true;
   }
   else
   {
      if(cur_sl <= 0 || desired_sl < cur_sl - g_point * 0.1)
         improve = true;
   }

   if(!improve)
      return;

   // Do not set SL beyond current price illegally
   if(type == OP_BUY && desired_sl >= bid) return;
   if(type == OP_SELL && desired_sl <= ask) return;

   ResetLastError();
   if(!OrderModify(ticket, open_price, desired_sl, 0, 0, clrYellow))
   {
      Print("IDC_V: trailing modify fail #", ticket, " err=", GetLastError(),
            " sl=", desired_sl, " lock_pts=", lock_pts);
   }
   else
   {
      g_trail_armed = true;
   }
}

//+------------------------------------------------------------------+
//| SL Guardian for open positions                                    |
//+------------------------------------------------------------------+
void GuardOpenPositionSL()
{
   int ticket = FindOurPositionTicket();
   if(ticket < 0) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return;

   int type = OrderType();
   double open_price = OrderOpenPrice();
   double cur_sl = OrderStopLoss();
   double bid = MarketInfo(g_symbol, MODE_BID);
   double ask = MarketInfo(g_symbol, MODE_ASK);

   int sl_pts = MinSLPoints();
   double sl_dist = PointsToPrice(sl_pts);

   // If SL missing — restore protective SL (never loosen a trailing lock)
   if(cur_sl <= 0)
   {
      double new_sl = (type == OP_BUY)
         ? NormalizeDouble(open_price - sl_dist, g_digits)
         : NormalizeDouble(open_price + sl_dist, g_digits);

      // clamp to broker min distance from market
      int min_pts = BrokerStopLevelPoints() + InpSLPadPts;
      double min_dist = PointsToPrice(min_pts);
      if(type == OP_BUY)
      {
         double floor_sl = NormalizeDouble(bid - min_dist, g_digits);
         if(new_sl > floor_sl) new_sl = floor_sl;
      }
      else
      {
         double ceil_sl = NormalizeDouble(ask + min_dist, g_digits);
         if(new_sl < ceil_sl) new_sl = ceil_sl;
      }

      ResetLastError();
      if(!OrderModify(ticket, open_price, new_sl, 0, 0, clrRed))
         Print("IDC_V: guardian set SL fail err=", GetLastError());
      return;
   }

   // If SL closer than broker allows — push it out (only if NOT already trailing in profit)
   if(!g_trail_armed)
   {
      int cur_sl_pts = 0;
      if(type == OP_BUY)  cur_sl_pts = PriceToPoints(open_price - cur_sl);
      if(type == OP_SELL) cur_sl_pts = PriceToPoints(cur_sl - open_price);

      int need = BrokerStopLevelPoints() + InpSLPadPts;
      if(cur_sl_pts > 0 && cur_sl_pts < need)
      {
         double new_sl = (type == OP_BUY)
            ? NormalizeDouble(open_price - PointsToPrice(need), g_digits)
            : NormalizeDouble(open_price + PointsToPrice(need), g_digits);

         // only widen (more protective distance), never tighten toward price here
         bool widen = false;
         if(type == OP_BUY  && new_sl < cur_sl) widen = true;
         if(type == OP_SELL && new_sl > cur_sl) widen = true;
         if(widen)
         {
            ResetLastError();
            if(!OrderModify(ticket, open_price, new_sl, 0, 0, clrRed))
               Print("IDC_V: guardian widen SL fail err=", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
bool CloseOurPosition()
{
   int ticket = FindOurPositionTicket();
   if(ticket < 0) return false;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;

   double price = (OrderType() == OP_BUY)
      ? MarketInfo(g_symbol, MODE_BID)
      : MarketInfo(g_symbol, MODE_ASK);
   int slip = (int)MathMax(1, MathRound(PointsToPrice(InpSlippagePts) / MarketInfo(g_symbol, MODE_POINT)));

   ResetLastError();
   bool ok = OrderClose(ticket, OrderLots(), price, slip, clrAqua);
   if(!ok)
      Print("IDC_V: close fail err=", GetLastError());
   return ok;
}

//+------------------------------------------------------------------+
void DrawPanel(const bool in_session)
{
   if(!InpShowPanel)
   {
      Comment("");
      return;
   }

   string s = "";
   s += "IDC_V | " + g_symbol + " M5\n";
   s += "Broker GMT: " + (g_gmt_offset_hours >= 0 ? "+" : "") + IntegerToString(g_gmt_offset_hours) + "\n";
   s += "Point: " + DoubleToStr(g_point, g_digits) + " | Spread: " + IntegerToString(SpreadPoints()) + " pts\n";
   s += "Session: " + (in_session ? "OPEN" : "CLOSED");
   s += " | DailyLoss: " + (g_daily_loss_hit ? "HIT" : "ok") + "\n";
   s += "Pos: " + IntegerToString(CountOurPositions());
   s += " | Pending: " + IntegerToString(CountOurPendings()) + "\n";
   s += "SL: " + IntegerToString(InpSLPoints) + " pts";
   s += " | TrailStart: " + IntegerToString(InpTrailStartPts);
   s += " / Step: " + IntegerToString(InpTrailStepPts) + "\n";
   s += "Lot: " + (InpUseAutoLot ? "AUTO" : "FIXED") + " | TrailArmed: " + (g_trail_armed ? "Y" : "N");
   Comment(s);
}

//+------------------------------------------------------------------+
