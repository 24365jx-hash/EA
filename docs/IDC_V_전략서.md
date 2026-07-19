# IDC_V 전략서 (완전명세) v1.0

**플랫폼:** MetaTrader 4 전용  
**타임프레임:** M5 고정 (M5 아니면 초기/가동 거부)  
**대상 심볼:** XAUUSD(골드) 계열 — 브로커 접미사 자동감지  
**EA명:** IDC_V  

본 문서는 구현·검수의 **유일한 기준 스펙**이다. 코드는 본 전략서 항목을 100% 충족해야 한다.

---

## 0. 설계 원칙

| ID | 원칙 |
|----|------|
| P01 | 거리·버퍼·슬리피지 등 **가격 간격 파라미터는 전부 포인트** |
| P02 | 포인트 정의: Digits 2/4 → `Point`, Digits 3/5 → `Point*10` (브로커 통일) |
| P03 | TP **사용 금지** (항상 0). 청산은 **SL 또는 트레일링 SL**만 |
| P04 | 원본 영상 스트래들 골격 + 사용자 개선규칙 동시 적용 |
| P05 | UI에 존재하는 모든 기능 파라미터는 반드시 실코드에 연결 |
| P06 | 데드코드·유령 오브젝트·허위 패널 표기 금지 |

---

## 1. 진입 전략 (스트래들)

### 1.1 주문 구성
- 동시에 **Buy Stop 1개 + Sell Stop 1개**만 보유 가능 (동일 magic·심볼).
- Limit 주문 사용 금지.

### 1.2 라인 간격 (핵심 파라미터)
| 항목 | 내용 |
|------|------|
| 파라미터 | `InpStopLineGapPts` |
| 디폴트 | **200 포인트** |
| 의미 | **Buy Stop 가격 − Sell Stop 가격 = 200pt** |
| 배치 | 현재 mid`(Ask+Bid)/2` 기준 상·하 대칭: 각 **Gap/2** |
| 사용자 | 변경 가능 (최소 2pt, 짝수 권장; 홀수면 아래쪽 floor) |

계산:
```
half = floor(InpStopLineGapPts / 2)
BuyStop  = Normalize(Ask + half_points)   // 또는 mid+half, 브로커 StopLevel 충족 시
SellStop = Normalize(Bid - half_points)
실제 간격이 StopLevel/스프레드로 부족하면 Guardian이 최소 간격까지 확대 (아래 5장)
```

### 1.3 초기 SL
| 파라미터 | 디폴트 | 의미 |
|----------|--------|------|
| `InpSLPoints` | **150** | 진입가 기준 SL 거리(pt). **TP 없음** |

- BuyStop SL = BuyStop − SL_pts  
- SellStop SL = SellStop + SL_pts  

### 1.4 대기주문 유지(리앵커)
- **신규 스트래들 배치:** M5 봉당 최대 1회.
- **같은 봉·포지션 없음·pending 존재:** 현재가 기준으로 Buy/Sell Stop 가격·SL을 **Modify로 재정렬** 허용.  
  → 이는 “추가 진입”이 아니라 **동일 셋업 유지**다.
- 스프레드 초과·세션 종료·일손실 히트 시 pending 전량 삭제.

---

## 2. 진입 제한 규칙 (강제)

| ID | 규칙 | 동작 |
|----|------|------|
| R01 | 매봉 단 1진입 | 동일 M5 봉에서 **포지션 체결(진입)은 최대 1회** |
| R02 | OCO | Buy/Sell 중 **먼저 체결된 쪽만 유지**. 반대 pending **즉시 삭제** |
| R03 | 청산 전 재진입 금지 | 우리 magic 포지션이 1개라도 있으면 스트래들 배치·리앵커·추가진입 **전부 금지** |
| R04 | 동시 포지션 1개 | Buy+Sell 동시 보유 금지. 감지 시 나중/반대 정리(pending 삭제 우선, 비상 시 로그) |

---

## 3. 청산 / 트레일링 (TP 없음)

### 3.1 금지
- Take Profit 가격 설정 금지 (pending·포지션 모두 TP=0).

### 3.2 초기 SL
- 사용자 `InpSLPoints` (디폴트 150).
- 브로커 StopLevel/Freeze보다 작으면 **브로커 최소 + pad**로만 확대 (Guardian). 그 외 사용자 값 유지.

### 3.3 트레일링
| 파라미터 | 디폴트 | 동작 |
|----------|--------|------|
| `InpTrailStartPts` | **200** | 평가익 ≥ 200pt 되는 순간 SL을 **진입가 ± 200pt**로 이동 |
| `InpTrailStepPts` | **10** | 이후 `start + floor((profit-start)/step)*step` 격자 추격 |

Buy 예시 (Start=200, Step=10):
- +200pt → SL = entry+200  
- +209pt → SL = entry+200  
- +210pt → SL = entry+210  
- +225pt → SL = entry+220  

Sell은 대칭.

---

## 4. 세션 / 일손실 / 랏

### 4.1 거래시간
| 파라미터 | 디폴트 |
|----------|--------|
| 사용 | true |
| 시작 GMT | **13:00** |
| 종료 GMT | **16:00** |

- 브로커 GMT 오프셋 **자동감지** (`TimeCurrent−TimeGMT`, 분 단위 포함 가능하면 분 단위).
- 세션 외: pending 전부 취소.  
- `InpCloseOutsideHrs`(디폴트 false): true면 세션 외 포지션 시장가 청산.

### 4.2 일일 손실 %
| 파라미터 | 디폴트 |
|----------|--------|
| `InpDailyLossPercent` | **5.0** |
| `InpStopOnDailyLoss` | true |

- 기준: 당일 시작 equity 대비 현재 equity 낙폭 %.
- 히트 시: 신규 배치 금지 + pending 취소. (포지션 강제청산은 `InpCloseOnDailyLoss`, 디폴트 false)

### 4.3 랏
| 모드 | 파라미터 | 디폴트 |
|------|----------|--------|
| 자동 | `InpUseAutoLot=true`, `InpRiskPercent` | 1.0% |
| 수동 | `InpFixedLot` | 0.01 |
| 상한 | `InpMaxLot` | 5.0 |

자동: `risk_money / (SL거리의 1랏 손실금)`.

---

## 5. SL Guardian (실기능 명세)

`InpUseSLGuardian=true`(디폴트)일 때만 아래 전부.

| ID | 기능 |
|----|------|
| G01 | 스프레드 > `InpMaxSpreadPts`(80) → 신규 배치 거부, `InpCancelOnWideSprd`면 pending 취소 |
| G02 | 배치/리앵커 시 StopLevel+Freeze+`InpSpreadBufferPts`+스프레드 반영한 **최소 간격** 보장 |
| G03 | SL에 `InpSLPadPts`(5) 가산한 브로커 최소거리 미만 금지 |
| G04 | 체결 후 SL=0 발견 시 즉시 사용자 SL(또는 최소)로 복구 |
| G05 | 트레일 전, SL이 브로커 최소보다 가까우면 **밖으로만** 확장 |
| G06 | Guardian OFF면 G01–G05 비활성. 오프셋은 순수 `Gap/2`만 사용 |

---

## 6. 심볼·시간·포인트 자동감지

| ID | 내용 |
|----|------|
| A01 | `InpForcedSymbol` 우선. 공백이면 차트 심볼이 골도면 사용 |
| A02 | 아니면 XAU/GOLD 후보·MarketWatch 스캔 |
| A03 | 골드 심볼 확정 실패 시 **INIT_FAILED** |
| A04 | GMT 오프셋 OnInit + 매 시간 재계산 |
| A05 | M5 아니면 **INIT_FAILED** (테스터/차트 모두) |

---

## 7. 디폴트값 표 (골드 최적)

| 파라미터 | 디폴트 | 단위 |
|----------|--------|------|
| StopLineGap | **200** | pt |
| SL | **150** | pt |
| TrailStart | **200** | pt |
| TrailStep | **10** | pt |
| MaxSpread | 80 | pt |
| SpreadBuffer | 15 | pt |
| SLPad | 5 | pt |
| Slippage | 30 | pt |
| Session GMT | 13:00–16:00 | — |
| DailyLoss | 5 | % |
| AutoLot Risk | 1 | % |
| FixedLot | 0.01 | lot |
| Magic | 260719 | — |

---

## 8. 상태머신

```
FLAT_NO_PENDING
  ├─ (세션OK ∧ ¬일손실 ∧ 스프레드OK ∧ 새M5봉배치가능) → PlaceStraddle → FLAT_PENDING
  └─ else wait

FLAT_PENDING
  ├─ 포지션 체결 감지 → CancelOpposite → IN_POSITION
  ├─ 같은 셋업 리앵커(Modify) 허용
  ├─ 세션끝/스프레드/일손실 → CancelAll → FLAT_NO_PENDING
  └─ 봉 전환 후에도 pending 유지 시 리앵커만 (신규 Place는 봉당 1회 플래그로 제어)

IN_POSITION
  ├─ Trailing / Guardian SL
  ├─ 신규 진입·pending 배치 금지
  └─ 포지션 청산 → FLAT_NO_PENDING (해당 봉 재진입 금지 if 같은 봉)
```

---

## 9. 구현 금지 / 필수

### 금지
- TP 설정
- 그리드·마틴·헤지 추가매수
- 섹션 헤더 외 “기능 없는 기능 파라미터”
- Comment에 실제 TF와 다른 고정 문자열 거짓말
- 생성하지 않은 차트 오브젝트 Delete

### 필수
- 본 전략서 §1–§8 전 항목 코드 대응
- 프리셋 `IDC_V_XAUUSD_M5.set` 디폴트 동기화
- 전수검사 시 본 문서 ID로 1:1 매핑 가능해야 함

---

## 10. 원본 영상 대비 명시적 채택/변경

| 원본 | IDC_V |
|------|-------|
| Buy/Sell Stop 스트래들 | 채택 |
| 라인 간격 ≈190pt | **200pt 디폴트·사용자설정** |
| SL ≈150pt | 채택 |
| 고정 TP ≈1250pt | **폐기 → 트레일링** |
| 고빈도 다건 스캘프 | **폐기 → 1포지션·봉당1진입** |
| pending 잦은 재호가 | **리앵커 Modify로 채택(진입 아님)** |
| 뉴욕 세션 | GMT 13–16 디폴트 |

---

**문서 끝. 이 버전(v1.0)이 코딩 락 스펙이다.**
