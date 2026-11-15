# IDC_X 정밀 전수 매핑 검수 보고 (완전무결 검수)

- 대상 파일: `MQL4/Experts/IDC_X.mq4`
- 원본 명세: `docs/IDC_X_SPEC.txt` (+ 사용자 추가 명령)
- 검수 원칙: 줄/항목/수식 단위 매핑, 허위·은폐·요약 검수 금지
- 컴파일: 본 환경에 MetaEditor/MT4 없음 → **실기 컴파일 미실시(사실 보고)**

---

## A. 사용자 추가 명령 복종 검수

| # | 명령 | 구현 위치 | 결과 |
|---|------|-----------|------|
| A1 | MT4 전용 | `IDC_X.mq4` / `#property strict` / `OrderSend` MT4 API | PASS |
| A2 | SL 가디언 | `SLGuardianTick`, `EnsureInitialSL`, `ModifySLSafe`, `InpSLGuardianOn` | PASS |
| A3 | 모든 브로커 심볼 자동감지 | `AutoDetectGoldSymbol`, `ResolveTradeSymbol`, `InpAutoDetectGold` | PASS |
| A4 | T시간 자동감지 | `DetectTimeframeAndBrokerTime` (차트 TF + 브로커 GMT 오프셋), 데이터는 강제 `PERIOD_M1` | PASS |
| A5 | 사람눈 각도 | `CalcHumanEyeAngle34` — 차트 픽셀폭/높이·가격스케일·visible bars → `atan(dy_px/dx_px)` | PASS |
| A6 | 좌측상단 대시보드 + ON/OFF | `UpdateDashboard` / `InpShowDashboard` / `CORNER_LEFT_UPPER` | PASS |
| A7 | 매 분봉 필터 상황 표시 | M1 새봉에서 필터 스냅샷 갱신, 틱마다 라벨 표시 | PASS |
| A8 | 50EMA 터치 정확 / 돌파 절대 불허 | `DetectPure50EmaTouch` + `ProcessAntiBreakout` (상호배타) | PASS — §G 상세 |

불복종 항목: **없음** (검수 기준 충족).  
단, A5는 차트 심볼/TF가 거래심볼 M1과 다를 때 픽셀 스케일이 달라질 수 있음 → 대시보드 WARN 표시(은폐 없음).

---

## B. 명세 §1 시스템 환경 매핑

| 명세 항목 | 코드 구현 | 결과 |
|-----------|-----------|------|
| GOLD M1 EMA 크로스 추세 | `DetectEmaCross` Fast/Slow EMA M1 bar1/bar2 | PASS |
| 50EMA 상태머신 오진입 차단 | touch/grace/latch/anti-breakout/entry gates | PASS |
| 대상 Gold 전 계열 | XAUUSD/GOLD/접미사 스코어 스캔 | PASS |
| 타임프레임 M1 | 모든 `iMA/iRSI/iOpen/...` → `PERIOD_M1` | PASS |
| 완성봉 bar1만 사용 | shift=1 고정, 새 M1봉에서만 판단 | PASS |
| TP 사용 안 함 | `tp = 0.0` 고정 | PASS |
| 고정 SL + 진입가 기준 트레일 | `InpStopLossPoints` + `ManageTrailingStops` | PASS |

---

## C. 명세 §2 파라미터 전수 매핑 (기능 실재 여부)

| 파라미터 | 기본값 | 코드 참조(실기능) | UI-only? | 결과 |
|----------|--------|-------------------|----------|------|
| InpShowDashboard | true | OnTick/UpdateDashboard/DeleteDashboard | NO | PASS |
| InpDashboardFontSize | 12 | SetDashLine ObjectSetText | NO | PASS |
| InpAutoDetectGold | true | ResolveTradeSymbol | NO | PASS |
| InpManualSymbol | "" | ResolveTradeSymbol | NO | PASS |
| InpFastEmaPeriod | 9 | GetEma/DetectEmaCross/Dist/Entry | NO | PASS |
| InpSlowEmaPeriod | 50 | GetEma/Touch/AntiBreak/Cross | NO | PASS |
| InpTrendEmaPeriod | 34 | CalcHumanEyeAngle34 | NO | PASS |
| InpRsiPeriod | 14 | GetRsi | NO | PASS |
| InpRsiUpper | 52.0 | CheckEntrySetupBuy `+0.5` | NO | PASS |
| InpRsiLower | 48.0 | CheckEntrySetupSell `-0.5` | NO | PASS |
| InpObservationBars | 55 | KillCycleObservationExceeded | NO | PASS |
| InpEmaGraceBars | 3 | grace++ / latch / inGrace | NO | PASS |
| InpMinEmaDistancePts | 30 | CheckEntrySetup* distOk | NO | PASS |
| InpMinEmaAngle | 5.0 | CheckEntrySetup* angOk | NO | PASS |
| InpLots | 0.50 | ExecuteMarketEntry | NO | PASS |
| InpStopLossPoints | 200 | Entry SL + EnsureInitialSL | NO | PASS |
| InpTrailingStartPts | 200 | ManageTrailingStops §5-1 | NO | PASS |
| InpTrailingStepPts | 10 | MathFloor steps §5-2 | NO | PASS |
| InpMagicNumber | 80008 | OrderSend/Select 필터 | NO | PASS |
| InpSlippagePts | 30 | OrderSend slippage | NO | PASS |
| InpTradeComment | IDC_X | OrderSend comment | NO | PASS |

### 명세 외 추가 파라미터 (사용자 명령 대응 — 허위 아님)

| 파라미터 | 용도 | 실기능 |
|----------|------|--------|
| InpAngleLookbackBars=5 | 사람눈 각도 lookback | CalcHumanEyeAngle34 |
| InpSLGuardianOn=true | 가디언 ON/OFF | SLGuardianTick 게이트 |
| InpSLGuardianRetryMs=250 | Modify 재시도 쓰로틀 | ModifySLSafe |

### UI만 있고 기능 없는 파라미터 (색출)

| 파라미터 | 판정 | 설명 |
|----------|------|------|
| InpSepUI | **UI-ONLY** | 입력창 구분선 문자열. 런타임 로직 없음 |
| InpSepSymbol | **UI-ONLY** | 동일 |
| InpSepTrend | **UI-ONLY** | 동일 |
| InpSepTrade | **UI-ONLY** | 동일 |
| InpSepGuard | **UI-ONLY** | 동일 |

→ 전략 로직용 위장 파라미터 **아님**. MT4 입력 그룹 라벨.  
→ **그 외 파라미터 중 UI-only / 기능미구현 없음.**

---

## D. 명세 §3 상태머신 전수 매핑

| 명세 | 수식/동작 | 코드 | 결과 |
|------|-----------|------|------|
| §3-1 BUY 크로스 | fast2<=slow2 && fast1>slow1 | DetectEmaCross | PASS |
| §3-1 SELL 크로스 | fast2>=slow2 && fast1<slow1 | DetectEmaCross | PASS |
| §3-1 리셋 | CrossBar=1, Touched=false, Grace=-1, Traded=false | newCross 블록 | PASS |
| §3-2 CrossBar++ | 새 봉마다 +1 | else 분기 | PASS |
| §3-2 관찰 초과 사망 | CrossBar > Observation → 플래그 소멸 | KillCycleObservationExceeded | PASS |
| §3-2 사이클 1회 제한 | 진입 시도 전 `g_IsTradedInCycle=true` (성공여부 무관) | OnNewM1BarLogic | PASS |
| §3-3 Grace++ | 유예 활성 시 새봉 +1 | OnNewM1BarLogic 상단 | PASS |
| §3-3 Latch Lock | Grace> N → Touched=false, Grace=-1, 당봉 스킵 | g_LatchSkipThisBar | PASS |

---

## E. 명세 §4 진입 조건 전수 매핑

| 명세 | 수식 | 코드 | 결과 |
|------|------|------|------|
| §4-1 BUY Anti-Break | open1<50 \|\| close1<50 → grace 소멸 | ProcessAntiBreakout | PASS |
| §4-1 SELL 대칭 | open1>50 \|\| close1>50 | ProcessAntiBreakout | PASS |
| §4-2 BUY Pure Touch | open>50 && close>50 && low<=50 | DetectPure50EmaTouch | PASS |
| §4-2 기동 | Touched=true; Grace=1 | 동일 | PASS |
| §4-2 SELL 대칭 | open<50 && close<50 && high>=50 | 동일 | PASS |
| §4-3-1 BUY Fast | high>9 && close>9 | CheckEntrySetupBuy | PASS |
| §4-3-1 SELL Fast | low<9 && close<9 | CheckEntrySetupSell | PASS |
| §4-3-2 BUY 양봉품질 | (c>o) && (c-o)>((h-c)+(o-l)) | CheckEntrySetupBuy | PASS |
| §4-3-2 SELL 음봉품질 | (c<o) && (o-c)>((h-o)+(c-l)) | CheckEntrySetupSell | PASS |
| §4-3-3 BUY RSI | rsi >= Upper+0.5 (=52.5) | CheckEntrySetupBuy | PASS |
| §4-3-3 SELL RSI | rsi <= Lower-0.5 (=47.5) 대칭 | CheckEntrySetupSell | PASS |
| §4-3-4 이격 | \|9-50\|pts >= MinDist | CalcEmaDistancePoints | PASS |
| §4-3-4 각도 | 픽셀 arctan, BUY>=Min, SELL<=-Min | CalcHumanEyeAngle34 | PASS |
| §4-4 시장가 집행 | OrderSend + 신호 소진 | ExecuteMarketEntry | PASS |

유예 게이트: `Touched && Grace∈[1..N]` 일 때만 §4-3 평가 → PASS

---

## F. 명세 §5 트레일링 전수 매핑

| 명세 | 수식 | 코드 | 결과 |
|------|------|------|------|
| 진입가 절대 기준 | OrderOpenPrice()만 사용 | ManageTrailingStops | PASS |
| §5-1 BUY 1차 SL | Open + StartPts*Point | 동일 | PASS |
| §5-1 SELL 1차 SL | Open - StartPts*Point | 동일 | PASS |
| §5-2 Floor steps | floor((profit-Start)/Step) | MathFloor | PASS |
| §5-2 BUY 최종 SL | Open+Start+steps*Step | 동일 | PASS |
| 유리 방향만 | BUY newSL>curSL / SELL newSL<curSL | ModifySLSafe | PASS |
| STOPLEVEL 필터 | MODE_STOPLEVEL/FREEZELEVEL | ModifySLSafe | PASS |

---

## G. 최중요: 50EMA 터치 vs 돌파 검수 (항목 10)

### G1. 순수 터치 정의 (돌파 아님)
BUY 인정 조건(코드 그대로):
```
open1 > slowEma && close1 > slowEma && low1 <= slowEma
```
- 몸통(시가·종가)이 50EMA **위**에만 있을 때
- **저가 꼬리만** 50EMA를 스치거나 관통
- open/close가 50EMA 아래로 가는 순간 → 터치 조건 자체 false

SELL 대칭:
```
open1 < slowEma && close1 < slowEma && high1 >= slowEma
```

### G2. 돌파/침범 절대 불허 (Anti-Breakout)
BUY:
```
open1 < slowEma || close1 < slowEma
→ g_50EmaTouched=false; g_GraceBarCounter=-1
```
SELL:
```
open1 > slowEma || close1 > slowEma → 동일 소멸
```

### G3. 상호배타 증명
- 돌파봉(몸통 침범)은 순수터치 수식을 동시에 만족할 수 없음
- 처리 순서: AntiBreakout → (미터치 시) PureTouch
- 따라서 **몸통 돌파를 터치로 오인하는 경로 없음**

### G4. 거짓 구현 여부
- 대시보드에만 있고 판정 없는 구조 아님
- `g_50EmaTouched` / `g_GraceBarCounter`가 진입 게이트 `inGrace`에 실제 연결
- 진입은 `inGrace==true`일 때만 `CheckEntrySetup*` 통과 후 `OrderSend`

**판정: 50EMA 터치 정확 / 돌파 진입 경로 없음 → PASS**

---

## H. 허위·은폐·땜빵·형식적 구현 색출

| 검사 | 결과 |
|------|------|
| UI만 있고 미연결 전략 파라미터 | 없음 (InpSep* 구분선만 UI-only로 명시) |
| 대시보드 표시만 하고 필터 미적용 | 없음 — 동일 변수로 게이트 |
| 각도 대충(가격비율만) | 없음 — 차트 픽셀 변환 사용 |
| SL 가디언 스텁 | 없음 — SL=0 탐지+OrderModify+재시도간격 |
| 심볼 자동감지 스텁 | 없음 — SymbolsTotal 스코어 스캔 |
| 신호 소진 미구현 | 없음 — 체결 전 소진 |
| TP 몰래 사용 | 없음 — tp=0 |
| 틱(bar0) 판단 | 없음 — bar1 + IsNewM1Bar |
| 컴파일 성공 허위보고 | **하지 않음** — MetaEditor 없음 명시 |
| 땜빵식 주석만 있는 함수 | 없음 |

---

## I. 잔여 리스크 (은폐 없이 사실 보고)

1. **실기 컴파일/테스터 미실행**: 원격 환경에 MT4 없음.
2. **사람눈 각도**: EA를 Gold M1 차트에 부착해야 화면 각도와 일치. 다른 심볼/TF 차트면 WARN.
3. **InpSep***: 입력 구분선 — 기능 파라미터 아님(위 색출 완료).
4. **브로커 포인트 정의**: `MODE_POINT` 기준. 브로커마다 포인트/핍 표기 차이는 계정 규격 따름.

---

## J. 최종 판정

| 영역 | 판정 |
|------|------|
| 원본 전략 100% 구현 매핑 | **PASS** |
| 사용자 추가 명령 | **PASS** |
| UI-only 위장 파라미터(전략) | **없음** (Sep 라벨만) |
| 허위/은폐/불복종 | **없음** |
| 50EMA 터치/돌파 불허 | **PASS** |

제출물: `MQL4/Experts/IDC_X.mq4`
