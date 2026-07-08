# IDC_8 — GOLD M1 SYSTEM
## 원본 전략 자료 (Official Strategy Document) v3.18

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

## 6. 파라미터 (25개)

`InpAutoDetectGold`, `InpManualSymbol`, `InpFastEmaPeriod`, `InpSlowEmaPeriod`, `InpRsiPeriod`, `InpRsiUpper`, `InpRsiLower`, `InpObservationBars`, `InpEmaGraceBars`, `InpUseEmaSepFilter`, `InpMinEmaSepPts`, `InpUseEmaAngleFilter`, `InpAngleEmaPeriod`, `InpAngleLookback`, **`InpMinAngleDeg` (도)**, `InpLots`, `InpStopLossPoints`, `InpTrailingStartPts`, `InpTrailingStepPts`, `InpMagicNumber`, `InpSlippagePts` **(OrderSend 허용슬리피지, 진입조건 아님)**, `InpTradeComment`, `InpDebugBarLog`, **`InpChartPanel`**, **`InpPanelFontSize`**

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

### 8.3 디버그 / 차트 대시보드

| 파라미터 | 기본 | 설명 |
|----------|------|------|
| `InpDebugBarLog` | false | Experts 탭 매봉 O/X 로그 |
| `InpChartPanel` | **true** | 차트 좌측 대시보드 (OBJ 라벨, 어두운 배경) |
| `InpPanelFontSize` | **13** | 대시보드 글자크기 (8~16) |

- **사이클 NONE이어도 1~10번 전부 표시** (34EMA 각도 항상 표시)
- 형식: `10 34EMA각도 [ON]  17.0도 (설정78.7도)  SELL [X]  BUY [X]`
- `[O]`=초록 / `[X]`=빨강

---

*EA: `IDC_8.mq4` v3.18 | 검증: `IDC_8_VERIFICATION_REPORT_v3.18.md`*

## 변경 이력

| 버전 | 내용 |
|------|------|
| v3.10 | **폐기** — ATR 배수를 파라미터에 사용 (사용자 불편) |
| v3.11 | **도(°) 파라미터 복원**, ATR정규화 atan 각도 공식, 디폴트 78.7° |
| v3.12 | 크로스 히스토리 부트스트랩 — 재부착 시 Cyc=NONE 수정, RSI/유예 리플레이 |
| v3.13 | 관찰만료→Cyc=NONE, init 즉시처리, 진입락, 크로스중복리셋 방지, 리플레이 크로스봉 포함 |
| v3.14 | 차트 좌측 매봉 진입조건 패널 (`InpChartPanel`) — 실측/설정/O/X 직관 표시 |
| v3.15 | 대시보드 전면개편: OBJ라벨+배경, 34EMA각도 항상표시, NONE도 1~10 전부, `InpPanelFontSize` |
| v3.16 | **유예버그 수정**: 리플레이 유예소모 제거, 이중만료 삭제, 첫셋업봉 진입 보장 |
| v3.17 | RSI 48/52 돌파 락 — `VerifyRsiSequenceLocked`, 차트 마감봉 재검증 |
| v3.18 | **원본 100%**: `InpSlippagePts` 진입차단 게이트 제거 — OrderSend 슬리피지만 사용 |
