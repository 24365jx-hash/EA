# IDC_3 v1.07 — 정밀 전수 매핑 검수 (락)

- EA: `MQL4/Experts/IDC_3.mq4` `#property version "1.07"`
- 전략서: `docs/IDC_3_전략서.md` v1.07
- 논리테스트: `python3 simulation/idc3_logic_test.py` → **PASS**
- MT4 MetaEditor 컴파일 / 틱테스터 / 실차트: **미실행** (허위 성공 보고 금지)
- 검수 기준일: 2026-08-03

---

## 0. 이전 감사문서 허위·은폐 색출 (항목 3)

| 문서 | 문제 | 판정 |
|------|------|------|
| `docs/IDC_3_MAPPING_AUDIT.md` (구 v1.04판) | 돌파봉을 **몸통>심지합**이 “명령 일치/OK”로 기록 | **허위보고** — 사용자 원본은 `body>upper AND body>lower`만. 합 비교는 v1.04 **과필터 버그** |
| 동일 | version을 1.04로 고정한 채 최신으로 제출 가능 상태 | **형식적/낡은 검수** |
| 동일 | “현재 불복종 0 / 몸통 각심지만 잔존 없음(합 조건 있음)” | **명령 역전 서술** — 합 조건이 있으면 오히려 불복종 |

본 문서는 v1.07 코드 기준으로 **전량 재작성**. 구판의 “합 조건 OK” 서술은 **폐기**.

---

## 10. 트레일링 작동 확인 (최우선 · 사용자 절대명령)

### 명령 원문
> Start 200: 진입점으로부터 200pt 되는 즉시 SL → **진입점으로부터 200pt 지점**  
> 이후 Step(예:10): **최초 이동한 200pt 지점부터** 10pt 간격 추격

### 코드 (`ManageTrailing`)

| 단계 | 식 | 줄(대략) |
|------|-----|----------|
| 미달 | `profit_pts < InpTrailingStartPts` → return | L561 |
| steps | `floor((profit − Start) / Step)` | L564–566 |
| lock | `Start + steps * Step` | L568 |
| BUY SL | `Open + PtsPrice(lock_pts)` | L571–572 |
| SELL SL | `Open − PtsPrice(lock_pts)` | L573–574 |
| BE/진입가 이동 | **코드 없음** (`lock_from_be` 검색 0건) | — |

| profit | lock_pts | BUY SL | 명령 | 논리테스트 | 판정 |
|--------|----------|--------|------|------------|------|
| 199 | (미발동) | 초기 SL | 유지 | PASS | **OK** |
| 200 | **200** | Open+200 | 진입±200 즉시 | PASS | **OK** |
| 209 | 200 | Open+200 | 200 유지 | PASS | **OK** |
| 210 | **210** | Open+210 | 200지점+10 | PASS | **OK** |
| 220 | **220** | Open+220 | +20 | PASS | **OK** |
| 231 | **230** | Open+230 | floor | PASS | **OK** |
| 200 | ≠0 | — | BE 금지 | PASS (`!=0`) | **OK** |

### 이번 검수에서 색출·수정한 트레일 관련 결함 (땜빵/미구현 아님 — 실버그)

| 결함 | 증상 | 조치 (v1.07) | 판정 |
|------|------|--------------|------|
| EA 재시작 시 `g_trail_armed=false` 강제 | Guardian G05가 수익측 SL(예: Open+200)을 **손실측으로 widen** 가능 | `DetectTrailAlreadyLocked` + `IsProfitSideSL`로 수익측 SL이면 widen 금지 | **수정함** (이전 은폐 금지: v1.06까지 존재) |

브로커 StopLevel로 `desired_sl`이 clamp되면 lock보다 덜 조여질 수 있음 → **브로커 제약**, 명령식 자체 불일치 아님. MT4 실기 미검증.

**항목10 판정: 명령식 일치 (코드). 실차트 틱검증은 미실시.**

---

## 11. 돌파캔들 조건 확인

| 조건 | 원본 | 코드 | 줄(대략) | 판정 |
|------|------|------|----------|------|
| BUY 종가 돌파 | `C3 > H2` | `IsCloseBreakBuy` | L403–406 | **OK** |
| SELL 종가 돌파 | `C3 < L2` | `IsCloseBreakSell` | L409–411 | **OK** |
| 심지만 BUY | `H3>H2 && C3<=H2` → CANCEL | `wick_only_buy` | L338–349 | **OK** |
| 심지만 SELL | `L3<L2 && C3>=L2` → CANCEL | `wick_only_sell` | 동상 | **OK** |
| 미돌파 | 종가 미돌파 → 셋업 취소 | `CANCEL no CLOSE break` | L351–357 | **OK** |
| 몸통 > 위심지 | `body > upper` | `body <= upper` → fail | L425–426 | **OK** |
| 몸통 > 아래심지 | `body > lower` | `body <= lower` → fail | L427–428 | **OK** |
| 몸통 > 심지**합** | **금지** | `upper+lower` 검색 **0건** | — | **OK (미포함)** |
| OrderSend 직전 재검증 | 우회 금지 | Close + body 재확인 | L439–468 | **OK** |
| High/Low로 방향결정 | 금지 | Close만 | — | **OK** |
| 캔들 색 | 무관 | O/C 색분기 **없음** | — | **OK** |

예: O100 H140 L88 C125 → body25 / up15 / dn12  
- 각심지: PASS → **진입 허용 (현행)**  
- 합(27): FAIL → **v1.04는 여기서 차단 = 버그** (논리테스트가 sum 거부 증명)

**항목11 판정: 종가돌파 + body>each만. 합 비교 없음.**

---

## 1. 원본전략 ↔ 코드 전수 매핑 (항목단위)

| ID | 규칙 | 구현 위치 | 판정 |
|----|------|-----------|------|
| TF | M1 only | `OnInit` Period!=M1 → INIT_FAILED | **OK** |
| SYM | Gold | `ResolveSymbol` / `IsGoldSymbol` | **OK** |
| R01 | `H2 < H1 && L2 > L1` 엄격(터치 불가) | `is_inside` L323 | **OK** |
| R01색 | #1/#2 색 무관 | 색 if 없음; O1/C1/O2/C2 진입식 미사용 | **OK** |
| R02 | R01 실패 시 중단 | `no inside bar` return | **OK** |
| R03 | #2 종가 돌파만 | `IsCloseBreak*` | **OK** |
| R03b | wick-only 무효 | CANCEL + Print | **OK** |
| R03c | body>upper AND body>lower | `IsBodyLargerThanWicks` | **OK** |
| R03c-금 | 합 비교 금지 | 합식 0건 | **OK** |
| R04 | #3만 / 미돌파 취소 / #4대기 없음 | shift1만 트리거; CANCEL; 대기 큐 없음 | **OK** |
| R05 | 1포지션 | `CountOurPositions` OnTick/OpenMarket | **OK** |
| R06-TP | TP=0 | `OrderSend(..., sl, 0, ...)` | **OK** |
| R06-SL | 초기 SL points | `InpStopLossPoints` + `EffectiveSLPts` | **OK** |
| R06-Trail | Start잠금+Step추격 | `lock_pts=Start+steps*Step` | **OK** |
| IDX | #1=shift3 #2=2 #3=1 | `ReadBarOHLC(1/2/3)` → o3/o2/o1 | **OK** |
| VIS | #1파랑/#2빨강 + 커스텀 | `InpLine1*` `InpLine2*` | **OK** |
| VIS-구간 | #1시각~#3시각, RAY_LEFT=false | `DrawLevelSegment` | **OK** |
| OHLC동기 | 차트 심볼이면 Time/O/H/L/C[] | `ReadBarOHLC` | **OK** |

---

## 2. UI-only / 기능없는 파라미터 전수 (항목 2)

입력 선언 **40개** 전수 참조 카운트:

| 분류 | 수량 | 목록 | 판정 |
|------|------|------|------|
| 섹션 라벨(의도적 UI 그룹) | 7 | `InpSecSym/Risk/Lot/Guard/Session/Lines/Sys` refs=1(선언만) | **위장 아님** |
| 기능 연결 | 33 | 나머지 전부 refs≥2 | **OK** |
| **위장(기능없음)** | **0** | — | **0건** |

가디언 OFF 시 `InpMaxSpreadPts` / `InpSpreadBufferPts` / `InpSLPadPts` 비활성 = 마스터 스위치 설계 (기능 사칭 아님).

`InpDebugLog`: 트레일 성공 Print 게이트만 — **기능 있음** (실패 Print는 항상).

---

## 3. 허위보고·은폐 색출 (항목 3)

| 검사 | 결과 |
|------|------|
| 구 감사문서 body>합=정상 | **허위로 색출·폐기** (본 문서 §0) |
| BE 트레일 잔존 | **없음** |
| body>합 잔존 | **없음** (0건) |
| inside 터치허용(`<=`/`>=`) 잔존 | **없음** (엄격 `<`/`>`) |
| TP 위장 | 없음 (항상 0) |
| 컴파일/실기 성공 허위 | **보고 안 함** |
| v1.06 Guardian 재시작 위험 | **은폐 안 함 → v1.07 수정** |

### 불복종·오제작 이력 (은폐 금지)

1. 트레일 BE(진입가) 해석 → v1.04에서 Start 잠금으로 교정  
2. body>합 과필터 → v1.05/1.06에서 제거 (원본=각 심지만)  
3. inside 터치 허용 시도(v1.05) → v1.06 엄격 복귀  
4. EA재시작 시 트레일 SL Guardian widen 위험 → **v1.07 수정**

**현재 코드 기준 불복종: 0건** (정적 매핑). MT4 실기 미검증은 한계로 별도 표기.

---

## 4. 사용자 명령 복종 체크리스트 (항목 4)

| 명령 | 상태 |
|------|------|
| #1파랑/#2빨강 기본 + 색·선 커스텀 | **복종** |
| #1·#2·돌파 방향 캔들색 무관 | **복종** |
| 종가 돌파만 / wick-only 차단 | **복종** |
| 몸통 > 위심지 AND > 아래심지 (합 금지) | **복종** |
| 인사이드 엄격(터치 불가) | **복종** |
| 라인 #1~#3만 (#1 이전 미표시) | **복종** |
| 트레일 @Start→진입±Start, 이후 Step | **복종** |
| 허위/요약만 검수 제출 금지 | 본 문서 항목단위 |

---

## 5–9. 형식·땜빵·미구현·줄단위

| 검사 | 판정 |
|------|------|
| OrderSend 경로 미구현 | 없음 (재검증 후 송신) |
| 패널만 있고 필터 없음 | 없음 (Evaluate+OpenMarket 실차단) |
| 주석만 고치고 식 미변경 | 없음 (`lock_pts`/`IsBodyLargerThanWicks` 실코드) |
| 시간변수 t1/t3 혼동 | **색출**: 구코드는 shift1 시각을 `t1`에 넣음(이름 혼란). v1.07에서 `t_trigger/t_inside/t_mother`로 명명 교정 — **동작은 구버전 DrawSetupHL 인자 매핑도 정상이었음** |
| 패널 OHLC 덤프 | #1/#2/#3 전체 OHLC 표시 (디버그용, 로직 변경 아님) |

---

## 입력 ↔ 사용처 1:1 (기능 33)

| Input | 사용 |
|-------|------|
| InpAutoDetectGold | ResolveSymbol |
| InpManualSymbol | ResolveSymbol |
| InpStopLossPoints | OnInit / EffectiveSLPts / Panel |
| InpTrailingStartPts | ManageTrailing / OnInit / Panel |
| InpTrailingStepPts | ManageTrailing / OnInit / Panel |
| InpUseAutoLot | CalcLot / Panel |
| InpFixedLot | CalcLot |
| InpRiskPercent | CalcLot / OnInit |
| InpMaxLot | NormalizeVolume / OnInit |
| InpUseSLGuardian | OnTick / Evaluate / OpenMarket / Trail / EffectiveSLPts |
| InpMaxSpreadPts | Evaluate 진입 스프레드 게이트 |
| InpSpreadBufferPts | EffectiveSLPts |
| InpSLPadPts | OpenMarket / Trail / Guardian / EffectiveSLPts |
| InpUseTimeFilter | IsWithinTradingHours |
| InpStart/End Hour/Minute GMT | BrokerFromGmtHMS |
| InpCloseOutsideHrs | OnTick 포지션 청산 |
| InpDailyLossPercent | UpdateDayState |
| InpStopOnDailyLoss | Evaluate 진입 차단 |
| InpCloseOnDailyLoss | OnTick 청산 |
| InpDrawSetupLines | Evaluate draw/delete |
| InpLine1/2 Color/Style | DrawSetupHL |
| InpLineWidth | DrawSetupHL / OnInit |
| InpMagic | IsOurSelected / OrderSend |
| InpSlippagePts | SlippageRaw |
| InpTradeComment | OrderSend |
| InpShowPanel | DrawPanel |
| InpDebugLog | Trail 성공 Print |

---

## 한계 (은폐 금지)

1. 초기 SL 기본값 500 — 원문 수치 없음 (운용 기본값)  
2. **MT4 .ex4 재컴파일·실기 트레일/돌파 틱검증 미실시** → 차트는 **반드시 v1.07 재컴파일**  
3. 본 환경 MetaEditor 없음  
4. Guardian clamp / 스프레드로 lock 거리 축소 가능 (브로커)

---

## 최종 판정

| 항목 | 판정 |
|------|------|
| 1 원본전략 매핑 | **정적 100% (v1.07)** |
| 2 UI-only 위장 | **0** |
| 3 허위·은폐 | 구감사 body>합 허위 **색출**; Guardian재시작 위험 **색출·수정** |
| 4 현재 불복종 | **0** (정적) |
| 5–9 형식/땜빵 | 명명혼동·재시작버그 색출 후 교정 |
| 10 트레일 | **명령식 일치** + 재시작 안전 보강 |
| 11 돌파캔들 | **종가 + body>each (합 없음)** |
| MT4 실기 | **미검증** |
