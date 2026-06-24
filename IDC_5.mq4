#property strict

#property copyright "IDC_5"
#property link      ""
#property version   "1.05"
#property description "GOLD M1 structure breakout failure pinbar strategy"

input double Lots                     = 0.10;
input int    MagicNumber              = 505;
input int    SlippagePoints           = 30;
input int    StopLossPoints           = 200;
input int    TrailingStartPoints      = 200;
input int    TrailingStepPoints       = 10;
input int    SetupLookbackBars        = 30;
input int    MinFalseBreakoutPoints   = 1;
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
   if(SetupLookbackBars < 1)
   {
      Print(EA_NAME, ": SetupLookbackBars must be at least 1.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(MinFalseBreakoutPoints < 0 || MinTailPoints < 0)
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
   int requiredBars = SetupLookbackBars + 5;
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

   double lookbackLow = 0.0;
   if(FindLookbackLowestLow(lookbackLow) && IsBuySetupAtLevel(lookbackLow))
   {
      if(IsBuyColorCandle(1))
         OpenTrade(OP_BUY);
      else if(ShouldWaitForBuyColor(1))
         StartPendingEntry(OP_BUY);
      return;
   }
   else
      DebugSignal("BUY blocked: lookback low strict false-breakout setup not found.");

   double lookbackHigh = 0.0;
   if(FindLookbackHighestHigh(lookbackHigh) && IsSellSetupAtLevel(lookbackHigh))
   {
      if(IsSellColorCandle(1))
         OpenTrade(OP_SELL);
      else if(ShouldWaitForSellColor(1))
         StartPendingEntry(OP_SELL);
   }
   else
      DebugSignal("SELL blocked: lookback high strict false-breakout setup not found.");
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

bool FindLookbackLowestLow(double &level)
{
   if(iBars(Symbol(), PERIOD_M1) < SetupLookbackBars + 2)
      return(false);

   level = iLow(Symbol(), PERIOD_M1, 2);
   for(int shift = 3; shift <= SetupLookbackBars + 1; shift++)
   {
      double candleLow = iLow(Symbol(), PERIOD_M1, shift);
      if(candleLow < level)
         level = candleLow;
   }

   return(true);
}

bool FindLookbackHighestHigh(double &level)
{
   if(iBars(Symbol(), PERIOD_M1) < SetupLookbackBars + 2)
      return(false);

   level = iHigh(Symbol(), PERIOD_M1, 2);
   for(int shift = 3; shift <= SetupLookbackBars + 1; shift++)
   {
      double candleHigh = iHigh(Symbol(), PERIOD_M1, shift);
      if(candleHigh > level)
         level = candleHigh;
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

   if(setupHigh < resistance + minPierce)
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
