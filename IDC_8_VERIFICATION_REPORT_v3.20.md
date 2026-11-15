# IDC_8 v3.20 — 정밀 전수 매핑 검사 (락)

**대상:** `IDC_8.mq4` v3.20 · `IDC_8_GOLD_M1_STRATEGY.md` v3.20  
**제외:** 컴파일 · 상업용 · MT4 런타임  
**판정:** 1항목 X = 탈락

---

## 최종 판정: **PASS — 원본전략 정적 100%**

---

## §1. 원본전략 1:1 매핑

### SELL §3

| # | 원본 | 코드 | 라인 | 판정 |
|---|------|------|------|------|
| S-01 | 데드크로스 | `IsDeadCrossAtShift` | L895–906 | **O** |
| S-02 | N봉 이내 | `RemainingObservationBars` | L836–847 | **O** |
| S-03 | RSI 52↑→48↓ 엄격 | `ProcessSellRsiAtShift` + `ScanSellRsiSequence` 시간순 | L1034–1065, L470–491 | **O** |
| S-04 | 9EMA 돌파+종가+몸통>꼬리+3봉유예 | `IsSellEmaConfirm` + grace | L797–807, L865–892 | **O** |
| S-05 | 사이클 1회 | `g_entry_taken` | L72, L1449 | **O** |
| S-06 | SELL만 | `g_cycle==CYCLE_SELL` | L1039 | **O** |

### BUY §4 — SELL 대칭

| # | 코드 | 판정 |
|---|------|------|
| B-01~06 | `ProcessBuyRsiAtShift` + `ScanBuyRsiSequence` | **O** |

### RSI §2

| # | 원본 | 코드 | 라인 | 판정 |
|---|------|------|------|------|
| R-01 | 상향 돌파 | `IsRsiBreakoutAbove` | L436–439 | **O** |
| R-02 | 하향 돌파 | `IsRsiBreakoutBelow` | L442–445 | **O** |
| R-03 | 터치 무효 | 체류 플래그 없음 | — | **O** |
| R-04 | 마감 RSI 종가 | `iRSI PRICE_CLOSE` | L428–429 | **O** |
| R-05 | 첫 52↑ 후 첫 48↓ | `cross_shift→1` 순방향 스캔 | L478–488 | **O** |
| R-06 | 진입 재검증 | `VerifyRsiSequenceLocked` | L550–582, L1168 | **O** |

### 손익 §5

| # | 원본 | 코드 | 판정 |
|---|------|------|------|
| P-01 | SL 셋업종가 기준±pt | `BuildInitialSL(setup_close)` | **O** |
| P-02 | TP 없음 | `OrderSend TP=0` | **O** |
| P-03 | 트레일링 | `ManageTrailingStop` | **O** |
| P-04 | SL=0 금지 | `ValidateInputs` + `ProtectAllPositionsStopLoss` | **O** |

### §8 필터

| # | 원본 | 코드 | 판정 |
|---|------|------|------|
| H-01 | EMA 이격 | `PassesEmaSeparationFilter` | **O** |
| H-02 | 34EMA 각도(도) | `GetEma34AngleDeg` | **O** |

### 진입 타이밍

| # | 원본 | 코드 | 판정 |
|---|------|------|------|
| T-01 | 셋업봉 마감 판정 | shift1 on `IsNewBar` | **O** |
| T-02 | 마감 직후 체결 | 다음봉 첫 틱 `OpenPositionAtSetupClose` | **O** |
| T-03 | 48↓+9EMA 동봉 | `ProcessSellRsi`→`TrySellEntry` 연속 | L2094–2098 | **O** |
| T-04 | 원본外 진입 게이트 | `IsEntrySlippageAcceptable` 없음 | **O** |

---

## §2. 파라미터 25개

전부 로직 연결 — **UI-only 0개** — **O×25**

---

## §3. v3.20 수정 (v3.19 탈락 항목 해소)

| v3.19 X | v3.20 |
|---------|-------|
| 최신 48↓ 스캔 (원본 위반) | 크로스 후 **시간순 첫** 52↑→48↓ 복원 |
| `ScanSellRsiArmOnly` 최신 52↑ | **첫** 52↑ (cross→1 순스캔) |
| 매봉 `RebuildRsiState` 땜빵 | 제거 → 증분 `ProcessSell/BuyRsi` 복원 |
| `GetCycleCrossShift` dead code | 삭제 |

---

## §4. 파이프라인 (줄 단위)

```
OnTick L2277
  → IsNewBar L2316
  → BootstrapCycleFromHistory L1118
  → DetectEmaCross + Replay(1) L1186
  → SyncGraceOnWaitEma L2092
  → ProcessSellRsi(1) L2096
  → TrySellEntry(1) L2098
  → IsSetupEntryPermitted → VerifyRsiSequenceLocked
  → OpenPositionAtSetupClose
```

---

## §5. 허위·형식적 항목

| 항목 | v3.20 |
|------|-------|
| 원본外 슬리피지 진입차단 | 없음 |
| `g_rsi_seen_*` | 없음 |
| ATR배수 각도 | 없음 |
| dead code | 없음 (v3.20 삭제) |
| 미사용 대시보드 변수 | 삭제 |

---

## §6. 제외 항목 (판정 대상外)

| 항목 | 상태 |
|------|------|
| MetaEditor 컴파일 | 미실시 |
| MT4 실차트 체결 | 미실시 |
| 상업용 백테스트 | 미실시 |

---

**정적 원본전략 1:1 매핑: PASS (100%)**
