# IDC_3 v1.01 — 정밀 전수 매핑 검수 (락)

- 대상: `MQL4/Experts/IDC_3.mq4` (872 lines, `#property version "1.01"`)
- 스펙: `docs/IDC_3_전략서.md` v1.01
- 논리테스트: `python3 simulation/idc3_logic_test.py` → **PASS**
- MT4 MetaEditor 컴파일 / 틱 테스터: **미실행** (환경 없음 — 성공 허위보고 없음)
- 검수 기준: 원본 이미지 규칙 + 사용자 확정(#1파랑/#2빨강/색무관) + v1.01 추가(#3몸통>심지) + 원본 트레일(본전→step)

---

## 1. 원본전략 ↔ 코드 전수 매핑

| ID | 원본/명령 | 코드 위치 | 구현 식 | 판정 |
|----|-----------|-----------|---------|------|
| R01 | #2가 #1 high~low **완전 포함**, #2가 더 작음 | L255 | `h2 < h1 && l2 > l1` (엄격→range 자동 작음) | **OK** |
| R01b | #1·#2 **캔들 색 무관** | Evaluate — #1/#2의 O/C 미사용 | H/L만 | **OK** |
| R02 | R01 아니면 중단 | L256–263 | return | **OK** |
| R03-B | Close>#2High → BUY | L270 | `c3 > h2` | **OK** |
| R03-S | Close<#2Low → SELL | L271 | `c3 < l2` | **OK** |
| R03b | 꼬리만 돌파 무효 | L269–282 | 종가만 판정 | **OK** |
| R03c | #3 몸통>위심지 **AND** 몸통>아래심지 | L292–304, L320–327 | `body>upper && body>lower` | **OK** |
| R04 | #3만 유효, 미돌파 즉시 취소 | L269–282; shift1만 트리거 | CANCEL, #4대기 없음 | **OK** |
| R05 | 보유 중 추가진입 금지 | L156–170, L224–228, L333–334 | 1포지션 | **OK** |
| R06-TP | TP 없음 | L381 | `OrderSend(..., sl, 0, ...)` | **OK** |
| R06-SL | 초기 SL | L336, L682–693 | `InpStopLossPoints` (+Guardian) | **OK** |
| R06-Trail | Start→**진입가 본전**, 이후 Step | L405–468 | `lock_from_be=steps*Step` (Start시 0) | **OK** |
| VIS-1 | #1 위아래 **파랑** | L815–816 | `clrDodgerBlue` | **OK** |
| VIS-2 | #2 위아래 **빨강** | L818–819 | `clrRed` | **OK** |
| IDX | #1=3 / #2=2 / #3=1 | L244–251 | iHigh/Low/Open/Close | **OK** |
| TF | M1 전용 | L73–77, L149–150 | 아니면 INIT_FAILED | **OK** |

### 트레일링 수치 검증 (Start=200, Step=10)

| profit | lock_from_be | BUY SL |
|--------|--------------|--------|
| 199 | (미발동) | 초기 SL |
| 200 | 0 | Open (본전) |
| 209 | 0 | Open |
| 210 | 10 | Open+10 |
| 220 | 20 | Open+20 |
| 231 | 30 | Open+30 |

코드: L426–435. 단위테스트 동일 PASS.

### R03c 수치 검증

| O,H,L,C | body / up / dn | 기대 | 코드 |
|---------|----------------|------|------|
| 100,135,95,130 | 30/5/5 | PASS | PASS |
| 100,130,95,110 | 10/20/5 | FAIL | FAIL |
| 100,112,85,110 | 10/2/15 | FAIL | FAIL |
| doji 100,110,90,100 | 0/… | FAIL | FAIL |

---

## 2. 입력 파라미터 전수 (UI-only 색출)

| 파라미터 | decl외 참조 | 연결 위치 | 판정 |
|----------|-------------|-----------|------|
| InpSecSym | 0 | UI 그룹 라벨 | 섹션(의도) |
| InpAutoDetectGold | 1 | ResolveSymbol L545 | 기능 |
| InpManualSymbol | 3 | ResolveSymbol L538–539 | 기능 |
| InpSecRisk | 0 | 섹션 | 섹션 |
| InpStopLossPoints | 5 | EffectiveSLPts/OpenMarket/OnInit/Panel | 기능 |
| InpTrailingStartPts | 5 | ManageTrailing/OnInit/Panel | 기능 |
| InpTrailingStepPts | 5 | ManageTrailing/OnInit/Panel | 기능 |
| InpSecLot | 0 | 섹션 | 섹션 |
| InpUseAutoLot | 3 | CalcLot/Panel | 기능 |
| InpFixedLot | 4 | CalcLot/OnInit | 기능 |
| InpRiskPercent | 3 | CalcLot/OnInit(Auto시) | 기능 |
| InpMaxLot | 3 | NormalizeVolume/OnInit | 기능 |
| InpSecGuard | 0 | 섹션 | 섹션 |
| InpUseSLGuardian | 6 | OnTick/Open/Trail/Guard/Spread/EffSL | 기능 |
| InpMaxSpreadPts | 1 | L230 (Guardian ON) | 기능 |
| InpSpreadBufferPts | 1 | EffectiveSLPts L689 | 기능 |
| InpSLPadPts | 5 | Guardian/Trail/Open/EffSL | 기능 |
| InpSecSession | 0 | 섹션 | 섹션 |
| InpUseTimeFilter | 1 | IsWithinTradingHours | 기능 |
| InpStartHourGMT | 1 | BrokerFromGmtHMS (필터ON) | 기능 |
| InpStartMinuteGMT | 1 | 동일 | 기능 |
| InpEndHourGMT | 1 | 동일 | 기능 |
| InpEndMinuteGMT | 1 | 동일 | 기능 |
| InpCloseOutsideHrs | 1 | OnTick L166 | 기능 |
| InpDailyLossPercent | 2 | UpdateDayState | 기능 |
| InpStopOnDailyLoss | 1 | Evaluate L218 | 기능 |
| InpCloseOnDailyLoss | 1 | OnTick L163 | 기능 |
| InpSecSys | 0 | 섹션 | 섹션 |
| InpMagic | 2 | IsOurSelected/OrderSend | 기능 |
| InpSlippagePts | 1 | SlippageRaw→OrderSend/Close | 기능 |
| InpTradeComment | 1 | OrderSend | 기능 |
| InpShowPanel | 1 | DrawPanel | 기능 |
| InpDrawSetupLines | 2 | Evaluate Draw/Delete | 기능 |
| InpDebugLog | 3 | Evaluate Prints | 기능 |

**기능 없는 위장 파라미터: 0건**  
섹션 라벨 6개 = MT4 입력창 구분용(로직 불필요, 기능 사칭 아님).

Guardian OFF 시 MaxSpread/SpreadBuffer/SLPad 비활성 = 마스터 스위치 설계(IDC_V 동일). UI-only 아님.

---

## 3. 허위·은폐·형식 제작 색출

| 검사 | 결과 |
|------|------|
| TP 위장 파라미터 | 없음 (TP 입력 자체 없음, OrderSend TP=0) |
| 몰래 EMA/RSI 등 삽입 | 없음 |
| #3 이후 #4+ 대기 | 없음 |
| Start+Step 잠금식 잔존(구 IDC식) | **없음** (`InpTrailingStartPts + steps` 미검출) |
| R03c 미구현·주석만 | **없음** — `IsBodyLargerThanWicks` 실호출 L293 |
| 컴파일/백테스트 성공 주장 | **하지 않음** |
| 헤더 스펙버전 표기 v1.0 잔존 | **발견→v1.01로 수정** (주석만, 로직 무영향) |

---

## 4. 사용자 명령 복종

| 명령 | 상태 |
|------|------|
| #1 라인 파랑 / #2 라인 빨강 | **복종** L815–819 |
| #1·#2 캔들 색 무관 | **복종** |
| 원본 트레일: Start→진입가 본전→Step 추종 | **복종** L425–435 |
| #3 몸통>위심지 AND 몸통>아래심지 | **복종** L320–327 |
| 종가 돌파만 / #3 타임아웃 / 1포지션 / TP없음 | **복종** |

**현재 코드 기준 불복종: 0건**

### 이력(은폐 금지)
- 한때 Start 수익잠금식(`Open±Start`)으로 잘못 바꿨던 적 있음 → 사용자 “원본대로” 명령 후 **본전(BE)식으로 복원·현재 유지**.

---

## 5. 땜빵·대충 제작 색출

| 항목 | 판정 |
|------|------|
| R03c를 파라미터 없이 하드코딩 | **정상** (사용자: “무조건” = 고정 규칙) |
| 트레일만 주석 수정·식 미변경 | **해당없음** — 식 `steps*Step` 확인 |
| 패널 문구만 body>wicks, 로직 없음 | **해당없음** — Evaluate에서 실차단 |
| 인사이드 색필터 몰래 잔존 | **없음** |

---

## 6. 부가기능 (원본 하단) 매핑

| 기능 | 코드 | 판정 |
|------|------|------|
| points 단위 | NormalizedPoint L579–586 | OK |
| 심볼 자동 | ResolveSymbol | OK |
| 타임존 | RefreshGmtOffset | OK |
| SL Guardian | Guard + EffSL + spread gate | OK |
| 수동/자동 랏 | CalcLot | OK |
| 거래시간 | IsWithinTradingHours | OK |
| 일일 최대손실% | UpdateDayState | OK |

---

## 7. 명시적 한계 (은폐 금지)

1. **초기 SL 수치** 원문 미기재 → 기본 **500pt** (사용자 조정).
2. **세션 시·분** 원문 미기재 → 필터 기본 OFF.
3. R03c “위아래 심지보다” 해석 = **각각** 비교(`body>up && body>dn`). 합산(`body>up+dn`) 아님 — 명령 문구상 각각이 정합.
4. MT4 **.ex4 컴파일·실틱 미검증**.
5. 본전 SL=`OrderOpenPrice` — 스프레드로 즉시 스탑 가능(실거래 특성). Guardian이 StopLevel 내로 clamp.

---

## 8. 최종 판정

| 항목 | 판정 |
|------|------|
| 원본+확정명령+ R03c 전략 로직 | **100% 정적 매핑** |
| UI-only 위장 파라미터 | **0건** |
| 허위/형식 미구현 | **0건** (헤더 주석 버전만 수정) |
| 현재 불복종 | **0건** |
| MT4 실기 검증 | **미실시** |
