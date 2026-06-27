//+------------------------------------------------------------------+
//| IDC_8.mq4 - GOLD M1 SYSTEM (MT4)                                 |
//| EMA cross + RSI cross + fast EMA candle confirmation             |
//+------------------------------------------------------------------+
#property copyright "IDC_8"
#property version   "2.00"
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

ENUM_CYCLE       g_cycle            = CYCLE_NONE;
ENUM_SETUP_PHASE g_setup_phase      = PHASE_IDLE;
datetime         g_cycle_start_time = 0;
bool             g_entry_taken      = false;

bool     g_rsi_armed       = false;
int      g_grace_remaining = 0;
datetime g_last_bar_time   = 0;

//+------------------------------------------------------------------+
double PointsToPrice(const int points)
  {
   return (double)points * Point;
  }

//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime bar_time = iTime(Symbol(), Period(), 0);
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
bool HasOpenPosition()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
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
   if(Bars < InpSlowEmaPeriod + shift + 2)
      return false;

   fast_ema = iMA(Symbol(), Period(), InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   return true;
  }

//+------------------------------------------------------------------+
bool GetEmaPair(const int shift, double &fast_ema, double &slow_ema)
  {
   if(Bars < InpSlowEmaPeriod + shift + 2)
      return false;

   fast_ema = iMA(Symbol(), Period(), InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   slow_ema = iMA(Symbol(), Period(), InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   return true;
  }

//+------------------------------------------------------------------+
bool GetRsiPair(const int shift, double &rsi_curr, double &rsi_prev)
  {
   if(Bars < InpRsiPeriod + shift + 3)
      return false;

   rsi_curr = iRSI(Symbol(), Period(), InpRsiPeriod, PRICE_CLOSE, shift);
   rsi_prev = iRSI(Symbol(), Period(), InpRsiPeriod, PRICE_CLOSE, shift + 1);
   return true;
  }

//+------------------------------------------------------------------+
bool IsBodyDominant(const int shift)
  {
   double open  = iOpen(Symbol(), Period(), shift);
   double close = iClose(Symbol(), Period(), shift);
   double high  = iHigh(Symbol(), Period(), shift);
   double low   = iLow(Symbol(), Period(), shift);

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

   double close = iClose(Symbol(), Period(), shift);
   double low   = iLow(Symbol(), Period(), shift);

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

   double close = iClose(Symbol(), Period(), shift);
   double high  = iHigh(Symbol(), Period(), shift);

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

   int start_shift = iBarShift(Symbol(), Period(), g_cycle_start_time, true);
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

   datetime cross_time = iTime(Symbol(), Period(), 1);

   bool dead_cross   = (fast_prev >= slow_prev) && (fast_curr < slow_curr);
   bool golden_cross = (fast_prev <= slow_prev) && (fast_curr > slow_curr);

   if(dead_cross)
      StartCycle(CYCLE_SELL, cross_time);
   else if(golden_cross)
      StartCycle(CYCLE_BUY, cross_time);
  }

//+------------------------------------------------------------------+
bool IsRsiCrossAbove(const double rsi_prev, const double rsi_curr, const double level)
  {
   return (rsi_prev <= level && rsi_curr > level);
  }

//+------------------------------------------------------------------+
bool IsRsiCrossBelow(const double rsi_prev, const double rsi_curr, const double level)
  {
   return (rsi_prev >= level && rsi_curr < level);
  }

//+------------------------------------------------------------------+
void ProcessSellRsiOnClosedBar()
  {
   double rsi_curr = 0.0, rsi_prev = 0.0;
   if(!GetRsiPair(1, rsi_curr, rsi_prev))
      return;

   if(g_setup_phase == PHASE_IDLE || g_setup_phase == PHASE_WAIT_RSI_ARM)
     {
      if(IsRsiCrossAbove(rsi_prev, rsi_curr, InpRsiUpper))
        {
         g_rsi_armed   = true;
         g_setup_phase = PHASE_WAIT_RSI_ARM;
        }
     }

   if(g_setup_phase == PHASE_WAIT_RSI_ARM && g_rsi_armed)
     {
      if(IsRsiCrossBelow(rsi_prev, rsi_curr, InpRsiLower))
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
   double rsi_curr = 0.0, rsi_prev = 0.0;
   if(!GetRsiPair(1, rsi_curr, rsi_prev))
      return;

   if(g_setup_phase == PHASE_IDLE || g_setup_phase == PHASE_WAIT_RSI_ARM)
     {
      if(IsRsiCrossBelow(rsi_prev, rsi_curr, InpRsiLower))
        {
         g_rsi_armed   = true;
         g_setup_phase = PHASE_WAIT_RSI_ARM;
        }
     }

   if(g_setup_phase == PHASE_WAIT_RSI_ARM && g_rsi_armed)
     {
      if(IsRsiCrossAbove(rsi_prev, rsi_curr, InpRsiUpper))
        {
         g_setup_phase     = PHASE_WAIT_EMA;
         g_grace_remaining = CalcGraceBarsForTrigger();
         if(g_grace_remaining <= 0)
            ResetSetupState();
        }
     }
  }

//+------------------------------------------------------------------+
double NormalizePrice(const double price)
  {
   return NormalizeDouble(price, Digits);
  }

//+------------------------------------------------------------------+
double GetSetupClosePrice()
  {
   return NormalizePrice(iClose(Symbol(), Period(), 1));
  }

//+------------------------------------------------------------------+
bool IsEntrySlippageAcceptable(const int order_type, const double setup_close)
  {
   RefreshRates();

   double market = (order_type == OP_BUY) ? Ask : Bid;
   double diff_pts = MathAbs(market - setup_close) / Point;

   return (diff_pts <= InpSlippagePts);
  }

//+------------------------------------------------------------------+
bool IsStopDistanceValid(const int order_type, const double entry_price, const double sl)
  {
   double stop_level_pts = MarketInfo(Symbol(), MODE_STOPLEVEL);
   if(stop_level_pts <= 0.0)
      return true;

   double distance_pts = 0.0;
   if(order_type == OP_BUY)
      distance_pts = (entry_price - sl) / Point;
   else
      distance_pts = (sl - entry_price) / Point;

   return (distance_pts >= stop_level_pts);
  }

//+------------------------------------------------------------------+
bool OpenPositionAtSetupClose(const int order_type)
  {
   g_entry_taken = true;

   RefreshRates();

   double setup_close = GetSetupClosePrice();
   double send_price  = (order_type == OP_BUY) ? Ask : Bid;

   if(!IsEntrySlippageAcceptable(order_type, setup_close))
     {
      Print("IDC_8: entry skipped. setup close=", setup_close,
            " market=", send_price, " max slippage pts=", InpSlippagePts);
      return false;
     }

   double sl = 0.0;
   if(InpStopLossPoints > 0)
     {
      if(order_type == OP_BUY)
         sl = setup_close - PointsToPrice(InpStopLossPoints);
      else
         sl = setup_close + PointsToPrice(InpStopLossPoints);

      sl = NormalizePrice(sl);

      if(!IsStopDistanceValid(order_type, setup_close, sl))
        {
         Print("IDC_8: SL distance below broker stop level. sl=", sl);
         return false;
        }
     }

   color arrow = (order_type == OP_BUY) ? clrGreen : clrRed;
   int ticket = OrderSend(Symbol(), order_type, InpLots, send_price, InpSlippagePts,
                          sl, 0, InpTradeComment, InpMagicNumber, 0, arrow);

   if(ticket < 0)
     {
      Print("IDC_8: OrderSend failed. error=", GetLastError());
      return false;
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
      profit_points = (market_price - open_price) / Point;
   else
      profit_points = (open_price - market_price) / Point;

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
bool ModifyOrderSL(const int ticket, const double new_sl)
  {
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   double sl = NormalizePrice(new_sl);
   double tp = OrderTakeProfit();
   int    order_type = OrderType();

   if(!IsStopDistanceValid(order_type, (order_type == OP_BUY) ? Bid : Ask, sl))
      return false;

   return OrderModify(ticket, OrderOpenPrice(), sl, tp, 0, clrNONE);
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
      if(OrderSymbol() != Symbol())
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      int order_type = OrderType();
      if(order_type != OP_BUY && order_type != OP_SELL)
         continue;

      double open_price   = OrderOpenPrice();
      double current_sl   = OrderStopLoss();
      double market_price = (order_type == OP_BUY) ? Bid : Ask;

      double target_sl = CalcTrailingStopPrice(order_type, open_price, market_price);
      if(target_sl <= 0.0)
         continue;

      double min_delta   = PointsToPrice(1);
      bool should_modify = false;

      if(order_type == OP_BUY)
         should_modify = (current_sl == 0.0) || (target_sl > current_sl + min_delta);
      else
         should_modify = (current_sl == 0.0) || (target_sl < current_sl - min_delta);

      if(should_modify)
        {
         if(!ModifyOrderSL(OrderTicket(), target_sl))
            Print("IDC_8: OrderModify failed. ticket=", OrderTicket(),
                  " error=", GetLastError());
        }
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
   if(InpStopLossPoints < 0)
     {
      Print("IDC_8: stop loss points must be >= 0");
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

   g_last_bar_time = iTime(Symbol(), Period(), 0);
   ResetCycleState();

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   ManageTrailingStop();

   if(!IsNewBar())
      return;

   ProcessEntryLogicOnNewBar();
  }
//+------------------------------------------------------------------+
