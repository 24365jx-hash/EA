# IDC_8 v3.13 — 전수 무결성 감사 보고서

**일시:** 2026-07-07  
**대상:** `IDC_8.mq4` `#property version "3.13"`  
**목적:** 원본 전략 100% 준수 + 로그·재현 버그 제거. 허위 PASS 금지.

---

## 1. v3.13 수정 항목 (코드 반영 완료)

| ID | 문제 | 증상/원인 | v3.13 수정 | 상태 |
|----|------|-----------|------------|------|
| B-25 | 관찰만료 후 사이클 잔류 | `Obs=X`인데 `Cyc=SELL` 유지 | `ExpireObservationWindow()` → `g_cycle=CYCLE_NONE` | **FIXED** |
| B-26 | 관찰만료 시 `ResetSetupState`만 호출 | 사이클 미해제 | Try*/ProcessSetupLogic/Replay 전부 `ExpireObservationWindow()` | **FIXED** |
| B-27 | `OnInit` 이중 부트스트랩 | Bootstrap + Pipeline 중복 호출 | `OnInit` → `ProcessClosedBarEntryPipeline()` 단일 경로 | **FIXED** |
| B-28 | `ProcessClosedBarEntryPipeline` 미정의 | 컴파일 불가 | 함수 추출 + `ProcessEntryLogicOnNewBar` 위임 | **FIXED** |
| B-29 | `OrderSend` 전 진입락 없음 | 동일 봉 이중 진입 위험 | `g_entry_taken=true` 선설정, 실패 시 rollback | **FIXED** |
| B-30 | Bootstrap 만료 크로스 수용 | obs 초과 크로스로 사이클 시작 | replay 후 `IsObservationWindowExpired()` → `BOOT\|SKIP` | **FIXED** |
| B-31 | 리플레이 크로스봉 누락 | `cross_shift-1`부터 시작 → 크로스봉 RSI 누락 | `cross_shift` ~ 2 포함 | **FIXED** |
| B-32 | `DetectEmaCross` 중복 리셋 | bootstrap 직후 동일 크로스로 `StartCycle` 재호출 | `g_cycle_start_time != cross_time` 가드 | **FIXED** |
| B-33 | `DetectEmaCross` DRY 위반 | 인라인 EMA 비교 중복 | `IsDeadCrossAtShift(1)` / `IsGoldenCrossAtShift(1)` | **FIXED** |
| B-34 | BOOT 없음 로그 부재 | 디버그 시 부트 실패 추적 불가 | `BOOT\|NONE` / `BOOT\|SKIP` | **FIXED** |

---

## 2. 원본 전략 1:1 매핑 (SELL 기준)

| # | 원본 조건 | 구현 함수 | v3.13 |
|---|----------|----------|-------|
| 1 | 데드크로스 (마감봉 엄격) | `IsDeadCrossAtShift` → `DetectEmaCrossOnClosedBar` / `Bootstrap` | **O** |
| 2 | 관찰 N봉 (크로스봉 포함) | `BarsSinceCycleStart`, `IsObservationWindowExpired` | **O** |
| 3 | RSI 52↑ → 48↓ (2봉 엄격 돌파) | `IsRsiBreakoutAbove/Below`, `ProcessSellRsiAtShift` | **O** |
| 4 | 9EMA 하향 돌파(`low<9EMA`) + 종가 아래 + 몸통>꼬리, 3봉 유예 | `IsSellEmaConfirm`, `InpEmaGraceBars`, `TrySellEntryAtShift` | **O** |
| 5 | 사이클 1회 진입 | `g_entry_taken`, `g_rsi_to_ema_used` | **O** |
| 6 | SELL 전용 | `g_cycle==CYCLE_SELL` 가드 | **O** |
| §8.1 | 9–50 EMA 이격 ≥ 100pt | `PassesEmaSeparationFilter` | **O** |
| §8.2 | EMA34 각도 (도) | `GetEma34AngleDeg`, `InpMinAngleDeg` | **O** |
| 진입 타이밍 | 셋업봉 마감 → 다음봉 첫 틱 | `IsNewBar` → shift1 처리; `OnInit` 즉시 1회 | **O** |

BUY: `ProcessBuyRsiAtShift`, `IsBuyEmaConfirm`, `IsGoldenCrossAtShift` — SELL 대칭 **O**

---

## 3. 파라미터 (23개) 전수 배선

| 파라미터 | 사용처 | 배선 |
|----------|--------|------|
| InpAutoDetectGold / InpManualSymbol | DetectGoldSymbol | **O** |
| InpFastEmaPeriod / InpSlowEmaPeriod | GetEmaPair, GetFastEma | **O** |
| InpRsiPeriod / InpRsiUpper / InpRsiLower | GetRsiPair, RSI 돌파 | **O** |
| InpObservationBars | RemainingObservationBars, FindMostRecentCrossShift | **O** |
| InpEmaGraceBars | BeginWaitEmaPhaseAtShift, IsEmaGraceWindowExpired | **O** |
| InpUseEmaSepFilter / InpMinEmaSepPts | PassesEmaSeparationFilter | **O** |
| InpUseEmaAngleFilter / InpAngleEmaPeriod / InpAngleLookback / InpMinAngleDeg | PassesEmaAngleFilter | **O** |
| InpLots / InpStopLossPoints / InpTrailingStartPts / InpTrailingStepPts | OrderSend, ManageTrailingStop | **O** |
| InpMagicNumber / InpSlippagePts / InpTradeComment | OrderSend, IsOurOrderTicket | **O** |
| InpDebugBarLog | LogBarFilterStatus, BOOT/ENTRY 로그 | **O** |

`ValidateInputs()` — 전 파라미터 범위 검증 **O**

---

## 4. 상태기계 검증

```
CYCLE_NONE ──(cross)──► CYCLE_SELL/BUY
       ▲                      │
       │ obs만료              │ RSI arm → WAIT_EMA → (EMA확인) → ENTRY
       │ ExpireObservation    │ grace만료 → EXHAUSTED
       └──────────────────────┘ entry_taken → 사이클 내 재진입 차단
```

| 전이 | 트리거 | 함수 | v3.13 |
|------|--------|------|-------|
| NONE→SELL/BUY | 마감봉 크로스 | StartCycle | **O** |
| NONE→SELL/BUY | 재부착 bootstrap | BootstrapCycleFromHistory | **O** |
| *→NONE | 관찰 N봉 초과 | ExpireObservationWindow | **O** (v3.12 X) |
| WAIT_EMA→EXHAUSTED | grace 소진 | ExpireEmaGraceWindow | **O** |
| WAIT_EMA→ENTRY | EMA+필터 통과 | OpenPositionAtSetupClose | **O** |

---

## 5. 로그 형식 (InpDebugBarLog=true)

| 태그 | 의미 | 시점 |
|------|------|------|
| `BOOT\|NONE` | N봉 내 크로스 없음 | init/새봉 |
| `BOOT\|SKIP` | 크로스 있으나 obs 만료 | bootstrap |
| `BOOT\|SELL/BUY` | bootstrap 성공 | bootstrap |
| `BAR\|...` | 필터 O/X 스냅샷 | RSI처리 후, TryEntry **전** |
| `ENTRY\|DONE` | 체결 완료 | OrderSend 성공 후 |
| `SKIP\|open position` | 포지션 존재 시 파이프라인 스킵 | pipeline |

**v3.10 이전 버그(수정됨):** TryEntry 후 `ResetSetupState` → `SetupOK=X` 오표시. v3.13은 LogBarFilterStatus가 TryEntry **이전** 호출.

---

## 6. 미해결 / 환경 의존 (허위 PASS 아님)

| ID | 항목 | 설명 | 심각도 |
|----|------|------|--------|
| E-01 | MT4 컴파일 | 본 환경에 MetaEditor 없음 — 사용자 재컴파일 필수 | 확인 필요 |
| E-02 | `CalcGraceBarsForTrigger()` | 정의만 있고 미호출 (dead code) | 낮음 |
| E-03 | 슬리피지 가드 | `IsEntrySlippageAcceptable` — 시장가가 셋업종가 대비 `InpSlippagePts` 초과 시 진입 스킵 | 설계 의도 |
| E-04 | 브로커 STOPLEVEL | `ClampStopLossForBroker` — 브로커별 SL 거리 조정 | 환경 의존 |
| E-05 | shift1=현재 미확정봉 아님 | 새봉 첫 틱에서 shift1=방금 마감봉 (원본 전략 일치) | 정상 |
| E-06 | 자동 백테스트 없음 | Strategy Tester 결과 미검증 | 확인 필요 |

---

## 7. v3.08 / v3.10 폐기 항목 재확인 (재도입 없음)

| 폐기 내용 | v3.13 상태 |
|----------|-----------|
| `g_rsi_seen_*` 틱 RSI | **없음** ✓ |
| 종가만 RSI (low/high 무시) | **없음** — `IsRsiBreakout*` 마감 RSI ✓ |
| 9EMA `low` 돌파 제거 | **없음** — `IsSellEmaBreakthrough` `low<fast_ema` ✓ |
| ATR 배수 각도 파라미터 | **없음** — `InpMinAngleDeg` 도(°) ✓ |

---

## 8. 사용자 검증 체크리스트

1. MetaEditor에서 `IDC_8.mq4` v3.13 **재컴파일** (0 error)
2. XAUUSD M1 차트 부착, `InpDebugBarLog=true`
3. 재부착 시 `BOOT|SELL` 또는 `BOOT|BUY` 확인 (02:15형 Cyc=NONE 재발 없어야 함)
4. 관찰만료 후 `Cyc=NONE` 확인 (`Obs=X` + `Cyc=SELL` 잔류 없어야 함)
5. 진입 시 `ENTRY|DONE` 1회만 출력
6. 05:21형 횡보 — `Ang34=X` (각도 필터 차단) 확인

---

## 9. 종합 판정

| 구분 | 판정 |
|------|------|
| 정적 코드 감사 (원본전략 매핑) | **PASS** |
| v3.12 알려진 버그 (B-25~B-34) | **FIXED** |
| MT4 런타임/백테스트 | **미검증** (E-01, E-06) |
| 무결성 완전본 제출 | **조건부 PASS** — 사용자 재컴파일·로그 검증 후 최종 확정 |
