# IDC_8 v3.11 — 원본전략 1:1 전수 매핑 및 검증 보고서

**EA:** `IDC_8.mq4` v3.11  
**기준:** 사용자 확정 원본전략 (2026-07-06)  
**v3.10 폐기:** ATR 배수를 파라미터에 직접 넣던 방식 → **v3.11에서 도(°) 파라미터 복원**

---

## 1. v3.10 오류 및 v3.11 수정

| 항목 | v3.10 (오류) | v3.11 (수정) |
|------|-------------|-------------|
| `InpMinAngleDeg` 의미 | ATR 배수 (1.0) — 사용자 혼란 | **도(degrees)** — 34, 55, 78.7 직접 입력 |
| 디폴트 | 1.0 | **78.7** (원본 전략) |
| 각도 계산 | slope_atr (무차원) | `atan(rise/ATR)×180/π` → **도(°)** |
| 로그 | `SlopeATR=0.08` | `Ang34=2.1<=-55.0` (도) |
| v3.09 Point 공식 | -80.8° 횡보 오통과 | **폐기** |
| 로그 시점 | v3.10 판정 직전 | **유지** |

---

## 2. §8.2 EMA34 각도 — 원본 → 코드

| 원본 | 코드 | 검증 |
|------|------|------|
| EMA34 기울기 필터 | `InpUseEmaAngleFilter` | **O** |
| EMA 기간 34 | `InpAngleEmaPeriod=34` | **O** |
| Lookback 7봉 | `InpAngleLookback=7` | **O** |
| 최소 각도 **도(°)** | `InpMinAngleDeg` (사용자 설정, 디폴트 78.7) | **O** |
| SELL: 하향 기울기 | `angle_deg <= -InpMinAngleDeg` | **O** |
| BUY: 상향 기울기 | `angle_deg >= +InpMinAngleDeg` | **O** |
| 횡보 차단 | rise≈0 → angle≈0° → \|angle\| < 임계값 → **X** | **O** |

**각도 공식 (v3.11):**
```
rise      = EMA34[1] − EMA34[1+N]
ATR       = iATR(N)[1]
angle_deg = atan(rise / ATR) × 180 / π
```

**15:59 횡보 사례 (ATR≈2.5, rise≈0.04):** angle≈**0.9°** → 55° 임계값 **X (차단)** ✓

---

## 3. SELL 6항목 1:1 매핑

| # | 원본 | 함수/위치 | 검증 |
|---|------|----------|------|
| 1 | 데드크로스 | `DetectEmaCrossOnClosedBar` L707-711 | **O** |
| 2 | N봉 이내 | `IsObservationWindowExpired` | **O** |
| 3a | RSI 52↑ 엄격 돌파 | `IsRsiBreakoutAbove` → `g_rsi_armed` | **O** |
| 3b | RSI 48↓ 엄격 돌파 | `IsRsiBreakoutBelow` → `BeginWaitEmaPhase` | **O** |
| 4a | 9EMA **하향 돌파** | `IsSellEmaBreakthrough`: `low < 9EMA` | **O** |
| 4b | 종가 9EMA 아래 | `IsSellEmaCloseBelow` | **O** |
| 4c | 몸통>꼬리 | `IsBodyDominant` | **O** |
| 4d | RSI48↓ 포함 3봉 유예 | `g_rsi_trigger_time`, `g_grace_remaining` | **O** |
| 5 | 사이클 1회 | `g_entry_taken` | **O** |
| 6 | SELL만 | `g_cycle==CYCLE_SELL` | **O** |

**진입:** 셋업캔들 마감 → 신규봉 첫 틱 `OpenPositionAtSetupClose`

---

## 4. BUY 대칭 1:1 매핑

| # | 원본 | 코드 | 검증 |
|---|------|------|------|
| 1 | 골든크로스 | `DetectEmaCrossOnClosedBar` | **O** |
| 2 | N봉 | 관찰 윈도우 동일 | **O** |
| 3 | RSI 48↓→52↑ | `ProcessBuyRsiOnClosedBar` | **O** |
| 4 | 9EMA 상향 돌파+종가위+몸통 | `IsBuyEmaBreakthrough` (`high>9EMA`) 등 | **O** |
| 5~6 | 1회/BUY만 | `g_entry_taken`, `CYCLE_BUY` | **O** |

---

## 5. RSI 돌파 §2 1:1

| 원본 | 코드 | 검증 |
|------|------|------|
| 상향: prev≤기준 AND curr>기준 | `IsRsiBreakoutAbove` | **O** |
| 하향: prev≥기준 AND curr<기준 | `IsRsiBreakoutBelow` | **O** |
| 터치/체류 무효 | `g_rsi_seen_*` 없음 | **O** |

---

## 6. 금지 사항 1:1

| 금지 | 구현 | 검증 |
|------|------|------|
| 반대 방향 | `IsSetupEntryPermitted` | **O** |
| 관찰 초과 | `IsObservationWindowExpired` | **O** |
| 2회 진입 | `g_entry_taken` | **O** |
| 2회 RSI→EMA | `g_rsi_to_ema_used`, `EXHAUSTED` | **O** |
| 유예 초과 | `IsEmaGraceWindowExpired` | **O** |
| SL=0 | `ValidateInputs`, `ProtectAllPositionsStopLoss` | **O** |
| 포지션 중 크로스 | `HasOpenPosition` in `DetectEmaCross` | **O** |

---

## 7. 손익 1:1

| 원본 | 코드 | 검증 |
|------|------|------|
| SL 셋업 종가 기준 | `BuildInitialSL(setup_close)` | **O** |
| TP 없음 | OrderSend TP=0 | **O** |
| 트레일링 | `ManageTrailingStop` | **O** |

---

## 8. §8 필터 1:1

| 필터 | 파라미터 | 코드 | 검증 |
|------|----------|------|------|
| 9-50 이격 | `InpMinEmaSepPts=100` | `PassesEmaSeparationFilter` | **O** |
| EMA34 각도 | `InpMinAngleDeg` (**도**) | `GetEma34AngleDeg` + `PassesEmaAngleFilter` | **O** |

---

## 9. 파라미터 23개 전수

| # | 파라미터 | 연결 | UI만 |
|---|----------|------|------|
| 1-22 | (v3.09 동일) | 전부 사용 | 0 |
| 23 | `InpDebugBarLog` | `LogBarFilterStatus`, `LogEntryDone` | 0 |

**각도 관련 4개:**

| 파라미터 | 디폴트 | 단위 | 설명 |
|----------|--------|------|------|
| `InpUseEmaAngleFilter` | true | on/off | |
| `InpAngleEmaPeriod` | 34 | 봉 | EMA34 |
| `InpAngleLookback` | 7 | 봉 | |
| **`InpMinAngleDeg`** | **78.7** | **도(°)** | 사용자가 34, 55 등 직접 설정 |

---

## 10. 디버그 로그 (v3.10+ 유지)

| 항목 | 내용 |
|------|------|
| 시점 | `TryEntry` **직전** (판정 스냅샷) |
| 각도 | `Ang34=O(-36.5<=-55.0)` — **도 단위** |
| 체결 | `IDC_8\|ENTRY\|DONE\|SELL\|bar=...\|ticket=...` |

---

## 11. 각도 임계값 참고 (도)

| InpMinAngleDeg | 필요 조건 (대략) |
|----------------|-----------------|
| 34° | EMA34 7봉 변화 ≈ 0.67×ATR 이상 |
| 55° | ≈ 1.43×ATR |
| 78.7° | ≈ 5.0×ATR (매우 가파른 추세만) |

횡보(34EMA 수평): angle ≈ 0°~5° → **전 임계값에서 차단**

---

## 12. 정적 검증 체크리스트

| # | 항목 | 결과 |
|---|------|------|
| 1 | InpMinAngleDeg = 도(°) 파라미터 | **PASS** |
| 2 | v3.10 ATR 배수 파라미터 폐기 | **PASS** |
| 3 | v3.09 Point 각도 공식 폐기 | **PASS** |
| 4 | 횡보 34EMA 차단 (0° 근처) | **PASS** |
| 5 | SELL/BUY 6항목 매핑 | **PASS** |
| 6 | RSI/9EMA 원본 엄격 돌파 | **PASS** |
| 7 | 금지/손익/필터 | **PASS** |
| 8 | 로그 판정 직전 + ENTRY\|DONE | **PASS** |
| 9 | 파라미터 23개 전 연결 | **PASS** |

**종합: v3.11 원본전략 1:1 정적 검증 PASS**
