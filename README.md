# IDC_3 (MT4) — GOLD M1 Inside Bar System

원본 전략 100% 구현 EA.

| 항목 | 경로 |
|------|------|
| EA | [`MQL4/Experts/IDC_3.mq4`](MQL4/Experts/IDC_3.mq4) **v1.00** |
| 전략서(스펙 락) | [`docs/IDC_3_전략서.md`](docs/IDC_3_전략서.md) |
| 전수 매핑 검수 | [`docs/IDC_3_MAPPING_AUDIT.md`](docs/IDC_3_MAPPING_AUDIT.md) |
| 프리셋 | [`MQL4/Presets/IDC_3_XAUUSD_M1.set`](MQL4/Presets/IDC_3_XAUUSD_M1.set) |
| 논리 단위테스트 | `python3 simulation/idc3_logic_test.py` |

## 핵심 규칙

1. #2가 #1 고저 안에 **완전 포함** (색 무관)
2. #3 **종가**가 #2(빨간 라인) 돌파 시 해당 방향 진입
3. #3 미돌파 시 **즉시 취소** (다음 봉 대기 없음)
4. 포지션 1개만 / **TP 없음** / SL + 트레일(200pt→본전, step 추종)

차트 라인: **#1 파랑 / #2 빨강**.

## Install

1. `IDC_3.mq4` → `MQL4/Experts/`
2. MetaEditor 컴파일
3. **XAUUSD M1** 차트에 부착 (AutoTrading ON)
4. 선택: 프리셋 로드
