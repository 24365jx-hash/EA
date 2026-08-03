# IDC_3 전수 매핑·정밀 검수 보고서

- EA: `MQL4/Experts/IDC_3.mq4` **v1.00** (838 lines)
- 전략서: `docs/IDC_3_전략서.md` v1.00
- 논리테스트: `simulation/idc3_logic_test.py` → **PASS (18)**
- 검수일: 2026-08-03
- MT4 컴파일: 본 환경에 MetaEditor 없음 → **정적+논리 검수** (허위 컴파일 성공 보고 없음)

---

## A. 원본 전략 ↔ 코드 1:1 매핑

| ID | 원본 규칙 | 코드 위치 | 구현식 | 결과 |
|----|-----------|-----------|--------|------|
| R01 | #2가 #1 high~low **완전 포함**, #2가 더 작음 | `EvaluateInsideBarSetup` L250 | `h2 < h1 && l2 > l1` (엄격 → range도 자동 작음) | **구현** |
| R01b | #1·#2 **캔들 색 무관** | 동일 함수 — open/close/색 미참조 | OHLC high/low만 사용 | **구현** |
| R02 | R01 미충족 시 중단 | L251–259 `return` | inside 아니면 signal NONE | **구현** |
| R03-BUY | #2 high **종가** 상향 돌파 → BUY | L265–266, L284 | `c3 > h2` | **구현** |
| R03-SELL | #2 low **종가** 하향 돌파 → SELL | L265–266, L284 | `c3 < l2` | **구현** |
| R03b | 꼬리만 돌파·종가 내부 → 무효 | L265–277 | close만 판정, wick는 진입 미사용 | **구현** |
| R04 | #3(직후 1봉) 미돌파 시 **취소**, 이후 봉 대기 없음 | L267–277; 신규봉마다 shift1·2·3만 평가 | CANCEL + return | **구현** |
| R05 | 포지션 중 추가진입 금지 | `OnTick` L155–169 early return; `Evaluate` L222–226; `OpenMarket` L302–303 | 동시 1포지션 | **구현** |
| R06-TP | TP 없음 | `OpenMarket` L350 `OrderSend(..., sl, 0, ...)` | TP=0 고정 | **구현** |
| R06-SL | 초기 SL | `EffectiveSLPts` + `OpenMarket` | `InpStopLossPoints` | **구현** |
| R06-Trail | 200pt → **본전(BE)**, 이후 step | `ManageTrailing` L388–396 | `lock_pts = steps*Step` (start 시 0=BE) | **구현** |
| VIS-1 | #1 위아래 = **파랑** | `DrawSetupHL` L782–783 | `clrDodgerBlue` | **구현** |
| VIS-2 | #2 위아래 = **빨강** | `DrawSetupHL` L785–786 | `clrRed` | **구현** |
| IDX | #1=모 / #2=인 / #3=트리거 | L242–246 | shift **3 / 2 / 1** | **구현** |
| TF | GOLD **M1** | `OnInit` L71–75, `OnTick` L147–148 | M1 아니면 INIT_FAILED | **구현** |

### 봉 매핑 (신규 M1 확정 시)

| 전략 | MT4 shift | 필드 |
|------|-----------|------|
| 캔들1 | 3 | H1,L1 (파란 라인) |
| 캔들2 | 2 | H2,L2 (빨간 라인 = 돌파 기준) |
| 캔들3 | 1 | C3 (종가 돌파) |

---

## B. 부가 기능 ↔ 코드

| 원본 하단 기능 | 코드 | 결과 |
|----------------|------|------|
| 단위 points | `NormalizedPoint`, 전 risk/trail 입력 points | **구현** |
| 브로커 심볼 자동 | `ResolveSymbol` / `IsGoldSymbol` / `InpAutoDetectGold` | **구현** |
| 브로커 타임존 | `RefreshGmtOffset`, 세션 GMT→브로커 변환 | **구현** |
| SL Guardian | `InpUseSLGuardian`, `GuardOpenPositionSL`, `EffectiveSLPts`, spread gate | **구현** |
| 수동/자동 랏 | `InpUseAutoLot` / `CalcLot` / `InpFixedLot` / `InpRiskPercent` | **구현** |
| 거래 시간 | `InpUseTimeFilter` + GMT start/end | **구현** |
| 일일 최대 손실% | `InpDailyLossPercent` + `UpdateDayState` | **구현** |
| Gold 기본 최적화 | SL500 / Trail200·10 / Guardian ON 등 | **기본값 반영** |

---

## C. 입력 파라미터 전수 (허위 UI 색출)

| 파라미터 | decl 외 참조 | 판정 |
|----------|-------------|------|
| `InpSecSym` | 0 | **섹션 라벨(의도)** — 로직 불필요 |
| `InpAutoDetectGold` | 1 | 기능 |
| `InpManualSymbol` | 3 | 기능 |
| `InpSecRisk` | 0 | 섹션 라벨 |
| `InpStopLossPoints` | 5 | 기능 |
| `InpTrailingStartPts` | 5 | 기능 |
| `InpTrailingStepPts` | 5 | 기능 |
| `InpSecLot` | 0 | 섹션 라벨 |
| `InpUseAutoLot` | 3 | 기능 |
| `InpFixedLot` | 4 | 기능 |
| `InpRiskPercent` | 3 | 기능 (Auto ON 시) |
| `InpMaxLot` | 3 | 기능 |
| `InpSecGuard` | 0 | 섹션 라벨 |
| `InpUseSLGuardian` | 6 | 기능 마스터 |
| `InpMaxSpreadPts` | 1 | 기능 (Guardian ON 시 진입 게이트) |
| `InpSpreadBufferPts` | 1 | 기능 (`EffectiveSLPts`에 가산) |
| `InpSLPadPts` | 5 | 기능 |
| `InpSecSession` | 0 | 섹션 라벨 |
| `InpUseTimeFilter` | 1 | 기능 |
| `InpStartHourGMT` | 1 | 기능 (필터 ON) |
| `InpStartMinuteGMT` | 1 | 기능 |
| `InpEndHourGMT` | 1 | 기능 |
| `InpEndMinuteGMT` | 1 | 기능 |
| `InpCloseOutsideHrs` | 1 | 기능 |
| `InpDailyLossPercent` | 2 | 기능 |
| `InpStopOnDailyLoss` | 1 | 기능 |
| `InpCloseOnDailyLoss` | 1 | 기능 |
| `InpSecSys` | 0 | 섹션 라벨 |
| `InpMagic` | 2 | 기능 |
| `InpSlippagePts` | 1 | 기능 (`SlippageRaw`→OrderSend) |
| `InpTradeComment` | 1 | 기능 |
| `InpShowPanel` | 1 | 기능 |
| `InpDrawSetupLines` | 2 | 기능 |
| `InpDebugLog` | 2 | 기능 |

**기능 없는 위장 파라미터: 0건**  
(섹션 문자열 6개는 MT4 입력창 그룹용 — 타 IDC EA와 동일 패턴, 기능 사칭 아님)

**Guardian OFF 시 비활성(설계):** `InpMaxSpreadPts`, `InpSpreadBufferPts`, `InpSLPadPts` — 마스터 스위치 종속. UI만 있는 것이 아니라 ON일 때 동작.

---

## D. 허위·은폐·형식 제작 색출

| 검사 | 결과 |
|------|------|
| OrderSend TP 숨김 고정값 외 위장 TP 파라미터 | **없음** (TP 입력 자체 없음) |
| 진입 조건에 없는 지표(EMA/RSI 등) 몰래 삽입 | **없음** |
| 인사이드 판정에 색/몸통 조건 추가 | **없음** |
| #3 이후 #4+ 대기(타임아웃 위반) | **없음** — 직후 1봉만 |
| 트레일을 “start만큼 잠금”으로 위장(본전 미이행) | **없음** — start 시 lock=0(BE) |
| 패널만 있고 미연결 스위치 | **없음** (전수 표 C) |
| 컴파일/백테스트 성공 허위 보고 | **하지 않음** (환경에 MT4 없음) |

---

## E. 사용자 명령 복종 검수

| 명령 | 상태 |
|------|------|
| #1 라인=파랑 / #2 라인=빨강 구분 | **복종** (`DrawSetupHL`) |
| #1·#2 캔들 컬러 무관 | **복종** (색 미사용) |
| 원본 100% 구현 | **복종** (표 A) |
| UI-only 색출 / 허위보고 금지 | **복종** (표 C·D) |
| 줄·항목 단위 전수 매핑 | **본 문서** |
| 대충 요약 검수 금지 | **본 문서 표 형식** |
| 전체본 업로드 후 검수 | EA+전략서+프리셋+테스트+본 감사 |

**불복종 항목: 0건**

---

## F. 명시적 한계 (은폐 금지)

1. **초기 SL 거리 수치**는 원본 이미지에 숫자 미기재 → 기본값 **500pt** (사용자 조정 가능). 트레일 예시 200/10만 원문에 명시되어 그대로 기본값.
2. **세션 시·분** 구체값은 원문 미기재 → 필터 기본 **OFF**, 기능은 구현.
3. 본 클라우드 환경에서 **.ex4 컴파일·틱 백테스트 미실행**. 논리 단위테스트 18항 PASS + 정적 매핑만 보증.
4. BE 본전 SL은 `OrderOpenPrice` 기준. 스프레드로 즉시 스탑될 수 있음(실거래 특성). Guardian이 StopLevel 내로 clamp.

---

## G. 논리 단위테스트 대응

| 테스트 | 대응 규칙 |
|--------|-----------|
| strict inside / equal H·L fail | R01 |
| SELL close\<L2 / BUY close\>H2 | R03 |
| close inside / touch = CANCEL | R03b·R04 |
| trail 200→0, 210→10, 220→20 | R06 |
| pos_count>0 block | R05 |

실행: `python3 simulation/idc3_logic_test.py` → `PASS: 18 logic assertions`

---

## H. 최종 판정

| 항목 | 판정 |
|------|------|
| 원본 진입·타임아웃·단일포지션·TP없음·BE트레일 | **100% 매핑** |
| 라인 색 #1파랑/#2빨강 · 캔들색 무시 | **100% 매핑** |
| UI-only 위장 파라미터 | **0건** |
| 허위/은폐/불복종 | **0건** |
| 땜빵·미구현 뼈대 | **0건** (핵심 경로 실함수 연결) |
| MT4 실기 컴파일 | **미검증(환경)** |

**제작 판정: 전략 스펙 대비 정적 완전본 제출. 실기 검증은 MT4 컴파일·테스터에서 확인 필요.**
