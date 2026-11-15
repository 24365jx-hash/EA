# IDC_D Simulation Validation Report

## Scope

- EA name: IDC_D
- Platform target: MT4
- Market target: GOLD / XAUUSD, using GC=F as public proxy when broker CSV is not supplied
- Timeframes: M1 execution with M5 trend/volatility filter
- Point model: 1 point = 0.01 price unit; 20 pips = 200 points
- Exit model: no TP; SL moves to +200 points once price reaches +200 points, then step trailing
- Grid, martingale, and averaging-down are excluded

## Data

- Source: Yahoo Finance GC=F range=7d interval=1m
- Bars: 7310
- First bar UTC: 2026-06-11T04:00:00+00:00
- Last bar UTC: 2026-06-18T11:11:36+00:00

## Conservative Assumptions

- Round-trip cost: 35 points subtracted from every closed trade
- Same-bar ambiguity is resolved against the strategy when the old stop and lock trigger are both touched
- Only one position is simulated at a time
- Trading stops for the day after a 20-pip lock event

## Best Candidate Parameters

- m5_fast: 34
- m5_slow: 89
- m1_fast: 9
- m1_slow: 21
- rsi_period: 14
- rsi_buy_min: 55
- rsi_sell_max: 45
- atr_min_points: 35
- atr_max_points: 450
- initial_sl_points: 450
- lock_trigger_points: 200
- lock_profit_points: 200
- trail_step_points: 50
- round_trip_cost_points: 35
- session_start_utc: 6
- session_end_utc: 21
- daily_probe_start_utc: 12
- use_daily_probe: True
- relaxed_trend_probe: False
- cooldown_bars: 10
- max_trades_per_day: 4
- stop_after_daily_lock: True

## Best Candidate Metrics

- Trades: 4
- Total days: 6
- Trade days: 4
- 20-pip locked days: 4 (66.7%)
- Win rate after costs: 100.0%
- Profit factor: inf
- Gross points: 900.0
- Net points after costs: 760.0
- Average daily net points: 126.7
- Max closed-trade drawdown points: 0.0
- Worst daily net points: 0.0
- Losing days: 0
- Median trade net points: 190.0

## Top 5 Candidates

| Rank | Score | Trade Day Rate | Locked Day Rate | Win Rate | PF | Net Points | Max DD Points | Trades | SL | Trail Step | Probe | Relaxed | M5 EMA | M1 EMA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 11326.7 | 66.7% | 66.7% | 100.0% | inf | 760.0 | 0.0 | 4 | 450 | 50 | True/12 | False | 34/89 | 9/21 |
| 2 | 11326.7 | 66.7% | 66.7% | 100.0% | inf | 760.0 | 0.0 | 4 | 450 | 50 | True/15 | False | 34/89 | 9/21 |
| 3 | 11276.7 | 66.7% | 66.7% | 100.0% | inf | 710.0 | 0.0 | 4 | 450 | 50 | False/21 | False | 8/21 | 5/13 |
| 4 | 11276.7 | 66.7% | 66.7% | 100.0% | inf | 710.0 | 0.0 | 4 | 450 | 50 | True/12 | False | 8/21 | 5/13 |
| 5 | 11276.7 | 66.7% | 66.7% | 100.0% | inf | 710.0 | 0.0 | 4 | 450 | 50 | True/12 | True | 8/21 | 5/13 |

## Validation Decision

FAIL: Do not ship the EA defaults without additional broker-quality XAUUSD M1 data and retesting.
