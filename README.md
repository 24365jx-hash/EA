# IDC_V (MT4)

MT4 Expert Advisor: **Buy Stop / Sell Stop** straddle on **XAUUSD M5**, with OCO, trailing (no TP), SL Guardian, session filter, and daily loss limit.

## Install

1. Copy `MQL4/Experts/IDC_V.mq4` into your terminal `MQL4/Experts/` folder.
2. Compile in MetaEditor.
3. Attach to **XAUUSD M5** chart (AutoTrading ON).
4. Optional: load `MQL4/Presets/IDC_V_XAUUSD_M5.set`.

## Defaults (Gold-oriented, all distances in points)

| Param | Default |
|-------|---------|
| Entry offset | 95 |
| SL | 150 |
| Trailing start | 200 |
| Trailing step | 10 |
| Session (GMT) | 13:00–16:00 |
| Daily loss % | 5 |
| AutoLot risk % | 1 |

## Rules implemented

1. One entry per M5 bar  
2. First triggered stop keeps the trade; opposite pending is cancelled (OCO)  
3. No re-entry until the position is fully closed  
4. No TP — trailing start then step chase; SL user-configurable  
