# IDC_3 전수 매핑·정밀 검수 보고서 (v1.01)

- EA: `MQL4/Experts/IDC_3.mq4` **v1.01**
- 전략서: `docs/IDC_3_전략서.md` v1.01
- 논리테스트: `simulation/idc3_logic_test.py` → 실행 결과 기준
- MT4 컴파일: 환경 미보유 → **미실행**

---

## 변경 (v1.01) — 사용자 명령

| # | 명령 | 조치 |
|---|------|------|
| 1 | 최초 원본전략대로 트레일링 보강 | Start 도달 → **SL=진입가(본전)**, 이후 Step 추종 |
| 2 | 돌파 마감 캔들#3 조건 추가 | **몸통 > 위심지 AND 몸통 > 아래심지** |

---

## A. 규칙 매핑

| ID | 규칙 | 코드 | 결과 |
|----|------|------|------|
| R01 | #2 ⊂ #1, 색 무관 | `h2 < h1 && l2 > l1` | 구현 |
| R03 | #3 종가 돌파 #2 | `c3 > h2` / `c3 < l2` | 구현 |
| R03c | #3 몸통>위심지 AND 몸통>아래심지 | `IsBodyLargerThanWicks` | **신규 구현** |
| R04 | #3 미돌파 취소 | CANCEL return | 구현 |
| R05 | 1포지션 | early return | 구현 |
| R06-TP | TP=0 | OrderSend TP=0 | 구현 |
| R06-Trail | Start→**진입가 본전**, Step 추종 | `lock_from_be = steps*Step` | **원본 복원** |
| VIS | #1파랑/#2빨강 | DrawSetupHL | 구현 |

### 트레일링 수식 (원본)

```
if profit < Start: 초기 SL 유지
steps = floor((profit - Start) / Step)
lock_from_BE = steps * Step          // Start 시 0 = 진입가
BUY : SL = Open + lock_from_BE
SELL: SL = Open - lock_from_BE
```

| 수익 | SL(BUY) |
|------|---------|
| 200 | Open (본전) |
| 210 | Open+10 |
| 220 | Open+20 |

### R03c 수식

```
body  = |C − O|
upper = H − max(O,C)
lower = min(O,C) − L
통과  = (body > upper) && (body > lower)   // 무조건, 등호 불허
```

---

## B. UI-only / 허위

- 신규 입력 파라미터 없음 (R03c는 고정 규칙, 토글 없음)
- UI-only 위장 파라미터: **0건** (섹션 라벨 제외)

---

## C. 한계

1. 초기 SL 기본 500pt (원문 수치 없음)
2. MT4 컴파일 미실행
3. 본전 SL=Open 시 스프레드로 즉시 스탑 가능(실거래 특성) — Guardian clamp 유지
