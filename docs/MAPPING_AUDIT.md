# IDC_Assistant — 정밀 전수 매핑 검수 보고

- 대상: `MQL4/Experts/IDC_Assistant.mq4`
- 원본 명세: `docs/IDC_Assistant_SPEC.txt` + 사용자 원문 요구(1~8항)
- 검수 원칙: 줄/항목/수식 단위 매핑, 허위·은폐·요약 검수 금지
- 컴파일: 본 환경에 MetaEditor/MT4 없음 → **실기 컴파일 미실시(사실 보고)**
- 수식 시뮬: Python으로 §5/§6/§7 수식·분류 검증 실시 (PASS)

---

## A. 사용자 원문 명령 복종 검수 (불복종 색출)

| # | 사용자 명령 | 구현 위치 | 결과 |
|---|-------------|-----------|------|
| A1 | SL, 트레일링 사용 (TP 없음) | `ExecuteMarketEntry` `tp=0.0`; `ModifySLSafe` `tp=0.0`; OrderSend 재시도도 TP=0 | **PASS** |
| A2 | 트레일 시작 N포인트 도달 즉시 SL을 진입(기준)가±N으로 이동 | `ManageTrailingStops` §5-3: `basePrice ± PointsToPrice(g_TrailStartPts)` when `profitPts >= Start` | **PASS** |
| A3 | 이후 스텝 간격 Floor 추격 | `steps = MathFloor((profitPts-Start)/Step)`; `+ steps*Step` | **PASS** |
| A4 | 예: Start 200 / Step 10 | 입력 기본값 `InpTrailingStartPts=200`, `InpTrailingStepPts=10` + 패널 Edit 동기화 | **PASS** |
| A5 | 모든 파라미터 수치 = 포인트 통일 | SL/Start/Step/Slippage 전부 Points; `GetPointSize/PointsToPrice` | **PASS** |
| A6 | 모든 브로커 심볼 자동감지 | `ResolveTradeSymbol` + `TrySymbolVariant` + `AutoDetectSymbolSpec` (Point/Digits/Stop/Freeze/Lot/Tick) | **PASS** |
| A7 | 브로커 시간 자동감지 | `DetectTimeframeAndBrokerTime` — `Period()` + `(TimeCurrent-TimeGMT)/60` | **PASS** |
| A8 | SL 가디언 | `SLGuardianTick` / `EnsureInitialSL` / `ModifySLSafe` / `InpSLGuardianOn` | **PASS** |
| A9 | 진입 랏 수동/자동 | `g_LotModeAuto` + `OBJ_BTN_AUTO` + `CalcAutoLots` / `GetTradeLots` | **PASS** |
| A10 | 패널: SL / Trail Start / Step / Lot / 일괄청산 / BUY / SELL | `CreatePanel` 전 컨트롤 생성 + `OnChartEvent` 바인딩 | **PASS** |
| A11 | 화면 크기·컬러 사용자 설정 | `InpPanelWidth/Height/X/Y` + `InpColor*` 전부 `CreatePanel`에서 사용 | **PASS** |
| A12 | 물타기: 모든 진입 SL/트레일 **동일 절대가** | `ClassifyAddMode==1` → `ResolveBasePriceForTicket` = 최초 Open; 트레일·초기SL 공통 | **PASS** |
| A13 | 불타기: 추가 진입가 기준 각자 SL/트레일 | `ClassifyAddMode==2` → BasePrice = 자기 OpenPrice | **PASS** |
| A14 | EA 명칭 IDC_Assistant | 파일명·패널 타이틀·copyright | **PASS** |

불복종 항목: **없음**.

---

## B. 명세 §1 시스템 환경 매핑

| 명세 | 코드 | 결과 |
|------|------|------|
| §1-1 MT4 전용 | `#property strict`, OrderSend/Modify/Close | PASS |
| §1-2 포인트 통일 | 전 거리 파라미터 Points + Point 환산 | PASS |
| §1-3 TP=0 | 진입·수정 모두 `tp=0.0` 고정 | PASS |
| §1-4 심볼 자동감지 | Resolve + Variant + Spec 로그 | PASS |
| §1-5 시간 자동감지 | TF + GMT 오프셋 분 단위 패널 표시 | PASS |

---

## C. 파라미터 전수 매핑 (기능 실재 / UI-only 색출)

| 파라미터 | 기본값 | 코드 실참조 | UI-only? | 결과 |
|----------|--------|-------------|----------|------|
| InpSepPanel | 문자열 | 입력창 구분선만 | **YES (라벨)** | UI-ONLY |
| InpPanelX | 20 | CreatePanel `x` | NO | PASS |
| InpPanelY | 30 | CreatePanel `y` | NO | PASS |
| InpPanelWidth | 280 | CreatePanel `w` | NO | PASS |
| InpPanelHeight | 360 | CreatePanel `h` | NO | PASS |
| InpColorBg | C'24,28,36' | SetRect BG | NO | PASS |
| InpColorBorder | C'70,80,95' | Border/Edit/Button | NO | PASS |
| InpColorText | C'230,235,240' | Labels/Edit text | NO | PASS |
| InpColorEditBg | C'40,46,58' | SetEdit BG | NO | PASS |
| InpColorBuy | C'30,140,90' | BUY 버튼 + OrderSend color | NO | PASS |
| InpColorSell | C'180,55,55' | SELL 버튼 + OrderSend color | NO | PASS |
| InpColorClose | C'160,110,30' | CLOSE ALL 버튼 | NO | PASS |
| InpColorAccent | C'80,140,200' | 타이틀 + AUTO 버튼 | NO | PASS |
| InpFontSize | 10 | Label/Edit/Button 폰트 | NO | PASS |
| InpSepTrade | 문자열 | 입력창 구분선만 | **YES (라벨)** | UI-ONLY |
| InpSLPoints | 200 | InitRuntime → g_SLPoints → CalcInitialSLPrice | NO | PASS |
| InpTrailingStartPts | 200 | g_TrailStartPts → ManageTrailingStops | NO | PASS |
| InpTrailingStepPts | 10 | g_TrailStepPts → ManageTrailingStops | NO | PASS |
| InpLots | 0.10 | g_Lots → GetTradeLots(MANUAL) | NO | PASS |
| InpLotModeAuto | false | g_LotModeAuto → GetTradeLots/CalcAutoLots | NO | PASS |
| InpRiskPercent | 1.0 | CalcAutoLots 위험금액 | NO | PASS |
| InpMagicNumber | 90001 | OrderSend + IsOurOrder 필터 | NO | PASS |
| InpSlippagePts | 30 | OrderSend / OrderClose | NO | PASS |
| InpTradeComment | IDC_A | OrderSend comment 접두 | NO | PASS |
| InpSepSymbol | 문자열 | 입력창 구분선만 | **YES (라벨)** | UI-ONLY |
| InpAutoDetectSymbol | true | OnInit/OnTick → AutoDetectSymbolSpec | NO | PASS |
| InpManualSymbol | "" | ResolveTradeSymbol | NO | PASS |
| InpSepGuard | 문자열 | 입력창 구분선만 | **YES (라벨)** | UI-ONLY |
| InpSLGuardianOn | true | OnTick 게이트 | NO | PASS |
| InpSLGuardianRetryMs | 250 | ModifySLSafe 실패 재시도 | NO | PASS |

### UI-only / 기능미구현 색출 결과

| 항목 | 판정 | 설명 |
|------|------|------|
| InpSepPanel / InpSepTrade / InpSepSymbol / InpSepGuard | **UI-ONLY** | MT4 입력 그룹 구분 문자열. 런타임 로직 없음. 위장 파라미터 아님. |
| 그 외 26개 파라미터 | **실기능** | 위 표 참조 |
| 전략 로직용 위장 파라미터 | **없음** | — |

패널 Edit(OBJ_EDT_*)는 input이 아니라 런타임 컨트롤이며 `SyncPanelEditsToRuntime`으로 `g_SLPoints/g_TrailStartPts/g_TrailStepPts/g_Lots`에 연결되어 **기능 있음**.

---

## D. 패널 컨트롤 ↔ 기능 바인딩 전수

| 컨트롤 | 객체명 | 이벤트/갱신 | 실제 효과 | 결과 |
|--------|--------|-------------|-----------|------|
| SL Edit | OBJ_EDT_SL | SyncPanelEditsToRuntime | g_SLPoints → 초기SL/가디언/자동랏 | PASS |
| Trail Start Edit | OBJ_EDT_TS | Sync | g_TrailStartPts → 트레일 | PASS |
| Trail Step Edit | OBJ_EDT_STEP | Sync | g_TrailStepPts → 트레일 | PASS |
| Lots Edit | OBJ_EDT_LOT | Sync (MANUAL시) | g_Lots → OrderSend lots | PASS |
| AUTO/MANUAL | OBJ_BTN_AUTO | OnChartEvent 토글 | g_LotModeAuto + CalcAutoLots | PASS |
| BUY | OBJ_BTN_BUY | OnChartEvent | ExecuteMarketEntry(OP_BUY) | PASS |
| SELL | OBJ_BTN_SELL | OnChartEvent | ExecuteMarketEntry(OP_SELL) | PASS |
| CLOSE ALL | OBJ_BTN_CLOSE | OnChartEvent | CloseAllOurOrdersFast | PASS |
| Status/Guard 라벨 | OBJ_STATUS/GUARD | UpdatePanelStatus | 표시 전용(정상) | PASS |

**UI만 있고 클릭/값이 무효인 버튼: 없음.**

---

## E. 트레일링 수식 전수 매핑 (§5)

| 명세 | 수식 | 코드 라인 근거 | 결과 |
|------|------|----------------|------|
| BasePrice | §6/§7 Resolve | `ResolveBasePriceForTicket` | PASS |
| BUY profitPts | (Bid-Base)/Point | ManageTrailingStops | PASS |
| SELL profitPts | (Base-Ask)/Point | ManageTrailingStops | PASS |
| Start 미만 | continue (미가동) | `profitPts < g_TrailStartPts` | PASS |
| 1차 SL BUY | Base+Start*Point | `basePrice + PointsToPrice(g_TrailStartPts)` | PASS |
| 1차 SL SELL | Base-Start*Point | 대칭 | PASS |
| Floor steps | floor((profit-Start)/Step) | `MathFloor(...)` | PASS |
| 최종 BUY SL | Base+Start+steps*Step | PointsToPrice 합산 | PASS |
| 유리 방향만 | BUY new>cur / SELL new<cur | improve 게이트 | PASS |
| TP 변경 금지 | tp=0 고정 | ModifySLSafe | PASS |

Python 시뮬: Start=200/Step=10 1차·스텝·미만·DCA동일가·PYR개별가 **전부 PASS**.

---

## F. 물타기(DCA) §6 전수

| 명세 | 코드 | 결과 |
|------|------|------|
| BUY 추가가 < 최초가 → DCA | ClassifyAddMode return 1 | PASS |
| SELL 추가가 > 최초가 → DCA | ClassifyAddMode return 1 | PASS |
| 최초 = OpenTime 최소 | FindBaseOrder | PASS |
| BasePrice = 최초 Open | ResolveBasePriceForTicket mode==1 | PASS |
| 초기 SL 동일 절대가 | CalcInitialSLPrice(type, basePx) 진입·가디언 | PASS |
| 트레일 동일 절대가 | 공통 BasePrice로 newSL 계산·적용 | PASS |
| 트레일 전 그룹 SL 재정렬 | SLGuardianTick DCA 루프 | PASS |

---

## G. 불타기(PYR) §7 전수

| 명세 | 코드 | 결과 |
|------|------|------|
| BUY 추가가 > 최초가 → PYR | ClassifyAddMode return 2 | PASS |
| SELL 추가가 < 최초가 → PYR | ClassifyAddMode return 2 | PASS |
| BasePrice = 자기 Open | ResolveBasePriceForTicket | PASS |
| 초기 SL = 자기 Open±SL | 진입 시 baseForSL=price / EnsureInitialSL | PASS |
| 트레일 독립 | 티켓별 own base | PASS |

---

## H. SL 가디언 §9 전수

| 명세 | 코드 | 결과 |
|------|------|------|
| SL==0 주입 | EnsureInitialSL | PASS |
| STOPLEVEL/FREEZELEVEL 보정 | ModifySLSafe minDist | PASS |
| RefreshRates | ModifySLSafe | PASS |
| 실패 티켓만 RetryMs | static s_lastFailTicket | PASS |
| 불리 후퇴 금지 (초기주입 제외) | initialFill 분기 | PASS |
| SLPoints<=0 시 무한FIX 방지 | g_SLPoints>0 게이트 / "SL OFF" | PASS |

---

## I. 일괄 청산 §10

| 명세 | 코드 | 결과 |
|------|------|------|
| 본 EA 매직·심볼만 | IsOurOrder | PASS |
| 시장가 OrderClose | CloseAllOurOrdersFast | PASS |
| 다회 패스 재시도 | CLOSE_MAX_PASSES=8 | PASS |

---

## J. 허위·은폐·형식적 구현 색출

| 검사 | 결과 |
|------|------|
| 버튼은 있으나 OrderSend 없음 | **해당 없음** — BUY/SELL → ExecuteMarketEntry |
| CLOSE 버튼 로그만 | **해당 없음** — OrderClose 루프 |
| 트레일 함수 빈 껍데기 | **해당 없음** — Floor 수식+ModifySLSafe |
| DCA/PYR 주석만 있고 분류 없음 | **해당 없음** — ClassifyAddMode 실사용 |
| 가디언 플래그 무시 | **해당 없음** — InpSLGuardianOn 게이트 |
| 자동랏 토글만 있고 계산 없음 | **해당 없음** — CalcAutoLots 공식 |
| TP 몰래 사용 | **해당 없음** — tp 항상 0 |
| 검수 허위 보고(컴파일 성공 위장) | **하지 않음** — MetaEditor 없음 명시 |

### 알려진 한계 (은폐 없이 사실 보고)

| # | 내용 | 심각도 |
|---|------|--------|
| L1 | MetaEditor 미존재로 **.ex4 실컴파일/차트 실기동 미검증** | 환경 한계 |
| L2 | DCA 판별은 “최초 진입가 대비” 상대비교. 사용자가 의도적으로 교차 혼합(물타기 후 중간가 재진입 등)해도 규칙 §6/§7대로만 동작 | 명세 준수 |
| L3 | 패널 폰트 `"Arial"` 고정(크기·색만 입력). 폰트 패밀리 입력 파라미터는 명세 요구 아님 | 해당없음 |
| L4 | `ModifySLSafe`가 DCA 초기SL 재정렬 시 기존 SL보다 불리한 방향으로는 거부(§9-5). 정상 가드 | 의도적 |
| L5 | 불타기 심부 트레일 시 Floor-스텝 수식 특성상 절대 SL이 시세 근처로 수렴할 수 있음. **가동 시점·초기SL·BasePrice는 진입가별 독립** (명세 §7 준수, 버그 아님) | 수식 특성 |

---

## K. 땜빵/대충 제작 색출

| 검사 | 결과 |
|------|------|
| TODO/FIXME/stub 함수 | **없음** (소스 검색) |
| empty OnChartEvent | **없음** |
| 매직 미필터 전계좌 청산 | **없음** — IsOurOrder |
| pip/point 혼용 | **없음** — Point만 |
| 골드 전용 하드코딩 | **없음** — 차트/수동 심볼 범용 |

---

## L. 최종 판정

| 영역 | 판정 |
|------|------|
| 원본전략(사용자 1~8 + SPEC) 매핑 | **PASS (100% 항목 매핑)** |
| UI-only 위장 파라미터 | 구분선 4개만 (정상) / 그 외 없음 |
| 불복종 | **없음** |
| 허위·은폐 보고 | **없음** (컴파일 미실시 명시) |
| 형식적 빈 구현 | **색출 0건** |

**종합: 제출본은 명세 항목 단위로 실기능 매핑 완료. 실기 MT4 컴파일·차트 검증은 사용자 환경에서 필요.**
