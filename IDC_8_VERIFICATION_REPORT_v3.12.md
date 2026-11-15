# IDC_8 v3.12 — 전수 검증 보고 (Cyc=NONE 수정)

## 핵심 수정: B-CYCLE-BOOT

| 문제 | 로그 증거 | v3.12 수정 |
|------|----------|-----------|
| EA 재부착 후 `Cyc=NONE` | `02:15\|Cyc=NONE\|Ph=IDLE` | `BootstrapCycleFromHistory()` |
| 데드크로스 이후 부착해도 사이클 없음 | RSI/EMA `--` | N봉 내 최근 크로스 스캔 + 상태 리플레이 |
| 포지션 있는데 재진입 | — | `SyncEntryTakenFromOpenPosition()` |

## Bootstrap 흐름

1. `FindMostRecentCrossShift` — shift 1~N 최근 데드/골든 크로스
2. `StartCycle(SELL/BUY, cross_time)`
3. `ReplayCycleStateSinceCross` — 크로스+1 ~ shift2 RSI·유예 리플레이
4. 현재 봉(shift1) — 정상 `ProcessSetupLogic`

## 원본전략 1:1 (진입조건)

| SELL | 코드 | v3.12 |
|------|------|-------|
| 데드크로스 | `DetectEmaCross` + `Bootstrap` | **O** |
| N봉 | `IsObservationWindowExpired` | **O** |
| RSI 52↑→48↓ | `ProcessSellRsiAtShift` | **O** |
| 9EMA 돌파+종가+몸통 | `IsSellEmaConfirm` | **O** |
| §8 필터 | `PassesRangeFilters` | **O** |
| 셋업 마감 진입 | `TrySellEntryAtShift(1,true)` | **O** |

## 정적 검증: PASS
