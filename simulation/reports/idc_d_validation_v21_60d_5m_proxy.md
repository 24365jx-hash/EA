# IDC_D Simulation Validation Report

## Scope

- EA name: IDC_D
- Platform target: MT4
- Market target: GOLD / XAUUSD, using GC=F as public proxy when broker CSV is not supplied
- Timeframes: M1 execution with M5 trend/volatility filter
- Point model: 1 point = 0.01 price unit; 20 pips = 200 points
- Exit model: no TP; SL moves to +200 points once price reaches +200 points, then step trailing
- Entry model: trend pullback, daily probe, and final daily directional entry
- Grid, martingale, and averaging-down are excluded

## Data

- Source: Yahoo Finance GC=F range=60d interval=5m
- Bars: 13624
- First bar UTC: 2026-04-09T04:00:00+00:00
- Last bar UTC: 2026-06-19T03:55:00+00:00

## Conservative Assumptions

- Round-trip cost: 35 points subtracted from every closed trade
- Same-bar ambiguity is resolved against the strategy when the old stop and lock trigger are both touched
- Only one position is simulated at a time
- Trading stops for the day after a 20-pip lock event

## Best Candidate Parameters

- m5_fast: 5
- m5_slow: 13
- m1_fast: 8
- m1_slow: 21
- rsi_period: 14
- rsi_buy_min: 52
- rsi_sell_max: 48
- atr_min_points: 20
- atr_max_points: 600
- initial_sl_points: 300
- lock_trigger_points: 200
- lock_profit_points: 200
- trail_step_points: 50
- max_loss_trades_per_day: 1
- block_same_direction_after_loss: True
- min_m5_slope_points: 10
- max_m5_pullback_points: 120
- round_trip_cost_points: 35
- session_start_utc: 6
- session_end_utc: 21
- daily_probe_start_utc: 6
- use_daily_probe: True
- relaxed_trend_probe: True
- force_daily_entry: True
- final_entry_hour_utc: 11
- neutral_rsi_low: 48
- neutral_rsi_high: 52
- cooldown_bars: 10
- max_trades_per_day: 3
- stop_after_daily_lock: True

## Best Candidate Metrics

- Trades: 50
- Total days: 50
- Trade days: 50
- 20-pip locked days: 31 (62.0%)
- Win rate after costs: 62.0%
- Profit factor: 2.01
- Gross points: 8200.0
- Net points after costs: 6450.0
- Average daily net points: 129.0
- Max closed-trade drawdown points: 2010.0
- Worst daily net points: -335.0
- Losing days: 19
- Median trade net points: 215.0

## Top 5 Candidates

| Rank | Score | Trade Day Rate | Locked Day Rate | Win Rate | PF | Net Points | Max DD Points | Trades | SL | Trail Step | Probe | Force | M5 EMA | M1 EMA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 11756.7 | 100.0% | 62.0% | 62.0% | 2.01 | 6450.0 | 2010.0 | 50 | 300 | 50 | True/6/True | True/11 | 5/13 | 8/21 |
| 2 | 11756.7 | 100.0% | 62.0% | 62.0% | 2.01 | 6450.0 | 2010.0 | 50 | 300 | 50 | True/6/True | True/12 | 5/13 | 8/21 |
| 3 | 11756.7 | 100.0% | 62.0% | 62.0% | 2.01 | 6450.0 | 2010.0 | 50 | 300 | 50 | True/6/True | True/13 | 5/13 | 8/21 |
| 4 | 11756.7 | 100.0% | 62.0% | 62.0% | 2.01 | 6450.0 | 2010.0 | 50 | 300 | 50 | True/6/True | True/14 | 5/13 | 8/21 |
| 5 | 11756.7 | 100.0% | 62.0% | 62.0% | 2.01 | 6450.0 | 2010.0 | 50 | 300 | 50 | True/6/True | True/11 | 8/21 | 8/21 |

## Validation Decision

PASS: The M1 proxy simulation meets the v2.0 frequency and profitability floor, with final broker-side MT4 Strategy Tester validation still required.
