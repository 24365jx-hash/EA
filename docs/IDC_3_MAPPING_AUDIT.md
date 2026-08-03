# IDC_3 v1.02 — 정밀 전수 매핑 검수 (락)

- 대상: `MQL4/Experts/IDC_3.mq4` (`#property version "1.02"`)
- 스펙: `docs/IDC_3_전략서.md` v1.02
- 논리테스트: `python3 simulation/idc3_logic_test.py` → **PASS**
- MT4 컴파일: **미실행**

---

## v1.02 추가 명령 매핑

| 명령 | 코드 | 판정 |
|------|------|------|
| #1/#2 라인 **색 커스터마이즈** | `InpLine1Color` / `InpLine2Color` → `DrawLevelSegment` | **OK** |
| #1/#2 라인 **선종류 커스터마이즈** | `InpLine1Style` / `InpLine2Style` (enum→STYLE_*) | **OK** |
| 선 두께 | `InpLineWidth` 1..5 (OnInit 검증) | **OK** |
| **#1 이전(1캔들 전) 미표시** | `OBJ_TREND` t_from=`t_mother`~`t_trigger`, `RAY_LEFT=false` | **OK** |
| 전차트 HLINE 폐기 | `OBJ_HLINE` 코드 **없음** | **OK** |

신규 입력 UI-only: **0건** (`InpSecLines` 섹션 라벨만 uses=0)

---

## 1. 원본전략 ↔ 코드 전수 매핑

| ID | 원본/명령 | 구현 | 판정 |
|----|-----------|------|------|
| R01 | #2 ⊂ #1 | `h2 < h1 && l2 > l1` | **OK** |
| R01b | #1·#2 색 무관 | #1/#2 O/C 미사용 | **OK** |
| R03 | #3 종가 돌파 | `c3 > h2` / `c3 < l2` | **OK** |
| R03c | 몸통>위·아래 심지 | `IsBodyLargerThanWicks` | **OK** |
| R04 | #3만, 미돌파 취소 | CANCEL | **OK** |
| R05 | 1포지션 | OnTick early return | **OK** |
| R06-TP | TP=0 | OrderSend TP=0 | **OK** |
| R06-Trail | Start→진입가 본전→Step | `lock_from_be=steps*Step` | **OK** |
| VIS | #1/#2 커스텀, #1~#3만 | DrawLevelSegment | **OK** |
| TF | M1 | INIT_FAILED if not | **OK** |

---

## 2. UI-only / 허위 / 불복종

| 검사 | 결과 |
|------|------|
| 위장 파라미터 | **0건** (섹션 라벨 제외) |
| 허위 미구현 | **0건** |
| 현재 명령 불복종 | **0건** |
| MT4 실기 | 미검증 |

## 3. 한계
초기 SL 기본 500 · 세션 기본 OFF · R03c=각각 비교 · 본전=Open · MT4 컴파일 미실시
