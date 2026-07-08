//+------------------------------------------------------------------+
//| IDC_8.mq4 - GOLD M1 SYSTEM (MT4)                                 |
//| EMA cross + RSI baseline breakout + fast EMA candle confirmation |
//+------------------------------------------------------------------+
#property copyright "IDC_8"
#property version   "3.18"
#property strict

enum ENUM_CYCLE
  {
   CYCLE_NONE = 0,
   CYCLE_BUY  = 1,
   CYCLE_SELL = 2
  };

enum ENUM_SETUP_PHASE
  {
   PHASE_IDLE            = 0,
   PHASE_WAIT_RSI_ARM    = 1,
   PHASE_WAIT_EMA        = 2,
   PHASE_SETUP_EXHAUSTED = 3
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

//--- Range filters (chop block)
input bool InpUseEmaSepFilter    = true;  // 9-50 EMA separation filter
input int  InpMinEmaSepPts       = 100;   // Min |9EMA-50EMA| (points)
input bool   InpUseEmaAngleFilter = true;  // EMA34 angle filter
input int    InpAngleEmaPeriod    = 34;    // Angle EMA period
input int    InpAngleLookback     = 7;     // Angle lookback bars
input double InpMinAngleDeg       = 78.7;  // Min |EMA34 angle| (degrees)

//--- Risk / exit
input double InpLots             = 0.01;
input int    InpStopLossPoints   = 500;
input int    InpTrailingStartPts = 200;
input int    InpTrailingStepPts  = 10;

//--- Trade settings
input int    InpMagicNumber  = 80008;
input int    InpSlippagePts  = 30;  // OrderSend max slippage (pts) — not an entry filter
input string InpTradeComment = "IDC_8";

//--- Debug / display
input bool InpDebugBarLog  = false; // Experts tab per-bar O/X log
input bool InpChartPanel   = true;  // Chart left dashboard (all conditions)
input int  InpPanelFontSize = 13;   // Dashboard font size (8-16)

string   g_trade_symbol      = "";
int      g_broker_gmt_offset = 0;
datetime g_broker_time       = 0;

ENUM_CYCLE       g_cycle            = CYCLE_NONE;
ENUM_SETUP_PHASE g_setup_phase      = PHASE_IDLE;
datetime         g_cycle_start_time = 0;
bool             g_entry_taken      = false;

bool     g_rsi_armed              = false;
bool     g_rsi_to_ema_used        = false;
int      g_grace_remaining        = 0;
datetime g_rsi_arm_time           = 0;
datetime g_rsi_trigger_time       = 0;
datetime g_last_bar_time          = 0;

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
void ExpireObservationWindow()
  {
   g_cycle            = CYCLE_NONE;
   g_cycle_start_time = 0;
   g_entry_taken      = false;
   g_rsi_to_ema_used  = false;
   ResetSetupState();
  }

//+------------------------------------------------------------------+
void ResetSetupState()
  {
   g_setup_phase      = PHASE_IDLE;
   g_rsi_armed        = false;
   g_grace_remaining  = 0;
   g_rsi_arm_time     = 0;
   g_rsi_trigger_time = 0;
  }

//+------------------------------------------------------------------+
void ExpireEmaGraceWindow()
  {
   g_setup_phase      = PHASE_SETUP_EXHAUSTED;
   g_rsi_armed        = false;
   g_grace_remaining  = 0;
   g_rsi_arm_time     = 0;
   g_rsi_trigger_time = 0;
  }

//+------------------------------------------------------------------+
void ResetCycleState()
  {
   g_cycle            = CYCLE_NONE;
   g_cycle_start_time = 0;
   g_entry_taken     = false;
   g_rsi_to_ema_used = false;
   ResetSetupState();
  }

//+------------------------------------------------------------------+
void StartCycle(const ENUM_CYCLE cycle, const datetime bar_time)
  {
   g_cycle            = cycle;
   g_cycle_start_time = bar_time;
   g_entry_taken      = false;
   g_rsi_to_ema_used  = false;
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
bool GetRsiPair(const int shift, double &rsi_curr, double &rsi_prev)
  {
   if(iBars(TradeSymbol(), Period()) < InpRsiPeriod + shift + 3)
      return false;

   rsi_curr = iRSI(TradeSymbol(), Period(), InpRsiPeriod, PRICE_CLOSE, shift);
   rsi_prev = iRSI(TradeSymbol(), Period(), InpRsiPeriod, PRICE_CLOSE, shift + 1);
   return true;
  }

//+------------------------------------------------------------------+
//| RSI baseline breakout on closed bar (prev side -> curr side)     |
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
//| 차트 RSI(종가)와 동일 — 해당 shift 마감봉에서 돌파 재검증 (눈=차트) |
//+------------------------------------------------------------------+
bool IsRsiBreakoutAboveAtShift(const int shift, const double level)
  {
   double rsi_curr = 0.0, rsi_prev = 0.0;
   if(!GetRsiPair(shift, rsi_curr, rsi_prev))
      return false;
   return IsRsiBreakoutAbove(rsi_prev, rsi_curr, level);
  }

//+------------------------------------------------------------------+
bool IsRsiBreakoutBelowAtShift(const int shift, const double level)
  {
   double rsi_curr = 0.0, rsi_prev = 0.0;
   if(!GetRsiPair(shift, rsi_curr, rsi_prev))
      return false;
   return IsRsiBreakoutBelow(rsi_prev, rsi_curr, level);
  }

//+------------------------------------------------------------------+
bool ScanSellRsiSequence(const int cross_shift, int &arm_shift, int &trigger_shift)
  {
   arm_shift     = -1;
   trigger_shift = -1;
   bool armed    = false;

   for(int shift = cross_shift; shift >= 1; shift--)
     {
      if(!armed)
        {
         if(IsRsiBreakoutAboveAtShift(shift, InpRsiUpper))
           {
            armed     = true;
            arm_shift = shift;
           }
        }
      else
        {
         if(IsRsiBreakoutBelowAtShift(shift, InpRsiLower))
           {
            trigger_shift = shift;
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
bool ScanBuyRsiSequence(const int cross_shift, int &arm_shift, int &trigger_shift)
  {
   arm_shift     = -1;
   trigger_shift = -1;
   bool armed    = false;

   for(int shift = cross_shift; shift >= 1; shift--)
     {
      if(!armed)
        {
         if(IsRsiBreakoutBelowAtShift(shift, InpRsiLower))
           {
            armed     = true;
            arm_shift = shift;
           }
        }
      else
        {
         if(IsRsiBreakoutAboveAtShift(shift, InpRsiUpper))
           {
            trigger_shift = shift;
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
bool VerifyRsiSequenceLocked(const int order_type)
  {
   if(g_rsi_arm_time == 0 || g_rsi_trigger_time == 0)
      return false;

   int arm_shift     = iBarShift(TradeSymbol(), Period(), g_rsi_arm_time, true);
   int trigger_shift = iBarShift(TradeSymbol(), Period(), g_rsi_trigger_time, true);
   if(arm_shift < 1 || trigger_shift < 1)
      return false;

   if(arm_shift <= trigger_shift)
      return false;

   if(order_type == OP_SELL)
     {
      if(!IsRsiBreakoutAboveAtShift(arm_shift, InpRsiUpper))
         return false;
      if(!IsRsiBreakoutBelowAtShift(trigger_shift, InpRsiLower))
         return false;
      return true;
     }

   if(order_type == OP_BUY)
     {
      if(!IsRsiBreakoutBelowAtShift(arm_shift, InpRsiLower))
         return false;
      if(!IsRsiBreakoutAboveAtShift(trigger_shift, InpRsiUpper))
         return false;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
void RebuildRsiStateFromHistory(const int cross_shift)
  {
   if(cross_shift < 1)
      return;

   g_rsi_armed        = false;
   g_rsi_arm_time     = 0;
   g_rsi_trigger_time = 0;
   g_rsi_to_ema_used  = false;
   g_grace_remaining  = 0;
   g_setup_phase      = PHASE_IDLE;

   int arm_shift     = -1;
   int trigger_shift = -1;

   if(g_cycle == CYCLE_SELL)
     {
      if(ScanSellRsiSequence(cross_shift, arm_shift, trigger_shift))
        {
         g_rsi_armed    = true;
         g_rsi_arm_time = iTime(TradeSymbol(), Period(), arm_shift);
         BeginWaitEmaPhaseAtShift(trigger_shift);
        }
      else if(arm_shift >= 1)
        {
         g_rsi_armed        = true;
         g_rsi_arm_time     = iTime(TradeSymbol(), Period(), arm_shift);
         g_setup_phase      = PHASE_WAIT_RSI_ARM;
        }
     }
   else if(g_cycle == CYCLE_BUY)
     {
      if(ScanBuyRsiSequence(cross_shift, arm_shift, trigger_shift))
        {
         g_rsi_armed    = true;
         g_rsi_arm_time = iTime(TradeSymbol(), Period(), arm_shift);
         BeginWaitEmaPhaseAtShift(trigger_shift);
        }
      else if(arm_shift >= 1)
        {
         g_rsi_armed        = true;
         g_rsi_arm_time     = iTime(TradeSymbol(), Period(), arm_shift);
         g_setup_phase      = PHASE_WAIT_RSI_ARM;
        }
     }

   SyncGraceRemainingFromTrigger();
  }

//+------------------------------------------------------------------+
bool GetEmaAtShift(const int period, const int shift, double &ema)
  {
   if(iBars(TradeSymbol(), Period()) < period + shift + 2)
      return false;

   ema = iMA(TradeSymbol(), Period(), period, 0, MODE_EMA, PRICE_CLOSE, shift);
   return true;
  }

//+------------------------------------------------------------------+
bool GetEmaSeparationPts(double &sep_pts)
  {
   sep_pts = 0.0;

   double fast_ema = 0.0;
   double slow_ema = 0.0;
   if(!GetFastEma(1, fast_ema))
      return false;
   if(!GetEmaAtShift(InpSlowEmaPeriod, 1, slow_ema))
      return false;

   sep_pts = MathAbs(fast_ema - slow_ema) / TradePoint();
   return true;
  }

//+------------------------------------------------------------------+
bool PassesEmaSeparationFilter()
  {
   if(!InpUseEmaSepFilter)
      return true;
   if(InpMinEmaSepPts <= 0)
      return true;

   double sep_pts = 0.0;
   if(!GetEmaSeparationPts(sep_pts))
      return false;

   return (sep_pts >= InpMinEmaSepPts);
  }

//+------------------------------------------------------------------+
//| EMA34 angle in degrees (ATR-normalized, gold M1 stable)          |
//| angle = atan( (EMA[shift]-EMA[shift+N]) / ATR(N)[shift] ) * 180/pi |
//| flat chop -> ~0 deg, steep trend -> high |angle|                  |
//+------------------------------------------------------------------+
bool GetEma34AngleDeg(const int ema_period,
                      const int lookback,
                      const int base_shift,
                      double &angle_deg)
  {
   if(lookback < 1)
      return false;

   double ema_now  = 0.0;
   double ema_prev = 0.0;
   if(!GetEmaAtShift(ema_period, base_shift, ema_now))
      return false;
   if(!GetEmaAtShift(ema_period, base_shift + lookback, ema_prev))
      return false;

   double atr = iATR(TradeSymbol(), Period(), lookback, base_shift);
   if(atr <= 0.0)
      return false;

   double rise = ema_now - ema_prev;
   angle_deg   = MathArctan(rise / atr) * 180.0 / 3.14159265358979323846;
   return true;
  }

//+------------------------------------------------------------------+
bool PassesEmaAngleFilter(const int order_type)
  {
   if(!InpUseEmaAngleFilter)
      return true;
   if(InpMinAngleDeg <= 0.0)
      return true;
   if(InpAngleLookback < 1)
      return true;

   double angle_deg = 0.0;
   if(!GetEma34AngleDeg(InpAngleEmaPeriod, InpAngleLookback, 1, angle_deg))
      return false;

   if(order_type == OP_SELL)
      return (angle_deg <= -InpMinAngleDeg);

   if(order_type == OP_BUY)
      return (angle_deg >= InpMinAngleDeg);

   return false;
  }

//+------------------------------------------------------------------+
bool PassesRangeFilters(const int order_type)
  {
   if(!PassesEmaSeparationFilter())
      return false;
   if(!PassesEmaAngleFilter(order_type))
      return false;
   return true;
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
bool IsSellEmaBreakthrough(const int shift)
  {
   double fast_ema = 0.0;
   if(!GetFastEma(shift, fast_ema))
      return false;

   double low = iLow(TradeSymbol(), Period(), shift);
   return (low < fast_ema);
  }

//+------------------------------------------------------------------+
bool IsSellEmaCloseBelow(const int shift)
  {
   double fast_ema = 0.0;
   if(!GetFastEma(shift, fast_ema))
      return false;

   double close = iClose(TradeSymbol(), Period(), shift);
   return (close < fast_ema);
  }

//+------------------------------------------------------------------+
bool IsBuyEmaBreakthrough(const int shift)
  {
   double fast_ema = 0.0;
   if(!GetFastEma(shift, fast_ema))
      return false;

   double high = iHigh(TradeSymbol(), Period(), shift);
   return (high > fast_ema);
  }

//+------------------------------------------------------------------+
bool IsBuyEmaCloseAbove(const int shift)
  {
   double fast_ema = 0.0;
   if(!GetFastEma(shift, fast_ema))
      return false;

   double close = iClose(TradeSymbol(), Period(), shift);
   return (close > fast_ema);
  }

//+------------------------------------------------------------------+
bool IsSellEmaConfirm(const int shift)
  {
   if(!IsSellEmaBreakthrough(shift))
      return false;
   if(!IsSellEmaCloseBelow(shift))
      return false;
   if(!IsBodyDominant(shift))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
bool IsBuyEmaConfirm(const int shift)
  {
   if(!IsBuyEmaBreakthrough(shift))
      return false;
   if(!IsBuyEmaCloseAbove(shift))
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
int BarsSinceRsiTrigger()
  {
   if(g_rsi_trigger_time == 0)
      return 2147483647;

   int shift = iBarShift(TradeSymbol(), Period(), g_rsi_trigger_time, true);
   if(shift < 0)
      return 2147483647;

   return shift;
  }

//+------------------------------------------------------------------+
bool IsEmaGraceWindowExpired()
  {
   return (g_grace_remaining <= 0);
  }

//+------------------------------------------------------------------+
//| RSI 2차돌파 봉 포함, shift1 기준 남은 유예봉 (부트스트랩 전용)     |
//| 유예구간 shift: [trigger-G+1 .. trigger] ∩ [1..]                   |
//+------------------------------------------------------------------+
void SyncGraceRemainingFromTrigger()
  {
   if(g_setup_phase != PHASE_WAIT_EMA || g_rsi_trigger_time == 0)
      return;

   int trigger_shift = iBarShift(TradeSymbol(), Period(), g_rsi_trigger_time, true);
   if(trigger_shift < 1)
     {
      ExpireEmaGraceWindow();
      return;
     }

   int first_grace_shift = trigger_shift - InpEmaGraceBars + 1;
   if(first_grace_shift < 1)
      first_grace_shift = 1;

   if(1 < first_grace_shift)
     {
      ExpireEmaGraceWindow();
      return;
     }

   g_grace_remaining = trigger_shift - first_grace_shift + 1;
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
bool IsDeadCrossAtShift(const int shift)
  {
   double fast_curr = 0.0, slow_curr = 0.0;
   double fast_prev = 0.0, slow_prev = 0.0;

   if(!GetEmaPair(shift, fast_curr, slow_curr))
      return false;
   if(!GetEmaPair(shift + 1, fast_prev, slow_prev))
      return false;

   return (fast_prev >= slow_prev) && (fast_curr < slow_curr);
  }

//+------------------------------------------------------------------+
bool IsGoldenCrossAtShift(const int shift)
  {
   double fast_curr = 0.0, slow_curr = 0.0;
   double fast_prev = 0.0, slow_prev = 0.0;

   if(!GetEmaPair(shift, fast_curr, slow_curr))
      return false;
   if(!GetEmaPair(shift + 1, fast_prev, slow_prev))
      return false;

   return (fast_prev <= slow_prev) && (fast_curr > slow_curr);
  }

//+------------------------------------------------------------------+
int FindMostRecentCrossShift(ENUM_CYCLE &cycle_out)
  {
   cycle_out = CYCLE_NONE;

   int max_shift = InpObservationBars;
   if(max_shift > 500)
      max_shift = 500;

   int best_shift = 2147483647;

   for(int shift = 1; shift <= max_shift; shift++)
     {
      if(IsDeadCrossAtShift(shift))
        {
         if(shift < best_shift)
           {
            best_shift = shift;
            cycle_out  = CYCLE_SELL;
           }
        }
      else if(IsGoldenCrossAtShift(shift))
        {
         if(shift < best_shift)
           {
            best_shift = shift;
            cycle_out  = CYCLE_BUY;
           }
        }
     }

   if(cycle_out == CYCLE_NONE)
      return -1;

   return best_shift;
  }

//+------------------------------------------------------------------+
bool BeginWaitEmaPhaseAtShift(const int trigger_shift)
  {
   if(g_rsi_to_ema_used)
      return false;
   if(g_rsi_arm_time == 0)
      return false;

   int arm_shift = iBarShift(TradeSymbol(), Period(), g_rsi_arm_time, true);
   if(arm_shift < 1 || arm_shift <= trigger_shift)
      return false;

   if(g_cycle == CYCLE_SELL)
     {
      if(!IsRsiBreakoutAboveAtShift(arm_shift, InpRsiUpper))
         return false;
      if(!IsRsiBreakoutBelowAtShift(trigger_shift, InpRsiLower))
         return false;
     }
   else if(g_cycle == CYCLE_BUY)
     {
      if(!IsRsiBreakoutBelowAtShift(arm_shift, InpRsiLower))
         return false;
      if(!IsRsiBreakoutAboveAtShift(trigger_shift, InpRsiUpper))
         return false;
     }
   else
      return false;

   g_setup_phase      = PHASE_WAIT_EMA;
   g_rsi_to_ema_used  = true;
   g_rsi_trigger_time = iTime(TradeSymbol(), Period(), trigger_shift);

   int elapsed = 0;
   if(g_cycle_start_time > 0)
     {
      int cross_shift = iBarShift(TradeSymbol(), Period(), g_cycle_start_time, true);
      if(cross_shift >= 0)
         elapsed = cross_shift - trigger_shift + 1;
     }

   int remaining_obs = InpObservationBars - elapsed + 1;
   if(remaining_obs < 0)
      remaining_obs = 0;

   g_grace_remaining = MathMin(InpEmaGraceBars, remaining_obs);

   if(g_grace_remaining <= 0)
     {
      ExpireEmaGraceWindow();
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
void ProcessSellRsiAtShift(const int shift)
  {
   if(g_setup_phase == PHASE_SETUP_EXHAUSTED)
      return;
   if(g_rsi_to_ema_used && g_setup_phase != PHASE_WAIT_EMA)
      return;

   double rsi_curr = 0.0, rsi_prev = 0.0;
   if(!GetRsiPair(shift, rsi_curr, rsi_prev))
      return;

   if(!g_rsi_armed)
     {
      if(IsRsiBreakoutAbove(rsi_prev, rsi_curr, InpRsiUpper))
        {
         g_rsi_armed    = true;
         g_rsi_arm_time = iTime(TradeSymbol(), Period(), shift);
         if(g_setup_phase == PHASE_IDLE)
            g_setup_phase = PHASE_WAIT_RSI_ARM;
        }
     }

   if(g_rsi_armed && g_setup_phase != PHASE_WAIT_EMA)
     {
      if(IsRsiBreakoutBelow(rsi_prev, rsi_curr, InpRsiLower))
         BeginWaitEmaPhaseAtShift(shift);
     }
  }

//+------------------------------------------------------------------+
void ProcessBuyRsiAtShift(const int shift)
  {
   if(g_setup_phase == PHASE_SETUP_EXHAUSTED)
      return;
   if(g_rsi_to_ema_used && g_setup_phase != PHASE_WAIT_EMA)
      return;

   double rsi_curr = 0.0, rsi_prev = 0.0;
   if(!GetRsiPair(shift, rsi_curr, rsi_prev))
      return;

   if(!g_rsi_armed)
     {
      if(IsRsiBreakoutBelow(rsi_prev, rsi_curr, InpRsiLower))
        {
         g_rsi_armed    = true;
         g_rsi_arm_time = iTime(TradeSymbol(), Period(), shift);
         if(g_setup_phase == PHASE_IDLE)
            g_setup_phase = PHASE_WAIT_RSI_ARM;
        }
     }

   if(g_rsi_armed && g_setup_phase != PHASE_WAIT_EMA)
     {
      if(IsRsiBreakoutAbove(rsi_prev, rsi_curr, InpRsiUpper))
         BeginWaitEmaPhaseAtShift(shift);
     }
  }

//+------------------------------------------------------------------+
void TrySellEntryAtShift(const int shift, const bool allow_open)
  {
   if(g_cycle != CYCLE_SELL || g_entry_taken)
      return;
   if(IsObservationWindowExpired())
     {
      ExpireObservationWindow();
      return;
     }
   if(g_setup_phase != PHASE_WAIT_EMA)
      return;
   if(g_grace_remaining <= 0)
     {
      ExpireEmaGraceWindow();
      return;
     }

   bool entered = false;
   if(IsSellEmaConfirm(shift) && PassesRangeFilters(OP_SELL))
     {
      if(allow_open)
         entered = OpenPositionAtSetupClose(OP_SELL);
     }

   if(!entered)
     {
      g_grace_remaining--;
      if(g_grace_remaining <= 0)
         ExpireEmaGraceWindow();
     }
  }

//+------------------------------------------------------------------+
void TryBuyEntryAtShift(const int shift, const bool allow_open)
  {
   if(g_cycle != CYCLE_BUY || g_entry_taken)
      return;
   if(IsObservationWindowExpired())
     {
      ExpireObservationWindow();
      return;
     }
   if(g_setup_phase != PHASE_WAIT_EMA)
      return;
   if(g_grace_remaining <= 0)
     {
      ExpireEmaGraceWindow();
      return;
     }

   bool entered = false;
   if(IsBuyEmaConfirm(shift) && PassesRangeFilters(OP_BUY))
     {
      if(allow_open)
         entered = OpenPositionAtSetupClose(OP_BUY);
     }

   if(!entered)
     {
      g_grace_remaining--;
      if(g_grace_remaining <= 0)
         ExpireEmaGraceWindow();
     }
  }

//+------------------------------------------------------------------+
void ReplayCycleStateSinceCross(const int cross_shift)
  {
   RebuildRsiStateFromHistory(cross_shift);
  }

//+------------------------------------------------------------------+
void SyncEntryTakenFromOpenPosition()
  {
   if(!HasOpenPosition())
      return;

   g_entry_taken = true;
  }

//+------------------------------------------------------------------+
void BootstrapCycleFromHistory()
  {
   if(g_cycle != CYCLE_NONE || g_entry_taken || HasOpenPosition())
      return;

   ENUM_CYCLE found_cycle = CYCLE_NONE;
   int        cross_shift = FindMostRecentCrossShift(found_cycle);
   if(cross_shift < 1)
     {
      if(InpDebugBarLog)
         Print("IDC_8|BOOT|NONE|no cross in ", InpObservationBars, " bars");
      return;
     }

   datetime cross_time = iTime(TradeSymbol(), Period(), cross_shift);
   if(cross_time == 0)
      return;

   StartCycle(found_cycle, cross_time);
   ReplayCycleStateSinceCross(cross_shift);

   if(g_cycle != CYCLE_NONE && IsObservationWindowExpired())
     {
      if(InpDebugBarLog)
         Print("IDC_8|BOOT|SKIP|obs expired|cross_bar=",
               TimeToString(cross_time, TIME_DATE | TIME_MINUTES),
               "|shift=", cross_shift);
      ExpireObservationWindow();
      return;
     }

   if(InpDebugBarLog)
      Print("IDC_8|BOOT|", CycleLabel(),
            "|cross_bar=", TimeToString(cross_time, TIME_DATE | TIME_MINUTES),
            "|shift=", cross_shift,
            "|Ph=", PhaseLabel(),
            "|Grace=", g_grace_remaining);
  }

//+------------------------------------------------------------------+
bool BeginWaitEmaPhase()
  {
   return BeginWaitEmaPhaseAtShift(1);
  }

//+------------------------------------------------------------------+
bool IsSetupEntryPermitted(const int order_type)
  {
   if(g_entry_taken)
      return false;
   if(g_setup_phase != PHASE_WAIT_EMA)
      return false;
   if(!g_rsi_to_ema_used)
      return false;
   if(g_rsi_trigger_time == 0 || g_rsi_arm_time == 0)
      return false;
   if(!VerifyRsiSequenceLocked(order_type))
      return false;
   if(g_grace_remaining <= 0)
      return false;
   if(IsEmaGraceWindowExpired())
      return false;
   if(IsObservationWindowExpired())
      return false;

   if(order_type == OP_BUY && g_cycle != CYCLE_BUY)
      return false;
   if(order_type == OP_SELL && g_cycle != CYCLE_SELL)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
void DetectEmaCrossOnClosedBar()
  {
   if(HasOpenPosition())
      return;

   datetime cross_time = iTime(TradeSymbol(), Period(), 1);
   if(cross_time == 0)
      return;

   if(IsDeadCrossAtShift(1))
     {
      if(g_cycle_start_time != cross_time)
         StartCycle(CYCLE_SELL, cross_time);
     }
   else if(IsGoldenCrossAtShift(1))
     {
      if(g_cycle_start_time != cross_time)
         StartCycle(CYCLE_BUY, cross_time);
     }
  }

//+------------------------------------------------------------------+
void ProcessSellRsiOnClosedBar()
  {
   ProcessSellRsiAtShift(1);
  }

//+------------------------------------------------------------------+
void ProcessBuyRsiOnClosedBar()
  {
   ProcessBuyRsiAtShift(1);
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
   if(!IsSetupEntryPermitted(order_type))
     {
      Print("IDC_8: entry blocked. phase=", (int)g_setup_phase,
            " grace=", g_grace_remaining,
            " rsi_lock=", (int)VerifyRsiSequenceLocked(order_type),
            " arm_bar=", TimeToString(g_rsi_arm_time, TIME_DATE | TIME_MINUTES),
            " trig_bar=", TimeToString(g_rsi_trigger_time, TIME_DATE | TIME_MINUTES));
      return false;
     }

   RefreshRates();

   double setup_close = GetSetupClosePrice();
   double send_price  = (order_type == OP_BUY) ? TradeAsk() : TradeBid();

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

   g_entry_taken = true;

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
      g_entry_taken = false;
      Print("IDC_8: OrderSend failed after retries. error=", GetLastError());
      return false;
     }

   LogEntryDone(order_type, ticket);

   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      if(OrderStopLoss() <= 0.0)
        {
         if(!AttachMissingStopLoss(ticket))
            Print("IDC_8: CRITICAL - opened without SL, restore failed. ticket=", ticket,
                  " (ProtectAllPositionsStopLoss will retry each tick)");
        }
     }

   ResetSetupState();
   return true;
  }

//+------------------------------------------------------------------+
void TrySellEntryOnClosedBar()
  {
   TrySellEntryAtShift(1, true);
  }

//+------------------------------------------------------------------+
void TryBuyEntryOnClosedBar()
  {
   TryBuyEntryAtShift(1, true);
  }

//+------------------------------------------------------------------+
string CycleLabel()
  {
   if(g_cycle == CYCLE_SELL)
      return "SELL";
   if(g_cycle == CYCLE_BUY)
      return "BUY";
   return "NONE";
  }

//+------------------------------------------------------------------+
string PhaseLabel()
  {
   switch(g_setup_phase)
     {
      case PHASE_IDLE:            return "IDLE";
      case PHASE_WAIT_RSI_ARM:    return "WAIT_RSI";
      case PHASE_WAIT_EMA:        return "WAIT_EMA";
      case PHASE_SETUP_EXHAUSTED: return "EXHAUSTED";
      default:                    return "?";
     }
  }

//+------------------------------------------------------------------+
string Ox(const bool ok)
  {
   return ok ? "O" : "X";
  }

//+------------------------------------------------------------------+
string OnOffLabel(const bool enabled)
  {
   return enabled ? "ON" : "OFF";
  }

//+------------------------------------------------------------------+
color PanelResultColor(const bool ok)
  {
   return ok ? clrLime : clrTomato;
  }

//+------------------------------------------------------------------+
string PanelMark(const bool ok)
  {
   return ok ? "[O]" : "[X]";
  }

//+------------------------------------------------------------------+
void ClearChartDashboard()
  {
   Comment("");

   for(int i = ObjectsTotal() - 1; i >= 0; i--)
     {
      string name = ObjectName(i);
      if(StringFind(name, "IDC8pnl_") == 0)
         ObjectDelete(name);
     }
  }

//+------------------------------------------------------------------+
bool SetDashboardLine(const int line_idx, const string text, const color clr)
  {
   string name = "IDC8pnl_" + IntegerToString(line_idx);

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
   string name = "IDC8pnl_bg";
   int      h    = (InpPanelFontSize + 6) * line_count + 14;
   int      w    = 560;

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
                          const bool dead_cross,
                          const bool golden_cross,
                          const bool rsi_ok,
                          const double rsi_curr,
                          const bool rsi52_up,
                          const bool rsi48_dn,
                          const bool rsi48_dn_step1,
                          const bool rsi52_up_step2,
                          const bool sell_br,
                          const bool sell_cl,
                          const bool sell_bd,
                          const bool sell_all,
                          const bool buy_br,
                          const bool buy_cl,
                          const bool buy_bd,
                          const bool buy_all,
                          const bool sep_data,
                          const double sep_pts,
                          const bool sep_pass,
                          const bool ang_data,
                          const double angle_deg,
                          const bool ang_sell_pass,
                          const bool ang_buy_pass,
                          const bool obs_ok,
                          const int obs_left,
                          const bool grace_ok,
                          const bool rng_pass,
                          const bool entry_all,
                          const bool has_pos)
  {
   const int PNL_LINE_COUNT = 18;

   ClearChartDashboard();
   SetDashboardBackground(PNL_LINE_COUNT);

   int line = 0;
   SetDashboardLine(line++,
                    "IDC_8 v3.18  " + TradeSymbol() + " " + TimeframeLabel(),
                    clrGold);
   SetDashboardLine(line++,
                    "봉 " + TimeToString(bar_time, TIME_DATE | TIME_MINUTES),
                    clrWhite);
   SetDashboardLine(line++,
                    StringFormat("사이클:%s  단계:%s  체결:%s",
                                 CycleLabel(), PhaseLabel(), PanelMark(g_entry_taken)),
                    g_setup_phase == PHASE_SETUP_EXHAUSTED ? clrTomato : clrAqua);
   SetDashboardLine(line++,
                    StringFormat("설정 관찰:%d봉  유예:%d봉  RSI:%.0f/%.0f  EMA:%d/%d",
                                 InpObservationBars, InpEmaGraceBars,
                                 InpRsiUpper, InpRsiLower,
                                 InpFastEmaPeriod, InpSlowEmaPeriod),
                    clrSilver);
   SetDashboardLine(line++, "========================================", clrDimGray);

   bool cross_sell = (g_cycle == CYCLE_SELL) || (g_cycle == CYCLE_NONE && dead_cross);
   bool cross_buy  = (g_cycle == CYCLE_BUY)  || (g_cycle == CYCLE_NONE && golden_cross);
   SetDashboardLine(line++,
                    StringFormat("1 데드크로스(%d/%d) %s   골든 %s",
                                 InpFastEmaPeriod, InpSlowEmaPeriod,
                                 PanelMark(cross_sell || dead_cross),
                                 PanelMark(cross_buy || golden_cross)),
                    PanelResultColor(dead_cross || golden_cross || g_cycle != CYCLE_NONE));

   if(g_cycle == CYCLE_NONE)
      SetDashboardLine(line++,
                       StringFormat("2 관찰N봉 %s  (-- / 설정%d봉)",
                                    PanelMark(false), InpObservationBars),
                       clrSilver);
   else
      SetDashboardLine(line++,
                       StringFormat("2 관찰N봉 %s  (잔여%d / 설정%d봉)",
                                    PanelMark(obs_ok), obs_left, InpObservationBars),
                       PanelResultColor(obs_ok));

   string rsi_val = rsi_ok ? DoubleToString(rsi_curr, 1) : "N/A";
   if(g_cycle == CYCLE_BUY)
     {
      SetDashboardLine(line++,
                       StringFormat("3 RSI%.0f하향돌파 %s  RSI%s (기준%.0f)",
                                    InpRsiLower, PanelMark(rsi48_dn_step1),
                                    rsi_val, InpRsiLower),
                       PanelResultColor(rsi48_dn_step1));
      SetDashboardLine(line++,
                       StringFormat("4 RSI1차완료 %s", PanelMark(g_rsi_armed || g_rsi_to_ema_used)),
                       PanelResultColor(g_rsi_armed || g_rsi_to_ema_used));
      SetDashboardLine(line++,
                       StringFormat("5 RSI%.0f상향돌파 %s  RSI%s (기준%.0f)",
                                    InpRsiUpper, PanelMark(rsi52_up_step2),
                                    rsi_val, InpRsiUpper),
                       PanelResultColor(rsi52_up_step2));
      SetDashboardLine(line++,
                       StringFormat("6 9EMA돌파 %s  (high>9EMA)", PanelMark(buy_br)),
                       PanelResultColor(buy_br));
      SetDashboardLine(line++,
                       StringFormat("7 9EMA종가 %s  (종가>9EMA)", PanelMark(buy_cl)),
                       PanelResultColor(buy_cl));
      SetDashboardLine(line++,
                       StringFormat("8 몸통>꼬리 %s", PanelMark(buy_bd)),
                       PanelResultColor(buy_bd));
     }
   else
     {
      SetDashboardLine(line++,
                       StringFormat("3 RSI%.0f상향돌파 %s  RSI%s (기준%.0f)",
                                    InpRsiUpper, PanelMark(rsi52_up),
                                    rsi_val, InpRsiUpper),
                       PanelResultColor(rsi52_up));
      SetDashboardLine(line++,
                       StringFormat("4 RSI1차완료 %s", PanelMark(g_rsi_armed || g_rsi_to_ema_used)),
                       PanelResultColor(g_rsi_armed || g_rsi_to_ema_used));
      SetDashboardLine(line++,
                       StringFormat("5 RSI%.0f하향돌파 %s  RSI%s (기준%.0f)",
                                    InpRsiLower, PanelMark(rsi48_dn),
                                    rsi_val, InpRsiLower),
                       PanelResultColor(rsi48_dn));
      SetDashboardLine(line++,
                       StringFormat("6 9EMA돌파 %s  (low<9EMA)", PanelMark(sell_br)),
                       PanelResultColor(sell_br));
      SetDashboardLine(line++,
                       StringFormat("7 9EMA종가 %s  (종가<9EMA)", PanelMark(sell_cl)),
                       PanelResultColor(sell_cl));
      SetDashboardLine(line++,
                       StringFormat("8 몸통>꼬리 %s", PanelMark(sell_bd)),
                       PanelResultColor(sell_bd));
     }

   if(!InpUseEmaSepFilter || InpMinEmaSepPts <= 0)
      SetDashboardLine(line++,
                       StringFormat("9 EMA이격 [%s]  SKIP", OnOffLabel(InpUseEmaSepFilter)),
                       clrSilver);
   else
      SetDashboardLine(line++,
                       StringFormat("9 EMA이격 [%s] %s  %.0fpt (설정%dpt)",
                                    OnOffLabel(true), PanelMark(sep_pass && sep_data),
                                    sep_pts, InpMinEmaSepPts),
                       PanelResultColor(sep_pass && sep_data));

   if(!InpUseEmaAngleFilter || InpMinAngleDeg <= 0.0)
      SetDashboardLine(line++,
                       StringFormat("10 %dEMA각도 [%s]  SKIP",
                                    InpAngleEmaPeriod, OnOffLabel(InpUseEmaAngleFilter)),
                       clrSilver);
   else if(ang_data)
      SetDashboardLine(line++,
                       StringFormat("10 %dEMA각도 [%s]  %.1f도 (설정%.1f도)  SELL %s  BUY %s",
                                    InpAngleEmaPeriod, OnOffLabel(true),
                                    angle_deg, InpMinAngleDeg,
                                    PanelMark(ang_sell_pass), PanelMark(ang_buy_pass)),
                       PanelResultColor(ang_sell_pass || ang_buy_pass));
   else
      SetDashboardLine(line++,
                       StringFormat("10 %dEMA각도 [%s]  N/A (설정%.1f도)  SELL %s  BUY %s",
                                    InpAngleEmaPeriod, OnOffLabel(true), InpMinAngleDeg,
                                    PanelMark(false), PanelMark(false)),
                       clrTomato);

   SetDashboardLine(line++, "========================================", clrDimGray);

   if(has_pos)
      SetDashboardLine(line++, "포지션 보유중 - 신규진입 없음", clrOrange);
   else if(g_cycle == CYCLE_NONE)
      SetDashboardLine(line++,
                       StringFormat("유예:--  9EMA:%s  필터:%s",
                                    PanelMark(false), PanelMark(sep_pass && (ang_sell_pass || ang_buy_pass))),
                       clrSilver);
   else
      SetDashboardLine(line++,
                       StringFormat("유예 %d봉 [%s]  9EMA %s  필터 %s",
                                    g_grace_remaining, PanelMark(grace_ok),
                                    PanelMark(g_cycle == CYCLE_SELL ? sell_all : buy_all),
                                    PanelMark(rng_pass)),
                       PanelResultColor(grace_ok && rng_pass));

   string block = "";
   if(g_setup_phase == PHASE_SETUP_EXHAUSTED)
      block = "  차단:유예소진";
   else if(g_setup_phase != PHASE_WAIT_EMA && g_cycle != CYCLE_NONE)
      block = "  차단:RSI미완";
   SetDashboardLine(line++,
                    StringFormat(">>> 진입가능 %s%s <<<",
                                 PanelMark(entry_all && !has_pos), block),
                    PanelResultColor(entry_all && !has_pos));

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

   double rsi_curr = 0.0, rsi_prev = 0.0;
   bool   rsi_ok   = GetRsiPair(1, rsi_curr, rsi_prev);

   bool dead_cross   = IsDeadCrossAtShift(1);
   bool golden_cross = IsGoldenCrossAtShift(1);

   bool rsi52_up = false;
   bool rsi48_dn = false;
   bool rsi48_dn_step1 = false;
   bool rsi52_up_step2 = false;

   if(rsi_ok)
     {
      rsi52_up       = IsRsiBreakoutAbove(rsi_prev, rsi_curr, InpRsiUpper);
      rsi48_dn       = IsRsiBreakoutBelow(rsi_prev, rsi_curr, InpRsiLower);
      rsi48_dn_step1 = IsRsiBreakoutBelow(rsi_prev, rsi_curr, InpRsiLower);
      rsi52_up_step2 = IsRsiBreakoutAbove(rsi_prev, rsi_curr, InpRsiUpper);
     }

   bool ema_break = false;
   bool ema_close = false;
   bool ema_body  = false;
   bool ema_all   = false;
   bool sep_pass  = false;
   bool ang_pass  = false;
   bool rng_pass  = false;
   int  order_type = -1;

   double sep_pts   = 0.0;
   double angle_deg = 0.0;
   bool   sep_data  = GetEmaSeparationPts(sep_pts);
   bool   ang_data  = GetEma34AngleDeg(InpAngleEmaPeriod, InpAngleLookback, 1, angle_deg);

   bool sell_br = IsSellEmaBreakthrough(1);
   bool sell_cl = IsSellEmaCloseBelow(1);
   bool sell_bd = IsBodyDominant(1);
   bool sell_all = IsSellEmaConfirm(1);
   bool buy_br  = IsBuyEmaBreakthrough(1);
   bool buy_cl  = IsBuyEmaCloseAbove(1);
   bool buy_bd  = IsBodyDominant(1);
   bool buy_all = IsBuyEmaConfirm(1);

   bool sep_pass_raw = (!InpUseEmaSepFilter || InpMinEmaSepPts <= 0) ? true : (sep_data && sep_pts >= InpMinEmaSepPts);
   bool ang_sell_pass = false;
   bool ang_buy_pass  = false;
   if(ang_data)
     {
      ang_sell_pass = (!InpUseEmaAngleFilter || InpMinAngleDeg <= 0.0) ? true : (angle_deg <= -InpMinAngleDeg);
      ang_buy_pass  = (!InpUseEmaAngleFilter || InpMinAngleDeg <= 0.0) ? true : (angle_deg >= InpMinAngleDeg);
     }

   if(g_cycle == CYCLE_SELL)
     {
      order_type = OP_SELL;
      ema_break  = IsSellEmaBreakthrough(1);
      ema_close  = IsSellEmaCloseBelow(1);
      ema_body   = IsBodyDominant(1);
      ema_all    = IsSellEmaConfirm(1);
      sep_pass   = PassesEmaSeparationFilter();
      ang_pass   = PassesEmaAngleFilter(OP_SELL);
      rng_pass   = (sep_pass && ang_pass);
     }
   else if(g_cycle == CYCLE_BUY)
     {
      order_type = OP_BUY;
      ema_break  = IsBuyEmaBreakthrough(1);
      ema_close  = IsBuyEmaCloseAbove(1);
      ema_body   = IsBodyDominant(1);
      ema_all    = IsBuyEmaConfirm(1);
      sep_pass   = PassesEmaSeparationFilter();
      ang_pass   = PassesEmaAngleFilter(OP_BUY);
      rng_pass   = (sep_pass && ang_pass);
     }

   bool obs_ok    = (g_cycle != CYCLE_NONE) && !IsObservationWindowExpired();
   bool grace_ok  = (g_setup_phase == PHASE_WAIT_EMA && g_grace_remaining > 0 && !IsEmaGraceWindowExpired());
   bool setup_ok  = (order_type >= 0) ? IsSetupEntryPermitted(order_type) : false;
   bool rsi_lock  = (order_type >= 0) ? VerifyRsiSequenceLocked(order_type) : false;
   bool entry_all = (order_type >= 0 && setup_ok && ema_all && rng_pass && rsi_lock);
   int  obs_left  = RemainingObservationBars();
   bool has_pos   = HasOpenPosition();

   if(InpDebugBarLog)
     {
      string rsi_line = "RSI=--";
      if(g_cycle == CYCLE_SELL)
         rsi_line = StringFormat("RSI52up=%s RSIarmed=%s RSI48dn=%s",
                                 Ox(rsi52_up), Ox(g_rsi_armed), Ox(rsi48_dn));
      else if(g_cycle == CYCLE_BUY)
         rsi_line = StringFormat("RSI48dn=%s RSIarmed=%s RSI52up=%s",
                                 Ox(rsi48_dn_step1), Ox(g_rsi_armed), Ox(rsi52_up_step2));
      else
         rsi_line = StringFormat("RSInow=%.1f RSI52up=%s RSI48dn=%s",
                                 rsi_ok ? rsi_curr : 0.0, Ox(rsi52_up), Ox(rsi48_dn));

      string ema_line = "EMA=--";
      if(g_cycle == CYCLE_SELL)
         ema_line = StringFormat("EMAbreak=%s EMAclose=%s EMAbody=%s EMAall=%s",
                                 Ox(sell_br), Ox(sell_cl), Ox(sell_bd), Ox(sell_all));
      else if(g_cycle == CYCLE_BUY)
         ema_line = StringFormat("EMAbreak=%s EMAclose=%s EMAbody=%s EMAall=%s",
                                 Ox(buy_br), Ox(buy_cl), Ox(buy_bd), Ox(buy_all));
      else
         ema_line = StringFormat("EMAsell=%s EMAbuy=%s", Ox(sell_all), Ox(buy_all));

      string sep_line = "Sep=--";
      if(!InpUseEmaSepFilter || InpMinEmaSepPts <= 0)
         sep_line = "Sep=SKIP";
      else
         sep_line = StringFormat("Sep=%s(%.0f>=%d)", Ox(sep_pass_raw), sep_pts, InpMinEmaSepPts);

      string ang_line = "Ang=--";
      if(!InpUseEmaAngleFilter || InpMinAngleDeg <= 0.0)
         ang_line = "Ang=SKIP";
      else if(ang_data)
         ang_line = StringFormat("Ang%d=%.1f|SELL<=-%.1f:%s|BUY>=%.1f:%s",
                                 InpAngleEmaPeriod, angle_deg, InpMinAngleDeg,
                                 Ox(ang_sell_pass), InpMinAngleDeg, Ox(ang_buy_pass));
      else
         ang_line = StringFormat("Ang%d=N/A(set%.1f)", InpAngleEmaPeriod, InpMinAngleDeg);

      Print("IDC_8|BAR|", TimeToString(bar_time, TIME_DATE | TIME_MINUTES),
            "|Cyc=", CycleLabel(),
            "|Ph=", PhaseLabel(),
            "|Obs=", Ox(obs_ok),
            "|Grace=", g_grace_remaining,
            "|", rsi_line,
            "|", ema_line,
            "|", sep_line,
            "|", ang_line,
            "|Rng=", Ox(g_cycle == CYCLE_NONE ? false : rng_pass),
            "|SetupOK=", Ox(setup_ok),
            "|ENTRY=", Ox(entry_all),
            "|Taken=", Ox(g_entry_taken));
     }

   if(!InpChartPanel)
     {
      ClearChartDashboard();
      return;
     }

   RenderChartDashboard(bar_time, dead_cross, golden_cross,
                        rsi_ok, rsi_curr, rsi52_up, rsi48_dn,
                        rsi48_dn_step1, rsi52_up_step2,
                        sell_br, sell_cl, sell_bd, sell_all,
                        buy_br, buy_cl, buy_bd, buy_all,
                        sep_data, sep_pts, sep_pass_raw,
                        ang_data, angle_deg, ang_sell_pass, ang_buy_pass,
                        obs_ok, obs_left, grace_ok, rng_pass,
                        entry_all, has_pos);
  }

//+------------------------------------------------------------------+
void LogBarFilterStatus()
  {
   UpdateBarConditionDisplay();
  }

//+------------------------------------------------------------------+
void LogEntryDone(const int order_type, const int ticket)
  {
   if(!InpDebugBarLog)
      return;

   datetime bar_time = iTime(TradeSymbol(), Period(), 1);
   string   side     = (order_type == OP_BUY) ? "BUY" : "SELL";

   Print("IDC_8|ENTRY|DONE|", side,
         "|bar=", TimeToString(bar_time, TIME_DATE | TIME_MINUTES),
         "|ticket=", ticket);
  }

//+------------------------------------------------------------------+
void ProcessSetupLogicOnNewBar()
  {
   if(g_cycle == CYCLE_NONE)
      return;

   if(IsObservationWindowExpired())
     {
      ExpireObservationWindow();
      UpdateBarConditionDisplay();
      return;
     }

   if(g_entry_taken)
     {
      UpdateBarConditionDisplay();
      return;
     }

   if(g_cycle == CYCLE_SELL)
     {
      ProcessSellRsiOnClosedBar();
      LogBarFilterStatus();
      TrySellEntryOnClosedBar();
     }
   else if(g_cycle == CYCLE_BUY)
     {
      ProcessBuyRsiOnClosedBar();
      LogBarFilterStatus();
      TryBuyEntryOnClosedBar();
     }
  }

//+------------------------------------------------------------------+
void ProcessClosedBarEntryPipeline()
  {
   BootstrapCycleFromHistory();
   DetectEmaCrossOnClosedBar();

   if(HasOpenPosition())
     {
      if(InpDebugBarLog)
         Print("IDC_8|BAR|", TimeToString(iTime(TradeSymbol(), Period(), 1), TIME_DATE | TIME_MINUTES),
               "|SKIP|open position exists");
      UpdateBarConditionDisplay();
      return;
     }

   ProcessSetupLogicOnNewBar();

   if(g_cycle == CYCLE_NONE)
      UpdateBarConditionDisplay();
  }

//+------------------------------------------------------------------+
void ProcessEntryLogicOnNewBar()
  {
   ProcessClosedBarEntryPipeline();
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
   if(InpEmaGraceBars > InpObservationBars)
     {
      Print("IDC_8: EMA grace bars must be <= observation bars");
      return false;
     }
   if(InpMinEmaSepPts < 0)
     {
      Print("IDC_8: min EMA separation points must be >= 0");
      return false;
     }
   if(InpAngleEmaPeriod < 2)
     {
      Print("IDC_8: angle EMA period must be >= 2");
      return false;
     }
   if(InpAngleLookback < 1)
     {
      Print("IDC_8: angle lookback bars must be >= 1");
      return false;
     }
   if(InpMinAngleDeg < 0.0)
     {
      Print("IDC_8: min EMA34 angle degrees must be >= 0");
      return false;
     }
   if(InpMinAngleDeg >= 90.0)
     {
      Print("IDC_8: min EMA34 angle degrees must be < 90");
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
   if(InpPanelFontSize < 8 || InpPanelFontSize > 16)
     {
      Print("IDC_8: panel font size must be 8-16");
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

   Print("IDC_8 init v3.18 | trade symbol=", g_trade_symbol,
         " | chart symbol=", Symbol(),
         " | timeframe=", TimeframeLabel(), " (all TF supported, optimized for M1)",
         " | broker time=", FormatBrokerTime(g_broker_time),
         " | offset=", BrokerOffsetLabel(),
         " | stop level pts=", DoubleToString(GetStopLevelPts(), 0),
         " | freeze level pts=", DoubleToString(GetFreezeLevelPts(), 0));

   g_last_bar_time = iTime(TradeSymbol(), Period(), 0);
   ResetCycleState();
   SyncEntryTakenFromOpenPosition();
   ProcessClosedBarEntryPipeline();

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

   if(!IsNewBar())
      return;

   ProcessEntryLogicOnNewBar();
  }
//+------------------------------------------------------------------+
