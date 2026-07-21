# EA Repository

## IDC_Assistant

MT4 전용 SL/Trailing 화면 패널 EA (TP 없음).

- Expert: `MQL4/Experts/IDC_Assistant.mq4`
- Spec: `docs/IDC_Assistant_SPEC.txt`
- Audit: `docs/MAPPING_AUDIT.md`

### 설치

1. `IDC_Assistant.mq4`를 MT4 `MQL4/Experts/`에 복사
2. MetaEditor에서 컴파일 → `IDC_Assistant.ex4`
3. 차트에 부착 후 패널에서 SL / Trail Start / Step / Lots 설정
4. BUY / SELL / CLOSE ALL 사용

### 핵심 동작

- 트레일: Start 도달 즉시 기준가±Start로 SL 이동 후 Step 간격 Floor 추격
- 물타기(DCA): 최초 진입가 기준 동일 절대가 SL/트레일
- 불타기(PYR): 각 진입가 기준 독립 SL/트레일
- SL 가디언: STOPLEVEL/FREEZELEVEL 보정 + 누락 SL 주입
