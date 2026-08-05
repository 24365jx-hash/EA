# IDC_7 — 원본전략 전수 매핑 · 검수 보고서

- **EA 파일**: `MQL4/Experts/IDC_7.mq4`
- **버전**: 1.01

## BUGFIX v1.01 — 트레일링 중 손실 마감

**증상**: TrailingStart(예: 50pt) 도달 후 트레일 이동이 보이는데 항상 손실로 청산.

**원인**: `ModifySL()`이 브로커 `STOPLEVEL` 미달 시 요청 SL(본전)을 시장가 방향으로 **클램프**하여 진입가보다 나쁜 손실 SL로 내려 씀. 이후 STAGE1 완료 처리 → 되돌림에 손실 SL 체결.

**수정**:
1. STOPLEVEL 미달 시 클램프 금지 → 수정 거부
2. 수익이 STOPLEVEL 미만이면 STAGE1 대기
3. 실제 `OrderStopLoss()`가 본전 이상일 때만 STAGE1 완료
4. STAGE2 타깃이 본전 미만/STOPLEVEL 미달이면 스킵
- **대상 플랫폼**: MT4 (`#property strict`)
- **검수 기준**: 사용자 제공 `[EA 시스템 원본 전략 명세서 : IDC_7]` 전문
- **정적 검사**: `tools/mql4_static_check.py` → **PASS**
- **MetaEditor 컴파일**: 본 환경에 MetaEditor/wine MT4 없음 → 로컬 MT4에서 `.mq4` 컴파일 필요 (소스 정적 오류 0)

---

## A. 검수 총평

| # | 검수 항목 | 결과 |
|---|---|---|
| 1 | 원본전략 100% 구현 매핑 | **PASS** (명세 전항 코드 연결 확인) |
| 2 | UI만 있고 기능 없는 파라미터 색출 | **없음** (구분선 `InpSep*` 제외, 전 input 참조) |
| 3 | 허위/은폐 보고 색출 | **해당 없음** — 아래 매핑표에 함수/라인 명시 |
| 4 | 명령 불복종 항목 | **없음** (MT4전용·포인트단위·Pending·2단계트레일·가디언·일손실·시간필터 모두 구현) |
| 5 | 항목단위 정밀 검수 | **완료** (섹션 B~G) |
| 6 | 형식만 있고 미작동 코드 색출 | **없음** |
| 7 | 상업용 완비 | **PASS** (심볼자동감지, 랏정규화, STOPLEVEL대응, 재시작 pending 복구, 대시보드) |
| 8 | 컴파일 오류 | **정적 PASS** / MetaEditor는 사용자 MT4에서 확인 |

---

## B. 시스템 기본 정보 매핑

| 명세 | 구현 | 위치 | 판정 |
|---|---|---|---|
| EA 명칭 IDC_7 | `#property copyright "IDC_7"`, comment 기본값 `"IDC_7"` | L9–L13, `InpTradeComment` | OK |
| 적용 시장 XAUUSD 골드 전용 | `IsGoldSymbolName` (XAU/GOLD), 비골드 거부 | `DetectGoldSymbol` / `IsGoldSymbolName` | OK |
| 모든 브로커 심볼명 자동 감지 | `InpAutoDetectGold` + `SymbolsTotal` 스캔 + 우선순위 | `DetectGoldSymbol` | OK |
| 수동 심볼 오버라이드 | `InpManualSymbol` | `DetectGoldSymbol` 선두 분기 | OK |
| 추천 TF M1 / M5 참고 | ATR·EMA·캔들수명 모두 `PERIOD_M1` 고정 사용 | `IsStrongTrendBlocked`, `ManagePendingCandleLifetime` | OK |
| OnTick 기반 | `void OnTick()` | `OnTick` | OK |
| Pending Order 체결 | `OP_BUYSTOP` / `OP_SELLSTOP` `OrderSend` | `PlacePending` | OK |
| 수치 Point 단위 통일 | 전 거리 `Points` input + `PointsToPrice` / `PriceToPoints` | 전역 헬퍼 | OK |
| 10 Points = 1 Pip = $0.1 | 골드 Point 규약 주석 + Point 연산 | 파일 헤더 | OK |

---

## C. 진입 3중 조건 매핑

### C-1. ① 연속 틱 (Consecutive Ticks)

| 명세 | 구현 | 판정 |
|---|---|---|
| 동일 방향 상승/하락 N회 이상 | Bid 비교로 `TICK_UP`/`TICK_DOWN`, `g_tickCount` 누적 | OK |
| 디폴트 6회 | `InpConsecutiveTicks = 6` | OK |
| 조건 미달 시 미발주 | `g_tickCount < InpConsecutiveTicks` → return | OK |
| 동일가 틱 처리 | 방향 불명 → 시퀀스 리셋 (`TICK_FLAT`) | OK |

**코드 경로**: `ProcessTickSequence()` → 카운트 검사 → `TryPlacePendingOrder()`

### C-2. ② 이동 거리 (Move Distance)

| 명세 | 구현 | 판정 |
|---|---|---|
| N회 연속 구간의 가격 변동폭 ≥ P | `g_seqMovePts = PriceToPoints(bid - g_seqStartPrice)` | OK |
| 디폴트 200 Points ($2.0) | `InpMoveDistancePts = 200` | OK |
| 미달 시 미발주 | `g_seqMovePts < InpMoveDistancePts` → return | OK |

### C-3. ③ 강한 추세 진입금지 필터

| 명세 | 구현 | 판정 |
|---|---|---|
| 파라미터 설정 가능 | `InpMaxATRPts`, `InpMaxEMADiffPts`, `InpATRPeriod`, `InpEMAPeriod` | OK |
| ON/OFF 기능 | `InpUseStrongTrendFilter` (default true) | OK |
| ATR(14) > MaxATR → 차단 | `iATR(...,14,...) / Point > InpMaxATRPts` | OK |
| Max ATR 디폴트 400 | `InpMaxATRPts = 400` | OK |
| EMA(50) 1바 기울기 > Max → 차단 | `|EMA[0]-EMA[1]| / Point > InpMaxEMADiffPts` | OK |
| Max EMA Diff 디폴트 100 | `InpMaxEMADiffPts = 100` | OK |
| OFF 시 차단 안 함 | `if(!InpUseStrongTrendFilter) return false` | OK |

**함수**: `IsStrongTrendBlocked()`

### C-4. 주문 유형 및 수명 제어

| 명세 | 구현 | 판정 |
|---|---|---|
| 조건 충족 시 현재가±Pending Distance에 BuyStop/SellStop | UP→BuyStop(Ask+dist), DOWN→SellStop(Bid−dist) | OK |
| Pending Distance 파라미터 | `InpPendingDistancePts` (명세 디폴트 미기재 → **50** 적용, 섹션 H) | OK* |
| M1 한 캔들 내 미체결 시 신규 캔들에서 자동 취소 | `ManagePendingCandleLifetime` → `OrderDelete` | OK |
| 포지션 열리면 청산 전 추가 진입 금지 | `CountOurPositions()>0` / `CountOurPendings()>0` 차단 | OK |
| TP = 0 | `tp = 0.0` 고정, OrderSend에 전달 | OK |
| SL 동시 설정 디폴트 300 | `InpStopLossPts = 300`, pending 생성 시 SL 계산 | OK |

---

## D. 청산 · 트레일링 매핑

| 명세 | 구현 | 판정 |
|---|---|---|
| TP 사용 안 함 | `tp = 0.0` 고정 / 대시보드 `TP: 0` | OK |
| SL 디폴트 300 Points | `InpStopLossPts = 300` | OK |
| 1단계: 수익 ≥ TrailingStart(200) → SL을 진입가로 (원금보존) | `ManageTrailingStop` STAGE1 → `targetSL = openPrice` | OK |
| 2단계: STAGE1 후 TrailingStep(10) 간격 추격 | `steps = floor((profit-Start)/Step)`, SL = open ± steps×Step | OK |
| TrailingStart 디폴트 200 | `InpTrailingStartPts = 200` | OK |
| TrailingStep 디폴트 10 | `InpTrailingStepPts = 10` | OK |
| 불리 방향 SL 수정 금지 | `ModifySL` 개선 방향만 허용 | OK |

---

## E. 리스크 · 자금관리 매핑

### E-1. SL 가디언

| 명세 | 구현 | 판정 |
|---|---|---|
| OnTick 실시간 손실 포인트 감시 | `SLGuardianTick()` — OnTick 최우선 호출 | OK |
| 설정 SL 초과 시 시장가 강제 청산 | `lossPts >= InpStopLossPts` → `OrderClose` | OK |
| ON/OFF | `InpSLGuardianOn` | OK |
| (상업 보강) SL=0 누락 복구 | 누락 시 초기 SL 재설정 | OK (명세 취지 강화) |

### E-2. 랏 수 설정

| 명세 | 구현 | 판정 |
|---|---|---|
| Manual Lot | `LOT_MANUAL` + `InpManualLots` | OK |
| Auto Lot: 잔고 × 리스크% / (SL거리×포인트가치) | `CalcLots()` | OK |
| 리스크% 파라미터 | `InpRiskPercent` (명세 디폴트 미기재 → **1.0%**, 섹션 H) | OK* |
| min/max/step 정규화 | `NormalizeLots` | OK |

### E-3. 일일 손실 한도

| 명세 | 구현 | 판정 |
|---|---|---|
| 당일 자정 기준 시작 잔고 | `g_dayStamp` / `g_dayStartBalance = AccountBalance()` | OK |
| 누적 손실에 평가손익 포함 | `loss = dayStartBalance - AccountEquity()` | OK |
| 설정 % 도달 시 당일 신규 매매 정지 | `g_dailyLossHit` → `IsTradingAllowed` false | OK |
| 디폴트 3.0% | `InpMaxDailyLossPct = 3.0` | OK |

### E-4. 거래 시간 필터

| 명세 | 구현 | 판정 |
|---|---|---|
| 브로커 서버 시간 기준 | `TimeCurrent()` | OK |
| Start Hour/Minute ~ End Hour/Minute | `InpStartHour/Minute`, `InpEndHour/Minute` | OK |
| 해당 시간대만 진입 허용 | `IsWithinTimeFilter` → `IsTradingAllowed` | OK |
| ON/OFF | `InpUseTimeFilter` | OK |
| 자정 넘김 세션 | overnight wrap 지원 | OK |
| 디폴트 시간 | 명세 미기재 → **00:00–23:59** (전일 허용) | OK* |

---

## F. 파라미터 디폴트 전수표

| 파라미터 | 명세 디폴트 | 코드 디폴트 | 일치 |
|---|---|---|---|
| ConsecutiveTicks N | 6 | 6 | YES |
| MoveDistance P | 200 | 200 | YES |
| StrongTrendFilter | ON + 설정가능 | `true` + inputs | YES |
| Max ATR | 400 | 400 | YES |
| Max EMA Diff | 100 | 100 | YES |
| ATR Period | 14 | 14 | YES |
| EMA Period | 50 | 50 | YES |
| Pending Distance | (미기재) | 50 | 명세外 합리적 디폴트 |
| SL | 300 | 300 | YES |
| TP | 0 (미사용) | 0 하드코딩 | YES |
| TrailingStart | 200 | 200 | YES |
| TrailingStep | 10 | 10 | YES |
| Daily Loss % | 3.0 | 3.0 | YES |
| Auto Risk % | (미기재) | 1.0 | 명세外 합리적 디폴트 |
| Time Filter window | (미기재) | 00:00–23:59 | 명세外 전일개방 |

---

## G. Input 기능 존재 여부 (허위 UI 색출)

| Input | 실제 사용처 | 기능 |
|---|---|---|
| InpSep* (6개) | MT4 입력창 구분선 | UI 구분 전용 (정상) |
| InpAutoDetectGold | `DetectGoldSymbol` | 동작 |
| InpManualSymbol | `DetectGoldSymbol` | 동작 |
| InpMagicNumber | 전 Order* 필터 | 동작 |
| InpSlippagePts | OrderSend/OrderClose | 동작 |
| InpTradeComment | OrderSend | 동작 |
| InpConsecutiveTicks | `ProcessTickSequence` | 동작 |
| InpMoveDistancePts | `ProcessTickSequence` | 동작 |
| InpPendingDistancePts | `PlacePending` | 동작 |
| InpUseStrongTrendFilter | `IsStrongTrendBlocked` | 동작 |
| InpATRPeriod / InpMaxATRPts | `IsStrongTrendBlocked` | 동작 |
| InpEMAPeriod / InpMaxEMADiffPts | `IsStrongTrendBlocked` | 동작 |
| InpStopLossPts | PlacePending / Guardian / AutoLot | 동작 |
| InpTrailingStartPts / StepPts | `ManageTrailingStop` | 동작 |
| InpSLGuardianOn | `OnTick` → `SLGuardianTick` | 동작 |
| InpLotMode / ManualLots / RiskPercent | `CalcLots` | 동작 |
| InpMaxDailyLossPct | `UpdateDailyLossState` | 동작 |
| InpUseTimeFilter + H/M | `IsWithinTimeFilter` | 동작 |
| InpShowDashboard / FontSize | `UpdateDashboard` | 동작 |
| InpPrintDebug | `LogDebug` | 동작 |

**결론: 기능 없는 위장 파라미터 0건.**

---

## H. 명세 미기재 → 구현 시 불가피한 상업용 보완 (은폐 아님)

아래는 원본 명세에 숫자가 없어 EA 동작에 필수라 명시한 디폴트다. 숨기지 않는다.

1. **Pending Distance = 50 Points** — 명세는 파라미터만 언급, 디폴트 숫자 없음.
2. **Auto Lot RiskPercent = 1.0%** — 명세는 방식만 언급, % 디폴트 없음.
3. **Time Filter 기본창 = 00:00–23:59** — 명세는 필드만 언급.
4. **MagicNumber = 70007**, **Slippage = 30** — 상업 EA 필수 운영값.
5. **차트 대시보드** — 명세 외 모니터링 UI (진입 로직에 영향 없음).

---

## I. OnTick 실행 순서 (실제 작동 흐름)

```
OnTick
 ├─ SLGuardianTick          // 손실초과 강제청산 / SL누락복구
 ├─ ManageOpenPosition      // pending→position 상태정리
 ├─ ManageTrailingStop      // 1단계 BE → 2단계 step 추격
 ├─ ManagePendingCandleLife // M1 새캔들이면 미체결 pending 삭제
 ├─ ProcessTickSequence     // ①틱연속 ②이동거리 ③추세필터 → Pending
 └─ UpdateDashboard         // 표시만
```

---

## J. 컴파일 · 설치

1. `MQL4/Experts/IDC_7.mq4` → MT4 `MQL4/Experts/` 복사
2. MetaEditor에서 Compile (F7)
3. XAUUSD(또는 브로커 골드 심볼) **M1** 차트에 부착
4. AutoTrading ON
5. 프리셋: `MQL4/Presets/IDC_7_XAUUSD_M1.set` (옵션)

**본 CI/클라우드 환경**: MetaEditor 바이너리 부재 → 문법/미사용input/필수API 정적 검사만 수행했고 **PASS**.

---

## K. 최종 판정

| 질문 | 답 |
|---|---|
| 원본전략대로 만들었는가? | **YES** — 섹션 B~E 전항 OK |
| UI-only 가짜 파라미터? | **0건** |
| 허위/은폐? | **없음** (섹션 H에 명세外 디폴트 공개) |
| 명령 불복종? | **없음** (MT4전용 고성능 EA 요구 충족) |
| 상업용 완비? | **YES** |
| 컴파일? | 정적 PASS / MetaEditor는 로컬 확인 |
