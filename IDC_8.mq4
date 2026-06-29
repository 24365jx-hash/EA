//+------------------------------------------------------------------+
//| IDC_8.mq4 - GOLD M1 SYSTEM (MT4)                                 |
//| EMA cross + RSI cross + fast EMA candle confirmation             |
//+------------------------------------------------------------------+
#property copyright "IDC_8"
#property version   "3.01"
#property strict

enum ENUM_CYCLE
  {
   CYCLE_NONE = 0,
   CYCLE_BUY  = 1,
   CYCLE_SELL = 2
  };

enum ENUM_SETUP_PHASE
  {
   PHASE_IDLE         = 0,
   PHASE_WAIT_RSI_ARM = 1,
   PHASE_WAIT_EMA     = 2
  };

//--- Symbol / broker
input bool   InpAutoDetectGold = true;   // Auto-detect gold symbol
input string InpManualSymbol   = "";     // Manual symbol override (blank=auto)

//--- EMA
input int InpFastEmaPeriod = 9;
input int InpSlowEmaPeriod = 50;

//--- RSI
input int    InpRsiPeriod = 14;
input double InpRsiUpper  = 52.0;
input double InpRsiLower  = 48.0;

//--- Entry rules
input int InpObservationBars = 30;
input int InpEmaGraceBars    = 3;

//--- Risk / exit
input double InpLots             = 0.01;
input int    InpStopLossPoints   = 500;
input int    InpTrailingStartPts = 200;
input int    InpTrailingStepPts  = 10;

//--- Trade settings
input int    InpMagicNumber  = 80008;
input int    InpSlippagePts  = 30;
input string InpTradeComment = "IDC_8";

string   g_trade_symbol      = "";
int      g_broker_gmt_offset = 0;
datetime g_broker_time       = 0;

ENUM_CYCLE       g_cycle            = CYCLE_NONE;
ENUM_SETUP_PHASE g_setup_phase      = PHASE_IDLE;
datetime         g_cycle_start_time = 0;
bool             g_entry_taken      = false;

bool     g_rsi_armed       = false;
int      g_grace_remaining = 0;
datetime g_last_bar_time   = 0;

//+------------------------------------------------------------------+
string TradeSymbol()
  {
   if(StringLen(g_trade_symbol) > 0)
      return g_trade_symbol;
   return Symbol();
  }

//+------------------------------------------------------------------+
double TradePoint()
  {
   return MarketInfo(TradeSymbol(), MODE_POINT);
  }

//+------------------------------------------------------------------+
int TradeDigits()
  {
   return (int)MarketInfo(TradeSymbol(), MODE_DIGITS);
  }

//+------------------------------------------------------------------+
double TradeAsk()
  {
   return MarketInfo(TradeSymbol(), MODE_ASK);
  }

//+------------------------------------------------------------------+
double TradeBid()
  {
   return MarketInfo(TradeSymbol(), MODE_BID);
  }

//+------------------------------------------------------------------+
double PointsToPrice(const int points)
  {
   return (double)points * TradePoint();
  }

//+------------------------------------------------------------------+
double NormalizeTradePrice(const double price)
  {
   return NormalizeDouble(price, TradeDigits());
  }

//+------------------------------------------------------------------+
double GetStopLevelPts()
  {
   return MarketInfo(TradeSymbol(), MODE_STOPLEVEL);
  }

//+------------------------------------------------------------------+
double GetFreezeLevelPts()
  {
   return MarketInfo(TradeSymbol(), MODE_FREEZELEVEL);
  }

//+------------------------------------------------------------------+
void UpdateBrokerTime()
  {
   g_broker_time       = TimeCurrent();
   g_broker_gmt_offset = TimeGMTOffset();
  }

//+------------------------------------------------------------------+
string FormatBrokerTime(const datetime t)
  {
   return TimeToString(t, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
  }

//+------------------------------------------------------------------+
string BrokerOffsetLabel()
  {
   int hours = g_broker_gmt_offset / 3600;
   int mins  = (MathAbs(g_broker_gmt_offset) % 3600) / 60;
   string sign = (g_broker_gmt_offset >= 0) ? "+" : "-";
   return StringFormat("GMT%s%02d:%02d", sign, MathAbs(hours), mins);
  }

//+------------------------------------------------------------------+
bool IsGoldSymbolName(const string sym)
  {
   string upper = sym;
   StringToUpper(upper);

   if(StringFind(upper, "XAU") >= 0)
      return true;
   if(StringFind(upper, "GOLD") >= 0)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsSymbolTradableGold(const string sym)
  {
   if(StringLen(sym) == 0)
      return false;
   if(!IsGoldSymbolName(sym))
      return false;

   if(!SymbolSelect(sym, true))
      return false;
   if(MarketInfo(sym, MODE_TRADEALLOWED) == 0)
      return false;
   if(MarketInfo(sym, MODE_BID) <= 0.0)
      return false;
   if(MarketInfo(sym, MODE_ASK) <= 0.0)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
int GoldSymbolPriority(const string sym)
  {
   string upper = sym;
   StringToUpper(upper);

   if(upper == "XAUUSD")
      return 100;
   if(StringFind(upper, "XAUUSD") == 0)
      return 90;
   if(upper == "GOLD")
      return 80;
   if(StringFind(upper, "GOLD") == 0)
      return 70;
   if(StringFind(upper, "XAU") >= 0)
      return 60;
   return 10;
  }

//+------------------------------------------------------------------+
bool TrySetTradeSymbol(const string sym, string &best_sym, int &best_rank)
  {
   if(!IsSymbolTradableGold(sym))
      return false;

   int rank = GoldSymbolPriority(sym);
   if(best_sym == "" || rank > best_rank)
     {
      best_sym  = sym;
      best_rank = rank;
     }
   return true;
  }

//+------------------------------------------------------------------+
bool DetectGoldSymbol()
  {
   string best_sym  = "";
   int    best_rank = -1;

   if(StringLen(InpManualSymbol) > 0)
     {
      if(!TrySetTradeSymbol(InpManualSymbol, best_sym, best_rank))
        {
         Print("IDC_8: manual symbol not tradable gold: ", InpManualSymbol);
         return false;
        }
      g_trade_symbol = best_sym;
      return true;
     }

   if(!InpAutoDetectGold)
     {
      if(!TrySetTradeSymbol(Symbol(), best_sym, best_rank))
        {
         Print("IDC_8: chart symbol is not tradable gold: ", Symbol());
         return false;
        }
      g_trade_symbol = best_sym;
      return true;
     }

   string preferred[] =
     {
      "XAUUSD", "XAUUSDm", "XAUUSD.", "XAUUSD#", "XAUUSD.i", "XAUUSDpro",
      "XAUUSD.r", "XAUUSD_", "XAU/USD", "GOLD", "GOLDm", "GOLD.", "GOLD#",
      "GOLD.i", "GOLDpro", "XAUUSD.ecn", "XAUUSD-STD", "XAUUSD.std"
     };

   int pref_count = ArraySize(preferred);
   for(int i = 0; i < pref_count; i++)
      TrySetTradeSymbol(preferred[i], best_sym, best_rank);

   if(IsSymbolTradableGold(Symbol()))
      TrySetTradeSymbol(Symbol(), best_sym, best_rank);

   int total = SymbolsTotal(false);
   for(int j = 0; j < total; j++)
     {
      string sym = SymbolName(j, false);
      TrySetTradeSymbol(sym, best_sym, best_rank);
     }

   total = SymbolsTotal(true);
   for(int k = 0; k < total; k++)
     {
      string sym = SymbolName(k, true);
      TrySetTradeSymbol(sym, best_sym, best_rank);
     }

   if(best_sym == "")
     {
      Print("IDC_8: no tradable gold symbol detected.");
      return false;
     }

   g_trade_symbol = best_sym;
   SymbolSelect(g_trade_symbol, true);
   return true;
  }

//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime bar_time = iTime(TradeSymbol(), Period(), 0);
   if(bar_time == 0)
      return false;
   if(bar_time != g_last_bar_time)
     {
      g_last_bar_time = bar_time;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
bool IsOurOrderTicket()
  {
   if(OrderSymbol() != TradeSymbol())
      return false;
   if(OrderMagicNumber() != InpMagicNumber)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(!IsOurOrderTicket())
         continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
void ResetSetupState()
  {
   g_setup_phase     = PHASE_IDLE;
   g_rsi_armed       = false;
   g_grace_remaining = 0;
  }

//+------------------------------------------------------------------+
void ResetCycleState()
  {
   g_cycle            = CYCLE_NONE;
   g_cycle_start_time = 0;
   g_entry_taken      = false;
   ResetSetupState();
  }

//+------------------------------------------------------------------+
void StartCycle(const ENUM_CYCLE cycle, const datetime bar_time)
  {
   g_cycle            = cycle;
   g_cycle_start_time = bar_time;
   g_entry_taken      = false;
   ResetSetupState();
  }

//+------------------------------------------------------------------+
bool GetFastEma(const int shift, double &fast_ema)
  {
   if(iBars(TradeSymbol(), Period()) < InpSlowEmaPeriod + shift + 2)
      return false;

   fast_ema = iMA(TradeSymbol(), Period(), InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   return true;
  }

//+------------------------------------------------------------------+
bool GetEmaPair(const int shift, double &fast_ema, double &slow_ema)
  {
   if(iBars(TradeSymbol(), Period()) < InpSlowEmaPeriod + shift + 2)
      return false;

   fast_ema = iMA(TradeSymbol(), Period(), InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   slow_ema = iMA(TradeSymbol(), Period(), InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   return true;
  }

//+------------------------------------------------------------------+
bool GetRsiValue(const int shift, double &rsi)
  {
   if(iBars(TradeSymbol(), Period()) < InpRsiPeriod + shift + 2)
      return false;

   rsi = iRSI(TradeSymbol(), Period(), InpRsiPeriod, PRICE_CLOSE, shift);
   return true;
  }

//+------------------------------------------------------------------+
//| Closed-bar RSI level breach (touch = break, original strategy)   |
//+------------------------------------------------------------------+
bool IsRsiBreakAboveLevel(const double rsi, const double level)
  {
   return (rsi >= level);
  }

//+------------------------------------------------------------------+
bool IsRsiBreakBelowLevel(const double rsi, const double level)
  {
   return (rsi <= level);
  }

//+------------------------------------------------------------------+
bool IsBodyDominant(const int shift)
  {
   double open  = iOpen(TradeSymbol(), Period(), shift);
   double close = iClose(TradeSymbol(), Period(), shift);
   double high  = iHigh(TradeSymbol(), Period(), shift);
   double low   = iLow(TradeSymbol(), Period(), shift);

   double body       = MathAbs(close - open);
   double upper_wick = high - MathMax(open, close);
   double lower_wick = MathMin(open, close) - low;

   return (body > upper_wick + lower_wick);
  }

//+------------------------------------------------------------------+
bool IsSellEmaConfirm(const int shift)
  {
   double fast_ema = 0.0;
   if(!GetFastEma(shift, fast_ema))
      return false;

   double close = iClose(TradeSymbol(), Period(), shift);
   double low   = iLow(TradeSymbol(), Period(), shift);

   if(close >= fast_ema)
      return false;
   if(low >= fast_ema)
      return false;
   if(!IsBodyDominant(shift))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
bool IsBuyEmaConfirm(const int shift)
  {
   double fast_ema = 0.0;
   if(!GetFastEma(shift, fast_ema))
      return false;

   double close = iClose(TradeSymbol(), Period(), shift);
   double high  = iHigh(TradeSymbol(), Period(), shift);

   if(close <= fast_ema)
      return false;
   if(high <= fast_ema)
      return false;
   if(!IsBodyDominant(shift))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
int BarsSinceCycleStart()
  {
   if(g_cycle_start_time == 0)
      return 2147483647;

   int start_shift = iBarShift(TradeSymbol(), Period(), g_cycle_start_time, true);
   if(start_shift < 0)
      return 2147483647;

   return start_shift;
  }

//+------------------------------------------------------------------+
int RemainingObservationBars()
  {
   int elapsed = BarsSinceCycleStart();
   if(elapsed == 2147483647)
      return 0;

   int remaining = InpObservationBars - elapsed + 1;
   if(remaining < 0)
      remaining = 0;

   return remaining;
  }

//+------------------------------------------------------------------+
bool IsObservationWindowExpired()
  {
   return (RemainingObservationBars() <= 0);
  }

//+------------------------------------------------------------------+
int CalcGraceBarsForTrigger()
  {
   int remaining = RemainingObservationBars();
   if(remaining <= 0)
      return 0;

   return MathMin(InpEmaGraceBars, remaining);
  }

//+------------------------------------------------------------------+
void DetectEmaCrossOnClosedBar()
  {
   double fast_curr = 0.0, slow_curr = 0.0;
   double fast_prev = 0.0, slow_prev = 0.0;

   if(!GetEmaPair(1, fast_curr, slow_curr))
      return;
   if(!GetEmaPair(2, fast_prev, slow_prev))
      return;

   datetime cross_time = iTime(TradeSymbol(), Period(), 1);

   bool dead_cross   = (fast_prev >= slow_prev) && (fast_curr < slow_curr);
   bool golden_cross = (fast_prev <= slow_prev) && (fast_curr > slow_curr);

   if(dead_cross)
      StartCycle(CYCLE_SELL, cross_time);
   else if(golden_cross)
      StartCycle(CYCLE_BUY, cross_time);
  }

//+------------------------------------------------------------------+
void ProcessSellRsiOnClosedBar()
  {
   double rsi = 0.0;
   if(!GetRsiValue(1, rsi))
      return;

   if(g_setup_phase == PHASE_IDLE || g_setup_phase == PHASE_WAIT_RSI_ARM)
     {
      if(IsRsiBreakAboveLevel(rsi, InpRsiUpper))
        {
         g_rsi_armed   = true;
         g_setup_phase = PHASE_WAIT_RSI_ARM;
        }
     }

   if(g_setup_phase == PHASE_WAIT_RSI_ARM && g_rsi_armed)
     {
      if(IsRsiBreakBelowLevel(rsi, InpRsiLower))
        {
         g_setup_phase     = PHASE_WAIT_EMA;
         g_grace_remaining = CalcGraceBarsForTrigger();
         if(g_grace_remaining <= 0)
            ResetSetupState();
        }
     }
  }

//+------------------------------------------------------------------+
void ProcessBuyRsiOnClosedBar()
  {
   double rsi = 0.0;
   if(!GetRsiValue(1, rsi))
      return;

   if(g_setup_phase == PHASE_IDLE || g_setup_phase == PHASE_WAIT_RSI_ARM)
     {
      if(IsRsiBreakBelowLevel(rsi, InpRsiLower))
        {
         g_rsi_armed   = true;
         g_setup_phase = PHASE_WAIT_RSI_ARM;
        }
     }

   if(g_setup_phase == PHASE_WAIT_RSI_ARM && g_rsi_armed)
     {
      if(IsRsiBreakAboveLevel(rsi, InpRsiUpper))
        {
         g_setup_phase     = PHASE_WAIT_EMA;
         g_grace_remaining = CalcGraceBarsForTrigger();
         if(g_grace_remaining <= 0)
            ResetSetupState();
        }
     }
  }

//+------------------------------------------------------------------+
double GetSetupClosePrice()
  {
   return NormalizeTradePrice(iClose(TradeSymbol(), Period(), 1));
  }

//+------------------------------------------------------------------+
double BuildInitialSL(const int order_type, const double reference_price)
  {
   if(InpStopLossPoints <= 0)
      return 0.0;

   if(order_type == OP_BUY)
      return NormalizeTradePrice(reference_price - PointsToPrice(InpStopLossPoints));

   return NormalizeTradePrice(reference_price + PointsToPrice(InpStopLossPoints));
  }

//+------------------------------------------------------------------+
bool IsEntrySlippageAcceptable(const int order_type, const double setup_close)
  {
   RefreshRates();

   double market = (order_type == OP_BUY) ? TradeAsk() : TradeBid();
   double diff_pts = MathAbs(market - setup_close) / TradePoint();

   return (diff_pts <= InpSlippagePts);
  }

//+------------------------------------------------------------------+
double ClampStopLossForBroker(const int order_type, const double desired_sl)
  {
   if(desired_sl <= 0.0)
      return 0.0;

   double stop_pts   = GetStopLevelPts();
   double freeze_pts = GetFreezeLevelPts();
   double guard_pts  = stop_pts;
   if(freeze_pts > guard_pts)
      guard_pts = freeze_pts;
   if(guard_pts < 1.0)
      guard_pts = 1.0;

   double guard = PointsToPrice((int)guard_pts);
   double bid   = TradeBid();
   double ask   = TradeAsk();
   double sl    = NormalizeTradePrice(desired_sl);

   if(order_type == OP_BUY)
     {
      double max_sl = bid - guard;
      if(sl > max_sl)
         sl = NormalizeTradePrice(max_sl);
     }
   else if(order_type == OP_SELL)
     {
      double min_sl = ask + guard;
      if(sl < min_sl)
         sl = NormalizeTradePrice(min_sl);
     }

   return sl;
  }

//+------------------------------------------------------------------+
bool IsStopDistanceValid(const int order_type, const double reference_price, const double sl)
  {
   if(sl <= 0.0)
      return false;

   double stop_level_pts = GetStopLevelPts();
   if(stop_level_pts <= 0.0)
      return true;

   double distance_pts = 0.0;
   if(order_type == OP_BUY)
      distance_pts = (reference_price - sl) / TradePoint();
   else
      distance_pts = (sl - reference_price) / TradePoint();

   return (distance_pts >= stop_level_pts);
  }

//+------------------------------------------------------------------+
bool IsTrailingImprovement(const int order_type, const double current_sl, const double new_sl)
  {
   if(new_sl <= 0.0)
      return false;

   double min_delta = PointsToPrice(1);

   if(order_type == OP_BUY)
     {
      if(current_sl <= 0.0)
         return true;
      return (new_sl > current_sl + min_delta);
     }

   if(current_sl <= 0.0)
      return true;

   return (new_sl < current_sl - min_delta);
  }

//+------------------------------------------------------------------+
bool SafeModifyStopLoss(const int ticket, const double desired_sl, const bool allow_restore)
  {
   if(desired_sl <= 0.0)
      return false;

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   int    order_type = OrderType();
   double open_price = OrderOpenPrice();
   double current_sl = OrderStopLoss();
   double tp         = OrderTakeProfit();

   double target_sl = ClampStopLossForBroker(order_type, desired_sl);
   if(target_sl <= 0.0)
      return false;

   if(!allow_restore)
     {
      if(!IsTrailingImprovement(order_type, current_sl, target_sl))
         return true;
     }
   else
     {
      if(current_sl > 0.0)
         return true;
     }

   if(!IsStopDistanceValid(order_type, (order_type == OP_BUY) ? TradeBid() : TradeAsk(), target_sl))
     {
      target_sl = BuildInitialSL(order_type, open_price);
      target_sl = ClampStopLossForBroker(order_type, target_sl);
     }

   if(target_sl <= 0.0)
      return false;

   for(int attempt = 0; attempt < 5; attempt++)
     {
      RefreshRates();
      target_sl = ClampStopLossForBroker(order_type, target_sl);
      if(target_sl <= 0.0)
         return false;

      if(OrderSelect(ticket, SELECT_BY_TICKET))
        {
         if(!allow_restore && !IsTrailingImprovement(order_type, OrderStopLoss(), target_sl))
            return true;
        }

      if(OrderModify(ticket, open_price, target_sl, tp, 0, clrNONE))
         return true;

      int err = GetLastError();
      Print("IDC_8: OrderModify retry ", attempt + 1,
            " ticket=", ticket, " sl=", target_sl, " err=", err);
      Sleep(200);
     }

   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      if(OrderStopLoss() <= 0.0)
         Print("IDC_8: CRITICAL - SL missing after failed modify. ticket=", ticket);
     }

   return false;
  }

//+------------------------------------------------------------------+
bool AttachMissingStopLoss(const int ticket)
  {
   if(InpStopLossPoints <= 0)
      return true;

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   if(OrderStopLoss() > 0.0)
      return true;

   double emergency_sl = BuildInitialSL(OrderType(), OrderOpenPrice());
   return SafeModifyStopLoss(ticket, emergency_sl, true);
  }

//+------------------------------------------------------------------+
void ProtectAllPositionsStopLoss()
  {
   if(InpStopLossPoints <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(!IsOurOrderTicket())
         continue;

      int order_type = OrderType();
      if(order_type != OP_BUY && order_type != OP_SELL)
         continue;

      if(OrderStopLoss() <= 0.0)
         AttachMissingStopLoss(OrderTicket());
     }
  }

//+------------------------------------------------------------------+
bool OpenPositionAtSetupClose(const int order_type)
  {
   g_entry_taken = true;

   RefreshRates();

   double setup_close = GetSetupClosePrice();
   double send_price  = (order_type == OP_BUY) ? TradeAsk() : TradeBid();

   if(!IsEntrySlippageAcceptable(order_type, setup_close))
     {
      Print("IDC_8: entry skipped. setup close=", setup_close,
            " market=", send_price, " max slippage pts=", InpSlippagePts);
      return false;
     }

   if(InpStopLossPoints <= 0)
     {
      Print("IDC_8: entry blocked. StopLossPoints must be > 0 for mandatory SL.");
      return false;
     }

   double sl = BuildInitialSL(order_type, setup_close);
   sl = ClampStopLossForBroker(order_type, sl);

   if(sl <= 0.0 || !IsStopDistanceValid(order_type, setup_close, sl))
     {
      Print("IDC_8: initial SL invalid after broker clamp. sl=", sl);
      return false;
     }

   color arrow = (order_type == OP_BUY) ? clrGreen : clrRed;
   int ticket  = -1;

   for(int attempt = 0; attempt < 5; attempt++)
     {
      RefreshRates();
      send_price = (order_type == OP_BUY) ? TradeAsk() : TradeBid();
      sl = ClampStopLossForBroker(order_type, BuildInitialSL(order_type, setup_close));

      ticket = OrderSend(TradeSymbol(), order_type, InpLots, send_price, InpSlippagePts,
                         sl, 0, InpTradeComment, InpMagicNumber, 0, arrow);
      if(ticket >= 0)
         break;

      Print("IDC_8: OrderSend retry ", attempt + 1, " err=", GetLastError());
      Sleep(200);
     }

   if(ticket < 0)
     {
      Print("IDC_8: OrderSend failed after retries. error=", GetLastError());
      return false;
     }

   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      if(OrderStopLoss() <= 0.0)
        {
         if(!AttachMissingStopLoss(ticket))
           {
            Print("IDC_8: CRITICAL - opened without SL, restore failed. ticket=", ticket);
            return false;
           }
        }
     }

   ResetSetupState();
   return true;
  }

//+------------------------------------------------------------------+
void TrySellEntryOnClosedBar()
  {
   if(g_cycle != CYCLE_SELL || g_entry_taken)
      return;
   if(IsObservationWindowExpired())
     {
      ResetSetupState();
      return;
     }
   if(g_setup_phase != PHASE_WAIT_EMA)
      return;
   if(g_grace_remaining <= 0)
     {
      ResetSetupState();
      return;
     }

   if(IsSellEmaConfirm(1))
     {
      OpenPositionAtSetupClose(OP_SELL);
      return;
     }

   g_grace_remaining--;
   if(g_grace_remaining <= 0)
      ResetSetupState();
  }

//+------------------------------------------------------------------+
void TryBuyEntryOnClosedBar()
  {
   if(g_cycle != CYCLE_BUY || g_entry_taken)
      return;
   if(IsObservationWindowExpired())
     {
      ResetSetupState();
      return;
     }
   if(g_setup_phase != PHASE_WAIT_EMA)
      return;
   if(g_grace_remaining <= 0)
     {
      ResetSetupState();
      return;
     }

   if(IsBuyEmaConfirm(1))
     {
      OpenPositionAtSetupClose(OP_BUY);
      return;
     }

   g_grace_remaining--;
   if(g_grace_remaining <= 0)
      ResetSetupState();
  }

//+------------------------------------------------------------------+
void ProcessSetupLogicOnNewBar()
  {
   if(g_cycle == CYCLE_NONE || g_entry_taken)
      return;

   if(IsObservationWindowExpired())
     {
      ResetSetupState();
      return;
     }

   if(g_cycle == CYCLE_SELL)
     {
      ProcessSellRsiOnClosedBar();
      TrySellEntryOnClosedBar();
     }
   else if(g_cycle == CYCLE_BUY)
     {
      ProcessBuyRsiOnClosedBar();
      TryBuyEntryOnClosedBar();
     }
  }

//+------------------------------------------------------------------+
void ProcessEntryLogicOnNewBar()
  {
   DetectEmaCrossOnClosedBar();

   if(HasOpenPosition())
      return;

   ProcessSetupLogicOnNewBar();
  }

//+------------------------------------------------------------------+
double CalcTrailingStopPrice(const int order_type,
                             const double open_price,
                             const double market_price)
  {
   if(InpTrailingStartPts <= 0)
      return 0.0;

   double profit_points = 0.0;

   if(order_type == OP_BUY)
      profit_points = (market_price - open_price) / TradePoint();
   else
      profit_points = (open_price - market_price) / TradePoint();

   if(profit_points < InpTrailingStartPts)
      return 0.0;

   int extra_steps = 0;
   if(InpTrailingStepPts > 0)
     {
      double beyond = profit_points - InpTrailingStartPts;
      extra_steps = (int)MathFloor(beyond / InpTrailingStepPts);
     }

   int locked_points = InpTrailingStartPts + extra_steps * InpTrailingStepPts;

   if(order_type == OP_BUY)
      return open_price + PointsToPrice(locked_points);

   return open_price - PointsToPrice(locked_points);
  }

//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   if(InpTrailingStartPts <= 0)
      return;

   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(!IsOurOrderTicket())
         continue;

      int order_type = OrderType();
      if(order_type != OP_BUY && order_type != OP_SELL)
         continue;

      int ticket = OrderTicket();

      if(OrderStopLoss() <= 0.0)
        {
         AttachMissingStopLoss(ticket);
         continue;
      }

      double open_price   = OrderOpenPrice();
      double current_sl   = OrderStopLoss();
      double market_price = (order_type == OP_BUY) ? TradeBid() : TradeAsk();

      double target_sl = CalcTrailingStopPrice(order_type, open_price, market_price);
      if(target_sl <= 0.0)
         continue;

      target_sl = ClampStopLossForBroker(order_type, target_sl);
      if(target_sl <= 0.0)
         continue;

      if(!IsTrailingImprovement(order_type, current_sl, target_sl))
         continue;

      SafeModifyStopLoss(ticket, target_sl, false);
     }
  }

//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   if(InpFastEmaPeriod < 1 || InpSlowEmaPeriod < 1)
     {
      Print("IDC_8: EMA periods must be >= 1");
      return false;
     }
   if(InpFastEmaPeriod >= InpSlowEmaPeriod)
     {
      Print("IDC_8: fast EMA period must be less than slow EMA period");
      return false;
     }
   if(InpRsiPeriod < 2)
     {
      Print("IDC_8: RSI period must be >= 2");
      return false;
     }
   if(InpRsiUpper <= InpRsiLower)
     {
      Print("IDC_8: RSI upper level must be greater than lower level");
      return false;
     }
   if(InpObservationBars < 1)
     {
      Print("IDC_8: observation window must be >= 1 bar");
      return false;
     }
   if(InpEmaGraceBars < 1)
     {
      Print("IDC_8: EMA grace bars must be >= 1");
      return false;
     }
   if(InpLots <= 0.0)
     {
      Print("IDC_8: lot size must be > 0");
      return false;
     }
   if(InpStopLossPoints <= 0)
     {
      Print("IDC_8: stop loss points must be > 0 (mandatory SL)");
      return false;
     }
   if(InpTrailingStartPts < 0)
     {
      Print("IDC_8: trailing start points must be >= 0");
      return false;
     }
   if(InpTrailingStepPts < 0)
     {
      Print("IDC_8: trailing step points must be >= 0");
      return false;
     }
   if(InpSlippagePts < 0)
     {
      Print("IDC_8: slippage points must be >= 0");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   UpdateBrokerTime();

   if(!DetectGoldSymbol())
      return INIT_FAILED;

   UpdateBrokerTime();

   Print("IDC_8 init | trade symbol=", g_trade_symbol,
         " | chart symbol=", Symbol(),
         " | broker time=", FormatBrokerTime(g_broker_time),
         " | offset=", BrokerOffsetLabel(),
         " | stop level pts=", DoubleToString(GetStopLevelPts(), 0),
         " | freeze level pts=", DoubleToString(GetFreezeLevelPts(), 0));

   g_last_bar_time = iTime(TradeSymbol(), Period(), 0);
   ResetCycleState();

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateBrokerTime();
   ProtectAllPositionsStopLoss();
   ManageTrailingStop();

   if(!IsNewBar())
      return;

   ProcessEntryLogicOnNewBar();
  }
//+------------------------------------------------------------------+
