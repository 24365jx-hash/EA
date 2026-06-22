# IDC_5 원본전략 문서

## 1. 전략명

- EA 이름: `IDC_5`
- 현재 버전: `1.03`
- 전략명: GOLD M1 진행 구조 직전 스윙 실패돌파 핀바 전략
- 대상 차트: GOLD / M1

## 2. 전략 핵심

이 전략은 돌파 추종 전략이 아니다.

명확한 구조가 진행되다가 직전 스윙저점 또는 직전 스윙고점을 바늘처럼 실제로 찌르는 false breakout을 만들고, 종가로는 돌파마감하지 못한 채 기준선 안쪽에서 마감할 때 진입한다.

- LH/LL 하락 구조 진행 + 직전 스윙저점 아래로 실제 하향 스윕 후 그 라인 위에서 마감 + 긴 아래꼬리 + BUY 방향 컬러 확인 = BUY
- HL/HH 상승 구조 진행 + 직전 스윙고점 위로 실제 상향 스윕 후 그 라인 아래에서 마감 + 긴 위꼬리 + SELL 방향 컬러 확인 = SELL

TP는 사용하지 않는다. 수익 실현은 오직 트레일링 스탑으로만 처리한다.

## 3. 구조 레벨 정의

### 3.1 BUY 기준 구조

- 기준선은 직전 확정 스윙저점, 즉 가장 최근 LL이다.
- BUY 전에는 최근 스윙 고점이 LH이고 최근 스윙 저점이 LL인 하락 구조가 확인되어야 한다.
- 스윙 순서는 이전 고점 -> 이전 저점 -> 최근 LH -> 최근 LL 순서여야 한다.
- LH/LL의 최소 가격 차이는 `StructureBreakMinPoints` 이상이어야 한다.
- 최근 `StructureSearchBars` 범위 안에서 가장 가까운 확정 스윙저점을 BUY 기준선으로 본다.

### 3.2 SELL 기준 구조

- 기준선은 직전 확정 스윙고점, 즉 가장 최근 HH이다.
- SELL 전에는 최근 스윙 저점이 HL이고 최근 스윙 고점이 HH인 상승 구조가 확인되어야 한다.
- 스윙 순서는 이전 저점 -> 이전 고점 -> 최근 HL -> 최근 HH 순서여야 한다.
- HL/HH의 최소 가격 차이는 `StructureBreakMinPoints` 이상이어야 한다.
- 최근 `StructureSearchBars` 범위 안에서 가장 가까운 확정 스윙고점을 SELL 기준선으로 본다.

## 4. BUY 진입 조건

BUY는 아래 조건을 모두 만족해야 한다.

1. 차트 주기는 M1이어야 한다.
2. 새 봉이 시작된 시점에 직전 마감봉을 셋업캔들로 평가한다.
3. 최근 구조가 LH/LL 하락 구조여야 한다.
4. 직전 확정 스윙저점, 즉 최근 LL이 존재해야 한다.
5. 셋업캔들의 저가는 직전 스윙저점을 `MinFalseBreakoutPoints` 이상 실제로 하향 이탈해야 한다.
6. 하향 스윕 폭은 `MaxLevelSweepPoints`를 초과하면 안 된다.
7. 셋업캔들의 종가는 직전 스윙저점 위에서 마감해야 한다.
8. 셋업캔들은 긴 아래꼬리 핀바형이어야 한다.
9. 셋업캔들이 양봉이면 다음 새 봉 오픈 시점에 즉시 BUY 진입한다.
10. 셋업캔들이 양봉이 아니면 셋업캔들을 포함해 3개 캔들 안에서 양봉이 마감될 때 다음 새 봉 오픈 시점에 BUY 진입한다.
11. 현재 심볼과 매직넘버 기준 기존 포지션이 없어야 한다.

진입 시점:

- 조건을 만족한 셋업캔들이 마감된 뒤, 다음 새 봉 오픈 시점에 BUY 진입한다.

## 5. SELL 진입 조건

SELL은 아래 조건을 모두 만족해야 한다.

1. 차트 주기는 M1이어야 한다.
2. 새 봉이 시작된 시점에 직전 마감봉을 셋업캔들로 평가한다.
3. 최근 구조가 HL/HH 상승 구조여야 한다.
4. 직전 확정 스윙고점, 즉 최근 HH가 존재해야 한다.
5. 셋업캔들의 고가는 직전 스윙고점을 `MinFalseBreakoutPoints` 이상 실제로 상향 이탈해야 한다.
6. 상향 스윕 폭은 `MaxLevelSweepPoints`를 초과하면 안 된다.
7. 셋업캔들의 종가는 직전 스윙고점 아래에서 마감해야 한다.
8. 셋업캔들은 긴 위꼬리 핀바형이어야 한다.
9. 셋업캔들이 음봉이면 다음 새 봉 오픈 시점에 즉시 SELL 진입한다.
10. 셋업캔들이 음봉이 아니면 셋업캔들을 포함해 3개 캔들 안에서 음봉이 마감될 때 다음 새 봉 오픈 시점에 SELL 진입한다.
11. 현재 심볼과 매직넘버 기준 기존 포지션이 없어야 한다.

진입 시점:

- 조건을 만족한 셋업캔들이 마감된 뒤, 다음 새 봉 오픈 시점에 SELL 진입한다.

## 6. 핀바 셋업캔들 정의

### 6.1 BUY 셋업캔들

- 아래꼬리가 `MinTailPoints` 이상이어야 한다.
- 아래꼬리가 전체 캔들 길이 대비 `MinSignalWickPercent`% 이상이어야 한다.
- 종가는 직전 스윙저점 위에서 마감해야 한다.
- BUY 방향 컬러는 양봉이다.
- 셋업캔들이 양봉이 아니면 이후 2개 마감봉 안에서 양봉 확인을 기다린다.

### 6.2 SELL 셋업캔들

- 위꼬리가 `MinTailPoints` 이상이어야 한다.
- 위꼬리가 전체 캔들 길이 대비 `MinSignalWickPercent`% 이상이어야 한다.
- 종가는 직전 스윙고점 아래에서 마감해야 한다.
- SELL 방향 컬러는 음봉이다.
- 셋업캔들이 음봉이 아니면 이후 2개 마감봉 안에서 음봉 확인을 기다린다.

## 7. 주문 관리

### 7.1 진입

- BUY 진입 가격: Ask
- SELL 진입 가격: Bid
- 주문 수량: `Lots`
- 허용 슬리피지: `SlippagePoints`
- 매직넘버: `MagicNumber`

### 7.2 초기 SL

- BUY 초기 SL: 진입가 - `StopLossPoints`
- SELL 초기 SL: 진입가 + `StopLossPoints`
- 모든 수치는 브로커 포인트 기준이다.

### 7.3 TP

- TP는 설정하지 않는다.
- `OrderSend`와 `OrderModify` 모두 TP 값을 `0.0`으로 유지한다.

## 8. 트레일링 규칙

트레일링은 사용자가 확정한 2번 방식이다.

### 8.1 BUY 트레일링

1. 현재 Bid 기준 수익이 `TrailingStartPoints` 이상이 되면 트레일링을 시작한다.
2. 시작 즉시 SL을 `진입가 + TrailingStartPoints` 위치로 이동한다.
3. 이후 추가 수익이 발생하면 `TrailingStepPoints` 단위로 SL을 더 위로 이동한다.

공식:

```text
profitPoints = (Bid - entryPrice) / Point
lockedPoints = TrailingStartPoints
             + floor((profitPoints - TrailingStartPoints) / TrailingStepPoints)
             * TrailingStepPoints
newSL = entryPrice + lockedPoints * Point
```

### 8.2 SELL 트레일링

1. 현재 Ask 기준 수익이 `TrailingStartPoints` 이상이 되면 트레일링을 시작한다.
2. 시작 즉시 SL을 `진입가 - TrailingStartPoints` 위치로 이동한다.
3. 이후 추가 수익이 발생하면 `TrailingStepPoints` 단위로 SL을 더 아래로 이동한다.

공식:

```text
profitPoints = (entryPrice - Ask) / Point
lockedPoints = TrailingStartPoints
             + floor((profitPoints - TrailingStartPoints) / TrailingStepPoints)
             * TrailingStepPoints
newSL = entryPrice - lockedPoints * Point
```

예시:

- `TrailingStartPoints = 200`
- `TrailingStepPoints = 10`
- BUY 수익이 +200포인트에 도달하면 SL은 진입가 +200포인트로 이동한다.
- BUY 수익이 +210포인트에 도달하면 SL은 진입가 +210포인트로 이동한다.
- SELL도 반대 방향으로 동일하게 적용한다.

## 9. 입력 파라미터 역할

| 파라미터 | 역할 |
| --- | --- |
| `Lots` | 주문 수량 |
| `MagicNumber` | IDC_5 포지션 식별 번호 |
| `SlippagePoints` | 주문 허용 슬리피지 |
| `StopLossPoints` | 초기 손절 거리 |
| `TrailingStartPoints` | 트레일링 시작 수익 및 최초 수익 고정 거리 |
| `TrailingStepPoints` | 트레일링 SL 이동 간격 |
| `StructureSearchBars` | 직전 구조 고점/저점 탐색 범위 |
| `SwingDepthBars` | 확정 스윙 고점/저점 판정 깊이 |
| `MinFalseBreakoutPoints` | 유효 false breakout으로 인정할 최소 라인 찌름 거리 |
| `MaxLevelSweepPoints` | 구조선 돌파 실패로 인정할 최대 꼬리 스윕 폭 |
| `StructureBreakMinPoints` | LH/LL 또는 HL/HH 구조 진행으로 인정할 최소 스윙 간 가격 차이 |
| `MinTailPoints` | 핀바 꼬리 최소 길이 |
| `MinSignalWickPercent` | 신호 꼬리가 전체 캔들에서 차지해야 하는 최소 비율 |
| `DebugSignalFilters` | 진입 조건 탈락 사유 로그 출력 여부 |

## 10. 사용하지 않는 규칙

IDC_5 원본전략에는 아래 항목을 넣지 않는다.

- 고정 TP
- 마틴게일
- 물타기
- 그리드
- 보조지표 필터
- 돌파 추종 진입
- 양방향 동시 보유
- 같은 심볼/매직넘버 중복 포지션

## 11. 1:1 매핑 체크리스트

| 원본전략 조건 | IDC_5 구현 기준 |
| --- | --- |
| GOLD M1 전략 | M1 차트에서만 신규 진입 평가 |
| 명확한 하락 구조 BUY | 최근 스윙 고점은 LH, 최근 스윙 저점은 LL이어야 함 |
| 명확한 상승 구조 SELL | 최근 스윙 저점은 HL, 최근 스윙 고점은 HH이어야 함 |
| 직전 저점 돌파 실패 BUY | 셋업캔들 저가가 직전 스윙저점을 실제 하향 이탈 후 종가가 저점 위에서 마감 |
| 직전 고점 돌파 실패 SELL | 셋업캔들 고가가 직전 스윙고점을 실제 상향 이탈 후 종가가 고점 아래에서 마감 |
| BUY 셋업은 긴 아래꼬리 핀바 | 아래꼬리 최소 길이 및 전체 캔들 대비 비율 검사 |
| SELL 셋업은 긴 위꼬리 핀바 | 위꼬리 최소 길이 및 전체 캔들 대비 비율 검사 |
| BUY 컬러 조건 | 셋업캔들이 양봉이거나 셋업 포함 3개 캔들 안에서 양봉 확인 |
| SELL 컬러 조건 | 셋업캔들이 음봉이거나 셋업 포함 3개 캔들 안에서 음봉 확인 |
| TP 없음 | 주문 및 수정 시 TP 0.0 |
| 트레일링 2번 방식 | 시작 수익 도달 시 진입가 +/- 시작포인트로 SL 이동 |
| 포인트 단위 SL/트레일링 | 모든 거리 계산에 `Point` 사용 |
| 유령 파라미터 없음 | 모든 입력값이 검증 또는 전략 로직에 연결 |
