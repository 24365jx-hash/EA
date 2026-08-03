# IDC_3 — GOLD M1 Inside Bar System

## Spec lock v1.00

| 항목 | 내용 |
|------|------|
| 시스템명 | IDC_3 |
| 상품 | Gold (XAUUSD 계열) |
| 타임프레임 | **M1 전용** |
| 플랫폼 | MetaTrader 4 |
| EA | `MQL4/Experts/IDC_3.mq4` v1.00 |

---

## 1. 시각 규칙 (차트 라인 색)

| 대상 | 라인 색 | 의미 |
|------|---------|------|
| 캔들 **#1** (모캔들) | **파란색** High/Low | 인사이드 판정 기준 범위 |
| 캔들 **#2** (인사이드) | **빨간색** High/Low | **진입 돌파 기준** 범위 |
| 캔들 **#1·#2 몸통 색** | **무관** | 양봉/음봉 모두 허용 |

---

## 2. 진입 규칙 (원본 1:1)

### R01 — 인사이드 바
- 캔들 #2 High < 캔들 #1 High
- 캔들 #2 Low  > 캔들 #1 Low
- #2가 #1보다 작음 (엄격 포함으로 자동 충족)
- 캔들 색 무시

### R02 — 전제
- R01 충족 시에만 이후 진행

### R03 — 진입 트리거
- 캔들 #2의 **빨간** High/Low를 **종가**로 돌파한 방향 진입
- Close > #2 High → **BUY**
- Close < #2 Low  → **SELL**
- 꼬리만 돌파하고 종가가 범위 안이면 **무효**

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

## 3. 트레일링 (원본 예시 락)

예: Start=200, Step=10

| 수익(points) | SL |
|--------------|-----|
| < 200 | 초기 SL 유지 |
| ≥ 200 | **진입가(본전/BE)** |
| ≥ 210 | BE + 10 |
| ≥ 220 | BE + 20 |
| … | step마다 추종 |

공식 (BUY): `lock_pts = floor((profit - Start) / Step) * Step` → SL = Open + lock_pts  
(SELL 대칭)

---

## 4. 봉 인덱싱 (신규 M1 봉 시점)

| 전략 캔들 | iHigh/iLow/iClose shift |
|-----------|-------------------------|
| #1 모캔들 | 3 |
| #2 인사이드 | 2 |
| #3 트리거 | 1 |

---

## 5. 부가 기능 (원본 하단 스펙)

| 기능 | 구현 |
|------|------|
| 단위 points | 전 파라미터 points, 브로커 digits 정규화 |
| 심볼/타임존 자동 | Gold 심볼 탐지 + GMT offset |
| SL Guardian | 스프레드·StopLevel 적응, SL=0 복구 |
| 수동/자동 랏 | Fixed / Risk% |
| 거래 시간 | GMT 세션 필터 |
| 일일 최대 손실% | day-start equity 대비 |
| Gold 기본값 | SL 500 / Trail 200·10 등 |

---

## 6. 입력 파라미터 목록

`InpAutoDetectGold`, `InpManualSymbol`,  
`InpStopLossPoints`, `InpTrailingStartPts`, `InpTrailingStepPts`,  
`InpUseAutoLot`, `InpFixedLot`, `InpRiskPercent`, `InpMaxLot`,  
`InpUseSLGuardian`, `InpMaxSpreadPts`, `InpSpreadBufferPts`, `InpSLPadPts`,  
`InpUseTimeFilter`, `InpStartHourGMT`, `InpStartMinuteGMT`, `InpEndHourGMT`, `InpEndMinuteGMT`,  
`InpCloseOutsideHrs`, `InpDailyLossPercent`, `InpStopOnDailyLoss`, `InpCloseOnDailyLoss`,  
`InpMagic`, `InpSlippagePts`, `InpTradeComment`,  
`InpShowPanel`, `InpDrawSetupLines`, `InpDebugLog`

섹션 구분용 `InpSec*` 문자열은 UI 그룹 라벨이며 로직 미사용(의도).
