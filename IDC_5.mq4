#property strict

#property copyright "IDC_5"
#property link      ""
#property version   "2.00"
#property description "GOLD M1 structure false-breakout pinbar strategy (original 1:1)"

//--- §9 원본 입력 파라미터 (12개, 유령 파라미터 없음)
input double Lots                       = 0.10;
input int    MagicNumber                = 505;
input int    SlippagePoints             = 30;
input int    StopLossPoints             = 200;
input int    TrailingStartPoints        = 200;
input int    TrailingStepPoints         = 10;
input int    StructureSearchBars        = 120;
input int    SwingDepthBars             = 3;
input int    LevelTouchTolerancePoints  = 30;
input int    MinTailPoints              = 30;
input double WickToBodyRatio            = 2.0;
input double WickToOppositeWickRatio    = 1.5;

string   EA_NAME       = "IDC_5";
datetime lastM1BarTime = 0;

//+------------------------------------------------------------------+
//| §4.1 / §5.1 — M1 차트 검증, 파라미터 유효성 검증                    |
//+------------------------------------------------------------------+
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
      Print(EA_NAME, ": TrailingStartPoints and TrailingStepPoints must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(StructureSearchBars < 1)
   {
      Print(EA_NAME, ": StructureSearchBars must be at least 1.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(SwingDepthBars < 1)
   {
      Print(EA_NAME, ": SwingDepthBars must be at least 1.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(LevelTouchTolerancePoints < 0)
   {
      Print(EA_NAME, ": LevelTouchTolerancePoints cannot be negative.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(MinTailPoints < 0)
   {
      Print(EA_NAME, ": MinTailPoints cannot be negative.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(WickToBodyRatio <= 0.0)
   {
      Print(EA_NAME, ": WickToBodyRatio must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(WickToOppositeWickRatio <= 0.0)
   {
      Print(EA_NAME, ": WickToOppositeWickRatio must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(Period() != PERIOD_M1)
      Print(EA_NAME, ": attach to M1. New entries are disabled on non-M1 charts.");

   lastM1BarTime = iTime(Symbol(), PERIOD_M1, 0);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 매 틱: §8 트레일링 / 새 M1 봉: §4·§5 진입 평가                     |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| §4.2 / §5.2 — 새 봉 첫 평가, shift=1 셋업캔들 평가                  |
//+------------------------------------------------------------------+
void EvaluateClosedSetupCandle()
{
   const int SETUP_SHIFT = 1;

   int requiredBars = StructureSearchBars + SwingDepthBars * 2 + 5;
   if(iBars(Symbol(), PERIOD_M1) < requiredBars)
      return;

   // §4.8 / §5.8 — 기존 포지션 있으면 신규 진입 금지
   if(CountOpenPositions() > 0)
      return;

   double swingLow = 0.0;
   datetime swingLowTime = 0;
   if(FindMostRecentSwingLow(swingLow, swingLowTime))
   {
      if(IsBuySetupAtLevel(swingLow, SETUP_SHIFT))
      {
         OpenTrade(OP_BUY);
         return;
      }
   }

   double swingHigh = 0.0;
   datetime swingHighTime = 0;
   if(FindMostRecentSwingHigh(swingHigh, swingHighTime))
   {
      if(IsSellSetupAtLevel(swingHigh, SETUP_SHIFT))
      {
         OpenTrade(OP_SELL);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| §3.1 — StructureSearchBars 내 가장 가까운 확정 스윙 저점             |
//+------------------------------------------------------------------+
bool FindMostRecentSwingLow(double &level, datetime &swingTime)
{
   int bars = iBars(Symbol(), PERIOD_M1);
   int firstShift = 1 + SwingDepthBars;
   int maxShift = MathMin(firstShift + StructureSearchBars - 1, bars - SwingDepthBars - 1);

   if(maxShift < firstShift)
      return(false);

   for(int shift = firstShift; shift <= maxShift; shift++)
   {
      if(!IsSwingLow(shift))
         continue;

      level = iLow(Symbol(), PERIOD_M1, shift);
      swingTime = iTime(Symbol(), PERIOD_M1, shift);
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
//| §3.2 — StructureSearchBars 내 가장 가까운 확정 스윙 고점             |
//+------------------------------------------------------------------+
bool FindMostRecentSwingHigh(double &level, datetime &swingTime)
{
   int bars = iBars(Symbol(), PERIOD_M1);
   int firstShift = 1 + SwingDepthBars;
   int maxShift = MathMin(firstShift + StructureSearchBars - 1, bars - SwingDepthBars - 1);

   if(maxShift < firstShift)
      return(false);

   for(int shift = firstShift; shift <= maxShift; shift++)
   {
      if(!IsSwingHigh(shift))
         continue;

      level = iHigh(Symbol(), PERIOD_M1, shift);
      swingTime = iTime(Symbol(), PERIOD_M1, shift);
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
//| §3.1 — SwingDepthBars 좌우 비교 확정 스윙 저점                     |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| §3.2 — SwingDepthBars 좌우 비교 확정 스윙 고점                     |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| §4.4·§4.5·§4.6·§4.7 — BUY 셋업캔들 조건                           |
//+------------------------------------------------------------------+
bool IsBuySetupAtLevel(double swingLow, int shift)
{
   double setupLow = iLow(Symbol(), PERIOD_M1, shift);

   // §4.4 — 저가가 직전 저점을 하향 돌파하면 안 된다
   if(setupLow < swingLow)
      return(false);

   // §4.5 — 저가는 직전 저점으로부터 LevelTouchTolerancePoints 이내
   double distancePoints = (setupLow - swingLow) / Point;
   if(distancePoints > LevelTouchTolerancePoints)
      return(false);

   // §4.6·§4.7·§6.1 — 양봉 + 긴 아래꼬리 핀바
   return(IsBuyPinbar(shift));
}

//+------------------------------------------------------------------+
//| §5.4·§5.5·§5.6·§5.7 — SELL 셋업캔들 조건                          |
//+------------------------------------------------------------------+
bool IsSellSetupAtLevel(double swingHigh, int shift)
{
   double setupHigh = iHigh(Symbol(), PERIOD_M1, shift);

   // §5.4 — 고가가 직전 고점을 상향 돌파하면 안 된다
   if(setupHigh > swingHigh)
      return(false);

   // §5.5 — 고가는 직전 고점으로부터 LevelTouchTolerancePoints 이내
   double distancePoints = (swingHigh - setupHigh) / Point;
   if(distancePoints > LevelTouchTolerancePoints)
      return(false);

   // §5.6·§5.7·§6.2 — 음봉 + 긴 위꼬리 핀바
   return(IsSellPinbar(shift));
}

//+------------------------------------------------------------------+
//| §6.1 BUY 핀바 — 4조건 전부                                        |
//+------------------------------------------------------------------+
bool IsBuyPinbar(int shift)
{
   double openPrice  = iOpen(Symbol(), PERIOD_M1, shift);
   double closePrice = iClose(Symbol(), PERIOD_M1, shift);
   double highPrice  = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice   = iLow(Symbol(), PERIOD_M1, shift);

   // §6.1-1 — 양봉 마감 (마감가 > 시가)
   if(closePrice <= openPrice)
      return(false);

   double body      = closePrice - openPrice;
   double lowerWick = MathMin(openPrice, closePrice) - lowPrice;
   double upperWick = highPrice - MathMax(openPrice, closePrice);

   // §6.1-2 — MinTailPoints
   if(lowerWick < MinTailPoints * Point)
      return(false);

   // §6.1-3 — WickToBodyRatio
   if(lowerWick < WickToBodyRatio * body)
      return(false);

   // §6.1-4 — WickToOppositeWickRatio
   if(lowerWick < WickToOppositeWickRatio * upperWick)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| §6.2 SELL 핀바 — 4조건 전부                                       |
//+------------------------------------------------------------------+
bool IsSellPinbar(int shift)
{
   double openPrice  = iOpen(Symbol(), PERIOD_M1, shift);
   double closePrice = iClose(Symbol(), PERIOD_M1, shift);
   double highPrice  = iHigh(Symbol(), PERIOD_M1, shift);
   double lowPrice   = iLow(Symbol(), PERIOD_M1, shift);

   // §6.2-1 — 음봉 마감 (마감가 < 시가)
   if(closePrice >= openPrice)
      return(false);

   double body      = openPrice - closePrice;
   double upperWick = highPrice - MathMax(openPrice, closePrice);
   double lowerWick = MathMin(openPrice, closePrice) - lowPrice;

   // §6.2-2 — MinTailPoints
   if(upperWick < MinTailPoints * Point)
      return(false);

   // §6.2-3 — WickToBodyRatio
   if(upperWick < WickToBodyRatio * body)
      return(false);

   // §6.2-4 — WickToOppositeWickRatio
   if(upperWick < WickToOppositeWickRatio * lowerWick)
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| §7.1·§7.2·§7.3 — 주문 진입 (TP=0.0)                                |
//+------------------------------------------------------------------+
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
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
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

//+------------------------------------------------------------------+
//| §4.8 / §5.8 / §10 — 심볼+매직 단일 포지션                          |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| §8 — 트레일링 스탑 (2번 방식)                                      |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| §8.1 BUY 트레일링 공식                                             |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| §8.2 SELL 트레일링 공식                                            |
//+------------------------------------------------------------------+
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

string OrderTypeName(int orderType)
{
   if(orderType == OP_BUY)
      return("BUY");
   if(orderType == OP_SELL)
      return("SELL");
   return("UNKNOWN");
}
