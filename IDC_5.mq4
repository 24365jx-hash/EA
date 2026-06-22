#property strict

#property copyright "IDC_5"
#property link      ""
#property version   "1.00"
#property description "GOLD M1 structure breakout failure pinbar strategy"

input double Lots                     = 0.10;
input int    MagicNumber              = 505;
input int    SlippagePoints           = 30;
input int    StopLossPoints           = 200;
input int    TrailingStartPoints      = 200;
input int    TrailingStepPoints       = 10;
input int    StructureSearchBars      = 120;
input int    SwingDepthBars           = 3;
input int    MinStructureTouches      = 2;
input int    MinLevelAgeBars          = 8;
input int    LevelTouchTolerancePoints = 20;
input int    MaxLevelSweepPoints      = 80;
input int    MinTailPoints            = 30;
input double WickToBodyRatio          = 2.0;
input double WickToOppositeWickRatio  = 1.5;

string EA_NAME = "IDC_5";
datetime lastM1BarTime = 0;

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
   if(MinStructureTouches < 2)
   {
      Print(EA_NAME, ": MinStructureTouches must be at least 2.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(MinLevelAgeBars < 2)
   {
      Print(EA_NAME, ": MinLevelAgeBars must be at least 2.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(LevelTouchTolerancePoints < 0 || MaxLevelSweepPoints < 0 || MinTailPoints < 0)
   {
      Print(EA_NAME, ": point filters cannot be negative.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(WickToBodyRatio <= 0.0 || WickToOppositeWickRatio <= 0.0)
   {
      Print(EA_NAME, ": wick ratios must be greater than zero.");
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
      return;

   double support = 0.0;
   if(FindPreviousStructureLow(support) && IsBuySetupAtLevel(support))
   {
      OpenTrade(OP_BUY);
      return;
   }

   double resistance = 0.0;
   if(FindPreviousStructureHigh(resistance) && IsSellSetupAtLevel(resistance))
      OpenTrade(OP_SELL);
}

bool FindPreviousStructureLow(double &level)
{
   int bars = iBars(Symbol(), PERIOD_M1);
   int firstShift = (int)MathMax(2 + SwingDepthBars, MinLevelAgeBars);
   int lastShift = (int)MathMin(StructureSearchBars, bars - SwingDepthBars - 1);

   for(int shift = firstShift; shift <= lastShift; shift++)
   {
      if(IsSwingLow(shift) && BuildStructureLowLevel(shift, firstShift, lastShift, level))
         return(true);
   }

   return(false);
}

bool FindPreviousStructureHigh(double &level)
{
   int bars = iBars(Symbol(), PERIOD_M1);
   int firstShift = (int)MathMax(2 + SwingDepthBars, MinLevelAgeBars);
   int lastShift = (int)MathMin(StructureSearchBars, bars - SwingDepthBars - 1);

   for(int shift = firstShift; shift <= lastShift; shift++)
   {
      if(IsSwingHigh(shift) && BuildStructureHighLevel(shift, firstShift, lastShift, level))
         return(true);
   }

   return(false);
}

bool BuildStructureLowLevel(int candidateShift, int firstShift, int lastShift, double &level)
{
   double candidate = iLow(Symbol(), PERIOD_M1, candidateShift);
   double tolerance = LevelTouchTolerancePoints * Point;
   int touches = 0;
   double levelSum = 0.0;

   for(int shift = firstShift; shift <= lastShift; shift++)
   {
      if(!IsSwingLow(shift))
         continue;

      double swingLow = iLow(Symbol(), PERIOD_M1, shift);
      if(MathAbs(swingLow - candidate) <= tolerance)
      {
         touches++;
         levelSum += swingLow;
      }
   }

   if(touches < MinStructureTouches)
      return(false);

   level = NormalizeDouble(levelSum / touches, Digits);
   return(true);
}

bool BuildStructureHighLevel(int candidateShift, int firstShift, int lastShift, double &level)
{
   double candidate = iHigh(Symbol(), PERIOD_M1, candidateShift);
   double tolerance = LevelTouchTolerancePoints * Point;
   int touches = 0;
   double levelSum = 0.0;

   for(int shift = firstShift; shift <= lastShift; shift++)
   {
      if(!IsSwingHigh(shift))
         continue;

      double swingHigh = iHigh(Symbol(), PERIOD_M1, shift);
      if(MathAbs(swingHigh - candidate) <= tolerance)
      {
         touches++;
         levelSum += swingHigh;
      }
   }

   if(touches < MinStructureTouches)
      return(false);

   level = NormalizeDouble(levelSum / touches, Digits);
   return(true);
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
   double setupOpen = iOpen(Symbol(), PERIOD_M1, shift);
   double setupLow = iLow(Symbol(), PERIOD_M1, shift);
   double setupClose = iClose(Symbol(), PERIOD_M1, shift);
   double tolerance = LevelTouchTolerancePoints * Point;
   double maxSweep = MaxLevelSweepPoints * Point;

   if(setupLow > support + tolerance)
      return(false);
   if(support - setupLow > maxSweep)
      return(false);
   if(MathMin(setupOpen, setupClose) <= support)
      return(false);
   if(setupClose <= support)
      return(false);

   return(IsBullishLongLowerWick(shift));
}

bool IsSellSetupAtLevel(double resistance)
{
   int shift = 1;
   double setupOpen = iOpen(Symbol(), PERIOD_M1, shift);
   double setupHigh = iHigh(Symbol(), PERIOD_M1, shift);
   double setupClose = iClose(Symbol(), PERIOD_M1, shift);
   double tolerance = LevelTouchTolerancePoints * Point;
   double maxSweep = MaxLevelSweepPoints * Point;

   if(setupHigh < resistance - tolerance)
      return(false);
   if(setupHigh - resistance > maxSweep)
      return(false);
   if(MathMax(setupOpen, setupClose) >= resistance)
      return(false);
   if(setupClose >= resistance)
      return(false);

   return(IsBearishLongUpperWick(shift));
}

bool IsBullishLongLowerWick(int shift)
{
   double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
   double closePrice = iClose(Symbol(), PERIOD_M1, shift);
   double highPrice = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice = iLow(Symbol(), PERIOD_M1, shift);

   if(closePrice <= openPrice)
      return(false);

   double body = MathAbs(closePrice - openPrice);
   double lowerWick = MathMin(openPrice, closePrice) - lowPrice;
   double upperWick = highPrice - MathMax(openPrice, closePrice);

   return(IsLongSetupWick(lowerWick, body, upperWick));
}

bool IsBearishLongUpperWick(int shift)
{
   double openPrice = iOpen(Symbol(), PERIOD_M1, shift);
   double closePrice = iClose(Symbol(), PERIOD_M1, shift);
   double highPrice = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice = iLow(Symbol(), PERIOD_M1, shift);

   if(closePrice >= openPrice)
      return(false);

   double body = MathAbs(closePrice - openPrice);
   double upperWick = highPrice - MathMax(openPrice, closePrice);
   double lowerWick = MathMin(openPrice, closePrice) - lowPrice;

   return(IsLongSetupWick(upperWick, body, lowerWick));
}

bool IsLongSetupWick(double signalWick, double body, double oppositeWick)
{
   if(signalWick < MinTailPoints * Point)
      return(false);

   double comparableBody = MathMax(body, Point);
   if(signalWick < comparableBody * WickToBodyRatio)
      return(false);

   if(signalWick < oppositeWick * WickToOppositeWickRatio)
      return(false);

   return(true);
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
