#property strict

#property copyright "IDC_5"
#property link      ""
#property version   "1.04"
#property description "GOLD M1 structure breakout failure pinbar strategy"

input double Lots                     = 0.10;
input int    MagicNumber              = 505;
input int    SlippagePoints           = 30;
input int    StopLossPoints           = 200;
input int    TrailingStartPoints      = 200;
input int    TrailingStepPoints       = 10;
input int    StructureSearchBars      = 120;
input int    SwingDepthBars           = 3;
input int    MinFalseBreakoutPoints   = 1;
input int    MaxLevelSweepPoints      = 80;
input int    StructureBreakMinPoints  = 30;
input int    MinTailPoints            = 30;
input double MinSignalWickPercent     = 50.0;
input bool   DebugSignalFilters       = true;

string EA_NAME = "IDC_5";
datetime lastM1BarTime = 0;
int pendingEntryType = -1;
int pendingEntryBarsRemaining = 0;

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
   if(StructureSearchBars < 10)
   {
      Print(EA_NAME, ": StructureSearchBars must be at least 10.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(SwingDepthBars < 1)
   {
      Print(EA_NAME, ": SwingDepthBars must be at least 1.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(MinFalseBreakoutPoints < 0 || MaxLevelSweepPoints < 0 ||
      StructureBreakMinPoints < 0 || MinTailPoints < 0)
   {
      Print(EA_NAME, ": point filters cannot be negative.");
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
   int requiredBars = StructureSearchBars + SwingDepthBars + 5;
   if(iBars(Symbol(), PERIOD_M1) < requiredBars)
      return;

   if(CountOpenPositions() > 0)
   {
      ClearPendingEntry();
      return;
   }

   if(HasPendingEntry())
   {
      if(ProcessPendingEntry())
         return;
   }

   double previousSwingLow = 0.0;
   if(FindBearishStructureReferenceLow(previousSwingLow) && IsBuySetupAtLevel(previousSwingLow))
   {
      if(IsBuyColorCandle(1))
         OpenTrade(OP_BUY);
      else
         StartPendingEntry(OP_BUY);
      return;
   }
   else
      DebugSignal("BUY blocked: bearish structure or strict false-breakout setup not found.");

   double previousSwingHigh = 0.0;
   if(FindBullishStructureReferenceHigh(previousSwingHigh) && IsSellSetupAtLevel(previousSwingHigh))
   {
      if(IsSellColorCandle(1))
         OpenTrade(OP_SELL);
      else
         StartPendingEntry(OP_SELL);
   }
   else
      DebugSignal("SELL blocked: bullish structure or strict false-breakout setup not found.");
}

bool HasPendingEntry()
{
   return((pendingEntryType == OP_BUY || pendingEntryType == OP_SELL) &&
          pendingEntryBarsRemaining > 0);
}

void StartPendingEntry(int orderType)
{
   pendingEntryType = orderType;
   pendingEntryBarsRemaining = 2;
}

void ClearPendingEntry()
{
   pendingEntryType = -1;
   pendingEntryBarsRemaining = 0;
}

void DebugSignal(string message)
{
   if(DebugSignalFilters)
      Print(EA_NAME, ": ", message);
}

bool ProcessPendingEntry()
{
   bool confirmed = false;

   if(pendingEntryType == OP_BUY)
      confirmed = IsBuyColorCandle(1);
   else if(pendingEntryType == OP_SELL)
      confirmed = IsSellColorCandle(1);
   else
   {
      ClearPendingEntry();
      return(false);
   }

   if(confirmed)
   {
      int orderType = pendingEntryType;
      ClearPendingEntry();
      OpenTrade(orderType);
      return(true);
   }

   pendingEntryBarsRemaining--;
   if(pendingEntryBarsRemaining > 0)
      return(true);

   ClearPendingEntry();
   return(false);
}

bool FindBearishStructureReferenceLow(double &level)
{
   int latestLowShift = -1;
   int previousLowShift = -1;
   int latestHighShift = -1;
   int previousHighShift = -1;

   if(!FindRecentSwingLows(latestLowShift, previousLowShift))
      return(false);
   if(!FindRecentSwingHighs(latestHighShift, previousHighShift))
      return(false);

   if(!IsBearishSwingSequence(latestLowShift, previousLowShift, latestHighShift, previousHighShift))
      return(false);

   double latestLow = iLow(Symbol(), PERIOD_M1, latestLowShift);
   double previousLow = iLow(Symbol(), PERIOD_M1, previousLowShift);
   double latestHigh = iHigh(Symbol(), PERIOD_M1, latestHighShift);
   double previousHigh = iHigh(Symbol(), PERIOD_M1, previousHighShift);
   double minimumBreak = StructureBreakMinPoints * Point;

   if(latestLow >= previousLow - minimumBreak)
      return(false);
   if(latestHigh >= previousHigh - minimumBreak)
      return(false);
   if(HasClosedBelowLevelAfterSwing(latestLowShift, latestLow))
      return(false);

   level = latestLow;
   return(true);
}

bool FindBullishStructureReferenceHigh(double &level)
{
   int latestHighShift = -1;
   int previousHighShift = -1;
   int latestLowShift = -1;
   int previousLowShift = -1;

   if(!FindRecentSwingHighs(latestHighShift, previousHighShift))
      return(false);
   if(!FindRecentSwingLows(latestLowShift, previousLowShift))
      return(false);

   if(!IsBullishSwingSequence(latestHighShift, previousHighShift, latestLowShift, previousLowShift))
      return(false);

   double latestHigh = iHigh(Symbol(), PERIOD_M1, latestHighShift);
   double previousHigh = iHigh(Symbol(), PERIOD_M1, previousHighShift);
   double latestLow = iLow(Symbol(), PERIOD_M1, latestLowShift);
   double previousLow = iLow(Symbol(), PERIOD_M1, previousLowShift);
   double minimumBreak = StructureBreakMinPoints * Point;

   if(latestHigh <= previousHigh + minimumBreak)
      return(false);
   if(latestLow <= previousLow + minimumBreak)
      return(false);
   if(HasClosedAboveLevelAfterSwing(latestHighShift, latestHigh))
      return(false);

   level = latestHigh;
   return(true);
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

bool IsBearishSwingSequence(int latestLowShift, int previousLowShift,
                            int latestHighShift, int previousHighShift)
{
   return(previousHighShift > previousLowShift &&
          previousLowShift > latestHighShift &&
          latestHighShift > latestLowShift);
}

bool IsBullishSwingSequence(int latestHighShift, int previousHighShift,
                            int latestLowShift, int previousLowShift)
{
   return(previousLowShift > previousHighShift &&
          previousHighShift > latestLowShift &&
          latestLowShift > latestHighShift);
}

bool FindRecentSwingLows(int &latestShift, int &previousShift)
{
   int bars = iBars(Symbol(), PERIOD_M1);
   int firstShift = 1 + SwingDepthBars;
   int lastShift = (int)MathMin(StructureSearchBars, bars - SwingDepthBars - 1);

   for(int shift = firstShift; shift <= lastShift; shift++)
   {
      if(!IsSwingLow(shift))
         continue;

      if(latestShift < 0)
         latestShift = shift;
      else
      {
         previousShift = shift;
         return(true);
      }
   }

   return(false);
}

bool FindRecentSwingHighs(int &latestShift, int &previousShift)
{
   int bars = iBars(Symbol(), PERIOD_M1);
   int firstShift = 1 + SwingDepthBars;
   int lastShift = (int)MathMin(StructureSearchBars, bars - SwingDepthBars - 1);

   for(int shift = firstShift; shift <= lastShift; shift++)
   {
      if(!IsSwingHigh(shift))
         continue;

      if(latestShift < 0)
         latestShift = shift;
      else
      {
         previousShift = shift;
         return(true);
      }
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
   double maxSweep = MaxLevelSweepPoints * Point;

   if(setupLow > support - minPierce)
      return(false);
   if(support - setupLow > maxSweep)
      return(false);
   if(setupClose <= support)
      return(false);

   return(IsLongLowerWick(shift));
}

bool IsSellSetupAtLevel(double resistance)
{
   int shift = 1;
   double setupHigh = iHigh(Symbol(), PERIOD_M1, shift);
   double setupClose = iClose(Symbol(), PERIOD_M1, shift);
   double minPierce = MinFalseBreakoutPoints * Point;
   double maxSweep = MaxLevelSweepPoints * Point;

   if(setupHigh < resistance + minPierce)
      return(false);
   if(setupHigh - resistance > maxSweep)
      return(false);
   if(setupClose >= resistance)
      return(false);

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

   return(IsLongSetupWick(lowerWick, candleRange));
}

bool IsLongUpperWick(int shift)
{
   double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
   double closePrice = iClose(Symbol(), PERIOD_M1, shift);
   double highPrice = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice = iLow(Symbol(), PERIOD_M1, shift);

   double upperWick = highPrice - MathMax(openPrice, closePrice);
   double candleRange = highPrice - lowPrice;

   return(IsLongSetupWick(upperWick, candleRange));
}

bool IsLongSetupWick(double signalWick, double candleRange)
{
   if(signalWick < MinTailPoints * Point)
      return(false);

   if(candleRange <= 0.0)
      return(false);

   if(signalWick * 100.0 < candleRange * MinSignalWickPercent)
      return(false);

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

void OpenTrade(int orderType)
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
      return;

   int ticket = OrderSend(Symbol(), orderType, volume, openPrice, SlippagePoints,
                          stopLoss, 0.0, EA_NAME, MagicNumber, 0, arrowColor);
   if(ticket < 0)
      Print(EA_NAME, ": OrderSend failed. type=", orderType, " error=", GetLastError());
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

   if(!OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, 0.0, 0, clrRed))
      Print(EA_NAME, ": SELL trailing OrderModify failed. ticket=", OrderTicket(), " error=", GetLastError());
}
