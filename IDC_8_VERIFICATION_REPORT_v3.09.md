# IDC_8 v3.09 — 원본전략 1:1 전수 매핑 및 검증 보고서

**EA:** `IDC_8.mq4` v3.09  
**기준 문서:** 사용자 확정 원본전략 (2026-07-06 컴펌)  
**검증일:** 2026-07-06  
**v3.08 위반분:** 전부 롤백 완료

---

## 1. v3.08 롤백 확인

| v3.08 위반 | v3.09 처리 | 검증 |
|------------|-----------|------|
| `g_rsi_seen_above_upper` 체류 인정 | **삭제** — `g_rsi_armed`만 엄격 52↑ 돌파로 설정 | `ProcessSellRsiOnClosedBar` L728-736 |
| 종가 `<48`만으로 WAIT_EMA | **삭제** — `IsRsiBreakoutBelow` 엄격 돌파만 | L738-742 |
| 9EMA `low` 돌파 조건 제거 | **복원** — `IsSellEmaBreakthrough` (`low < 9EMA`) | L548-556 |
| BUY 9EMA `high` 돌파 제거 | **복원** — `IsBuyEmaBreakthrough` (`high > 9EMA`) | L570-578 |

---

## 2. SELL 원본 6항목 → 코드 1:1 매핑

| # | 원본 조건 | 코드 함수/위치 | 판정식 (마감봉 shift=1) | 검증 |
|---|-----------|---------------|------------------------|------|
| 1 | 데드크로스 9EMA↓50EMA | `DetectEmaCrossOnClosedBar` L707-711 | `fast_prev>=slow_prev && fast_curr<slow_curr` | **O** |
| 2 | 크로스 후 N봉 이내 (크로스봉 포함) | `IsObservationWindowExpired` L609-612, `RemainingObservationBars` L595-606 | `elapsed = iBarShift(cycle_start)`; `remaining = N - elapsed + 1` | **O** |
| 3a | RSI 52 **상향 돌파** (1단계) | `ProcessSellRsiOnClosedBar` L728-736 | `IsRsiBreakoutAbove`: `rsi_prev<=52 && rsi_curr>52` | **O** |
| 3b | RSI 48 **하향 돌파** (2단계, 1단계 후) | `ProcessSellRsiOnClosedBar` L738-742 | `g_rsi_armed && IsRsiBreakoutBelow`: `rsi_prev>=48 && rsi_curr<48` | **O** |
| 4a | 9EMA **하향 돌파(이탈)** | `IsSellEmaBreakthrough` L548-556 | `low < fast_ema` (터치≠돌파) | **O** |
| 4b | 종가 9EMA 아래 | `IsSellEmaCloseBelow` L559-567 | `close < fast_ema` | **O** |
| 4c | 몸통>꼬리 | `IsBodyDominant` L533-545 | `body > upper_wick + lower_wick` | **O** |
| 4d | RSI 48↓ 완료봉 포함 3봉 유예 | `BeginWaitEmaPhase` L647-663, `IsEmaGraceWindowExpired` L628-634 | `BarsSinceRsiTrigger() > InpEmaGraceBars` 시 만료 | **O** |
| 5 | 사이클당 1회 진입 | `g_entry_taken`, `OpenPositionAtSetupClose` L1046 | OrderSend 성공 시 `g_entry_taken=true` | **O** |
| 6 | 데드크로스 후 SELL만 | `IsSetupEntryPermitted` L683-685, `g_cycle==CYCLE_SELL` | BUY 차단 | **O** |

**진입 시점:** `OnTick` → `IsNewBar` → `ProcessEntryLogicOnNewBar` → `ProcessSellRsi` → `TrySellEntry` (동일 신규봉) → `OpenPositionAtSetupClose` → 다음봉 첫 틱 Ask/Bid 체결, SL=셋업 종가 기준.

---

## 3. BUY 원본 (SELL 대칭) → 코드 1:1 매핑

| # | 원본 조건 | 코드 | 검증 |
|---|-----------|------|------|
| 1 | 골든크로스 | `DetectEmaCrossOnClosedBar` L708,712-713 | **O** |
| 2 | N봉 이내 | 동일 관찰 윈도우 | **O** |
| 3a | RSI 48↓ 돌파 (1단계) | `ProcessBuyRsiOnClosedBar` L756-764 | **O** |
| 3b | RSI 52↑ 돌파 (2단계) | `ProcessBuyRsiOnClosedBar` L766-770 | **O** |
| 4a | 9EMA **상향 돌파** | `IsBuyEmaBreakthrough`: `high > fast_ema` | **O** |
| 4b | 종가 9EMA 위 | `IsBuyEmaCloseAbove`: `close > fast_ema` | **O** |
| 4c | 몸통>꼬리 | `IsBodyDominant` | **O** |
| 4d | 3봉 유예 | 동일 grace 로직 | **O** |
| 5~6 | 1회 / BUY만 | `g_entry_taken`, `CYCLE_BUY` | **O** |

---

## 4. RSI 돌파 정의 (§2) → 코드

| 원본 | 코드 | 검증 |
|------|------|------|
| 상향 돌파: prev≤기준 AND curr>기준 | `IsRsiBreakoutAbove` L424-427 | **O** |
| 하향 돌파: prev≥기준 AND curr<기준 | `IsRsiBreakoutBelow` L430-433 | **O** |
| 터치/체류 무효 | `g_rsi_seen_*` **없음**, 체류만으로 arm 불가 | **O** |

---

## 5. 금지 사항 → 코드

| 금지 | 구현 | 검증 |
|------|------|------|
| 반대 방향 | `IsSetupEntryPermitted` cycle 검사 | **O** |
| 관찰 N봉 초과 | `IsObservationWindowExpired` | **O** |
| 사이클 2회 진입 | `g_entry_taken` | **O** |
| 사이클 2회 RSI→EMA | `g_rsi_to_ema_used` + `PHASE_SETUP_EXHAUSTED` | **O** |
| 3봉 유예 초과 | `ExpireEmaGraceWindow`, `IsEmaGraceWindowExpired` | **O** |
| SL=0 | `ValidateInputs` L1304+, `ProtectAllPositionsStopLoss` | **O** |
| 포지션 중 크로스 | `DetectEmaCross` + `HasOpenPosition` | **O** |
| 필터 실패 시 유예 1봉 소모 | `TrySell/BuyEntry` grace-- (EMA 확인 시도 후) | **O** |

---

## 6. 손익 관리 → 코드

| 원본 | 코드 | 검증 |
|------|------|------|
| SL 셋업 종가 기준 고정 pt | `BuildInitialSL(order, setup_close)` L780-788 | **O** |
| TP 없음 | OrderSend TP=0 L1031-1032 | **O** |
| 트레일링 | `ManageTrailingStop` L1191+ | **O** |
| SL=0 금지 | 입력 검증 + 매틱 복구 | **O** |

---

## 7. §8 횡보 필터 → 코드

| 필터 | 파라미터 | 코드 | 검증 |
|------|----------|------|------|
| 9-50 EMA 이격 | `InpUseEmaSepFilter`, `InpMinEmaSepPts` | `PassesEmaSeparationFilter` L446-461 | **O** |
| EMA34 시각 각도 | `InpMinAngleDeg` 등 | `GetEmaVisualAngleDeg` + `PassesEmaAngleFilter` | **O** |
| SELL 각도 | ≤ -78.7° | L513-514 | **O** |
| BUY 각도 | ≥ +78.7° | L516-517 | **O** |

---

## 8. 입력 파라미터 전수 (23개)

| # | 파라미터 | 코드 사용처 | UI만 | 검증 |
|---|----------|------------|------|------|
| 1 | InpAutoDetectGold | DetectGoldSymbol | | **O** |
| 2 | InpManualSymbol | DetectGoldSymbol | | **O** |
| 3 | InpFastEmaPeriod | GetFastEma, GetEmaPair | | **O** |
| 4 | InpSlowEmaPeriod | GetEmaPair, sep filter | | **O** |
| 5 | InpRsiPeriod | GetRsiPair | | **O** |
| 6 | InpRsiUpper | RSI breakout | | **O** |
| 7 | InpRsiLower | RSI breakout | | **O** |
| 8 | InpObservationBars | 관찰 윈도우 | | **O** |
| 9 | InpEmaGraceBars | 유예 3봉 | | **O** |
| 10 | InpUseEmaSepFilter | PassesEmaSeparationFilter | | **O** |
| 11 | InpMinEmaSepPts | PassesEmaSeparationFilter | | **O** |
| 12 | InpUseEmaAngleFilter | PassesEmaAngleFilter | | **O** |
| 13 | InpAngleEmaPeriod | GetEmaVisualAngleDeg | | **O** |
| 14 | InpAngleLookback | GetEmaVisualAngleDeg | | **O** |
| 15 | InpMinAngleDeg | PassesEmaAngleFilter | | **O** |
| 16 | InpLots | OrderSend | | **O** |
| 17 | InpStopLossPoints | SL 전 구간 | | **O** |
| 18 | InpTrailingStartPts | CalcTrailingStopPrice | | **O** |
| 19 | InpTrailingStepPts | CalcTrailingStopPrice | | **O** |
| 20 | InpMagicNumber | IsOurOrderTicket | | **O** |
| 21 | InpSlippagePts | OrderSend, slippage check | | **O** |
| 22 | InpTradeComment | OrderSend | | **O** |
| 23 | **InpDebugBarLog** | LogBarFilterStatus | | **O** (v3.09 신규) |

**UI만 파라미터: 0개**

---

## 9. 매봉 필터 O/X 로그 (`InpDebugBarLog`)

| 항목 | 로그 키 | 의미 |
|------|---------|------|
| 봉 시각 | `BAR\|YYYY.MM.DD HH:MM` | 마감봉(shift=1) |
| 사이클 | `Cyc=` | NONE/SELL/BUY |
| 단계 | `Ph=` | IDLE/WAIT_RSI/WAIT_EMA/EXHAUSTED |
| 관찰 | `Obs=` | N봉 이내 O/X |
| 유예 | `Grace=` | 남은 유예 봉 수 |
| RSI 1·2단계 | `RSI52up` / `RSI48dn` / `RSIarmed` | 해당 봉 돌파 O/X + arm 상태 |
| 9EMA 돌파 | `EMAbreak=` | low<9EMA (SELL) / high>9EMA (BUY) |
| 9EMA 종가 | `EMAclose=` | close vs 9EMA |
| 몸통 | `EMAbody=` | body>wicks |
| 9EMA 통합 | `EMAall=` | 위 3개 AND |
| 이격 | `Sep=` | pt 값 + O/X |
| 각도 | `Ang=` | 도 값 + O/X |
| 범위필터 | `Rng=` | Sep AND Ang |
| 진입허가 | `SetupOK=` | IsSetupEntryPermitted |
| 최종 | `ENTRY=` | SetupOK AND EMAall AND Rng |
| 체결잠금 | `Taken=` | g_entry_taken |

**출력 위치:** MT4 터미널 **「전문가」** 탭 (`Print`). `InpDebugBarLog=false` 시 로그 없음.

---

## 10. 처리 순서 검증 (05:21 셋업캔들 시나리오)

신규봉(05:22:00) 첫 틱:

1. `DetectEmaCrossOnClosedBar` — 기존 SELL 사이클 유지
2. `ProcessSellRsiOnClosedBar` — 48↓ 돌파 시 `BeginWaitEmaPhase()` (이미 WAIT_EMA면 스킵)
3. `TrySellEntryOnClosedBar` — bar[1]=05:21 캔들:
   - `IsSellEmaBreakthrough(1)` → low < 9EMA
   - `IsSellEmaCloseBelow(1)` → close < 9EMA
   - `IsBodyDominant(1)` → 몸통>꼬리
   - `PassesRangeFilters` → §8
   - 통과 시 `OpenPositionAtSetupClose` → **05:21 종가 기준 SELL**

동일 봉에서 RSI 48↓ 트리거 + 9EMA 셋업 동시 충족 시 2→3 연속 실행으로 **즉시 진입**.

---

## 11. 정적 검증 체크리스트

| # | 검증 항목 | 결과 |
|---|----------|------|
| 1 | v3.08 RSI 체류/종가-only 로직 잔존 없음 | **PASS** |
| 2 | 9EMA 돌파(low/high) 복원 | **PASS** |
| 3 | RSI 엄격 2봉 돌파만 | **PASS** |
| 4 | 원본 6항목 SELL 전항목 매핑 | **PASS** |
| 5 | BUY 대칭 | **PASS** |
| 6 | 금지 8항목 | **PASS** |
| 7 | 손익 4항목 | **PASS** |
| 8 | §8 필터 2항목 | **PASS** |
| 9 | 파라미터 23개 전부 연결 | **PASS** |
| 10 | InpDebugBarLog ON/OFF | **PASS** |

**종합: 원본전략 1:1 구현 정적 검증 PASS (v3.09)**

---

## 12. 사용자 재검증 방법

1. MT4에서 `IDC_8.mq4` v3.09 컴파일·재부착
2. `InpDebugBarLog = true` 설정
3. 05:21 전후 구간 Strategy Tester 또는 실시간
4. 전문가 탭에서 `IDC_8|BAR|...|ENTRY=O` 봉 확인
5. `ENTRY=X` 시 로그에서 `EMAbreak` / `Sep` / `Ang` 등 X 항목이 차단 원인
