# IDC_8 — GOLD M1 SYSTEM
## 원본 전략 자료 (Official Strategy Document) v3.11

| 항목 | 내용 |
|------|------|
| 시스템명 | IDC_8 |
| 상품 | Gold (XAUUSD 계열) |
| 설계 타임프레임 | M1 (1분봉) — **권장** |
| 플랫폼 | MetaTrader 4 (MT4) 전용 |

---

## 1. 시스템 개요

```
[EMA 크로스] → [관찰 N봉] → [RSI 2단계 돌파] → [9EMA 캔들 돌파 확인] → [종가 진입]
```

---

## 2. RSI 돌파 (엄격 2봉, 터치 무효)

| 용어 | 정의 (마감봉) |
|------|--------------|
| 상향 돌파 | prev ≤ 기준 AND curr > 기준 |
| 하향 돌파 | prev ≥ 기준 AND curr < 기준 |

---

## 3. SELL 6항목

| # | 조건 |
|---|------|
| 1 | 데드크로스 |
| 2 | N봉 이내 |
| 3 | RSI 52↑ → 48↓ (엄격 돌파) |
| 4 | 9EMA 하향 **돌파** + 종가 아래 + 몸통>꼬리 (3봉 유예) |
| 5 | 사이클 1회 |
| 6 | SELL만 |

---

## 4. BUY — SELL 대칭

---

## 5. 손익

SL 셋업 종가 / TP 없음 / 트레일링 / SL=0 금지

---

## 6. 파라미터 (23개)

`InpAutoDetectGold`, `InpManualSymbol`, `InpFastEmaPeriod`, `InpSlowEmaPeriod`, `InpRsiPeriod`, `InpRsiUpper`, `InpRsiLower`, `InpObservationBars`, `InpEmaGraceBars`, `InpUseEmaSepFilter`, `InpMinEmaSepPts`, `InpUseEmaAngleFilter`, `InpAngleEmaPeriod`, `InpAngleLookback`, **`InpMinAngleDeg` (도)**, `InpLots`, `InpStopLossPoints`, `InpTrailingStartPts`, `InpTrailingStepPts`, `InpMagicNumber`, `InpSlippagePts`, `InpTradeComment`, `InpDebugBarLog`

---

## 8. 횡보 차단 필터

### 8.1 EMA 이격 — `InpMinEmaSepPts` (100pt)

### 8.2 EMA34 각도 (v3.11 — **도 단위 파라미터**)

```
angle(°) = atan( (EMA34[1] − EMA34[1+N]) / ATR(N)[1] ) × 180 / π
```

| 파라미터 | 디폴트 | 단위 |
|----------|--------|------|
| `InpAngleEmaPeriod` | 34 | EMA |
| `InpAngleLookback` | 7 | 봉 |
| **`InpMinAngleDeg`** | **78.7** | **도(°)** — 사용자가 34, 55 등 직접 설정 |

- SELL: angle ≤ −`InpMinAngleDeg`
- BUY: angle ≥ +`InpMinAngleDeg`
- 횡보: angle ≈ 0° → 차단

### 8.3 디버그 — `InpDebugBarLog` → `Ang34=...` (도), `ENTRY|DONE`

---

*EA: `IDC_8.mq4` v3.11 | 검증: `IDC_8_VERIFICATION_REPORT_v3.11.md`*

## 변경 이력

| 버전 | 내용 |
|------|------|
| v3.10 | **폐기** — ATR 배수를 파라미터에 사용 (사용자 불편) |
| v3.11 | **도(°) 파라미터 복원**, ATR정규화 atan 각도 공식, 디폴트 78.7° |
