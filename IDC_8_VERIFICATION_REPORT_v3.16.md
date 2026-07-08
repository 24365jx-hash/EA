# IDC_8 v3.16 — 원본전략 100% 점검 (한줄한점)

판정 기준: 1점이라도 X → **전체 탈락** / MT4 런타임 미검증 항목 별도 표기

---

1. 데드크로스(9/50) 마감봉 엄격 — `IsDeadCrossAtShift` — **O**
2. 골든크로스(9/50) 마감봉 엄격 — `IsGoldenCrossAtShift` — **O**
3. 관찰 N봉(크로스봉 포함) — `RemainingObservationBars` — **O**
4. 관찰만료 시 사이클 NONE — `ExpireObservationWindow` — **O**
5. RSI 상향돌파 prev≤기준 AND curr>기준 — `IsRsiBreakoutAbove` — **O**
6. RSI 하향돌파 prev≥기준 AND curr<기준 — `IsRsiBreakoutBelow` — **O**
7. RSI 터치/체류 무효 — 2봉 돌파만 — **O**
8. SELL RSI 52↑→48↓ 순서 — `ProcessSellRsiAtShift` — **O**
9. BUY RSI 48↓→52↑ 순서 — `ProcessBuyRsiAtShift` — **O**
10. SELL 9EMA low<9EMA 돌파 — `IsSellEmaBreakthrough` — **O**
11. SELL 9EMA 종가 아래 — `IsSellEmaCloseBelow` — **O**
12. BUY 9EMA high>9EMA 돌파 — `IsBuyEmaBreakthrough` — **O**
13. BUY 9EMA 종가 위 — `IsBuyEmaCloseAbove` — **O**
14. 몸통>꼬리 — `IsBodyDominant` — **O**
15. 유예 3봉(RSI 2차돌파 봉 포함) — `InpEmaGraceBars` + `g_grace_remaining` — **O** (v3.16 수정)
16. 리플레이가 유예 소모 안 함 — `ReplayCycleStateSinceCross` RSI만 — **O** (v3.16 수정)
17. 이중 유예만료 제거 — `IsEmaGraceWindowExpired` 카운터만 — **O** (v3.16 수정)
18. 부트스트랩 유예 동기화 — `SyncGraceRemainingFromTrigger` — **O** (v3.16 수정)
19. 셋업봉(shift1) 9EMA+필터 충족 시 진입 — `TryBuy/TrySellEntryAtShift(1,true)` — **O**
20. RSI 2차돌파와 동봉 9EMA 진입 — ProcessRSI→TryEntry 동일봉 — **O**
21. 사이클 1회 진입 — `g_entry_taken` + `g_rsi_to_ema_used` — **O**
22. SELL/BUY 사이클 분리 — `g_cycle` 가드 — **O**
23. §8 EMA 이격 필터 — `PassesEmaSeparationFilter` — **O**
24. §8 EMA34 각도(도) — `GetEma34AngleDeg` + `InpMinAngleDeg` — **O**
25. SL 셋업 종가 기준 — `BuildInitialSL(setup_close)` — **O**
26. TP 없음 — OrderSend TP=0 — **O**
27. SL=0 금지 — `ValidateInputs` + `ProtectAllPositionsStopLoss` — **O**
28. 트레일링 — `ManageTrailingStop` — **O**
29. 셋업봉 마감→다음봉 첫틱 — `IsNewBar` + shift1 — **O**
30. EA 재부착 사이클 복원 — `BootstrapCycleFromHistory` — **O**

---

## 탈락 항목 (100% 아님)

31. MT4 실제 컴파일·체결 — 본 환경 미검증 — **확인필요**
32. `InpSlippagePts` 초과 시 진입 스킵 — 전략문서 미명시, 코드 존재 — **확인필요**

---

## v3.16 수정 요약

- 리플레이: `TryEntry` 제거 → RSI 상태만 복원
- 유예: `BarsSinceRsiTrigger` 이중만료 삭제
- 부트스트랩: `SyncGraceRemainingFromTrigger`로 shift1 기준 남은 유예 계산
- 대시보드: RSI "돌파" 표기, EXHAUSTED 차단사유 표시

---

## 종합

| 구분 | 판정 |
|------|------|
| 원본전략 정적매핑 1~30 | **PASS** |
| MT4 런타임 31~32 | **미검증** |
| 100% 완전판정 | **조건부** — 재컴파일·실차트 1회 확인 후 확정 |
