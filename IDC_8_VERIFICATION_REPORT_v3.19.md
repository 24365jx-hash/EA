# IDC_8 v3.19 — 원본전략 100% (정적)

## v3.19 수정 (셋업봉 미진입 버그)

| 버그 | 수정 |
|------|------|
| RSI 스캔이 **첫** 52↑/48↓만 사용 | **최신** 48↓ + 직전 52↑ 스캔 |
| 유예 `SyncGrace` shift1=1일 때 grace=1 | `3-(trigger_shift-1)` 정상 3봉 |
| 증분 RSI만 처리 → arm/48↓ 누락 | 매봉 `SyncRsiStateFromHistory` |
| 크로스봉 RSI 미복원 | `DetectEmaCross` 후 `ReplayCycleStateSinceCross(1)` |
| 대시보드 RSI shift1만 표시 | arm/trigger 봉 재검증 표시 |

## 정적 매핑

원본 SELL/BUY 6항목 + §8 + 손익 + 진입타이밍 + 원본外 게이트 없음 = **PASS**

(컴파일·데모 제외)
