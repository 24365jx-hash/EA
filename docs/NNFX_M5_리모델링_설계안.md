# NNFX-M5 Remodel 설계안

## 문서 목적

오리지널 NNFX(D1)의 **역할 분리 Decision Tree**는 유지하되, 실행 레이어를 **M5**로 옮겨  
**거래 빈도를 높이고 정확도(품질)를 동시에 올리는** 리모델링 설계안이다.

본 문서는 구현 전 **아키텍처·탐색 공간·검증 프로토콜·수용 기준**을 고정한다.  
구체 지표 “정답 조합”은 수만 조합 서치 후 확정한다(설계 단계에서 임의 고정하지 않음).

---

## 1. 설계 목표 (OKR)

| 목표 | D1 원본 | M5 Remodel 목표 | 측정 |
|------|---------|-----------------|------|
| 거래 빈도 | 페어당 월 수 회 수준 | **페어당 일 2~8회** (세션 필터 후) | trades/day, trades/week |
| 정확도 | 추세 구간 기대값 중심 | **승률↑보다 Expectancy↑** + PF 안정 | Expectancy, PF, Avg R |
| 비용 민감도 | 낮음 | **스프레드/커미션 후** 기대값 > 0 | net expectancy |
| 과최적화 방지 | 수동 스크리닝 | **Walk-Forward + OOS 게이트** | WFE, OOS/IS 비율 |
| 자동화 | 역할 슬롯 | **조합 서치 엔진 + 라이브 EA** | 파이프라인 통과 여부 |

### 비목표
- 마틴게일/그리드/복구 로직 금지
- “만능 단일 지표” 금지
- D1 설정을 M5에 그대로 복붙하는 접근 금지

---

## 2. D1 → M5 이식 문제와 해결 원칙

| D1 가정 | M5에서 깨지는 지점 | Remodel 대응 |
|---------|-------------------|--------------|
| 봉 노이즈 낮음 | 가짜 교차·스파이크 증가 | **HTF 바이어스(H1/H4)** + 세션 필터 |
| ATR 폭이 큼 | 스프레드 대비 SL 여유가 큼 | **최소 R:스프레드 비율**, ATR 하한 |
| 신호 희소 | 신호가 과도하게 폭증 | **품질 게이트**로 빈도/정확도 동시 제어 |
| 뉴스 영향 상대적 | M5는 뉴스에 즉시 붕괴 | **뉴스 블랙아웃 창** |
| 1/7 Candle Rule | 7×5분=35분은 너무 짧음 | **시간 정규화 규칙**으로 재정의 |
| 완성봉만 | 동일 | 유지(진행봉 금지) |

### 핵심 원칙
1. **역할 슬롯은 유지** (Baseline / C1 / C2 / V1 / Exit / ATR)
2. **시간축만 압축하지 말고, 멀티타임프레임으로 재구성**
3. **빈도↑는 트리거 완화, 정확도↑는 필터 강화**로 분리 제어
4. **수만 조합 서치는 전수 무차별이 아니라 계층형(stage) 탐색**

---

## 3. 타깃 시스템 아키텍처: `NNFX-M5-Hybrid`

```
                    ┌─────────────────────────┐
                    │  H4/H1 Regime Bias      │  ← 정확도 축 (방향·국면)
                    │  (Baseline-HTF)         │
                    └───────────┬─────────────┘
                                │ allow long/short/flat
                                ▼
┌──────────────┐   trigger    ┌─────────────────────────┐
│ M5 C1 Signal │ ───────────► │ M5 Decision Tree        │
└──────────────┘              │  C2 + V1 + Micro-ATR    │
                              │  Session + Spread Gate  │
                              └───────────┬─────────────┘
                                          │ pass
                                          ▼
                              ┌─────────────────────────┐
                              │ ATR-M5 Risk Engine      │
                              │  2-split / BE / Trail   │
                              └───────────┬─────────────┘
                                          │
                                          ▼
                              ┌─────────────────────────┐
                              │ Exit Stack              │
                              │  Exit-M5 OR HTF invalidate│
                              └─────────────────────────┘
```

### 레이어 정의

| 레이어 | TF | 역할 | 빈도/정확도 |
|--------|----|------|-------------|
| L0 Regime | H4 | 추세/비추세 국면 | 정확도↑ (횡보 차단) |
| L1 Bias | H1 | 매수/매도 허용 방향 | 정확도↑ |
| L2 Trigger | M5 | C1 셋업 발생 | 빈도↑ |
| L3 Confirm | M5 | C2 + Volume | 정확도↑ |
| L4 Cost Gate | M5 | 스프레드·ATR·세션 | 정확도↑ (비용) |
| L5 Manage | M5 | SL/TP/BE/Trail/Exit | 기대값↑ |

> D1의 단일 Baseline을 **HTF Bias + M5 Baseline(선택)** 으로 분해한다.  
> 빈도는 L2에서, 정확도는 L0/L1/L3/L4에서 만든다.

---

## 4. M5용 Decision Tree 리모델링

### 4.1 진입 게이트 (모두 AND)

1. **Regime OK** (H4): 추세 국면만 (또는 약한 추세 허용 모드는 별도 서치)
2. **Bias OK** (H1): 가격이 HTF Baseline 허용 측
3. **C1 Signal** (M5): 주 확인 시그널 (완성봉)
4. **C2 Agree** (M5)
5. **V1 Agree** (M5) — tick volume / real volume 프록시
6. **Micro-Baseline 근접** (옵션 슬롯): `|close - BL| ≤ k·ATR_M5`
7. **Timing Rule** 통과
8. **Cost Gate** 통과: `ATR_M5 / spread ≥ MinATRSpreadRatio`
9. **Session Gate** 통과
10. **News Blackout** 통과

### 4.2 타이밍 규칙 (D1 규칙의 시간 정규화)

원본:
- 1-Candle Rule ≈ 1일
- 7-Candle Rule ≈ 7일

M5 Remodel (기본안, 서치 가능):

| 규칙 | D1 | M5 기본 제안 | 탐색 범위 |
|------|----|--------------|-----------|
| Fresh Confirm | 1 candle | **N_fresh = 3~12** M5봉 | {3,6,9,12} |
| Signal Expiry | 7 candles | **N_expire = 24~96** M5봉 (2~8시간) | {24,36,48,72,96} |
| HTF Align Lookback | n/a | H1 bias가 **M_h1**봉 내 유지 | {1,2,4,8} |

의미:
- C1 발생 후 필터가 안 맞으면 **N_fresh**봉까지만 재확인
- C1이 **N_expire**보다 오래되면 셋업 폐기

### 4.3 진입 유형 (M5 재정의)

| 유형 | 빈도 | 정확도 | 사용 권장 |
|------|------|--------|-----------|
| A. HTF-Aligned Standard | 중 | 고 | **주력** |
| B. M5 Baseline Cross + HTF agree | 중고 | 중고 | 주력 후보 |
| C. Micro Pullback to M5 BL | 고 | 중 | 빈도 보강 |
| D. Continuation (같은 Bias 유지) | 고 | 중저 | 리스크 캡 있을 때만 |
| E. Mean-reversion 반전 | — | — | **금지**(NNFX 철학 이탈) |

빈도 목표를 맞추는 기본 믹스:
- **A+B 필수**, C는 서치에서 채택 여부 결정, D는 일일 최대 추가진입 제한.

---

## 5. 자금관리 리모델링 (M5 ATR Engine)

### 5.1 유지할 NNFX DNA
- 2분할 주문
- 1차 TP 후 BE
- 잔여 추세 추적
- 고정 % 리스크 (마틴 금지)

### 5.2 M5 기본 파라미터 (탐색 중심값)

| 파라미터 | D1 원본 | M5 기본안 | 탐색 그리드 |
|----------|---------|-----------|-------------|
| ATR period | 14 | **14 / 21** | {7,14,21,28} |
| SL | 1.5×ATR | **1.2~1.8×ATR** | {1.0,1.2,1.5,1.8,2.0} |
| TP1 | 1.0×ATR | **0.8~1.2×ATR** | {0.6,0.8,1.0,1.2} |
| Trail arm | 2.0×ATR | **1.5~2.5×ATR** | {1.5,2.0,2.5} |
| Trail width | 1.5×ATR | **1.0~1.5×ATR** | {1.0,1.2,1.5} |
| Risk/trade | 2% (1+1) | **0.5~1.0%** 총 | {0.25+0.25, 0.5+0.5} |
| Max concurrent | n/a | **심볼당 1~2** | {1,2} |
| Max/day/symbol | n/a | **4~10** | {4,6,8,10} |

### 5.3 비용·품질 하드 게이트 (정확도 핵심)

```
allow_entry iff
  spread <= MaxSpreadPoints
  AND ATR_M5 >= MinATR
  AND ATR_M5 / spread >= MinATRSpreadRatio   # 기본 8~15
  AND expected_TP1_net > 0                     # TP1 - spread*2 - commission
```

M5에서 승률이 높아도 **비용 후 기대값이 음수**면 탈락시킨다.

### 5.4 세션 필터 (빈도↑와 정확도↑의 교집합)

기본 허용(브로커 서버시간 기준으로 매핑):
- London open ~ NY mid (유동성 구간)
- Asian은 **별도 서치 플래그**(페어별로만 허용)

블랙아웃:
- High-impact news ±N분 (기본 15~30)
- 롤오버 전후
- 스프레드 급등 구간

---

## 6. 지표 유니버스와 “수만 조합” 탐색 설계

### 6.1 역할별 후보 풀 (예시 규모)

| 슬롯 | 후보 수(목표) | 파라미터 변형 | 유효 변형 대략 |
|------|---------------|---------------|----------------|
| HTF Bias (H1/H4) | 20 | 3~5 | ~80 |
| M5 Baseline | 25 | 4 | ~100 |
| C1 | 60 | 3 | ~180 |
| C2 | 60 | 3 | ~180 |
| V1 | 20 | 2 | ~40 |
| Exit | 25 | 3 | ~75 |
| ATR/MM 프로파일 | — | 12 | 12 |

단순 전수:
`80 × 100 × 180 × 180 × 40 × 75 × 12 ≈ 10^14` → **불가능**

따라서 **계층형 탐색 + 상관 가지치기 + 베이지안/진화 탐색**을 사용한다.  
“수만 가지”는 **평가하는 유효 조합 수(최종 스테이지 누적)** 목표로 둔다.

### 6.2 지표 패밀리(중복 제거용 태그)

각 후보에 태그를 붙여 C1/C2 동시 채택 시 **같은 패밀리 금지**:

- Trend MA: SMA/EMA/DEMA/TEMA/KAMA/HMA/VWMA
- Channel: BB/Keltner/Donchian
- Momentum Osc: RSI/Stoch/CCI/ROC/CMO
- Trend Strength: ADX/DMI/Aroon/SuperTrend
- Volatility Break: ATR% / WAE / Bollinger Width
- Volume: OBV/MFI/VPCI/tick-vol SMA slope
- Cycle/Other: Fisher/MACD hist/Schaff

규칙:
- C1∈Momentum 이면 C2는 TrendStrength/Volume/Channel 우선
- Baseline과 C1이 모두 MA 교차면 감점

### 6.3 3-Stage Combinatorial Search

```
Stage-0  Feature Screening (단변량)
  - 각 슬롯 후보를 "단독 + 고정 베이스라인"으로 단기 평가
  - Top-K only 생존
  목표 평가수: 2,000~5,000

Stage-1  Pairwise / Triple Build
  - HTF Bias × C1 × (ATR profile)
  - 이후 +C2, +V1 순차 부착
  - 상관 가지치기 적용
  목표 평가수: 10,000~30,000

Stage-2  Full Tree + MM Refine
  - 생존 알고리즘에 Exit/세션/타이밍/리스크 그리드
  - Walk-Forward 필수
  목표 평가수: 3,000~10,000

Total evaluated ≈ 15,000~45,000  (요청의 "수만 가지")
```

### 6.4 목적함수 (정확도·빈도 동시)

단일 Profit Factor만 쓰면 저빈도 과적합이 난다. **다목적 스코어**:

```
Score =
  w1 * Expectancy_R
+ w2 * ProfitFactor_capped
+ w3 * Sharpe_like
+ w4 * FrequencyScore          # 목표 밴드 안이면 1, 벗어나면 감점
- w5 * MaxDD
- w6 * StabilityPenalty        # 파라미터 이웃 민감도
- w7 * CostDrag                # spread/commission 영향
```

FrequencyScore 예시:
- 목표: 심볼당 주 10~40 trades
- `<10` 또는 `>60`이면 큰 감점 (과도 매매/무거래 방지)

기본 가중치(시작점):
`w1=0.30, w2=0.20, w3=0.15, w4=0.15, w5=0.10, w6=0.05, w7=0.05`

### 6.5 과최적화 방어

1. **Walk-Forward**: IS 3개월 / OOS 1개월 롤링, ≥8 윈도우
2. **OOS 게이트**: OOS Expectancy ≥ 0.15×IS, OOS PF ≥ 1.1
3. **Cross-symbol**: 학습 심볼 외 2개 이상에서 부호 일치
4. **Perturbation**: 파라미터 ±10%  Perturb 시 Score 유지율 ≥ 70%
5. **Monte-Carlo trade shuffle**: DD 분포 꼬리 점검
6. **Embargo**: 뉴스/갭 구간 성과 분리 리포트

통과 못하면 “최고 수익 조합”이라도 **기각**.

---

## 7. 데이터·백테스트 프로토콜

### 7.1 데이터
- TF: M5 실행, H1/H4 바이어스
- 기간: 최소 **3년** (가능하면 5년)
- 비용: **실스프레드 or 보수적 고정 + 커미션**
- 심볼 우선순위(저장소 EA 맥락 고려): XAUUSD, 주요 FX 5종, 인덱스 1종(옵션)

### 7.2 실행 가정
- 시그널: **직전 완성봉**
- 체결: 다음 봉 시가 (또는 시가+슬리피지 모델)
- 슬리피지: 심볼별 고정 포인트 + ATR 비례 옵션

### 7.3 리포트 필수 지표
- Net Profit, PF, Expectancy(R), WinRate, Avg Win/Loss
- Trades/day, Trades/week
- MaxDD, Ulcer, Recovery Factor
- Avg holding time
- Spread drag %, News-window loss share
- IS vs OOS vs Forward

---

## 8. 소프트웨어 설계 (구현 단위)

### 8.1 모듈

| 모듈 | 설명 |
|------|------|
| `indicator_registry` | 역할·패밀리·파라미터 스키마 등록 |
| `signal_adapters` | 각 지표 → `{side, signal, agree}` 표준 인터페이스 |
| `decision_tree_m5` | L0~L5 게이트 엔진 |
| `risk_engine_atr` | 2분할/BE/Trail/로트 |
| `combo_search` | Stage0~2 탐색 오케스트레이터 |
| `wfo_runner` | Walk-Forward / OOS 게이트 |
| `report_builder` | 리더보드·탈락 사유·상위 N 조합 |
| `nnfx_m5_ea` | 최종 채택 조합 라이브 EA |

### 8.2 표준 시그널 인터페이스

```text
struct SlotSignal {
  int    side;        // +1 long, -1 short, 0 none
  bool   is_signal;   // C1/Baseline cross 등 "이벤트"
  bool   agrees;      // 필터 동의
  double strength;    // 0..1 optional
  int    age_bars;    // 시그널 경과 봉수
}
```

모든 지표는 이 인터페이스로만 Decision Tree에 연결한다 → **수만 조합 스왑 가능**.

### 8.3 탐색 가속
- 지표 버퍼 사전 계산(feature cache)
- 조합은 시그널 불리언 연산만 수행
- 조기 중단: 최소 거래수 미달 / DD 상한 / 비용게이트 실패 시 abort
- 병렬 워커(심볼·스테이지 단위)

### 8.4 산출물 아티팩트
```
artifacts/nnfx_m5/
  universe.json
  stage0_leaderboard.csv
  stage1_leaderboard.csv
  stage2_wfo_leaderboard.csv
  selected_algo.json
  selected_algo_report.md
```

---

## 9. 정확도↑ + 빈도↑를 동시에 만드는 제어판

| 노브 | 빈도 영향 | 정확도 영향 | 기본 방향 |
|------|-----------|-------------|-----------|
| HTF Bias 강도 | ↓ | ↑↑ | **강하게 ON** |
| C2 필수 | ↓ | ↑ | ON |
| V1 필수 | ↓ | ↑ | ON |
| N_expire 확대 | ↑ | ↓ | 중 |
| Pullback Entry 허용 | ↑ | ↓~ | 조건부 |
| MinATRSpreadRatio | ↓ | ↑↑ | **높게** |
| Session filter | ↓(나쁜 시간 제거) | ↑ | ON |
| Continuation Entry | ↑↑ | ↓ | 캡과 함께 |
| SL 타이트화 | 승률↓/빈도≈ | 기대값 ? | 서치 |

운영 정책:
- 빈도 부족 시: Pullback ON, N_expire↑, Session 확대
- 정확도 부족 시: HTF 강화, V1 강화, MinATRSpreadRatio↑, Continuation OFF

즉 **한 노브로 둘 다 올리지 않고, 상충 노브를 분리 튜닝**한다.

---

## 10. 권장 롤아웃 로드맵

### Phase A — 설계 고정 (본 문서)
- 슬롯/게이트/목적함수/WFO 프로토콜 확정

### Phase B — 서치 인프라
- registry + adapters + combo_search + report
- 소규모 smoke (100조합)로 파이프라인 검증

### Phase C — 대규모 서치
- Stage0~2로 1.5만~4.5만 조합 평가
- 상위 20 → WFO → 상위 3

### Phase D — Forward
- 데모/소액 2~4주
- 라이브 슬리피지·스프레드 드리프트 모니터링

### Phase E — Freeze
- `selected_algo.json` 동결
- 분기 1회만 재서치 (연속 재최적화 금지)

---

## 11. 수용 기준 (Go / No-Go)

심볼 1개 기준(예: XAUUSD M5) 1차 게이트:

| 지표 | Go |
|------|----|
| OOS Profit Factor | ≥ 1.20 |
| OOS Expectancy | ≥ +0.10 R |
| MaxDD (OOS) | ≤ 15% (리스크 설정 전제)
| Trades/week | 10~40 |
| Avg trade duration | 20분~6시간 밴드 |
| Spread drag | 총 gross의 ≤ 35% |
| WFO 통과 윈도우 | ≥ 70% |
| Cross-symbol 부호 | ≥ 2/3 양수 expectancy |

미달 시: 지표를 더 찾기보다 **게이트/세션/비용 모델**을 먼저 재설계.

---

## 12. 원본 NNFX 대비 변경 요약

| 항목 | Original NNFX | NNFX-M5 Remodel |
|------|---------------|-----------------|
| 실행 TF | D1 | **M5** |
| 방향 필터 | D1 Baseline | **H4 Regime + H1 Bias (+ optional M5 BL)** |
| 확인 | C1/C2/V1 | 동일 슬롯, **패밀리 비중복 강제** |
| 타이밍 | 1/7 candles | **시간 정규화 N_fresh / N_expire** |
| 빈도 | 낮음 | **트리거 M5 + pullback/continuation 옵션** |
| 정확도 | 다층 확인 | **+HTF + session + cost gate + WFO** |
| 조합 선택 | 수동 소수 | **계층형 수만 조합 서치** |
| 리스크 | 2%급 | **축소(0.5~1.0%) + 일일 캡** |

---

## 13. 결론 (설계 결정)

1. D1 NNFX를 M5에 그대로 이식하지 말고, **HTF 정확도 레이어 + M5 빈도 레이어**로 분리한다.
2. 거래 빈도는 C1/Pullback 등 **트리거**로, 정확도는 HTF·C2·V1·비용게이트로 **독립 제어**한다.
3. 지표 정답은 미리 고르지 않는다. **역할 슬롯 + 패밀리 제약 + Stage0~2 서치 + WFO**로 상위 조합을 고른다.
4. 성공 기준은 수익 최대화가 아니라 **OOS Expectancy·빈도 밴드·비용 후 기대값**이다.

이 설계안이 승인되면 다음 구현 단위는 `indicator_registry` + `decision_tree_m5` + `combo_search` 스켈레톤이다.

---

## 부록 A. 초기 서치 시드(예시, 확정 아님)

> 아래는 서치 시작용 시드일 뿐, 최종 채택이 아니다.

- HTF Bias: EMA(50) H1 / KAMA H4
- M5 Baseline: HMA / TEMA
- C1 pool seed: ROC, Schaff, TSI, RSI MA cross, SuperTrend flip
- C2 pool seed: ADX-DMI, Aroon, CCI, WaveTrend
- V1: MFI, OBV slope, tick-vol z-score
- Exit: opposite C1, WAE fade, Chandelier

## 부록 B. 위험 고지

본 문서는 시스템 설계안이며 투자 권유가 아니다.  
M5는 비용·슬리피지·레짐 변화에 민감하므로, 서치 우승 조합도 Forward 검증 없이 실계좌 투입하지 않는다.
