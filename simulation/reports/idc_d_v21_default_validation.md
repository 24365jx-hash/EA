# IDC_D v2.1 Default Validation Summary

## Default Parameters

- M5FastEMA: 12
- M5SlowEMA: 36
- M1FastEMA: 8
- M1SlowEMA: 21
- InitialSLPoints: 350
- LockProfitTriggerPoints: 200
- LockProfitPoints: 200
- TrailStepPoints: 50
- MaxLossTradesPerDay: 1
- BlockSameDirectionAfterLoss: true
- MinM5SlopePoints: 10
- MaxM5PullbackPoints: 120
- ATRMinPoints: 20
- ATRMaxPoints: 600
- DailyProbeStartHour: 6 UTC
- ForceDailyEntry: true
- FinalEntryHour: 11 UTC
- MaxTradesPerDay: 3
- StopAfterDailyLock: true

## 8-day M1 GC=F Proxy

- Trades: 7
- Total days: 8
- Trade days: 7
- 20-pip locked days: 5
- Win rate after costs: 71.4%
- Profit factor: 1.46
- Net points after costs: 355.0
- Max closed-trade drawdown points: 385.0
- Worst daily net points: -385.0
- Losing days: 2
- Validation: PASS

## 60-day 5m GC=F Proxy

- Trades: 50
- Total days: 50
- Trade days: 50
- 20-pip locked days: 31
- Win rate after costs: 62.0%
- Profit factor: 2.01
- Net points after costs: 6450.0
- Max closed-trade drawdown points: 2010.0
- Worst daily net points: -335.0
- Losing days: 19
- Validation: PASS

## Notes

- v2.1 prioritizes stopping repeated same-day loss chains over maximizing daily locked-profit count.
- GC=F is a public GOLD proxy, not broker XAUUSD tick history.
- Final live deployment still requires MT4 Strategy Tester validation with the target broker's XAUUSD M1 data, spread, commission, StopLevel, and slippage.
