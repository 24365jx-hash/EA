# IDC_D

`IDC_D` is an MT4 Expert Advisor designed for GOLD/XAUUSD M1/M5 operation.

## 핵심 조건

- MT4 전용
- GOLD/XAUUSD 계열 전용
- M1 진입 + M5 추세/변동성 보조 필터
- 모든 핵심 거리 설정은 포인트 단위
- 기본 기준: 20핍 = 200포인트
- TP 미사용
- 가격이 진입가에서 `LockProfitTriggerPoints` 만큼 유리하게 이동하면 SL을 즉시 `LockProfitPoints` 위치로 이동
- 이후 `TrailStepPoints` 단위로 SL을 추격
- 정규 진입, 당일 보조 진입, 최종 1일 1회 방향성 진입 엔진
- 당일 손실 거래 1회 발생 시 신규 진입 중단
- 같은 방향 손실 후 당일 같은 방향 재진입 차단
- M5 EMA 기울기/되돌림 필터로 고점 이후 꺾이는 BUY, 저점 이후 꺾이는 SELL 억제
- 차트 상태 패널과 진입 차단 사유 표시
- 마틴게일, 물타기, 그리드 금지
- 일일 손실 제한은 Balance 기준 `%` 입력값으로 제어

## 파일 구조

```text
experts/IDC_D.mq4                  MT4 EA source
experts/IDC_D.ex4                  MT4 compiled EA binary
simulation/idc_d_simulator.py      독립 시뮬레이션/검증 도구
simulation/reports/*.md            생성된 검증 리포트
```

## MT4 컴파일 결과

`experts/IDC_D.ex4`는 Wine 환경에서 Pepperstone MT4의 `metaeditor.exe`로 직접 컴파일했습니다.

```text
Result: 0 errors, 0 warnings
```

## v2.1 기본 검증 결과

공개 데이터 제약 때문에 브로커 XAUUSD tick 데이터가 아닌 Yahoo Finance `GC=F` 데이터를 GOLD 프록시로 사용했습니다.

- 8일 1분 프록시: PASS
  - 8 활성일 중 7일 거래
  - 5일 20핍 잠금
  - 승률 71.4%
  - Profit Factor 1.46
  - 순 포인트 +355
  - 최대 폐쇄거래 DD 385포인트
  - 최악 일일 손익 -385포인트
- 60일 5분 프록시: PASS
  - 50 활성일 중 50일 거래
  - 31일 20핍 잠금
  - 승률 62.0%
  - Profit Factor 2.01
  - 순 포인트 +6,450
  - 최대 폐쇄거래 DD 2,010포인트
  - 최악 일일 손익 -335포인트

최종 실거래 전에는 반드시 사용 브로커의 MT4 Strategy Tester에서 XAUUSD M1 고품질 히스토리로 재검증해야 합니다.

## 시뮬레이션 실행

공개 GC=F 1분 데이터:

```bash
python3 simulation/idc_d_simulator.py --range 8d --interval 1m \
  --report simulation/reports/idc_d_validation_v21_8d_1m_proxy.md
```

공개 GC=F 5분 장기 프록시:

```bash
python3 simulation/idc_d_simulator.py --range 60d --interval 5m \
  --report simulation/reports/idc_d_validation_v21_60d_5m_proxy.md
```

MT4에서 내보낸 XAUUSD M1 CSV:

```bash
python3 simulation/idc_d_simulator.py --csv path/to/XAUUSD_M1.csv \
  --report simulation/reports/idc_d_validation_broker_m1.md
```

기본값 고정 검증 요약:

```text
simulation/reports/idc_d_v21_default_validation.md
```

## EA 설치

1. `experts/IDC_D.ex4`를 MT4의 `MQL4/Experts` 폴더에 복사합니다.
2. 소스 수정이 필요하면 `experts/IDC_D.mq4`도 함께 복사 후 MetaEditor에서 컴파일합니다.
3. GOLD/XAUUSD 계열 M1 차트에 부착합니다.
4. 기본값으로 테스트 후 브로커 스프레드/StopLevel에 맞게 조정합니다.

## 주의

EA는 월 수익이나 매일 수익을 보장하지 않습니다. `IDC_D`는 하루 20핍 확보를 목표로 설계되었지만, 스프레드 확대, 슬리피지, 뉴스 급등락, 브로커 StopLevel/FreezeLevel 때문에 SL 이동이 지연될 수 있습니다.
