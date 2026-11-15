# IDC_3 v1.03 — 진입/몸통 버그 재검수 보고

## 사용자 지적
1. 마감(종가) 돌파 없이 멋대로 진입
2. 돌파캔들 몸통 조건이 전혀 안 먹힘

---

## 원인 (허위 없음)

### A. 몸통 조건 — **실버그(완화 해석)**
| 항목 | 내용 |
|------|------|
| 구 식 (v1.01–1.02) | `body > upper AND body > lower` (각 심지) |
| 문제 | 몸통이 심지 **합**보다 작아도 통과 가능 (예: body30, up20, dn15 → 구식 PASS) |
| 체감 | “조건이 전혀 안 먹힌다” |
| 신 식 (v1.03) | `body > upper AND body > lower AND body > (upper+lower)` |

### B. 종가 돌파 — **소스상 Close만 사용 중**
| 항목 | 내용 |
|------|------|
| 구 코드 | `c3 > h2` / `c3 < l2` (Close) — High/Low로 방향 결정 안 함 |
| 약점 | wick-only를 **명시 차단·상시 로그**하지 않음 → 심지 돌파 캔들과 혼동 여지 |
| 신 코드 | wick-only 명시 CANCEL + Experts 상시 Print + OpenMarket 직전 재검증 |

### C. 기타 가능 원인 (은폐 금지)
- **구버전 .ex4** 재컴파일 없이 실행 중이면 몸통 필터 자체가 없음
- 진입 시점은 #3 **마감 후** 다음봉 시가 — 차트상 #3 진행 중 심지와 착각 가능

---

## v1.03 수정

1. 종가 돌파만 (`IsCloseBreakBuy/Sell`) — High/Low 진입 근거 금지  
2. wick-only (고저만 돌파·종가 미돌파) → **무조건 CANCEL + Print**  
3. 몸통: `body > up+dn` (합) 포함 엄격화  
4. `OpenMarket` 직전 Close돌파·몸통 **재검증** (우회 불가)  
5. SIGNAL/CANCEL/OPEN 근거 OHLC **상시 Print**

---

## 검증
`python3 simulation/idc3_logic_test.py` → **PASS**  
MT4 컴파일: 환경 없음 → 미실행. **반드시 MetaEditor로 v1.03 재컴파일 후 재부착**.
