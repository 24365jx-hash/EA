# IDC_V (MT4)

XAUUSD **M5** BuyStop/SellStop straddle EA.

- **전략서(스펙 락):** [`docs/IDC_V_전략서.md`](docs/IDC_V_전략서.md) v1.0  
- **EA:** `MQL4/Experts/IDC_V.mq4` v2.00  
- **프리셋:** `MQL4/Presets/IDC_V_XAUUSD_M5.set`

## Install

1. `IDC_V.mq4` → terminal `MQL4/Experts/`
2. MetaEditor compile
3. Attach to **XAUUSD M5** (AutoTrading ON)
4. Optional: load the preset

## Defaults (points)

| Param | Default |
|-------|---------|
| BuyStop↔SellStop gap | **200** |
| SL | 150 |
| Trail start / step | 200 / 10 |
| Session GMT | 13:00–16:00 |
| Daily loss % | 5 |
