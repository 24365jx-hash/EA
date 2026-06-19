//+------------------------------------------------------------------+
//|                                                        IDC_D.mq4 |
//| GOLD/XAUUSD M1/M5 automated EA                                  |
//+------------------------------------------------------------------+
#property strict
#property copyright "IDC_D"
#property link      ""
#property version   "2.00"
#property description "GOLD-only M1/M5 EA with daily entry engine, 20-pip lock, and step trailing."

#define EA_NAME "IDC_D"

input bool   UseAutoSymbolDetect      = true;
input string AllowedBaseSymbol        = "XAUUSD";
input bool   AllowGoldAliasSymbols    = true;

input int    MagicNumber              = 5473001;
input bool   UseFixedLot              = false;
input double FixedLot                 = 0.01;
input double RiskPercentPerTrade      = 1.00;

input int    InitialSLPoints          = 300;
input int    LockProfitTriggerPoints  = 200;
input int    LockProfitPoints         = 200;
input int    TrailStepPoints          = 50;
input int    MaxSpreadPoints          = 80;
input int    HardMaxSpreadPoints      = 120;
input int    SlippagePoints           = 30;

input double MaxDailyLossPercent      = 5.00;
input int    MaxTradesPerDay          = 3;
input bool   StopAfterDailyLock       = true;
input int    CooldownBars             = 10;

input bool   UseSessionFilter         = true;
input bool   UseGMTSessionHours       = true;
input int    TradingStartHour         = 6;
input int    TradingEndHour           = 21;

input bool   UseManualNewsBlock       = false;
input int    NewsBlockStartHour       = 0;
input int    NewsBlockEndHour         = 0;

input int    M5FastEMA                = 8;
input int    M5SlowEMA                = 21;
input int    M1FastEMA                = 5;
input int    M1SlowEMA                = 13;
input int    RSIPeriod                = 14;
input double RSIBuyMin                = 50.0;
input double RSISellMax               = 50.0;
input int    M5ATRPeriod              = 14;
input int    ATRMinPoints             = 20;
input int    ATRMaxPoints             = 600;

input bool   UseDailyProbe            = true;
input int    DailyProbeStartHour      = 6;
input bool   RelaxedTrendProbe        = true;
input bool   ForceDailyEntry          = true;
input int    FinalEntryHour           = 13;
input int    NeutralRSILow            = 48;
input int    NeutralRSIHigh           = 52;

input bool   PrintDebugLogs           = true;
input bool   ShowStatusPanel          = true;

string   TradeSymbol = "";
datetime LastM1BarTime = 0;
datetime CooldownUntilBarTime = 0;
string   LastBlockedReason = "Initializing";
string   LastLoggedReason = "";
string   LastEntryMode = "NONE";

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   TradeSymbol = ResolveTradeSymbol();
   if(TradeSymbol == "")
   {
      Print(EA_NAME, ": GOLD/XAUUSD compatible symbol was not found.");
      return(INIT_FAILED);
   }

   if(Period() != PERIOD_M1 && Period() != PERIOD_M5)
   {
      Print(EA_NAME, ": attach only to M1 or M5 charts. Current period=", Period());
      return(INIT_FAILED);
   }

   if(InitialSLPoints <= 0 || LockProfitTriggerPoints <= 0 || LockProfitPoints <= 0)
   {
      Print(EA_NAME, ": SL and lock point inputs must be positive.");
      return(INIT_FAILED);
   }

   if(M5FastEMA >= M5SlowEMA || M1FastEMA >= M1SlowEMA)
   {
      Print(EA_NAME, ": fast EMA periods must be lower than slow EMA periods.");
      return(INIT_FAILED);
   }

   Print(EA_NAME, ": initialized for symbol ", TradeSymbol);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   if(TradeSymbol == "")
      return;

   ManageOpenOrders();
   UpdateStatusPanel();

   datetime m1BarTime = iTime(TradeSymbol, PERIOD_M1, 0);
   if(m1BarTime <= 0 || m1BarTime == LastM1BarTime)
      return;
   LastM1BarTime = m1BarTime;

   if(!CanOpenNewTrade())
   {
      UpdateStatusPanel();
      return;
   }

   int signal = GetEntrySignal();
   if(signal == OP_BUY || signal == OP_SELL)
      OpenTrade(signal);
   else
      LastEntryMode = "NONE";

   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| Symbol handling                                                   |
//+------------------------------------------------------------------+
string ResolveTradeSymbol()
{
   string current = Symbol();
   if(IsGoldSymbol(current))
      return(current);

   if(!UseAutoSymbolDetect)
      return("");

   int selectedTotal = SymbolsTotal(true);
   for(int i = 0; i < selectedTotal; i++)
   {
      string candidate = SymbolName(i, true);
      if(IsGoldSymbol(candidate))
         return(candidate);
   }

   int allTotal = SymbolsTotal(false);
   for(int j = 0; j < allTotal; j++)
   {
      string anyCandidate = SymbolName(j, false);
      if(IsGoldSymbol(anyCandidate))
      {
         SymbolSelect(anyCandidate, true);
         return(anyCandidate);
      }
   }
   return("");
}

bool IsGoldSymbol(string symbolName)
{
   if(symbolName == "")
      return(false);

   if(StringFind(symbolName, AllowedBaseSymbol) >= 0)
      return(true);
   if(StringFind(symbolName, "XAUUSD") >= 0 || StringFind(symbolName, "xauusd") >= 0)
      return(true);
   if(AllowGoldAliasSymbols)
   {
      if(StringFind(symbolName, "XAU") >= 0 || StringFind(symbolName, "xau") >= 0)
         return(true);
      if(StringFind(symbolName, "GOLD") >= 0 || StringFind(symbolName, "gold") >= 0)
         return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Trade eligibility                                                 |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   if(!IsGoldSymbol(TradeSymbol))
   {
      SetBlockedReason("Not GOLD/XAUUSD symbol");
      return(false);
   }

   if(CountOpenOrders() > 0)
   {
      SetBlockedReason("Open position exists");
      return(false);
   }

   if(TimeCurrent() < CooldownUntilBarTime)
   {
      SetBlockedReason("Cooldown active");
      return(false);
   }

   if(GetSpreadPoints() > HardMaxSpreadPoints)
   {
      SetBlockedReason("Hard spread filter");
      return(false);
   }

   if(UseSessionFilter && !IsWithinHourWindow(TradingStartHour, TradingEndHour))
   {
      SetBlockedReason("Outside session hours");
      return(false);
   }

   if(UseManualNewsBlock && IsWithinHourWindow(NewsBlockStartHour, NewsBlockEndHour))
   {
      SetBlockedReason("Manual news block");
      return(false);
   }

   if(MaxDailyLossPercent > 0.0)
   {
      double limit = AccountBalance() * MaxDailyLossPercent / 100.0;
      if(GetTodayClosedProfitMoney() <= -limit)
      {
         SetBlockedReason("Daily loss limit reached");
         return(false);
      }
   }

   if(CountTodayTrades() >= MaxTradesPerDay)
   {
      SetBlockedReason("Max daily trades reached");
      return(false);
   }

   if(StopAfterDailyLock && IsDailyLockReached())
   {
      SetBlockedReason("Daily 200-point lock reached");
      return(false);
   }

   SetBlockedReason("Eligible");
   return(true);
}

bool IsWithinHourWindow(int startHour, int endHour)
{
   datetime nowTime = UseGMTSessionHours ? TimeGMT() : TimeCurrent();
   int hour = TimeHour(nowTime);
   startHour = MathMax(0, MathMin(23, startHour));
   endHour = MathMax(0, MathMin(23, endHour));

   if(startHour == endHour)
      return(true);
   if(startHour < endHour)
      return(hour >= startHour && hour < endHour);
   return(hour >= startHour || hour < endHour);
}

//+------------------------------------------------------------------+
//| Entry logic                                                       |
//+------------------------------------------------------------------+
int GetEntrySignal()
{
   if(iBars(TradeSymbol, PERIOD_M1) < MathMax(M1SlowEMA, RSIPeriod) + 5)
   {
      SetBlockedReason("Not enough M1 bars");
      return(-1);
   }
   if(iBars(TradeSymbol, PERIOD_M5) < MathMax(M5SlowEMA, M5ATRPeriod) + 5)
   {
      SetBlockedReason("Not enough M5 bars");
      return(-1);
   }

   double point = MarketInfo(TradeSymbol, MODE_POINT);
   double m5Fast = iMA(TradeSymbol, PERIOD_M5, M5FastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double m5Slow = iMA(TradeSymbol, PERIOD_M5, M5SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double m5AtrPoints = iATR(TradeSymbol, PERIOD_M5, M5ATRPeriod, 1) / point;
   if(m5AtrPoints < ATRMinPoints || m5AtrPoints > ATRMaxPoints)
   {
      SetBlockedReason("ATR filter");
      return(-1);
   }

   int spread = GetSpreadPoints();
   bool normalSpread = (spread <= MaxSpreadPoints);
   bool hardSpreadOk = (spread <= HardMaxSpreadPoints);
   if(!hardSpreadOk)
   {
      SetBlockedReason("Hard spread filter");
      return(-1);
   }

   double m1Close = iClose(TradeSymbol, PERIOD_M1, 1);
   double m1Open = iOpen(TradeSymbol, PERIOD_M1, 1);
   double m1High = iHigh(TradeSymbol, PERIOD_M1, 1);
   double m1Low = iLow(TradeSymbol, PERIOD_M1, 1);
   double m1ClosePrev = iClose(TradeSymbol, PERIOD_M1, 2);
   double m1ClosePrev2 = iClose(TradeSymbol, PERIOD_M1, 3);
   double fastNow = iMA(TradeSymbol, PERIOD_M1, M1FastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowNow = iMA(TradeSymbol, PERIOD_M1, M1SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double rsiNow = iRSI(TradeSymbol, PERIOD_M1, RSIPeriod, PRICE_CLOSE, 1);

   bool m5Up = (m5Fast > m5Slow);
   bool m5Down = (m5Fast < m5Slow);
   bool m1Up = (fastNow > slowNow);
   bool m1Down = (fastNow < slowNow);
   bool strongOppositeForBuy = (m5Down && m1Close < m5Slow);
   bool strongOppositeForSell = (m5Up && m1Close > m5Slow);
   bool neutralRsi = (rsiNow >= NeutralRSILow && rsiNow <= NeutralRSIHigh);

   bool buyPullbackResume = (
      normalSpread
      && m5Up
      && m1Up
      && rsiNow >= RSIBuyMin
      && m1Close > m1Open
      && m1Close > m1ClosePrev
      && m1Low <= fastNow + 20 * point
   );
   bool sellPullbackResume = (
      normalSpread
      && m5Down
      && m1Down
      && rsiNow <= RSISellMax
      && m1Close < m1Open
      && m1Close < m1ClosePrev
      && m1High >= fastNow - 20 * point
   );

   if(buyPullbackResume)
   {
      LastEntryMode = "TREND_PULLBACK_BUY";
      SetBlockedReason("Signal ready");
      return(OP_BUY);
   }
   if(sellPullbackResume)
   {
      LastEntryMode = "TREND_PULLBACK_SELL";
      SetBlockedReason("Signal ready");
      return(OP_SELL);
   }

   if(UseDailyProbe && CountTodayTrades() == 0 && CurrentSessionHour() >= DailyProbeStartHour)
   {
      bool buyProbe = (
         normalSpread
         && m1Up
         && m1Close > fastNow
         && rsiNow >= RSIBuyMin
         && (RelaxedTrendProbe ? !strongOppositeForBuy : m5Up)
      );
      bool sellProbe = (
         normalSpread
         && m1Down
         && m1Close < fastNow
         && rsiNow <= RSISellMax
         && (RelaxedTrendProbe ? !strongOppositeForSell : m5Down)
      );

      if(buyProbe)
      {
         LastEntryMode = "DAILY_PROBE_BUY";
         SetBlockedReason("Signal ready");
         return(OP_BUY);
      }
      if(sellProbe)
      {
         LastEntryMode = "DAILY_PROBE_SELL";
         SetBlockedReason("Signal ready");
         return(OP_SELL);
      }
   }

   if(ForceDailyEntry && CountTodayTrades() == 0 && CurrentSessionHour() >= FinalEntryHour && !neutralRsi)
   {
      bool recentUp = (m1Close > m1ClosePrev && m1ClosePrev >= m1ClosePrev2);
      bool recentDown = (m1Close < m1ClosePrev && m1ClosePrev <= m1ClosePrev2);

      if((m1Up || recentUp) && m1Close > fastNow && rsiNow > NeutralRSIHigh)
      {
         LastEntryMode = "FORCE_DAILY_BUY";
         SetBlockedReason("Signal ready");
         return(OP_BUY);
      }
      if((m1Down || recentDown) && m1Close < fastNow && rsiNow < NeutralRSILow)
      {
         LastEntryMode = "FORCE_DAILY_SELL";
         SetBlockedReason("Signal ready");
         return(OP_SELL);
      }
   }

   LastEntryMode = "WAITING";
   SetBlockedReason("No v2.0 entry signal");
   return(-1);
}

int CurrentSessionHour()
{
   return(TimeHour(UseGMTSessionHours ? TimeGMT() : TimeCurrent()));
}

//+------------------------------------------------------------------+
//| Order placement                                                   |
//+------------------------------------------------------------------+
void OpenTrade(int orderType)
{
   RefreshRates();

   double point = MarketInfo(TradeSymbol, MODE_POINT);
   int digits = (int)MarketInfo(TradeSymbol, MODE_DIGITS);
   double lots = CalculateLots();
   if(lots <= 0.0)
   {
      Print(EA_NAME, ": lot calculation failed.");
      return;
   }

   double price = (orderType == OP_BUY) ? MarketInfo(TradeSymbol, MODE_ASK) : MarketInfo(TradeSymbol, MODE_BID);
   double stopLoss = (orderType == OP_BUY)
      ? price - InitialSLPoints * point
      : price + InitialSLPoints * point;

   price = NormalizeDouble(price, digits);
   stopLoss = NormalizeDouble(stopLoss, digits);

   if(!IsStopDistanceValid(orderType, stopLoss))
   {
      Print(EA_NAME, ": initial stop distance is invalid for broker stop level.");
      return;
   }

   int ticket = OrderSend(
      TradeSymbol,
      orderType,
      lots,
      price,
      SlippagePoints,
      stopLoss,
      0,
      EA_NAME,
      MagicNumber,
      0,
      (orderType == OP_BUY) ? clrDodgerBlue : clrTomato
   );

   if(ticket < 0)
   {
      int errorCode = GetLastError();
      SetBlockedReason(StringConcatenate("OrderSend failed: ", IntegerToString(errorCode)));
      Print(EA_NAME, ": OrderSend failed. error=", errorCode);
      ResetLastError();
      return;
   }

   CooldownUntilBarTime = TimeCurrent() + CooldownBars * 60;
   SetBlockedReason("Order opened");
   Print(EA_NAME, ": opened ", (orderType == OP_BUY ? "BUY" : "SELL"), " ticket=", ticket, " lots=", DoubleToString(lots, 2));
}

double CalculateLots()
{
   double minLot = MarketInfo(TradeSymbol, MODE_MINLOT);
   double maxLot = MarketInfo(TradeSymbol, MODE_MAXLOT);
   double lotStep = MarketInfo(TradeSymbol, MODE_LOTSTEP);
   double lots = FixedLot;

   if(!UseFixedLot)
   {
      double tickValue = MarketInfo(TradeSymbol, MODE_TICKVALUE);
      double tickSize = MarketInfo(TradeSymbol, MODE_TICKSIZE);
      double point = MarketInfo(TradeSymbol, MODE_POINT);
      if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0)
         return(0.0);

      double valuePerPointPerLot = tickValue * point / tickSize;
      double riskMoney = AccountBalance() * RiskPercentPerTrade / 100.0;
      lots = riskMoney / (InitialSLPoints * valuePerPointPerLot);
   }

   if(lotStep <= 0.0)
      lotStep = 0.01;
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return(NormalizeDouble(lots, 2));
}

//+------------------------------------------------------------------+
//| Trailing and lock management                                      |
//+------------------------------------------------------------------+
void ManageOpenOrders()
{
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != TradeSymbol || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      ManageOneOrder();
   }
}

void ManageOneOrder()
{
   double point = MarketInfo(TradeSymbol, MODE_POINT);
   int digits = (int)MarketInfo(TradeSymbol, MODE_DIGITS);
   double openPrice = OrderOpenPrice();
   double currentStop = OrderStopLoss();
   double targetStop = currentStop;
   bool lockReached = false;
   bool stopProtected = false;

   if(OrderType() == OP_BUY)
   {
      double bid = MarketInfo(TradeSymbol, MODE_BID);
      if((bid - openPrice) >= LockProfitTriggerPoints * point)
      {
         double lockPrice = openPrice + LockProfitPoints * point;
         int steps = 0;
         if(TrailStepPoints > 0 && bid > lockPrice)
            steps = (int)MathFloor((bid - lockPrice) / (TrailStepPoints * point));
         targetStop = lockPrice + steps * TrailStepPoints * point;
         targetStop = NormalizeDouble(targetStop, digits);
         lockReached = true;
      }

      if(lockReached)
      {
         double lockPriceCheck = openPrice + LockProfitPoints * point;
         if(currentStop >= lockPriceCheck)
            stopProtected = true;
         else if(targetStop > currentStop + point && IsStopDistanceValid(OP_BUY, targetStop))
            stopProtected = ModifyStop(targetStop);
      }
   }
   else if(OrderType() == OP_SELL)
   {
      double ask = MarketInfo(TradeSymbol, MODE_ASK);
      if((openPrice - ask) >= LockProfitTriggerPoints * point)
      {
         double lockPrice = openPrice - LockProfitPoints * point;
         int steps = 0;
         if(TrailStepPoints > 0 && ask < lockPrice)
            steps = (int)MathFloor((lockPrice - ask) / (TrailStepPoints * point));
         targetStop = lockPrice - steps * TrailStepPoints * point;
         targetStop = NormalizeDouble(targetStop, digits);
         lockReached = true;
      }

      if(lockReached)
      {
         double lockPriceCheck = openPrice - LockProfitPoints * point;
         if(currentStop > 0.0 && currentStop <= lockPriceCheck)
            stopProtected = true;
         else if((currentStop <= 0.0 || targetStop < currentStop - point) && IsStopDistanceValid(OP_SELL, targetStop))
            stopProtected = ModifyStop(targetStop);
      }
   }

   if(stopProtected)
      MarkDailyLockReached();
}

bool ModifyStop(double stopLoss)
{
   bool result = OrderModify(OrderTicket(), OrderOpenPrice(), stopLoss, 0, 0, clrYellow);
   if(!result)
   {
      int errorCode = GetLastError();
      DebugLog(StringConcatenate("OrderModify failed. error=", IntegerToString(errorCode)));
      ResetLastError();
      return(false);
   }
   return(true);
}

bool IsStopDistanceValid(int orderType, double stopLoss)
{
   double point = MarketInfo(TradeSymbol, MODE_POINT);
   double stopLevel = MarketInfo(TradeSymbol, MODE_STOPLEVEL) * point;
   double freezeLevel = MarketInfo(TradeSymbol, MODE_FREEZELEVEL) * point;
   double minDistance = MathMax(stopLevel, freezeLevel);

   if(orderType == OP_BUY)
   {
      double bid = MarketInfo(TradeSymbol, MODE_BID);
      return((bid - stopLoss) > minDistance);
   }

   if(orderType == OP_SELL)
   {
      double ask = MarketInfo(TradeSymbol, MODE_ASK);
      return((stopLoss - ask) > minDistance);
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Daily state                                                       |
//+------------------------------------------------------------------+
int CountOpenOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == TradeSymbol && OrderMagicNumber() == MagicNumber && (OrderType() == OP_BUY || OrderType() == OP_SELL))
         count++;
   }
   return(count);
}

int CountTodayTrades()
{
   datetime dayStart = TodayStart(TimeCurrent());
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == TradeSymbol && OrderMagicNumber() == MagicNumber && OrderOpenTime() >= dayStart)
         count++;
   }

   for(int j = OrdersHistoryTotal() - 1; j >= 0; j--)
   {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() == TradeSymbol && OrderMagicNumber() == MagicNumber && OrderOpenTime() >= dayStart)
         count++;
   }

   return(count);
}

double GetTodayClosedProfitMoney()
{
   datetime dayStart = TodayStart(TimeCurrent());
   double profit = 0.0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != TradeSymbol || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderCloseTime() < dayStart)
         continue;
      profit += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return(profit);
}

bool IsDailyLockReached()
{
   if(GlobalVariableCheck(DailyLockKey()))
      return(true);

   datetime dayStart = TodayStart(TimeCurrent());
   double point = MarketInfo(TradeSymbol, MODE_POINT);

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != TradeSymbol || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderOpenTime() < dayStart)
         continue;

      double points = ClosedOrderPoints();
      if(points >= LockProfitPoints)
      {
         MarkDailyLockReached();
         return(true);
      }
   }

   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != TradeSymbol || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_BUY && OrderStopLoss() >= OrderOpenPrice() + LockProfitPoints * point)
         return(true);
      if(OrderType() == OP_SELL && OrderStopLoss() <= OrderOpenPrice() - LockProfitPoints * point && OrderStopLoss() > 0.0)
         return(true);
   }

   return(false);
}

void MarkDailyLockReached()
{
   GlobalVariableSet(DailyLockKey(), TimeCurrent());
}

string DailyLockKey()
{
   datetime nowTime = TimeCurrent();
   return(StringFormat("%s.%d.%04d%03d.lock", EA_NAME, MagicNumber, TimeYear(nowTime), TimeDayOfYear(nowTime)));
}

datetime TodayStart(datetime value)
{
   return(StrToTime(TimeToString(value, TIME_DATE)));
}

double ClosedOrderPoints()
{
   double point = MarketInfo(OrderSymbol(), MODE_POINT);
   if(OrderType() == OP_BUY)
      return((OrderClosePrice() - OrderOpenPrice()) / point);
   if(OrderType() == OP_SELL)
      return((OrderOpenPrice() - OrderClosePrice()) / point);
   return(0.0);
}

//+------------------------------------------------------------------+
//| Misc                                                              |
//+------------------------------------------------------------------+
int GetSpreadPoints()
{
   return((int)MarketInfo(TradeSymbol, MODE_SPREAD));
}

void SetBlockedReason(string reason)
{
   LastBlockedReason = reason;
   if(PrintDebugLogs && reason != LastLoggedReason && reason != "Eligible" && reason != "No v2.0 entry signal")
   {
      Print(EA_NAME, ": ", reason);
      LastLoggedReason = reason;
   }
}

void UpdateStatusPanel()
{
   if(!ShowStatusPanel)
      return;

   string lockText = IsDailyLockReached() ? "YES" : "NO";
   string nextTime = "NOW";
   if(TimeCurrent() < CooldownUntilBarTime)
      nextTime = TimeToString(CooldownUntilBarTime, TIME_MINUTES);

   Comment(
      "IDC_D v2.0\n",
      "Symbol: ", TradeSymbol, "\n",
      "TF: M1 entry / M5 filter\n",
      "Spread: ", IntegerToString(GetSpreadPoints()), " points\n",
      "Today Trades: ", IntegerToString(CountTodayTrades()), "/", IntegerToString(MaxTradesPerDay), "\n",
      "Today P/L: ", DoubleToString(GetTodayClosedProfitMoney(), 2), "\n",
      "Daily Lock: ", lockText, "\n",
      "Entry Mode: ", LastEntryMode, "\n",
      "Blocked Reason: ", LastBlockedReason, "\n",
      "Next Entry: ", nextTime
   );
}

void DebugLog(string message)
{
   if(PrintDebugLogs)
      Print(EA_NAME, ": ", message);
}
