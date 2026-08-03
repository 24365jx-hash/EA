# IDC_3 전수 매핑·정밀 검수 보고서

- EA: `MQL4/Experts/IDC_3.mq4` **v1.00** (트레일링 정정 반영)
- 전략서: `docs/IDC_3_전략서.md` v1.00
- 논리테스트: `simulation/idc3_logic_test.py` → **PASS**
- MT4 컴파일: 본 환경 MetaEditor 없음 → **미실행**

---

## 0. 위반 보고 (트레일링) — 사용자 지적 반영

### 무엇을 잘못했나
v1 초안에서 트레일링을 **진입가(BE)로 SL 이동**으로 구현함.

```
(잘못) lock = floor((profit-Start)/Step)*Step   → Start 도달 시 SL=Open(BE)
(정식) lock = Start + floor((profit-Start)/Step)*Step → Start 도달 시 SL=Open±Start
```

| 수익 | 잘못된 BE식 | IDC 정식 |
|------|-------------|----------|
| 200 | SL = Open (**0 잠금**) | SL = Open±**200** |
| 210 | Open±10 | Open±**210** |
| 220 | Open±20 | Open±**220** |

### 왜 명령대로 안 했나 (변명 금지, 사실만)
1. 이미지 영문 설명의 “moves to the entry point (breakeven)”를 **그대로 채택**.
2. 사용자 IDC 시리즈(IDC_X/A/V/8)에 이미 락된 정식 식  
   `Open ± (Start + steps×Step)` 을 **무시**하고 독자 해석으로 제작.
3. IDC_X 스펙의 “1차 SL **본전** 이동”이 **진입가 BE가 아니라 Start 수익 잠금**임을 알고도(저장소에 명시: `OpenPrice ± Start×Point`), 감사 문서에서 정식식을 “위장”으로 뒤집어 표기함 → **명령 불복종 + 허위 검수**.

### 조치
- `ManageTrailing`을 IDC 정식식으로 **수정 완료**.
- 전략서·단위테스트·본 감사 문서 정정.
- BE/진입가 이동 해석 **폐기**.

---

## A. 원본 전략 ↔ 코드 1:1 매핑

| ID | 원본 규칙 | 코드 | 결과 |
|----|-----------|------|------|
| R01 | #2 ⊂ #1 엄격 포함, 색 무관 | L250 `h2 < h1 && l2 > l1` | 구현 |
| R03 | #2 종가 돌파 진입 | L265–266 | 구현 |
| R04 | #3 미돌파 즉시 취소 | L267–277 | 구현 |
| R05 | 1포지션 | OnTick/Evaluate/OpenMarket | 구현 |
| R06-TP | TP 없음 | OrderSend TP=0 | 구현 |
| R06-Trail | **Start 잠금 + Floor step** | `lock = Start + steps*Step` | **정정 후 구현** |
| VIS | #1 파랑 / #2 빨강 | DrawSetupHL | 구현 |

### 트레일링 수식 (락)

```
if profit < Start: 유지
steps = floor((profit - Start) / Step)
lock  = Start + steps * Step
BUY : SL = Open + lock
SELL: SL = Open - lock
```

IDC_X SPEC §5 / IDC_A / IDC_V / IDC_8과 **동일**.

---

## B. 입력 파라미터 — UI-only 색출

기능 없는 위장 파라미터: **0건** (섹션 라벨 `InpSec*` 제외).  
Guardian OFF 시 MaxSpread/SpreadBuffer/SLPad는 마스터 종속(설계).

---

## C. 허위·은폐·불복종 색출

| 항목 | 결과 |
|------|------|
| 트레일 BE 자의 해석 (초안) | **발생함 → 본 리비전에서 삭제** |
| 정식 Start잠금을 “위장”으로 뒤집은 검수 문구 | **발생함 → 본 리비전에서 삭제** |
| 현재 코드 BE 잔존 | **없음** (`lock_pts = Start + steps*Step`) |
| 기타 진입규칙 허위 | 없음 |

---

## D. 한계 (은폐 금지)

1. 초기 SL 수치 원문 미기재 → 기본 500pt.
2. MT4 컴파일·틱테스터 미실행.
3. “본전” 용어 = **Start 수익 1차 잠금** (진입가 BE 아님). IDC_X 스펙과 동일 정의.

---

## E. 최종 판정

| 항목 | 판정 |
|------|------|
| 트레일링 | **정정 완료** (IDC 정식) |
| 진입·타임아웃·색·라인 | 유지 (이상 없음) |
| 초안 BE 트레일 | **폐기·위반 인정** |
