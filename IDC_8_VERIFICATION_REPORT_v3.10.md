# IDC_8 v3.10 — 각도 필터 수정 + 로그 수정 검증 보고

**EA:** `IDC_8.mq4` v3.10  
**기준:** 사용자 컴펌 원본전략 + 15:59 SELL 로그 분석 결과

---

## 1. 수정 사항

### 1.1 EMA34 기울기 필터 (B-ANGLE)

| 항목 | v3.09 (오류) | v3.10 (수정) |
|------|-------------|-------------|
| 공식 | `atan(rise/(N×Point))×180/π` | `(EMA34[1]-EMA34[1+N]) / ATR(N)[1]` |
| 단위 | 가짜 도(°) — 금 M1에서 과대·불안정 | ATR 배수 (무차원) |
| 디폴트 | 78.7° | **1.0** (7봉 EMA 변화 ≥ 1×ATR) |
| 횡보 | $0.04 변동 → -80° 통과 (오류) | slope≈0.02 → **차단** |
| SELL | angle ≤ −임계값 | slope_atr ≤ −임계값 |
| BUY | angle ≥ +임계값 | slope_atr ≥ +임계값 |

**코드:** `GetEmaSlopeAtrRatio` L473-498, `PassesEmaAngleFilter` L500-521

### 1.2 디버그 로그 (B-LOG)

| 항목 | v3.09 (오류) | v3.10 (수정) |
|------|-------------|-------------|
| 출력 시점 | `TryEntry` **후** (ResetSetupState 이후) | `TryEntry` **직전** |
| Ph/SetupOK/ENTRY | 체결 후 IDLE/X/X 오표시 | 판정 시점 WAIT_EMA/O/O 정확 |
| 체결 확인 | 없음 | `IDC_8\|ENTRY\|DONE\|SELL\|bar=...\|ticket=...` |
| 각도 키 | `Ang=-80.8°` | `SlopeATR=-0.05` |

**코드:** `ProcessSetupLogicOnNewBar` — RSI 처리 → `LogBarFilterStatus()` → `TryEntry`

---

## 2. 15:59 사례 재검증 (수정 후 예상)

| 항목 | v3.09 로그 | v3.10 예상 |
|------|-----------|-----------|
| SlopeATR | -80.8° (가짜) | ≈ 0.02~0.15 (횡보) |
| SlopeATR 필터 (1.0) | O (오통과) | **X (차단)** |
| Ph at log | IDLE (사후) | WAIT_EMA (판정 시) |
| SetupOK at log | X (사후) | 판정 시점 정확 |
| 진입 | 발생 | **차단** (횡보 34EMA) |

---

## 3. §8.2 원본 의도 매핑

| 원본 의도 | v3.10 구현 | 검증 |
|-----------|-----------|------|
| 34EMA 횡보 차단 | \|slope_atr\| < 1.0 → 차단 | **O** |
| SELL 하향 추세만 | slope_atr ≤ −1.0 | **O** |
| BUY 상향 추세만 | slope_atr ≥ +1.0 | **O** |
| 파라미터 on/off | `InpUseEmaAngleFilter` | **O** |

---

## 4. 파라미터 주의

**`InpMinAngleDeg` 이름 유지, 의미 변경:**

| 값 | v3.09 (도) | v3.10 (ATR 배수) |
|----|-----------|-----------------|
| 78.7 | 구 공식 | **무효** — init 경고 |
| 55.0 (사용자 설정) | 구 공식 | **무효** — init 경고, 전부 차단 |
| **1.0** (신규 디폴트) | — | 7봉 EMA ≥ 1×ATR 기울기 |

재부착 시 **InpMinAngleDeg = 1.0** 으로 재설정 권장.

---

## 5. 로그 사용법

```
IDC_8|BAR|2026.07.06 15:59|Ph=WAIT_EMA|...|SlopeATR=X(0.08<=-1.00)|ENTRY=X|Taken=X
IDC_8|ENTRY|DONE|SELL|bar=2026.07.06 15:59|ticket=642991750   ← 체결 시만
```

- `BAR` 줄 = **진입 판정 직전** 스냅샷
- `ENTRY|DONE` = 실제 체결 확인

---

## 6. 정적 검증

| # | 항목 | 결과 |
|---|------|------|
| 1 | 구 도(degree) 공식 제거 | **PASS** |
| 2 | ATR 정규화 기울기 | **PASS** |
| 3 | 로그 판정 직전 출력 | **PASS** |
| 4 | ENTRY\|DONE 체결 로그 | **PASS** |
| 5 | 원본 RSI/9EMA/유예 로직 유지 | **PASS** |
| 6 | init 구 임계값 경고 | **PASS** |

**종합: v3.10 정적 검증 PASS**
