//+------------------------------------------------------------------+
//|                                      IDC_GOLD_NoWick_Angle_Sniper |
//|                        No-Wick Angle Sniper strategy for MT4      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
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
input double Max_Wick_Percentage = 20.0;
input int    ZeroWick_Tolerance_Points = 2; // Treat tiny visual/noise wicks as zero. Gold: 2 points = 0.02 price.
input int    StopLoss_Points = 200;       // Gold standard: 200 points = 2.00 price.
input int    TrailingStart_Points = 200;  // First secured profit distance from entry.
input int    TrailingStep_Points = 300;   // Jumping trailing interval after first secure point.
input bool   EnableBuy = true;
input bool   EnableSell = true;
input bool   EnableEntryDebugLog = true;  // Print exact filter rejection reasons on closed bars.

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
         ", ZeroWickTolerancePoints=", ZeroWick_Tolerance_Points,
         ", ZeroWickTolerancePrice=", DoubleToString(ZeroWickTolerancePrice(), Digits),
         ", AngleThreshold=", DoubleToString(EMA_Angle_Threshold, 2),
         ", AngleLookbackBars=", EMA_Angle_Lookback_Bars,
         ", CrossTime=", TimeToString(_crossTime, TIME_DATE|TIME_MINUTES),
         ", EntryAllowed=", BoolToText(_entryAllowedInCurrentCross));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageTrailing();

   static datetime lastBarTime = 0;
   if(lastBarTime == Time[0])
      return;

   lastBarTime = Time[0];

   CheckForCrossChange();

   if(!HasOpenPosition() && _entryAllowedInCurrentCross)
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
//| Find most recent closed-bar EMA cross inside setup window        |
//+------------------------------------------------------------------+
bool FindLatestRecentCross(datetime &crossTime, int &crossType, int &barsSinceCross)
  {
   int maxShift = Max_Setup_Candles;
   int requiredBars = EMA_Slow_Period + EMA_Angle_Lookback_Bars + Max_Setup_Candles + 5;

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

   if(_lastCrossType == 0)
     {
      _lastCrossType = currentRelation;
      return;
     }

   if(currentRelation != _lastCrossType)
     {
      _lastCrossType = currentRelation;
      _crossTime = Time[1];
      _entryAllowedInCurrentCross = !IsCurrentCrossAlreadyTraded();

      Print("New EMA cross detected. Type=", CrossTypeToText(_lastCrossType),
            ", CrossTime=", TimeToString(_crossTime, TIME_DATE|TIME_MINUTES),
            ", EntryAllowed=", BoolToText(_entryAllowedInCurrentCross));
     }
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
      if(upperWick > zeroWickTolerance)
       {
        reason = "BUY upper wick exceeds visual zero tolerance. UpperWick=" +
                 DoubleToString(upperWick, Digits) + ", Tolerance=" +
                 DoubleToString(zeroWickTolerance, Digits) + ". " + CandleMetricsText(index);
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
      if(lowerWick > zeroWickTolerance)
       {
        reason = "SELL lower wick exceeds visual zero tolerance. LowerWick=" +
                 DoubleToString(lowerWick, Digits) + ", Tolerance=" +
                 DoubleToString(zeroWickTolerance, Digits) + ". " + CandleMetricsText(index);
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

   if(barsSinceCross > Max_Setup_Candles)
     {
      _entryAllowedInCurrentCross = false;
      DebugEntryLog("Entry disabled: setup window expired. BarsSinceCross=" +
                    IntegerToString(barsSinceCross) + ", Max=" +
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
//| Open position with exact configured SL distance                  |
//+------------------------------------------------------------------+
bool OpenPosition(const int orderType)
  {
   RefreshRates();

   double entryPrice = (orderType == OP_BUY) ? Ask : Bid;
   int slippagePoints = PointsToBrokerPoints(Slippage);
   color orderColor = (orderType == OP_BUY) ? clrLime : clrRed;
   string orderComment = (orderType == OP_BUY) ? "IDC_NOWICK_BUY" : "IDC_NOWICK_SELL";

   ResetLastError();
   int ticket = OrderSend(Symbol(), orderType, LotSize, NormalizePrice(entryPrice),
                          slippagePoints, 0, 0, orderComment, MagicNumber, 0, orderColor);

   if(ticket < 0)
     {
      Print("OrderSend failed. Type=", OrderTypeToText(orderType),
            ", Error=", GetLastError());
      return(false);
     }

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
     {
      Print("OrderSelect failed after OrderSend. Ticket=", ticket,
            ", Error=", GetLastError());
      return(false);
     }

   double openPrice = OrderOpenPrice();
   double exactSL = CalculateInitialStopLoss(orderType, openPrice);

   RefreshRates();
   if(!CanPlaceStopLoss(orderType, exactSL))
     {
      Print("Exact initial SL cannot be placed because of broker stop/freeze level. Ticket=", ticket,
            ", RequestedSL=", DoubleToString(exactSL, Digits),
            ", StopLossPoints=", StopLoss_Points);
      CloseUnprotectedPosition(ticket);
      return(false);
     }

   ResetLastError();
   bool modified = OrderModify(ticket, openPrice, exactSL, 0, 0, orderColor);
   if(!modified)
     {
      Print("Initial exact SL OrderModify failed. Ticket=", ticket,
            ", SL=", DoubleToString(exactSL, Digits),
            ", Error=", GetLastError());
      CloseUnprotectedPosition(ticket);
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
//| Close position if exact initial SL could not be attached         |
//+------------------------------------------------------------------+
bool CloseUnprotectedPosition(const int ticket)
  {
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return(false);

   RefreshRates();

   int orderType = OrderType();
   double closePrice = (orderType == OP_BUY) ? Bid : Ask;
   int slippagePoints = PointsToBrokerPoints(Slippage);

   ResetLastError();
   bool closed = OrderClose(ticket, OrderLots(), NormalizePrice(closePrice), slippagePoints, clrOrange);
   if(!closed)
      Print("Failed to close unprotected position. Ticket=", ticket,
            ", Error=", GetLastError());

   return(closed);
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
         if(currentSL != 0.0 && newSL <= currentSL)
            continue;

         if(CanPlaceStopLoss(orderType, newSL))
            ModifyTrailingStop(newSL, clrLime);
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
         if(currentSL != 0.0 && newSL >= currentSL)
            continue;

         if(CanPlaceStopLoss(orderType, newSL))
            ModifyTrailingStop(newSL, clrRed);
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
