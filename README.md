# IDC_M — Session Flow Rider (MT4)

**안 B** 전략 · EA 이름 **IDC_M** · MetaTrader 4 전용.

## 파일

| 경로 | 설명 |
|------|------|
| `docs/IDC_M_CONSTITUTION_LOCK.md` | 헌법락 · 전략 원본 · 매핑 테이블 |
| `MQL4/Experts/IDC_M.mq4` | **완전본 EA** (단일 파일) |

## 설치

1. `IDC_M.mq4` → `MetaTrader 4/MQL4/Experts/`
2. 메타에디터에서 컴파일 (F7)
3. 차트에 부착 (권장: `USTEC` 또는 `XAUUSD` — **M5**)
4. `InpTradeSymbol`을 브로커 심볼명에 맞게 수정 (기본 `US100`)

## 기본 프리셋

- 트레일: **200 / 200 / 10** (포인트)
- 뉴스: **Guardian만** (`InpNewsGuardian=true`, 완전 차단 없음)
- 랏: 리스크 **0.5%** (고정 랏으로 변경 가능)

## 참고

- MQL5 폴더는 초기 초안으로 **사용하지 않음** (MT4만 사용).
- 실거래 전 데모·시각화 검증 필수 (헌법 문서 §4 테스트 보고).