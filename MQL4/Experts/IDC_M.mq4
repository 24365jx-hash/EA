//+------------------------------------------------------------------+
//| IDC_M.mq4  Session Flow Rider (Strategy B)                       |
//| EA 완전본 안전 포맷 v1.0 · 교육용 포맷                            |
//| Platform: MT4 only | Default symbol: US100                         |
//+------------------------------------------------------------------+
#property copyright "IDC_M v1.0"
#property link      ""
#property version   "1.00"
#property strict

//--- LAYER 0: 원본 전략 B (Session Flow) — 변경 금지(헌법락)

//=== 프로젝트 / 심볼 =================================================
input string   InpTradeSymbol           = "US100";     // 거래 심볼 (USTEC, XAUUSD 등)
input int      InpMagic                 = 20261116;    // 매직넘버
input int      InpSlippage              = 30;          // 슬리피지(포인트)

//=== 차트 / 세션 (사용자 조정) ========================================
input int      InpSignalTF              = 5;           // 신호 주기(분) M5=5
input int      InpAsiaStartHour         = 0;           // 아시아 시작(서버시)
input int      InpAsiaEndHour           = 8;           // 아시아 종료(서버시)
input bool     InpUseLondon             = true;        // 런던 구간 거래
input int      InpLondonStartHour       = 8;           // 런던 시작
input int      InpLondonEndHour         = 12;          // 런던 종료
input bool     InpUseNewYork            = true;        // 뉴욕 구간 거래
input int      InpNewYorkStartHour      = 13;          // 뉴욕 시작
input int      InpNewYorkEndHour        = 21;          // 뉴욕 종료

//=== 전략 파라미터 (포인트) ==========================================
input int      InpBreakBufferPts        = 20;          // 레인지 돌파 버퍼(포인트)
input int      InpH1_EMA_Period         = 50;          // H1 EMA 기간
input int      InpM5_EMA_Period         = 20;          // M5 EMA 기간
input int      InpSwingBars             = 8;           // SL 스윙 봉 수
input int      InpSL_BufferPts          = 50;          // SL 버퍼(포인트)
input int      InpPullbackMaxBars       = 12;          // 돌파 후 풀백 대기 봉 수

//=== 트레일링 (기본 200/200/10) =======================================
input int      InpTrailStartPts         = 200;         // 트레일 시작 이익(포인트)
input int      InpTrailLockPts          = 200;         // 최초 SL 이동(진입가±포인트)
input int      InpTrailStepPts          = 10;          // 스텝 추격(포인트)

//=== 랏 (수동/오토) ====================================================
enum ENUM_IDC_LOTS_MODE { IDC_LOTS_FIXED=0, IDC_LOTS_RISK_PCT=1 };
input ENUM_IDC_LOTS_MODE InpLotsMode    = IDC_LOTS_RISK_PCT;
input double   InpFixedLots             = 0.01;        // 고정 랏
input double   InpRiskPercent           = 0.5;         // 리스크 % (오토)

//=== 리스크 / 프랍 =====================================================
input double   InpDailyLossLimitPct     = 4.0;         // 일일 손실 한도 %
input double   InpTotalDDLimitPct       = 9.0;         // 총 낙폭 한도 %
input int      InpMaxTradesPerDay       = 8;           // 일일 최대 진입
input int      InpMinTradesPerDay       = 2;           // 일일 최소 목표(임계 완화)

//=== Guardian / 뉴스 (Guardian만 기본) ===============================
input long     InpMaxSpreadPts          = 0;           // 최대 스프레드(0=무제한)
input int      InpFridayStopMins        = 60;          // 금요일 마감 전 진입금지(분)
input int      InpRolloverStartHour     = 23;          // 롤오버 시작
input int      InpRolloverEndHour       = 1;           // 롤오버 종료
input bool     InpNewsGuardian          = true;        // 뉴스 Guardian (차단 아님)
input int      InpNewsGuard1StartHour   = 14;          // 가드 창1 시작(서버)
input int      InpNewsGuard1EndHour     = 16;          // 가드 창1 종료
input int      InpNewsExtraSLPts        = 80;          // 가드 시 SL 추가(포인트)
input long     InpSpreadSpikePts        = 0;           // 스프레드 급등 기준(0=off)

//=== Quality / 자가학습 ==============================================
input bool     InpLearningOn            = true;
input int      InpQualityMinScore       = 55;          // 최소 품질 점수
input int      InpQualityFloorScore     = 40;          // 일말 완화 하한
input int      InpLearnEveryNTrades     = 5;           // N거래마다 임계 미세조정

//=== 기타 ==============================================================
input bool     InpDebugLog              = false;       // 진입조건 디버그 로그

//--- LAYER 1: Quality Engine (추가 — 원본 대체 없음)
//--- LAYER 2: Guardian / Risk
//--- LAYER 3: Trailing / Execution

string   g_sym;
double   g_point;
int      g_digits;
datetime g_lastEntryBarTime = 0;
datetime g_dayAnchor = 0;
double   g_dayStartEquity = 0;
double   g_initBalance = 0;
int      g_tradesToday = 0;
int      g_totalLearnTrades = 0;
double   g_adaptThreshold = 0;

// 돌파 상태
bool     g_breakUp = false;
bool     g_breakDn = false;
datetime g_breakTime = 0;

double   g_asiaHigh = 0;
double   g_asiaLow  = 0;
bool     g_rangeValid = false;

//+------------------------------------------------------------------+
int IDC_Period()
  {
   switch(InpSignalTF)
     {
      case 1: return PERIOD_M1;
      case 5: return PERIOD_M5;
      case 15: return PERIOD_M15;
      case 30: return PERIOD_M30;
      case 60: return PERIOD_H1;
     }
   return PERIOD_M5;
  }

//+------------------------------------------------------------------+
bool IDC_EnsureSymbol()
  {
   if(StringLen(InpTradeSymbol) < 1)
      g_sym = Symbol();
   else
      g_sym = InpTradeSymbol;
   if(MarketInfo(g_sym, MODE_BID) <= 0)
     {
      if(MarketInfo(Symbol(), MODE_BID) > 0)
         g_sym = Symbol();
      else
         return false;
     }
   g_point = MarketInfo(g_sym, MODE_POINT);
   g_digits = (int)MarketInfo(g_sym, MODE_DIGITS);
   if(g_point <= 0)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
double IDC_PtsToPrice(const int pts)
  { return (double)pts * g_point; }

//+------------------------------------------------------------------+
long IDC_SpreadPts()
  {
   double ask = MarketInfo(g_sym, MODE_ASK);
   double bid = MarketInfo(g_sym, MODE_BID);
   return (long)MathRound((ask - bid) / g_point);
  }

//+------------------------------------------------------------------+
void IDC_ResetDayStats()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime d0 = StructToTime(dt);
   if(d0 != g_dayAnchor)
     {
      g_dayAnchor = d0;
      g_dayStartEquity = AccountEquity();
      g_tradesToday = 0;
      g_breakUp = false; g_breakDn = false;
      g_breakTime = 0;
     }
  }

//+------------------------------------------------------------------+
double IDC_DailyLossPct()
  {
   if(g_dayStartEquity <= 0) return 0;
   double dd = (g_dayStartEquity - AccountEquity()) / g_dayStartEquity * 100.0;
   return (dd > 0) ? dd : 0;
  }

double IDC_TotalDDPct()
  {
   if(g_initBalance <= 0) return 0;
   double dd = (g_initBalance - AccountEquity()) / g_initBalance * 100.0;
   return (dd > 0) ? dd : 0;
  }

//+------------------------------------------------------------------+
bool IDC_InHourWindow(const int h, const int startH, const int endH)
  {
   if(startH == endH) return false;
   if(startH < endH)
      return (h >= startH && h < endH);
   return (h >= startH || h < endH);
  }

bool IDC_TradeSessionOk()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(InpUseLondon && IDC_InHourWindow(h, InpLondonStartHour, InpLondonEndHour))
      return true;
   if(InpUseNewYork && IDC_InHourWindow(h, InpNewYorkStartHour, InpNewYorkEndHour))
      return true;
   return false;
  }

//+------------------------------------------------------------------+
bool IDC_NewsGuardActive()
  {
   if(!InpNewsGuardian) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(IDC_InHourWindow(dt.hour, InpNewsGuard1StartHour, InpNewsGuard1EndHour))
      return true;
   if(InpSpreadSpikePts > 0 && IDC_SpreadPts() >= InpSpreadSpikePts)
      return true;
   return false;
  }

bool IDC_RolloverBlock()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return IDC_InHourWindow(dt.hour, InpRolloverStartHour, InpRolloverEndHour);
  }

bool IDC_FridayBlock()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != 5) return false;
   int minsLeft = (24 - dt.hour) * 60 - dt.min;
   return (minsLeft <= InpFridayStopMins);
  }

//+------------------------------------------------------------------+
bool IDC_GuardianAllowEntry(string &why)
  {
   why = "";
   if(InpMaxSpreadPts > 0 && IDC_SpreadPts() > InpMaxSpreadPts)
     { why = "spread"; return false; }
   if(IDC_RolloverBlock())
     { why = "rollover"; return false; }
   if(IDC_FridayBlock())
     { why = "friday"; return false; }
   if(IDC_DailyLossPct() >= InpDailyLossLimitPct)
     { why = "daily_dd"; return false; }
   if(IDC_TotalDDPct() >= InpTotalDDLimitPct)
     { why = "total_dd"; return false; }
   if(g_tradesToday >= InpMaxTradesPerDay)
     { why = "max_trades"; return false; }
   if(!IDC_TradeSessionOk())
     { why = "session"; return false; }
   return true;
  }

//+------------------------------------------------------------------+
void IDC_CalcAsiaRange()
  {
   g_rangeValid = false;
   g_asiaHigh = -1e100;
   g_asiaLow  = 1e100;
   int p = IDC_Period();
   int bars = iBars(g_sym, p);
   if(bars < 20) return;

   datetime today0 = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   for(int i = 1; i < MathMin(bars - 1, 500); i++)
     {
      datetime bt = iTime(g_sym, p, i);
      if(bt < today0)
         break;
      MqlDateTime bdt;
      TimeToStruct(bt, bdt);
      if(!IDC_InHourWindow(bdt.hour, InpAsiaStartHour, InpAsiaEndHour))
         continue;
      double hi = iHigh(g_sym, p, i);
      double lo = iLow(g_sym, p, i);
      if(hi > g_asiaHigh) g_asiaHigh = hi;
      if(lo < g_asiaLow)  g_asiaLow  = lo;
     }
   if(g_asiaHigh > g_asiaLow && g_asiaHigh < 1e50)
      g_rangeValid = true;
  }

//+------------------------------------------------------------------+
int IDC_CountOpen()
  {
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagic) continue;
      if(OrderSymbol() != g_sym) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         c++;
     }
   return c;
  }

//+------------------------------------------------------------------+
int IDC_DynamicQualityThreshold()
  {
   double th = (double)InpQualityMinScore;
   if(g_adaptThreshold > 0)
      th = g_adaptThreshold;
   if(g_tradesToday >= InpMinTradesPerDay)
      return (int)MathRound(th);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int mins = dt.hour * 60 + dt.min;
   int endMins = InpNewYorkEndHour * 60;
   if(endMins <= mins) return (int)MathMax((double)InpQualityFloorScore, th - 8);
   double dayProg = (double)mins / (double)MathMax(1, endMins);
   double relax = (1.0 - dayProg) * 10.0;
   int out = (int)MathRound(th - relax);
   return (int)MathMax((double)InpQualityFloorScore, out);
  }

//+------------------------------------------------------------------+
int IDC_QualityScore(const bool forBuy, const double brkStrengthPts)
  {
   int score = 50;
   long spread = IDC_SpreadPts();
   if(InpMaxSpreadPts > 0)
      score += (int)(15.0 * (1.0 - (double)spread / (double)InpMaxSpreadPts));
   else if(spread < 30)
      score += 10;

   if(IDC_TradeSessionOk()) score += 10;
   if(brkStrengthPts > InpBreakBufferPts * 2) score += 8;

   int h1dir = 0;
   double h1c = iClose(g_sym, PERIOD_H1, 1);
   double h1ma = iMA(g_sym, PERIOD_H1, InpH1_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   if(h1c > h1ma) h1dir = 1; else if(h1c < h1ma) h1dir = -1;
   if((forBuy && h1dir > 0) || (!forBuy && h1dir < 0)) score += 15;

   if(IDC_NewsGuardActive()) score -= 5;

   if(score < 0) score = 0;
   if(score > 100) score = 100;
   return score;
  }

//+------------------------------------------------------------------+
void IDC_LearnOnClose(const double profitMoney, const int qualityAtEntry)
  {
   if(!InpLearningOn) return;
   g_totalLearnTrades++;
   int handle = FileOpen("IDC_M_learn_"+g_sym+".csv", FILE_CSV|FILE_READ|FILE_WRITE|FILE_COMMON);
   if(handle == INVALID_HANDLE)
      handle = FileOpen("IDC_M_learn_"+g_sym+".csv", FILE_CSV|FILE_WRITE|FILE_COMMON);
   if(handle != INVALID_HANDLE)
     {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, TimeToString(TimeCurrent()), profitMoney, qualityAtEntry);
      FileClose(handle);
     }
   if(g_totalLearnTrades % InpLearnEveryNTrades == 0)
     {
      if(profitMoney < 0 && g_adaptThreshold <= 0)
         g_adaptThreshold = InpQualityMinScore + 2;
      else if(profitMoney < 0)
         g_adaptThreshold = MathMin(85, g_adaptThreshold + 1);
      else if(profitMoney > 0 && g_adaptThreshold > 0)
         g_adaptThreshold = MathMax((double)InpQualityFloorScore, g_adaptThreshold - 0.5);
     }
  }

//+------------------------------------------------------------------+
double IDC_NormalizeLots(double lots)
  {
   double minLot = MarketInfo(g_sym, MODE_MINLOT);
   double maxLot = MarketInfo(g_sym, MODE_MAXLOT);
   double step   = MarketInfo(g_sym, MODE_LOTSTEP);
   if(step <= 0) step = 0.01;
   if(minLot <= 0) minLot = 0.01;
   lots = MathFloor(lots / step) * step;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   return NormalizeDouble(lots, 2);
  }

double IDC_CalcLots(const double slDistancePrice)
  {
   if(InpLotsMode == IDC_LOTS_FIXED)
      return IDC_NormalizeLots(InpFixedLots);
   if(slDistancePrice <= 0)
      return IDC_NormalizeLots(InpFixedLots);
   double tickVal  = MarketInfo(g_sym, MODE_TICKVALUE);
   double tickSize = MarketInfo(g_sym, MODE_TICKSIZE);
   if(tickVal <= 0 || tickSize <= 0)
      return IDC_NormalizeLots(InpFixedLots);
   double ticks = slDistancePrice / tickSize;
   double riskMoney = AccountBalance() * InpRiskPercent / 100.0;
   double lots = riskMoney / (ticks * tickVal);
   return IDC_NormalizeLots(lots);
  }

bool IDC_MarginOk(const int cmd, double lots, const double price)
  {
   while(lots >= MarketInfo(g_sym, MODE_MINLOT))
     {
      double chk = AccountFreeMarginCheck(g_sym, cmd, lots, price);
      if(chk > 0)
         return true;
      double step = MarketInfo(g_sym, MODE_LOTSTEP);
      lots -= step;
      lots = IDC_NormalizeLots(lots);
     }
   return false;
  }

//+------------------------------------------------------------------+
double IDC_StopLevelMinDist()
  {
   long st = MarketInfo(g_sym, MODE_STOPLEVEL);
   if(st <= 0) return 0;
   return (double)st * g_point;
  }

double IDC_FixSLBuy(const double entry, double sl)
  {
   double minD = IDC_StopLevelMinDist();
   if(entry - sl < minD) sl = entry - minD;
   return NormalizeDouble(sl, g_digits);
  }

double IDC_FixSLSell(const double entry, double sl)
  {
   double minD = IDC_StopLevelMinDist();
   if(sl - entry < minD) sl = entry + minD;
   return NormalizeDouble(sl, g_digits);
  }

//+------------------------------------------------------------------+
bool IDC_CheckBreakout(const bool wantBuy)
  {
   if(!g_rangeValid) return false;
   int p = IDC_Period();
   double close1 = iClose(g_sym, p, 1);
   double buf = IDC_PtsToPrice(InpBreakBufferPts);
   if(wantBuy)
     {
      if(close1 > g_asiaHigh + buf)
        {
         if(!g_breakUp)
           { g_breakUp = true; g_breakTime = iTime(g_sym, p, 1); g_breakDn = false; }
         return true;
        }
     }
   else
     {
      if(close1 < g_asiaLow - buf)
        {
         if(!g_breakDn)
           { g_breakDn = true; g_breakTime = iTime(g_sym, p, 1); g_breakUp = false; }
         return true;
        }
     }
   return (wantBuy && g_breakUp) || (!wantBuy && g_breakDn);
  }

bool IDC_BreakExpired()
  {
   if(g_breakTime <= 0) return true;
   int sec = InpSignalTF * 60 * InpPullbackMaxBars;
   return (TimeCurrent() - g_breakTime > sec);
  }

bool IDC_CheckPullback(const bool wantBuy)
  {
   if(g_breakTime <= 0) return false;
   if(IDC_BreakExpired())
     {
      g_breakUp = false; g_breakDn = false; g_breakTime = 0;
      return false;
     }
   int p = IDC_Period();
   int shift = 1;
   double ema = iMA(g_sym, p, InpM5_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
   double lo = iLow(g_sym, p, shift);
   double hi = iHigh(g_sym, p, shift);
   double op = iOpen(g_sym, p, shift);
   double cl = iClose(g_sym, p, shift);
   if(wantBuy)
     {
      if(lo > ema + g_point) return false;
      if(cl <= op) return false;
     }
   else
     {
      if(hi < ema - g_point) return false;
      if(cl >= op) return false;
     }
   return true;
  }

bool IDC_H1TrendOk(const bool wantBuy)
  {
   double h1c = iClose(g_sym, PERIOD_H1, 1);
   double h1ma = iMA(g_sym, PERIOD_H1, InpH1_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   return wantBuy ? (h1c > h1ma) : (h1c < h1ma);
  }

double IDC_SwingSL(const bool forBuy)
  {
   int p = IDC_Period();
   double sl = 0;
   int extra = InpSL_BufferPts;
   if(IDC_NewsGuardActive()) extra += InpNewsExtraSLPts;
   double buf = IDC_PtsToPrice(extra);
   if(forBuy)
     {
      sl = iLow(g_sym, p, 1);
      for(int i = 2; i <= InpSwingBars; i++)
         sl = MathMin(sl, iLow(g_sym, p, i));
      sl -= buf;
     }
   else
     {
      sl = iHigh(g_sym, p, 1);
      for(int j = 2; j <= InpSwingBars; j++)
         sl = MathMax(sl, iHigh(g_sym, p, j));
      sl += buf;
     }
   return NormalizeDouble(sl, g_digits);
  }

//+------------------------------------------------------------------+
bool IDC_IsNewSignalBar()
  {
   int p = IDC_Period();
   datetime t0 = iTime(g_sym, p, 0);
   static datetime lastTickBar = 0;
   if(t0 != lastTickBar)
     {
      lastTickBar = t0;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
void IDC_DebugState(const string tag, const bool wantBuy, const int q, const int qNeed)
  {
   if(!InpDebugLog) return;
   PrintFormat("[IDC_M][%s] sym=%s spread=%d range=%d brkUp=%d brkDn=%d Q=%d need=%d wantBuy=%d",
               tag, g_sym, (int)IDC_SpreadPts(), g_rangeValid, g_breakUp, g_breakDn, q, qNeed, wantBuy);
  }

//+------------------------------------------------------------------+
bool IDC_OpenTrade(const bool buy, const int quality)
  {
   int p = IDC_Period();
   datetime bar1 = iTime(g_sym, p, 1);
   if(bar1 == g_lastEntryBarTime) return false;
   if(IDC_CountOpen() > 0) return false;

   string why = "";
   if(!IDC_GuardianAllowEntry(why))
     {
      IDC_DebugState("block_"+why, buy, quality, 0);
      return false;
     }

   double sl = IDC_SwingSL(buy);
   double entry = buy ? MarketInfo(g_sym, MODE_ASK) : MarketInfo(g_sym, MODE_BID);
   if(buy) sl = IDC_FixSLBuy(entry, sl);
   else    sl = IDC_FixSLSell(entry, sl);

   double slDist = MathAbs(entry - sl);
   double lots = IDC_CalcLots(slDist);
   int cmd = buy ? OP_BUY : OP_SELL;
   if(!IDC_MarginOk(cmd, lots, entry))
     {
      lots = IDC_NormalizeLots(MarketInfo(g_sym, MODE_MINLOT));
      if(!IDC_MarginOk(cmd, lots, entry))
        {
         Print("[IDC_M] margin insufficient (134 guard)");
         return false;
        }
     }

   int ticket = OrderSend(g_sym, cmd, lots, entry, InpSlippage, sl, 0,
                          "IDC_M", InpMagic, 0, buy ? clrBlue : clrRed);
   if(ticket < 0)
     {
      Print("[IDC_M] OrderSend err=", GetLastError(), " lots=", lots);
      return false;
     }

   g_lastEntryBarTime = bar1;
   g_tradesToday++;
   GlobalVariableSet("IDC_M_q_"+IntegerToString(ticket), quality);
   PrintFormat("[IDC_M] opened ticket=%d %s lots=%.2f SL=%.5f Q=%d", ticket, buy?"BUY":"SELL", lots, sl, quality);
   return true;
  }

//+------------------------------------------------------------------+
void IDC_ManageTrailing()
  {
   double start = IDC_PtsToPrice(InpTrailStartPts);
   double lock  = IDC_PtsToPrice(InpTrailLockPts);
   double step  = IDC_PtsToPrice(InpTrailStepPts);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagic || OrderSymbol() != g_sym) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      double openP = OrderOpenPrice();
      double sl    = OrderStopLoss();
      double bid   = MarketInfo(g_sym, MODE_BID);
      double ask   = MarketInfo(g_sym, MODE_ASK);

      if(type == OP_BUY)
        {
         double profit = bid - openP;
         if(profit < start) continue;
         double newSL = openP + lock;
         if(sl < newSL - g_point * 0.5)
            newSL = newSL;
         else
           {
            double trailSL = bid - step;
            newSL = MathMax(sl, MathMax(openP + lock, trailSL));
           }
         newSL = IDC_FixSLBuy(openP, newSL);
         if(newSL > sl + g_point * 0.5)
           {
            if(!OrderModify(OrderTicket(), openP, newSL, 0, 0, clrNONE))
               Print("[IDC_M] trail buy modify err ", GetLastError());
           }
        }
      else
        {
         double profit = openP - ask;
         if(profit < start) continue;
         double newSL = openP - lock;
         if(sl > newSL + g_point * 0.5)
            newSL = newSL;
         else
           {
            double trailSL = ask + step;
            newSL = MathMin(sl, MathMin(openP - lock, trailSL));
           }
         newSL = IDC_FixSLSell(openP, newSL);
         if(newSL < sl - g_point * 0.5 || sl == 0)
           {
            if(!OrderModify(OrderTicket(), openP, newSL, 0, 0, clrNONE))
               Print("[IDC_M] trail sell modify err ", GetLastError());
           }
        }
     }
  }

//+------------------------------------------------------------------+
void IDC_CheckClosedTrades()
  {
   static int known = -1;
   int hist = OrdersHistoryTotal();
   if(known < 0) { known = hist; return; }
   for(int i = known; i < hist; i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderMagicNumber() != InpMagic || OrderSymbol() != g_sym) continue;
      int ticket = OrderTicket();
      double q = 0;
      if(GlobalVariableCheck("IDC_M_q_"+IntegerToString(ticket)))
         q = GlobalVariableGet("IDC_M_q_"+IntegerToString(ticket));
      IDC_LearnOnClose(OrderProfit() + OrderSwap() + OrderCommission(), (int)q);
      GlobalVariableDel("IDC_M_q_"+IntegerToString(ticket));
     }
   known = hist;
  }

//+------------------------------------------------------------------+
void IDC_OnSignalBar()
  {
   IDC_CalcAsiaRange();
   if(IDC_CountOpen() > 0) return;

   int qNeed = IDC_DynamicQualityThreshold();

   bool tryBuy  = g_rangeValid && IDC_H1TrendOk(true)  && IDC_CheckBreakout(true)  && IDC_CheckPullback(true);
   bool trySell = g_rangeValid && IDC_H1TrendOk(false) && IDC_CheckBreakout(false) && IDC_CheckPullback(false);

   if(tryBuy)
     {
      double close1 = iClose(g_sym, IDC_Period(), 1);
      double brk = (close1 - g_asiaHigh) / g_point;
      int q = IDC_QualityScore(true, brk);
      IDC_DebugState("eval_buy", true, q, qNeed);
      if(q >= qNeed) IDC_OpenTrade(true, q);
     }
   if(trySell)
     {
      double close1 = iClose(g_sym, IDC_Period(), 1);
      double brk = (g_asiaLow - close1) / g_point;
      int q = IDC_QualityScore(false, brk);
      IDC_DebugState("eval_sell", false, q, qNeed);
      if(q >= qNeed) IDC_OpenTrade(false, q);
     }
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!IDC_EnsureSymbol())
     {
      Print("[IDC_M] invalid symbol");
      return INIT_FAILED;
     }
   g_initBalance = AccountBalance();
   g_adaptThreshold = InpQualityMinScore;
   IDC_ResetDayStats();
   PrintFormat("[IDC_M] init sym=%s point=%.10f digits=%d server=%s (교육용 포맷 v1.0)",
               g_sym, g_point, g_digits, TimeToString(TimeCurrent()));
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("[IDC_M] deinit reason=", reason);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(!IDC_EnsureSymbol()) return;
   IDC_ResetDayStats();
   IDC_CheckClosedTrades();
   IDC_ManageTrailing();

   if(InpDebugLog && !IDC_IsNewSignalBar())
     {
      // 틱마다 경량 상태 (새 바에서 상세 eval)
      static datetime lastDbg = 0;
      if(TimeCurrent() - lastDbg >= 5)
        {
         lastDbg = TimeCurrent();
         IDC_DebugState("tick", false, 0, IDC_DynamicQualityThreshold());
        }
     }

   if(IDC_IsNewSignalBar())
      IDC_OnSignalBar();
  }
//+------------------------------------------------------------------+