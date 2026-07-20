//+------------------------------------------------------------------+
//|                                                       IDC_X.mq4  |
//|           GOLD M1 추세 정밀 상태머신 시스템 (MT4 전용 완전무결판)   |
//|  Spec: IDC_X SYSTEM SPECIFICATION — 100% 원본전략 매핑 구현        |
//+------------------------------------------------------------------+
#property copyright "IDC_X"
#property link      ""
#property version   "1.00"
#property strict

//====================================================================
// 1) INPUT PARAMETERS — 명세서 §2 전수 매핑 + 사용자 추가 요구
//====================================================================
input string           InpSepUI           = "=== UI / Dashboard ==="; // -
input bool             InpShowDashboard   = true;   // 화면 실시간 모니터링 대시보드
input int              InpDashboardFontSize = 12;   // 대시보드 글자 크기

input string           InpSepSymbol       = "=== Symbol / Time ==="; // -
input bool             InpAutoDetectGold  = true;   // 브로커별 골드 심볼 자동 스캔
input string           InpManualSymbol    = "";     // 수동 심볼 (비우면 자동)

input string           InpSepTrend        = "=== Trend / Filters ==="; // -
input int              InpFastEmaPeriod   = 9;      // Fast EMA
input int              InpSlowEmaPeriod   = 50;     // Slow EMA (터치/돌파 기준)
input int              InpTrendEmaPeriod  = 34;     // 시각 각도용 Trend EMA
input int              InpRsiPeriod       = 14;     // RSI 기간
input double           InpRsiUpper        = 52.0;   // RSI 상단
input double           InpRsiLower        = 48.0;   // RSI 하단
input int              InpObservationBars = 55;     // 크로스 후 관찰 봉 수
input int              InpEmaGraceBars    = 3;      // 50EMA 터치 후 유예 봉 수
input int              InpMinEmaDistancePts = 30;   // 9-50EMA 최소 이격(포인트)
input double           InpMinEmaAngle     = 5.0;    // 34EMA 최소 시각 각도(도)
input int              InpAngleLookbackBars = 5;    // 사람눈 각도 산출 lookback 봉

input string           InpSepTrade        = "=== Trade / Risk ==="; // -
input double           InpLots            = 0.50;   // 랏
input int              InpStopLossPoints  = 200;    // 필수 안전 손절 포인트
input int              InpTrailingStartPts = 200;   // 1차 SL 본전 이동 수익 포인트
input int              InpTrailingStepPts = 10;     // 계단식 Floor 스텝 포인트
input int              InpMagicNumber     = 80008;  // 매직넘버
input int              InpSlippagePts     = 30;     // 최대 슬리피지 포인트
input string           InpTradeComment    = "IDC_X"; // 주문 코멘트

input string           InpSepGuard        = "=== SL Guardian ==="; // -
input bool             InpSLGuardianOn    = true;   // SL 가디언 ON/OFF
input int              InpSLGuardianRetryMs = 250;  // 가디언 OrderModify 재시도 간격(ms)

//====================================================================
// 2) GLOBAL STATE — 명세서 §3 상태머신 변수
//====================================================================
string   g_TradeSymbol          = "";
bool     g_SymbolReady          = false;
int      g_DetectedPeriod       = 0;       // T시간(타임프레임) 자동감지 결과
int      g_BrokerGmtOffsetMin   = 0;       // 브로커 서버 GMT 오프셋(분)

int      g_CycleDirection       = 0;       // +1 BUY / -1 SELL / 0 none
int      g_CrossBarIndex        = 0;       // 크로스 후 경과 봉 (개시=1)
bool     g_50EmaTouched         = false;   // 순수 터치 래치
int      g_GraceBarCounter      = -1;      // 유예 카운터 (-1=비활성)
bool     g_IsTradedInCycle      = false;   // 사이클 내 신호 소진

datetime g_LastM1BarTime        = 0;
bool     g_LatchSkipThisBar     = false;   // 유예초과 강제 격리 래치

// 대시보드/필터 스냅샷 (매 M1 완성봉 갱신)
string   g_DashCycle            = "NONE";
string   g_DashCrossIdx         = "-";
string   g_DashGrace            = "-";
string   g_DashTouch            = "IDLE";
string   g_DashAntiBreak        = "OK";
string   g_DashFastAbove        = "-";
string   g_DashCandleQuality    = "-";
string   g_DashRsi              = "-";
string   g_DashDistance         = "-";
string   g_DashAngle            = "-";
string   g_DashEntryReady       = "NO";
string   g_DashLastAction       = "INIT";
string   g_DashSLGuard          = "IDLE";
string   g_DashTouchDiag        = "-";  // bar1 OHLC vs 50EMA 수치 진단
bool     g_AntiBreakThisBar     = false;
double   g_LastAngleDeg         = 0.0;
double   g_LastRsi              = 0.0;
double   g_LastEmaDistPts       = 0.0;

uint     g_LastModifyAttemptMs  = 0;

#define DASH_PREFIX "IDC_X_DASH_"
#define ANGLE_EPS   0.0000001

//====================================================================
// 3) FORWARD DECLARATIONS
//====================================================================
bool   AutoDetectGoldSymbol(string &outSymbol);
bool   ResolveTradeSymbol();
void   DetectTimeframeAndBrokerTime();
bool   IsNewM1Bar();
void   OnNewM1BarLogic();
void   ResetCycleFull(const string reason);
void   KillCycleObservationExceeded();
bool   DetectEmaCross(int &dirOut);
void   ProcessAntiBreakout(const double slowEma);
bool   DetectPure50EmaTouch(const double slowEma);
void   UpdateTouchDiagnostics(const double slowEma);
bool   CheckEntrySetupBuy(const double fastEma, const double slowEma,
                          const double trendAngle, const double rsi1,
                          const double distPts);
bool   CheckEntrySetupSell(const double fastEma, const double slowEma,
                           const double trendAngle, const double rsi1,
                           const double distPts);
bool   ExecuteMarketEntry(const int dir);
double GetEma(const int period, const int shift);
double GetRsi(const int shift);
double GetPointSize();
double PointsToPrice(const int pts);
int    PriceToPoints(const double priceDiff);
double CalcHumanEyeAngle34(const int shiftRef);
double CalcEmaDistancePoints(const int shift);
int    CountOurPositions();
bool   HasOurPosition();
void   ManageTrailingStops();
void   SLGuardianTick();
bool   EnsureInitialSL(const int ticket);
bool   ModifySLSafe(const int ticket, const double newSL);
void   UpdateDashboard();
void   DeleteDashboard();
void   SetDashLine(const int row, const string key, const string text, const color clr);
string DirName(const int d);
double BidP();
double AskP();
int    DigitsSym();
double NormalizeP(const double price);

//====================================================================
// 4) INIT / DEINIT / TICK
//====================================================================
int OnInit()
{
   DetectTimeframeAndBrokerTime();

   if(!ResolveTradeSymbol())
   {
      Print("IDC_X|INIT|FAIL|Gold symbol not resolved. ManualSymbol='", InpManualSymbol, "'");
      g_SymbolReady = false;
   }
   else
   {
      g_SymbolReady = true;
      Print("IDC_X|INIT|OK|symbol=", g_TradeSymbol,
            "|chartTF=", Period(),
            "|forcedDataTF=M1",
            "|brokerGmtOffsetMin=", g_BrokerGmtOffsetMin);
   }

   if(!SymbolSelect(g_TradeSymbol, true) && g_SymbolReady)
      Print("IDC_X|WARN|SymbolSelect failed for ", g_TradeSymbol);

   g_LastM1BarTime = iTime(g_TradeSymbol, PERIOD_M1, 0);
   ResetCycleFull("INIT");
   g_DashLastAction = "INIT_OK";

   if(InpShowDashboard)
      UpdateDashboard();
   else
      DeleteDashboard();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteDashboard();
}

void OnTick()
{
   DetectTimeframeAndBrokerTime();

   if(!g_SymbolReady)
   {
      if(!ResolveTradeSymbol())
      {
         g_DashLastAction = "NO_SYMBOL";
         if(InpShowDashboard) UpdateDashboard();
         return;
      }
      g_SymbolReady = true;
   }

   //--- SL Guardian: 매 틱 무결 감시 (완성봉 로직과 독립)
   if(InpSLGuardianOn)
      SLGuardianTick();

   //--- 트레일링 (진입가 절대 기준) — 틱마다
   ManageTrailingStops();

   //--- M1 새 봉에서만 상태머신/필터/진입 판단 (bar1 확정 데이터)
   if(IsNewM1Bar())
      OnNewM1BarLogic();

   if(InpShowDashboard)
      UpdateDashboard();
   else
      DeleteDashboard();
}

//====================================================================
// 5) SYMBOL + T-TIME AUTO DETECT
//====================================================================
bool ResolveTradeSymbol()
{
   string manual = InpManualSymbol;
   StringTrimLeft(manual);
   StringTrimRight(manual);

   if(StringLen(manual) > 0)
   {
      if(SymbolSelect(manual, true) || MarketInfo(manual, MODE_BID) > 0.0)
      {
         g_TradeSymbol = manual;
         return(true);
      }
      Print("IDC_X|SYMBOL|manual not tradable: ", manual);
      // fall through to auto if enabled
   }

   if(InpAutoDetectGold)
   {
      string found = "";
      if(AutoDetectGoldSymbol(found))
      {
         g_TradeSymbol = found;
         return(true);
      }
   }

   // 차트 심볼이 골드계열이면 최후 수단
   string chartSym = Symbol();
   string up = chartSym;
   StringToUpper(up);
   if(StringFind(up, "XAU") >= 0 || StringFind(up, "GOLD") >= 0)
   {
      g_TradeSymbol = chartSym;
      return(true);
   }

   g_TradeSymbol = "";
   return(false);
}

bool AutoDetectGoldSymbol(string &outSymbol)
{
   outSymbol = "";
   string chartSym = Symbol();
   string chartUp = chartSym;
   StringToUpper(chartUp);

   // 1) 차트 심볼 우선 (골드면)
   if(StringFind(chartUp, "XAUUSD") >= 0 || chartUp == "GOLD" || StringFind(chartUp, "GOLD") == 0)
   {
      outSymbol = chartSym;
      return(true);
   }

   // 2) 마켓워치 + 전체 심볼 스캔
   string best = "";
   int bestScore = -1;
   int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
   {
      string s = SymbolName(i, false);
      if(s == "") continue;
      string u = s;
      StringToUpper(u);

      int score = -1;
      if(u == "XAUUSD")                         score = 100;
      else if(u == "GOLD")                      score = 95;
      else if(StringFind(u, "XAUUSD") == 0)     score = 90;  // XAUUSD.a / m / #
      else if(StringFind(u, "GOLD") == 0 && StringFind(u, "GOLDs") < 0) score = 85;
      else if(StringFind(u, "XAU") >= 0 && StringFind(u, "USD") >= 0) score = 80;
      else if(StringFind(u, "XAU") >= 0)        score = 60;
      else if(StringFind(u, "GOLD") >= 0)       score = 50;

      if(score < 0) continue;
      if(!SymbolSelect(s, true)) continue;
      double bid = MarketInfo(s, MODE_BID);
      if(bid <= 0.0) continue;

      if(score > bestScore)
      {
         bestScore = score;
         best = s;
      }
   }

   if(best != "")
   {
      outSymbol = best;
      return(true);
   }
   return(false);
}

void DetectTimeframeAndBrokerTime()
{
   g_DetectedPeriod = Period(); // 차트 T시간 자동감지
   datetime server = TimeCurrent();
   datetime gmt    = TimeGMT();
   g_BrokerGmtOffsetMin = (int)((server - gmt) / 60);
}

//====================================================================
// 6) M1 BAR ENGINE + STATE MACHINE (§3, §4)
//====================================================================
bool IsNewM1Bar()
{
   datetime t = iTime(g_TradeSymbol, PERIOD_M1, 0);
   if(t <= 0) return(false);
   if(t != g_LastM1BarTime)
   {
      g_LastM1BarTime = t;
      return(true);
   }
   return(false);
}

void ResetCycleFull(const string reason)
{
   g_CycleDirection   = 0;
   g_CrossBarIndex    = 0;
   g_50EmaTouched     = false;
   g_GraceBarCounter  = -1;
   g_IsTradedInCycle  = false;
   g_LatchSkipThisBar = false;
   g_DashCycle        = "NONE";
   g_DashTouch        = "IDLE";
   g_DashGrace        = "-";
   g_DashEntryReady   = "NO";
   g_DashLastAction   = "RESET:" + reason;
}

void KillCycleObservationExceeded()
{
   // §3-2: 관찰창 초과 시 진입제어/유예 메모리 완벽 소멸
   g_CycleDirection   = 0;
   g_CrossBarIndex    = 0;
   g_50EmaTouched     = false;
   g_GraceBarCounter  = -1;
   // traded 플래그는 사이클 사망과 함께 청소
   g_IsTradedInCycle  = false;
   g_DashLastAction   = "OBS_WINDOW_DEAD";
   g_DashCycle        = "DEAD";
   g_DashTouch        = "IDLE";
   g_DashGrace        = "-";
   g_DashEntryReady   = "NO";
}

void OnNewM1BarLogic()
{
   g_LatchSkipThisBar = false;

   //----- §3-3 유예 카운터 누적 + 초과 시 강제 격리 래치 락 -----
   if(g_50EmaTouched && g_GraceBarCounter >= 1)
   {
      g_GraceBarCounter++;
      if(g_GraceBarCounter > InpEmaGraceBars)
      {
         g_50EmaTouched    = false;
         g_GraceBarCounter = -1;
         g_LatchSkipThisBar = true; // 당해 봉 판단 전면 스킵
         g_DashTouch       = "GRACE_EXPIRED_LATCH";
         g_DashGrace       = "LOCK";
         g_DashLastAction  = "LATCH_LOCK_SKIP";
      }
   }

   //----- 지표 (전부 bar1 = 완성봉) -----
   double fast1 = GetEma(InpFastEmaPeriod, 1);
   double slow1 = GetEma(InpSlowEmaPeriod, 1);
   double rsi1  = GetRsi(1);
   double distPts = CalcEmaDistancePoints(1);
   double angle = CalcHumanEyeAngle34(1);

   g_LastRsi        = rsi1;
   g_LastEmaDistPts = distPts;
   g_LastAngleDeg   = angle;

   //----- §3-1 크로스 판단 -----
   int crossDir = 0;
   bool newCross = DetectEmaCross(crossDir);
   if(newCross)
   {
      g_CycleDirection  = crossDir;
      g_CrossBarIndex   = 1;          // 개시 시점 = 1
      g_50EmaTouched    = false;
      g_GraceBarCounter = -1;
      g_IsTradedInCycle = false;
      g_LatchSkipThisBar = false;     // 새 사이클이면 당봉부터 판단 허용
      g_DashCycle       = DirName(crossDir);
      g_DashTouch       = "IDLE";
      g_DashGrace       = "-";
      g_DashLastAction  = "NEW_CROSS_" + DirName(crossDir);
   }
   else
   {
      // §3-2: 새 봉마다 경과 봉 누적
      if(g_CycleDirection != 0)
         g_CrossBarIndex++;
   }

   g_DashCrossIdx = IntegerToString(g_CrossBarIndex);
   g_DashCycle    = (g_CycleDirection == 0 ? "NONE" : DirName(g_CycleDirection));
   if(g_50EmaTouched)
      g_DashGrace = IntegerToString(g_GraceBarCounter) + "/" + IntegerToString(InpEmaGraceBars);
   else if(!g_LatchSkipThisBar)
      g_DashGrace = "OFF";

   //----- §3-2 관찰 윈도우 사망 -----
   if(g_CycleDirection != 0 && g_CrossBarIndex > InpObservationBars)
   {
      KillCycleObservationExceeded();
      g_DashFastAbove = "-";
      g_DashCandleQuality = "-";
      g_DashRsi = "-";
      g_DashDistance = "-";
      g_DashAngle = "-";
      g_DashAntiBreak = "-";
      return;
   }

   //----- 래치 락: 당해 봉 판단 스킵 -----
   if(g_LatchSkipThisBar)
   {
      g_DashEntryReady = "NO";
      g_DashAntiBreak  = "SKIP";
      g_DashFastAbove  = "SKIP";
      g_DashCandleQuality = "SKIP";
      g_DashRsi = "SKIP";
      g_DashDistance = "SKIP";
      g_DashAngle = "SKIP";
      return;
   }

   //----- 사이클 없거나 이미 소진 -----
   if(g_CycleDirection == 0 || g_IsTradedInCycle)
   {
      g_DashEntryReady = "NO";
      if(g_IsTradedInCycle) g_DashLastAction = "SIGNAL_CONSUMED";
      g_DashAntiBreak = "-";
      g_DashFastAbove = "-";
      g_DashCandleQuality = "-";
      g_DashRsi = DoubleToStr(rsi1, 2);
      g_DashDistance = DoubleToStr(distPts, 1);
      g_DashAngle = DoubleToStr(angle, 2);
      return;
   }

   //----- §4-1 Anti-Breakout (50EMA 몸통 돌파/침범 절대 불허 → 유예 소멸) -----
   g_AntiBreakThisBar = false;
   ProcessAntiBreakout(slow1);
   UpdateTouchDiagnostics(slow1);

   //----- §4-2 순수 터치 (돌파 아님: 몸통은 EMA 한쪽, 꼬리만 접촉) -----
   // 당봉이 몸통 침범(안티브레이크)이면 터치 판정 금지 — 돌파를 터치로 오인 방지
   if(!g_50EmaTouched && !g_AntiBreakThisBar)
      DetectPure50EmaTouch(slow1);

   if(g_50EmaTouched)
      g_DashGrace = IntegerToString(g_GraceBarCounter) + "/" + IntegerToString(InpEmaGraceBars);

   //----- §4-3 유예 기간 내부에서만 최종 진입 셋업 -----
   bool inGrace = (g_50EmaTouched && g_GraceBarCounter >= 1 && g_GraceBarCounter <= InpEmaGraceBars);
   bool ready = false;

   if(inGrace)
   {
      if(g_CycleDirection == 1)
         ready = CheckEntrySetupBuy(fast1, slow1, angle, rsi1, distPts);
      else if(g_CycleDirection == -1)
         ready = CheckEntrySetupSell(fast1, slow1, angle, rsi1, distPts);
   }
   else
   {
      // 유예 밖: 필터 상태만 표시(기능은 유예 내에서만 활성)
      g_DashFastAbove = "WAIT_TOUCH";
      g_DashCandleQuality = "WAIT_TOUCH";
      g_DashRsi = DoubleToStr(rsi1, 2);
      g_DashDistance = DoubleToStr(distPts, 1) + "pt";
      g_DashAngle = DoubleToStr(angle, 2) + "deg";
      g_DashEntryReady = "NO";
   }

   g_DashEntryReady = (ready ? "YES" : "NO");

   //----- §4-4 진입 집행 (신호 즉시 소진) -----
   if(ready)
   {
      // 체결 성공 여부와 무관하게 신호 소진 (§3-2)
      g_IsTradedInCycle = true;
      bool ok = ExecuteMarketEntry(g_CycleDirection);
      g_DashLastAction = (ok ? "ENTRY_OK_" : "ENTRY_FAIL_") + DirName(g_CycleDirection);
      g_DashEntryReady = (ok ? "FIRED" : "FAIL");
   }
}

//====================================================================
// 7) CROSS / ANTI-BREAKOUT / PURE TOUCH
//====================================================================
bool DetectEmaCross(int &dirOut)
{
   dirOut = 0;
   double fast1 = GetEma(InpFastEmaPeriod, 1);
   double slow1 = GetEma(InpSlowEmaPeriod, 1);
   double fast2 = GetEma(InpFastEmaPeriod, 2);
   double slow2 = GetEma(InpSlowEmaPeriod, 2);

   if(fast1 == 0.0 || slow1 == 0.0 || fast2 == 0.0 || slow2 == 0.0)
      return(false);

   // BUY: 9EMA가 50EMA를 상향 돌파
   if(fast2 <= slow2 && fast1 > slow1)
   {
      dirOut = 1;
      return(true);
   }
   // SELL: 9EMA가 50EMA를 하향 돌파
   if(fast2 >= slow2 && fast1 < slow1)
   {
      dirOut = -1;
      return(true);
   }
   return(false);
}

void ProcessAntiBreakout(const double slowEma)
{
   double o = iOpen(g_TradeSymbol, PERIOD_M1, 1);
   double c = iClose(g_TradeSymbol, PERIOD_M1, 1);

   if(g_CycleDirection == 1)
   {
      // BUY: Open 또는 Close가 50EMA 미만으로 하향 침범 → 유예 강제 소멸
      // 50EMA 몸통 돌파/침범 절대 불허 (= 순수 터치 절대 아님)
      if(o < slowEma || c < slowEma)
      {
         g_50EmaTouched     = false;
         g_GraceBarCounter  = -1;
         g_AntiBreakThisBar = true;
         g_DashAntiBreak    = "RESET_BELOW_50";
         g_DashTouch        = "KILLED_BREAKOUT";
         g_DashLastAction   = "ANTI_BREAKOUT_BUY";
         return;
      }
      g_DashAntiBreak = "OK";
   }
   else if(g_CycleDirection == -1)
   {
      // SELL 대칭: Open 또는 Close가 50EMA 초과로 상향 침범 → 소멸
      if(o > slowEma || c > slowEma)
      {
         g_50EmaTouched     = false;
         g_GraceBarCounter  = -1;
         g_AntiBreakThisBar = true;
         g_DashAntiBreak    = "RESET_ABOVE_50";
         g_DashTouch        = "KILLED_BREAKOUT";
         g_DashLastAction   = "ANTI_BREAKOUT_SELL";
         return;
      }
      g_DashAntiBreak = "OK";
   }
   else
      g_DashAntiBreak = "-";
}

// bar1 시가/종가/저가/고가 vs 50EMA 수치를 대시보드·로그에 고정 출력 (논쟁 방지)
void UpdateTouchDiagnostics(const double slowEma)
{
   double o = iOpen(g_TradeSymbol, PERIOD_M1, 1);
   double c = iClose(g_TradeSymbol, PERIOD_M1, 1);
   double h = iHigh(g_TradeSymbol, PERIOD_M1, 1);
   double l = iLow(g_TradeSymbol, PERIOD_M1, 1);
   int dig = DigitsSym();

   string reason = "";
   if(g_CycleDirection == 1)
   {
      if(o < slowEma || c < slowEma)
         reason = "BODY_BELOW(돌파-터치불허)";
      else if(l > slowEma)
         reason = "LOW_ABOVE(미도달)";
      else
         reason = "PURE_OK(몸통위+저가접촉)";
   }
   else if(g_CycleDirection == -1)
   {
      if(o > slowEma || c > slowEma)
         reason = "BODY_ABOVE(돌파-터치불허)";
      else if(h < slowEma)
         reason = "HIGH_BELOW(미도달)";
      else
         reason = "PURE_OK(몸통아래+고가접촉)";
   }
   else
      reason = "NO_CYCLE";

   g_DashTouchDiag =
      "O=" + DoubleToStr(o, dig) +
      " C=" + DoubleToStr(c, dig) +
      " L=" + DoubleToStr(l, dig) +
      " H=" + DoubleToStr(h, dig) +
      " EMA50=" + DoubleToStr(slowEma, dig) +
      " | L-EMA=" + DoubleToStr(l - slowEma, dig) +
      " | " + reason;

   Print("IDC_X|TOUCH_DIAG|", TimeToString(iTime(g_TradeSymbol, PERIOD_M1, 1), TIME_DATE|TIME_MINUTES),
         "|", g_DashTouchDiag);
}

bool DetectPure50EmaTouch(const double slowEma)
{
   double o = iOpen(g_TradeSymbol, PERIOD_M1, 1);
   double c = iClose(g_TradeSymbol, PERIOD_M1, 1);
   double h = iHigh(g_TradeSymbol, PERIOD_M1, 1);
   double l = iLow(g_TradeSymbol, PERIOD_M1, 1);

   // 돌파 마감 이탈봉이 아니라는 전제하에만 터치 인정
   if(g_CycleDirection == 1)
   {
      // BUY 순수 터치: 몸통(시가·종가)은 완벽히 50EMA 위, 저가만 스치거나 찌름
      // 산술: open>slow && close>slow && low<=slow
      // ※ close/open이 EMA 아래로 가는 구조는 절대 터치로 인정하지 않음 (돌파 불허)
      if(o > slowEma && c > slowEma && l <= slowEma)
      {
         g_50EmaTouched    = true;
         g_GraceBarCounter = 1;
         g_DashTouch       = "PURE_TOUCH_BUY";
         g_DashLastAction  = "TOUCH_ARMED_BUY";
         return(true);
      }
      g_DashTouch = "NO_TOUCH";
      return(false);
   }

   if(g_CycleDirection == -1)
   {
      // SELL 대칭: 몸통은 50EMA 아래, 고가만 스침
      if(o < slowEma && c < slowEma && h >= slowEma)
      {
         g_50EmaTouched    = true;
         g_GraceBarCounter = 1;
         g_DashTouch       = "PURE_TOUCH_SELL";
         g_DashLastAction  = "TOUCH_ARMED_SELL";
         return(true);
      }
      g_DashTouch = "NO_TOUCH";
      return(false);
   }

   g_DashTouch = "IDLE";
   return(false);
}

//====================================================================
// 8) ENTRY SETUP FILTERS (§4-3)
//====================================================================
bool CheckEntrySetupBuy(const double fastEma, const double slowEma,
                        const double trendAngle, const double rsi1,
                        const double distPts)
{
   double o = iOpen(g_TradeSymbol, PERIOD_M1, 1);
   double c = iClose(g_TradeSymbol, PERIOD_M1, 1);
   double h = iHigh(g_TradeSymbol, PERIOD_M1, 1);
   double l = iLow(g_TradeSymbol, PERIOD_M1, 1);

   // 1) 9EMA 상향 돌파 이탈: High와 Close 모두 9EMA 위
   bool fastOk = (h > fastEma && c > fastEma);
   g_DashFastAbove = (fastOk ? "OK" : "FAIL");

   // 2) 양봉 품질: 순수 양봉 + 몸통 > (위꼬리+아래꼬리)
   bool bull = (c > o) && ((c - o) > ((h - c) + (o - l)));
   g_DashCandleQuality = (bull ? "OK" : "FAIL");

   // 3) RSI: rsi >= (Upper + 0.5) → 기본 52.5
   double rsiNeed = InpRsiUpper + 0.5;
   bool rsiOk = (rsi1 >= rsiNeed);
   g_DashRsi = DoubleToStr(rsi1, 2) + (rsiOk ? " OK" : " FAIL");

   // 4) 이격도
   bool distOk = (distPts >= (double)InpMinEmaDistancePts);
   g_DashDistance = DoubleToStr(distPts, 1) + "pt" + (distOk ? " OK" : " FAIL");

   // 5) 시각 각도 (사람눈 = 차트 픽셀 arctan) — BUY는 +각도
   bool angOk = (trendAngle >= InpMinEmaAngle);
   g_DashAngle = DoubleToStr(trendAngle, 2) + "deg" + (angOk ? " OK" : " FAIL");

   return(fastOk && bull && rsiOk && distOk && angOk);
}

bool CheckEntrySetupSell(const double fastEma, const double slowEma,
                         const double trendAngle, const double rsi1,
                         const double distPts)
{
   double o = iOpen(g_TradeSymbol, PERIOD_M1, 1);
   double c = iClose(g_TradeSymbol, PERIOD_M1, 1);
   double h = iHigh(g_TradeSymbol, PERIOD_M1, 1);
   double l = iLow(g_TradeSymbol, PERIOD_M1, 1);

   // 1) 9EMA 하향 이탈: Low와 Close 모두 9EMA 아래
   bool fastOk = (l < fastEma && c < fastEma);
   g_DashFastAbove = (fastOk ? "OK" : "FAIL");

   // 2) 음봉 품질 대칭
   bool bear = (c < o) && ((o - c) > ((h - o) + (c - l)));
   g_DashCandleQuality = (bear ? "OK" : "FAIL");

   // 3) RSI: rsi <= (Lower - 0.5) → 기본 47.5
   double rsiNeed = InpRsiLower - 0.5;
   bool rsiOk = (rsi1 <= rsiNeed);
   g_DashRsi = DoubleToStr(rsi1, 2) + (rsiOk ? " OK" : " FAIL");

   // 4) 이격도
   bool distOk = (distPts >= (double)InpMinEmaDistancePts);
   g_DashDistance = DoubleToStr(distPts, 1) + "pt" + (distOk ? " OK" : " FAIL");

   // 5) 시각 각도 — SELL은 하방 각도(음수) 절대값
   bool angOk = (trendAngle <= -InpMinEmaAngle);
   g_DashAngle = DoubleToStr(trendAngle, 2) + "deg" + (angOk ? " OK" : " FAIL");

   return(fastOk && bear && rsiOk && distOk && angOk);
}

//====================================================================
// 9) HUMAN-EYE ANGLE (§4-3 시각 각도 = 차트 픽셀 기반 arctan)
//====================================================================
double CalcHumanEyeAngle34(const int shiftRef)
{
   int lookback = InpAngleLookbackBars;
   if(lookback < 1) lookback = 1;

   double emaNow  = GetEma(InpTrendEmaPeriod, shiftRef);
   double emaPast = GetEma(InpTrendEmaPeriod, shiftRef + lookback);
   if(emaNow == 0.0 || emaPast == 0.0)
      return(0.0);

   // 차트에 보이는 실제 픽셀 스케일 (사람 눈이 보는 각도)
   int chartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS, 0);

   if(chartWidth < 10)  chartWidth = 800;
   if(chartHeight < 10) chartHeight = 400;
   if(visibleBars < 2)  visibleBars = 100;

   double priceRange = priceMax - priceMin;
   if(priceRange < ANGLE_EPS)
      priceRange = GetPointSize() * 1000.0;

   double pxPerBar   = (double)chartWidth  / (double)visibleBars;
   double pxPerPrice = (double)chartHeight / priceRange;

   double dx = (double)lookback * pxPerBar;                 // 가로 픽셀
   double dy = (emaNow - emaPast) * pxPerPrice;             // 세로 픽셀 (부호 유지)

   if(MathAbs(dx) < ANGLE_EPS)
      return(0.0);

   double rad = MathArctan(dy / dx);
   double deg = rad * 180.0 / 3.14159265358979323846;
   return(deg);
}

double CalcEmaDistancePoints(const int shift)
{
   double fast = GetEma(InpFastEmaPeriod, shift);
   double slow = GetEma(InpSlowEmaPeriod, shift);
   if(fast == 0.0 || slow == 0.0) return(0.0);
   return((double)PriceToPoints(MathAbs(fast - slow)));
}

//====================================================================
// 10) EXECUTION
//====================================================================
bool ExecuteMarketEntry(const int dir)
{
   if(HasOurPosition())
   {
      Print("IDC_X|ENTRY|skip already in position");
      return(false);
   }

   RefreshRates();
   double point = GetPointSize();
   int    dig   = DigitsSym();
   double lots  = InpLots;
   double minLot = MarketInfo(g_TradeSymbol, MODE_MINLOT);
   double maxLot = MarketInfo(g_TradeSymbol, MODE_MAXLOT);
   double lotStep= MarketInfo(g_TradeSymbol, MODE_LOTSTEP);
   if(lotStep <= 0.0) lotStep = 0.01;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / lotStep + 1e-9) * lotStep;
   lots = NormalizeDouble(lots, 2);

   int cmd = (dir > 0 ? OP_BUY : OP_SELL);
   double price = (dir > 0 ? AskP() : BidP());
   double sl = 0.0;
   if(dir > 0)
      sl = NormalizeP(price - PointsToPrice(InpStopLossPoints));
   else
      sl = NormalizeP(price + PointsToPrice(InpStopLossPoints));

   // TP 일절 사용 안 함
   double tp = 0.0;

   // 1차: SL 동시 주입 (명세: 진입 즉시 필수 안전 손절)
   int ticket = OrderSend(g_TradeSymbol, cmd, lots, price, InpSlippagePts,
                          sl, tp, InpTradeComment, InpMagicNumber, 0,
                          (dir > 0 ? clrDodgerBlue : clrOrangeRed));
   if(ticket < 0)
   {
      int err = GetLastError();
      Print("IDC_X|ENTRY|OrderSend+SL fail err=", err, " → ECN fallback SL=0");
      // 2차: 전브로커(ECN) 호환 — SL=0 진입 후 가디언이 즉시 강제 주입
      RefreshRates();
      price = (dir > 0 ? AskP() : BidP());
      ticket = OrderSend(g_TradeSymbol, cmd, lots, price, InpSlippagePts,
                         0, 0, InpTradeComment, InpMagicNumber, 0,
                         (dir > 0 ? clrDodgerBlue : clrOrangeRed));
      if(ticket < 0)
      {
         Print("IDC_X|ENTRY|OrderSend fail err=", GetLastError(), " price=", price);
         return(false);
      }
   }

   Print("IDC_X|ENTRY|OK ticket=", ticket, " dir=", DirName(dir),
         " price=", OrderOpenPrice(), " lots=", lots);

   // 즉시 SL 재확인/주입 (가디언 — SL 누락 절대 불허)
   EnsureInitialSL(ticket);

   return(true);
}

//====================================================================
// 11) TRAILING STOP (§5) — 진입가 절대 기준 + Floor 계단
//====================================================================
void ManageTrailingStops()
{
   double point = GetPointSize();
   if(point <= 0.0) return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderSymbol() != g_TradeSymbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      double openPrice = OrderOpenPrice();
      double curSL     = OrderStopLoss();
      int    type      = OrderType();
      int    ticket    = OrderTicket();

      double profitPts = 0.0;
      if(type == OP_BUY)
         profitPts = (BidP() - openPrice) / point;
      else
         profitPts = (openPrice - AskP()) / point;

      // §5-1: 1차 트리거 미달이면 유지
      if(profitPts < (double)InpTrailingStartPts)
         continue;

      // §5-2: Floor 계단
      int steps = (int)MathFloor((profitPts - (double)InpTrailingStartPts) / (double)InpTrailingStepPts);
      if(steps < 0) steps = 0;

      double newSL = 0.0;
      if(type == OP_BUY)
      {
         newSL = openPrice
                 + PointsToPrice(InpTrailingStartPts)
                 + PointsToPrice(steps * InpTrailingStepPts);
      }
      else
      {
         newSL = openPrice
                 - PointsToPrice(InpTrailingStartPts)
                 - PointsToPrice(steps * InpTrailingStepPts);
      }
      newSL = NormalizeP(newSL);

      // 유리 방향만 전진
      bool improve = false;
      if(type == OP_BUY)
         improve = (curSL == 0.0 || newSL > curSL + point * 0.5);
      else
         improve = (curSL == 0.0 || newSL < curSL - point * 0.5);

      if(!improve) continue;

      ModifySLSafe(ticket, newSL);
   }
}

//====================================================================
// 12) SL GUARDIAN — 손절 실실/누락/거부 무결 감시
//====================================================================
void SLGuardianTick()
{
   int missing = 0;
   int fixed   = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderSymbol() != g_TradeSymbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      int ticket = OrderTicket();
      double sl  = OrderStopLoss();

      if(sl == 0.0)
      {
         missing++;
         if(EnsureInitialSL(ticket))
            fixed++;
      }
   }

   if(missing > 0)
      g_DashSLGuard = "FIX " + IntegerToString(fixed) + "/" + IntegerToString(missing);
   else
      g_DashSLGuard = "OK";
}

bool EnsureInitialSL(const int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return(false);
   if(OrderStopLoss() != 0.0)
      return(true);

   double openPrice = OrderOpenPrice();
   double newSL = 0.0;
   if(OrderType() == OP_BUY)
      newSL = NormalizeP(openPrice - PointsToPrice(InpStopLossPoints));
   else if(OrderType() == OP_SELL)
      newSL = NormalizeP(openPrice + PointsToPrice(InpStopLossPoints));
   else
      return(false);

   return(ModifySLSafe(ticket, newSL));
}

bool ModifySLSafe(const int ticket, const double newSL)
{
   uint now = GetTickCount();
   if(g_LastModifyAttemptMs != 0 && (now - g_LastModifyAttemptMs) < (uint)InpSLGuardianRetryMs)
      return(false);
   g_LastModifyAttemptMs = now;

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return(false);

   double openPrice = OrderOpenPrice();
   double tp        = OrderTakeProfit(); // 기존 TP 유지(본 시스템은 0)
   int    type      = OrderType();
   double point     = GetPointSize();
   double curSL     = OrderStopLoss();
   bool   initialFill = (curSL == 0.0); // SL 누락 강제 주입 모드

   // STOPLEVEL / FREEZELEVEL 브로커 마진 필터
   double stopLvl = MarketInfo(g_TradeSymbol, MODE_STOPLEVEL) * point;
   double freeze  = MarketInfo(g_TradeSymbol, MODE_FREEZELEVEL) * point;
   double minDist = MathMax(stopLvl, freeze);

   double sl = NormalizeP(newSL);
   RefreshRates();

   if(type == OP_BUY)
   {
      double maxSL = BidP() - minDist;
      if(minDist > 0.0 && sl > maxSL)
         sl = NormalizeP(maxSL);
      if(sl <= 0.0) return(false);
      // 불리 수정 금지 — 단, SL=0 초기 주입은 허용
      if(!initialFill && sl <= curSL)
         return(false);
   }
   else if(type == OP_SELL)
   {
      double minSL = AskP() + minDist;
      if(minDist > 0.0 && sl < minSL)
         sl = NormalizeP(minSL);
      if(sl <= 0.0) return(false);
      if(!initialFill && sl >= curSL)
         return(false);
   }
   else
      return(false);

   bool ok = OrderModify(ticket, openPrice, sl, tp, 0, clrYellow);
   if(!ok)
   {
      int err = GetLastError();
      Print("IDC_X|SL|OrderModify fail ticket=", ticket, " err=", err, " sl=", sl);
      g_DashSLGuard = "ERR " + IntegerToString(err);
      return(false);
   }
   return(true);
}

//====================================================================
// 13) INDICATORS / PRICE UTILS — 전부 PERIOD_M1 bar 확정 데이터
//====================================================================
double GetEma(const int period, const int shift)
{
   return(iMA(g_TradeSymbol, PERIOD_M1, period, 0, MODE_EMA, PRICE_CLOSE, shift));
}

double GetRsi(const int shift)
{
   return(iRSI(g_TradeSymbol, PERIOD_M1, InpRsiPeriod, PRICE_CLOSE, shift));
}

double GetPointSize()
{
   double p = MarketInfo(g_TradeSymbol, MODE_POINT);
   if(p <= 0.0) p = Point;
   return(p);
}

double PointsToPrice(const int pts)
{
   return((double)pts * GetPointSize());
}

int PriceToPoints(const double priceDiff)
{
   double p = GetPointSize();
   if(p <= 0.0) return(0);
   return((int)MathRound(priceDiff / p));
}

double BidP()
{
   RefreshRates();
   double b = MarketInfo(g_TradeSymbol, MODE_BID);
   if(b <= 0.0) b = Bid;
   return(b);
}

double AskP()
{
   RefreshRates();
   double a = MarketInfo(g_TradeSymbol, MODE_ASK);
   if(a <= 0.0) a = Ask;
   return(a);
}

int DigitsSym()
{
   int d = (int)MarketInfo(g_TradeSymbol, MODE_DIGITS);
   if(d <= 0) d = Digits;
   return(d);
}

double NormalizeP(const double price)
{
   return(NormalizeDouble(price, DigitsSym()));
}

int CountOurPositions()
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderSymbol() != g_TradeSymbol) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL) n++;
   }
   return(n);
}

bool HasOurPosition()
{
   return(CountOurPositions() > 0);
}

string DirName(const int d)
{
   if(d > 0) return("BUY");
   if(d < 0) return("SELL");
   return("NONE");
}

//====================================================================
// 14) DASHBOARD — 좌측 상단, 매 M1 필터 상황, ON/OFF
//====================================================================
void DeleteDashboard()
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, DASH_PREFIX) == 0)
         ObjectDelete(name);
   }
}

void SetDashLine(const int row, const string key, const string text, const color clr)
{
   string name = DASH_PREFIX + key;
   if(ObjectFind(name) < 0)
   {
      ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
      ObjectSet(name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSet(name, OBJPROP_XDISTANCE, 8);
      ObjectSet(name, OBJPROP_SELECTABLE, 0);
      ObjectSet(name, OBJPROP_HIDDEN, 1);
   }
   ObjectSet(name, OBJPROP_YDISTANCE, 12 + row * (InpDashboardFontSize + 4));
   ObjectSetText(name, text, InpDashboardFontSize, "Consolas", clr);
}

void UpdateDashboard()
{
   if(!InpShowDashboard)
   {
      DeleteDashboard();
      return;
   }

   string tfName = "M" + IntegerToString(g_DetectedPeriod);
   if(g_DetectedPeriod == PERIOD_M1) tfName = "M1";
   else if(g_DetectedPeriod == PERIOD_M5) tfName = "M5";
   else if(g_DetectedPeriod == PERIOD_M15) tfName = "M15";
   else if(g_DetectedPeriod == PERIOD_H1) tfName = "H1";

   color okC   = clrLime;
   color badC  = clrTomato;
   color neuC  = clrSilver;
   color headC = clrAqua;

   int r = 0;
   SetDashLine(r++, "T0", "IDC_X | GOLD M1 STATE MACHINE", headC);
   SetDashLine(r++, "T1", "Symbol: " + (g_TradeSymbol == "" ? "N/A" : g_TradeSymbol)
                        + " | ChartTF: " + tfName
                        + " | Data: M1"
                        + " | GMT+: " + IntegerToString(g_BrokerGmtOffsetMin), neuC);

   SetDashLine(r++, "T2", "Cycle: " + g_DashCycle
                        + " | CrossBar: " + g_DashCrossIdx + "/" + IntegerToString(InpObservationBars)
                        + " | Traded: " + (g_IsTradedInCycle ? "YES" : "NO"), 
                        (g_CycleDirection != 0 ? okC : neuC));

   color touchC = neuC;
   if(StringFind(g_DashTouch, "PURE_TOUCH") == 0) touchC = okC;
   if(StringFind(g_DashTouch, "KILLED") == 0 || g_DashTouch == "NO_TOUCH") touchC = badC;
   SetDashLine(r++, "T3", "50EMA Touch: " + g_DashTouch
                        + " | Grace: " + g_DashGrace
                        + " | AntiBreak: " + g_DashAntiBreak, touchC);
   SetDashLine(r++, "T3b", "TouchDiag: " + g_DashTouchDiag, neuC);

   color fC = (StringFind(g_DashFastAbove, "OK") >= 0 ? okC :
              (StringFind(g_DashFastAbove, "FAIL") >= 0 ? badC : neuC));
   SetDashLine(r++, "T4", "Filter FastEMA: " + g_DashFastAbove, fC);

   color qC = (StringFind(g_DashCandleQuality, "OK") >= 0 ? okC :
              (StringFind(g_DashCandleQuality, "FAIL") >= 0 ? badC : neuC));
   SetDashLine(r++, "T5", "Filter Candle:  " + g_DashCandleQuality, qC);

   color rC = (StringFind(g_DashRsi, "OK") >= 0 ? okC :
              (StringFind(g_DashRsi, "FAIL") >= 0 ? badC : neuC));
   SetDashLine(r++, "T6", "Filter RSI:     " + g_DashRsi, rC);

   color dC = (StringFind(g_DashDistance, "OK") >= 0 ? okC :
              (StringFind(g_DashDistance, "FAIL") >= 0 ? badC : neuC));
   SetDashLine(r++, "T7", "Filter Dist:    " + g_DashDistance, dC);

   color aC = (StringFind(g_DashAngle, "OK") >= 0 ? okC :
              (StringFind(g_DashAngle, "FAIL") >= 0 ? badC : neuC));
   SetDashLine(r++, "T8", "Filter Angle:   " + g_DashAngle + " (eye-px)", aC);

   color eC = (g_DashEntryReady == "YES" || g_DashEntryReady == "FIRED" ? okC : badC);
   SetDashLine(r++, "T9", "ENTRY READY:    " + g_DashEntryReady
                        + " | Last: " + g_DashLastAction, eC);

   SetDashLine(r++, "TA", "SL Guardian:    " + g_DashSLGuard
                        + (InpSLGuardianOn ? " [ON]" : " [OFF]")
                        + " | Pos: " + IntegerToString(CountOurPositions()),
                        (InpSLGuardianOn ? okC : neuC));

   SetDashLine(r++, "TB", "Server: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
                        + " | Bar1: " + TimeToString(iTime(g_TradeSymbol, PERIOD_M1, 1), TIME_DATE|TIME_MINUTES),
                        neuC);

   if(Symbol() != g_TradeSymbol)
      SetDashLine(r++, "TC", "WARN: Chart!=TradeSymbol → eye-angle uses this chart scale", badC);
   if(g_DetectedPeriod != PERIOD_M1)
      SetDashLine(r++, "TD", "WARN: Attach on M1 for eye-angle == human view (data still M1)", badC);
}

//+------------------------------------------------------------------+
