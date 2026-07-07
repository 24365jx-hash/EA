//+------------------------------------------------------------------+
//| IDC_A.mq4 - GOLD M1 SYSTEM (MT4)                                 |
//| 9EMA first breakout + candle shape + RSI confirmation            |
//+------------------------------------------------------------------+
#property copyright "IDC_A"
#property version   "1.01"
#property strict

enum ENUM_LOT_MODE
  {
   LOT_MANUAL         = 0,
   LOT_AUTO_BALANCE   = 1
  };

//--- Symbol / broker
input bool   InpAutoDetectGold = true;   // Auto-detect gold symbol
input string InpManualSymbol   = "";     // Manual symbol override (blank=auto)

//--- EMA
input int InpEmaPeriod = 9;              // Baseline EMA period

//--- RSI
input int    InpRsiPeriod = 14;
input double InpRsiUpper  = 52.0;        // BUY RSI level
input double InpRsiLower  = 48.0;        // SELL RSI level

//--- Lot sizing
input ENUM_LOT_MODE InpLotMode           = LOT_MANUAL;
input double        InpManualLots        = 0.01;   // Manual lot size
input double        InpAutoLotsPer10000   = 0.01;   // Auto: lots per 10,000 balance

//--- Risk / exit
input int InpStopLossPoints   = 500;       // SL distance from entry (points, mandatory)
input int InpTrailingStartPts = 200;       // Trailing start (points profit)
input int InpTrailingStepPts  = 10;        // Trailing step (points)

//--- Trade settings
input int    InpMagicNumber  = 80001;
input int    InpSlippagePts  = 30;        // OrderSend max deviation (points)
input string InpTradeComment = "IDC_A";

//--- Debug / display
input bool InpDebugBarLog   = false;     // Experts tab per-bar O/X log
input bool InpChartPanel      = true;      // Chart left dashboard
input int  InpPanelFontSize   = 13;        // Dashboard font size (8-16)

string   g_trade_symbol      = "";
int      g_broker_gmt_offset = 0;
datetime g_broker_time       = 0;
datetime g_last_bar_time     = 0;

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
string TimeframeLabel()
  {
   switch(Period())
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return IntegerToString(Period());
     }
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
         Print("IDC_A: manual symbol not tradable gold: ", InpManualSymbol);
         return false;
        }
      g_trade_symbol = best_sym;
      return true;
     }

   if(!InpAutoDetectGold)
     {
      if(!TrySetTradeSymbol(Symbol(), best_sym, best_rank))
        {
         Print("IDC_A: chart symbol is not tradable gold: ", Symbol());
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
      Print("IDC_A: no tradable gold symbol detected.");
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
bool GetEma(const int shift, double &ema)
  {
   if(iBars(TradeSymbol(), Period()) < InpEmaPeriod + shift + 2)
      return false;

   ema = iMA(TradeSymbol(), Period(), InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   return true;
  }

//+------------------------------------------------------------------+
bool GetRsiPair(const int shift, double &rsi_curr, double &rsi_prev)
  {
   if(iBars(TradeSymbol(), Period()) < InpRsiPeriod + shift + 3)
      return false;

   rsi_curr = iRSI(TradeSymbol(), Period(), InpRsiPeriod, PRICE_CLOSE, shift);
   rsi_prev = iRSI(TradeSymbol(), Period(), InpRsiPeriod, PRICE_CLOSE, shift + 1);
   return true;
  }

//+------------------------------------------------------------------+
bool IsRsiBreakoutAbove(const double rsi_prev, const double rsi_curr, const double level)
  {
   return (rsi_prev <= level && rsi_curr > level);
  }

//+------------------------------------------------------------------+
bool IsRsiBreakoutBelow(const double rsi_prev, const double rsi_curr, const double level)
  {
   return (rsi_prev >= level && rsi_curr < level);
  }

//+------------------------------------------------------------------+
void GetCandleWicks(const int shift,
                    double &body,
                    double &upper_wick,
                    double &lower_wick,
                    bool   &is_bearish,
                    bool   &is_bullish)
  {
   double open  = iOpen(TradeSymbol(), Period(), shift);
   double close = iClose(TradeSymbol(), Period(), shift);
   double high  = iHigh(TradeSymbol(), Period(), shift);
   double low   = iLow(TradeSymbol(), Period(), shift);

   body       = MathAbs(close - open);
   upper_wick = high - MathMax(open, close);
   lower_wick = MathMin(open, close) - low;
   is_bearish = (close < open);
   is_bullish = (close > open);
  }

//+------------------------------------------------------------------+
bool IsBodyDominant(const int shift)
  {
   double body = 0.0, upper_wick = 0.0, lower_wick = 0.0;
   bool   bear = false, bull = false;
   GetCandleWicks(shift, body, upper_wick, lower_wick, bear, bull);
   return (body > upper_wick + lower_wick);
  }

//+------------------------------------------------------------------+
bool IsSellWickShape(const int shift)
  {
   double body = 0.0, upper_wick = 0.0, lower_wick = 0.0;
   bool   bear = false, bull = false;
   GetCandleWicks(shift, body, upper_wick, lower_wick, bear, bull);
   return (lower_wick < upper_wick);
  }

//+------------------------------------------------------------------+
bool IsBuyWickShape(const int shift)
  {
   double body = 0.0, upper_wick = 0.0, lower_wick = 0.0;
   bool   bear = false, bull = false;
   GetCandleWicks(shift, body, upper_wick, lower_wick, bear, bull);
   return (upper_wick < lower_wick);
  }

//+------------------------------------------------------------------+
bool IsPrevCloseAboveEma(const int setup_shift)
  {
   double ema = 0.0;
   if(!GetEma(setup_shift + 1, ema))
      return false;

   double prev_close = iClose(TradeSymbol(), Period(), setup_shift + 1);
   return (prev_close > ema);
  }

//+------------------------------------------------------------------+
bool IsPrevCloseBelowEma(const int setup_shift)
  {
   double ema = 0.0;
   if(!GetEma(setup_shift + 1, ema))
      return false;

   double prev_close = iClose(TradeSymbol(), Period(), setup_shift + 1);
   return (prev_close < ema);
  }

//+------------------------------------------------------------------+
bool IsSetupCloseBelowEma(const int setup_shift)
  {
   double ema = 0.0;
   if(!GetEma(setup_shift, ema))
      return false;

   double setup_close = iClose(TradeSymbol(), Period(), setup_shift);
   return (setup_close < ema);
  }

//+------------------------------------------------------------------+
bool IsSetupCloseAboveEma(const int setup_shift)
  {
   double ema = 0.0;
   if(!GetEma(setup_shift, ema))
      return false;

   double setup_close = iClose(TradeSymbol(), Period(), setup_shift);
   return (setup_close > ema);
  }

//+------------------------------------------------------------------+
bool IsSellEmaFirstBreakout(const int setup_shift)
  {
   return (IsPrevCloseAboveEma(setup_shift) && IsSetupCloseBelowEma(setup_shift));
  }

//+------------------------------------------------------------------+
bool IsBuyEmaFirstBreakout(const int setup_shift)
  {
   return (IsPrevCloseBelowEma(setup_shift) && IsSetupCloseAboveEma(setup_shift));
  }

//+------------------------------------------------------------------+
bool IsSellRsiOk(const double rsi_prev, const double rsi_curr)
  {
   if(IsRsiBreakoutBelow(rsi_prev, rsi_curr, InpRsiLower))
      return true;
   return (rsi_curr <= InpRsiLower);
  }

//+------------------------------------------------------------------+
bool IsBuyRsiOk(const double rsi_prev, const double rsi_curr)
  {
   if(IsRsiBreakoutAbove(rsi_prev, rsi_curr, InpRsiUpper))
      return true;
   return (rsi_curr >= InpRsiUpper);
  }

//+------------------------------------------------------------------+
bool IsBearishCandle(const int shift)
  {
   double open  = iOpen(TradeSymbol(), Period(), shift);
   double close = iClose(TradeSymbol(), Period(), shift);
   return (close < open);
  }

//+------------------------------------------------------------------+
bool IsBullishCandle(const int shift)
  {
   double open  = iOpen(TradeSymbol(), Period(), shift);
   double close = iClose(TradeSymbol(), Period(), shift);
   return (close > open);
  }

//+------------------------------------------------------------------+
bool EvaluateSellSetup(const int setup_shift,
                       bool &ema_first_break,
                       bool &body_ok,
                       bool &wick_ok,
                       bool &color_ok,
                       bool &rsi_ok,
                       bool &all_ok)
  {
   ema_first_break = IsSellEmaFirstBreakout(setup_shift);
   body_ok         = IsBodyDominant(setup_shift);
   wick_ok         = IsSellWickShape(setup_shift);
   color_ok        = IsBearishCandle(setup_shift);

   double rsi_curr = 0.0, rsi_prev = 0.0;
   rsi_ok = false;
   if(GetRsiPair(setup_shift, rsi_curr, rsi_prev))
      rsi_ok = IsSellRsiOk(rsi_prev, rsi_curr);

   all_ok = (ema_first_break && body_ok && wick_ok && color_ok && rsi_ok);
   return all_ok;
  }

//+------------------------------------------------------------------+
bool EvaluateBuySetup(const int setup_shift,
                      bool &ema_first_break,
                      bool &body_ok,
                      bool &wick_ok,
                      bool &color_ok,
                      bool &rsi_ok,
                      bool &all_ok)
  {
   ema_first_break = IsBuyEmaFirstBreakout(setup_shift);
   body_ok         = IsBodyDominant(setup_shift);
   wick_ok         = IsBuyWickShape(setup_shift);
   color_ok        = IsBullishCandle(setup_shift);

   double rsi_curr = 0.0, rsi_prev = 0.0;
   rsi_ok = false;
   if(GetRsiPair(setup_shift, rsi_curr, rsi_prev))
      rsi_ok = IsBuyRsiOk(rsi_prev, rsi_curr);

   all_ok = (ema_first_break && body_ok && wick_ok && color_ok && rsi_ok);
   return all_ok;
  }

//+------------------------------------------------------------------+
double NormalizeLots(const double lots)
  {
   double min_lot  = MarketInfo(TradeSymbol(), MODE_MINLOT);
   double max_lot  = MarketInfo(TradeSymbol(), MODE_MAXLOT);
   double lot_step = MarketInfo(TradeSymbol(), MODE_LOTSTEP);

   if(min_lot <= 0.0)
      min_lot = 0.01;
   if(max_lot <= 0.0)
      max_lot = 100.0;
   if(lot_step <= 0.0)
      lot_step = 0.01;

   double normalized = lots;
   normalized = MathFloor(normalized / lot_step + 0.0000001) * lot_step;
   normalized = NormalizeDouble(normalized, 2);

   if(normalized < min_lot)
      normalized = min_lot;
   if(normalized > max_lot)
      normalized = max_lot;

   return normalized;
  }

//+------------------------------------------------------------------+
double CalcTradeLots()
  {
   double lots = InpManualLots;

   if(InpLotMode == LOT_AUTO_BALANCE)
     {
      double balance = AccountBalance();
      if(balance > 0.0 && InpAutoLotsPer10000 > 0.0)
         lots = balance / 10000.0 * InpAutoLotsPer10000;
     }

   return NormalizeLots(lots);
  }

//+------------------------------------------------------------------+
double GetSetupClosePrice()
  {
   return NormalizeTradePrice(iClose(TradeSymbol(), Period(), 1));
  }

//+------------------------------------------------------------------+
double BuildInitialSL(const int order_type, const double entry_price)
  {
   if(InpStopLossPoints <= 0)
      return 0.0;

   if(order_type == OP_BUY)
      return NormalizeTradePrice(entry_price - PointsToPrice(InpStopLossPoints));

   return NormalizeTradePrice(entry_price + PointsToPrice(InpStopLossPoints));
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
      Print("IDC_A: OrderModify retry ", attempt + 1,
            " ticket=", ticket, " sl=", target_sl, " err=", err);
      Sleep(200);
     }

   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      if(OrderStopLoss() <= 0.0)
         Print("IDC_A: CRITICAL - SL missing after failed modify. ticket=", ticket);
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
   RefreshRates();

   double setup_close = GetSetupClosePrice();
   double send_price  = (order_type == OP_BUY) ? TradeAsk() : TradeBid();
   double lots        = CalcTradeLots();

   if(lots <= 0.0)
     {
      Print("IDC_A: invalid lot size.");
      return false;
     }

   if(InpStopLossPoints <= 0)
     {
      Print("IDC_A: entry blocked. StopLossPoints must be > 0 for mandatory SL.");
      return false;
     }

   double sl = BuildInitialSL(order_type, send_price);
   sl = ClampStopLossForBroker(order_type, sl);

   if(sl <= 0.0 || !IsStopDistanceValid(order_type, send_price, sl))
     {
      Print("IDC_A: initial SL invalid after broker clamp. sl=", sl);
      return false;
     }

   color arrow = (order_type == OP_BUY) ? clrGreen : clrRed;
   int ticket  = -1;

   for(int attempt = 0; attempt < 5; attempt++)
     {
      RefreshRates();
      send_price = (order_type == OP_BUY) ? TradeAsk() : TradeBid();
      sl = ClampStopLossForBroker(order_type, BuildInitialSL(order_type, send_price));

      ticket = OrderSend(TradeSymbol(), order_type, lots, send_price, InpSlippagePts,
                         sl, 0, InpTradeComment, InpMagicNumber, 0, arrow);
      if(ticket >= 0)
         break;

      Print("IDC_A: OrderSend retry ", attempt + 1, " err=", GetLastError());
      Sleep(200);
     }

   if(ticket < 0)
     {
      Print("IDC_A: OrderSend failed after retries. error=", GetLastError());
      return false;
     }

   Print("IDC_A: ", (order_type == OP_BUY ? "BUY" : "SELL"),
         " entry ticket=", ticket,
         " lots=", DoubleToString(lots, 2),
         " setup_close=", setup_close,
         " fill=", send_price,
         " sl=", sl);

   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      if(OrderStopLoss() <= 0.0)
        {
         if(!AttachMissingStopLoss(ticket))
            Print("IDC_A: CRITICAL - opened without SL, restore failed. ticket=", ticket);
        }
     }

   return true;
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
      double market_price = (order_type == OP_BUY) ? TradeBid() : TradeAsk();
      double target_sl    = CalcTrailingStopPrice(order_type, open_price, market_price);

      if(target_sl <= 0.0)
         continue;

      target_sl = ClampStopLossForBroker(order_type, target_sl);
      if(target_sl <= 0.0)
         continue;

      if(!IsTrailingImprovement(order_type, OrderStopLoss(), target_sl))
         continue;

      SafeModifyStopLoss(ticket, target_sl, false);
     }
  }

//+------------------------------------------------------------------+
string Ox(const bool ok)
  {
   return ok ? "O" : "X";
  }

//+------------------------------------------------------------------+
string PanelMark(const bool ok)
  {
   return ok ? "[O]" : "[X]";
  }

//+------------------------------------------------------------------+
color PanelResultColor(const bool ok)
  {
   return ok ? clrLime : clrTomato;
  }

//+------------------------------------------------------------------+
string LotModeLabel()
  {
   if(InpLotMode == LOT_AUTO_BALANCE)
      return "AUTO";
   return "MANUAL";
  }

//+------------------------------------------------------------------+
void ClearChartDashboard()
  {
   Comment("");

   for(int i = ObjectsTotal() - 1; i >= 0; i--)
     {
      string name = ObjectName(i);
      if(StringFind(name, "IDCA_pnl_") == 0)
         ObjectDelete(name);
     }
  }

//+------------------------------------------------------------------+
bool SetDashboardLine(const int line_idx, const string text, const color clr)
  {
   string name = "IDCA_pnl_" + IntegerToString(line_idx);

   if(ObjectFind(name) < 0)
     {
      if(!ObjectCreate(name, OBJ_LABEL, 0, 0, 0))
         return false;
      ObjectSet(name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSet(name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSet(name, OBJPROP_SELECTABLE, false);
      ObjectSet(name, OBJPROP_HIDDEN, true);
     }

   ObjectSetText(name, text, InpPanelFontSize, "Arial Bold", clr);
   ObjectSet(name, OBJPROP_XDISTANCE, 12);
   ObjectSet(name, OBJPROP_YDISTANCE, 16 + line_idx * (InpPanelFontSize + 6));
   return true;
  }

//+------------------------------------------------------------------+
void SetDashboardBackground(const int line_count)
  {
   string name = "IDCA_pnl_bg";
   int      h    = (InpPanelFontSize + 6) * line_count + 14;
   int      w    = 520;

   if(ObjectFind(name) < 0)
     {
      ObjectCreate(name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSet(name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSet(name, OBJPROP_SELECTABLE, false);
      ObjectSet(name, OBJPROP_HIDDEN, true);
      ObjectSet(name, OBJPROP_BACK, false);
     }

   ObjectSet(name, OBJPROP_XDISTANCE, 6);
   ObjectSet(name, OBJPROP_YDISTANCE, 8);
   ObjectSet(name, OBJPROP_XSIZE, w);
   ObjectSet(name, OBJPROP_YSIZE, h);
   ObjectSet(name, OBJPROP_BGCOLOR, C'16,18,28');
   ObjectSet(name, OBJPROP_COLOR, C'70,80,110');
   ObjectSet(name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSet(name, OBJPROP_WIDTH, 2);
  }

//+------------------------------------------------------------------+
void RenderChartDashboard(const datetime bar_time,
                          const double rsi_curr,
                          const bool rsi_data,
                          const bool sell_prev_above,
                          const bool sell_setup_below,
                          const bool sell_body,
                          const bool sell_wick,
                          const bool sell_color,
                          const bool sell_rsi,
                          const bool sell_all,
                          const bool buy_prev_below,
                          const bool buy_setup_above,
                          const bool buy_body,
                          const bool buy_wick,
                          const bool buy_color,
                          const bool buy_rsi,
                          const bool buy_all,
                          const bool has_pos)
  {
   const int PNL_LINE_COUNT = 21;

   ClearChartDashboard();
   SetDashboardBackground(PNL_LINE_COUNT);

   int line = 0;
   SetDashboardLine(line++,
                    "IDC_A v1.01  " + TradeSymbol() + " " + TimeframeLabel(),
                    clrGold);
   SetDashboardLine(line++,
                    "브로커 " + FormatBrokerTime(g_broker_time) + "  " + BrokerOffsetLabel(),
                    clrSilver);
   SetDashboardLine(line++,
                    "봉 " + TimeToString(bar_time, TIME_DATE | TIME_MINUTES),
                    clrWhite);
   SetDashboardLine(line++,
                    StringFormat("사이클:%s  랏:%s %.2f  SL:%dpt",
                                 has_pos ? "진행중" : "대기",
                                 LotModeLabel(), CalcTradeLots(), InpStopLossPoints),
                    clrAqua);
   SetDashboardLine(line++,
                    StringFormat("설정 EMA:%d  RSI:%.0f/%.0f  Trail:%d/%d",
                                 InpEmaPeriod, InpRsiUpper, InpRsiLower,
                                 InpTrailingStartPts, InpTrailingStepPts),
                    clrSilver);
   SetDashboardLine(line++, "========================================", clrDimGray);

   string rsi_val = rsi_data ? DoubleToString(rsi_curr, 1) : "N/A";

   SetDashboardLine(line++,
                    StringFormat("SELL 1 직전봉>EMA %s", PanelMark(sell_prev_above)),
                    PanelResultColor(sell_prev_above));
   SetDashboardLine(line++,
                    StringFormat("SELL 2 셋업<EMA %s", PanelMark(sell_setup_below)),
                    PanelResultColor(sell_setup_below));
   SetDashboardLine(line++,
                    StringFormat("SELL 3 몸통>꼬리 %s", PanelMark(sell_body)),
                    PanelResultColor(sell_body));
   SetDashboardLine(line++,
                    StringFormat("SELL 4 아랫<윗꼬리 %s", PanelMark(sell_wick)),
                    PanelResultColor(sell_wick));
   SetDashboardLine(line++,
                    StringFormat("SELL 5 음봉 %s", PanelMark(sell_color)),
                    PanelResultColor(sell_color));
   SetDashboardLine(line++,
                    StringFormat("SELL 6 RSI%.0f↓/이하 %s  RSI=%s",
                                 InpRsiLower, PanelMark(sell_rsi), rsi_val),
                    PanelResultColor(sell_rsi));

   SetDashboardLine(line++, "----------------------------------------", clrDimGray);

   SetDashboardLine(line++,
                    StringFormat("BUY 1 직전봉<EMA %s", PanelMark(buy_prev_below)),
                    PanelResultColor(buy_prev_below));
   SetDashboardLine(line++,
                    StringFormat("BUY 2 셋업>EMA %s", PanelMark(buy_setup_above)),
                    PanelResultColor(buy_setup_above));
   SetDashboardLine(line++,
                    StringFormat("BUY 3 몸통>꼬리 %s", PanelMark(buy_body)),
                    PanelResultColor(buy_body));
   SetDashboardLine(line++,
                    StringFormat("BUY 4 윗<아랫꼬리 %s", PanelMark(buy_wick)),
                    PanelResultColor(buy_wick));
   SetDashboardLine(line++,
                    StringFormat("BUY 5 양봉 %s", PanelMark(buy_color)),
                    PanelResultColor(buy_color));
   SetDashboardLine(line++,
                    StringFormat("BUY 6 RSI%.0f↑/이상 %s  RSI=%s",
                                 InpRsiUpper, PanelMark(buy_rsi), rsi_val),
                    PanelResultColor(buy_rsi));

   SetDashboardLine(line++, "========================================", clrDimGray);

   if(has_pos)
      SetDashboardLine(line++, "포지션 보유중 - 신규진입 없음", clrOrange);
   else
      SetDashboardLine(line++,
                       StringFormat(">>> SELL %s  BUY %s <<<",
                                    PanelMark(sell_all), PanelMark(buy_all)),
                       PanelResultColor(sell_all || buy_all));

   ChartRedraw();
  }

//+------------------------------------------------------------------+
void UpdateBarConditionDisplay()
  {
   if(!InpDebugBarLog && !InpChartPanel)
      return;

   datetime bar_time = iTime(TradeSymbol(), Period(), 1);
   if(bar_time == 0)
      return;

   bool s_ema = false, s_body = false, s_wick = false, s_color = false, s_rsi = false, s_all = false;
   bool b_ema = false, b_body = false, b_wick = false, b_color = false, b_rsi = false, b_all = false;

   EvaluateSellSetup(1, s_ema, s_body, s_wick, s_color, s_rsi, s_all);
   EvaluateBuySetup(1, b_ema, b_body, b_wick, b_color, b_rsi, b_all);

   bool s_prev_above  = IsPrevCloseAboveEma(1);
   bool s_setup_below = IsSetupCloseBelowEma(1);
   bool b_prev_below  = IsPrevCloseBelowEma(1);
   bool b_setup_above = IsSetupCloseAboveEma(1);

   double rsi_curr = 0.0, rsi_prev = 0.0;
   bool   rsi_data = GetRsiPair(1, rsi_curr, rsi_prev);
   bool   has_pos  = HasOpenPosition();

   if(InpDebugBarLog)
     {
      static datetime s_last_debug_bar = 0;
      if(bar_time != 0 && bar_time != s_last_debug_bar)
        {
         s_last_debug_bar = bar_time;
         Print("IDC_A|BAR|", TimeToString(bar_time, TIME_DATE | TIME_MINUTES),
               "|SELL=", Ox(s_all),
               "|EMA=", Ox(s_ema), "|BODY=", Ox(s_body), "|WICK=", Ox(s_wick),
               "|COLOR=", Ox(s_color), "|RSI=", Ox(s_rsi),
               "|BUY=", Ox(b_all),
               "|POS=", Ox(has_pos));
        }
     }

   if(!InpChartPanel)
     {
      ClearChartDashboard();
      return;
     }

   RenderChartDashboard(bar_time, rsi_curr, rsi_data,
                        s_prev_above, s_setup_below, s_body, s_wick, s_color, s_rsi, s_all,
                        b_prev_below, b_setup_above, b_body, b_wick, b_color, b_rsi, b_all,
                        has_pos);
  }

//+------------------------------------------------------------------+
void ProcessClosedBarEntry()
  {
   const int SETUP_SHIFT = 1;

   if(HasOpenPosition())
      return;

   bool s_ema = false, s_body = false, s_wick = false, s_color = false, s_rsi = false, s_all = false;
   bool b_ema = false, b_body = false, b_wick = false, b_color = false, b_rsi = false, b_all = false;

   EvaluateSellSetup(SETUP_SHIFT, s_ema, s_body, s_wick, s_color, s_rsi, s_all);
   EvaluateBuySetup(SETUP_SHIFT, b_ema, b_body, b_wick, b_color, b_rsi, b_all);

   if(s_all && b_all)
     {
      Print("IDC_A: both SELL and BUY on same bar - SELL priority.");
      OpenPositionAtSetupClose(OP_SELL);
      return;
     }

   if(s_all)
      OpenPositionAtSetupClose(OP_SELL);
   else if(b_all)
      OpenPositionAtSetupClose(OP_BUY);
  }

//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   if(InpEmaPeriod < 1)
     {
      Print("IDC_A: EMA period must be >= 1");
      return false;
     }
   if(InpRsiPeriod < 2)
     {
      Print("IDC_A: RSI period must be >= 2");
      return false;
     }
   if(InpRsiUpper <= InpRsiLower)
     {
      Print("IDC_A: RSI upper level must be greater than lower level");
      return false;
     }
   if(InpManualLots <= 0.0)
     {
      Print("IDC_A: manual lot size must be > 0");
      return false;
     }
   if(InpAutoLotsPer10000 <= 0.0)
     {
      Print("IDC_A: auto lots per 10000 must be > 0");
      return false;
     }
   if(InpStopLossPoints <= 0)
     {
      Print("IDC_A: stop loss points must be > 0 (mandatory SL)");
      return false;
     }
   if(InpTrailingStartPts < 0)
     {
      Print("IDC_A: trailing start points must be >= 0");
      return false;
     }
   if(InpTrailingStepPts < 0)
     {
      Print("IDC_A: trailing step points must be >= 0");
      return false;
     }
   if(InpSlippagePts < 0)
     {
      Print("IDC_A: slippage points must be >= 0");
      return false;
     }
   if(InpPanelFontSize < 8 || InpPanelFontSize > 16)
     {
      Print("IDC_A: panel font size must be 8-16");
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

   if(Period() != PERIOD_M1)
      Print("IDC_A: WARNING - strategy designed for M1. current TF=", TimeframeLabel());

   Print("IDC_A init v1.01 | trade symbol=", g_trade_symbol,
         " | chart symbol=", Symbol(),
         " | timeframe=", TimeframeLabel(),
         " | broker time=", FormatBrokerTime(g_broker_time),
         " | offset=", BrokerOffsetLabel(),
         " | lot mode=", LotModeLabel(),
         " | stop level pts=", DoubleToString(GetStopLevelPts(), 0),
         " | freeze level pts=", DoubleToString(GetFreezeLevelPts(), 0));

   g_last_bar_time = iTime(TradeSymbol(), Period(), 0);
   UpdateBarConditionDisplay();

   if(!InpChartPanel)
      ClearChartDashboard();

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ClearChartDashboard();
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateBrokerTime();
   ProtectAllPositionsStopLoss();
   ManageTrailingStop();

   if(InpChartPanel || InpDebugBarLog)
      UpdateBarConditionDisplay();

   if(!IsNewBar())
      return;

   ProcessClosedBarEntry();
  }
//+------------------------------------------------------------------+
