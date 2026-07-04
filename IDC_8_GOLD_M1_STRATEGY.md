# IDC_8 — GOLD M1 SYSTEM
## 원본 전략 자료 (Official Strategy Document) v3.05

| 항목 | 내용 |
|------|------|
| 시스템명 | IDC_8 |
| 상품 | Gold (XAUUSD 계열) |
| 설계 타임프레임 | M1 (1분봉) — **권장** |
| 지원 타임프레임 | **모든 TF** (차트에 부착한 TF에서 동작) |
| 플랫폼 | MetaTrader 4 (MT4) 전용 |

---

## 1. 시스템 개요

```
[EMA 크로스] → [관찰 N봉] → [RSI 2단계 돌파] → [9EMA 캔들 확인] → [종가 진입]
```

- 데드크로스 이후: **SELL만**
- 골든크로스 이후: **BUY만**
- 크로스 사이클당: **1회 진입**

---

## 2. RSI 돌파 정의 (원본)

**「터치」는 전략에 없음. 오직 베이스라인 위·아래 「돌파」만 인정.**

| 용어 | 정의 (마감봉 기준) |
|------|-------------------|
| **상향 돌파** | 이전봉 RSI ≤ 기준선 **AND** 현재봉 RSI > 기준선 |
| **하향 돌파** | 이전봉 RSI ≥ 기준선 **AND** 현재봉 RSI < 기준선 |

기준선에 닿기만 하거나, 이미 위/아래에 머무는 것은 **돌파가 아님**.

---

## 3. SELL 6항목

| # | 조건 |
|---|------|
| 1 | 데드크로스 (9EMA ↓ 50EMA) |
| 2 | 데드크로스 후 **N봉** 이내 (크로스봉 포함) |
| 3 | RSI **52 상향 돌파** → **48 하향 돌파** |
| 4 | 9EMA 하향 이탈 + 종가 아래 + 몸통>꼬리 (RSI봉 포함 **3봉** 유예) |
| 5 | 사이클당 1회 |
| 6 | 데드크로스 후 SELL만 |

**진입:** 셋업 캔들 종가 (다음 봉 첫 틱, 슬리피지 허용 범위 내)

---

## 4. BUY (SELL 대칭)

| # | 조건 |
|---|------|
| 1 | 골든크로스 |
| 2 | N봉 이내 |
| 3 | RSI **48 하향 돌파** → **52 상향 돌파** |
| 4~6 | SELL과 동일 구조 |

---

## 5. 손익 관리

| 항목 | 규칙 |
|------|------|
| SL | 셋업 종가 기준 고정 포인트 (필수, >0) |
| TP | 없음 |
| 트레일링 | 시작 포인트 도달 시 SL 이동 → 스텝 추격 |
| SL=0 | **금지** — 코드 원천 차단 + 매 틱 복구 |

---

## 6. 파라미터 (전부 사용자 설정)

`InpAutoDetectGold`, `InpManualSymbol`, `InpFastEmaPeriod`, `InpSlowEmaPeriod`, `InpRsiPeriod`, `InpRsiUpper`, `InpRsiLower`, `InpObservationBars`, `InpEmaGraceBars`, `InpUseEmaSepFilter`, `InpMinEmaSepPts`, `InpUseEmaAngleFilter`, `InpAngleEmaPeriod`, `InpAngleLookback`, `InpMinAngleDeg`, `InpLots`, `InpStopLossPoints`, `InpTrailingStartPts`, `InpTrailingStepPts`, `InpMagicNumber`, `InpSlippagePts`, `InpTradeComment`

---

## 7. 금지 사항

| 항목 | 내용 |
|------|------|
| 반대 방향 진입 | 금지 |
| 관찰구간 초과 | 무효 |
| 사이클 2회 진입 | 금지 |
| RSI 체류만 (돌파 없음) | **무효** |
| SL 미설정 | 금지 |

---

*EA 파일: `IDC_8.mq4` v3.05*

---

## 8. 횡보 차단 필터 (v3.03+)

### 8.1 EMA 이격

| 파라미터 | 디폴트 | 설명 |
|----------|--------|------|
| `InpUseEmaSepFilter` | true | 9-50 EMA 이격 필터 on/off |
| `InpMinEmaSepPts` | 100 | \|9EMA−50EMA\| 최소 (pt) |

### 8.2 EMA34 시각 각도 (v3.04 — 도 단위)

MT4 **MA Angle** 지표와 동일한 시각 각도 공식:

```
각도(°) = atan( (EMA[1] − EMA[1+N]) / (N × Point) ) × 180 / π
```

| 파라미터 | 디폴트 | 설명 |
|----------|--------|------|
| `InpUseEmaAngleFilter` | true | EMA34 각도 필터 on/off |
| `InpAngleEmaPeriod` | 34 | 각도 측정 EMA |
| `InpAngleLookback` | 7 | lookback N (봉) |
| `InpMinAngleDeg` | **78.7** | 최소 \|각도\| (도) |

- **SELL:** 각도 ≤ −78.7° / **BUY:** 각도 ≥ +78.7°
- v3.03 `35pt` 기울기(7봉)와 **동등**: `atan(35/7) ≈ 78.7°`
- 진입 직전(9EMA 캔들 확인 후) 적용

### 8.3 RSI→EMA 유예 (v3.05 수정)

- RSI 2단계 돌파 완료 봉 포함 **최대 3봉** 이내만 9EMA 진입 허용
- `g_rsi_trigger_time` + `g_grace_remaining` 이중 만료 검사
- 9EMA 확인됐으나 필터 실패 시에도 **유예 1봉 소모** (v3.04 무한 연장 버그 수정)
