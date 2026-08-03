# IDC_3 — GOLD M1 Inside Bar System

## Spec lock v1.04

| 항목 | 내용 |
|------|------|
| 시스템명 | IDC_3 |
| 상품 | Gold (XAUUSD 계열) |
| 타임프레임 | **M1 전용** |
| 플랫폼 | MetaTrader 4 |
| EA | `MQL4/Experts/IDC_3.mq4` **v1.03** |

---

## 1. 시각 규칙 (셋업 라인)

| 대상 | 기본 | 커스터마이즈 |
|------|------|--------------|
| 캔들 **#1** High/Low | 파랑 / Dash | `InpLine1Color`, `InpLine1Style` |
| 캔들 **#2** High/Low | 빨강 / Dash | `InpLine2Color`, `InpLine2Style` |
| 선 두께 | 1 | `InpLineWidth` (1–5) |
| 표시 ON/OFF | ON | `InpDrawSetupLines` |

### 표시 시간 범위 (v1.02)
- **OBJ_TREND** 구간: 캔들 **#1 시각 → #3 시각**
- `RAY_LEFT=false` → **#1보다 왼쪽(1캔들 이전 포함)에는 선 미표시**
- `RAY_RIGHT=false` → #3 이후로 무한 연장 없음
- 전차트 HLINE 폐기 → 셋업 구간만 보여 “어느 셋업인지” 식별 가능

캔들 **#1·#2 몸통 색**은 진입 판정과 **무관**.

---

## 2. 진입 규칙

### R01 — 인사이드 바
- 캔들 #2 High < 캔들 #1 High
- 캔들 #2 Low  > 캔들 #1 Low
- #2가 #1보다 작음 (엄격 포함으로 자동 충족)
- 캔들 색 무시

### R02 — 전제
- R01 충족 시에만 이후 진행

### R03 — 진입 트리거 (종가 돌파만)
- 캔들 #2의 High/Low를 **종가(Close)** 로 돌파한 방향만 진입
- Close > #2 High → **BUY**
- Close < #2 Low  → **SELL**
- **심지(High/Low)만 돌파하고 종가 미돌파 = 무효** (wick-only CANCEL)
- High/Low는 진입 근거로 사용 금지

### R03c — 돌파 마감 캔들 #3 몸통 조건
- `body = |Close−Open|`
- `upper = High − max(Open,Close)`
- `lower = min(Open,Close) − Low`
- **통과: body > upper AND body > lower AND body > (upper+lower)** (등호 불허)
- 미충족 시 **셋업 취소**

### R04 — 타임아웃
- #2 **직후 1봉(#3)** 만 유효
- #3가 #2 범위를 종가 돌파하지 않으면 **셋업 취소**
- #4 이후 대기 **없음**

### R05 — 포지션
- 보유 중 **추가 진입 금지** (동시 1포지션)

### R06 — 청산
- **TP 없음** (항상 0)
- **초기 SL** + **트레일링**만 사용

---

## 3. 트레일링 (최초 원본전략)

예: Start=200, Step=10

| 수익(points) | SL (BUY) |
|--------------|----------|
| < 200 | 초기 SL 유지 |
| ≥ 200 | **진입가(본전/BE)** |
| ≥ 210 | 본전 + 10 |
| ≥ 220 | 본전 + 20 |
| … | Step마다 추종 |

공식 (BUY):  
`lock_from_BE = floor((profit − Start) / Step) × Step`  ← Start 시 **0 = 진입가**  
`SL = Open + lock_from_BE`  
(SELL 대칭)

원문: Start 도달 시 SL을 **진입가(본전)** 으로 이동 후, Step 간격으로 가격 추종.

---

## 4. 봉 인덱싱 (신규 M1 봉 시점)

| 전략 캔들 | shift |
|-----------|-------|
| #1 모캔들 | 3 |
| #2 인사이드 | 2 |
| #3 트리거 | 1 |

---

## 5. 부가 기능

단위 points / 심볼·타임존 자동 / SL Guardian / 수동·자동 랏 / 세션·일일손실% / Gold 기본값
