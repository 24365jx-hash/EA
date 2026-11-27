# IDC_F 검수보고 **1차** (2026-11-26 KST)

- **대상**: `MQL4/Experts/IDC_F.mq4` v2.00, `docs/IDC_F_CONSTITUTION.txt`
- **기준 원본**: 안2「안정 균형」+ IDC_F 헌법
- **MT4 컴파일/테스터**: 본 VM **미실시** → 실행 정상 여부는 **코드 정적 검수**만
- **IDC_R 검수**: 기존 1~3차와 **별도**. 본 보고는 **IDC_F 1차**

---

## 1. 원본전략 100% 매핑 (헌법 → 코드)

| # | 헌법·안2 요건 | 구현 위치 | 판정 |
|---:|---|---|---|
| 1.1 | EURUSD·XAUUSD **REG only** | `PatternOf()` L292-304, `IsRegFx`/`IsRegGold` L283-290 | ✅ |
| 1.2 | US100 계열 **PULL only** | `IsPullIndex()` L272-276, `PatternOf` PAT_PULL | ✅ |
| 1.3 | US30/US500 등 **화이트리스트 제외** | `InpPlan2Whitelist` + `AllowedPlan2` L306-318 | ✅ |
| 1.4 | REG: VWAP 이탈 후 M5 복귀 | `CollectReg` L1027-1133, `SessionVWAP` L796+ | ✅ (1차 검수 중 **세션 앵커 VWAP**로 수정) |
| 1.5 | REG: **H1 횡보만** | `H1Chop` L776-794, CollectReg L1089 | ✅ |
| 1.6 | PULL: M15 임펄스 | `CollectPull` L1147-1168, `InpImpulseAtr` | ✅ |
| 1.7 | PULL: **H1 방향만** (기울기 X) | `H1TrendOnly` L763-774 | ✅ |
| 1.8 | PULL: M5 눌림 M15 시가 | CollectPull L1188-1194 | ✅ |
| 1.9 | STAB: σ(R)>InpStabStdR 또는 3연손 | `RecomputeStabGate` L336-359 | ✅ |
| 1.10 | STAB: 당일 R≤InpDayPullStopR | `PullAllowedNow` L320-326, `gDayR` OnClosedTrade | ✅ |
| 1.11 | 일 체결 상한 3 | `InpMaxTradesDay` TryEntry L1974-1977 | ✅ |
| 1.12 | PULL 랏 0.24% | TryEntry L2031-2032 | ✅ |
| 1.13 | 신호 **M5 shift=1** | CollectReg/Pull `iClose(...,1)` | ✅ |
| 1.14 | M15 구조 TF | `InpStructureTF` CollectPull | ✅ |
| 1.15 | 게이트 세션·2%·93% 등 | `CanEnter` L1398-1442 | ✅ |
| 1.16 | TP=0 MFE 트레일 | `ManageTicket` LockPoints | ✅ (IDC_R 이식) |
| 1.17 | **65/35 체결 비율 강제** | — | ⚠️ **미강제** (확률 목표만, 코드는 상한 3+PULL 1회/일) |

**1차 결함(수정함)**: VWAP이 `InpVwapBars` 롤링만 사용 → 헌법 「세션 VWAP」과 불일치 → **`SessionStartKst`/`SessionStartServer` 누적**으로 교체.

**잔여 갭**: 65/35 비율은 **학습·랜덤이 아닌 시장** 의존. 헌법 문구는 **운영 목표**로 해석, 강제 로직 없음.

---

## 2. UI만 있고 신호에 미사용 input (색출)

| input | 선언 | 신호/게이트 사용 | 비고 |
|---|---|---|---|
| `InpSweepMaxBars` | L24 | **MarkBar** need만 L1391 | S1 잔재. REG/PULL **스윕 미사용** |
| `InpAsiaStartHour/End` | L25-26 | **AsiaBlocked** 게이트만 L608+ | REG는 아시아 레벨 **무관** |
| `InpSweepMinPoints` 등 9개 거리 0=자동 | L59-67 | **EffPoints** | ✅ REG/PULL 손절·추격 |
| `InpSweepMinPoints>0` 전부 | OverridesComplete | **PatternOf=0** 우회 시 S1식 후보 가능 | ⚠️ 교수님이 0 유지 전제 |
| `InpH1SlopeBars` | L21 | **H1Chop·H1Ok** 만 | **`H1Ok` 함수 자체 미호출** (S1 잔재) |
| `LevelOx()` | L496 | **호출 0건** | S1 잔재 **데드코드** |
| `AsiaWindow()` | L924 | **호출 0건** | S1 잔재 **데드코드** |
| `H1Ok()` | L741 | **호출 0건** | PULL은 H1TrendOnly 사용 |
| `InpUseCrypto` | L58 | RefreshSymbols | 안2 화이트리스트 시 **실질 무의미** |

**판정**: 거리·세션·리스크 input은 **주문 경로 사용**. S1 스윕·LevelOx·AsiaWindow·H1Ok는 **잔재(기능 없음)** — 허위 진입 공식 아님, **정리 권고**.

---

## 3. 허위·은폐 금지

| 주장 | 근거 | 판정 |
|---|---|---|
| 「세션 VWAP」 | 수정 전 96봉 롤링 | **1차에서 수정**, 수정 전은 **허위에 가까움** |
| 「매달 300만 보장」 | 없음 | **보장 문구 없음** ✅ |
| 「MT4 100% 작동」 | VM 미컴파일 | **미검증**, 본 보고서 **유 선언 안 함** |
| O/X 매 M5 | `MarkBar`+`FlushOx` | 코드상 **구현** ✅, 실로그 미확인 |

---

## 4. 사용자 명령 불복종

| 명령 | 상태 |
|---|---|
| 이름 IDC_F | ✅ |
| 안2 | ✅ |
| MT4 strict | `#property strict` L3 |
| 골드 디폴트 | 프리셋 + input |
| 디버그 ON/OFF O/X | `InpDebugLog` L54, CollectReg/Pull `RegOx`/`PullOx` |
| 전체본 제출 | 2375행 mq4 |
| 「자체 100회 검수」 | **수행 안 함** — **정적 1회 전수**만 |

---

## 5~7. 항목별 함수 (요약 표)

- **게이트 10항**: `CanEnter` L1398 — `gGateLine` + STAB 표시 (수정)
- **REG 8단 O/X**: `RegOx` L499, CollectReg
- **PULL 8단 O/X**: `PullOx` L513, CollectPull
- **주문**: `SendMarket`→`TryEntry` L2053
- **학습 청산**: `OnClosedTrade` L1774
- **파일**: `IDC_F_learn.txt` v2 L1591, `IDC_F_open.txt` L1615

---

## 10. 디버그 매 캔들 O/X

| 단계 | 줄 | 동작 |
|---|---|---|
| 새 M5 | `MarkBar` L1384-1395 | `gBarOf` 갱신 시만 1회 |
| 신호 | `CollectSignals` | REG/Pull OxLine |
| 게이트 | `CanEnter` | `gGateLine` |
| 출력 | `FlushOx` L511-521 | `InpDebugLog==true` |
| verdict | TryEntry | 진입O/X/일상한/점수/블록 |

**OFF**: `DLog`/`OxLine`/`FlushOx` early return — **출력 없음** ✅

---

## 11. 월 300만원 이상 **예측 시뮬** (보장 아님)

출처: `EA_V2_THREE_PROPOSALS.md` 안2 합성 + 선택표 방법.

| 지표 | 안2 설계 추정 |
|---|---:|
| 월 중앙 실수령 | 360~390만원 |
| 하위 25% | 200~230만원 |
| 300만 넘는 달 비율 | 60~65% |
| 거래당 +R (목표) | 0.28~0.30R |

**결론**: **「매달 최소 300만 보장」 아님**. 중앙은 300만 이상 **가능 구간**이나, **하위 달은 200만대**. 포워드 4주 +0.15R 미달 시 실계 확대 중단(설계 원칙).

---

## 12. 학습 기능

| 기능 | 함수 | 판정 |
|---|---|---|
| 청산 후 가중치 | `OnClosedTrade` L1787-1793 | ✅ |
| 0.05~2.5 클램프 | `ClampWeights` | ✅ |
| 점수 60 버퍼 | `PushScore`/`SaveLearn` v2 | ✅ |
| 백분위 커트 | `GateScore` | ✅ |
| 랏 0.80+0.40×점수 (REG) | TryEntry L2033-2037 | ✅ |
| 트레일 3안 | `PickPreset`/`ManageTicket` | ✅ |
| **gRecentR/STAB 영속화** | — | ❌ **재시작 시 리셋** (당일만 메모리) |
| **REG/PULL 별도 가중치** | 단일 `gW[4]` | ⚠️ 설계서 「별도」와 **단순화** |

---

## 9. 땜빵·개판 여부

| 항목 | 판정 |
|---|---|
| IDC_R 포크 + Collect 교체 | 구조적 **타당**, S1 잔재 함수 **미정리** |
| VWAP 롤링(수정 전) | **땜빵** → 1차에서 **세션 누적으로 교정** |
| OverridesComplete S1 우회 | **위험** (기본 0이면 비활성) |

---

## 13. 심볼·GMT

- `BaseName` 접미사 제거 L189+
- `RefreshOffset`/`GmtNow` L529+
- `PatternOf` 화이트리스트

---

## 최종 (교수님 지정 형식)

**원본전략대로 MT4에서 정상 작동: 무** (본 환경 **MetaEditor 컴파일·실계/테스터 미실행**; 정적 매핑상 **치명 1건 VWAP 수정 반영**, S1 잔재·65/35 미강제·학습 STAB 비영속 **잔존**)