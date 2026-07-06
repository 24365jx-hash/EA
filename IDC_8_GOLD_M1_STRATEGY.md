# IDC_8 — GOLD M1 SYSTEM
## 원본 전략 자료 (Official Strategy Document) v3.10

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
[EMA 크로스] → [관찰 N봉] → [RSI 2단계 돌파] → [9EMA 캔들 돌파 확인] → [종가 진입]
```

- 데드크로스 이후: **SELL만**
- 골든크로스 이후: **BUY만**
- 크로스 사이클당: **1회 진입**
- 크로스 사이클당: **RSI→EMA 기회 1회** (유예 만료 시 재시도 없음)

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
| 3 | RSI **52 상향 돌파** → **48 하향 돌파** (엄격 2봉 돌파만) |
| 4 | **9EMA 하향 돌파(이탈)** + 종가 9EMA 아래 + 몸통>꼬리 (RSI 48↓ 완료봉 포함 **3봉** 유예) |
| 5 | 사이클당 1회 |
| 6 | 데드크로스 후 SELL만 |

**9EMA SELL 돌파 정의:** `low < 9EMA` (가격이 9EMA를 **뚫고** 하향 이탈) + `close < 9EMA`. 터치만은 무효.

**진입:** 셋업 캔들 종가 (다음 봉 첫 틱, 슬리피지 허용 범위 내)

---

## 4. BUY (SELL 대칭)

| # | 조건 |
|---|------|
| 1 | 골든크로스 |
| 2 | N봉 이내 |
| 3 | RSI **48 하향 돌파** → **52 상향 돌파** |
| 4 | **9EMA 상향 돌파** + 종가 9EMA 위 + 몸통>꼬리 |

**9EMA BUY 돌파 정의:** `high > 9EMA` + `close > 9EMA`.

---

## 5. 손익 관리

| 항목 | 규칙 |
|------|------|
| SL | 셋업 종가 기준 고정 포인트 (필수, >0) |
| TP | 없음 |
| 트레일링 | 시작 포인트 도달 시 SL 이동 → 스텝 추격 |
| SL=0 | **금지** — 코드 원천 차단 + 매 틱 복구 |

---

## 6. 파라미터

`InpAutoDetectGold`, `InpManualSymbol`, `InpFastEmaPeriod`, `InpSlowEmaPeriod`, `InpRsiPeriod`, `InpRsiUpper`, `InpRsiLower`, `InpObservationBars`, `InpEmaGraceBars`, `InpUseEmaSepFilter`, `InpMinEmaSepPts`, `InpUseEmaAngleFilter`, `InpAngleEmaPeriod`, `InpAngleLookback`, `InpMinAngleDeg`, `InpLots`, `InpStopLossPoints`, `InpTrailingStartPts`, `InpTrailingStepPts`, `InpMagicNumber`, `InpSlippagePts`, `InpTradeComment`, **`InpDebugBarLog`**

---

## 7. 금지 사항

| 항목 | 내용 |
|------|------|
| 반대 방향 진입 | 금지 |
| 관찰구간 초과 | 무효 |
| 사이클 2회 진입 | 금지 |
| 사이클 2회 RSI→EMA | 금지 |
| RSI/9EMA 터치·체류만 | **무효** |
| 3봉 유예 초과 진입 | **금지** |
| SL 미설정 | 금지 |

---

*EA 파일: `IDC_8.mq4` v3.10*  
*검증 보고: `IDC_8_VERIFICATION_REPORT_v3.10.md`*

---

## 8. 횡보 차단 필터 (v3.03+)

### 8.1 EMA 이격

| 파라미터 | 디폴트 | 설명 |
|----------|--------|------|
| `InpUseEmaSepFilter` | true | 9-50 EMA 이격 필터 on/off |
| `InpMinEmaSepPts` | 100 | \|9EMA−50EMA\| 최소 (pt) |

### 8.2 EMA34 기울기 — ATR 정규화 (v3.10)

```
slope_atr = (EMA34[1] − EMA34[1+N]) / ATR(N)[1]
```

| 파라미터 | 디폴트 | 설명 |
|----------|--------|------|
| `InpUseEmaAngleFilter` | true | EMA34 기울기 필터 on/off |
| `InpAngleEmaPeriod` | 34 | 기울기 측정 EMA |
| `InpAngleLookback` | 7 | lookback N (봉) = ATR 기간 |
| `InpMinAngleDeg` | **1.0** | 최소 \|slope_atr\| (1.0 = 7봉 동안 EMA가 ATR 1배 이상 이동) |

- **횡보:** slope_atr ≈ 0 → 차단
- **SELL:** slope_atr ≤ −`InpMinAngleDeg`
- **BUY:** slope_atr ≥ +`InpMinAngleDeg`
- v3.09 이전 도(degree) 공식 **폐기** (금 M1에서 차트와 불일치)

### 8.3 RSI→EMA 유예

| 규칙 | 구현 |
|------|------|
| RSI 2단계 완료봉 포함 최대 3봉 | `g_rsi_trigger_time` + `g_grace_remaining` + `IsEmaGraceWindowExpired()` |
| 유예 만료 후 RSI 재시작 금지 | `g_rsi_to_ema_used` + `PHASE_SETUP_EXHAUSTED` |
| 진입 직전 최종 방어 | `IsSetupEntryPermitted()` |
| 필터/슬리피지 실패 시 유예 1봉 소모 | `TrySell/BuyEntry` grace-- |

### 8.4 디버그 로그 (v3.09)

| 파라미터 | 디폴트 | 설명 |
|----------|--------|------|
| `InpDebugBarLog` | false | 매봉 필터 O/X 로그 (전문가 탭) |

---

## 변경 이력

| 버전 | 날짜 | 내용 |
|------|------|------|
| v3.07 | 2026-07-06 | RSI→EMA 1회 제한, EXHAUSTED |
| v3.08 | 2026-07-06 | **폐기** — 원본 위반 완화 (체류 RSI, 9EMA 완화) |
| v3.09 | 2026-07-06 | v3.08 롤백, 원본 100% 복원, 9EMA 돌파 복원, InpDebugBarLog |
| v3.10 | 2026-07-06 | EMA34 ATR 기울기 필터, 로그 판정 직전 출력, ENTRY\|DONE |
