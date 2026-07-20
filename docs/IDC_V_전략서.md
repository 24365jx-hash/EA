# IDC_V 전략서 (완전명세) v1.1

**플랫폼:** MetaTrader 4 전용  
**타임프레임:** M5 고정 (M5 아니면 초기/가동 거부)  
**대상 심볼:** XAUUSD(골드) 계열 — 브로커 접미사 자동감지  
**EA명:** IDC_V  

본 문서는 구현·검수의 **유일한 기준 스펙**이다.  
**v1.1 변경:** §1.4 리앵커(가격 추격 Modify) **폐기**. 대기주문은 **배치 후 가격 고정**만 허용.  
(v1.0 리앵커는 체결 불능을 유발하는 잘못된 스펙이었음 — 폐기·금지)

---

## 0. 설계 원칙

| ID | 원칙 |
|----|------|
| P01 | 거리·버퍼·슬리피지 등 **가격 간격 파라미터는 전부 포인트** |
| P02 | 포인트 정의: Digits 2/4 → `Point`, Digits 3/5 → `Point*10` |
| P03 | TP **사용 금지** (항상 0). 청산은 **SL 또는 트레일링 SL**만 |
| P04 | 원본 작동 스트래들 = **고정 BuyStop/SellStop** + 사용자 개선(트레일·1진입 등) |
| P05 | UI 기능 파라미터는 반드시 실코드 연결 |
| P06 | 데드코드·유령 오브젝트·허위 보고 금지 |
| P07 | **대기주문 가격을 시세 따라 Modify/추격하는 행위 절대 금지** |

---

## 1. 진입 전략 (스트래들)

### 1.1 주문 구성
- 동시에 **Buy Stop 1개 + Sell Stop 1개**만 보유 (동일 magic·심볼).
- Limit 주문 사용 금지.

### 1.2 라인 간격
| 항목 | 내용 |
|------|------|
| 파라미터 | `InpStopLineGapPts` |
| 디폴트 | **200 포인트** |
| 의미 | mid 기준 상·하 각 Gap/2 → BuyStop−SellStop ≈ Gap |
| 배치 시점 | **Place 순간에만** 현재 mid로 계산 |
| 사용자 | 변경 가능 (최소 2pt) |

```
half = floor(InpStopLineGapPts / 2)
mid  = (Ask + Bid) / 2
BuyStop  = mid + half   (Ask 위, StopLevel 충족)
SellStop = mid - half   (Bid 아래, StopLevel 충족)
```

### 1.3 초기 SL
| 파라미터 | 디폴트 |
|----------|--------|
| `InpSLPoints` | **150** |

- BuyStop SL = BuyStop − SL  
- SellStop SL = SellStop + SL  
- **TP = 0 (없음)**

### 1.4 대기주문 유지 (고정 — 리앵커 금지)
- M5 봉당 **신규 Place 최대 1회** (해당 봉에 아직 place/entry 없을 때).
- Place 이후 BuyStop/SellStop **가격·SL 고정**.  
  - `OrderModify`로 진입가를 시세 추격 **금지**.
  - 시세가 라인에 닿을 때까지 대기 → 체결.
- pending 삭제 허용 조건만:
  1. 한쪽 체결(OCO)로 반대 삭제  
  2. 세션 종료  
  3. 일손실 히트(차단 ON)  
  4. 스프레드 초과(Guardian + Cancel ON)  
  5. EA 제거/수동

---

## 2. 진입 제한

| ID | 규칙 |
|----|------|
| R01 | 동일 M5 봉 **포지션 체결 최대 1회** |
| R02 | OCO — 선체결만 유지, 반대 pending 즉시 삭제 |
| R03 | 포지션 보유 중 신규 스트래들·추가진입 금지 |
| R04 | Buy+Sell 동시 포지션 금지 (발생 시 신규 쪽 정리) |

---

## 3. 청산 / 트레일링 (TP 없음)

| 파라미터 | 디폴트 | 동작 |
|----------|--------|------|
| `InpTrailStartPts` | **200** | 평가익 ≥ Start → SL = 진입 ± Start |
| `InpTrailStepPts` | **10** | `start + floor((profit-start)/step)*step` 추격 |

---

## 4. 세션 / 일손실 / 랏

| 항목 | 디폴트 |
|------|--------|
| 세션 필터 | true, GMT **13:00–16:00** |
| 일손실 | 5%, StopOnDailyLoss true, CloseOnDailyLoss false |
| 랏 | Auto 1% / Fixed 0.01 / Max 5.0 |

- GMT 오프셋 자동감지 (초).  
- 세션 외: pending 취소.  
- **주의:** GMT 시각 ≠ 차트 시각. 오프셋만큼 변환됨.

---

## 5. SL Guardian

Guardian ON일 때만:

| ID | 기능 |
|----|------|
| G01 | 스프레드 > Max → 신규 Place 거부, Cancel ON이면 pending 취소 |
| G02 | **Place 시** StopLevel+버퍼로 최소 half 보장 |
| G03 | SL 최소거리+pad |
| G04 | 체결 후 SL=0 복구 |
| G05 | 트레일 전 SL 최소거리 밖 확장 |
| G06 | OFF면 G01–G05 비활성, Gap/2·사용자 SL만 |

---

## 6. 자동감지

| ID | 내용 |
|----|------|
| A01–A03 | Forced / 골드 스캔 / 실패 INIT_FAILED |
| A04 | GMT 오프셋 OnInit + 매시간 |
| A05 | M5 아니면 INIT_FAILED |

---

## 7. 디폴트

| 파라미터 | 값 |
|----------|-----|
| StopLineGap | **200** pt |
| SL | **150** pt |
| TrailStart / Step | **200 / 10** pt |
| Session GMT | 13:00–16:00 |
| DailyLoss | 5% |
| MaxSpread | 80 pt |

---

## 8. 상태머신

```
FLAT_NO_PENDING
  → (조건OK ∧ 봉당 place 가능) PlaceStraddle → FLAT_PENDING

FLAT_PENDING
  → 가격 고정 대기 (Modify 추격 없음)
  → 체결 → OCO → IN_POSITION
  → 세션끝/스프레드/일손실 → CancelAll → FLAT_NO_PENDING

IN_POSITION
  → Trailing / Guardian
  → 청산 → FLAT_NO_PENDING
```

---

## 9. 금지 / 필수

### 금지
- TP  
- 그리드·마틴·헤지 추가매수  
- **pending 시세 추격 Modify (리앵커)**  
- 허위 전수검사 보고  

### 필수
- 고정 스트래들 체결 가능 구조  
- 본 문서 v1.1 ↔ 코드 1:1  

---

## 10. 원본 대비

| 원본 | IDC_V v1.1 |
|------|------------|
| Buy/Sell Stop 스트래들 | 채택 (**가격 고정**) |
| 갭 ≈190pt | 200pt 디폴트 |
| SL ≈150pt | 채택 |
| 고정 TP | 폐기 → 트레일 |
| 다건 스캘프 | 폐기 → 1포지션·봉당1진입 |
| 영상 중 HyperActivity 재호가 | **채택 금지** (체결 파괴) |
| 뉴욕 세션 | GMT 13–16 디폴트 |

---

**문서 끝. v1.1이 코딩 락 스펙이다. v1.0 리앵커 조항은 무효.**
