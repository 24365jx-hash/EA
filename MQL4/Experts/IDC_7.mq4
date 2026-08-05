//+------------------------------------------------------------------+
//|                                                         IDC_7.mq4 |
//| EA 명칭       : IDC_7                                             |
//| 적용 시장     : XAUUSD (골드 전용 / 브로커 심볼 자동 감지)         |
//| 추천 TF       : M1 (메인) / M5 참고                               |
//| 운용 방식     : OnTick 조건 분석 + Pending(BuyStop/SellStop)      |
//| 수치 표준     : Point 단위 (10 Points = 1 Pip = $0.1 on gold)     |
//+------------------------------------------------------------------+
#property copyright "IDC_7"
#property link      ""
#property version   "1.01"
#property strict
#property description "IDC_7 — Gold M1 consecutive-tick pending EA (MT4)"

//====================================================================
// ENUMS
//====================================================================
enum ENUM_LOT_MODE
  {
   LOT_MANUAL = 0,   // Manual Lot (고정 랏)
   LOT_AUTO   = 1    // Auto Lot (잔고 리스크% × SL 거리)
  };

enum ENUM_TICK_DIR
  {
   TICK_NONE = 0,
   TICK_UP   = 1,
   TICK_DOWN = 2
  };

//====================================================================
// INPUT PARAMETERS — 명세 디폴트 1:1
//====================================================================
input string InpSepSys           = "======== SYSTEM ========"; // —
input bool   InpAutoDetectGold   = true;     // 골드 심볼 자동 감지
input string InpManualSymbol     = "";       // 수동 심볼 (빈칸=자동)
input int    InpMagicNumber      = 70007;    // Magic Number
input int    InpSlippagePts      = 30;       // 시장가 청산 허용 슬리피지(Points)
input string InpTradeComment     = "IDC_7";  // 주문 코멘트

input string InpSepEntry         = "======== ENTRY (3중 조건) ========"; // —
input int    InpConsecutiveTicks = 6;        // ① 연속 틱 횟수 N (default 6)
input int    InpMoveDistancePts  = 200;      // ② 이동 거리 P Points (default 200=$2.0)
input int    InpPendingDistancePts = 50;     // Pending Distance (현재가→Stop 거리, Points)

input string InpSepTrend         = "======== STRONG TREND FILTER ========"; // —
input bool   InpUseStrongTrendFilter = true; // ③ 강한 추세 진입금지 필터 ON/OFF
input int    InpATRPeriod        = 14;       // ATR 기간
input int    InpMaxATRPts        = 400;      // Max ATR Points (초과 시 진입 차단)
input int    InpEMAPeriod        = 50;       // EMA 기간
input int    InpMaxEMADiffPts    = 100;      // Max EMA 1바 기울기 Points (초과 차단)

input string InpSepExit          = "======== EXIT / TRAILING ========"; // —
input int    InpStopLossPts      = 300;      // SL Points (default 300=$3.0) / TP=0 고정
input int    InpTrailingStartPts = 200;      // 1단계: 본전이동 트리거 Points
input int    InpTrailingStepPts  = 10;       // 2단계: 추격 스텝 Points

input string InpSepRisk          = "======== RISK / MONEY ========"; // —
input bool   InpSLGuardianOn     = true;     // SL 가디언 ON/OFF
input ENUM_LOT_MODE InpLotMode   = LOT_MANUAL; // 랏 모드
input double InpManualLots       = 0.01;     // Manual Lot
input double InpRiskPercent      = 1.0;      // Auto Lot: 잔고 대비 리스크 %
input double InpMaxDailyLossPct  = 3.0;      // 일일 손실 한도 % (평가손익 포함)

input string InpSepTime          = "======== TIME FILTER ========"; // —
input bool   InpUseTimeFilter    = true;     // 거래 시간 필터 ON/OFF
input int    InpStartHour        = 0;        // Start Hour (브로커 서버)
input int    InpStartMinute      = 0;        // Start Minute
input int    InpEndHour          = 23;       // End Hour (브로커 서버)
input int    InpEndMinute        = 59;       // End Minute

input string InpSepUI            = "======== UI ========"; // —
input bool   InpShowDashboard    = true;     // 차트 대시보드
input int    InpDashboardFontSize = 11;      // 대시보드 글자 크기
input bool   InpPrintDebug       = false;    // 디버그 로그

//====================================================================
// GLOBALS
//====================================================================
string   g_tradeSymbol = "";
double   g_point       = 0.0;
int      g_digits      = 0;

//--- consecutive tick state
double       g_lastTickPrice   = 0.0;
ENUM_TICK_DIR g_tickDir        = TICK_NONE;
int          g_tickCount       = 0;
double       g_seqStartPrice   = 0.0;
double       g_seqMovePts      = 0.0;

//--- pending candle lifetime (M1)
datetime g_pendingBarTime = 0;
int      g_pendingTicket  = -1;

//--- trailing stage tracking (per ticket)
int      g_trailTicket    = -1;
bool     g_trailStage1Done = false;

//--- daily loss
datetime g_dayStamp        = 0;
double   g_dayStartBalance = 0.0;
bool     g_dailyLossHit    = false;

//--- dashboard cache
string   g_dashReason = "";
string   g_dashLines[24];
color    g_dashColors[24];
int      g_dashCount = 0;

#define IDC7_DASH_PREFIX "IDC7_DASH_"

//====================================================================
// FORWARD DECLARATIONS
//====================================================================
bool   DetectGoldSymbol();
bool   IsGoldSymbolName(const string sym);
bool   InitTradeSymbol();
void   RefreshSymbolMeta();
string TradeSymbol();
double TradeAsk();
double TradeBid();
double PointsToPrice(const int points);
int    PriceToPoints(const double priceDelta);
double NormalizeTradePrice(const double price);
double NormalizeLots(double lots);

bool   IsTradingAllowed();
bool   IsWithinTimeFilter();
bool   IsDailyLossLimitHit();
void   UpdateDailyLossState();
double CalcLots();

int    CountOurPositions();
int    CountOurPendings();
bool   SelectOurOrderByTicket(const int ticket);
void   CancelAllPendings(const string reason);
void   ManagePendingCandleLifetime();

void   ProcessTickSequence();
bool   IsStrongTrendBlocked(string &detail);
bool   TryPlacePendingOrder();
bool   PlacePending(const int orderType, const double lots);

void   ManageOpenPosition();
void   ManageTrailingStop();
void   SLGuardianTick();
bool   ClosePositionMarket(const int ticket, const string reason);
double BrokerMinStopDistance();
int    BrokerMinStopPoints();
bool   IsSLDistanceValid(const int type, const double sl);
bool   IsBreakEvenSL(const int type, const double sl, const double openPrice);
bool   ModifySL(const int ticket, const double newSL);

void   UpdateDashboard();
void   ClearDashboard();
void   DashReset();
void   DashAdd(const string text, const color clr);
void   LogDebug(const string msg);

//====================================================================
// INIT / DEINIT / TICK
//====================================================================
int OnInit()
  {
   if(InpConsecutiveTicks < 2)
     {
      Print("IDC_7: InpConsecutiveTicks must be >= 2");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpMoveDistancePts < 0 || InpPendingDistancePts < 0 ||
      InpStopLossPts <= 0 || InpTrailingStartPts < 0 || InpTrailingStepPts < 0)
     {
      Print("IDC_7: invalid distance/SL/trailing parameters");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpATRPeriod < 1 || InpEMAPeriod < 1)
     {
      Print("IDC_7: ATR/EMA period must be >= 1");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpManualLots <= 0.0 && InpLotMode == LOT_MANUAL)
     {
      Print("IDC_7: Manual lot must be > 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRiskPercent <= 0.0 && InpLotMode == LOT_AUTO)
     {
      Print("IDC_7: Risk percent must be > 0 for Auto Lot");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpStartHour < 0 || InpStartHour > 23 || InpEndHour < 0 || InpEndHour > 23 ||
      InpStartMinute < 0 || InpStartMinute > 59 || InpEndMinute < 0 || InpEndMinute > 59)
     {
      Print("IDC_7: invalid time filter hour/minute");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!InitTradeSymbol())
     {
      Print("IDC_7: gold symbol detection failed");
      return(INIT_FAILED);
     }

   RefreshSymbolMeta();
   UpdateDailyLossState();

   g_lastTickPrice  = 0.0;
   g_tickDir        = TICK_NONE;
   g_tickCount      = 0;
   g_seqStartPrice  = 0.0;
   g_seqMovePts     = 0.0;
   g_pendingBarTime = 0;
   g_pendingTicket  = -1;
   g_trailTicket    = -1;
   g_trailStage1Done = false;
   g_dashReason     = "INIT";

   // recover pending ticket if EA restarted mid-pending
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderSymbol() != g_tradeSymbol)
         continue;
      if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP)
        {
         g_pendingTicket  = OrderTicket();
         g_pendingBarTime = iTime(g_tradeSymbol, PERIOD_M1, 0);
         break;
        }
     }

   Print("IDC_7: initialized | symbol=", g_tradeSymbol,
         " point=", DoubleToString(g_point, g_digits),
         " digits=", g_digits,
         " chartTF=", Period());

   if(InpShowDashboard)
      UpdateDashboard();

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ClearDashboard();
  }

void OnTick()
  {
   if(StringLen(g_tradeSymbol) == 0)
     {
      if(!InitTradeSymbol())
         return;
     }

   RefreshSymbolMeta();
   if(g_point <= 0.0)
      return;

   UpdateDailyLossState();

   //--- 1) SL Guardian (온틱 최우선)
   if(InpSLGuardianOn)
      SLGuardianTick();

   //--- 2) 포지션 트레일링
   ManageOpenPosition();
   ManageTrailingStop();

   //--- 3) 대기주문 M1 캔들 수명 제어
   ManagePendingCandleLifetime();

   //--- 4) 진입 조건 분석 → Pending 발주
   ProcessTickSequence();

   if(InpShowDashboard)
      UpdateDashboard();
  }

//====================================================================
// SYMBOL / BROKER HELPERS
//====================================================================
string TradeSymbol()
  {
   if(StringLen(g_tradeSymbol) > 0)
      return(g_tradeSymbol);
   return(Symbol());
  }

double TradeAsk()
  {
   return(MarketInfo(TradeSymbol(), MODE_ASK));
  }

double TradeBid()
  {
   return(MarketInfo(TradeSymbol(), MODE_BID));
  }

double PointsToPrice(const int points)
  {
   return((double)points * g_point);
  }

int PriceToPoints(const double priceDelta)
  {
   if(g_point <= 0.0)
      return(0);
   return((int)MathRound(MathAbs(priceDelta) / g_point));
  }

double NormalizeTradePrice(const double price)
  {
   return(NormalizeDouble(price, g_digits));
  }

void RefreshSymbolMeta()
  {
   g_point  = MarketInfo(TradeSymbol(), MODE_POINT);
   g_digits = (int)MarketInfo(TradeSymbol(), MODE_DIGITS);
  }

bool IsGoldSymbolName(const string sym)
  {
   string upper = sym;
   StringToUpper(upper);
   if(StringFind(upper, "XAU") >= 0)
      return(true);
   if(StringFind(upper, "GOLD") >= 0)
      return(true);
   return(false);
  }

bool IsSymbolTradableGold(const string sym)
  {
   if(StringLen(sym) == 0)
      return(false);
   if(!IsGoldSymbolName(sym))
      return(false);
   if(!SymbolSelect(sym, true))
      return(false);
   if(MarketInfo(sym, MODE_TRADEALLOWED) == 0)
      return(false);
   if(MarketInfo(sym, MODE_BID) <= 0.0 || MarketInfo(sym, MODE_ASK) <= 0.0)
      return(false);
   return(true);
  }

int GoldSymbolPriority(const string sym)
  {
   string upper = sym;
   StringToUpper(upper);
   if(upper == "XAUUSD")
      return(100);
   if(StringFind(upper, "XAUUSD") == 0)
      return(90);
   if(upper == "GOLD")
      return(80);
   if(StringFind(upper, "GOLD") == 0)
      return(70);
   if(StringFind(upper, "XAU") >= 0)
      return(60);
   return(10);
  }

bool TrySetTradeSymbol(const string sym, string &best_sym, int &best_rank)
  {
   if(!IsSymbolTradableGold(sym))
      return(false);
   int rank = GoldSymbolPriority(sym);
   if(best_sym == "" || rank > best_rank)
     {
      best_sym  = sym;
      best_rank = rank;
     }
   return(true);
  }

bool DetectGoldSymbol()
  {
   string best_sym  = "";
   int    best_rank = -1;

   if(StringLen(InpManualSymbol) > 0)
     {
      if(!TrySetTradeSymbol(InpManualSymbol, best_sym, best_rank))
        {
         Print("IDC_7: manual symbol not tradable gold: ", InpManualSymbol);
         return(false);
        }
      g_tradeSymbol = best_sym;
      return(true);
     }

   if(!InpAutoDetectGold)
     {
      if(IsSymbolTradableGold(Symbol()))
        {
         g_tradeSymbol = Symbol();
         return(true);
        }
      Print("IDC_7: chart symbol is not tradable gold and auto-detect is OFF");
      return(false);
     }

   // chart symbol first
   TrySetTradeSymbol(Symbol(), best_sym, best_rank);

   int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
     {
      string sym = SymbolName(i, false);
      if(!IsGoldSymbolName(sym))
         continue;
      TrySetTradeSymbol(sym, best_sym, best_rank);
     }

   if(best_sym == "")
     {
      Print("IDC_7: no tradable gold symbol found");
      return(false);
     }

   g_tradeSymbol = best_sym;
   return(true);
  }

bool InitTradeSymbol()
  {
   if(!DetectGoldSymbol())
      return(false);
   RefreshSymbolMeta();
   return(g_point > 0.0);
  }

//====================================================================
// TIME FILTER / DAILY LOSS / LOTS
//====================================================================
bool IsWithinTimeFilter()
  {
   if(!InpUseTimeFilter)
      return(true);

   datetime now = TimeCurrent(); // 브로커 서버 시간
   int curMin  = TimeHour(now) * 60 + TimeMinute(now);
   int startMin = InpStartHour * 60 + InpStartMinute;
   int endMin   = InpEndHour * 60 + InpEndMinute;

   if(startMin == endMin)
      return(true); // 동일 = 전일 허용

   // Start~End 분단위 포함(inclusive)
   if(startMin < endMin)
      return(curMin >= startMin && curMin <= endMin);

   // overnight wrap (예: 22:00 ~ 06:00)
   return(curMin >= startMin || curMin <= endMin);
  }

void UpdateDailyLossState()
  {
   datetime now = TimeCurrent();
   datetime day = StringToTime(TimeToString(now, TIME_DATE));

   if(g_dayStamp != day)
     {
      g_dayStamp        = day;
      g_dayStartBalance = AccountBalance();
      g_dailyLossHit    = false;
      LogDebug("New day stamp. startBalance=" + DoubleToString(g_dayStartBalance, 2));
     }

   if(InpMaxDailyLossPct <= 0.0)
     {
      g_dailyLossHit = false;
      return;
     }

   if(g_dayStartBalance <= 0.0)
     {
      g_dayStartBalance = AccountBalance();
      if(g_dayStartBalance <= 0.0)
         return;
     }

   // 당일 누적 손실(평가손익 포함) = 시작잔고 - 현재 에쿼티
   double equity = AccountEquity();
   double lossAmt = g_dayStartBalance - equity;
   double lossPct = (lossAmt / g_dayStartBalance) * 100.0;

   if(lossPct >= InpMaxDailyLossPct)
     {
      if(!g_dailyLossHit)
        {
         Print("IDC_7: daily loss limit hit | lossPct=", DoubleToString(lossPct, 2),
               "% limit=", DoubleToString(InpMaxDailyLossPct, 2),
               "% startBal=", DoubleToString(g_dayStartBalance, 2),
               " equity=", DoubleToString(equity, 2));
        }
      g_dailyLossHit = true;
     }
  }

bool IsDailyLossLimitHit()
  {
   return(g_dailyLossHit);
  }

double NormalizeLots(double lots)
  {
   double minLot  = MarketInfo(TradeSymbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(TradeSymbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(TradeSymbol(), MODE_LOTSTEP);
   if(lotStep <= 0.0)
      lotStep = 0.01;

   lots = MathFloor(lots / lotStep + 1.0e-12) * lotStep;
   if(lots < minLot)
      lots = minLot;
   if(lots > maxLot)
      lots = maxLot;

   int lotDigits = 2;
   if(lotStep < 0.01)
      lotDigits = 3;
   if(lotStep < 0.001)
      lotDigits = 4;

   return(NormalizeDouble(lots, lotDigits));
  }

double CalcLots()
  {
   if(InpLotMode == LOT_MANUAL)
      return(NormalizeLots(InpManualLots));

   // Auto Lot: Balance × Risk% / (SL_points × value_per_point_per_lot)
   double tickValue = MarketInfo(TradeSymbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(TradeSymbol(), MODE_TICKSIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || g_point <= 0.0 || InpStopLossPts <= 0)
      return(NormalizeLots(InpManualLots));

   double valuePerPointPerLot = tickValue * (g_point / tickSize);
   if(valuePerPointPerLot <= 0.0)
      return(NormalizeLots(InpManualLots));

   double riskMoney = AccountBalance() * InpRiskPercent / 100.0;
   double lots = riskMoney / ((double)InpStopLossPts * valuePerPointPerLot);
   return(NormalizeLots(lots));
  }

bool IsTradingAllowed()
  {
   if(!IsConnected())
     {
      g_dashReason = "NO_CONNECTION";
      return(false);
     }
   if(!IsTradeAllowed())
     {
      g_dashReason = "TRADE_DISABLED";
      return(false);
     }
   if(IsStopped())
     {
      g_dashReason = "EA_STOPPED";
      return(false);
     }
   if(!IsWithinTimeFilter())
     {
      g_dashReason = "TIME_FILTER";
      return(false);
     }
   if(IsDailyLossLimitHit())
     {
      g_dashReason = "DAILY_LOSS_LIMIT";
      return(false);
     }
   return(true);
  }

//====================================================================
// ORDER COUNTS
//====================================================================
int CountOurPositions()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderSymbol() != TradeSymbol())
         continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         count++;
     }
   return(count);
  }

int CountOurPendings()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderSymbol() != TradeSymbol())
         continue;
      if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP ||
         OrderType() == OP_BUYLIMIT || OrderType() == OP_SELLLIMIT)
         count++;
     }
   return(count);
  }

bool SelectOurOrderByTicket(const int ticket)
  {
   if(ticket <= 0)
      return(false);
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return(false);
   if(OrderMagicNumber() != InpMagicNumber)
      return(false);
   if(OrderSymbol() != TradeSymbol())
      return(false);
   return(true);
  }

//====================================================================
// PENDING LIFETIME (M1 candle)
//====================================================================
void CancelAllPendings(const string reason)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderSymbol() != TradeSymbol())
         continue;
      int type = OrderType();
      if(type != OP_BUYSTOP && type != OP_SELLSTOP &&
         type != OP_BUYLIMIT && type != OP_SELLLIMIT)
         continue;

      int ticket = OrderTicket();
      bool ok = OrderDelete(ticket);
      if(!ok)
         Print("IDC_7: OrderDelete failed ticket=", ticket,
               " err=", GetLastError(), " reason=", reason);
      else
         LogDebug("Pending deleted ticket=" + IntegerToString(ticket) + " reason=" + reason);
     }
   g_pendingTicket  = -1;
   g_pendingBarTime = 0;
  }

void ManagePendingCandleLifetime()
  {
   if(CountOurPendings() <= 0)
     {
      g_pendingTicket  = -1;
      g_pendingBarTime = 0;
      return;
     }

   datetime m1Bar = iTime(TradeSymbol(), PERIOD_M1, 0);
   if(m1Bar <= 0)
      return;

   // first observation after place/restart
   if(g_pendingBarTime == 0)
     {
      g_pendingBarTime = m1Bar;
      return;
     }

   // 신규 M1 캔들 형성 시 미체결 대기주문 자동 취소
   if(m1Bar != g_pendingBarTime)
     {
      Print("IDC_7: M1 candle expired — cancel unfilled pending | oldBar=",
            TimeToString(g_pendingBarTime, TIME_DATE|TIME_MINUTES),
            " newBar=", TimeToString(m1Bar, TIME_DATE|TIME_MINUTES));
      CancelAllPendings("M1_CANDLE_EXPIRED");
     }
  }

//====================================================================
// ENTRY: consecutive ticks + move distance + strong trend filter
//====================================================================
void ProcessTickSequence()
  {
   // 단일 포지션/대기주문 제어: 포지션 또는 대기주문이 있으면 추가 진입 금지
   if(CountOurPositions() > 0)
     {
      g_dashReason = "POSITION_OPEN";
      return;
     }
   if(CountOurPendings() > 0)
     {
      g_dashReason = "PENDING_EXISTS";
      return;
     }
   if(!IsTradingAllowed())
      return;

   double bid = TradeBid();
   if(bid <= 0.0)
      return;

   // mid/bid 기준 틱 방향 (골드 Bid 스트림)
   if(g_lastTickPrice <= 0.0)
     {
      g_lastTickPrice = bid;
      g_tickDir       = TICK_NONE;
      g_tickCount     = 0;
      g_seqStartPrice = bid;
      g_seqMovePts    = 0.0;
      g_dashReason    = "WAIT_TICK";
      return;
     }

   if(bid > g_lastTickPrice)
     {
      if(g_tickDir == TICK_UP)
         g_tickCount++;
      else
        {
         g_tickDir       = TICK_UP;
         g_tickCount     = 1;
         g_seqStartPrice = g_lastTickPrice;
        }
     }
   else if(bid < g_lastTickPrice)
     {
      if(g_tickDir == TICK_DOWN)
         g_tickCount++;
      else
        {
         g_tickDir       = TICK_DOWN;
         g_tickCount     = 1;
         g_seqStartPrice = g_lastTickPrice;
        }
     }
   else
     {
      // 동일가 틱: 연속성 유지하지 않음 (방향 불명) → 리셋
      g_tickDir       = TICK_NONE;
      g_tickCount     = 0;
      g_seqStartPrice = bid;
      g_seqMovePts    = 0.0;
      g_lastTickPrice = bid;
      g_dashReason    = "TICK_FLAT";
      return;
     }

   g_lastTickPrice = bid;
   g_seqMovePts    = (double)PriceToPoints(bid - g_seqStartPrice);

   // ① 연속 틱
   if(g_tickCount < InpConsecutiveTicks)
     {
      g_dashReason = "WAIT_CONSEC_TICKS";
      return;
     }

   // ② 이동 거리
   if(g_seqMovePts < (double)InpMoveDistancePts)
     {
      g_dashReason = "WAIT_MOVE_DISTANCE";
      return;
     }

   // ③ 강한 추세 필터
   string trendDetail = "";
   if(IsStrongTrendBlocked(trendDetail))
     {
      g_dashReason = "TREND_BLOCK:" + trendDetail;
      // 조건은 충족했으나 필터 차단 — 시퀀스 리셋하여 폭주 구간 재발주 억제
      g_tickDir    = TICK_NONE;
      g_tickCount  = 0;
      return;
     }

   // 3중 조건 충족 → Pending 발주
   if(TryPlacePendingOrder())
     {
      g_tickDir    = TICK_NONE;
      g_tickCount  = 0;
      g_seqMovePts = 0.0;
      g_dashReason = "PENDING_PLACED";
     }
  }

bool IsStrongTrendBlocked(string &detail)
  {
   detail = "";
   if(!InpUseStrongTrendFilter)
     {
      detail = "OFF";
      return(false);
     }

   double atr = iATR(TradeSymbol(), PERIOD_M1, InpATRPeriod, 0);
   double atrPts = (g_point > 0.0) ? (atr / g_point) : 0.0;

   double ema0 = iMA(TradeSymbol(), PERIOD_M1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema1 = iMA(TradeSymbol(), PERIOD_M1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaDiffPts = (g_point > 0.0) ? (MathAbs(ema0 - ema1) / g_point) : 0.0;

   if(atrPts > (double)InpMaxATRPts)
     {
      detail = "ATR>" + IntegerToString(InpMaxATRPts) + "(" + DoubleToString(atrPts, 1) + ")";
      return(true);
     }
   if(emaDiffPts > (double)InpMaxEMADiffPts)
     {
      detail = "EMA>" + IntegerToString(InpMaxEMADiffPts) + "(" + DoubleToString(emaDiffPts, 1) + ")";
      return(true);
     }

   detail = "OK ATR=" + DoubleToString(atrPts, 1) + " EMA=" + DoubleToString(emaDiffPts, 1);
   return(false);
  }

bool TryPlacePendingOrder()
  {
   if(g_tickDir != TICK_UP && g_tickDir != TICK_DOWN)
      return(false);

   double lots = CalcLots();
   if(lots <= 0.0)
     {
      g_dashReason = "LOT_ZERO";
      Print("IDC_7: lot calculation returned zero");
      return(false);
     }

   int orderType = (g_tickDir == TICK_UP) ? OP_BUYSTOP : OP_SELLSTOP;
   return(PlacePending(orderType, lots));
  }

bool PlacePending(const int orderType, const double lots)
  {
   RefreshRates();
   double ask = TradeAsk();
   double bid = TradeBid();
   if(ask <= 0.0 || bid <= 0.0)
      return(false);

   double stopLevelPts = MarketInfo(TradeSymbol(), MODE_STOPLEVEL);
   double freezePts    = MarketInfo(TradeSymbol(), MODE_FREEZELEVEL);
   double minDistPts   = MathMax(stopLevelPts, freezePts);
   int    pendPts      = InpPendingDistancePts;
   if((double)pendPts < minDistPts)
      pendPts = (int)MathCeil(minDistPts);

   double entry = 0.0;
   double sl    = 0.0;
   double tp    = 0.0; // TP 사용 안 함

   if(orderType == OP_BUYSTOP)
     {
      entry = NormalizeTradePrice(ask + PointsToPrice(pendPts));
      sl    = NormalizeTradePrice(entry - PointsToPrice(InpStopLossPts));
     }
   else if(orderType == OP_SELLSTOP)
     {
      entry = NormalizeTradePrice(bid - PointsToPrice(pendPts));
      sl    = NormalizeTradePrice(entry + PointsToPrice(InpStopLossPts));
     }
   else
      return(false);

   // 추가 안전: SL 거리 브로커 최소 충족
   int slDistPts = PriceToPoints(entry - sl);
   if(slDistPts < (int)minDistPts && minDistPts > 0)
     {
      if(orderType == OP_BUYSTOP)
         sl = NormalizeTradePrice(entry - PointsToPrice((int)MathCeil(minDistPts)));
      else
         sl = NormalizeTradePrice(entry + PointsToPrice((int)MathCeil(minDistPts)));
     }

   color clr = (orderType == OP_BUYSTOP) ? clrDodgerBlue : clrOrangeRed;

   ResetLastError();
   int ticket = OrderSend(TradeSymbol(), orderType, lots, entry, InpSlippagePts,
                          sl, tp, InpTradeComment, InpMagicNumber, 0, clr);

   if(ticket < 0)
     {
      int err = GetLastError();
      Print("IDC_7: OrderSend pending failed type=", orderType,
            " lots=", DoubleToString(lots, 2),
            " entry=", DoubleToString(entry, g_digits),
            " sl=", DoubleToString(sl, g_digits),
            " err=", err);
      g_dashReason = "ORDERSEND_ERR:" + IntegerToString(err);
      return(false);
     }

   g_pendingTicket   = ticket;
   g_pendingBarTime  = iTime(TradeSymbol(), PERIOD_M1, 0);
   g_trailTicket     = -1;
   g_trailStage1Done = false;

   Print("IDC_7: pending placed ticket=", ticket,
         " type=", (orderType == OP_BUYSTOP ? "BUYSTOP" : "SELLSTOP"),
         " lots=", DoubleToString(lots, 2),
         " entry=", DoubleToString(entry, g_digits),
         " sl=", DoubleToString(sl, g_digits),
         " tp=0",
         " consec=", g_tickCount,
         " movePts=", DoubleToString(g_seqMovePts, 1),
         " pendPts=", pendPts,
         " m1Bar=", TimeToString(g_pendingBarTime, TIME_DATE|TIME_MINUTES));

   return(true);
  }

//====================================================================
// EXIT: trailing 2-stage + SL guardian
//====================================================================
void ManageOpenPosition()
  {
   // 체결 후 pending 상태 클리어
   if(CountOurPositions() > 0 && CountOurPendings() == 0)
     {
      g_pendingTicket  = -1;
      g_pendingBarTime = 0;
     }

   // 포지션 없으면 트레일 상태 리셋
   if(CountOurPositions() == 0)
     {
      g_trailTicket     = -1;
      g_trailStage1Done = false;
     }
  }

double BrokerMinStopDistance()
  {
   double stopLvl = MarketInfo(TradeSymbol(), MODE_STOPLEVEL) * g_point;
   double freeze  = MarketInfo(TradeSymbol(), MODE_FREEZELEVEL) * g_point;
   return(MathMax(stopLvl, freeze));
  }

int BrokerMinStopPoints()
  {
   if(g_point <= 0.0)
      return(0);
   return((int)MathCeil(BrokerMinStopDistance() / g_point));
  }

// 요청 SL이 브로커 STOPLEVEL/FREEZELEVEL을 만족하는지 (클램프 금지 — 손실 SL로 끌어내리지 않음)
bool IsSLDistanceValid(const int type, const double sl)
  {
   double minDist = BrokerMinStopDistance();
   if(minDist <= 0.0)
      return(true);

   RefreshRates();
   if(type == OP_BUY)
      return(TradeBid() - sl >= minDist - g_point * 0.1);
   if(type == OP_SELL)
      return(sl - TradeAsk() >= minDist - g_point * 0.1);
   return(false);
  }

bool IsBreakEvenSL(const int type, const double sl, const double openPrice)
  {
   if(sl <= 0.0 || g_point <= 0.0)
      return(false);
   if(type == OP_BUY)
      return(sl >= openPrice - g_point * 0.1);
   if(type == OP_SELL)
      return(sl <= openPrice + g_point * 0.1);
   return(false);
  }

// 요청한 SL 그대로만 적용. STOPLEVEL 미달 시 절대 시장쪽으로 클램프하지 않고 거부.
bool ModifySL(const int ticket, const double newSL)
  {
   if(!SelectOurOrderByTicket(ticket))
      return(false);

   double openPrice = OrderOpenPrice();
   double tp        = OrderTakeProfit(); // 유지 (정상 0)
   double curSL     = OrderStopLoss();
   int    type      = OrderType();
   double sl        = NormalizeTradePrice(newSL);

   if(!IsSLDistanceValid(type, sl))
     {
      LogDebug("ModifySL rejected (stop/freeze level) ticket=" + IntegerToString(ticket) +
               " wantSL=" + DoubleToString(sl, g_digits) +
               " minPts=" + IntegerToString(BrokerMinStopPoints()));
      return(false);
     }

   // 유리 방향만 허용 (동일/불리 거부). SL=0 초기주입은 허용.
   if(type == OP_BUY)
     {
      if(curSL > 0.0 && sl <= curSL + g_point * 0.1)
         return(false);
     }
   else if(type == OP_SELL)
     {
      if(curSL > 0.0 && sl >= curSL - g_point * 0.1)
         return(false);
     }
   else
      return(false);

   ResetLastError();
   bool ok = OrderModify(ticket, openPrice, sl, tp, 0, clrYellow);
   if(!ok)
     {
      Print("IDC_7: OrderModify SL fail ticket=", ticket,
            " err=", GetLastError(),
            " sl=", DoubleToString(sl, g_digits));
      return(false);
     }

   // 실제 체결된 SL 재확인
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return(false);

   double actualSL = OrderStopLoss();
   if(type == OP_BUY && actualSL < sl - g_point * 0.5)
      return(false);
   if(type == OP_SELL && (actualSL <= 0.0 || actualSL > sl + g_point * 0.5))
      return(false);

   return(true);
  }

void ManageTrailingStop()
  {
   if(InpTrailingStartPts <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderSymbol() != TradeSymbol())
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      int ticket = OrderTicket();
      double openPrice = OrderOpenPrice();
      double curSL     = OrderStopLoss();
      double point     = g_point;
      if(point <= 0.0)
         continue;

      double profitPts = 0.0;
      if(type == OP_BUY)
         profitPts = (TradeBid() - openPrice) / point;
      else
         profitPts = (openPrice - TradeAsk()) / point;

      // 1단계 미도달
      if(profitPts < (double)InpTrailingStartPts)
         continue;

      // 티켓 변경 시 스테이지 리셋
      if(g_trailTicket != ticket)
        {
         g_trailTicket     = ticket;
         g_trailStage1Done = false;
        }

      double targetSL = 0.0;
      int minStopPts = BrokerMinStopPoints();

      //--- 1단계: SL → 진입가 (원금 보존)
      // STOPLEVEL보다 수익이 작으면 본전 SL 자체가 불법 → 대기 (절대 손실쪽으로 당기지 않음)
      if(!g_trailStage1Done)
        {
         if(IsBreakEvenSL(type, curSL, openPrice))
           {
            g_trailStage1Done = true;
           }
         else if(profitPts + 1.0e-9 < (double)minStopPts)
           {
            g_dashReason = "TRAIL_WAIT_STOPLEVEL";
            LogDebug("STAGE1 wait stop level ticket=" + IntegerToString(ticket) +
                     " profitPts=" + DoubleToString(profitPts, 1) +
                     " needPts>=" + IntegerToString(minStopPts));
            continue;
           }
         else
           {
            targetSL = NormalizeTradePrice(openPrice);
            if(ModifySL(ticket, targetSL))
              {
               // 실제 SL이 본전 이상인지 재검증 후에만 STAGE1 완료
               if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES) &&
                  IsBreakEvenSL(type, OrderStopLoss(), openPrice))
                 {
                  g_trailStage1Done = true;
                  Print("IDC_7: trailing STAGE1 BE ticket=", ticket,
                        " sl=", DoubleToString(OrderStopLoss(), g_digits),
                        " profitPts=", DoubleToString(profitPts, 1),
                        " minStopPts=", minStopPts);
                 }
               else
                 {
                  Print("IDC_7: STAGE1 BE verify FAIL ticket=", ticket,
                        " actualSL=", DoubleToString(OrderStopLoss(), g_digits),
                        " open=", DoubleToString(openPrice, g_digits));
                 }
              }
            continue; // 1단계 처리 후 이번 틱은 종료
           }
        }

      //--- 2단계: TrailingStep 간격 실시간 추격 (본전 이상만)
      if(InpTrailingStepPts <= 0)
         continue;

      double beyond = profitPts - (double)InpTrailingStartPts;
      int steps = (int)MathFloor(beyond / (double)InpTrailingStepPts);
      if(steps <= 0)
         continue;

      if(type == OP_BUY)
         targetSL = openPrice + PointsToPrice(steps * InpTrailingStepPts);
      else
         targetSL = openPrice - PointsToPrice(steps * InpTrailingStepPts);

      targetSL = NormalizeTradePrice(targetSL);

      // 본전 미만으로 내려가는 타깃 금지
      if(type == OP_BUY && targetSL < openPrice - point * 0.1)
         continue;
      if(type == OP_SELL && targetSL > openPrice + point * 0.1)
         continue;

      // STOPLEVEL 미달이면 이번 스텝 스킵 (클램프하여 손실 SL 만들지 않음)
      if(!IsSLDistanceValid(type, targetSL))
         continue;

      bool improve = false;
      if(type == OP_BUY)
         improve = (curSL == 0.0 || targetSL > curSL + point * 0.5);
      else
         improve = (curSL == 0.0 || targetSL < curSL - point * 0.5);

      if(!improve)
         continue;

      if(ModifySL(ticket, targetSL))
        {
         if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            Print("IDC_7: trailing STAGE2 ticket=", ticket,
                  " sl=", DoubleToString(OrderStopLoss(), g_digits),
                  " steps=", steps,
                  " profitPts=", DoubleToString(profitPts, 1));
        }
     }
  }

// SL Guardian: 설정 SL 포인트 초과 손실 시 온틱 시장가 강제 청산
// + SL 누락 시 즉시 재설정
void SLGuardianTick()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderSymbol() != TradeSymbol())
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      int ticket = OrderTicket();
      double openPrice = OrderOpenPrice();
      double curSL     = OrderStopLoss();
      double point      = g_point;
      if(point <= 0.0)
         continue;

      // SL 누락 복구
      if(curSL == 0.0 && InpStopLossPts > 0)
        {
         double restoreSL = 0.0;
         if(type == OP_BUY)
            restoreSL = NormalizeTradePrice(openPrice - PointsToPrice(InpStopLossPts));
         else
            restoreSL = NormalizeTradePrice(openPrice + PointsToPrice(InpStopLossPts));

         if(ModifySL(ticket, restoreSL))
            Print("IDC_7: SL Guardian restored missing SL ticket=", ticket,
                  " sl=", DoubleToString(restoreSL, g_digits));
        }

      // 실시간 손실 포인트 감시 → 설정 SL 초과 시 강제 청산
      double lossPts = 0.0;
      if(type == OP_BUY)
         lossPts = (openPrice - TradeBid()) / point;
      else
         lossPts = (TradeAsk() - openPrice) / point;

      if(lossPts >= (double)InpStopLossPts)
        {
         Print("IDC_7: SL Guardian FORCE CLOSE ticket=", ticket,
               " lossPts=", DoubleToString(lossPts, 1),
               " limit=", InpStopLossPts);
         ClosePositionMarket(ticket, "SL_GUARDIAN");
        }
     }
  }

bool ClosePositionMarket(const int ticket, const string reason)
  {
   if(!SelectOurOrderByTicket(ticket))
      return(false);

   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL)
      return(false);

   RefreshRates();
   double price = (type == OP_BUY) ? TradeBid() : TradeAsk();
   double lots  = OrderLots();

   ResetLastError();
   bool ok = OrderClose(ticket, lots, price, InpSlippagePts, clrRed);
   if(!ok)
     {
      Print("IDC_7: OrderClose failed ticket=", ticket,
            " err=", GetLastError(), " reason=", reason);
      return(false);
     }

   Print("IDC_7: position closed ticket=", ticket, " reason=", reason);
   g_trailTicket     = -1;
   g_trailStage1Done = false;
   return(true);
  }

//====================================================================
// DASHBOARD
//====================================================================
void LogDebug(const string msg)
  {
   if(InpPrintDebug)
      Print("IDC_7|DBG|", msg);
  }

void ClearDashboard()
  {
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
     {
      string name = ObjectName(i);
      if(StringFind(name, IDC7_DASH_PREFIX) == 0)
         ObjectDelete(name);
     }
  }

void DashReset()
  {
   g_dashCount = 0;
  }

void DashAdd(const string text, const color clr)
  {
   if(g_dashCount >= 24)
      return;
   g_dashLines[g_dashCount]  = text;
   g_dashColors[g_dashCount] = clr;
   g_dashCount++;
  }

void UpdateDashboard()
  {
   DashReset();

   string trendDetail = "";
   bool trendBlock = IsStrongTrendBlocked(trendDetail);

   double atr = iATR(TradeSymbol(), PERIOD_M1, InpATRPeriod, 0);
   double atrPts = (g_point > 0.0) ? atr / g_point : 0.0;
   double ema0 = iMA(TradeSymbol(), PERIOD_M1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema1 = iMA(TradeSymbol(), PERIOD_M1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaDiffPts = (g_point > 0.0) ? MathAbs(ema0 - ema1) / g_point : 0.0;

   double equity = AccountEquity();
   double lossPct = 0.0;
   if(g_dayStartBalance > 0.0)
      lossPct = ((g_dayStartBalance - equity) / g_dayStartBalance) * 100.0;

   string dirStr = "NONE";
   if(g_tickDir == TICK_UP)
      dirStr = "UP";
   else if(g_tickDir == TICK_DOWN)
      dirStr = "DOWN";

   color okC   = clrLime;
   color badC  = clrTomato;
   color neuC  = clrSilver;
   color headC = clrGold;

   DashAdd("IDC_7  |  " + TradeSymbol() + "  M1 Pending EA", headC);
   DashAdd("------------------------------------------------", neuC);
   DashAdd(StringFormat("Ticks: %s x%d / need %d", dirStr, g_tickCount, InpConsecutiveTicks),
           (g_tickCount >= InpConsecutiveTicks ? okC : neuC));
   DashAdd(StringFormat("Move: %.0f / need %d pts", g_seqMovePts, InpMoveDistancePts),
           (g_seqMovePts >= (double)InpMoveDistancePts ? okC : neuC));
   DashAdd(StringFormat("TrendFilter: %s  %s",
                        (InpUseStrongTrendFilter ? "ON" : "OFF"), trendDetail),
           (InpUseStrongTrendFilter ? (trendBlock ? badC : okC) : neuC));
   DashAdd(StringFormat("ATR(14): %.1f / max %d   EMA50d: %.1f / max %d",
                        atrPts, InpMaxATRPts, emaDiffPts, InpMaxEMADiffPts), neuC);
   DashAdd(StringFormat("PendingDist: %d pts   SL: %d pts   TP: 0",
                        InpPendingDistancePts, InpStopLossPts), neuC);
   DashAdd(StringFormat("Trail: start %d → BE, step %d",
                        InpTrailingStartPts, InpTrailingStepPts), neuC);
   DashAdd(StringFormat("Lot: %s  lots=%.2f  risk%%=%.2f",
                        (InpLotMode == LOT_MANUAL ? "MANUAL" : "AUTO"),
                        CalcLots(), InpRiskPercent), neuC);
   DashAdd(StringFormat("DailyLoss: %.2f%% / max %.2f%%  %s",
                        lossPct, InpMaxDailyLossPct,
                        (g_dailyLossHit ? "STOPPED" : "OK")),
           (g_dailyLossHit ? badC : okC));
   DashAdd(StringFormat("TimeFilter: %s  %02d:%02d-%02d:%02d  %s",
                        (InpUseTimeFilter ? "ON" : "OFF"),
                        InpStartHour, InpStartMinute, InpEndHour, InpEndMinute,
                        (IsWithinTimeFilter() ? "IN" : "OUT")),
           (IsWithinTimeFilter() ? okC : badC));
   DashAdd(StringFormat("Pos: %d  Pending: %d  Guard: %s  Stage1: %s",
                        CountOurPositions(), CountOurPendings(),
                        (InpSLGuardianOn ? "ON" : "OFF"),
                        (g_trailStage1Done ? "DONE" : "WAIT")), neuC);
   DashAdd("Reason: " + g_dashReason, neuC);

   int fontSize = InpDashboardFontSize;
   if(fontSize < 8)
      fontSize = 8;
   if(fontSize > 18)
      fontSize = 18;

   int y = 20;
   for(int i = 0; i < g_dashCount; i++)
     {
      string name = IDC7_DASH_PREFIX + IntegerToString(i);
      if(ObjectFind(name) < 0)
        {
         ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
         ObjectSet(name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSet(name, OBJPROP_XDISTANCE, 10);
         ObjectSet(name, OBJPROP_SELECTABLE, 0);
        }
      ObjectSet(name, OBJPROP_YDISTANCE, y);
      ObjectSetText(name, g_dashLines[i], fontSize, "Consolas", g_dashColors[i]);
      y += fontSize + 4;
     }

   // remove extras
   for(int j = g_dashCount; j < 24; j++)
     {
      string name2 = IDC7_DASH_PREFIX + IntegerToString(j);
      if(ObjectFind(name2) >= 0)
         ObjectDelete(name2);
     }
  }

//+------------------------------------------------------------------+
