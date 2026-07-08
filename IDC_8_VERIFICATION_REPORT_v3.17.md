# IDC_8 v3.17 — RSI 돌파 락 (차트=눈)

## v3.17 핵심

1. `IsRsiBreakoutAboveAtShift` / `IsRsiBreakoutBelowAtShift` — 마감봉 shift별 차트 RSI와 동일 재검증
2. `VerifyRsiSequenceLocked` — 진입 직전 1차·2차 돌파 봉 **재계산** (플래그만 신뢰 금지)
3. `ScanSell/BuyRsiSequence` — 부트스트랩 시 돌파 봉만 스캔
4. `RebuildRsiStateFromHistory` — 리플레이 유예소모 제거, 스캔 기반 복원
5. `IsSetupEntryPermitted` — `VerifyRsiSequenceLocked` 필수

## RSI 락 판정

| 항목 | v3.17 |
|------|-------|
| SELL 52↑ 해당 봉 재검증 | **O** |
| SELL 48↓ 해당 봉 재검증 | **O** |
| BUY 48↓ 해당 봉 재검증 | **O** |
| BUY 52↑ 해당 봉 재검증 | **O** |
| 진입 시 플래그만으로 통과 | **X** (차단) |
| 차트 RSI(종가,마감봉) | **O** (`iRSI PRICE_CLOSE`) |

## 종합

정적 RSI 락: **PASS** / MT4 런타임: 사용자 재컴파일 확인
