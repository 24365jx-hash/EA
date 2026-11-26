#property copyright "IDC_F v2.0"
#property version   "2.00"
#property strict
#property description "IDC_F 안2 REG+PULL. spec: docs/IDC_F_CONSTITUTION.txt"

enum ENUM_LOT_MODE
{
   LOT_MANUAL  = 0,
   LOT_PERCENT = 1
};

input int    InpMagic              = 261126;       // 매직넘버 (IDC_F)
input ENUM_LOT_MODE InpLotMode     = LOT_PERCENT;  // 0수동랏 1잔고%
input double InpFixedLot           = 0.01;         // 수동 랏
input double InpRiskPercent        = 0.30;         // 자동 랏 위험 %
input double InpRiskMaxPercent     = 0.40;         // 자동 랏 한 거래 상한 %
input int    InpSlippagePoints     = 50;           // 슬리피지 포인트
input int    InpSignalTF           = 5;            // 신호 주기(분) M5=5
input int    InpTrendTF            = 60;           // 추세 주기(분) H1=60
input int    InpEmaPeriod          = 50;           // H1 EMA 기간
input int    InpH1SlopeBars        = 3;            // H1 EMA 기울기 봉 수
input int    InpAtrPeriod          = 14;           // ATR 기간
input double InpReclaimAtr         = 0.40;         // 복귀 바 범위 / M5 ATR
input int    InpSweepMaxBars       = 6;            // 스윕 확인 봉 수
input int    InpAsiaStartHour      = 0;            // 아시아 시작 GMT 시
input int    InpAsiaEndHour        = 6;            // 아시아 끝 GMT 시
input int    InpSessionStartHour   = 16;           // 거래 시작 시 (한국시간)
input int    InpSessionStartMin    = 0;            // 거래 시작 분
input int    InpSessionEndHour     = 0;            // 거래 끝 시 (한국시간)
input int    InpSessionEndMin      = 30;           // 거래 끝 분
input bool   InpCloseAtSessionEnd  = true;         // 세션 종료 시 청산
input int    InpMinHoldSeconds     = 90;           // 이익 청산 최소 보유 초
input double InpDailyLossPercent   = 2.0;          // 일일 손실 % (초기잔고)
input double InpSoftMaxLossPercent = 7.0;          // 소프트 최대손실 % (초기잔고)
input double InpInitialBalance     = 0;            // 초기잔고 0=첫 잔고, FTMO는 100000
input bool   InpUseBlockHours      = true;         // 서버 차단시간 사용
input int    InpBlockServerStart   = 0;            // 서버 차단 시작 시
input int    InpBlockServerEnd     = 2;            // 서버 차단 끝 시
input bool   InpFridayStop         = true;         // 금요일 신규 마감 사용
input int    InpFridayStopHour     = 23;           // 금요일 신규 마감 시 (한국시간)
input int    InpTargetPerDay       = 2;            // 하루 목표 진입 수
input int    InpWarmup             = 40;           // 학습 시작 전 청산 횟수
input double InpBaselineR          = 0.35;         // 가중치 기준 R
input double InpLearnRate          = 0.06;         // 학습 속도
input int    InpScoreCutStart      = 30;           // 점수 커트 시작 백분위 0~80
input double InpTrailTight         = 0.80;         // 좁은 트레일 시작 배수
input double InpTrailWide          = 1.30;         // 넓은 트레일 시작 배수
input int    InpStandOffPoints     = 0;            // 트레일 이격 0=스텝과 동일
input int    InpBrokerSyncMult     = 5;            // 브로커 손절 동기화 스텝 배수
input int    InpMaxModifies        = 800;          // 하루 손절 수정 상한
input int    InpMaxTickGap         = 30;           // 틱 공백 초
input double InpSpreadMedianMult   = 2.5;          // 스프레드 / 중앙값 상한
input double InpSpreadVsSl         = 0.25;         // 스프레드 / 손절거리 상한
input bool   InpDebugLog           = false;        // 진입 디버그 O/X (매 신호봉)
input bool   InpUseGold            = true;         // 마켓워치 골드 추가
input bool   InpUseIndex           = true;         // 마켓워치 지수 추가
input bool   InpUseFX              = true;         // 마켓워치 FX (안2 EURUSD)
input bool   InpUseCrypto          = false;        // 마켓워치 크립토 추가
input int    InpSweepMinPoints     = 0;            // 스윕 최소 0=등급 자동
input int    InpSlBufferPoints     = 0;            // 손절 버퍼 0=등급 자동
input int    InpSlMinPoints        = 0;            // 손절 최소 0=등급 자동
input int    InpSlMaxPoints        = 0;            // 손절 최대 0=등급 자동
input int    InpTrailStartPoints   = 0;            // 트레일 시작 0=등급 자동
input int    InpTrailStepPoints    = 0;            // 트레일 스텝 0=등급 자동
input int    InpSpreadCapPoints    = 0;            // 스프레드 상한 0=등급 자동
input int    InpReclaimMinPoints   = 0;            // 복귀 최소 0=등급 자동
input int    InpChasePoints        = 0;            // 추격 한도 0=등급 자동
input int    InpStructureTF        = 15;           // PULL 구조 TF (분) M15=15
input int    InpMaxTradesDay       = 3;            // 일 체결 상한 (안2)
input double InpPullRiskPercent    = 0.24;         // PULL 랏 위험 % (REG는 InpRiskPercent)
input double InpRegDevAtr          = 0.45;         // REG VWAP 이탈 / M5 ATR
input double InpH1ChopAtr          = 0.35;         // H1 EMA 기울기 / H1 ATR 횡보
input double InpImpulseAtr         = 0.85;         // PULL M15 임펄스 / M15 ATR
input double InpStabStdR           = 1.15;         // STAB_GATE 최근 R 표준편차
input double InpDayPullStopR       = -1.2;          // 당일 누적 R 이하 PULL 중단
input bool   InpPlan2Whitelist     = true;         // 안2 종목 화이트리스트
input int    InpVwapBars           = 96;           // REG VWAP 누적 M5 봉 (세션 근사)

#define MAXS    12
#define PAT_REG 1
#define PAT_PULL 2
#define REC_R   20
#define MAXOPEN 32
#define MAXSCORE 60
#define MAXSIG  4

string   SName[MAXS];
datetime gBarOf[MAXS];
int      SSpread[MAXS][32];
int      SSpreadN[MAXS];
int      SSpreadPos[MAXS];
int      gN = 0;

double   gW[4] = {1.0, 1.0, 1.0, 1.0};
int      gClosed = 0;
double   gPR[3];
int      gPN[3];
int      gPercentile = 30;
double   gScore[MAXSCORE];
int      gScoreN = 0;
int      gEntrySeq = 0;

int      gOpenTicket[MAXOPEN];
double   gOpenFeat[MAXOPEN][4];
int      gOpenPreset[MAXOPEN];
double   gOpenRisk[MAXOPEN];
double   gOpenExtreme[MAXOPEN];
int      gOpenN = 0;

int      gDayKey = 0;
int      gTradesToday = 0;
bool     gHaveDay = false;
double   gDayStartBal = 0.0;
double   gInitBal = 0.0;
int      gBrokerOff = 0;
bool     gOffReady = false;
bool     gGmtWarned = false;
int      gModifiesToday = 0;
bool     gSelfOK = false;
datetime gLastSymRefresh = 0;
bool     gHistWarned = false;
bool     gDayLocked = false;
datetime gLastOpenSave = 0;
string   gOxLine[8];
int      gOxN = 0;
string   gGateLine = "";
string   gBlock = "";
bool     gOxSent = false;
double   gRecentR[REC_R];
int      gRecentRn = 0;
int      gLossStreak = 0;
bool     gStabGate = false;
double   gDayR = 0.0;
int      gPullToday = 0;

int LockPoints(int start, int step, int stand, int profitPts)
{
   int n;
   int lock;
   if(step < 1) step = 1;
   if(stand < 1) stand = step;
   if(profitPts < start) return(-1);
   n = (profitPts - start) / step;
   lock = start + n * step - stand;
   if(lock < 0) lock = 0;
   return(lock);
}

bool InWindow(int nowMin, int startMin, int endMin)
{
   if(startMin == endMin) return(true);
   if(startMin < endMin) return(nowMin >= startMin && nowMin < endMin);
   return(nowMin >= startMin || nowMin < endMin);
}

double FloorStep(double lot, double step)
{
   double n;
   double v;
   if(step <= 0.0) return(lot);
   if(lot <= 0.0) return(0.0);
   n = MathFloor(lot / step + 1e-6);
   v = n * step;
   if(v > lot + 1e-7) v = (n - 1.0) * step;
   if(v < 0.0) v = 0.0;
   return(v);
}

bool SelfTest()
{
   double floored;
   if(LockPoints(200, 10, 10, 190) != -1) { Print("IDC_F self-test lock 190"); return(false); }
   if(LockPoints(200, 10, 10, 200) != 190) { Print("IDC_F self-test lock 200"); return(false); }
   if(LockPoints(200, 10, 10, 210) != 200) { Print("IDC_F self-test lock 210"); return(false); }
   if(LockPoints(200, 10, 10, 219) != 200) { Print("IDC_F self-test lock 219"); return(false); }
   if(LockPoints(200, 10, 10, 220) != 210) { Print("IDC_F self-test lock 220"); return(false); }
   if(LockPoints(200, 10, 0, 200) != 190)  { Print("IDC_F self-test stand 0"); return(false); }
   if(!InWindow(18 * 60, 16 * 60, 30)) { Print("IDC_F self-test 18:00"); return(false); }
   if(!InWindow(10, 16 * 60, 30))      { Print("IDC_F self-test 00:10"); return(false); }
   if(!InWindow(16 * 60, 16 * 60, 30)) { Print("IDC_F self-test 16:00"); return(false); }
   if(!InWindow(29, 16 * 60, 30))      { Print("IDC_F self-test 00:29"); return(false); }
   if(InWindow(30, 16 * 60, 30))       { Print("IDC_F self-test 00:30"); return(false); }
   if(InWindow(12 * 60, 16 * 60, 30))  { Print("IDC_F self-test 12:00"); return(false); }
   floored = FloorStep(0.037, 0.01);
   if(MathAbs(floored - 0.03) > 1e-8) { Print("IDC_F self-test lot 0.037"); return(false); }
   floored = FloorStep(0.03, 0.01);
   if(MathAbs(floored - 0.03) > 1e-8) { Print("IDC_F self-test lot 0.03"); return(false); }
   floored = FloorStep(0.009, 0.01);
   if(floored > 1e-8) { Print("IDC_F self-test lot below step"); return(false); }
   return(true);
}

string Upper(string s)
{
   string t = s;
   StringToUpper(t);
   return(t);
}

bool EndsWith(string s, string suf)
{
   int n = StringLen(s);
   int m = StringLen(suf);
   if(m <= 0 || n < m) return(false);
   return(StringSubstr(s, n - m, m) == suf);
}

string BaseName(string sym)
{
   string t;
   string u;
   string suf[5];
   int i;
   int c;
   int guard;
   bool cut;
   t = Upper(sym);
   u = "";
   for(i = 0; i < StringLen(t); i++)
   {
      c = (int)StringGetChar(t, i);
      if((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) u = u + ShortToString((ushort)c);
   }
   suf[0] = "MICRO";
   suf[1] = "CASH";
   suf[2] = "PRO";
   suf[3] = "RAW";
   suf[4] = "ECN";
   cut = true;
   guard = 0;
   while(cut && guard < 6)
   {
      guard++;
      cut = false;
      for(i = 0; i < 5; i++)
      {
         if(EndsWith(u, suf[i]) && StringLen(u) > StringLen(suf[i]))
         {
            u = StringSubstr(u, 0, StringLen(u) - StringLen(suf[i]));
            cut = true;
            break;
         }
      }
      if(!cut && EndsWith(u, "M") && StringLen(u) - 1 >= 6)
      {
         u = StringSubstr(u, 0, StringLen(u) - 1);
         cut = true;
      }
   }
   return(u);
}

int ClassOf(string sym)
{
   string b = BaseName(sym);
   if(StringFind(b, "XAU") == 0 || b == "GOLD" || StringFind(b, "XAG") == 0 || b == "SILVER") return(1);
   if(b == "US100" || b == "NAS100" || b == "USTEC" || b == "ND100" || b == "NASDAQ" ||
      b == "US30"  || b == "DJ30"   || b == "WS30"  || b == "US500" || b == "SPX500" ||
      b == "DE40"  || b == "GER40"  || b == "DE30"  || b == "GER30") return(2);
   if(StringFind(b, "BTC") == 0 || StringFind(b, "ETH") == 0) return(3);
   if(StringLen(b) == 6) return(4);
   return(0);
}

bool ClassWanted(int cls)
{
   if(cls == 1) return(InpUseGold);
   if(cls == 2) return(InpUseIndex);
   if(cls == 3) return(InpUseCrypto);
   if(cls == 4) return(InpUseFX);
   return(false);
}

bool IsPullIndex(string sym)
{
   string b = BaseName(sym);
   if(b == "US100" || b == "NAS100" || b == "USTEC" || b == "ND100" || b == "NASDAQ") return(true);
   return(false);
}

bool IsRegFx(string sym)
{
   return(BaseName(sym) == "EURUSD");
}

bool IsRegGold(string sym)
{
   int c = ClassOf(sym);
   return(c == 1);
}

int PatternOf(string sym)
{
   if(InpPlan2Whitelist)
   {
      if(IsPullIndex(sym)) return(PAT_PULL);
      if(IsRegFx(sym) || IsRegGold(sym)) return(PAT_REG);
      return(0);
   }
   if(IsPullIndex(sym)) return(PAT_PULL);
   if(ClassOf(sym) == 4 || ClassOf(sym) == 1) return(PAT_REG);
   return(0);
}

bool AllowedPlan2(string sym)
{
   int p;
   if(sym == "" || sym == NULL) return(false);
   p = PatternOf(sym);
   if(p == 0) return(false);
   if(p == PAT_PULL) return(InpUseIndex);
   if(IsRegFx(sym)) return(InpUseFX);
   if(IsRegGold(sym)) return(InpUseGold);
   return(false);
}

bool PullAllowedNow()
{
   if(gStabGate) return(false);
   if(gDayR <= InpDayPullStopR + 1e-8) return(false);
   if(gPullToday >= 1) return(false);
   return(true);
}

void PushRecentR(double R)
{
   int i;
   if(gRecentRn < REC_R)
   {
      gRecentR[gRecentRn] = R;
      gRecentRn++;
   }
   else
   {
      for(i = 0; i < REC_R - 1; i++) gRecentR[i] = gRecentR[i + 1];
      gRecentR[REC_R - 1] = R;
   }
   if(R < 0.0) gLossStreak++;
   else gLossStreak = 0;
}

void RecomputeStabGate()
{
   int n;
   int i;
   double mean;
   double var;
   double sd;
   n = gRecentRn;
   if(n < 8)
   {
      gStabGate = (gLossStreak >= 3);
      return;
   }
   mean = 0.0;
   for(i = 0; i < n; i++) mean += gRecentR[i];
   mean /= n;
   var = 0.0;
   for(i = 0; i < n; i++)
   {
      double d = gRecentR[i] - mean;
      var += d * d;
   }
   var /= n;
   sd = MathSqrt(var);
   gStabGate = (sd > InpStabStdR) || (gLossStreak >= 3);
}

bool OverridesComplete()
{
   if(InpSweepMinPoints <= 0) return(false);
   if(InpSlBufferPoints <= 0) return(false);
   if(InpSlMinPoints <= 0) return(false);
   if(InpSlMaxPoints <= 0) return(false);
   if(InpTrailStartPoints <= 0) return(false);
   if(InpTrailStepPoints <= 0) return(false);
   if(InpSpreadCapPoints <= 0) return(false);
   if(InpReclaimMinPoints <= 0) return(false);
   if(InpChasePoints <= 0) return(false);
   return(true);
}

int Scale10(int v)
{
   int r = (int)MathRound(v / 10.0);
   if(r < 1) r = 1;
   return(r);
}

void ApplyScale10(int &sweep, int &buf, int &slmin, int &slmax, int &trStart, int &trStep, int &spreadCap, int &reclaim, int &chase)
{
   sweep = Scale10(sweep);
   buf = Scale10(buf);
   slmin = Scale10(slmin);
   slmax = Scale10(slmax);
   trStart = Scale10(trStart);
   trStep = Scale10(trStep);
   spreadCap = Scale10(spreadCap);
   reclaim = Scale10(reclaim);
   chase = Scale10(chase);
}

void EffPoints(string sym, int &sweep, int &buf, int &slmin, int &slmax, int &trStart, int &trStep, int &spreadCap, int &reclaim, int &chase)
{
   int cls;
   double pt;
   string base;
   bool jpy;
   cls = ClassOf(sym);
   pt = MarketInfo(sym, MODE_POINT);
   base = BaseName(sym);
   jpy = (StringFind(base, "JPY") >= 0);
   sweep = 30; buf = 20; slmin = 80; slmax = 600; trStart = 200; trStep = 10; spreadCap = 25; reclaim = 15; chase = 30;
   if(cls == 1)
   {
      if(pt > 0.0 && pt < 0.005)
      {
         sweep = 500; buf = 300; slmin = 1500; slmax = 12000; trStart = 3000; trStep = 200; spreadCap = 450; reclaim = 250; chase = 500;
      }
      else
      {
         sweep = 50; buf = 30; slmin = 150; slmax = 1200; trStart = 300; trStep = 20; spreadCap = 45; reclaim = 25; chase = 50;
      }
   }
   else if(cls == 2)
   {
      if(pt >= 0.5)
      {
         sweep = 8; buf = 5; slmin = 15; slmax = 180; trStart = 30; trStep = 2; spreadCap = 8; reclaim = 4; chase = 8;
      }
      else if(pt >= 0.05)
      {
         sweep = 80; buf = 50; slmin = 150; slmax = 1800; trStart = 300; trStep = 20; spreadCap = 80; reclaim = 40; chase = 80;
      }
      else
      {
         sweep = 80; buf = 50; slmin = 200; slmax = 2500; trStart = 400; trStep = 20; spreadCap = 100; reclaim = 40; chase = 80;
      }
   }
   else if(cls == 3)
   {
      sweep = 150; buf = 200; slmin = 400; slmax = 8000; trStart = 800; trStep = 50; spreadCap = 400; reclaim = 75; chase = 150;
   }
   else if(cls == 4)
   {
      if(jpy)
      {
         if(pt >= 0.005) ApplyScale10(sweep, buf, slmin, slmax, trStart, trStep, spreadCap, reclaim, chase);
      }
      else if(pt >= 0.00005)
      {
         ApplyScale10(sweep, buf, slmin, slmax, trStart, trStep, spreadCap, reclaim, chase);
      }
   }
   if(InpSweepMinPoints > 0) sweep = InpSweepMinPoints;
   if(InpSlBufferPoints > 0) buf = InpSlBufferPoints;
   if(InpSlMinPoints > 0) slmin = InpSlMinPoints;
   if(InpSlMaxPoints > 0) slmax = InpSlMaxPoints;
   if(InpTrailStartPoints > 0) trStart = InpTrailStartPoints;
   if(InpTrailStepPoints > 0) trStep = InpTrailStepPoints;
   if(InpSpreadCapPoints > 0) spreadCap = InpSpreadCapPoints;
   if(InpReclaimMinPoints > 0) reclaim = InpReclaimMinPoints;
   if(InpChasePoints > 0) chase = InpChasePoints;
   if(trStep < 1) trStep = 1;
   if(trStart < trStep) trStart = trStep;
   if(slmax < slmin) slmax = slmin;
}

void DLog(string sym, string msg)
{
   if(!InpDebugLog) return;
   Print("IDC_F chartTF=", IntegerToString(Period()), " signalTF=", IntegerToString(InpSignalTF), " ", sym, " ", msg);
}

void OxLine(string s)
{
   if(!InpDebugLog) return;
   if(gOxN >= 8) return;
   gOxLine[gOxN] = s;
   gOxN++;
}

string Yn(bool v)
{
   if(v) return("O");
   return("X");
}

string StepMark(int reached, int at)
{
   if(reached > at) return("O");
   if(reached == at) return("X");
   return("-");
}

string LevelOx(string name, int reached)
{
   return(name
      + " 스윕" + StepMark(reached, 0)
      + " 복귀" + StepMark(reached, 1)
      + " 첫복귀" + StepMark(reached, 2)
      + " H1" + StepMark(reached, 3)
      + " 품질" + StepMark(reached, 4)
      + " 추격" + StepMark(reached, 5)
      + " 손절" + StepMark(reached, 6)
      + " 스프레드상한" + StepMark(reached, 7)
      + " 손절대비" + StepMark(reached, 8)
      + " 후보" + StepMark(reached, 9));
}

void FlushOx(string sym, string verdict)
{
   int i;
   datetime closed;
   if(!InpDebugLog || gOxSent) return;
   gOxSent = true;
   closed = iTime(sym, InpSignalTF, 1);
   Print("IDC_F ", sym, " ", TfNote(), " closed=", TimeToString(closed, TIME_DATE | TIME_MINUTES));
   Print(gGateLine);
   for(i = 0; i < gOxN; i++) Print(gOxLine[i]);
   Print("=> ", verdict);
}

string TfNote()
{
   return("chart=" + IntegerToString(Period()) + " signal=" + IntegerToString(InpSignalTF));
}

datetime GmtNow()
{
   int raw = (int)(TimeCurrent() - TimeGMT());
   if(MathAbs(raw) > 48 * 3600) return(TimeCurrent() - gBrokerOff);
   return(TimeGMT());
}

datetime KstNow()
{
   return(GmtNow() + 9 * 3600);
}

void RefreshOffset()
{
   int raw;
   int mag;
   int sign;
   int step;
   int rounded;
   raw = (int)(TimeCurrent() - TimeGMT());
   if(MathAbs(raw) > 48 * 3600)
   {
      if(!gGmtWarned)
      {
         Print("IDC_F TimeGMT is not the server clock. Asia and KST follow server time.");
         gGmtWarned = true;
      }
      return;
   }
   if(gOffReady && MathAbs(raw - gBrokerOff) <= 15 * 60) return;
   step = 1800;
   sign = 1;
   mag = raw;
   if(mag < 0) { sign = -1; mag = -mag; }
   rounded = ((mag + step / 2) / step) * step;
   gBrokerOff = sign * rounded;
   gOffReady = true;
}

int ClockMin(int hour, int minute)
{
   int h = hour;
   int m = minute;
   if(h < 0) h = 0;
   if(h > 23) h = 23;
   if(m < 0) m = 0;
   if(m > 59) m = 59;
   return(h * 60 + m);
}

bool SessionClock()
{
   datetime k = KstNow();
   int nowM = TimeHour(k) * 60 + TimeMinute(k);
   int a = ClockMin(InpSessionStartHour, InpSessionStartMin);
   int b = ClockMin(InpSessionEndHour, InpSessionEndMin);
   return(InWindow(nowM, a, b));
}

bool InSession()
{
   datetime k = KstNow();
   int dow = TimeDayOfWeek(k);
   if(dow == 0 || dow == 6) return(false);
   if(InpFridayStop && dow == 5 && TimeHour(k) >= InpFridayStopHour) return(false);
   return(SessionClock());
}

bool FlattenDue()
{
   datetime k = KstNow();
   int dow = TimeDayOfWeek(k);
   if(dow == 0 || dow == 6) return(true);
   if(InpCloseAtSessionEnd && !SessionClock()) return(true);
   return(false);
}

bool AsiaBlocked()
{
   int sh = InpAsiaStartHour;
   int eh = InpAsiaEndHour;
   int h;
   if(sh < 0) sh = 0;
   if(eh > 24) eh = 24;
   if(eh <= sh) return(false);
   h = TimeHour(GmtNow());
   return(h >= sh && h < eh);
}

bool BlockHour()
{
   int h;
   if(!InpUseBlockHours) return(false);
   h = TimeHour(TimeCurrent());
   if(InpBlockServerStart == InpBlockServerEnd) return(false);
   if(InpBlockServerStart < InpBlockServerEnd) return(h >= InpBlockServerStart && h < InpBlockServerEnd);
   return(h >= InpBlockServerStart || h < InpBlockServerEnd);
}

int KeyOf(datetime t)
{
   return(TimeYear(t) * 10000 + TimeMonth(t) * 100 + TimeDay(t));
}

int DayKey()
{
   return(KeyOf(TimeCurrent()));
}

int WarmCount()
{
   if(InpWarmup < 0) return(0);
   return(InpWarmup);
}

bool RiskAllowsEntry()
{
   double eq;
   double dayFloor;
   double maxFloor;
   if(gInitBal <= 0.0) return(false);
   if(gDayLocked) return(false);
   eq = AccountEquity();
   dayFloor = gDayStartBal - gInitBal * InpDailyLossPercent / 100.0;
   maxFloor = gInitBal * (1.0 - InpSoftMaxLossPercent / 100.0);
   if(eq <= dayFloor)
   {
      gDayLocked = true;
      SaveLearn();
      return(false);
   }
   if(eq <= maxFloor) return(false);
   return(true);
}

int FindSym(string sym)
{
   int i;
   for(i = 0; i < gN; i++) if(SName[i] == sym) return(i);
   return(-1);
}

void EnsureSymbol(string sym)
{
   if(sym == "" || sym == NULL) return;
   if(FindSym(sym) >= 0) return;
   if(gN >= MAXS) return;
   if(MarketInfo(sym, MODE_POINT) <= 0.0) return;
   SName[gN] = sym;
   gBarOf[gN] = 0;
   SSpreadN[gN] = 0;
   SSpreadPos[gN] = 0;
   gN++;
}

void RefreshSymbols()
{
   int total;
   int i;
   string s;
   EnsureSymbol(Symbol());
   if(IsTesting()) return;
   if(TimeCurrent() - gLastSymRefresh < 30) return;
   gLastSymRefresh = TimeCurrent();
   total = SymbolsTotal(true);
   for(i = 0; i < total; i++)
   {
      s = SymbolName(i, true);
      if(InpPlan2Whitelist)
      {
         if(AllowedPlan2(s)) EnsureSymbol(s);
      }
      else if(ClassWanted(ClassOf(s))) EnsureSymbol(s);
   }
}

void PushSpread(int slot, int spread)
{
   if(slot < 0 || slot >= gN) return;
   if(spread < 0) return;
   SSpread[slot][SSpreadPos[slot]] = spread;
   SSpreadPos[slot] = (SSpreadPos[slot] + 1) % 32;
   if(SSpreadN[slot] < 32) SSpreadN[slot]++;
}

int MedianSpread(int slot)
{
   int tmp[32];
   int n;
   int i;
   int j;
   int start;
   int z;
   if(slot < 0 || SSpreadN[slot] <= 0) return(0);
   n = SSpreadN[slot];
   start = (n < 32) ? 0 : SSpreadPos[slot];
   for(i = 0; i < n; i++) tmp[i] = SSpread[slot][(start + i) % 32];
   for(i = 0; i < n; i++)
   {
      for(j = i + 1; j < n; j++)
      {
         if(tmp[j] < tmp[i])
         {
            z = tmp[i];
            tmp[i] = tmp[j];
            tmp[j] = z;
         }
      }
   }
   return(tmp[n / 2]);
}

bool H1Ok(string sym, int dir)
{
   int emaP;
   int slope;
   int shiftBack;
   double ema;
   double emaPrev;
   double cl;
   emaP = InpEmaPeriod;
   if(emaP < 1) emaP = 1;
   slope = InpH1SlopeBars;
   if(slope < 1) slope = 1;
   shiftBack = 1 + slope;
   ema = iMA(sym, InpTrendTF, emaP, 0, MODE_EMA, PRICE_CLOSE, 1);
   emaPrev = iMA(sym, InpTrendTF, emaP, 0, MODE_EMA, PRICE_CLOSE, shiftBack);
   cl = iClose(sym, InpTrendTF, 1);
   if(ema == 0.0 || cl == 0.0) return(false);
   if(dir > 0) return(cl > ema && ema >= emaPrev);
   return(cl < ema && ema <= emaPrev);
}

bool H1TrendOnly(string sym, int dir)
{
   int emaP;
   double ema;
   double cl;
   emaP = InpEmaPeriod;
   if(emaP < 1) emaP = 1;
   ema = iMA(sym, InpTrendTF, emaP, 0, MODE_EMA, PRICE_CLOSE, 1);
   cl = iClose(sym, InpTrendTF, 1);
   if(ema == 0.0 || cl == 0.0) return(false);
   if(dir > 0) return(cl > ema);
   return(cl < ema);
}

bool H1Chop(string sym)
{
   int emaP;
   int slope;
   int shiftBack;
   double ema;
   double emaPrev;
   double h1atr;
   emaP = InpEmaPeriod;
   if(emaP < 1) emaP = 1;
   slope = InpH1SlopeBars;
   if(slope < 1) slope = 1;
   shiftBack = 1 + slope;
   ema = iMA(sym, InpTrendTF, emaP, 0, MODE_EMA, PRICE_CLOSE, 1);
   emaPrev = iMA(sym, InpTrendTF, emaP, 0, MODE_EMA, PRICE_CLOSE, shiftBack);
   h1atr = iATR(sym, InpTrendTF, InpAtrPeriod, 1);
   if(ema == 0.0 || emaPrev == 0.0 || h1atr <= 0.0) return(false);
   return(MathAbs(ema - emaPrev) <= InpH1ChopAtr * h1atr);
}

datetime SessionStartKst()
{
   datetime kn;
   int nowMin;
   int a;
   int b;
   int daySec;
   datetime day0;
   kn = KstNow();
   nowMin = TimeHour(kn) * 60 + TimeMinute(kn);
   a = ClockMin(InpSessionStartHour, InpSessionStartMin);
   b = ClockMin(InpSessionEndHour, InpSessionEndMin);
   daySec = TimeHour(kn) * 3600 + TimeMinute(kn) * 60 + TimeSeconds(kn);
   day0 = kn - daySec;
   if(nowMin >= a) return(day0 + a * 60);
   if(InWindow(nowMin, 0, b)) return(day0 - 86400 + a * 60);
   return(day0 + a * 60);
}

datetime SessionStartServer()
{
   return(TimeCurrent() - (KstNow() - SessionStartKst()));
}

bool SessionVWAP(string sym, double &vwap)
{
   int i;
   int bars;
   int cap;
   int counted;
   datetime srvStart;
   datetime bt;
   double sumPV;
   double sumV;
   double h;
   double l;
   double c;
   double vol;
   double tp;
   vwap = 0.0;
   bars = iBars(sym, InpSignalTF);
   if(bars < 3) return(false);
   srvStart = SessionStartServer();
   cap = InpVwapBars;
   if(cap < 10) cap = 10;
   sumPV = 0.0;
   sumV = 0.0;
   counted = 0;
   for(i = 1; i < bars && counted < cap; i++)
   {
      bt = iTime(sym, InpSignalTF, i);
      if(bt < srvStart) break;
      h = iHigh(sym, InpSignalTF, i);
      l = iLow(sym, InpSignalTF, i);
      c = iClose(sym, InpSignalTF, i);
      if(h <= 0.0 || l <= 0.0 || c <= 0.0) continue;
      vol = (double)iVolume(sym, InpSignalTF, i);
      if(vol <= 0.0) vol = 1.0;
      tp = (h + l + c) / 3.0;
      sumPV += tp * vol;
      sumV += vol;
      counted++;
   }
   if(sumV <= 0.0) return(false);
   vwap = sumPV / sumV;
   return(true);
}

string RegOx(int reached)
{
   return("REG 이탈" + StepMark(reached, 0)
      + " 복귀" + StepMark(reached, 1)
      + " H1횡보" + StepMark(reached, 2)
      + " 품질" + StepMark(reached, 3)
      + " 추격" + StepMark(reached, 4)
      + " 손절" + StepMark(reached, 5)
      + " 스프레드" + StepMark(reached, 6)
      + " 후보" + StepMark(reached, 7));
}

string PullOx(int reached)
{
   return("PULL 임펄스" + StepMark(reached, 0)
      + " H1추세" + StepMark(reached, 1)
      + " 눌림" + StepMark(reached, 2)
      + " 품질" + StepMark(reached, 3)
      + " 추격" + StepMark(reached, 4)
      + " 손절" + StepMark(reached, 5)
      + " 스프레드" + StepMark(reached, 6)
      + " 후보" + StepMark(reached, 7));
}

double Clamp01(double x)
{
   if(x < 0.0) return(0.0);
   if(x > 1.0) return(1.0);
   return(x);
}

double ScoreOf(double &f[])
{
   double sw = gW[0] + gW[1] + gW[2] + gW[3];
   if(sw <= 0.0) return(0.0);
   return((gW[0] * f[0] + gW[1] * f[1] + gW[2] * f[2] + gW[3] * f[3]) / sw);
}

void PushScore(double s)
{
   int i;
   if(gScoreN < MAXSCORE)
   {
      gScore[gScoreN] = s;
      gScoreN++;
      return;
   }
   for(i = 0; i < MAXSCORE - 1; i++) gScore[i] = gScore[i + 1];
   gScore[MAXSCORE - 1] = s;
}

double ScoreThreshold()
{
   double tmp[MAXSCORE];
   int n;
   int i;
   int j;
   int idx;
   double z;
   if(gClosed < WarmCount()) return(-1.0);
   if(gPercentile <= 0 || gScoreN < 10) return(-1.0);
   n = gScoreN;
   for(i = 0; i < n; i++) tmp[i] = gScore[i];
   for(i = 0; i < n; i++)
   {
      for(j = i + 1; j < n; j++)
      {
         if(tmp[j] < tmp[i])
         {
            z = tmp[i];
            tmp[i] = tmp[j];
            tmp[j] = z;
         }
      }
   }
   idx = (int)MathFloor((gPercentile / 100.0) * n);
   if(idx < 0) idx = 0;
   if(idx >= n) idx = n - 1;
   return(tmp[idx]);
}

bool GateScore(double score)
{
   double th;
   if(gClosed < WarmCount()) return(true);
   th = ScoreThreshold();
   if(th < 0.0) return(true);
   if(score + 1e-12 < th) return(false);
   return(true);
}

bool AsiaWindow(double &hi, double &lo, string sym)
{
   int sh;
   int eh;
   int bars;
   int limit;
   int i;
   datetime nowG;
   datetime dayStart;
   datetime endT;
   datetime startT;
   datetime bt;
   datetime gmt;
   bool found;
   double h;
   double l;
   double bh;
   double bl;
   hi = 0.0;
   lo = 0.0;
   sh = InpAsiaStartHour;
   eh = InpAsiaEndHour;
   if(sh < 0) sh = 0;
   if(eh > 24) eh = 24;
   if(eh <= sh) return(false);
   nowG = GmtNow();
   dayStart = nowG - (nowG % 86400);
   endT = dayStart + eh * 3600;
   if(nowG < endT) endT -= 86400;
   startT = endT - (eh - sh) * 3600;
   bars = iBars(sym, InpSignalTF);
   if(bars < 20) return(false);
   limit = bars - 1;
   if(limit > 400) limit = 400;
   found = false;
   h = 0.0;
   l = 0.0;
   for(i = 1; i <= limit; i++)
   {
      bt = iTime(sym, InpSignalTF, i);
      if(bt <= 0) continue;
      gmt = bt - gBrokerOff;
      if(gmt >= endT) continue;
      if(gmt < startT) break;
      bh = iHigh(sym, InpSignalTF, i);
      bl = iLow(sym, InpSignalTF, i);
      if(bh <= 0.0 || bl <= 0.0) continue;
      if(!found) { h = bh; l = bl; found = true; }
      else
      {
         if(bh > h) h = bh;
         if(bl < l) l = bl;
      }
   }
   if(!found || h <= l) return(false);
   hi = h;
   lo = l;
   return(true);
}

bool SlAccept(string sym, int dir, double entryPx, double sl, int slmin, int slmax)
{
   double point;
   double bid;
   double ask;
   int riskPts;
   int need;
   int freeze;
   int brokerPts;
   double mkt;
   point = MarketInfo(sym, MODE_POINT);
   if(point <= 0.0 || entryPx <= 0.0 || sl <= 0.0) return(false);
   bid = MarketInfo(sym, MODE_BID);
   ask = MarketInfo(sym, MODE_ASK);
   if(bid <= 0.0 || ask <= 0.0) return(false);
   if(dir > 0)
   {
      if(!(sl < entryPx && sl < bid)) return(false);
   }
   else
   {
      if(!(sl > entryPx && sl > ask)) return(false);
   }
   riskPts = (int)MathRound(MathAbs(entryPx - sl) / point);
   if(riskPts < slmin || riskPts > slmax) return(false);
   need = (int)MarketInfo(sym, MODE_STOPLEVEL);
   freeze = (int)MarketInfo(sym, MODE_FREEZELEVEL);
   if(need < 0) need = 0;
   if(freeze > need) need = freeze;
   mkt = (dir > 0) ? bid : ask;
   brokerPts = (int)MathFloor(MathAbs(mkt - sl) / point + 1e-6);
   if(brokerPts < need) return(false);
   return(true);
}

int SweepBars()
{
   int maxB = InpSweepMaxBars;
   if(maxB < 1) maxB = 1;
   if(maxB > 500) maxB = 500;
   return(maxB);
}

int CollectReg(string sym,
               int &dir[], double &level[], double &extreme[], double &sl[],
               double &score[], double &depth[], double &clsPx[], double &feat[][4], string &tag[])
{
   int d;
   int sweep;
   int buf;
   int slmin;
   int slmax;
   int trS;
   int trStep;
   int spCap;
   int reclaimMin;
   int chase;
   int spr;
   int digits;
   int riskPts;
   int reached;
   int emaP;
   double point;
   double vwap;
   double closePx;
   double hi1;
   double lo1;
   double atr;
   double range;
   double dev;
   double px;
   double slp;
   double ext;
   double depPts;
   double reclaimPts;
   double h1atr;
   double h1bw;
   double ff[4];
   bool quality;
   reached = -1;
   emaP = InpEmaPeriod;
   if(emaP < 1) emaP = 1;
   point = MarketInfo(sym, MODE_POINT);
   if(point <= 0.0) return(0);
   if(iBars(sym, InpSignalTF) < 10) return(0);
   EffPoints(sym, sweep, buf, slmin, slmax, trS, trStep, spCap, reclaimMin, chase);
   if(!SessionVWAP(sym, vwap)) { OxLine(RegOx(0)); return(0); }
   closePx = iClose(sym, InpSignalTF, 1);
   hi1 = iHigh(sym, InpSignalTF, 1);
   lo1 = iLow(sym, InpSignalTF, 1);
   if(closePx <= 0.0 || hi1 <= 0.0 || lo1 <= 0.0) { OxLine(RegOx(0)); return(0); }
   atr = iATR(sym, InpSignalTF, InpAtrPeriod, 1);
   if(atr <= 0.0) { OxLine(RegOx(0)); return(0); }
   dev = InpRegDevAtr * atr;
   d = 0;
   if(lo1 < vwap - dev && closePx > vwap) d = 1;
   else if(hi1 > vwap + dev && closePx < vwap) d = -1;
   if(d == 0) { OxLine(RegOx(0)); return(0); }
   reached = 0;
   reached = 1;
   if(!H1Chop(sym)) { OxLine(RegOx(2)); return(0); }
   reached = 2;
   range = hi1 - lo1;
   if(range < 0.0) range = 0.0;
   reclaimPts = (d > 0) ? (closePx - vwap) / point : (vwap - closePx) / point;
   quality = (range >= InpReclaimAtr * atr) || (reclaimPts >= reclaimMin);
   if(!quality) { OxLine(RegOx(3)); return(0); }
   reached = 3;
   px = (d > 0) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   if(px <= 0.0) { OxLine(RegOx(4)); return(0); }
   if(d > 0 && px > closePx + chase * point) { OxLine(RegOx(4)); return(0); }
   if(d < 0 && px < closePx - chase * point) { OxLine(RegOx(4)); return(0); }
   reached = 4;
   ext = (d > 0) ? lo1 : hi1;
   slp = (d > 0) ? ext - buf * point : ext + buf * point;
   digits = (int)MarketInfo(sym, MODE_DIGITS);
   slp = NormalizeDouble(slp, digits);
   if(!SlAccept(sym, d, px, slp, slmin, slmax)) { OxLine(RegOx(5)); return(0); }
   reached = 5;
   spr = (int)MarketInfo(sym, MODE_SPREAD);
   if(spCap > 0 && spr > spCap) { OxLine(RegOx(6)); return(0); }
   if(InpSpreadVsSl > 0.0)
   {
      riskPts = (int)MathRound(MathAbs(px - slp) / point);
      if(riskPts > 0 && spr > riskPts * InpSpreadVsSl) { OxLine(RegOx(6)); return(0); }
   }
   reached = 7;
   depPts = (d > 0) ? (vwap - ext) / point : (ext - vwap) / point;
   h1atr = iATR(sym, InpTrendTF, InpAtrPeriod, 1);
   h1bw = h1atr;
   ff[0] = Clamp01(depPts / (sweep * 3.0));
   ff[1] = Clamp01(reclaimPts / (sweep * 2.0));
   ff[2] = (spCap > 0) ? Clamp01(1.0 - (double)spr / (double)spCap) : 1.0;
   ff[3] = 0.0;
   if(h1atr > 0.0) ff[3] = Clamp01(h1bw / h1atr);
   dir[0] = d;
   level[0] = vwap;
   extreme[0] = ext;
   sl[0] = slp;
   depth[0] = depPts;
   clsPx[0] = closePx;
   feat[0][0] = ff[0];
   feat[0][1] = ff[1];
   feat[0][2] = ff[2];
   feat[0][3] = ff[3];
   score[0] = ScoreOf(ff);
   tag[0] = "REG";
   OxLine(RegOx(reached));
   return(1);
}

int CollectPull(string sym,
                int &dir[], double &level[], double &extreme[], double &sl[],
                double &score[], double &depth[], double &clsPx[], double &feat[][4], string &tag[])
{
   int d;
   int b;
   int sh;
   int sweep;
   int buf;
   int slmin;
   int slmax;
   int trS;
   int trStep;
   int spCap;
   int reclaimMin;
   int chase;
   int spr;
   int digits;
   int riskPts;
   int reached;
   double point;
   double m15atr;
   double m15o;
   double m15h;
   double m15l;
   double m15c;
   double m15body;
   double m15range;
   double pullLvl;
   double closePx;
   double lo1;
   double hi1;
   double atr;
   double range;
   double px;
   double slp;
   double ext;
   double depPts;
   double h1atr;
   double ff[4];
   bool impulse;
   bool touch;
   reached = -1;
   point = MarketInfo(sym, MODE_POINT);
   if(point <= 0.0) return(0);
   if(iBars(sym, InpStructureTF) < 5 || iBars(sym, InpSignalTF) < 5) return(0);
   EffPoints(sym, sweep, buf, slmin, slmax, trS, trStep, spCap, reclaimMin, chase);
   d = 0;
   impulse = false;
   pullLvl = 0.0;
   for(sh = 2; sh <= 6; sh++)
   {
      m15o = iOpen(sym, InpStructureTF, sh);
      m15h = iHigh(sym, InpStructureTF, sh);
      m15l = iLow(sym, InpStructureTF, sh);
      m15c = iClose(sym, InpStructureTF, sh);
      m15atr = iATR(sym, InpStructureTF, InpAtrPeriod, sh);
      if(m15o <= 0.0 || m15c <= 0.0 || m15atr <= 0.0) continue;
      m15body = MathAbs(m15c - m15o);
      m15range = m15h - m15l;
      if(m15range < 0.0) m15range = 0.0;
      if(m15range < InpImpulseAtr * m15atr) continue;
      if(m15c > m15o)
      {
         d = 1;
         pullLvl = m15o;
         impulse = true;
         break;
      }
      if(m15c < m15o)
      {
         d = -1;
         pullLvl = m15o;
         impulse = true;
         break;
      }
   }
   if(!impulse) { OxLine(PullOx(0)); return(0); }
   reached = 0;
   if(!H1TrendOnly(sym, d)) { OxLine(PullOx(1)); return(0); }
   reached = 1;
   closePx = iClose(sym, InpSignalTF, 1);
   lo1 = iLow(sym, InpSignalTF, 1);
   hi1 = iHigh(sym, InpSignalTF, 1);
   if(closePx <= 0.0) { OxLine(PullOx(2)); return(0); }
   touch = false;
   if(d > 0 && lo1 <= pullLvl + 3.0 * point && closePx >= pullLvl) touch = true;
   if(d < 0 && hi1 >= pullLvl - 3.0 * point && closePx <= pullLvl) touch = true;
   if(!touch) { OxLine(PullOx(2)); return(0); }
   reached = 2;
   atr = iATR(sym, InpSignalTF, InpAtrPeriod, 1);
   range = hi1 - lo1;
   if(range < 0.0) range = 0.0;
   if(atr > 0.0 && range < 0.25 * atr) { OxLine(PullOx(3)); return(0); }
   reached = 3;
   px = (d > 0) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   if(px <= 0.0) { OxLine(PullOx(4)); return(0); }
   if(d > 0 && px > closePx + chase * point) { OxLine(PullOx(4)); return(0); }
   if(d < 0 && px < closePx - chase * point) { OxLine(PullOx(4)); return(0); }
   reached = 4;
   ext = (d > 0) ? lo1 : hi1;
   slp = (d > 0) ? ext - buf * point : ext + buf * point;
   digits = (int)MarketInfo(sym, MODE_DIGITS);
   slp = NormalizeDouble(slp, digits);
   if(!SlAccept(sym, d, px, slp, slmin, slmax)) { OxLine(PullOx(5)); return(0); }
   reached = 5;
   spr = (int)MarketInfo(sym, MODE_SPREAD);
   if(spCap > 0 && spr > spCap) { OxLine(PullOx(6)); return(0); }
   if(InpSpreadVsSl > 0.0)
   {
      riskPts = (int)MathRound(MathAbs(px - slp) / point);
      if(riskPts > 0 && spr > riskPts * InpSpreadVsSl) { OxLine(PullOx(6)); return(0); }
   }
   reached = 7;
   depPts = MathAbs(closePx - pullLvl) / point;
   h1atr = iATR(sym, InpTrendTF, InpAtrPeriod, 1);
   ff[0] = Clamp01(m15body / (m15atr + 1e-8));
   ff[1] = Clamp01(depPts / (sweep * 2.0));
   ff[2] = (spCap > 0) ? Clamp01(1.0 - (double)spr / (double)spCap) : 1.0;
   ff[3] = 0.0;
   if(h1atr > 0.0) ff[3] = Clamp01(depPts / h1atr * point);
   dir[0] = d;
   level[0] = pullLvl;
   extreme[0] = ext;
   sl[0] = slp;
   depth[0] = depPts;
   clsPx[0] = closePx;
   feat[0][0] = ff[0];
   feat[0][1] = ff[1];
   feat[0][2] = ff[2];
   feat[0][3] = ff[3];
   score[0] = ScoreOf(ff);
   tag[0] = "PULL";
   OxLine(PullOx(reached));
   return(1);
}

int CollectSignals(string sym,
                   int &dir[], double &level[], double &extreme[], double &sl[],
                   double &score[], double &depth[], double &clsPx[], double &feat[][4], string &tag[])
{
   int pat;
   pat = PatternOf(sym);
   if(pat == PAT_REG) return(CollectReg(sym, dir, level, extreme, sl, score, depth, clsPx, feat, tag));
   if(pat == PAT_PULL)
   {
      if(!PullAllowedNow())
      {
         OxLine("PULL STAB_GATE X");
         return(0);
      }
      return(CollectPull(sym, dir, level, extreme, sl, score, depth, clsPx, feat, tag));
   }
   OxLine("종목패턴 X");
   return(0);
}

int LotDigits(double step)
{
   int d = 0;
   double x = step;
   while(d < 8 && MathAbs(x - MathRound(x)) > 1e-7)
   {
      x *= 10.0;
      d++;
   }
   return(d);
}

double MoneyPerPoint(string sym)
{
   double tickVal = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize = MarketInfo(sym, MODE_TICKSIZE);
   double point = MarketInfo(sym, MODE_POINT);
   if(tickSize <= 0.0 || point <= 0.0 || tickVal <= 0.0) return(0.0);
   return(tickVal * point / tickSize);
}

bool FitLot(string sym, int cmd, double want, double &outLot)
{
   double minl;
   double maxl;
   double step;
   double lot;
   int dg;
   int guard;
   minl = MarketInfo(sym, MODE_MINLOT);
   maxl = MarketInfo(sym, MODE_MAXLOT);
   step = MarketInfo(sym, MODE_LOTSTEP);
   if(minl <= 0.0) minl = 0.01;
   if(step <= 0.0) step = 0.01;
   if(maxl < minl) maxl = minl;
   dg = LotDigits(step);
   lot = NormalizeDouble(FloorStep(want, step), dg);
   if(lot > maxl) lot = NormalizeDouble(FloorStep(maxl, step), dg);
   if(lot + 1e-8 < minl)
   {
      DLog(sym, "lot below min, skip");
      return(false);
   }
   guard = 0;
   while(lot + 1e-8 >= minl && AccountFreeMarginCheck(sym, cmd, lot) < 0.0 && guard < 100)
   {
      guard++;
      lot = NormalizeDouble(FloorStep(lot - step, step), dg);
   }
   if(lot + 1e-8 < minl) return(false);
   if(AccountFreeMarginCheck(sym, cmd, lot) < 0.0)
   {
      DLog(sym, "margin fail");
      return(false);
   }
   outLot = lot;
   return(true);
}

bool HasOurPosition(string sym)
{
   int i;
   for(i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagic) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderSymbol() == sym) return(true);
   }
   return(false);
}

bool QuoteFresh(string sym)
{
   datetime qt;
   qt = (datetime)MarketInfo(sym, MODE_TIME);
   if(qt <= 0) return(false);
   if(InpMaxTickGap > 0 && (TimeCurrent() - qt) > InpMaxTickGap) return(false);
   return(true);
}

bool SpreadOkMedian(int slot, string sym)
{
   int spr;
   int med;
   spr = (int)MarketInfo(sym, MODE_SPREAD);
   med = MedianSpread(slot);
   PushSpread(slot, spr);
   if(med > 0 && InpSpreadMedianMult > 0.0 && spr > med * InpSpreadMedianMult) return(false);
   return(true);
}

bool MarkBar(string sym, int slot)
{
   datetime bar;
   int need;
   bar = iTime(sym, InpSignalTF, 0);
   if(bar <= 0) return(false);
   if(bar == gBarOf[slot]) return(false);
   need = SweepBars() + 5;
   if(need < 30) need = 30;
   if(iBars(sym, InpSignalTF) < need) return(false);
   gBarOf[slot] = bar;
   return(true);
}

bool CanEnter(string sym, int slot)
{
   bool tradeOk;
   bool autoOk;
   bool known;
   bool fresh;
   bool medOk;
   bool sess;
   bool asiaOk;
   bool hourOk;
   bool riskOk;
   bool flat;
   tradeOk = (MarketInfo(sym, MODE_TRADEALLOWED) > 0.0);
   autoOk = (IsTesting() || IsTradeAllowed());
   known = (PatternOf(sym) != 0 || OverridesComplete());
   fresh = QuoteFresh(sym);
   medOk = SpreadOkMedian(slot, sym);
   sess = InSession();
   asiaOk = !AsiaBlocked();
   hourOk = !BlockHour();
   riskOk = RiskAllowsEntry();
   flat = !HasOurPosition(sym);
   gGateLine = "세션" + Yn(sess)
      + " STAB" + Yn(!gStabGate)
      + " 아시아외" + Yn(asiaOk)
      + " 서버시간" + Yn(hourOk)
      + " 손실한도" + Yn(riskOk)
      + " 포지션없음" + Yn(flat)
      + " 시세" + Yn(fresh)
      + " 중앙스프레드" + Yn(medOk)
      + " 종목거래" + Yn(tradeOk)
      + " 자동매매" + Yn(autoOk)
      + " 심볼등급" + Yn(known);
   gBlock = "";
   if(!tradeOk) gBlock = "종목거래";
   else if(!autoOk) gBlock = "자동매매";
   else if(!known) gBlock = "심볼등급";
   else if(!fresh) gBlock = "시세";
   else if(!medOk) gBlock = "중앙스프레드";
   else if(!sess) gBlock = "세션";
   else if(!asiaOk) gBlock = "아시아외";
   else if(!hourOk) gBlock = "서버시간";
   else if(!riskOk) gBlock = "손실한도";
   else if(!flat) gBlock = "포지션없음";
   return(gBlock == "");
}

int PickPreset()
{
   int i;
   int least;
   int best;
   double bestA;
   double a;
   bool ready;
   bool any;
   if(gClosed < WarmCount()) return(1);
   ready = true;
   for(i = 0; i < 3; i++) if(gPN[i] < 5) ready = false;
   if(!ready) return(gEntrySeq % 3);
   if(gEntrySeq > 0 && (gEntrySeq % 20) == 0)
   {
      least = 0;
      for(i = 1; i < 3; i++) if(gPN[i] < gPN[least]) least = i;
      return(least);
   }
   best = 1;
   bestA = -1e9;
   any = false;
   for(i = 0; i < 3; i++)
   {
      if(gPN[i] <= 0) continue;
      a = gPR[i] / gPN[i];
      if(!any || a > bestA) { bestA = a; best = i; any = true; }
   }
   if(!any) return(1);
   return(best);
}

double PresetFactor(int preset)
{
   if(preset == 0) return(InpTrailTight);
   if(preset == 2) return(InpTrailWide);
   return(1.0);
}

int SendMarket(string sym, int dir, double lot, double sl, double closePx, int chase, int slmin, int slmax)
{
   int cmd;
   int digits;
   int attempt;
   int ticket;
   int e;
   double point;
   double price;
   cmd = (dir > 0) ? OP_BUY : OP_SELL;
   point = MarketInfo(sym, MODE_POINT);
   digits = (int)MarketInfo(sym, MODE_DIGITS);
   sl = NormalizeDouble(sl, digits);
   for(attempt = 0; attempt < 3; attempt++)
   {
      RefreshRates();
      price = (cmd == OP_BUY) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
      price = NormalizeDouble(price, digits);
      if(point > 0.0)
      {
         if(dir > 0 && price > closePx + chase * point) { DLog(sym, "chase at send"); return(-1); }
         if(dir < 0 && price < closePx - chase * point) { DLog(sym, "chase at send"); return(-1); }
      }
      if(!SlAccept(sym, dir, price, sl, slmin, slmax)) { DLog(sym, "sl moved"); return(-1); }
      if(AccountFreeMarginCheck(sym, cmd, lot) < 0.0) { DLog(sym, "margin at send"); return(-1); }
      ticket = OrderSend(sym, cmd, lot, price, InpSlippagePoints, sl, 0, "IDC_F", InpMagic, 0,
                         (cmd == OP_BUY) ? clrBlue : clrRed);
      if(ticket > 0)
      {
         if(OrderSelect(ticket, SELECT_BY_TICKET) && OrderStopLoss() == 0.0)
         {
            if(!OrderModify(ticket, OrderOpenPrice(), sl, 0, 0, clrNONE))
            {
               Print("IDC_F naked stop, closing ", IntegerToString(ticket), " err=", IntegerToString(GetLastError()));
               price = (cmd == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
               OrderClose(ticket, lot, NormalizeDouble(price, digits), InpSlippagePoints, clrYellow);
               return(-1);
            }
         }
         return(ticket);
      }
      e = GetLastError();
      Print("IDC_F OrderSend fail sym=", sym, " err=", IntegerToString(e), " lot=", DoubleToString(lot, 4));
      if(e == 146 || e == 128 || e == 129 || e == 135 || e == 136 || e == 138)
      {
         Sleep(200);
         continue;
      }
      return(-1);
   }
   return(-1);
}

int FindOpen(int ticket)
{
   int i;
   for(i = 0; i < gOpenN; i++) if(gOpenTicket[i] == ticket) return(i);
   return(-1);
}

void RemoveOpenAt(int idx)
{
   int i;
   if(idx < 0 || idx >= gOpenN) return;
   for(i = idx; i < gOpenN - 1; i++)
   {
      gOpenTicket[i] = gOpenTicket[i + 1];
      gOpenPreset[i] = gOpenPreset[i + 1];
      gOpenRisk[i] = gOpenRisk[i + 1];
      gOpenExtreme[i] = gOpenExtreme[i + 1];
      gOpenFeat[i][0] = gOpenFeat[i + 1][0];
      gOpenFeat[i][1] = gOpenFeat[i + 1][1];
      gOpenFeat[i][2] = gOpenFeat[i + 1][2];
      gOpenFeat[i][3] = gOpenFeat[i + 1][3];
   }
   gOpenN--;
}

string StripCr(string line)
{
   int n = StringLen(line);
   if(n > 0 && StringGetChar(line, n - 1) == '\r') return(StringSubstr(line, 0, n - 1));
   return(line);
}

int SplitComma(string line, string &out[])
{
   int n;
   int i;
   string cur;
   string ch;
   ArrayResize(out, 128);
   n = 0;
   cur = "";
   for(i = 0; i < StringLen(line); i++)
   {
      ch = StringSubstr(line, i, 1);
      if(ch == ",")
      {
         if(n < 128) { out[n] = cur; n++; }
         cur = "";
      }
      else cur = cur + ch;
   }
   if(n < 128) { out[n] = cur; n++; }
   return(n);
}

void SaveLearn()
{
   int h;
   int i;
   string line;
   h = FileOpen("IDC_F_learn.txt", FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   line = "v2," + IntegerToString(gClosed) + "," +
          DoubleToString(gW[0], 6) + "," + DoubleToString(gW[1], 6) + "," +
          DoubleToString(gW[2], 6) + "," + DoubleToString(gW[3], 6) + "," +
          DoubleToString(gPR[0], 4) + "," + IntegerToString(gPN[0]) + "," +
          DoubleToString(gPR[1], 4) + "," + IntegerToString(gPN[1]) + "," +
          DoubleToString(gPR[2], 4) + "," + IntegerToString(gPN[2]) + "," +
          IntegerToString(gPercentile) + "," + DoubleToString(gInitBal, 2) + "," +
          IntegerToString(gDayKey) + "," + IntegerToString(gTradesToday) + "," +
          IntegerToString(gModifiesToday) + "," + IntegerToString(gEntrySeq) + "," +
          IntegerToString(gDayLocked ? 1 : 0) + "," + DoubleToString(gDayStartBal, 2) + "," +
          IntegerToString(gScoreN);
   for(i = 0; i < gScoreN; i++)
      line = line + "," + DoubleToString(gScore[i], 6);
   FileWriteString(h, line + "\n");
   FileClose(h);
}

void SaveOpen()
{
   int h;
   int i;
   string line;
   h = FileOpen("IDC_F_open.txt", FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   for(i = 0; i < gOpenN; i++)
   {
      line = IntegerToString(gOpenTicket[i]) + "," +
             DoubleToString(gOpenFeat[i][0], 4) + "," + DoubleToString(gOpenFeat[i][1], 4) + "," +
             DoubleToString(gOpenFeat[i][2], 4) + "," + DoubleToString(gOpenFeat[i][3], 4) + "," +
             IntegerToString(gOpenPreset[i]) + "," + DoubleToString(gOpenRisk[i], 4) + "," +
             DoubleToString(gOpenExtreme[i], 10);
      FileWriteString(h, line + "\n");
   }
   FileClose(h);
}

bool AddOpen(int ticket, double &f[], int preset, double risk, double extreme)
{
   int i;
   if(ticket <= 0 || gOpenN >= MAXOPEN) return(false);
   if(FindOpen(ticket) >= 0) return(true);
   i = gOpenN;
   gOpenTicket[i] = ticket;
   gOpenFeat[i][0] = f[0];
   gOpenFeat[i][1] = f[1];
   gOpenFeat[i][2] = f[2];
   gOpenFeat[i][3] = f[3];
   if(preset < 0 || preset > 2) preset = 1;
   gOpenPreset[i] = preset;
   gOpenRisk[i] = risk;
   gOpenExtreme[i] = extreme;
   gOpenN++;
   SaveOpen();
   return(true);
}

void ClampWeights()
{
   int k;
   for(k = 0; k < 4; k++)
   {
      if(gW[k] < 0.05) gW[k] = 0.05;
      if(gW[k] > 2.5) gW[k] = 2.5;
   }
}

void ClampPercentile()
{
   if(gPercentile < 0) gPercentile = 0;
   if(gPercentile > 80) gPercentile = 80;
}

void LoadLearn()
{
   int h;
   int n;
   int i;
   int sn;
   double ib;
   string line;
   string p[];
   gW[0] = 1.0; gW[1] = 1.0; gW[2] = 1.0; gW[3] = 1.0;
   gClosed = 0;
   gPR[0] = 0.0; gPR[1] = 0.0; gPR[2] = 0.0;
   gPN[0] = 0; gPN[1] = 0; gPN[2] = 0;
   gPercentile = InpScoreCutStart;
   ClampPercentile();
   gEntrySeq = 0;
   gDayLocked = false;
   gScoreN = 0;
   gDayStartBal = 0.0;
   h = FileOpen("IDC_F_learn.txt", FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   if(!FileIsEnding(h))
   {
      line = StripCr(FileReadString(h));
      n = SplitComma(line, p);
      if(n >= 18 && (p[0] == "v1" || p[0] == "v2"))
      {
         gClosed = (int)StringToInteger(p[1]);
         gW[0] = StringToDouble(p[2]);
         gW[1] = StringToDouble(p[3]);
         gW[2] = StringToDouble(p[4]);
         gW[3] = StringToDouble(p[5]);
         gPR[0] = StringToDouble(p[6]);  gPN[0] = (int)StringToInteger(p[7]);
         gPR[1] = StringToDouble(p[8]);  gPN[1] = (int)StringToInteger(p[9]);
         gPR[2] = StringToDouble(p[10]); gPN[2] = (int)StringToInteger(p[11]);
         gPercentile = (int)StringToInteger(p[12]);
         if(InpInitialBalance <= 0.0)
         {
            ib = StringToDouble(p[13]);
            if(ib > 0.0) gInitBal = ib;
         }
         gDayKey = (int)StringToInteger(p[14]);
         gTradesToday = (int)StringToInteger(p[15]);
         gModifiesToday = (int)StringToInteger(p[16]);
         gEntrySeq = (int)StringToInteger(p[17]);
         if(n >= 19 && StringToInteger(p[18]) != 0) gDayLocked = true;
         if(p[0] == "v2" && n >= 20)
         {
            gDayStartBal = StringToDouble(p[19]);
            if(gDayStartBal < 0.0) gDayStartBal = 0.0;
         }
         if(p[0] == "v2" && n >= 21)
         {
            sn = (int)StringToInteger(p[20]);
            if(sn < 0) sn = 0;
            if(sn > MAXSCORE) sn = MAXSCORE;
            gScoreN = 0;
            for(i = 0; i < sn; i++)
            {
               if(21 + i >= n) break;
               gScore[gScoreN] = StringToDouble(p[21 + i]);
               gScoreN++;
            }
         }
      }
   }
   FileClose(h);
   ClampWeights();
   ClampPercentile();
   if(gEntrySeq < 0) gEntrySeq = 0;
   if(gTradesToday < 0) gTradesToday = 0;
   if(gModifiesToday < 0) gModifiesToday = 0;
}

void LoadOpen()
{
   int h;
   int n;
   string line;
   string p[];
   gOpenN = 0;
   h = FileOpen("IDC_F_open.txt", FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h) && gOpenN < MAXOPEN)
   {
      line = StripCr(FileReadString(h));
      if(StringLen(line) < 3) continue;
      n = SplitComma(line, p);
      if(n < 8) continue;
      gOpenTicket[gOpenN] = (int)StringToInteger(p[0]);
      gOpenFeat[gOpenN][0] = StringToDouble(p[1]);
      gOpenFeat[gOpenN][1] = StringToDouble(p[2]);
      gOpenFeat[gOpenN][2] = StringToDouble(p[3]);
      gOpenFeat[gOpenN][3] = StringToDouble(p[4]);
      gOpenPreset[gOpenN] = (int)StringToInteger(p[5]);
      gOpenRisk[gOpenN] = StringToDouble(p[6]);
      gOpenExtreme[gOpenN] = StringToDouble(p[7]);
      if(gOpenTicket[gOpenN] > 0) gOpenN++;
   }
   FileClose(h);
}

void OnClosedTrade(int idx, double profitMoney)
{
   double risk;
   double R;
   double lr;
   int preset;
   int k;
   if(idx < 0 || idx >= gOpenN) return;
   risk = gOpenRisk[idx];
   R = 0.0;
   if(risk > 1e-8) R = profitMoney / risk;
   preset = gOpenPreset[idx];
   if(preset < 0 || preset > 2) preset = 1;
   lr = InpLearnRate;
   if(lr < 0.0) lr = 0.0;
   lr = lr / (1.0 + gClosed / 120.0);
   for(k = 0; k < 4; k++)
   {
      gW[k] += lr * (R - InpBaselineR) * gOpenFeat[idx][k];
   }
   ClampWeights();
   gPR[preset] += R;
   gPN[preset] += 1;
   gClosed++;
   gDayR += R;
   PushRecentR(R);
   RecomputeStabGate();
   RemoveOpenAt(idx);
   SaveLearn();
   SaveOpen();
   Print("IDC_F learn close R=", DoubleToString(R, 2), " n=", IntegerToString(gClosed), " STAB=", (gStabGate ? "ON" : "OFF"));
}

void RecoverClosed()
{
   int i;
   int ticket;
   double profit;
   i = 0;
   while(i < gOpenN)
   {
      ticket = gOpenTicket[i];
      if(!OrderSelect(ticket, SELECT_BY_TICKET))
      {
         i++;
         continue;
      }
      if(OrderCloseTime() == 0)
      {
         i++;
         continue;
      }
      if(OrderMagicNumber() != InpMagic)
      {
         RemoveOpenAt(i);
         SaveOpen();
         continue;
      }
      profit = OrderProfit() + OrderSwap() + OrderCommission();
      OnClosedTrade(i, profit);
   }
}

void AdoptOrphans()
{
   int i;
   int ticket;
   int digits;
   double f[4];
   double point;
   double mpp;
   double risk;
   double ext;
   string sym;
   f[0] = 0.0; f[1] = 0.0; f[2] = 0.0; f[3] = 0.0;
   for(i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagic) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      ticket = OrderTicket();
      if(FindOpen(ticket) >= 0) continue;
      sym = OrderSymbol();
      point = MarketInfo(sym, MODE_POINT);
      mpp = MoneyPerPoint(sym);
      risk = 0.0;
      if(point > 0.0 && OrderStopLoss() > 0.0 && mpp > 0.0)
         risk = MathAbs(OrderOpenPrice() - OrderStopLoss()) / point * mpp * OrderLots();
      if(OrderType() == OP_BUY) ext = MarketInfo(sym, MODE_BID);
      else ext = MarketInfo(sym, MODE_ASK);
      digits = (int)MarketInfo(sym, MODE_DIGITS);
      ext = NormalizeDouble(ext, digits);
      if(AddOpen(ticket, f, 1, risk, ext))
         Print("IDC_F adopt ", IntegerToString(ticket), " ", sym);
   }
}

int CountEntriesOnDay(int key)
{
   int c;
   int i;
   int total;
   int stop;
   c = 0;
   for(i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagic) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(KeyOf(OrderOpenTime()) == key) c++;
   }
   total = OrdersHistoryTotal();
   stop = total - 2000;
   if(stop < 0) stop = 0;
   for(i = total - 1; i >= stop; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderMagicNumber() != InpMagic) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(KeyOf(OrderOpenTime()) == key) c++;
   }
   return(c);
}

void ApplyPercentile(int entries)
{
   if(gClosed < WarmCount()) return;
   if(entries > InpTargetPerDay + 1) gPercentile += 5;
   else if(entries < InpTargetPerDay - 1) gPercentile -= 5;
   ClampPercentile();
}

void RollDay()
{
   int k = DayKey();
   if(!gHaveDay)
   {
      gDayKey = k;
      gHaveDay = true;
      if(gDayStartBal <= 0.0) gDayStartBal = AccountBalance();
      return;
   }
   if(k == gDayKey) return;
   ApplyPercentile(gTradesToday);
   gDayKey = k;
   gDayStartBal = AccountBalance();
   gTradesToday = 0;
   gPullToday = 0;
   gDayR = 0.0;
   gModifiesToday = 0;
   gDayLocked = false;
   RecomputeStabGate();
   SaveLearn();
}

bool TryEntry(string sym, int slot)
{
   int dir[MAXSIG];
   double level[MAXSIG];
   double extreme[MAXSIG];
   double sl[MAXSIG];
   double score[MAXSIG];
   double depth[MAXSIG];
   double clsPx[MAXSIG];
   double feat[MAXSIG][4];
   string tag[MAXSIG];
   double ff[4];
   int n;
   int pick;
   int s;
   int preset;
   int sweep;
   int buf;
   int slmin;
   int slmax;
   int trS;
   int trStep;
   int spCap;
   int reclaimMin;
   int chase;
   int cmd;
   int dist;
   int ticket;
   double px;
   double point;
   double mpp;
   double riskPct;
   double tilt;
   double want;
   double riskMoney;
   double lot;
   double realRisk;
   double openPx;
   bool known;
   bool gates;
   if(!gSelfOK) return(false);
   if(!MarkBar(sym, slot)) return(false);
   gOxN = 0;
   gOxSent = false;
   gGateLine = "";
   gBlock = "";
   known = (PatternOf(sym) != 0 || OverridesComplete());
   if(gTradesToday >= InpMaxTradesDay)
   {
      if(InpDebugLog) FlushOx(sym, "진입X 일상한");
      return(false);
   }
   n = 0;
   if(!InpDebugLog)
   {
      if(!CanEnter(sym, slot)) return(false);
      n = CollectSignals(sym, dir, level, extreme, sl, score, depth, clsPx, feat, tag);
      if(n <= 0) return(false);
   }
   else
   {
      if(known) n = CollectSignals(sym, dir, level, extreme, sl, score, depth, clsPx, feat, tag);
      gates = CanEnter(sym, slot);
      if(!gates)
      {
         FlushOx(sym, "진입X " + gBlock);
         return(false);
      }
      if(n <= 0)
      {
         FlushOx(sym, "진입X 신호없음");
         return(false);
      }
   }
   pick = 0;
   if(gClosed < WarmCount())
   {
      for(s = 1; s < n; s++) if(depth[s] > depth[pick]) pick = s;
   }
   else
   {
      for(s = 1; s < n; s++) if(score[s] > score[pick]) pick = s;
   }
   if(!GateScore(score[pick]))
   {
      FlushOx(sym, "진입X 점수 " + DoubleToString(score[pick], 2));
      for(s = 0; s < n; s++) PushScore(score[s]);
      SaveLearn();
      return(false);
   }
   for(s = 0; s < n; s++) PushScore(score[s]);
   ff[0] = feat[pick][0];
   ff[1] = feat[pick][1];
   ff[2] = feat[pick][2];
   ff[3] = feat[pick][3];
   preset = PickPreset();
   EffPoints(sym, sweep, buf, slmin, slmax, trS, trStep, spCap, reclaimMin, chase);
   cmd = (dir[pick] > 0) ? OP_BUY : OP_SELL;
   px = (cmd == OP_BUY) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   point = MarketInfo(sym, MODE_POINT);
   mpp = MoneyPerPoint(sym);
   if(mpp <= 0.0 || point <= 0.0 || px <= 0.0) { FlushOx(sym, "진입X 시세가치"); return(false); }
   dist = (int)MathRound(MathAbs(px - sl[pick]) / point);
   if(dist <= 0) { FlushOx(sym, "진입X 손절거리"); return(false); }
   riskPct = InpRiskPercent;
   if(tag[pick] == "PULL") riskPct = InpPullRiskPercent;
   else if(gClosed >= WarmCount())
   {
      tilt = 0.80 + 0.40 * score[pick];
      riskPct = InpRiskPercent * tilt;
      if(InpRiskMaxPercent > 0.0 && riskPct > InpRiskMaxPercent) riskPct = InpRiskMaxPercent;
   }
   want = InpFixedLot;
   riskMoney = 0.0;
   if(InpLotMode == LOT_PERCENT)
   {
      if(riskPct <= 0.0) { FlushOx(sym, "진입X 위험비율"); return(false); }
      riskMoney = AccountBalance() * riskPct / 100.0;
      want = riskMoney / (dist * mpp);
   }
   else
   {
      riskMoney = InpFixedLot * dist * mpp;
   }
   if(!FitLot(sym, cmd, want, lot)) { FlushOx(sym, "진입X 랏"); return(false); }
   if(HasOurPosition(sym)) { FlushOx(sym, "진입X 포지션없음"); return(false); }
   ticket = SendMarket(sym, dir[pick], lot, sl[pick], clsPx[pick], chase, slmin, slmax);
   if(ticket <= 0) { FlushOx(sym, "진입X 주문"); return(false); }
   gTradesToday++;
   if(tag[pick] == "PULL") gPullToday++;
   gEntrySeq++;
   realRisk = riskMoney;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
   {
      openPx = OrderOpenPrice();
      realRisk = MathAbs(openPx - sl[pick]) / point * mpp * OrderLots();
      if(realRisk <= 0.0) realRisk = riskMoney;
   }
   AddOpen(ticket, ff, preset, realRisk, extreme[pick]);
   Print("IDC_F entry ", sym, " ", tag[pick], " lot=", DoubleToString(lot, 4), " ", TfNote());
   FlushOx(sym, "진입O " + tag[pick] + " 점수" + DoubleToString(score[pick], 2));
   SaveLearn();
   return(true);
}

bool CloseTicket(int ticket)
{
   string sym;
   double lot;
   double price;
   int digits;
   int attempt;
   int e;
   int type;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return(false);
   if(OrderCloseTime() != 0) return(true);
   sym = OrderSymbol();
   lot = OrderLots();
   type = OrderType();
   digits = (int)MarketInfo(sym, MODE_DIGITS);
   for(attempt = 0; attempt < 3; attempt++)
   {
      RefreshRates();
      if(!OrderSelect(ticket, SELECT_BY_TICKET)) return(false);
      if(OrderCloseTime() != 0) return(true);
      price = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
      price = NormalizeDouble(price, digits);
      if(OrderClose(ticket, lot, price, InpSlippagePoints, clrYellow)) return(true);
      e = GetLastError();
      Print("IDC_F close fail ", IntegerToString(ticket), " err=", IntegerToString(e));
      if(e == 146 || e == 128 || e == 129 || e == 135 || e == 136 || e == 138)
      {
         Sleep(200);
         continue;
      }
      return(false);
   }
   return(false);
}

void ModifySL(int ticket, double newSL)
{
   string sym;
   double point;
   double cur;
   double bid;
   double ask;
   int digits;
   int stopLv;
   int freeze;
   int need;
   int sweep;
   int buf;
   int slmin;
   int slmax;
   int trS;
   int trStep;
   int spCap;
   int reclaimMin;
   int chase;
   int gap;
   int type;
   double movePts;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   if(OrderCloseTime() != 0) return;
   sym = OrderSymbol();
   point = MarketInfo(sym, MODE_POINT);
   if(point <= 0.0) return;
   digits = (int)MarketInfo(sym, MODE_DIGITS);
   newSL = NormalizeDouble(newSL, digits);
   cur = OrderStopLoss();
   type = OrderType();
   if(MathAbs(cur - newSL) <= point * 0.5) return;
   if(type == OP_BUY && cur > 0.0 && newSL <= cur) return;
   if(type == OP_SELL && cur > 0.0 && newSL >= cur) return;
   bid = MarketInfo(sym, MODE_BID);
   ask = MarketInfo(sym, MODE_ASK);
   stopLv = (int)MarketInfo(sym, MODE_STOPLEVEL);
   freeze = (int)MarketInfo(sym, MODE_FREEZELEVEL);
   need = stopLv;
   if(freeze > need) need = freeze;
   if(need < 0) need = 0;
   if(type == OP_BUY && (bid - newSL) / point < need) return;
   if(type == OP_SELL && (newSL - ask) / point < need) return;
   EffPoints(sym, sweep, buf, slmin, slmax, trS, trStep, spCap, reclaimMin, chase);
   gap = trStep * InpBrokerSyncMult;
   if(gap < 1) gap = 1;
   if(gModifiesToday >= InpMaxModifies) gap = gap * 2;
   movePts = MathAbs(newSL - cur) / point;
   if(cur != 0.0 && movePts + 0.01 < gap) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   if(!OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrNONE))
   {
      Print("IDC_F modify fail ", IntegerToString(ticket), " err=", IntegerToString(GetLastError()));
      return;
   }
   gModifiesToday++;
}

void ManageTicket(int ticket)
{
   string sym;
   int idx;
   int type;
   int preset;
   int sweep;
   int buf;
   int slmin;
   int slmax;
   int trS;
   int trStep;
   int spCap;
   int reclaimMin;
   int chase;
   int useStart;
   int stand;
   int profitPts;
   int prevPts;
   int held;
   int lock;
   int digits;
   double point;
   double bid;
   double ask;
   double ext;
   double virt;
   double openPx;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   if(OrderCloseTime() != 0) return;
   if(OrderMagicNumber() != InpMagic) return;
   if(OrderType() != OP_BUY && OrderType() != OP_SELL) return;
   sym = OrderSymbol();
   idx = FindOpen(ticket);
   if(idx < 0) return;
   if(FlattenDue())
   {
      CloseTicket(ticket);
      return;
   }
   point = MarketInfo(sym, MODE_POINT);
   if(point <= 0.0) return;
   type = OrderType();
   bid = MarketInfo(sym, MODE_BID);
   ask = MarketInfo(sym, MODE_ASK);
   if(bid <= 0.0 || ask <= 0.0) return;
   ext = gOpenExtreme[idx];
   openPx = OrderOpenPrice();
   if(type == OP_BUY)
   {
      prevPts = (int)MathFloor((ext - openPx) / point + 1e-6);
      if(bid > ext) ext = bid;
      profitPts = (int)MathFloor((ext - openPx) / point + 1e-6);
   }
   else
   {
      prevPts = (int)MathFloor((openPx - ext) / point + 1e-6);
      if(ext <= 0.0 || ask < ext) ext = ask;
      profitPts = (int)MathFloor((openPx - ext) / point + 1e-6);
   }
   if(ext != gOpenExtreme[idx])
   {
      gOpenExtreme[idx] = ext;
      if(profitPts != prevPts && TimeCurrent() != gLastOpenSave)
      {
         gLastOpenSave = TimeCurrent();
         SaveOpen();
      }
   }
   held = (int)(TimeCurrent() - OrderOpenTime());
   if(InpMinHoldSeconds > 0 && held < InpMinHoldSeconds) return;
   preset = gOpenPreset[idx];
   EffPoints(sym, sweep, buf, slmin, slmax, trS, trStep, spCap, reclaimMin, chase);
   useStart = (int)MathRound(trS * PresetFactor(preset));
   if(useStart < trStep) useStart = trStep;
   stand = InpStandOffPoints;
   lock = LockPoints(useStart, trStep, stand, profitPts);
   if(lock < 0) return;
   digits = (int)MarketInfo(sym, MODE_DIGITS);
   if(type == OP_BUY) virt = NormalizeDouble(openPx + lock * point, digits);
   else virt = NormalizeDouble(openPx - lock * point, digits);
   if(type == OP_BUY && bid <= virt)
   {
      CloseTicket(ticket);
      return;
   }
   if(type == OP_SELL && ask >= virt)
   {
      CloseTicket(ticket);
      return;
   }
   ModifySL(ticket, virt);
}

void ManageAll()
{
   int tickets[64];
   int n;
   int i;
   n = 0;
   for(i = OrdersTotal() - 1; i >= 0 && n < 64; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != InpMagic) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      tickets[n] = OrderTicket();
      n++;
   }
   for(i = 0; i < n; i++) ManageTicket(tickets[i]);
}

void Panel()
{
   string text;
   text = "IDC_F v2.0 안2  " + TfNote() + "\n";
   text = text + "KST " + TimeToString(KstNow(), TIME_DATE | TIME_MINUTES);
   text = text + "  session=" + (InSession() ? "ON" : "OFF");
   text = text + "  STAB=" + (gStabGate ? "ON" : "OFF");
   text = text + "  learn=" + IntegerToString(gClosed) + "/" + IntegerToString(WarmCount()) + "\n";
   text = text + "today=" + IntegerToString(gTradesToday) + "/" + IntegerToString(InpMaxTradesDay);
   text = text + "  pull=" + IntegerToString(gPullToday) + "  dayR=" + DoubleToString(gDayR, 2) + "\n";
   text = text + "cut=" + IntegerToString(gPercentile) + "  riskOK=" + (RiskAllowsEntry() ? "Y" : "N") + "\n";
   text = text + "W " + DoubleToString(gW[0], 2) + " " + DoubleToString(gW[1], 2) + " " + DoubleToString(gW[2], 2) + " " + DoubleToString(gW[3], 2);
   Comment(text);
}

void Run()
{
   int i;
   if(!gSelfOK || IsStopped()) return;
   if(!gHistWarned && iBars(Symbol(), InpSignalTF) < 30)
   {
      Print("IDC_F waiting for signal history ", TfNote());
      gHistWarned = true;
   }
   RefreshOffset();
   RollDay();
   RefreshSymbols();
   RecoverClosed();
   AdoptOrphans();
   for(i = 0; i < gN; i++) TryEntry(SName[i], i);
   ManageAll();
   Panel();
}

void CatchUpDay()
{
   int today;
   int counted;
   today = DayKey();
   if(gDayKey != 0 && gDayKey != today)
   {
      ApplyPercentile(gTradesToday);
      gTradesToday = CountEntriesOnDay(today);
      gModifiesToday = 0;
      gDayLocked = false;
      gDayKey = today;
      gDayStartBal = AccountBalance();
      SaveLearn();
   }
   else
   {
      counted = CountEntriesOnDay(today);
      if(counted > gTradesToday) gTradesToday = counted;
      if(gDayKey == 0) gDayKey = today;
      if(gDayStartBal <= 0.0) gDayStartBal = AccountBalance();
   }
   gHaveDay = true;
}

int OnInit()
{
   gSelfOK = SelfTest();
   if(!gSelfOK)
   {
      Print("IDC_F self-test FAILED. No trading.");
      return(INIT_FAILED);
   }
   Print("IDC_F v2.0 self-test OK ", TfNote(), " plan2 REG+PULL");
   if(InpInitialBalance > 0.0) gInitBal = InpInitialBalance;
   LoadLearn();
   if(gInitBal <= 0.0) gInitBal = AccountBalance();
   LoadOpen();
   RefreshOffset();
   CatchUpDay();
   RecoverClosed();
   AdoptOrphans();
   EventSetTimer(1);
   Run();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   SaveLearn();
   SaveOpen();
   Comment("");
   Print("IDC_F stop reason=", IntegerToString(reason));
}

void OnTick()
{
   Run();
}

void OnTimer()
{
   Run();
}
