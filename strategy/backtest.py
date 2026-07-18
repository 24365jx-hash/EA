"""
Single-MA FX backtester focused on monthly income consistency.

Signal source: exactly one moving average (price vs MA).
Risk / execution uses fixed fractional sizing and pip-based stops derived
from the same MA distance (no second indicator series).
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Literal

import numpy as np
import pandas as pd

from .indicators import compute_ma

Mode = Literal["flip", "pullback", "slope_flip"]


@dataclass
class StrategyConfig:
    ma_type: str = "ema"
    ma_period: int = 50
    mode: Mode = "pullback"
    risk_pct: float = 0.0075  # 0.75% equity risk per trade
    rr: float = 2.0  # take-profit multiple of stop distance
    stop_ma_buffer: float = 0.15  # stop beyond MA by 15% of |entry-MA|
    min_stop_pips: float = 15.0
    max_stop_pips: float = 80.0
    pip_size: float = 0.0001
    pip_value_per_lot: float = 10.0  # standard lot USD per pip for XXXUSD
    spread_pips: float = 1.2
    commission_per_lot: float = 7.0  # round-turn USD
    initial_capital: float = 4000.0
    max_positions: int = 1
    slope_lookback: int = 3
    # Monthly income controls
    monthly_withdraw_pct: float = 0.5  # withdraw 50% of month profit if positive
    reserve_floor: float = 4000.0  # never withdraw below start capital
    # Consistency: skip entries when MA is flat (same MA slope only)
    min_slope_pips: float = 2.0


@dataclass
class Trade:
    entry_time: pd.Timestamp
    exit_time: pd.Timestamp
    side: int
    entry: float
    exit: float
    lots: float
    pnl: float
    reason: str


def _pip_distance(a: float, b: float, pip_size: float) -> float:
    return abs(a - b) / pip_size


def prepare_signals(df: pd.DataFrame, cfg: StrategyConfig) -> pd.DataFrame:
    data = df.copy()
    if not isinstance(data.index, pd.DatetimeIndex):
        data.index = pd.to_datetime(data.index)

    close = data["Close"].astype(float)
    high = data["High"].astype(float)
    low = data["Low"].astype(float)

    ma = compute_ma(close, cfg.ma_type, cfg.ma_period)
    data["ma"] = ma
    data["prev_close"] = close.shift(1)
    data["prev_ma"] = ma.shift(1)
    data["ma_slope"] = ma - ma.shift(cfg.slope_lookback)
    data["ma_slope_pips"] = data["ma_slope"] / cfg.pip_size

    cross_up = (data["prev_close"] <= data["prev_ma"]) & (close > ma)
    cross_dn = (data["prev_close"] >= data["prev_ma"]) & (close < ma)
    data["cross_up"] = cross_up.fillna(False)
    data["cross_dn"] = cross_dn.fillna(False)

    # Pullback: price tags MA from trend side, then closes back with trend
    touched_from_above = (low <= ma) & (close > ma) & (data["ma_slope_pips"] >= cfg.min_slope_pips)
    touched_from_below = (high >= ma) & (close < ma) & (data["ma_slope_pips"] <= -cfg.min_slope_pips)
    data["pullback_long"] = touched_from_above.fillna(False)
    data["pullback_short"] = touched_from_below.fillna(False)

    slope_ok_long = data["ma_slope_pips"] >= cfg.min_slope_pips
    slope_ok_short = data["ma_slope_pips"] <= -cfg.min_slope_pips

    if cfg.mode == "flip":
        data["long_signal"] = data["cross_up"]
        data["short_signal"] = data["cross_dn"]
    elif cfg.mode == "slope_flip":
        data["long_signal"] = data["cross_up"] & slope_ok_long
        data["short_signal"] = data["cross_dn"] & slope_ok_short
    elif cfg.mode == "pullback":
        data["long_signal"] = data["pullback_long"]
        data["short_signal"] = data["pullback_short"]
    else:
        raise ValueError(f"Unknown mode: {cfg.mode}")

    data["High"] = high
    data["Low"] = low
    data["Close"] = close
    return data.dropna(subset=["ma"])


def _position_lots(equity: float, stop_pips: float, cfg: StrategyConfig) -> float:
    risk_usd = equity * cfg.risk_pct
    if stop_pips <= 0:
        return 0.0
    lots = risk_usd / (stop_pips * cfg.pip_value_per_lot)
    # Micro-lot rounding for small accounts
    lots = max(0.01, np.floor(lots * 100) / 100.0)
    return float(lots)


def _stop_distance_pips(entry: float, ma_value: float, side: int, cfg: StrategyConfig) -> float:
    base = _pip_distance(entry, ma_value, cfg.pip_size)
    stop_pips = base * (1.0 + cfg.stop_ma_buffer)
    # Ensure stop is on the far side of MA
    if stop_pips < cfg.min_stop_pips:
        stop_pips = cfg.min_stop_pips
    if stop_pips > cfg.max_stop_pips:
        stop_pips = cfg.max_stop_pips
    return float(stop_pips)


def run_backtest(df: pd.DataFrame, cfg: StrategyConfig) -> dict:
    data = prepare_signals(df, cfg)
    equity = cfg.initial_capital
    peak = equity
    max_dd = 0.0

    position = 0  # -1 short, 0 flat, +1 long
    entry_price = 0.0
    stop_price = 0.0
    tp_price = 0.0
    lots = 0.0
    entry_time = None

    trades: list[Trade] = []
    equity_curve = []

    month_start_equity = equity
    current_month = None
    monthly_rows = []
    withdrawn_total = 0.0

    for ts, row in data.iterrows():
        month_key = (ts.year, ts.month)
        if current_month is None:
            current_month = month_key
            month_start_equity = equity

        # Month rollover: record and optionally withdraw
        if month_key != current_month:
            month_pnl = equity - month_start_equity
            withdraw = 0.0
            if month_pnl > 0 and equity > cfg.reserve_floor:
                withdraw = min(month_pnl * cfg.monthly_withdraw_pct, equity - cfg.reserve_floor)
                equity -= withdraw
                withdrawn_total += withdraw
            monthly_rows.append(
                {
                    "year": current_month[0],
                    "month": current_month[1],
                    "start_equity": month_start_equity,
                    "end_equity": equity + withdraw,
                    "pnl": month_pnl,
                    "pnl_pct": month_pnl / month_start_equity if month_start_equity else 0.0,
                    "withdrawn": withdraw,
                    "positive": month_pnl > 0,
                }
            )
            current_month = month_key
            month_start_equity = equity

        # Manage open position
        if position != 0:
            hit_stop = hit_tp = False
            if position == 1:
                hit_stop = row["Low"] <= stop_price
                hit_tp = row["High"] >= tp_price
            else:
                hit_stop = row["High"] >= stop_price
                hit_tp = row["Low"] <= tp_price

            # Same-bar ambiguity: assume stop first (conservative)
            exit_price = None
            reason = ""
            if hit_stop:
                exit_price = stop_price
                reason = "stop"
            elif hit_tp:
                exit_price = tp_price
                reason = "tp"
            elif (position == 1 and row["Close"] < row["ma"]) or (
                position == -1 and row["Close"] > row["ma"]
            ):
                # Exit if price closes through the single MA against us
                exit_price = row["Close"]
                reason = "ma_exit"

            if exit_price is not None:
                spread_cost = cfg.spread_pips * cfg.pip_size / 2.0
                fill = exit_price - spread_cost if position == 1 else exit_price + spread_cost
                move_pips = (fill - entry_price) / cfg.pip_size * position
                pnl = move_pips * cfg.pip_value_per_lot * lots - cfg.commission_per_lot * lots
                equity += pnl
                trades.append(
                    Trade(
                        entry_time=entry_time,
                        exit_time=ts,
                        side=position,
                        entry=entry_price,
                        exit=fill,
                        lots=lots,
                        pnl=pnl,
                        reason=reason,
                    )
                )
                position = 0
                lots = 0.0

        # Entries (flat only; max one position)
        if position == 0:
            side = 0
            if row["long_signal"]:
                side = 1
            elif row["short_signal"]:
                side = -1

            if side != 0:
                spread_cost = cfg.spread_pips * cfg.pip_size / 2.0
                entry = row["Close"] + spread_cost if side == 1 else row["Close"] - spread_cost
                stop_pips = _stop_distance_pips(entry, float(row["ma"]), side, cfg)
                lots = _position_lots(equity, stop_pips, cfg)
                if lots >= 0.01 and equity > 100:
                    position = side
                    entry_price = entry
                    entry_time = ts
                    if side == 1:
                        stop_price = entry - stop_pips * cfg.pip_size
                        tp_price = entry + stop_pips * cfg.rr * cfg.pip_size
                    else:
                        stop_price = entry + stop_pips * cfg.pip_size
                        tp_price = entry - stop_pips * cfg.rr * cfg.pip_size

        peak = max(peak, equity)
        dd = (peak - equity) / peak if peak else 0.0
        max_dd = max(max_dd, dd)
        equity_curve.append({"time": ts, "equity": equity})

    # Final partial month
    if current_month is not None:
        month_pnl = equity - month_start_equity
        monthly_rows.append(
            {
                "year": current_month[0],
                "month": current_month[1],
                "start_equity": month_start_equity,
                "end_equity": equity,
                "pnl": month_pnl,
                "pnl_pct": month_pnl / month_start_equity if month_start_equity else 0.0,
                "withdrawn": 0.0,
                "positive": month_pnl > 0,
            }
        )

    trades_df = pd.DataFrame([asdict(t) for t in trades])
    monthly_df = pd.DataFrame(monthly_rows)
    eq_df = pd.DataFrame(equity_curve).set_index("time")

    n_months = len(monthly_df)
    pos_months = int(monthly_df["positive"].sum()) if n_months else 0
    avg_month = float(monthly_df["pnl"].mean()) if n_months else 0.0
    med_month = float(monthly_df["pnl"].median()) if n_months else 0.0
    month_std = float(monthly_df["pnl"].std(ddof=0)) if n_months else 0.0
    win_rate = float((trades_df["pnl"] > 0).mean()) if len(trades_df) else 0.0
    profit_factor = _profit_factor(trades_df)
    total_return = (equity + withdrawn_total) / cfg.initial_capital - 1.0

    # Consistency score: prioritize positive-month rate, penalize DD and month vol
    pos_rate = pos_months / n_months if n_months else 0.0
    consistency = pos_rate * (1.0 - max_dd) * (1.0 / (1.0 + abs(month_std) / max(cfg.initial_capital * 0.02, 1e-9)))

    return {
        "config": asdict(cfg),
        "final_equity": equity,
        "withdrawn_total": withdrawn_total,
        "total_wealth": equity + withdrawn_total,
        "total_return": total_return,
        "max_drawdown": max_dd,
        "trades": len(trades_df),
        "win_rate": win_rate,
        "profit_factor": profit_factor,
        "positive_months": pos_months,
        "total_months": n_months,
        "positive_month_rate": pos_rate,
        "avg_monthly_pnl": avg_month,
        "median_monthly_pnl": med_month,
        "monthly_pnl_std": month_std,
        "consistency_score": consistency,
        "trades_df": trades_df,
        "monthly_df": monthly_df,
        "equity_df": eq_df,
    }


def _profit_factor(trades_df: pd.DataFrame) -> float:
    if trades_df.empty:
        return 0.0
    gains = trades_df.loc[trades_df["pnl"] > 0, "pnl"].sum()
    losses = -trades_df.loc[trades_df["pnl"] < 0, "pnl"].sum()
    if losses <= 0:
        return float("inf") if gains > 0 else 0.0
    return float(gains / losses)


def walk_forward(
    df: pd.DataFrame,
    cfg: StrategyConfig,
    train_years: int = 3,
    test_years: int = 1,
) -> dict:
    """Anchored walk-forward: optimize period on train, apply on next test window."""
    data = df.sort_index()
    start = data.index.min()
    end = data.index.max()

    oos_monthly = []
    oos_trades = 0
    oos_wealth_start = cfg.initial_capital
    cursor = start + pd.DateOffset(years=train_years)
    folds = []

    while cursor + pd.DateOffset(years=test_years) <= end + pd.DateOffset(days=5):
        train_end = cursor
        test_end = min(cursor + pd.DateOffset(years=test_years), end)
        train = data.loc[:train_end]
        test = data.loc[train_end:test_end]
        if len(train) < 250 or len(test) < 60:
            break

        best = None
        for period in (21, 34, 50, 55, 89):
            for mode in ("pullback", "slope_flip"):
                trial = StrategyConfig(**{**asdict(cfg), "ma_period": period, "mode": mode})
                res = run_backtest(train, trial)
                score = res["consistency_score"]
                if best is None or score > best["score"]:
                    best = {"score": score, "period": period, "mode": mode, "train": res}

        assert best is not None
        oos_cfg = StrategyConfig(
            **{**asdict(cfg), "ma_period": best["period"], "mode": best["mode"]}
        )
        oos = run_backtest(test, oos_cfg)
        folds.append(
            {
                "train_end": str(train_end.date()),
                "test_end": str(test_end.date()),
                "chosen_period": best["period"],
                "chosen_mode": best["mode"],
                "oos_positive_month_rate": oos["positive_month_rate"],
                "oos_avg_monthly_pnl": oos["avg_monthly_pnl"],
                "oos_max_drawdown": oos["max_drawdown"],
                "oos_total_return": oos["total_return"],
                "oos_trades": oos["trades"],
                "oos_profit_factor": oos["profit_factor"],
            }
        )
        if not oos["monthly_df"].empty:
            oos_monthly.append(oos["monthly_df"])
        oos_trades += oos["trades"]
        cursor = cursor + pd.DateOffset(years=test_years)

    monthly = pd.concat(oos_monthly, ignore_index=True) if oos_monthly else pd.DataFrame()
    pos_rate = float(monthly["positive"].mean()) if len(monthly) else 0.0
    return {
        "folds": folds,
        "oos_months": len(monthly),
        "oos_positive_month_rate": pos_rate,
        "oos_avg_monthly_pnl": float(monthly["pnl"].mean()) if len(monthly) else 0.0,
        "oos_median_monthly_pnl": float(monthly["pnl"].median()) if len(monthly) else 0.0,
        "oos_trades": oos_trades,
        "monthly_df": monthly,
        "start_capital": oos_wealth_start,
    }
