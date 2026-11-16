# IDC_M 검수 보고서 — **2차** (2026-11-16)

> 1차: v1.0 제출·헌법락 초안 매핑  
> **2차: 사용자 지시 11항목 전수 대조 + 코드 보완 (v1.10)**

---

## A. 원본(헌법 §2) ↔ 코드 줄단위 매핑

| ID | 원본 조건 | 코드 위치 | v1.0 | v1.10 | 비고 |
|----|-----------|-----------|------|-------|------|
| R01 | M5 신호·H1 구조 | `IDC_Period()`, `IDC_H1TrendOk()` L492-497 | ✅ | ✅ | H1 고정(원본 동일) |
| R02 | 심볼 US100·사용자 변경 | `InpTradeSymbol`, `IDC_EnsureSymbol()` | ⚠️ | ✅ | v1.0: 후보 자동탐색 없음 → `IDC_ResolveSymbol()` |
| R03 | Point·서버시간 자동 | `MODE_POINT`, `TimeCurrent()` | ✅ | ✅ | |
| R04 | 아시아 레인지 | `IDC_CalcAsiaRange()` | ⚠️ | ✅ | v1.0: 아시아 **종료 전**에도 rangeValid → `IDC_AsiaSessionComplete()` |
| R05 | 런던/NY만 거래 | `IDC_TradeSessionOk()` | ✅ | ✅ | |
| R06 | M5 종가 돌파+버퍼 | `IDC_CheckBreakout()` | ✅ | ✅ | 돌파 후 상태 유지 |
| R07 | H1 EMA 방향 일치 | `IDC_H1TrendOk()` | ✅ | ✅ | |
| R08 | M5 EMA 풀백+방향봉 | `IDC_CheckPullback()` | ✅ | ✅ | 50~61.8%는 헌법§2 **미포함** |
| R09 | Quality≥동적임계 | `IDC_QualityScore`, `IDC_DynamicQualityThreshold` | ⚠️ | ✅ | v1.0: 학습 off여도 adapt 고정 버그 |
| R10 | 자가학습 CSV | `IDC_LearnOnClose()` | ⚠️ | ✅ | v1.0: 히스토리 인덱스 취약 → 재작성 |
| R11 | Degrade Guard | 원본 제안 Layer | ❌ | ✅ | `IDC_DegradeBlocksEntry()` |
| R12 | TP 없음·트레일 | `OrderSend` TP=0, `IDC_ManageTrailing()` | ✅ | ✅ | |
| R13 | 트레일 200/200/10 | `InpTrail*` | ✅ | ✅ | |
| R14 | SL 스윙+버퍼 | `IDC_SwingSL()` | ✅ | ✅ | |
| R15 | 뉴스 Guardian만 | `IDC_NewsGuardActive` SL만 확대 | ✅ | ✅ | MT4 경제캘린더 API 없음→시간창 |
| R16 | 스프레드·롤오버·금요일 | `IDC_GuardianAllowEntry()` | ✅ | ✅ | |
| R17 | 일일/총 DD% | `IDC_DailyLossPct`, `IDC_TotalDDPct` | ✅ | ✅ | |
| R18 | 일 최소2건 임계완화 | `InpMinTradesPerDay`, `IDC_DynamicQualityThreshold` | ✅ | ✅ | |
| R19 | 일 최대 거래 | `InpMaxTradesPerDay` | ✅ | ✅ | |
| R20 | 1봉 1진입 | `g_lastEntryBarTime` L549-550 | ✅ | ✅ | |
| R21 | 포지션 중 재진입 금지 | `IDC_CountOpen()` | ⚠️ | ✅ | v1.0: 오픈 중 **O/X 로그 생략** → 매봉 로그 |
| R22 | Lot 131 | `IDC_NormalizeLots` | ✅ | ✅ | |
| R23 | Margin 134 | `IDC_MarginOk` | ⚠️ | ✅ | chk<0 명확화 |
| R24 | 디버그 ON/OFF 매봉 O/X | `InpDebugLog` | ❌ | ✅ | `IDC_LogBarOX()` |

---

## B. input 파라미터 실기능 여부 (2차)

| Input | 기능 | v1.0 | v1.10 |
|-------|------|------|-------|
| InpTradeSymbol | 거래 심볼 | ✅ | ✅+후보 |
| InpMagic/Slippage | 주문 | ✅ | ✅ |
| InpSignalTF~NY hours | 세션/주기 | ✅ | ✅ |
| InpBreakBuffer~PullbackMax | 전략 | ✅ | ✅ |
| InpTrail* | 트레일 | ✅ | ✅ |
| InpLots* | 랏 | ✅ | ✅ |
| InpDaily/Total DD, Min/Max trades | 리스크 | ✅ | ✅ |
| InpMaxSpread, Friday, Rollover | Guardian | ✅ | ✅ |
| InpNewsGuardian, Guard1 hours, ExtraSL, SpreadSpike | 뉴스 Guardian | ✅ | ✅ |
| InpLearning*, Quality* | 학습 | ⚠️ | ✅ |
| InpDebugLog | O/X 로그 | ⚠️ | ✅ |
| **InpDegradeMaxLoss**, **InpDegradeMinExpR** | (신규) | ❌ | ✅ |

**UI만 있고 무기능인 input: v1.10 기준 0건** (2차 추가분 포함).

---

## C. 허위·음폐·땜빵 (1차 대비)

| 항목 | 판정 |
|------|------|
| 헌법 §3 전항목 ✅ 표기 | **1차 과장** — Degrade/매봉 로그/아시아종료 미구현 |
| "상업용 완전무결" 주장 | **1차 허위에 가까움** — MT4 미실행 |
| 틱 5초 요약 로그 | **땜빵** — 사용자 요구(매캔들 O/X) 불일치 |
| 학습 임계 항상 adapt | **버그** |
| 월 300만원 보장 암시 | **미실시** — 2차 §F 시나리오만 |

---

## D. 사용자 명령 불이행 (1차 → 2차)

| 명령 | 1차 | 2차 |
|------|-----|-----|
| 매캔들 진입조건 O/X | ❌ | ✅ |
| 원본 100% (Layer 포함 Degrade) | 부분 | 보완 |
| MT4 자체 테스트 | ❌ | ❌ (환경 한계, 정직 고지) |
| 완전무결 단정 | ❌ | ❌ |

---

## E. MT4 런타임 검증 (자체)

| 항목 | 결과 |
|------|------|
| MetaEditor 컴파일 | **본 VM 미실행** — MQL4 문법·`strict` 수준 수동 검수 |
| Strategy Tester | **미실행** |
| 시각화 | **미실행** |

---

## F. 월 300만원 시뮬레이션 (가정·예측, 실측 아님)

**전제:** 10만 USD, 리스크 0.5%/건, 일 2~4건, 기대 R 1.2(트레일 의존), 승률 42% (가정).

| 시나리오 | 월 수익률 | 월 수익(USD) | KRW(1USD=1,350원) |
|----------|-----------|--------------|-------------------|
| 보수 | 0.8% | $800 | **108만원** |
| 중립 | 1.8% | $1,800 | **243만원** |
| 낙관 | 3.0% | $3,000 | **405만원** |

→ **300만원/월은 중립~낙관 구간에서만 가능한 가정치. EA 코드만으로 수익 보장 불가.**

---

## G. 2차 변경 파일

- `MQL4/Experts/IDC_M.mq4` → **v1.10**
- 본 문서

---

**2차 최종(매핑·정적):** 원본 헌법§2 핵심 진입·리스크·트레일 **구현됨**.  
**2차 최종(런타임):** MT4 실기 테스트 없어 **작동 확정 불가**.