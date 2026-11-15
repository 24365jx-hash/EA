# IDC_D v2.0 Default Validation Summary

## Default Parameters

- M5FastEMA: 12
- M5SlowEMA: 36
- M1FastEMA: 3
- M1SlowEMA: 9
- InitialSLPoints: 300
- LockProfitTriggerPoints: 200
- LockProfitPoints: 200
- TrailStepPoints: 50
- ATRMinPoints: 20
- ATRMaxPoints: 600
- DailyProbeStartHour: 6 UTC
- ForceDailyEntry: true
- FinalEntryHour: 11 UTC
- MaxTradesPerDay: 3
- StopAfterDailyLock: true

## 8-day M1 GC=F Proxy

- Trades: 10
- Total days: 8
- Trade days: 7
- 20-pip locked days: 7
- Win rate after costs: 70.0%
- Profit factor: 1.45
- Net points after costs: 450.0
- Max closed-trade drawdown points: 505.0
- Worst daily net points: -170.0
- Validation: PASS

## 60-day 5m GC=F Proxy

- Trades: 78
- Total days: 50
- Trade days: 50
- 20-pip locked days: 45
- Win rate after costs: 57.7%
- Profit factor: 1.62
- Net points after costs: 6820.0
- Max closed-trade drawdown points: 2805.0
- Worst daily net points: -1005.0
- Validation: PASS

## Notes

- GC=F is a public GOLD proxy, not broker XAUUSD tick history.
- Final live deployment still requires MT4 Strategy Tester validation with the target broker's XAUUSD M1 data, spread, commission, StopLevel, and slippage.
