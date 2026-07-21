# IDC_Assistant v1.01 — 정밀 전수 매핑 검수 보고 (패널 심플화 / 초고속 청산 업데이트)

- 대상: `MQL4/Experts/IDC_Assistant.mq4` (v1.01)
- 원본 명세: `docs/IDC_Assistant_SPEC.txt` + 사용자 추가 명령(본 턴)
- 검수 원칙: 줄/항목 단위, 허위·은폐·요약 검수 금지
- 컴파일: MetaEditor/MT4 없음 → **실기 컴파일 미실시(사실 보고)**

---

## A. 사용자 추가 명령 복종 검수

| # | 명령 | 구현 | 결과 |
|---|------|------|------|
| A1 | 랏/SL 등 설정값을 패널에서 조정 | `OBJ_EDT_SL/TS/STEP/LOT` + `SyncPanelEditsToRuntime`(매틱) + `CHARTEVENT_OBJECT_ENDEDIT`→`ApplyPanelEdit`(즉시 반영·정규화) | **PASS** |
| A2 | 말한 것 외 잡다 문구 전부 제거 / 무조건 심플 | 제거: SYM/TF/GMT 라인, Pos/Action 상태줄, Guard 상태줄. 잔존 UI = 타이틀+SL+Start+Step+Lots+AUTO+BUY+SELL+CLOSE ALL | **PASS** |
| A3 | 일괄청산 구현가능 최속 | `CollectOurTickets` 스냅샷 + `OrderCloseBy` 우선 + 상향슬리피지 + 루프 Print제거 + Refresh 절약 + 32패스 + `g_ClosingAll` | **PASS** |
| A4 | 동일방식 전수검사 보고 | 본 문서 | **PASS** |

불복종 항목: **없음**

---

## B. 패널 표시 요소 전수 (허용/제거)

| 요소 | 허용? | 코드 | 결과 |
|------|-------|------|------|
| 타이틀 IDC_Assistant | YES | OBJ_TITLE | PASS |
| SL (pts) Edit | YES | OBJ_LBL_SL + OBJ_EDT_SL | PASS |
| Trail Start Edit | YES | OBJ_LBL_TS + OBJ_EDT_TS | PASS |
| Trail Step Edit | YES | OBJ_LBL_STEP + OBJ_EDT_STEP | PASS |
| Lots Edit | YES | OBJ_LBL_LOT + OBJ_EDT_LOT | PASS |
| MANUAL/AUTO | YES | OBJ_BTN_AUTO | PASS |
| BUY | YES | OBJ_BTN_BUY | PASS |
| SELL | YES | OBJ_BTN_SELL | PASS |
| CLOSE ALL | YES | OBJ_BTN_CLOSE | PASS |
| SYM \| TF \| GMT 문구 | **NO** | 소스 검색 0건 (OBJ_INFO 삭제) | **REMOVED** |
| Pos B/S \| Action 문구 | **NO** | OBJ_STATUS 삭제, g_LastAction/g_StatusLine 삭제 | **REMOVED** |
| Guard: OK \| SL= 중복문구 | **NO** | OBJ_GUARD 삭제 (g_GuardStatus는 내부/저널만) | **REMOVED** |

---

## C. 패널 설정값 조정 기능 전수

| 설정 | Edit 객체 | 틱 동기화 | ENDEDIT 확정 | 실사용처 | UI-only? | 결과 |
|------|-----------|-----------|--------------|----------|----------|------|
| SL pts | OBJ_EDT_SL | Sync→g_SLPoints | ApplyPanelEdit 정규화 | CalcInitialSLPrice/가디언/자동랏 | NO | PASS |
| Trail Start | OBJ_EDT_TS | →g_TrailStartPts | ApplyPanelEdit | ManageTrailingStops | NO | PASS |
| Trail Step | OBJ_EDT_STEP | →g_TrailStepPts | ApplyPanelEdit (min 1) | ManageTrailingStops | NO | PASS |
| Lots | OBJ_EDT_LOT | MANUAL시 →g_Lots | NormalizeLots 재표시 | GetTradeLots/OrderSend | NO | PASS |
| AUTO토글 | OBJ_BTN_AUTO | — | 클릭 토글 | g_LotModeAuto/CalcAutoLots | NO | PASS |

MANUAL 모드에서 틱마다 Lots Edit를 덮어쓰지 않음 (`RefreshAutoLotDisplay`는 AUTO만) → 입력 중 간섭 방지 **PASS**

---

## D. 초고속 청산 매핑 (§10)

| 명세 | 코드 | 결과 |
|------|------|------|
| 10-1 본 EA만 | IsOurOrder 필터 | PASS |
| 10-2 티켓 스냅샷 | CollectOurTickets | PASS |
| 10-3 CloseBy 우선 | OrderCloseBy 루프 | PASS |
| 10-4 상향 슬리피지 | max(InpSlippage, CLOSE_SLIP_MIN=100) | PASS |
| 10-4 Refresh 절약 | 패스당 1회 + 4건마다 1회 | PASS |
| 10-5 Print 루프 금지 | CloseAll 루프 내 Print 없음 | PASS |
| 10-5 다회 패스 | CLOSE_MAX_PASSES=32 | PASS |
| 10-5 TradeContextBusy | spin Sleep(1) 최대 50 | PASS |
| 10-6 청산중 트레일/가디언 정지 | g_ClosingAll 게이트 OnTick | PASS |
| 10-7 TP/펜딩 아님 | CloseBy+Close만 | PASS |

### 청산 속도 — 정직한 한계

| # | 내용 |
|---|------|
| L1 | MT4는 비동기 OrderClose API 없음. 서버 왕복 지연은 브로커 종속 |
| L2 | 넷팅 계좌에서 OrderCloseBy 실패 시 자동으로 시장가 OrderClose 폴백 |
| L3 | 실기 속도 벤치마크는 본 환경에서 측정 불가 (사실 보고) |

---

## E. 원본전략 1~8항 회귀 매핑 (업데이트 후)

| # | 요구 | 결과 |
|---|------|------|
| 1 SL+트레일/TP없음 | tp=0 유지, ManageTrailingStops 유지 | PASS |
| 2 포인트 통일 | 유지 | PASS |
| 3 심볼/시간 자동감지 | 내부 유지, **패널 표시만 제거** (감지 로직 삭제 아님) | PASS |
| 4 SL 가디언 | 유지 (패널 문구만 제거) | PASS |
| 5 수동/자동 랏 | 유지 | PASS |
| 6 패널 구성 | 심플화 후 필수 컨트롤만 | PASS |
| 7 물타기 동일 절대가 | ClassifyAddMode/ResolveBasePrice 유지 | PASS |
| 8 불타기 개별 진입가 | 유지 | PASS |

---

## F. 파라미터 UI-only 색출

| 파라미터 | 판정 |
|----------|------|
| InpSepPanel/Trade/Symbol/Guard | UI-ONLY (입력 구분선) |
| 그 외 input | 실기능 (패널크기/색/기본값/가디언/심볼) |
| 위장 무기능 파라미터 | **없음** |

---

## G. 허위·은폐·땜빵·불복종 색출

| 검사 | 결과 |
|------|------|
| 상태줄만 숨기고 객체 잔존 | **없음** — OBJ_INFO/STATUS/GUARD 정의·생성 0건 |
| Edit는 있으나 ENDEDIT 미연결 | **없음** — ApplyPanelEdit 연결 |
| CLOSE 속도 “최속” 과장(비동기 위장) | **안 함** — MT4 한계 L1 명시 |
| TODO/FIXME/stub | **없음** |
| 불복종 | **없음** |

---

## H. 최종 판정

| 영역 | 판정 |
|------|------|
| 패널 심플화 | **PASS** |
| 패널 설정값 조정 | **PASS** (틱동기화+ENDEDIT) |
| 초고속 청산 | **PASS** (구현가능 범위 최속 기법 적용) |
| 원본 1~8 회귀 | **PASS** |
| 허위/은폐/불복종 | **0건** |

**종합: v1.01 제출본은 본 턴 명령 + 원본전략 항목단위 실기능 매핑 완료. MT4 실컴파일·실측 속도는 사용자 환경 검증 필요.**
