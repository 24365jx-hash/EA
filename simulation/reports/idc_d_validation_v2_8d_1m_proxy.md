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

- Source: Yahoo Finance GC=F range=8d interval=1m
- Bars: 9635
- First bar UTC: 2026-06-10T04:00:00+00:00
- Last bar UTC: 2026-06-19T03:58:00+00:00

## Conservative Assumptions

- Round-trip cost: 35 points subtracted from every closed trade
- Same-bar ambiguity is resolved against the strategy when the old stop and lock trigger are both touched
- Only one position is simulated at a time
- Trading stops for the day after a 20-pip lock event

## Best Candidate Parameters

- m5_fast: 12
- m5_slow: 36
- m1_fast: 3
- m1_slow: 9
- rsi_period: 14
- rsi_buy_min: 50
- rsi_sell_max: 50
- atr_min_points: 20
- atr_max_points: 600
- initial_sl_points: 300
- lock_trigger_points: 200
- lock_profit_points: 200
- trail_step_points: 50
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

- Trades: 10
- Total days: 8
- Trade days: 7
- 20-pip locked days: 7 (87.5%)
- Win rate after costs: 70.0%
- Profit factor: 1.45
- Gross points: 800.0
- Net points after costs: 450.0
- Average daily net points: 56.2
- Max closed-trade drawdown points: 505.0
- Worst daily net points: -170.0
- Losing days: 2
- Median trade net points: 165.0

## Top 5 Candidates

| Rank | Score | Trade Day Rate | Locked Day Rate | Win Rate | PF | Net Points | Max DD Points | Trades | SL | Trail Step | Probe | Force | M5 EMA | M1 EMA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 10926.4 | 87.5% | 87.5% | 70.0% | 1.45 | 450.0 | 505.0 | 10 | 300 | 50 | True/6/True | True/11 | 12/36 | 3/9 |
| 2 | 10926.4 | 87.5% | 87.5% | 70.0% | 1.45 | 450.0 | 505.0 | 10 | 300 | 50 | True/6/True | True/12 | 12/36 | 3/9 |
| 3 | 10926.4 | 87.5% | 87.5% | 70.0% | 1.45 | 450.0 | 505.0 | 10 | 300 | 50 | True/6/True | True/13 | 12/36 | 3/9 |
| 4 | 10926.4 | 87.5% | 87.5% | 70.0% | 1.45 | 450.0 | 505.0 | 10 | 300 | 50 | True/6/True | True/14 | 12/36 | 3/9 |
| 5 | 10912.7 | 87.5% | 87.5% | 77.8% | 1.69 | 535.0 | 605.0 | 9 | 350 | 50 | True/6/True | True/11 | 12/36 | 3/9 |

## Validation Decision

PASS: The M1 proxy simulation meets the v2.0 frequency and profitability floor, with final broker-side MT4 Strategy Tester validation still required.
