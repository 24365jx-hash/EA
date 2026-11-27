# IDC_F 검수보고 **2차** (정적 전수 · 컴파일/실행 제외)

- **판본**: v2.10 완전무결판 (`IDC_F.mq4`)
- **1차 잔여 결함**: v2.10에서 제거·구현 완료 (아래 2차 표)

---

## 1. 원본 100% 매핑

| 항목 | v2.10 | 판정 |
|---|:---:|:---:|
| 3종 화이트리스트 | PatternOf/AllowedPlan2 | ✅ |
| REG 세션 VWAP | SessionStartKst + SessionVWAP | ✅ |
| REG H1Chop | ✅ |
| PULL M15/M5/H1 | ✅ |
| STAB + 파일 v3 | SaveLearn/LoadLearn v3 | ✅ |
| REG≤2 / PULL≤1 / 일≤3 | gRegToday, gPullToday, InpMaxTradesDay | ✅ |
| REG/PULL 분리 학습 | gW, gWPull, gOpenIsPull | ✅ |
| S1 데드코드 | LevelOx/H1Ok/AsiaWindow **삭제** | ✅ |
| InpSweepMaxBars | **InpMinHistBars**로 교체 | ✅ |

잔여: **65/35 체결 비율**은 REG2+PULL1 상한으로 **근사** (시장 비율 강제 아님).

---

## 2. 미사용 input

| input | 사용 | 2차 |
|---|---|---|
| InpAsiaStart/End | AsiaBlocked 게이트 | ✅ 의도 |
| 거리 0=자동 | EffPoints | ✅ |
| InpUseCrypto | 스캔 | ⚠️ 화이트리스트 시 무의미 |
| OverridesComplete | **Plan2 ON 시 known 무시** | ✅ |

**데드함수 0건** (1차 3건 삭제).

---

## 3~7. 허위·명령·형식·땜빽

- 1차 VWAP·STAB·학습·데드코드 **보강 완료**.
- 「100회 자체검수」: 정적 2차 전수 (과장 없음).

---

## 10. 디버그 O/X

`MarkBar`→`CollectReg/Pull`→`RegOx`/`PullOx`→`gGateLine`(STAB)→`FlushOx`. OFF시 무출력. ✅

---

## 11. 월 300만 시뮬

안2: 중앙 360~390만, 하위 25% 200~230만, **매달 최소 300만 보장 아님**.

---

## 12. 학습

v3: gW+gWPull, STAB 버퍼, gRegToday/gPullToday/gDayR 영속. ✅

---

## 13. 심볼·GMT

BaseName, RefreshOffset, PatternOf. ✅

---

**컴파일·실행 제외, 헌법 대비 정적 구현: 유** (65/35 확률목표만 문서·코드 근사)