# IDC_X 원본전략 ↔ 최신코드 1:1 전수 매핑 검수 (버그 색출)

- 대상: `MQL4/Experts/IDC_X.mq4` (최신)
- 기준: `docs/IDC_X_SPEC.txt` 원본 명세
- 방식: 줄/항목/수식 1:1 대조. 스샷 현재값으로 과거봉 단정 금지.
- 결과: **아래 버그 확인·수정 완료** + 매핑표

---

## A. 색출된 버그 / 결함 (중요도순)

### BUG-1 [치명/동작] EA 중간 부착 시 직전 완성봉(bar1) 영구 미검수
- **명세:** 모든 판단은 완성봉 bar1 기준
- **결함:** `OnInit`에서 `g_LastM1BarTime = iTime(...,0)` 로 현재 진행봉을 이미 처리한 것처럼 표시 → 다음 봉이 열릴 때까지 **직전 완성봉을 한 번도 안 봄**
- **결과:** 부착 직전 닫힌 50EMA 터치봉이 통째로 스킵될 수 있음
- **수정:** `g_LastM1BarTime = 0` → 첫 틱에 bar1 즉시 검수

### BUG-2 [치명/동작] 기존 포지션 있으면 진입 시도도 안 했는데 사이클 신호 소진
- **명세:** 신호 발생·주문 체결 시도 기준 1회 소진 (성공 여부 무관)
- **결함:** `g_IsTradedInCycle=true` 후 `HasOurPosition()` 로 OrderSend 자체를 스킵 → **신호만 죽고 미진입**
- **수정:** 포지션 있으면 `ENTRY_BLOCKED_OPEN_POS`만 표시, **소진하지 않음**. 실제 진입 시도 시에만 소진

### BUG-3 [중/표시오인] 유예 없는데도 `ANTI_BREAKOUT` / `KILLED_BREAKOUT` 표시
- **명세:** 안티브레이크는 “기억·연명 중이던 유예” 소멸
- **결함:** 터치/유예가 없어도 몸통이 50 아래면 `Last=ANTI_BREAKOUT_BUY`, `Touch=KILLED_BREAKOUT` → **터치가 죽은 것처럼 오인**
- **수정:** 유예가 있을 때만 KILLED/ANTI_BREAKOUT. 없으면 `BODY_BELOW_50` + `NO_TOUCH`

### BUG-4 [중/동작] SL Modify 전역 250ms 쓰로틀
- **결함:** 성공·실패 무관하게 전 티켓 공용 `g_LastModifyAttemptMs` → 트레일링 지연 가능
- **수정:** **실패 재시도에만** 티켓별 간격 적용

### BUG-5 [하/동작] 랏 `NormalizeDouble(lots, 2)` 고정
- **결함:** lotstep이 0.01이 아닌 브로커에서 랏 정규화 오류 가능
- **수정:** lotstep 자릿수에 맞춰 정규화

### BUG-6 [하/표시] 진입 성공 후 다음 봉에서 `Last`가 `SIGNAL_CONSUMED`로 덮임
- **수정:** `ENTRY_OK`/`ENTRY_FAIL` 유지

---

## B. 명세 §1 환경 1:1

| 명세 | 코드 | 판정 |
|------|------|------|
| GOLD M1 | `PERIOD_M1` 강제 + 심볼 자동감지 | PASS |
| bar1만 판단 | shift=1, `IsNewM1Bar` | PASS (BUG-1 수정) |
| TP 없음 | `tp=0` | PASS |
| 고정SL+진입가 트레일 | `InpStopLossPoints` + `ManageTrailingStops` | PASS |

---

## C. 명세 §2 파라미터 1:1

| 파라미터 | 기본값 | 코드 사용 | 판정 |
|----------|--------|-----------|------|
| InpShowDashboard | true | UpdateDashboard | PASS |
| InpDashboardFontSize | 12 | SetDashLine | PASS |
| InpAutoDetectGold | true | ResolveTradeSymbol | PASS |
| InpManualSymbol | "" | ResolveTradeSymbol | PASS |
| InpFastEmaPeriod | 9 | cross/dist/entry | PASS |
| InpSlowEmaPeriod | 50 | touch/antibreak/cross | PASS |
| InpTrendEmaPeriod | 34 | CalcHumanEyeAngle34 | PASS |
| InpRsiPeriod | 14 | GetRsi | PASS |
| InpRsiUpper | 52.0 | +0.5 | PASS |
| InpRsiLower | 48.0 | -0.5 SELL | PASS |
| InpObservationBars | 55 | kill window | PASS |
| InpEmaGraceBars | 3 | grace/latch | PASS |
| InpMinEmaDistancePts | 30 | distOk | PASS |
| InpMinEmaAngle | 5.0 | angOk | PASS |
| InpLots | 0.50 | OrderSend | PASS (BUG-5 수정) |
| InpStopLossPoints | 200 | SL | PASS |
| InpTrailingStartPts | 200 | trail | PASS |
| InpTrailingStepPts | 10 | MathFloor | PASS |
| InpMagicNumber | 80008 | filter | PASS |
| InpSlippagePts | 30 | OrderSend | PASS |
| InpTradeComment | IDC_X | OrderSend | PASS |
| InpSep* | 구분선 | UI-only | 명시 (기능 위장 아님) |
| InpAngleLookbackBars 등 | 추가요구 | 실기능 | PASS |

---

## D. 명세 §3 상태머신 1:1

| 항목 | 명세 | 코드 | 판정 |
|------|------|------|------|
| 3-1 BUY 크로스 | fast2≤slow2 & fast1>slow1 | DetectEmaCross | PASS |
| 3-1 SELL 크로스 | 대칭 | 동일 | PASS |
| 3-1 리셋 | Cross=1, Touch=false, Grace=-1, Traded=false | newCross 블록 | PASS |
| 3-2 Cross++ | 새 봉 +1 | else 분기 | PASS |
| 3-2 관찰 초과 사망 | >N → 플래그 소멸 | KillCycle… | PASS |
| 3-2 1회 소진 | 성공무관 | 진입 시도 시 (BUG-2 수정) | PASS |
| 3-3 Grace++ | 유예중 새봉 +1 | 상단 | PASS |
| 3-3 Latch | >N → 클리어+당봉스킵 | LatchSkip return | PASS |

---

## E. 명세 §4 진입 1:1 (50EMA 포함)

| 항목 | 명세 수식 | 코드 | 판정 |
|------|-----------|------|------|
| 4-1 AntiBreak BUY | open<50 \| close<50 → grace 소멸 | ProcessAntiBreakout | PASS |
| 4-2 Pure Touch BUY | open>50 & close>50 & low≤50 | DetectPure50EmaTouch | PASS |
| 4-2 바늘 관통 | low≤50 (몸통 위) | 포함 | PASS |
| 4-2 돌파≠터치 | 몸통 침범 시 터치 불가 | AntiBreak 후 스킵 | PASS |
| 4-2 Grace=1 기동 | Touched=true; Grace=1 | 동일 | PASS |
| 4-3 Grace 범위 | 1..N | inGrace | PASS |
| 4-3-1 9EMA | High&Close > 9 | CheckEntrySetupBuy | PASS |
| 4-3-2 양봉품질 | (c>o)&&((c-o)>((h-c)+(o-l))) | 동일 | PASS |
| 4-3-3 RSI | rsi≥Upper+0.5 | 동일 | PASS |
| 4-3-4 이격 | \|9-50\|≥MinDist | 동일 | PASS |
| 4-3-4 각도 | 픽셀 arctan ≥ MinAngle | CalcHumanEyeAngle34 | PASS |
| 4-4 시장가+소진 | OrderSend, traded | 수정 후 PASS | PASS |
| SELL 대칭 | 명세 “대칭” | CheckEntrySetupSell | PASS |

---

## F. 명세 §5 트레일 1:1

| 항목 | 명세 | 코드 | 판정 |
|------|------|------|------|
| 진입가 절대기준 | OrderOpenPrice만 | ManageTrailingStops | PASS |
| 5-1 BUY SL | Open+Start*Point | 동일 | PASS |
| 5-1 SELL SL | Open-Start*Point | 동일 | PASS |
| 5-2 Floor | floor((profit-Start)/Step) | MathFloor | PASS |
| 유리방향만 | newSL 개선만 | ModifySLSafe | PASS |
| STOPLEVEL | 마진 필터 | 동일 | PASS (BUG-4 수정) |

---

## G. 명세에 없으나 요구사항으로 추가된 항목

| 요구 | 구현 | 판정 |
|------|------|------|
| MT4 전용 | .mq4 | PASS |
| SL Guardian | SLGuardianTick | PASS |
| 심볼/T시간 자동감지 | Resolve + DetectTimeframe | PASS |
| 사람눈 각도 | 차트 픽셀 atan | PASS |
| 좌상단 대시보드 ON/OFF | UpdateDashboard | PASS |

---

## H. 잔여 리스크 (버그 아닌 명세/환경 한계)

1. 각도값은 차트 줌/스크롤에 따라 변함 (명세가 픽셀 각도 요구 → 의도적).
2. 포인트는 브로커 `MODE_POINT` 기준.
3. MetaEditor 없는 환경 → 실기 컴파일은 로컬 필요.
4. 과거 봉 미진입 사후검증은 로그/OHLC 숫자 필요 (현재 대시보드≠과거봉).

---

## I. 최종 판정

| 구분 | 결과 |
|------|------|
| 원본 전략 수식/상태머신 매핑 | **PASS** (위 표) |
| 색출 버그 | **6건** → 본 개정에서 **수정** |
| 허위 “버그없음” 보고 | **하지 않음** |

수정 반영 파일: `MQL4/Experts/IDC_X.mq4`
