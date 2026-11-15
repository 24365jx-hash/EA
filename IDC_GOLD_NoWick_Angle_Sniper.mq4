//+------------------------------------------------------------------+
//|                                      IDC_GOLD_NoWick_Angle_Sniper |
//|                        No-Wick Angle Sniper strategy for MT4      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.05"
#property description "IDC_GOLD No-Wick Angle Sniper EA"

#define IDC_PI 3.14159265358979323846

//--- input parameters
input double LotSize = 0.01;
input int    MagicNumber = 12345;
input int    Slippage = 3;                // Strategy points. Gold: 1 point = 0.01 price.
input int    EMA_Fast_Period = 9;
input int    EMA_Slow_Period = 20;
input int    Max_Setup_Candles = 20;
input double EMA_Angle_Threshold = 10.0;
input int    EMA_Angle_Lookback_Bars = 3;
input int    Min_Body_Points = 50;         // Gold: 50 points = 0.50 minimum setup candle body.
input int    Pre_Setup_Confirm_Candles = 2; // 0=off, N=previous N candles must confirm setup direction.
input double Max_Wick_Percentage = 20.0;
input int    ZeroWick_Tolerance_Points = 2; // Treat tiny visual/noise wicks as zero. Gold: 2 points = 0.02 price.
input int    StopLoss_Points = 200;       // Gold standard: 200 points = 2.00 price.
input int    TrailingStart_Points = 200;  // First secured profit distance from entry.
input int    TrailingStep_Points = 300;   // Jumping trailing interval after first secure point.
input bool   EnableBuy = true;
input bool   EnableSell = true;
input bool   EnableEntryDebugLog = true;  // Print exact filter rejection reasons on closed bars.
input bool   ResetCycleStateOnInit = false; // Debug option: clear stored one-entry-per-cross memory on attach.
input int    ProtectionRetryCount = 5;    // Retries for SL attach/forced close protection.
input bool   EnableVirtualTrailingGuard = true; // Market-close backup if broker rejects protected SL move.

//--- global state
double   _StrategyPoint = 0.0;
int      _lastCrossType = 0;              // 1 = fast EMA above slow EMA, -1 = below, 0 = equal/unknown
bool     _entryAllowedInCurrentCross = false;
datetime _crossTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ValidateInputs())
      return(INIT_FAILED);

   _StrategyPoint = DetectStrategyPoint();

   if(ResetCycleStateOnInit)
     {
      string resetKey = CrossStateKey();
      if(GlobalVariableCheck(resetKey))
         GlobalVariableDel(resetKey);
      Print("IDC cycle state reset on init. Key=", resetKey);
     }

   int currentRelation = GetEMARelation(1);
   _lastCrossType = currentRelation;
   _entryAllowedInCurrentCross = false;
   _crossTime = 0;

   datetime foundCrossTime = 0;
   int foundCrossType = 0;
   int barsSinceCross = 0;

   if(FindLatestRecentCross(foundCrossTime, foundCrossType, barsSinceCross))
     {
      _crossTime = foundCrossTime;
      _lastCrossType = foundCrossType;
      _entryAllowedInCurrentCross = !IsCurrentCrossAlreadyTraded();
     }

   Print("IDC_GOLD No-Wick Angle Sniper initialized. Symbol=", Symbol(),
         ", Digits=", Digits,
         ", Point=", DoubleToString(Point, Digits),
         ", StrategyPoint=", DoubleToString(_StrategyPoint, Digits),
         ", MaxWickPct=", DoubleToString(Max_Wick_Percentage, 2),
         ", MinBodyPoints=", Min_Body_Points,
         ", MinBodyPrice=", DoubleToString(PointsToPrice(Min_Body_Points), Digits),
         ", PreSetupConfirmCandles=", Pre_Setup_Confirm_Candles,
         ", ZeroWickTolerancePoints=", ZeroWick_Tolerance_Points,
         ", ZeroWickTolerancePrice=", DoubleToString(ZeroWickTolerancePrice(), Digits),
         ", AngleThreshold=", DoubleToString(EMA_Angle_Threshold, 2),
         ", AngleLookbackBars=", EMA_Angle_Lookback_Bars,
         ", ProtectionRetryCount=", ProtectionRetryCount,
         ", CrossTime=", TimeToString(_crossTime, TIME_DATE|TIME_MINUTES),
         ", EntryAllowed=", BoolToText(_entryAllowedInCurrentCross));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageUnprotectedPositions();
   ManageVirtualTrailingGuards();
   ManageTrailing();

   static datetime lastBarTime = 0;
   if(lastBarTime == Time[0])
      return;

   lastBarTime = Time[0];

   CheckForCrossChange();
   RefreshRecentCrossStateFromHistory();

   if(HasOpenPosition())
     {
      DebugEntryLog("Entry gate skipped before condition check: open position already exists. " +
                    EntryGateStateText());
      return;
     }

   if(!_entryAllowedInCurrentCross)
     {
      DebugEntryLog("Entry gate skipped before condition check: entry is not allowed for current cross. " +
                    EntryGateStateText());
      return;
     }

   CheckForEntry();
  }

//+------------------------------------------------------------------+
//| Input validation                                                  |
//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   if(LotSize <= 0.0)
     {
      Print("Invalid LotSize. It must be greater than zero.");
      return(false);
     }
   if(EMA_Fast_Period <= 0 || EMA_Slow_Period <= 0)
     {
      Print("Invalid EMA period. Periods must be greater than zero.");
      return(false);
     }
   if(EMA_Fast_Period == EMA_Slow_Period)
     {
      Print("Invalid EMA periods. Fast and slow EMA periods must be different.");
      return(false);
     }
   if(Max_Setup_Candles < 1)
     {
      Print("Invalid Max_Setup_Candles. It must be at least 1.");
      return(false);
     }
   if(EMA_Angle_Threshold < 0.0)
     {
      Print("Invalid EMA_Angle_Threshold. It must be zero or greater.");
      return(false);
     }
   if(EMA_Angle_Lookback_Bars < 1)
     {
      Print("Invalid EMA_Angle_Lookback_Bars. It must be at least 1.");
      return(false);
     }
   if(Min_Body_Points < 0)
     {
      Print("Invalid Min_Body_Points. It must be zero or greater.");
      return(false);
     }
   if(Pre_Setup_Confirm_Candles < 0)
     {
      Print("Invalid Pre_Setup_Confirm_Candles. It must be zero or greater.");
      return(false);
     }
   if(Max_Wick_Percentage < 0.0 || Max_Wick_Percentage > 100.0)
     {
      Print("Invalid Max_Wick_Percentage. It must be between 0 and 100.");
      return(false);
     }
   if(ZeroWick_Tolerance_Points < 0)
     {
      Print("Invalid ZeroWick_Tolerance_Points. It must be zero or greater.");
      return(false);
     }
   if(StopLoss_Points <= 0 || TrailingStart_Points <= 0 || TrailingStep_Points <= 0)
     {
      Print("Invalid point settings. StopLoss, TrailingStart, and TrailingStep must be greater than zero.");
      return(false);
     }
   if(ProtectionRetryCount < 1)
     {
      Print("Invalid ProtectionRetryCount. It must be at least 1.");
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Broker/symbol point detection                                    |
//+------------------------------------------------------------------+
double DetectStrategyPoint()
  {
   // Gold brokers commonly quote XAU/GOLD with 2 or 3 decimals.
   // The strategy defines 200 points as 2.00 price, so gold strategy point is fixed at 0.01.
   if(IsGoldSymbol())
      return(0.01);

   // For non-gold symbols, use the common pip-style point normalization.
   if(Digits == 3 || Digits == 5)
      return(Point * 10.0);

   return(Point);
  }

//+------------------------------------------------------------------+
//| Gold symbol detection with broker suffix/prefix support          |
//+------------------------------------------------------------------+
bool IsGoldSymbol()
  {
   string symbol = Symbol();

   if(StringFind(symbol, "XAU", 0) >= 0 || StringFind(symbol, "xau", 0) >= 0)
      return(true);
   if(StringFind(symbol, "GOLD", 0) >= 0 || StringFind(symbol, "gold", 0) >= 0)
      return(true);
   if(StringFind(symbol, "Gold", 0) >= 0)
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
//| Convert strategy points to price distance                        |
//+------------------------------------------------------------------+
double PointsToPrice(const int points)
  {
   return(points * _StrategyPoint);
  }

//+------------------------------------------------------------------+
//| Visual zero-wick tolerance in price                              |
//+------------------------------------------------------------------+
double ZeroWickTolerancePrice()
  {
   return(PointsToPrice(ZeroWick_Tolerance_Points));
  }

//+------------------------------------------------------------------+
//| Convert strategy points to broker raw points for slippage        |
//+------------------------------------------------------------------+
int PointsToBrokerPoints(const int points)
  {
   if(points <= 0)
      return(0);

   int brokerPoints = (int)MathFloor((PointsToPrice(points) / Point) + 0.5);
   if(brokerPoints < 1)
      brokerPoints = 1;

   return(brokerPoints);
  }

//+------------------------------------------------------------------+
//| Normalize price to broker digits                                 |
//+------------------------------------------------------------------+
double NormalizePrice(const double price)
  {
   return(NormalizeDouble(price, Digits));
  }

//+------------------------------------------------------------------+
//| Price comparison after broker-digit normalization                |
//+------------------------------------------------------------------+
bool PriceExceeds(const double value, const double limit)
  {
   return(NormalizePrice(value - limit) > 0.0);
  }

//+------------------------------------------------------------------+
//| EMA relation helper                                              |
//+------------------------------------------------------------------+
int GetEMARelation(const int index)
  {
   if(Bars <= index + EMA_Slow_Period)
      return(0);

   double emaFast = iMA(NULL, 0, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, index);
   double emaSlow = iMA(NULL, 0, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, index);

   if(emaFast > emaSlow)
      return(1);
   if(emaFast < emaSlow)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| Find most recent closed-bar EMA cross inside post-cross window   |
//+------------------------------------------------------------------+
bool FindLatestRecentCross(datetime &crossTime, int &crossType, int &barsSinceCross)
  {
   // The cross candle itself is not a setup candle. A valid setup is the
   // 1st through Max_Setup_Candles-th candle closed after the cross candle.
   int maxShift = Max_Setup_Candles + 1;
   int requiredBars = EMA_Slow_Period + EMA_Angle_Lookback_Bars + maxShift + 5;

   if(Bars <= requiredBars)
      return(false);

   for(int shift = 1; shift <= maxShift; shift++)
     {
      int currentRelation = GetEMARelation(shift);
      int previousRelation = GetEMARelation(shift + 1);

      if(currentRelation == 0 || previousRelation == 0)
         continue;

      if(currentRelation != previousRelation)
        {
         crossTime = Time[shift];
         crossType = currentRelation;
         barsSinceCross = shift;
         return(true);
        }
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Detect new closed-bar EMA cross                                  |
//+------------------------------------------------------------------+
void CheckForCrossChange()
  {
   int currentRelation = GetEMARelation(1);
   if(currentRelation == 0)
      return;

   datetime foundCrossTime = 0;
   int foundCrossType = 0;
   int barsSinceCross = 0;

   if(FindLatestRecentCross(foundCrossTime, foundCrossType, barsSinceCross))
     {
      if(foundCrossTime != _crossTime)
        {
         _crossTime = foundCrossTime;
         _lastCrossType = foundCrossType;
         _entryAllowedInCurrentCross = !IsCurrentCrossAlreadyTraded();

         Print("EMA cross synchronized from history. Type=", CrossTypeToText(_lastCrossType),
               ", CrossTime=", TimeToString(_crossTime, TIME_DATE|TIME_MINUTES),
               ", BarsSinceCross=", barsSinceCross,
               ", SetupCandlesAfterCross=", barsSinceCross - 1,
               ", EntryAllowed=", BoolToText(_entryAllowedInCurrentCross),
               ", AlreadyTraded=", BoolToText(IsCurrentCrossAlreadyTraded()));
        }
      else
         _lastCrossType = foundCrossType;

      return;
     }

   _lastCrossType = currentRelation;
  }

//+------------------------------------------------------------------+
//| Recover recent cross state if OnInit/history loading missed it   |
//+------------------------------------------------------------------+
void RefreshRecentCrossStateFromHistory()
  {
   if(_entryAllowedInCurrentCross)
      return;

   datetime foundCrossTime = 0;
   int foundCrossType = 0;
   int barsSinceCross = 0;

   if(!FindLatestRecentCross(foundCrossTime, foundCrossType, barsSinceCross))
      return;

   if(foundCrossTime == _crossTime)
      return;

   _crossTime = foundCrossTime;
   _lastCrossType = foundCrossType;
   _entryAllowedInCurrentCross = !IsCurrentCrossAlreadyTraded();

   Print("Recovered recent EMA cross from history. Type=", CrossTypeToText(_lastCrossType),
         ", CrossTime=", TimeToString(_crossTime, TIME_DATE|TIME_MINUTES),
         ", BarsSinceCross=", barsSinceCross,
         ", SetupCandlesAfterCross=", barsSinceCross - 1,
         ", EntryAllowed=", BoolToText(_entryAllowedInCurrentCross),
         ", AlreadyTraded=", BoolToText(IsCurrentCrossAlreadyTraded()));
  }

//+------------------------------------------------------------------+
//| Check if there is an open EA position                            |
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| No-Wick candle strategy check                                    |
//+------------------------------------------------------------------+
bool IsNoWickCandle(const int index, const int orderType)
  {
   string reason = "";
   return(CheckNoWickCandle(index, orderType, reason));
  }

//+------------------------------------------------------------------+
//| No-Wick candle strategy check with rejection reason              |
//+------------------------------------------------------------------+
bool CheckNoWickCandle(const int index, const int orderType, string &reason)
  {
   reason = "";

   double open = NormalizePrice(Open[index]);
   double close = NormalizePrice(Close[index]);
   double high = NormalizePrice(High[index]);
   double low = NormalizePrice(Low[index]);
   double fullSize = NormalizePrice(high - low);

   if(fullSize <= 0.0)
     {
      reason = "full candle size is zero. " + CandleMetricsText(index);
      return(false);
     }

   double bodySize = MathAbs(close - open);
   if(bodySize <= 0.0)
     {
      reason = "doji body is zero. " + CandleMetricsText(index);
      return(false);
     }

   double minimumBodySize = PointsToPrice(Min_Body_Points);
   if(PriceExceeds(minimumBodySize, bodySize))
     {
      reason = "setup candle body is smaller than minimum. BodySize=" +
               DoubleToString(bodySize, Digits) + ", MinBody=" +
               DoubleToString(minimumBodySize, Digits) + " (" +
               IntegerToString(Min_Body_Points) + " points). " + CandleMetricsText(index);
      return(false);
     }

   double upperWick = NormalizePrice(high - MathMax(open, close));
   double lowerWick = NormalizePrice(MathMin(open, close) - low);
   double zeroWickTolerance = ZeroWickTolerancePrice();

   if(orderType == OP_BUY)
     {
      if(close <= open)
       {
        reason = "BUY requires bullish candle. " + CandleMetricsText(index);
         return(false);
       }

      // Visual no-wick rule: tiny broker tick noise is treated as zero.
      if(PriceExceeds(upperWick, zeroWickTolerance))
       {
        reason = "BUY upper wick exceeds visual zero tolerance. UpperWick=" +
                 DoubleToString(upperWick, Digits) + ", Tolerance=" +
                 DoubleToString(zeroWickTolerance, Digits) + ". " + CandleMetricsText(index);
         return(false);
       }

      if(PriceExceeds(upperWick, lowerWick))
       {
        reason = "BUY lower wick must be equal to or longer than upper wick. UpperWick=" +
                 DoubleToString(upperWick, Digits) + ", LowerWick=" +
                 DoubleToString(lowerWick, Digits) + ". " + CandleMetricsText(index);
         return(false);
       }

      double lowerWickPct = (lowerWick / fullSize) * 100.0;
      if(lowerWickPct > Max_Wick_Percentage)
       {
        reason = "BUY lower wick percentage exceeds limit. LowerWickPct=" +
                 DoubleToString(lowerWickPct, 2) + ", Limit=" +
                 DoubleToString(Max_Wick_Percentage, 2) + ". " + CandleMetricsText(index);
         return(false);
       }
     }
   else if(orderType == OP_SELL)
     {
      if(close >= open)
       {
        reason = "SELL requires bearish candle. " + CandleMetricsText(index);
         return(false);
       }

      // Visual no-wick rule: tiny broker tick noise is treated as zero.
      if(PriceExceeds(lowerWick, zeroWickTolerance))
       {
        reason = "SELL lower wick exceeds visual zero tolerance. LowerWick=" +
                 DoubleToString(lowerWick, Digits) + ", Tolerance=" +
                 DoubleToString(zeroWickTolerance, Digits) + ". " + CandleMetricsText(index);
         return(false);
       }

      if(PriceExceeds(lowerWick, upperWick))
       {
        reason = "SELL upper wick must be equal to or longer than lower wick. UpperWick=" +
                 DoubleToString(upperWick, Digits) + ", LowerWick=" +
                 DoubleToString(lowerWick, Digits) + ". " + CandleMetricsText(index);
         return(false);
       }

      double upperWickPct = (upperWick / fullSize) * 100.0;
      if(upperWickPct > Max_Wick_Percentage)
       {
        reason = "SELL upper wick percentage exceeds limit. UpperWickPct=" +
                 DoubleToString(upperWickPct, 2) + ", Limit=" +
                 DoubleToString(Max_Wick_Percentage, 2) + ". " + CandleMetricsText(index);
         return(false);
       }
     }
   else
     {
      reason = "invalid order type for candle check.";
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Previous setup-direction candle confirmation                     |
//+------------------------------------------------------------------+
bool CheckPreSetupConfirmation(const int setupIndex, const int orderType, string &reason)
  {
   reason = "";

   if(Pre_Setup_Confirm_Candles <= 0)
      return(true);

   for(int offset = 1; offset <= Pre_Setup_Confirm_Candles; offset++)
     {
      int index = setupIndex + offset;
      if(Bars <= index)
        {
         reason = "not enough bars for previous candle confirmation. RequiredPreviousCandles=" +
                  IntegerToString(Pre_Setup_Confirm_Candles);
         return(false);
        }

      double open = NormalizePrice(Open[index]);
      double close = NormalizePrice(Close[index]);
      double high = NormalizePrice(High[index]);
      double low = NormalizePrice(Low[index]);
      double fullSize = NormalizePrice(high - low);
      if(fullSize <= 0.0)
        {
         reason = "previous confirmation candle full size is zero. " + CandleMetricsText(index);
         return(false);
        }

      double bodySize = MathAbs(close - open);
      if(bodySize <= 0.0)
        {
         reason = "previous confirmation candle is doji. " + CandleMetricsText(index);
         return(false);
        }

      double upperWick = NormalizePrice(high - MathMax(open, close));
      double lowerWick = NormalizePrice(MathMin(open, close) - low);
      double totalWick = NormalizePrice(upperWick + lowerWick);

      if(!PriceExceeds(bodySize, totalWick))
        {
         reason = "previous confirmation candle body must be longer than total wicks. BodySize=" +
                  DoubleToString(bodySize, Digits) + ", TotalWick=" +
                  DoubleToString(totalWick, Digits) + ", Offset=" +
                  IntegerToString(offset) + ". " + CandleMetricsText(index);
         return(false);
        }

      if(orderType == OP_SELL)
        {
         if(close >= open)
           {
            reason = "SELL previous confirmation candle must be bearish. Offset=" +
                     IntegerToString(offset) + ". " + CandleMetricsText(index);
            return(false);
           }

         if(!PriceExceeds(upperWick, lowerWick))
           {
            reason = "SELL previous confirmation candle lower wick must be shorter than upper wick. UpperWick=" +
                     DoubleToString(upperWick, Digits) + ", LowerWick=" +
                     DoubleToString(lowerWick, Digits) + ", Offset=" +
                     IntegerToString(offset) + ". " + CandleMetricsText(index);
            return(false);
           }
        }
      else if(orderType == OP_BUY)
        {
         if(close <= open)
           {
            reason = "BUY previous confirmation candle must be bullish. Offset=" +
                     IntegerToString(offset) + ". " + CandleMetricsText(index);
            return(false);
           }

         if(!PriceExceeds(lowerWick, upperWick))
           {
            reason = "BUY previous confirmation candle upper wick must be shorter than lower wick. UpperWick=" +
                     DoubleToString(upperWick, Digits) + ", LowerWick=" +
                     DoubleToString(lowerWick, Digits) + ", Offset=" +
                     IntegerToString(offset) + ". " + CandleMetricsText(index);
            return(false);
           }
        }
      else
        {
         reason = "invalid order type for previous candle confirmation.";
         return(false);
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Candle metrics text for diagnostics                              |
//+------------------------------------------------------------------+
string CandleMetricsText(const int index)
  {
   double open = NormalizePrice(Open[index]);
   double close = NormalizePrice(Close[index]);
   double high = NormalizePrice(High[index]);
   double low = NormalizePrice(Low[index]);
   double fullSize = NormalizePrice(high - low);
   double upperWick = NormalizePrice(high - MathMax(open, close));
   double lowerWick = NormalizePrice(MathMin(open, close) - low);
   double upperPct = 0.0;
   double lowerPct = 0.0;

   if(fullSize > 0.0)
     {
      upperPct = (upperWick / fullSize) * 100.0;
      lowerPct = (lowerWick / fullSize) * 100.0;
     }

   return("Time=" + TimeToString(Time[index], TIME_DATE|TIME_MINUTES) +
          ", O=" + DoubleToString(open, Digits) +
          ", H=" + DoubleToString(high, Digits) +
          ", L=" + DoubleToString(low, Digits) +
          ", C=" + DoubleToString(close, Digits) +
          ", UpperWick=" + DoubleToString(upperWick, Digits) +
          " (" + DoubleToString(upperPct, 2) + "%)" +
          ", LowerWick=" + DoubleToString(lowerWick, Digits) +
          " (" + DoubleToString(lowerPct, 2) + "%)");
  }

//+------------------------------------------------------------------+
//| 9 EMA angle helper                                               |
//+------------------------------------------------------------------+
double GetEMAAngle(const int period, const int index)
  {
   int previousIndex = index + EMA_Angle_Lookback_Bars;
   if(Bars <= previousIndex + period)
      return(0.0);

   double emaCurrent = iMA(NULL, 0, period, 0, MODE_EMA, PRICE_CLOSE, index);
   double emaPrevious = iMA(NULL, 0, period, 0, MODE_EMA, PRICE_CLOSE, previousIndex);
   double dyPoints = (emaCurrent - emaPrevious) / _StrategyPoint;
   double dxBars = EMA_Angle_Lookback_Bars;

   return(MathArctan(dyPoints / dxBars) * 180.0 / IDC_PI);
  }

//+------------------------------------------------------------------+
//| Entry condition check                                            |
//+------------------------------------------------------------------+
void CheckForEntry()
  {
   if(_crossTime <= 0)
     {
      DebugEntryLog("No entry check: no valid EMA cross inside setup window.");
      return;
     }

   int barsSinceCross = iBarShift(NULL, 0, _crossTime, true);
   if(barsSinceCross < 0)
     {
      _entryAllowedInCurrentCross = false;
      DebugEntryLog("Entry disabled: cross time was not found on current chart. CrossTime=" +
                    TimeToString(_crossTime, TIME_DATE|TIME_MINUTES));
      return;
     }

   int setupCandlesAfterCross = barsSinceCross - 1;
   if(setupCandlesAfterCross <= 0)
     {
      DebugEntryLog("Entry skipped: EMA cross candle itself is not a valid setup candle. BarsSinceCross=" +
                    IntegerToString(barsSinceCross) + ", SetupCandlesAfterCross=" +
                    IntegerToString(setupCandlesAfterCross));
      return;
     }

   if(setupCandlesAfterCross > Max_Setup_Candles)
     {
      _entryAllowedInCurrentCross = false;
      DebugEntryLog("Entry disabled: post-cross setup window expired. SetupCandlesAfterCross=" +
                    IntegerToString(setupCandlesAfterCross) + ", Max=" +
                    IntegerToString(Max_Setup_Candles));
      return;
     }

   if(IsCurrentCrossAlreadyTraded())
     {
      _entryAllowedInCurrentCross = false;
      DebugEntryLog("Entry disabled: this EMA cross was already traded. CrossTime=" +
                    TimeToString(_crossTime, TIME_DATE|TIME_MINUTES));
      return;
     }

   int currentRelation = GetEMARelation(1);
   double angle = GetEMAAngle(EMA_Fast_Period, 1);

   if(currentRelation == 1)
     {
      if(!EnableBuy)
        {
         DebugEntryLog("BUY skipped: EnableBuy is false.");
         return;
        }

      string buyCandleReason = "";
      if(!CheckNoWickCandle(1, OP_BUY, buyCandleReason))
        {
         DebugEntryLog("BUY rejected by No-Wick filter. " + buyCandleReason);
         return;
        }

      string buyPreSetupReason = "";
      if(!CheckPreSetupConfirmation(1, OP_BUY, buyPreSetupReason))
        {
         DebugEntryLog("BUY rejected by previous candle confirmation. " + buyPreSetupReason);
         return;
        }

      if(angle < EMA_Angle_Threshold)
        {
         DebugEntryLog("BUY rejected by EMA angle. Angle=" +
                       DoubleToString(angle, 2) + ", Required>=" +
                       DoubleToString(EMA_Angle_Threshold, 2));
         return;
        }

      if(OpenPosition(OP_BUY))
        {
         MarkCurrentCrossAsTraded();
         _entryAllowedInCurrentCross = false;
        }

      return;
     }

   if(currentRelation == -1)
     {
      if(!EnableSell)
        {
         DebugEntryLog("SELL skipped: EnableSell is false.");
         return;
        }

      string sellCandleReason = "";
      if(!CheckNoWickCandle(1, OP_SELL, sellCandleReason))
        {
         DebugEntryLog("SELL rejected by No-Wick filter. " + sellCandleReason);
         return;
        }

      string sellPreSetupReason = "";
      if(!CheckPreSetupConfirmation(1, OP_SELL, sellPreSetupReason))
        {
         DebugEntryLog("SELL rejected by previous candle confirmation. " + sellPreSetupReason);
         return;
        }

      if(angle > -EMA_Angle_Threshold)
        {
         DebugEntryLog("SELL rejected by EMA angle. Angle=" +
                       DoubleToString(angle, 2) + ", Required<=" +
                       DoubleToString(-EMA_Angle_Threshold, 2));
         return;
        }

      if(OpenPosition(OP_SELL))
        {
         MarkCurrentCrossAsTraded();
         _entryAllowedInCurrentCross = false;
        }

      return;
     }

   DebugEntryLog("Entry rejected: EMA relation is flat/equal on closed candle.");
  }

//+------------------------------------------------------------------+
//| Entry diagnostics                                                |
//+------------------------------------------------------------------+
void DebugEntryLog(const string message)
  {
   if(!EnableEntryDebugLog)
      return;

   Print("IDC_ENTRY_DEBUG: ", message,
         " ClosedBar=", TimeToString(Time[1], TIME_DATE|TIME_MINUTES),
         ", CrossTime=", TimeToString(_crossTime, TIME_DATE|TIME_MINUTES),
         ", CrossType=", CrossTypeToText(_lastCrossType));
  }

//+------------------------------------------------------------------+
//| Entry gate state diagnostics                                     |
//+------------------------------------------------------------------+
string EntryGateStateText()
  {
   int barsSinceCross = -1;
   int setupCandlesAfterCross = -1;
   string crossTimeText = "none";
   string alreadyTradedText = "false";

   if(_crossTime > 0)
     {
      barsSinceCross = iBarShift(NULL, 0, _crossTime, true);
      setupCandlesAfterCross = barsSinceCross - 1;
      crossTimeText = TimeToString(_crossTime, TIME_DATE|TIME_MINUTES);
      alreadyTradedText = BoolToText(IsCurrentCrossAlreadyTraded());
     }

   return("EntryAllowed=" + BoolToText(_entryAllowedInCurrentCross) +
          ", LastCrossType=" + CrossTypeToText(_lastCrossType) +
          ", CrossTime=" + crossTimeText +
          ", BarsSinceCross=" + IntegerToString(barsSinceCross) +
          ", SetupCandlesAfterCross=" + IntegerToString(setupCandlesAfterCross) +
          ", MaxSetupCandles=" + IntegerToString(Max_Setup_Candles) +
          ", AlreadyTraded=" + alreadyTradedText +
          ", CurrentRelation=" + CrossTypeToText(GetEMARelation(1)));
  }

//+------------------------------------------------------------------+
//| Open position with exact configured SL distance                  |
//+------------------------------------------------------------------+
bool OpenPosition(const int orderType)
  {
   RefreshRates();

   double entryPrice = (orderType == OP_BUY) ? Ask : Bid;
   double requestedSL = CalculateInitialStopLoss(orderType, entryPrice);
   int slippagePoints = PointsToBrokerPoints(Slippage);
   color orderColor = (orderType == OP_BUY) ? clrLime : clrRed;
   string orderComment = (orderType == OP_BUY) ? "IDC_NOWICK_BUY" : "IDC_NOWICK_SELL";

   if(!CanPlaceStopLoss(orderType, requestedSL))
     {
      Print("Order blocked before send: configured initial SL is not legal right now. Type=",
            OrderTypeToText(orderType),
            ", Entry=", DoubleToString(entryPrice, Digits),
            ", RequestedSL=", DoubleToString(requestedSL, Digits),
            ", StopLossPoints=", StopLoss_Points);
      return(false);
     }

   ResetLastError();
   int ticket = OrderSend(Symbol(), orderType, LotSize, NormalizePrice(entryPrice),
                          slippagePoints, requestedSL, 0, orderComment, MagicNumber, 0, orderColor);

   if(ticket < 0)
     {
      Print("OrderSend failed. Type=", OrderTypeToText(orderType),
            ", Error=", GetLastError());
      return(false);
     }

   if(!SelectOrderWithRetries(ticket))
     {
      Print("OrderSelect failed after OrderSend. Ticket=", ticket,
            ", Error=", GetLastError(),
            ". Protection monitor will continue scanning open orders.");
      MarkCurrentCrossAsTraded();
      _entryAllowedInCurrentCross = false;
      return(false);
     }

   double openPrice = OrderOpenPrice();
   double exactSL = CalculateInitialStopLoss(orderType, openPrice);

   RefreshRates();
   if(!CanPlaceStopLoss(orderType, exactSL))
     {
      Print("Exact initial SL cannot be placed after fill because of broker stop/freeze level. Ticket=", ticket,
            ", RequestedSL=", DoubleToString(exactSL, Digits),
            ", StopLossPoints=", StopLoss_Points);
      CloseUnprotectedPosition(ticket);
      MarkCurrentCrossAsTraded();
      _entryAllowedInCurrentCross = false;
      return(false);
     }

   if(!AttachStopLossWithRetries(ticket, exactSL, orderColor, "initial exact SL"))
     {
      CloseUnprotectedPosition(ticket);
      MarkCurrentCrossAsTraded();
      _entryAllowedInCurrentCross = false;
      return(false);
     }

   Print("Entry completed. Type=", OrderTypeToText(orderType),
         ", Ticket=", ticket,
         ", Open=", DoubleToString(openPrice, Digits),
         ", SL=", DoubleToString(exactSL, Digits),
         ", StrategySLPoints=", StopLoss_Points);

   return(true);
  }

//+------------------------------------------------------------------+
//| Initial SL calculation                                           |
//+------------------------------------------------------------------+
double CalculateInitialStopLoss(const int orderType, const double openPrice)
  {
   double gap = PointsToPrice(StopLoss_Points);

   if(orderType == OP_BUY)
      return(NormalizePrice(openPrice - gap));

   return(NormalizePrice(openPrice + gap));
  }

//+------------------------------------------------------------------+
//| Broker stop/freeze distance                                      |
//+------------------------------------------------------------------+
double MinimumStopDistance()
  {
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double freezeLevel = MarketInfo(Symbol(), MODE_FREEZELEVEL) * Point;

   if(stopLevel < 0.0)
      stopLevel = 0.0;
   if(freezeLevel < 0.0)
      freezeLevel = 0.0;

   return(MathMax(stopLevel, freezeLevel));
  }

//+------------------------------------------------------------------+
//| Check whether an SL price is legal right now                     |
//+------------------------------------------------------------------+
bool CanPlaceStopLoss(const int orderType, const double slPrice)
  {
   double minDistance = MinimumStopDistance();

   RefreshRates();

   if(orderType == OP_BUY)
     {
      if(slPrice >= Bid)
         return(false);
      if((Bid - slPrice) < minDistance)
         return(false);
     }
   else if(orderType == OP_SELL)
     {
      if(slPrice <= Ask)
         return(false);
      if((slPrice - Ask) < minDistance)
         return(false);
     }
   else
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| Select an order with retries after trade operations              |
//+------------------------------------------------------------------+
bool SelectOrderWithRetries(const int ticket)
  {
   for(int attempt = 1; attempt <= ProtectionRetryCount; attempt++)
     {
      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
         return(true);

      RefreshRates();
      Sleep(100);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Attach or correct SL with retries                                |
//+------------------------------------------------------------------+
bool AttachStopLossWithRetries(const int ticket, const double targetSL,
                               const color arrowColor, const string context)
  {
   double normalizedSL = NormalizePrice(targetSL);

   for(int attempt = 1; attempt <= ProtectionRetryCount; attempt++)
     {
      if(!SelectOrderWithRetries(ticket))
        {
         Print("SL protection select retry failed. Context=", context,
               ", Ticket=", ticket,
               ", Attempt=", attempt,
               ", Error=", GetLastError());
         Sleep(100);
         continue;
        }

      if(OrderCloseTime() > 0)
         return(true);

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         return(false);

      double currentSL = NormalizePrice(OrderStopLoss());
      if(currentSL != 0.0 && NormalizePrice(MathAbs(currentSL - normalizedSL)) <= 0.0)
         return(true);

      RefreshRates();
      if(!CanPlaceStopLoss(orderType, normalizedSL))
        {
         Print("SL protection cannot place stop right now. Context=", context,
               ", Ticket=", ticket,
               ", Attempt=", attempt,
               ", TargetSL=", DoubleToString(normalizedSL, Digits));
         Sleep(150);
         continue;
        }

      ResetLastError();
      bool modified = OrderModify(ticket, OrderOpenPrice(), normalizedSL,
                                  OrderTakeProfit(), 0, arrowColor);
      if(modified)
         return(true);

      Print("SL protection OrderModify failed. Context=", context,
            ", Ticket=", ticket,
            ", Attempt=", attempt,
            ", TargetSL=", DoubleToString(normalizedSL, Digits),
            ", Error=", GetLastError());
      Sleep(150);
     }

   Print("CRITICAL: SL protection failed after retries. Context=", context,
         ", Ticket=", ticket,
         ", TargetSL=", DoubleToString(normalizedSL, Digits),
         ". Forced close will be attempted.");

   return(false);
  }

//+------------------------------------------------------------------+
//| Monitor and resolve any position without SL                      |
//+------------------------------------------------------------------+
void ManageUnprotectedPositions()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      if(OrderStopLoss() != 0.0)
         continue;

      int ticket = OrderTicket();
      double emergencySL = CalculateInitialStopLoss(orderType, OrderOpenPrice());
      color arrowColor = (orderType == OP_BUY) ? clrLime : clrRed;

      Print("CRITICAL: Unprotected position detected. Ticket=", ticket,
            ", Type=", OrderTypeToText(orderType),
            ", Open=", DoubleToString(OrderOpenPrice(), Digits),
            ", EmergencySL=", DoubleToString(emergencySL, Digits));

      if(AttachStopLossWithRetries(ticket, emergencySL, arrowColor, "unprotected position monitor"))
         continue;

      CloseUnprotectedPosition(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Close position if exact initial SL could not be attached         |
//+------------------------------------------------------------------+
bool CloseUnprotectedPosition(const int ticket)
  {
   for(int attempt = 1; attempt <= ProtectionRetryCount; attempt++)
     {
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
         RefreshRates();
         Sleep(150);
         continue;
        }

      if(OrderCloseTime() > 0)
         return(true);

      RefreshRates();

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         return(false);

      double closePrice = (orderType == OP_BUY) ? Bid : Ask;
      int slippagePoints = PointsToBrokerPoints(Slippage);

      ResetLastError();
      bool closed = OrderClose(ticket, OrderLots(), NormalizePrice(closePrice), slippagePoints, clrOrange);
      if(closed)
        {
         DeleteVirtualTrailingGuard(ticket);
         return(true);
        }

      Print("Forced close retry failed for unprotected position. Ticket=", ticket,
            ", Attempt=", attempt,
            ", Error=", GetLastError());
      Sleep(200);
     }

   Print("CRITICAL: Failed to close unprotected position after retries. Ticket=", ticket,
         ". Protection monitor will retry on the next tick.");

   return(false);
  }

//+------------------------------------------------------------------+
//| Virtual trailing guard key                                       |
//+------------------------------------------------------------------+
string VirtualTrailKey(const int ticket)
  {
   return("IDC_GOLD_NOWICK_SNIPER." +
          IntegerToString(AccountNumber()) + "." +
          Symbol() + "." +
          IntegerToString(Period()) + "." +
          IntegerToString(MagicNumber) + "." +
          IntegerToString(ticket) + ".VIRTUAL_TRAIL_SL");
  }

//+------------------------------------------------------------------+
//| Arm/update virtual protected stop                                |
//+------------------------------------------------------------------+
void ArmVirtualTrailingGuard(const int ticket, const int orderType, const double targetSL)
  {
   if(!EnableVirtualTrailingGuard)
      return;

   double normalizedTarget = NormalizePrice(targetSL);
   string key = VirtualTrailKey(ticket);
   bool shouldUpdate = true;

   if(GlobalVariableCheck(key))
     {
      double currentTarget = NormalizePrice(GlobalVariableGet(key));
      if(orderType == OP_BUY && normalizedTarget <= currentTarget)
         shouldUpdate = false;
      if(orderType == OP_SELL && normalizedTarget >= currentTarget)
         shouldUpdate = false;
     }

   if(!shouldUpdate)
      return;

   GlobalVariableSet(key, normalizedTarget);
   Print("Virtual trailing guard armed. Ticket=", ticket,
         ", Type=", OrderTypeToText(orderType),
         ", GuardPrice=", DoubleToString(normalizedTarget, Digits));
  }

//+------------------------------------------------------------------+
//| Delete virtual protected stop                                    |
//+------------------------------------------------------------------+
void DeleteVirtualTrailingGuard(const int ticket)
  {
   string key = VirtualTrailKey(ticket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
  }

//+------------------------------------------------------------------+
//| Monitor virtual trailing guards and close on guard touch         |
//+------------------------------------------------------------------+
void ManageVirtualTrailingGuards()
  {
   if(!EnableVirtualTrailingGuard)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      int ticket = OrderTicket();
      string key = VirtualTrailKey(ticket);
      if(!GlobalVariableCheck(key))
         continue;

      double guardPrice = NormalizePrice(GlobalVariableGet(key));
      RefreshRates();

      bool shouldClose = false;
      double closePrice = 0.0;

      if(orderType == OP_BUY)
        {
         if(Bid <= guardPrice)
           {
            shouldClose = true;
            closePrice = Bid;
           }
        }
      else if(orderType == OP_SELL)
        {
         if(Ask >= guardPrice)
           {
            shouldClose = true;
            closePrice = Ask;
           }
        }

      if(!shouldClose)
         continue;

      Print("Virtual trailing guard touched. Ticket=", ticket,
            ", Type=", OrderTypeToText(orderType),
            ", GuardPrice=", DoubleToString(guardPrice, Digits),
            ", ClosePrice=", DoubleToString(closePrice, Digits));

      if(ClosePositionWithRetries(ticket, "virtual trailing guard"))
         DeleteVirtualTrailingGuard(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Close position with retries                                      |
//+------------------------------------------------------------------+
bool ClosePositionWithRetries(const int ticket, const string context)
  {
   for(int attempt = 1; attempt <= ProtectionRetryCount; attempt++)
     {
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
         RefreshRates();
         Sleep(150);
         continue;
        }

      if(OrderCloseTime() > 0)
         return(true);

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         return(false);

      RefreshRates();
      double closePrice = (orderType == OP_BUY) ? Bid : Ask;
      int slippagePoints = PointsToBrokerPoints(Slippage);

      ResetLastError();
      bool closed = OrderClose(ticket, OrderLots(), NormalizePrice(closePrice), slippagePoints, clrYellow);
      if(closed)
        {
         DeleteVirtualTrailingGuard(ticket);
         return(true);
        }

      Print("Position close retry failed. Context=", context,
            ", Ticket=", ticket,
            ", Attempt=", attempt,
            ", Error=", GetLastError());
      Sleep(200);
     }

   Print("CRITICAL: Failed to close position after retries. Context=", context,
         ", Ticket=", ticket,
         ". EA will retry on the next tick if condition remains active.");

   return(false);
  }

//+------------------------------------------------------------------+
//| Jumping stop trailing logic                                      |
//+------------------------------------------------------------------+
void ManageTrailing()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      RefreshRates();

      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double triggerGap = PointsToPrice(TrailingStart_Points);
      double stepGap = PointsToPrice(TrailingStep_Points);
      double currentProfit = 0.0;
      double newSL = 0.0;

      if(orderType == OP_BUY)
        {
         currentProfit = Bid - openPrice;
         if(currentProfit < triggerGap)
            continue;

         newSL = openPrice + triggerGap;
         if(currentProfit >= triggerGap + stepGap)
           {
            int steps = (int)MathFloor((currentProfit - triggerGap) / stepGap);
            newSL = openPrice + triggerGap + (steps * stepGap);
           }

         newSL = NormalizePrice(newSL);
         ArmVirtualTrailingGuard(OrderTicket(), orderType, newSL);

         if(currentSL != 0.0 && newSL <= currentSL)
            continue;

         if(CanPlaceStopLoss(orderType, newSL))
           {
            if(!ModifyTrailingStop(newSL, clrLime))
               ClosePositionWithRetries(OrderTicket(), "protected BUY trailing SL modify failure");
           }
         else
           {
            Print("Protected BUY trailing server SL is not legal; closing to prevent protected profit loss. Ticket=",
                  OrderTicket(),
                  ", TargetSL=", DoubleToString(newSL, Digits));
            ClosePositionWithRetries(OrderTicket(), "protected BUY trailing SL not legal");
           }
        }
      else if(orderType == OP_SELL)
        {
         currentProfit = openPrice - Ask;
         if(currentProfit < triggerGap)
            continue;

         newSL = openPrice - triggerGap;
         if(currentProfit >= triggerGap + stepGap)
           {
            int steps = (int)MathFloor((currentProfit - triggerGap) / stepGap);
            newSL = openPrice - triggerGap - (steps * stepGap);
           }

         newSL = NormalizePrice(newSL);
         ArmVirtualTrailingGuard(OrderTicket(), orderType, newSL);

         if(currentSL != 0.0 && newSL >= currentSL)
            continue;

         if(CanPlaceStopLoss(orderType, newSL))
           {
            if(!ModifyTrailingStop(newSL, clrRed))
               ClosePositionWithRetries(OrderTicket(), "protected SELL trailing SL modify failure");
           }
         else
           {
            Print("Protected SELL trailing server SL is not legal; closing to prevent protected profit loss. Ticket=",
                  OrderTicket(),
                  ", TargetSL=", DoubleToString(newSL, Digits));
            ClosePositionWithRetries(OrderTicket(), "protected SELL trailing SL not legal");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Modify selected order trailing SL                                |
//+------------------------------------------------------------------+
bool ModifyTrailingStop(const double newSL, const color arrowColor)
  {
   int ticket = OrderTicket();
   double openPrice = OrderOpenPrice();
   double takeProfit = OrderTakeProfit();

   ResetLastError();
   bool modified = OrderModify(ticket, openPrice, newSL, takeProfit, 0, arrowColor);
   if(!modified)
      Print("Trailing OrderModify failed. Ticket=", ticket,
            ", NewSL=", DoubleToString(newSL, Digits),
            ", Error=", GetLastError());

   return(modified);
  }

//+------------------------------------------------------------------+
//| Persistent cycle-limit state                                     |
//+------------------------------------------------------------------+
string CrossStateKey()
  {
   return("IDC_GOLD_NOWICK_SNIPER." +
          IntegerToString(AccountNumber()) + "." +
          Symbol() + "." +
          IntegerToString(Period()) + "." +
          IntegerToString(MagicNumber) + ".LAST_TRADED_CROSS");
  }

//+------------------------------------------------------------------+
//| Check persistent current-cross traded state                      |
//+------------------------------------------------------------------+
bool IsCurrentCrossAlreadyTraded()
  {
   if(_crossTime <= 0)
      return(false);

   string key = CrossStateKey();
   if(!GlobalVariableCheck(key))
      return(false);

   datetime tradedCrossTime = (datetime)GlobalVariableGet(key);
   return(tradedCrossTime == _crossTime);
  }

//+------------------------------------------------------------------+
//| Mark current cross as traded                                     |
//+------------------------------------------------------------------+
void MarkCurrentCrossAsTraded()
  {
   if(_crossTime <= 0)
      return;

   GlobalVariableSet(CrossStateKey(), (double)_crossTime);
  }

//+------------------------------------------------------------------+
//| Text helpers                                                     |
//+------------------------------------------------------------------+
string BoolToText(const bool value)
  {
   if(value)
      return("true");

   return("false");
  }

//+------------------------------------------------------------------+
//| Cross text helper                                                |
//+------------------------------------------------------------------+
string CrossTypeToText(const int crossType)
  {
   if(crossType > 0)
      return("GOLDEN");
   if(crossType < 0)
      return("DEAD");

   return("NONE");
  }

//+------------------------------------------------------------------+
//| Order type text helper                                           |
//+------------------------------------------------------------------+
string OrderTypeToText(const int orderType)
  {
   if(orderType == OP_BUY)
      return("BUY");
   if(orderType == OP_SELL)
      return("SELL");

   return("UNKNOWN");
  }
//+------------------------------------------------------------------+
