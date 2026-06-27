//+------------------------------------------------------------------+
//| IDC_8.mq5 - GOLD M1 SYSTEM                                       |
//| EMA cross + RSI pullback + 9EMA candle confirmation              |
//+------------------------------------------------------------------+
#property copyright "IDC_8"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- trade direction cycle
enum ENUM_CYCLE
  {
   CYCLE_NONE = 0,
   CYCLE_BUY  = 1,
   CYCLE_SELL = 2
  };

//--- setup phase within a cycle
enum ENUM_SETUP_PHASE
  {
   PHASE_IDLE          = 0,
   PHASE_WAIT_RSI_ARM  = 1,
   PHASE_WAIT_EMA      = 2
  };

//+------------------------------------------------------------------+
//| Inputs (all numeric values in points where applicable)           |
//+------------------------------------------------------------------+
input group "=== EMA ==="
input int InpFastEmaPeriod   = 9;
input int InpSlowEmaPeriod   = 50;

input group "=== RSI ==="
input int    InpRsiPeriod    = 14;
input double InpRsiUpper     = 52.0;
input double InpRsiLower     = 48.0;

input group "=== Entry Rules ==="
input int InpObservationBars = 30;
input int InpEmaGraceBars    = 3;

input group "=== Risk / Exit ==="
input double InpLots              = 0.01;
input int    InpStopLossPoints    = 500;
input int    InpTrailingStartPts  = 200;
input int    InpTrailingStepPts   = 10;

input group "=== Trade Settings ==="
input ulong  InpMagicNumber = 80008;
input int    InpSlippagePts = 30;
input string InpTradeComment = "IDC_8";

//+------------------------------------------------------------------+
CTrade   g_trade;
int      g_handle_fast_ema = INVALID_HANDLE;
int      g_handle_slow_ema = INVALID_HANDLE;
int      g_handle_rsi      = INVALID_HANDLE;

ENUM_CYCLE      g_cycle           = CYCLE_NONE;
ENUM_SETUP_PHASE g_setup_phase    = PHASE_IDLE;
datetime        g_cycle_start_time = 0;
bool            g_entry_taken     = false;

bool     g_rsi_armed       = false;
int      g_grace_remaining = 0;

datetime g_last_bar_time   = 0;

//+------------------------------------------------------------------+
double PointsToPrice(const int points)
  {
   return (double)points * _Point;
  }

//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
void ResetSetupState()
  {
   g_setup_phase    = PHASE_IDLE;
   g_rsi_armed      = false;
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
bool CopyIndicatorValue(const int handle, const int shift, double &value)
  {
   double buffer[1];
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
      return false;
   value = buffer[0];
   return true;
  }

//+------------------------------------------------------------------+
bool GetEmaValues(const int shift, double &fast, double &slow)
  {
   if(!CopyIndicatorValue(g_handle_fast_ema, shift, fast))
      return false;
   if(!CopyIndicatorValue(g_handle_slow_ema, shift, slow))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
bool GetRsiValue(const int shift, double &rsi)
  {
   return CopyIndicatorValue(g_handle_rsi, shift, rsi);
  }

//+------------------------------------------------------------------+
bool IsBearishBodyDominant(const int shift)
  {
   double open  = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   double high  = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double low   = iLow(_Symbol, PERIOD_CURRENT, shift);

   double body       = MathAbs(close - open);
   double upper_wick = high - MathMax(open, close);
   double lower_wick = MathMin(open, close) - low;

   return (body > upper_wick + lower_wick);
  }

//+------------------------------------------------------------------+
bool IsBullishBodyDominant(const int shift)
  {
   return IsBearishBodyDominant(shift);
  }

//+------------------------------------------------------------------+
bool IsSellEmaConfirm(const int shift)
  {
   double fast_ema = 0.0;
   double slow_ema = 0.0;
   if(!GetEmaValues(shift, fast_ema, slow_ema))
      return false;

   double open  = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   double low   = iLow(_Symbol, PERIOD_CURRENT, shift);

   if(close >= fast_ema)
      return false;
   if(low >= fast_ema)
      return false;
   if(!IsBearishBodyDominant(shift))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
bool IsBuyEmaConfirm(const int shift)
  {
   double fast_ema = 0.0;
   double slow_ema = 0.0;
   if(!GetEmaValues(shift, fast_ema, slow_ema))
      return false;

   double open  = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   double high  = iHigh(_Symbol, PERIOD_CURRENT, shift);

   if(close <= fast_ema)
      return false;
   if(high <= fast_ema)
      return false;
   if(!IsBullishBodyDominant(shift))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
int BarsSinceCycleStart()
  {
   if(g_cycle_start_time == 0)
      return INT_MAX;

   int start_shift = iBarShift(_Symbol, PERIOD_CURRENT, g_cycle_start_time, true);
   if(start_shift < 0)
      return INT_MAX;

   return start_shift;
  }

//+------------------------------------------------------------------+
bool IsObservationWindowExpired()
  {
   return (BarsSinceCycleStart() > InpObservationBars);
  }

//+------------------------------------------------------------------+
void DetectEmaCrossOnClosedBar()
  {
   double fast_curr = 0.0, slow_curr = 0.0;
   double fast_prev = 0.0, slow_prev = 0.0;

   if(!GetEmaValues(1, fast_curr, slow_curr))
      return;
   if(!GetEmaValues(2, fast_prev, slow_prev))
      return;

   const datetime cross_time = iTime(_Symbol, PERIOD_CURRENT, 1);

   const bool dead_cross =
      (fast_prev >= slow_prev) && (fast_curr < slow_curr);

   const bool golden_cross =
      (fast_prev <= slow_prev) && (fast_curr > slow_curr);

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
      if(rsi > InpRsiUpper)
        {
         g_rsi_armed    = true;
         g_setup_phase  = PHASE_WAIT_RSI_ARM;
        }
     }

   if(g_setup_phase == PHASE_WAIT_RSI_ARM && g_rsi_armed)
     {
      if(rsi < InpRsiLower)
        {
         g_setup_phase     = PHASE_WAIT_EMA;
         g_grace_remaining = InpEmaGraceBars;
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
      if(rsi < InpRsiLower)
        {
         g_rsi_armed    = true;
         g_setup_phase  = PHASE_WAIT_RSI_ARM;
        }
     }

   if(g_setup_phase == PHASE_WAIT_RSI_ARM && g_rsi_armed)
     {
      if(rsi > InpRsiUpper)
        {
         g_setup_phase     = PHASE_WAIT_EMA;
         g_grace_remaining = InpEmaGraceBars;
        }
     }
  }

//+------------------------------------------------------------------+
bool OpenPosition(const ENUM_ORDER_TYPE order_type)
  {
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippagePts);

   const double price = (order_type == ORDER_TYPE_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl = 0.0;
   if(InpStopLossPoints > 0)
     {
      if(order_type == ORDER_TYPE_BUY)
         sl = price - PointsToPrice(InpStopLossPoints);
      else
         sl = price + PointsToPrice(InpStopLossPoints);

      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      sl = NormalizeDouble(sl, digits);
     }

   bool result = false;
   if(order_type == ORDER_TYPE_BUY)
      result = g_trade.Buy(InpLots, _Symbol, 0.0, sl, 0.0, InpTradeComment);
   else
      result = g_trade.Sell(InpLots, _Symbol, 0.0, sl, 0.0, InpTradeComment);

   if(!result)
     {
      Print("IDC_8: order failed. retcode=", g_trade.ResultRetcode(),
            " desc=", g_trade.ResultRetcodeDescription());
      return false;
     }

   g_entry_taken = true;
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

   if(IsSellEmaConfirm(1))
     {
      OpenPosition(ORDER_TYPE_SELL);
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

   if(IsBuyEmaConfirm(1))
     {
      OpenPosition(ORDER_TYPE_BUY);
      return;
     }

   g_grace_remaining--;
   if(g_grace_remaining <= 0)
      ResetSetupState();
  }

//+------------------------------------------------------------------+
void ProcessEntryLogicOnNewBar()
  {
   if(HasOpenPosition())
      return;

   DetectEmaCrossOnClosedBar();

   if(g_cycle == CYCLE_NONE)
      return;

   if(g_entry_taken)
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
double CalcTrailingStopPrice(const ENUM_POSITION_TYPE pos_type,
                             const double open_price,
                             const double market_price)
  {
   if(InpTrailingStartPts <= 0)
      return 0.0;

   const double point = _Point;
   double profit_points = 0.0;

   if(pos_type == POSITION_TYPE_BUY)
      profit_points = (market_price - open_price) / point;
   else
      profit_points = (open_price - market_price) / point;

   if(profit_points < InpTrailingStartPts)
      return 0.0;

   int extra_steps = 0;
   if(InpTrailingStepPts > 0)
     {
      const double beyond = profit_points - InpTrailingStartPts;
      extra_steps = (int)MathFloor(beyond / InpTrailingStepPts);
     }

   const int locked_points = InpTrailingStartPts + extra_steps * InpTrailingStepPts;

   if(pos_type == POSITION_TYPE_BUY)
      return open_price + PointsToPrice(locked_points);

   return open_price - PointsToPrice(locked_points);
  }

//+------------------------------------------------------------------+
bool ModifyPositionSL(const ulong ticket, const double new_sl)
  {
   if(!PositionSelectByTicket(ticket))
      return false;

   const double tp = PositionGetDouble(POSITION_TP);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double sl = NormalizeDouble(new_sl, digits);

   return g_trade.PositionModify(ticket, sl, tp);
  }

//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   if(InpTrailingStartPts <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const ENUM_POSITION_TYPE pos_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);

      const double market_price = (pos_type == POSITION_TYPE_BUY)
                                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      const double target_sl = CalcTrailingStopPrice(pos_type, open_price, market_price);
      if(target_sl <= 0.0)
         continue;

      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      const double min_delta = PointsToPrice(1);

      bool should_modify = false;
      if(pos_type == POSITION_TYPE_BUY)
         should_modify = (current_sl == 0.0) || (target_sl > current_sl + min_delta);
      else
         should_modify = (current_sl == 0.0) || (target_sl < current_sl - min_delta);

      if(should_modify)
         ModifyPositionSL(ticket, target_sl);
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
   return true;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   g_handle_fast_ema = iMA(_Symbol, PERIOD_CURRENT, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_handle_slow_ema = iMA(_Symbol, PERIOD_CURRENT, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_handle_rsi      = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE);

   if(g_handle_fast_ema == INVALID_HANDLE ||
      g_handle_slow_ema == INVALID_HANDLE ||
      g_handle_rsi == INVALID_HANDLE)
     {
      Print("IDC_8: indicator handle creation failed");
      return INIT_FAILED;
     }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippagePts);

   g_last_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   ResetCycleState();

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_handle_fast_ema != INVALID_HANDLE)
      IndicatorRelease(g_handle_fast_ema);
   if(g_handle_slow_ema != INVALID_HANDLE)
      IndicatorRelease(g_handle_slow_ema);
   if(g_handle_rsi != INVALID_HANDLE)
      IndicatorRelease(g_handle_rsi);
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
