# EA — Single-MA FX Monthly Income Strategy

검증 기반 제출 문서: **[STRATEGY.md](./STRATEGY.md)**

## 한 줄 요약

**GBPUSD · D1 · WMA(21) 가격 플립 · RR 2.5 · 리스크 1%/거래 · 원금 $4,000 보존형 월 인출**

초기 $4,000로는 생활비 대체 불가(검증상 월 중앙값 약 $20–40).  
목표를 “매달 흑자에 가까운 빈도(≈60%+ 양성 월) + 생존”으로 두고, 복리 후 인출을 스케일하는 설계.

## 재현

```bash
pip install -r requirements.txt
python -m strategy.research
```

결과 파일은 `results/`에 저장된다.

## 패키지

| 경로 | 역할 |
|------|------|
| `strategy/indicators.py` | SMA/EMA/WMA/JMA(근사) — 항상 1개만 사용 |
| `strategy/backtest.py` | 백테스트·월별 인출·워크포워드 |
| `strategy/research.py` | 데이터 수집·그리드·챔피언 선정 |
| `STRATEGY.md` | 전략 제출서 (규칙·검증·운영) |
