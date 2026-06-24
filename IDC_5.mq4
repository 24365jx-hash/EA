#property strict

#property copyright "IDC_5"
#property link      ""
#property version   "1.07"
#property description "GOLD M1 strict swing false-breakout pinbar strategy"

input double Lots                     = 0.10;
input int    MagicNumber              = 505;
input int    SlippagePoints           = 30;
input int    StopLossPoints           = 200;
input int    TrailingStartPoints      = 200;
input int    TrailingStepPoints       = 10;
input int    SwingDepthBars           = 3;
input int    SwingSearchBars          = 120;
input int    MinFalseBreakoutPoints   = 1;
input int    MinTailPoints            = 30;
input double MinSignalWickPercent     = 50.0;
input bool   DebugSignalFilters       = true;

string EA_NAME = "IDC_5";
datetime lastM1BarTime = 0;
int pendingEntryType = -1;
int pendingEntryBarsRemaining = 0;
double pendingReferenceLevel = 0.0;
datetime pendingReferenceTime = 0;
int lastTradedType = -1;
datetime lastTradedReferenceTime = 0;

int OnInit()
{
   if(Lots <= 0.0)
   {
      Print(EA_NAME, ": Lots must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(MagicNumber <= 0)
   {
      Print(EA_NAME, ": MagicNumber must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(SlippagePoints < 0)
   {
      Print(EA_NAME, ": SlippagePoints cannot be negative.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(StopLossPoints <= 0)
   {
      Print(EA_NAME, ": StopLossPoints must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(TrailingStartPoints <= 0 || TrailingStepPoints <= 0)
   {
      Print(EA_NAME, ": trailing values must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(SwingDepthBars < 1)
   {
      Print(EA_NAME, ": SwingDepthBars must be at least 1.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(SwingSearchBars < 1)
   {
      Print(EA_NAME, ": SwingSearchBars must be at least 1.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(MinFalseBreakoutPoints < 1 || MinTailPoints < 0)
   {
      Print(EA_NAME, ": MinFalseBreakoutPoints must be >= 1 and MinTailPoints cannot be negative.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(MinSignalWickPercent <= 0.0 || MinSignalWickPercent > 100.0)
   {
      Print(EA_NAME, ": MinSignalWickPercent must be between 0 and 100.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(Period() != PERIOD_M1)
      Print(EA_NAME, ": attach to M1. Entries are disabled on non-M1 charts.");

   lastM1BarTime = iTime(Symbol(), PERIOD_M1, 0);
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   ManageTrailingStops();

   if(Period() != PERIOD_M1)
      return;

   datetime currentBarTime = iTime(Symbol(), PERIOD_M1, 0);
   if(currentBarTime == 0 || currentBarTime == lastM1BarTime)
      return;

   lastM1BarTime = currentBarTime;
   EvaluateClosedSetupCandle();
}

void EvaluateClosedSetupCandle()
{
   int requiredBars = SwingDepthBars * 2 + SwingSearchBars + 5;
   if(iBars(Symbol(), PERIOD_M1) < requiredBars)
   {
      DebugSignal("blocked: not enough M1 bars for swing search.");
      return;
   }

   if(CountOpenPositions() > 0)
   {
      ClearPendingEntry();
      DebugSignal("blocked: existing position for symbol/magic.");
      return;
   }

   if(HasPendingEntry())
   {
      if(ProcessPendingEntry())
         return;
   }

   double swingLow = 0.0;
   datetime swingLowTime = 0;
   if(FindMostRecentValidSwingLow(swingLow, swingLowTime) && IsBuySetupAtLevel(swingLow))
   {
      if(WasReferenceTraded(OP_BUY, swingLowTime))
      {
         DebugSignal("BUY blocked: same swing low reference already traded.");
         return;
      }

      if(IsBuyColorCandle(1))
      {
         if(OpenTrade(OP_BUY))
            MarkReferenceTraded(OP_BUY, swingLowTime);
      }
      else if(ShouldWaitForBuyColor(1))
         StartPendingEntry(OP_BUY, swingLow, swingLowTime);
      else
         DebugSignal("BUY blocked: setup candle is unsupported doji for buy color rule.");
      return;
   }

   double swingHigh = 0.0;
   datetime swingHighTime = 0;
   if(FindMostRecentValidSwingHigh(swingHigh, swingHighTime) && IsSellSetupAtLevel(swingHigh))
   {
      if(WasReferenceTraded(OP_SELL, swingHighTime))
      {
         DebugSignal("SELL blocked: same swing high reference already traded.");
         return;
      }

      if(IsSellColorCandle(1))
      {
         if(OpenTrade(OP_SELL))
            MarkReferenceTraded(OP_SELL, swingHighTime);
      }
      else if(ShouldWaitForSellColor(1))
         StartPendingEntry(OP_SELL, swingHigh, swingHighTime);
      else
         DebugSignal("SELL blocked: setup candle is unsupported doji for sell color rule.");
      return;
   }
}

bool HasPendingEntry()
{
   return((pendingEntryType == OP_BUY || pendingEntryType == OP_SELL) &&
          pendingEntryBarsRemaining > 0 && pendingReferenceTime > 0);
}

void StartPendingEntry(int orderType, double referenceLevel, datetime referenceTime)
{
   pendingEntryType = orderType;
   pendingEntryBarsRemaining = 2;
   pendingReferenceLevel = referenceLevel;
   pendingReferenceTime = referenceTime;
   DebugSignal(StringFormat("pending %s started. reference=%s barsRemaining=%d",
                            OrderTypeName(orderType), PriceText(referenceLevel), pendingEntryBarsRemaining));
}

void ClearPendingEntry()
{
   pendingEntryType = -1;
   pendingEntryBarsRemaining = 0;
   pendingReferenceLevel = 0.0;
   pendingReferenceTime = 0;
}

bool ProcessPendingEntry()
{
   if(pendingEntryType == OP_BUY)
   {
      if(iClose(Symbol(), PERIOD_M1, 1) <= pendingReferenceLevel)
      {
         DebugSignal("pending BUY cancelled: candle closed back below/equal reference swing low.");
         ClearPendingEntry();
         return(false);
      }
      if(IsBuyColorCandle(1))
      {
         datetime referenceTime = pendingReferenceTime;
         ClearPendingEntry();
         if(OpenTrade(OP_BUY))
            MarkReferenceTraded(OP_BUY, referenceTime);
         return(true);
      }
   }
   else if(pendingEntryType == OP_SELL)
   {
      if(iClose(Symbol(), PERIOD_M1, 1) >= pendingReferenceLevel)
      {
         DebugSignal("pending SELL cancelled: candle closed back above/equal reference swing high.");
         ClearPendingEntry();
         return(false);
      }
      if(IsSellColorCandle(1))
      {
         datetime referenceTime = pendingReferenceTime;
         ClearPendingEntry();
         if(OpenTrade(OP_SELL))
            MarkReferenceTraded(OP_SELL, referenceTime);
         return(true);
      }
   }
   else
   {
      ClearPendingEntry();
      return(false);
   }

   pendingEntryBarsRemaining--;
   if(pendingEntryBarsRemaining > 0)
   {
      DebugSignal(StringFormat("pending %s waiting. barsRemaining=%d",
                               OrderTypeName(pendingEntryType), pendingEntryBarsRemaining));
      return(true);
   }

   DebugSignal(StringFormat("pending %s expired.", OrderTypeName(pendingEntryType)));
   ClearPendingEntry();
   return(false);
}

void DebugSignal(string message)
{
   if(DebugSignalFilters)
      Print(EA_NAME, ": ", message);
}

bool FindMostRecentValidSwingLow(double &level, datetime &swingTime)
{
   int bars = iBars(Symbol(), PERIOD_M1);
   int firstShift = 2 + SwingDepthBars;
   int maxShift = MathMin(firstShift + SwingSearchBars - 1, bars - SwingDepthBars - 1);

   if(maxShift < firstShift)
   {
      DebugSignal("BUY blocked: no searchable swing-low range.");
      return(false);
   }

   for(int shift = firstShift; shift <= maxShift; shift++)
   {
      if(!IsSwingLow(shift))
         continue;

      level = iLow(Symbol(), PERIOD_M1, shift);
      swingTime = iTime(Symbol(), PERIOD_M1, shift);

      if(HasClosedBelowLevelAfterSwing(shift, level))
      {
         DebugSignal(StringFormat("BUY blocked: most recent swing low invalidated by close below. level=%s time=%s",
                                  PriceText(level), TimeToString(swingTime, TIME_DATE|TIME_MINUTES)));
         return(false);
      }

      return(true);
   }

   DebugSignal("BUY blocked: no confirmed swing low found.");
   return(false);
}

bool FindMostRecentValidSwingHigh(double &level, datetime &swingTime)
{
   int bars = iBars(Symbol(), PERIOD_M1);
   int firstShift = 2 + SwingDepthBars;
   int maxShift = MathMin(firstShift + SwingSearchBars - 1, bars - SwingDepthBars - 1);

   if(maxShift < firstShift)
   {
      DebugSignal("SELL blocked: no searchable swing-high range.");
      return(false);
   }

   for(int shift = firstShift; shift <= maxShift; shift++)
   {
      if(!IsSwingHigh(shift))
         continue;

      level = iHigh(Symbol(), PERIOD_M1, shift);
      swingTime = iTime(Symbol(), PERIOD_M1, shift);

      if(HasClosedAboveLevelAfterSwing(shift, level))
      {
         DebugSignal(StringFormat("SELL blocked: most recent swing high invalidated by close above. level=%s time=%s",
                                  PriceText(level), TimeToString(swingTime, TIME_DATE|TIME_MINUTES)));
         return(false);
      }

      return(true);
   }

   DebugSignal("SELL blocked: no confirmed swing high found.");
   return(false);
}

bool HasClosedBelowLevelAfterSwing(int swingShift, double level)
{
   for(int shift = swingShift - 1; shift >= 2; shift--)
   {
      if(iClose(Symbol(), PERIOD_M1, shift) < level)
         return(true);
   }

   return(false);
}

bool HasClosedAboveLevelAfterSwing(int swingShift, double level)
{
   for(int shift = swingShift - 1; shift >= 2; shift--)
   {
      if(iClose(Symbol(), PERIOD_M1, shift) > level)
         return(true);
   }

   return(false);
}

bool IsSwingLow(int shift)
{
   double pivotLow = iLow(Symbol(), PERIOD_M1, shift);

   for(int offset = 1; offset <= SwingDepthBars; offset++)
   {
      if(iLow(Symbol(), PERIOD_M1, shift - offset) <= pivotLow)
         return(false);
      if(iLow(Symbol(), PERIOD_M1, shift + offset) <= pivotLow)
         return(false);
   }

   return(true);
}

bool IsSwingHigh(int shift)
{
   double pivotHigh = iHigh(Symbol(), PERIOD_M1, shift);

   for(int offset = 1; offset <= SwingDepthBars; offset++)
   {
      if(iHigh(Symbol(), PERIOD_M1, shift - offset) >= pivotHigh)
         return(false);
      if(iHigh(Symbol(), PERIOD_M1, shift + offset) >= pivotHigh)
         return(false);
   }

   return(true);
}

bool IsBuySetupAtLevel(double support)
{
   int shift = 1;
   double setupLow = iLow(Symbol(), PERIOD_M1, shift);
   double setupClose = iClose(Symbol(), PERIOD_M1, shift);
   double minPierce = MinFalseBreakoutPoints * Point;

   if(setupLow > support - minPierce)
   {
      DebugSignal(StringFormat("BUY blocked: setup low did not pierce swing low. setupLow=%s level=%s minPierce=%d",
                               PriceText(setupLow), PriceText(support), MinFalseBreakoutPoints));
      return(false);
   }
   if(setupClose <= support)
   {
      DebugSignal(StringFormat("BUY blocked: setup close not back above swing low. close=%s level=%s",
                               PriceText(setupClose), PriceText(support)));
      return(false);
   }

   return(IsLongLowerWick(shift));
}

bool IsSellSetupAtLevel(double resistance)
{
   int shift = 1;
   double setupHigh = iHigh(Symbol(), PERIOD_M1, shift);
   double setupClose = iClose(Symbol(), PERIOD_M1, shift);
   double minPierce = MinFalseBreakoutPoints * Point;

   if(setupHigh < resistance + minPierce)
   {
      DebugSignal(StringFormat("SELL blocked: setup high did not pierce swing high. setupHigh=%s level=%s minPierce=%d",
                               PriceText(setupHigh), PriceText(resistance), MinFalseBreakoutPoints));
      return(false);
   }
   if(setupClose >= resistance)
   {
      DebugSignal(StringFormat("SELL blocked: setup close not back below swing high. close=%s level=%s",
                               PriceText(setupClose), PriceText(resistance)));
      return(false);
   }

   return(IsLongUpperWick(shift));
}

bool IsLongLowerWick(int shift)
{
   double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
   double closePrice = iClose(Symbol(), PERIOD_M1, shift);
   double highPrice = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice = iLow(Symbol(), PERIOD_M1, shift);
   double lowerWick = MathMin(openPrice, closePrice) - lowPrice;
   double candleRange = highPrice - lowPrice;

   return(IsLongSetupWick(lowerWick, candleRange, "BUY"));
}

bool IsLongUpperWick(int shift)
{
   double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
   double closePrice = iClose(Symbol(), PERIOD_M1, shift);
   double highPrice = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice = iLow(Symbol(), PERIOD_M1, shift);
   double upperWick = highPrice - MathMax(openPrice, closePrice);
   double candleRange = highPrice - lowPrice;

   return(IsLongSetupWick(upperWick, candleRange, "SELL"));
}

bool IsLongSetupWick(double signalWick, double candleRange, string side)
{
   if(signalWick < MinTailPoints * Point)
   {
      DebugSignal(StringFormat("%s blocked: signal wick shorter than MinTailPoints. wickPoints=%s min=%d",
                               side, DoubleToString(signalWick / Point, 1), MinTailPoints));
      return(false);
   }

   if(candleRange <= 0.0)
   {
      DebugSignal(StringFormat("%s blocked: candle range is zero.", side));
      return(false);
   }

   double wickPercent = signalWick * 100.0 / candleRange;
   if(wickPercent < MinSignalWickPercent)
   {
      DebugSignal(StringFormat("%s blocked: signal wick percent too small. wickPercent=%s min=%s",
                               side, DoubleToString(wickPercent, 1), DoubleToString(MinSignalWickPercent, 1)));
      return(false);
   }

   return(true);
}

bool IsBuyColorCandle(int shift)
{
   return(iClose(Symbol(), PERIOD_M1, shift) > iOpen(Symbol(), PERIOD_M1, shift));
}

bool IsSellColorCandle(int shift)
{
   return(iClose(Symbol(), PERIOD_M1, shift) < iOpen(Symbol(), PERIOD_M1, shift));
}

bool IsDojiCandle(int shift)
{
   return(iClose(Symbol(), PERIOD_M1, shift) == iOpen(Symbol(), PERIOD_M1, shift));
}

bool IsBullishShapeDoji(int shift)
{
   if(!IsDojiCandle(shift))
      return(false);

   double highPrice = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice = iLow(Symbol(), PERIOD_M1, shift);
   double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
   double upperWick = highPrice - openPrice;
   double lowerWick = openPrice - lowPrice;

   return(upperWick < lowerWick);
}

bool IsBearishShapeDoji(int shift)
{
   if(!IsDojiCandle(shift))
      return(false);

   double highPrice = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice = iLow(Symbol(), PERIOD_M1, shift);
   double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
   double upperWick = highPrice - openPrice;
   double lowerWick = openPrice - lowPrice;

   return(upperWick > lowerWick);
}

bool ShouldWaitForBuyColor(int shift)
{
   if(IsSellColorCandle(shift))
      return(true);

   return(IsBullishShapeDoji(shift));
}

bool ShouldWaitForSellColor(int shift)
{
   if(IsBuyColorCandle(shift))
      return(true);

   return(IsBearishShapeDoji(shift));
}

bool WasReferenceTraded(int orderType, datetime referenceTime)
{
   return(lastTradedType == orderType && lastTradedReferenceTime == referenceTime);
}

void MarkReferenceTraded(int orderType, datetime referenceTime)
{
   lastTradedType = orderType;
   lastTradedReferenceTime = referenceTime;
}

bool OpenTrade(int orderType)
{
   RefreshRates();

   double volume = NormalizeVolume(Lots);
   double openPrice = 0.0;
   double stopLoss = 0.0;
   color arrowColor = clrNONE;

   if(orderType == OP_BUY)
   {
      openPrice = Ask;
      stopLoss = NormalizeDouble(openPrice - StopLossPoints * Point, Digits);
      arrowColor = clrLime;
   }
   else if(orderType == OP_SELL)
   {
      openPrice = Bid;
      stopLoss = NormalizeDouble(openPrice + StopLossPoints * Point, Digits);
      arrowColor = clrRed;
   }
   else
      return(false);

   ResetLastError();
   int ticket = OrderSend(Symbol(), orderType, volume, openPrice, SlippagePoints,
                          stopLoss, 0.0, EA_NAME, MagicNumber, 0, arrowColor);
   if(ticket < 0)
   {
      Print(EA_NAME, ": OrderSend failed. type=", OrderTypeName(orderType), " error=", GetLastError());
      return(false);
   }

   return(true);
}

double NormalizeVolume(double requestedLots)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   double volume = requestedLots;
   if(volume < minLot)
      volume = minLot;
   if(volume > maxLot)
      volume = maxLot;

   if(lotStep > 0.0)
      volume = MathFloor(volume / lotStep) * lotStep;

   return(NormalizeDouble(volume, 2));
}

int CountOpenPositions()
{
   int count = 0;

   for(int index = OrdersTotal() - 1; index >= 0; index--)
   {
      if(!OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         count++;
   }

   return(count);
}

void ManageTrailingStops()
{
   RefreshRates();

   for(int index = OrdersTotal() - 1; index >= 0; index--)
   {
      if(!OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY)
         TrailBuyOrder();
      else if(OrderType() == OP_SELL)
         TrailSellOrder();
   }
}

void TrailBuyOrder()
{
   double profitPoints = (Bid - OrderOpenPrice()) / Point;
   if(profitPoints < TrailingStartPoints)
      return;

   double lockedPoints = TrailingStartPoints +
                         MathFloor((profitPoints - TrailingStartPoints) / TrailingStepPoints) *
                         TrailingStepPoints;
   double newStopLoss = NormalizeDouble(OrderOpenPrice() + lockedPoints * Point, Digits);

   if(OrderStopLoss() != 0.0 && newStopLoss <= OrderStopLoss() + Point * 0.5)
      return;

   ResetLastError();
   if(!OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, 0.0, 0, clrLime))
      Print(EA_NAME, ": BUY trailing OrderModify failed. ticket=", OrderTicket(), " error=", GetLastError());
}

void TrailSellOrder()
{
   double profitPoints = (OrderOpenPrice() - Ask) / Point;
   if(profitPoints < TrailingStartPoints)
      return;

   double lockedPoints = TrailingStartPoints +
                         MathFloor((profitPoints - TrailingStartPoints) / TrailingStepPoints) *
                         TrailingStepPoints;
   double newStopLoss = NormalizeDouble(OrderOpenPrice() - lockedPoints * Point, Digits);

   if(OrderStopLoss() != 0.0 && newStopLoss >= OrderStopLoss() - Point * 0.5)
      return;

   ResetLastError();
   if(!OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, 0.0, 0, clrRed))
      Print(EA_NAME, ": SELL trailing OrderModify failed. ticket=", OrderTicket(), " error=", GetLastError());
}

string PriceText(double price)
{
   return(DoubleToString(price, Digits));
}

string OrderTypeName(int orderType)
{
   if(orderType == OP_BUY)
      return("BUY");
   if(orderType == OP_SELL)
      return("SELL");
   return("UNKNOWN");
}
