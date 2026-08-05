# IDC_7 (MT4)

XAUUSD(골드) 전용 M1 Expert Advisor.

## 전략 요약

1. **연속 틱** N회(기본 6) 동일 방향
2. **이동 거리** P포인트(기본 200) 이상
3. **강한 추세 필터**(ATR/EMA, ON/OFF) 통과  
→ 현재가 ± Pending Distance에 **BuyStop / SellStop** 발주  
→ M1 캔들 내 미체결 시 자동 취소 / 단일 포지션  
→ SL 300 + 2단계 트레일링(본전→스텝 추격) + SL 가디언

## 파일

| 경로 | 설명 |
|---|---|
| `MQL4/Experts/IDC_7.mq4` | EA 소스 (MT4) |
| `MQL4/Presets/IDC_7_XAUUSD_M1.set` | 기본 프리셋 |
| `docs/IDC_7_SPEC_MAPPING_AUDIT.md` | 원본전략 전수 매핑·검수 보고 |
| `tools/mql4_static_check.py` | 정적 문법/미사용 input 검사 |

## 설치

1. `IDC_7.mq4`를 MT4 `MQL4/Experts/`에 복사
2. MetaEditor에서 컴파일(F7)
3. 골드 심볼 **M1** 차트에 부착, AutoTrading ON

## 정적 검사

```bash
python3 tools/mql4_static_check.py MQL4/Experts/IDC_7.mq4
```
