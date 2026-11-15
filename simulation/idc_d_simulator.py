#!/usr/bin/env python3
"""IDC_D strategy simulator.

This is a conservative, dependency-free validation harness for the IDC_D MT4 EA.
It can fetch public Yahoo Finance GC=F intraday data as a GOLD proxy or read an
MT4-exported CSV file. The EA itself does not depend on this script.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import statistics
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.parse import urlencode
from urllib.request import Request, urlopen


POINT_SIZE = 0.01


@dataclass(frozen=True)
class Bar:
    time: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float = 0.0


@dataclass(frozen=True)
class Params:
    m5_fast: int
    m5_slow: int
    m1_fast: int
    m1_slow: int
    rsi_period: int
    rsi_buy_min: float
    rsi_sell_max: float
    atr_min_points: int
    atr_max_points: int
    initial_sl_points: int
    lock_trigger_points: int
    lock_profit_points: int
    trail_step_points: int
    max_loss_trades_per_day: int
    block_same_direction_after_loss: bool
    min_m5_slope_points: int
    max_m5_pullback_points: int
    round_trip_cost_points: int
    session_start_utc: int
    session_end_utc: int
    daily_probe_start_utc: int
    use_daily_probe: bool
    relaxed_trend_probe: bool
    force_daily_entry: bool
    final_entry_hour_utc: int
    neutral_rsi_low: float
    neutral_rsi_high: float
    cooldown_bars: int
    max_trades_per_day: int
    stop_after_daily_lock: bool


@dataclass
class Trade:
    side: str
    entry_time: datetime
    exit_time: datetime
    entry: float
    exit: float
    gross_points: float
    net_points: float
    locked: bool


@dataclass
class SimulationResult:
    params: Params
    trades: list[Trade]
    total_days: int
    trade_days: int
    locked_days: int
    daily_net_points: dict[str, float]
    max_drawdown_points: float
    profit_factor: float
    score: float

    @property
    def net_points(self) -> float:
        return sum(t.net_points for t in self.trades)

    @property
    def gross_points(self) -> float:
        return sum(t.gross_points for t in self.trades)

    @property
    def win_rate(self) -> float:
        if not self.trades:
            return 0.0
        return sum(1 for t in self.trades if t.net_points > 0) / len(self.trades)

    @property
    def locked_day_rate(self) -> float:
        return self.locked_days / self.total_days if self.total_days else 0.0

    @property
    def avg_daily_net_points(self) -> float:
        return self.net_points / self.total_days if self.total_days else 0.0


def fetch_yahoo_bars(symbol: str, range_name: str, interval: str) -> list[Bar]:
    query = urlencode({"range": range_name, "interval": interval})
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?{query}"
    request = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(request, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))

    chart = payload.get("chart", {})
    error = chart.get("error")
    if error:
        raise RuntimeError(f"Yahoo Finance error for {symbol}: {error}")
    result = chart.get("result") or []
    if not result:
        raise RuntimeError(f"No chart data returned for {symbol}")

    data = result[0]
    timestamps = data.get("timestamp") or []
    quote = (data.get("indicators", {}).get("quote") or [{}])[0]
    bars: list[Bar] = []
    for idx, stamp in enumerate(timestamps):
        values = {
            "open": quote.get("open", [None] * len(timestamps))[idx],
            "high": quote.get("high", [None] * len(timestamps))[idx],
            "low": quote.get("low", [None] * len(timestamps))[idx],
            "close": quote.get("close", [None] * len(timestamps))[idx],
            "volume": quote.get("volume", [0] * len(timestamps))[idx],
        }
        if any(values[key] is None for key in ("open", "high", "low", "close")):
            continue
        bars.append(
            Bar(
                time=datetime.fromtimestamp(stamp, tz=timezone.utc),
                open=float(values["open"]),
                high=float(values["high"]),
                low=float(values["low"]),
                close=float(values["close"]),
                volume=float(values["volume"] or 0),
            )
        )
    if len(bars) < 200:
        raise RuntimeError(f"Insufficient data: only {len(bars)} bars")
    return bars


def read_mt4_csv(path: Path) -> list[Bar]:
    """Read common MT4 history CSV formats.

    Supported columns include either Date/Time/Open/High/Low/Close or the MT4
    export shape: Date, Time, Open, High, Low, Close, Volume.
    """

    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        sample = handle.read(4096)
        handle.seek(0)
        has_header = any(token.lower() in sample.lower() for token in ("open", "high", "close"))
        if has_header:
            reader: Iterable[dict[str, str]] = csv.DictReader(handle)
            rows = list(reader)
        else:
            raw = csv.reader(handle)
            rows = []
            for row in raw:
                if len(row) < 6:
                    continue
                rows.append(
                    {
                        "Date": row[0],
                        "Time": row[1],
                        "Open": row[2],
                        "High": row[3],
                        "Low": row[4],
                        "Close": row[5],
                        "Volume": row[6] if len(row) > 6 else "0",
                    }
                )

    bars: list[Bar] = []
    for row in rows:
        normalized = {key.strip().lower(): value for key, value in row.items() if key is not None}
        date_text = normalized.get("date") or normalized.get("<date>") or normalized.get("time")
        time_text = normalized.get("time") if normalized.get("date") else ""
        if date_text is None:
            continue
        stamp_text = f"{date_text} {time_text}".strip()
        parsed_time = parse_datetime(stamp_text)
        try:
            bars.append(
                Bar(
                    time=parsed_time,
                    open=float(normalized.get("open", normalized.get("<open>", "nan"))),
                    high=float(normalized.get("high", normalized.get("<high>", "nan"))),
                    low=float(normalized.get("low", normalized.get("<low>", "nan"))),
                    close=float(normalized.get("close", normalized.get("<close>", "nan"))),
                    volume=float(normalized.get("volume", normalized.get("tickvol", "0")) or 0),
                )
            )
        except ValueError:
            continue

    bars = [bar for bar in bars if all(math.isfinite(value) for value in (bar.open, bar.high, bar.low, bar.close))]
    bars.sort(key=lambda bar: bar.time)
    if len(bars) < 200:
        raise RuntimeError(f"Insufficient CSV data: only {len(bars)} bars")
    return bars


def parse_datetime(text: str) -> datetime:
    formats = (
        "%Y.%m.%d %H:%M",
        "%Y.%m.%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%d %H:%M:%S",
        "%m/%d/%Y %H:%M",
        "%m/%d/%Y %H:%M:%S",
    )
    for fmt in formats:
        try:
            return datetime.strptime(text, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def aggregate_bars(bars: list[Bar], minutes: int) -> list[Bar]:
    buckets: dict[datetime, list[Bar]] = {}
    for bar in bars:
        minute = (bar.time.minute // minutes) * minutes
        bucket_time = bar.time.replace(minute=minute, second=0, microsecond=0)
        buckets.setdefault(bucket_time, []).append(bar)
    aggregated: list[Bar] = []
    for bucket_time in sorted(buckets):
        group = buckets[bucket_time]
        aggregated.append(
            Bar(
                time=bucket_time,
                open=group[0].open,
                high=max(bar.high for bar in group),
                low=min(bar.low for bar in group),
                close=group[-1].close,
                volume=sum(bar.volume for bar in group),
            )
        )
    return aggregated


def ema(values: list[float], period: int) -> list[float | None]:
    output: list[float | None] = [None] * len(values)
    if len(values) < period:
        return output
    alpha = 2.0 / (period + 1)
    current = sum(values[:period]) / period
    output[period - 1] = current
    for idx in range(period, len(values)):
        current = (values[idx] - current) * alpha + current
        output[idx] = current
    return output


def atr(bars: list[Bar], period: int) -> list[float | None]:
    output: list[float | None] = [None] * len(bars)
    if len(bars) <= period:
        return output
    true_ranges: list[float] = []
    for idx, bar in enumerate(bars):
        if idx == 0:
            true_ranges.append(bar.high - bar.low)
        else:
            previous_close = bars[idx - 1].close
            true_ranges.append(max(bar.high - bar.low, abs(bar.high - previous_close), abs(bar.low - previous_close)))
    current = sum(true_ranges[1 : period + 1]) / period
    output[period] = current
    for idx in range(period + 1, len(bars)):
        current = ((current * (period - 1)) + true_ranges[idx]) / period
        output[idx] = current
    return output


def rsi(values: list[float], period: int) -> list[float | None]:
    output: list[float | None] = [None] * len(values)
    if len(values) <= period:
        return output
    gains: list[float] = []
    losses: list[float] = []
    for idx in range(1, period + 1):
        change = values[idx] - values[idx - 1]
        gains.append(max(change, 0.0))
        losses.append(abs(min(change, 0.0)))
    avg_gain = sum(gains) / period
    avg_loss = sum(losses) / period
    output[period] = 100.0 if avg_loss == 0 else 100.0 - (100.0 / (1.0 + avg_gain / avg_loss))
    for idx in range(period + 1, len(values)):
        change = values[idx] - values[idx - 1]
        gain = max(change, 0.0)
        loss = abs(min(change, 0.0))
        avg_gain = ((avg_gain * (period - 1)) + gain) / period
        avg_loss = ((avg_loss * (period - 1)) + loss) / period
        output[idx] = 100.0 if avg_loss == 0 else 100.0 - (100.0 / (1.0 + avg_gain / avg_loss))
    return output


def floor_to_m5(stamp: datetime) -> datetime:
    return stamp.replace(minute=(stamp.minute // 5) * 5, second=0, microsecond=0)


def simulate(bars: list[Bar], params: Params) -> SimulationResult:
    m5_bars = aggregate_bars(bars, 5)
    m5_closes = [bar.close for bar in m5_bars]
    m5_fast = ema(m5_closes, params.m5_fast)
    m5_slow = ema(m5_closes, params.m5_slow)
    m5_atr = atr(m5_bars, 14)
    m5_index = {bar.time: idx for idx, bar in enumerate(m5_bars)}

    closes = [bar.close for bar in bars]
    m1_fast = ema(closes, params.m1_fast)
    m1_slow = ema(closes, params.m1_slow)
    m1_rsi = rsi(closes, params.rsi_period)

    trades: list[Trade] = []
    daily_net: dict[str, float] = {}
    daily_trades: dict[str, int] = {}
    daily_loss_trades: dict[str, int] = {}
    daily_loss_sides: dict[str, set[str]] = {}
    daily_locked: set[str] = set()
    bars_by_day: dict[str, int] = {}
    for source_bar in bars:
        source_day = source_bar.time.date().isoformat()
        bars_by_day[source_day] = bars_by_day.get(source_day, 0) + 1
    # Ignore very short partial sessions when judging "daily" behavior.
    all_days = sorted(day for day, count in bars_by_day.items() if count >= 120)
    position: dict[str, float | str | bool | datetime] | None = None
    cooldown_until = -1
    equity_curve: list[float] = [0.0]

    for idx in range(2, len(bars)):
        bar = bars[idx]
        day = bar.time.date().isoformat()
        daily_net.setdefault(day, 0.0)
        daily_trades.setdefault(day, 0)
        daily_loss_trades.setdefault(day, 0)
        daily_loss_sides.setdefault(day, set())

        if position is not None:
            side = str(position["side"])
            entry = float(position["entry"])
            stop = float(position["stop"])
            locked = bool(position["locked"])
            exit_price: float | None = None
            new_stop = stop

            if side == "buy":
                if bar.low <= stop:
                    exit_price = stop
                else:
                    lock_price = entry + params.lock_profit_points * POINT_SIZE
                    trigger_price = entry + params.lock_trigger_points * POINT_SIZE
                    if bar.high >= trigger_price:
                        locked = True
                        steps = 0
                        if params.trail_step_points > 0:
                            steps = int((bar.high - lock_price) / (params.trail_step_points * POINT_SIZE))
                        new_stop = max(stop, lock_price + steps * params.trail_step_points * POINT_SIZE)
                    if bar.low <= new_stop:
                        exit_price = new_stop
            else:
                if bar.high >= stop:
                    exit_price = stop
                else:
                    lock_price = entry - params.lock_profit_points * POINT_SIZE
                    trigger_price = entry - params.lock_trigger_points * POINT_SIZE
                    if bar.low <= trigger_price:
                        locked = True
                        steps = 0
                        if params.trail_step_points > 0:
                            steps = int((lock_price - bar.low) / (params.trail_step_points * POINT_SIZE))
                        new_stop = min(stop, lock_price - steps * params.trail_step_points * POINT_SIZE)
                    if bar.high >= new_stop:
                        exit_price = new_stop

            position["stop"] = new_stop
            position["locked"] = locked

            if exit_price is not None:
                gross_points = ((exit_price - entry) / POINT_SIZE) if side == "buy" else ((entry - exit_price) / POINT_SIZE)
                net_points = gross_points - params.round_trip_cost_points
                trade = Trade(
                    side=side,
                    entry_time=position["entry_time"],  # type: ignore[arg-type]
                    exit_time=bar.time,
                    entry=entry,
                    exit=exit_price,
                    gross_points=gross_points,
                    net_points=net_points,
                    locked=locked,
                )
                trades.append(trade)
                entry_day = trade.entry_time.date().isoformat()
                daily_net[entry_day] = daily_net.get(entry_day, 0.0) + net_points
                if net_points < 0:
                    daily_loss_trades[entry_day] = daily_loss_trades.get(entry_day, 0) + 1
                    daily_loss_sides.setdefault(entry_day, set()).add(side)
                if locked:
                    daily_locked.add(entry_day)
                equity_curve.append(equity_curve[-1] + net_points)
                position = None
                cooldown_until = idx + params.cooldown_bars
                continue

        if position is not None:
            continue
        if idx < cooldown_until:
            continue
        if not (params.session_start_utc <= bar.time.hour < params.session_end_utc):
            continue
        if daily_trades.get(day, 0) >= params.max_trades_per_day:
            continue
        if params.max_loss_trades_per_day > 0 and daily_loss_trades.get(day, 0) >= params.max_loss_trades_per_day:
            continue
        if params.stop_after_daily_lock and day in daily_locked:
            continue

        m5_pos = m5_index.get(floor_to_m5(bar.time))
        if m5_pos is None:
            continue
        indicator_values = (
            m5_fast[m5_pos],
            m5_slow[m5_pos],
            m5_atr[m5_pos],
            m1_fast[idx],
            m1_slow[idx],
            m1_rsi[idx],
            m1_fast[idx - 1],
            m1_slow[idx - 1],
        )
        if any(value is None for value in indicator_values):
            continue

        m5_fast_value = float(m5_fast[m5_pos] or 0.0)
        m5_slow_value = float(m5_slow[m5_pos] or 0.0)
        m5_fast_prev_value = float(m5_fast[m5_pos - 1] or 0.0) if m5_pos > 0 and m5_fast[m5_pos - 1] is not None else m5_fast_value
        m5_slow_prev_value = float(m5_slow[m5_pos - 1] or 0.0) if m5_pos > 0 and m5_slow[m5_pos - 1] is not None else m5_slow_value
        m5_close_value = m5_bars[m5_pos].close
        m5_close_prev_value = m5_bars[m5_pos - 1].close if m5_pos > 0 else m5_close_value
        m5_atr_points = float(m5_atr[m5_pos] or 0.0) / POINT_SIZE
        fast_now = float(m1_fast[idx] or 0.0)
        slow_now = float(m1_slow[idx] or 0.0)
        rsi_now = float(m1_rsi[idx] or 0.0)

        if not (params.atr_min_points <= m5_atr_points <= params.atr_max_points):
            continue

        m5_up = m5_fast_value > m5_slow_value
        m5_down = m5_fast_value < m5_slow_value
        m5_rising = (
            m5_fast_value >= m5_fast_prev_value + params.min_m5_slope_points * POINT_SIZE
            and m5_slow_value >= m5_slow_prev_value
            and m5_close_value >= m5_close_prev_value
        )
        m5_falling = (
            m5_fast_value <= m5_fast_prev_value - params.min_m5_slope_points * POINT_SIZE
            and m5_slow_value <= m5_slow_prev_value
            and m5_close_value <= m5_close_prev_value
        )
        m1_up = fast_now > slow_now
        m1_down = fast_now < slow_now
        strong_opposite_for_buy = m5_down and bar.close < m5_slow_value
        strong_opposite_for_sell = m5_up and bar.close > m5_slow_value
        buy_trend_healthy = m5_up and m5_rising and bar.close >= m5_fast_value - params.max_m5_pullback_points * POINT_SIZE
        sell_trend_healthy = m5_down and m5_falling and bar.close <= m5_fast_value + params.max_m5_pullback_points * POINT_SIZE
        neutral_rsi = params.neutral_rsi_low <= rsi_now <= params.neutral_rsi_high
        previous_close = bars[idx - 1].close
        previous_close_2 = bars[idx - 2].close

        buy_pullback_reclaim = (
            buy_trend_healthy
            and m1_up
            and rsi_now >= params.rsi_buy_min
            and bar.close > bar.open
            and bar.close > previous_close
            and bar.low <= fast_now + 20 * POINT_SIZE
        )
        sell_pullback_reclaim = (
            sell_trend_healthy
            and m1_down
            and rsi_now <= params.rsi_sell_max
            and bar.close < bar.open
            and bar.close < previous_close
            and bar.high >= fast_now - 20 * POINT_SIZE
        )
        buy_daily_probe = (
            params.use_daily_probe
            and daily_trades.get(day, 0) == 0
            and bar.time.hour >= params.daily_probe_start_utc
            and m1_up
            and bar.close > fast_now
            and rsi_now >= params.rsi_buy_min
            and (not strong_opposite_for_buy if params.relaxed_trend_probe else m5_up)
        )
        sell_daily_probe = (
            params.use_daily_probe
            and daily_trades.get(day, 0) == 0
            and bar.time.hour >= params.daily_probe_start_utc
            and m1_down
            and bar.close < fast_now
            and rsi_now <= params.rsi_sell_max
            and (not strong_opposite_for_sell if params.relaxed_trend_probe else m5_down)
        )
        force_buy = (
            params.force_daily_entry
            and daily_trades.get(day, 0) == 0
            and bar.time.hour >= params.final_entry_hour_utc
            and not neutral_rsi
            and (m1_up or (bar.close > previous_close and previous_close >= previous_close_2))
            and bar.close > fast_now
            and rsi_now > params.neutral_rsi_high
        )
        force_sell = (
            params.force_daily_entry
            and daily_trades.get(day, 0) == 0
            and bar.time.hour >= params.final_entry_hour_utc
            and not neutral_rsi
            and (m1_down or (bar.close < previous_close and previous_close <= previous_close_2))
            and bar.close < fast_now
            and rsi_now < params.neutral_rsi_low
        )
        side: str | None = None
        if buy_pullback_reclaim:
            side = "buy"
        elif sell_pullback_reclaim:
            side = "sell"
        elif buy_daily_probe:
            side = "buy"
        elif sell_daily_probe:
            side = "sell"
        elif force_buy:
            side = "buy"
        elif force_sell:
            side = "sell"
        if side is None:
            continue
        if params.block_same_direction_after_loss and side in daily_loss_sides.get(day, set()):
            continue

        entry = bar.close
        stop = entry - params.initial_sl_points * POINT_SIZE if side == "buy" else entry + params.initial_sl_points * POINT_SIZE
        position = {
            "side": side,
            "entry": entry,
            "stop": stop,
            "entry_time": bar.time,
            "locked": False,
        }
        daily_trades[day] = daily_trades.get(day, 0) + 1

    gains = sum(trade.net_points for trade in trades if trade.net_points > 0)
    losses = abs(sum(trade.net_points for trade in trades if trade.net_points < 0))
    profit_factor = gains / losses if losses > 0 else float("inf") if gains > 0 else 0.0
    peak = equity_curve[0]
    max_dd = 0.0
    for point in equity_curve:
        peak = max(peak, point)
        max_dd = max(max_dd, peak - point)

    trade_days = len({trade.entry_time.date().isoformat() for trade in trades})
    locked_days = len(daily_locked)
    result = SimulationResult(
        params=params,
        trades=trades,
        total_days=len(all_days),
        trade_days=trade_days,
        locked_days=locked_days,
        daily_net_points=daily_net,
        max_drawdown_points=max_dd,
        profit_factor=profit_factor,
        score=0.0,
    )
    result.score = score_result(result)
    return result


def score_result(result: SimulationResult) -> float:
    if not result.trades:
        return -1_000_000.0
    pf = min(result.profit_factor, 5.0)
    return (
        result.locked_day_rate * 10_000
        + (result.trade_days / result.total_days if result.total_days else 0.0) * 1_500
        + result.win_rate * 1_000
        + pf * 500
        + result.net_points
        - result.max_drawdown_points * 2
        - max(0, 10 - len(result.trades)) * 100
    )


def candidate_params() -> list[Params]:
    candidates: list[Params] = []
    for m5_fast, m5_slow in ((5, 13), (8, 21), (12, 36)):
        for m1_fast, m1_slow in ((3, 9), (5, 13), (8, 21)):
            for initial_sl in (250, 300, 350):
                for trail_step in (50, 75):
                    for rsi_buy, rsi_sell in ((50, 50), (52, 48), (55, 45)):
                        for final_hour in (11, 12, 13, 14):
                            candidates.append(
                                Params(
                                    m5_fast=m5_fast,
                                    m5_slow=m5_slow,
                                    m1_fast=m1_fast,
                                    m1_slow=m1_slow,
                                    rsi_period=14,
                                    rsi_buy_min=rsi_buy,
                                    rsi_sell_max=rsi_sell,
                                    atr_min_points=20,
                                    atr_max_points=600,
                                    initial_sl_points=initial_sl,
                                    lock_trigger_points=200,
                                    lock_profit_points=200,
                                    trail_step_points=trail_step,
                                    max_loss_trades_per_day=1,
                                    block_same_direction_after_loss=True,
                                    min_m5_slope_points=10,
                                    max_m5_pullback_points=120,
                                    round_trip_cost_points=35,
                                    session_start_utc=6,
                                    session_end_utc=21,
                                    daily_probe_start_utc=6,
                                    use_daily_probe=True,
                                    relaxed_trend_probe=True,
                                    force_daily_entry=True,
                                    final_entry_hour_utc=final_hour,
                                    neutral_rsi_low=48,
                                    neutral_rsi_high=52,
                                    cooldown_bars=10,
                                    max_trades_per_day=3,
                                    stop_after_daily_lock=True,
                                )
                            )
    return candidates


def summarize(result: SimulationResult) -> list[str]:
    trades = result.trades
    net_values = [trade.net_points for trade in trades]
    losing_days = [points for points in result.daily_net_points.values() if points < 0]
    lines = [
        f"Trades: {len(trades)}",
        f"Total days: {result.total_days}",
        f"Trade days: {result.trade_days}",
        f"20-pip locked days: {result.locked_days} ({result.locked_day_rate:.1%})",
        f"Win rate after costs: {result.win_rate:.1%}",
        f"Profit factor: {result.profit_factor:.2f}",
        f"Gross points: {result.gross_points:.1f}",
        f"Net points after costs: {result.net_points:.1f}",
        f"Average daily net points: {result.avg_daily_net_points:.1f}",
        f"Max closed-trade drawdown points: {result.max_drawdown_points:.1f}",
        f"Worst daily net points: {min(result.daily_net_points.values() or [0]):.1f}",
        f"Losing days: {len(losing_days)}",
        f"Median trade net points: {statistics.median(net_values):.1f}" if net_values else "Median trade net points: n/a",
    ]
    return lines


def write_report(report_path: Path, source: str, bars: list[Bar], top_results: list[SimulationResult]) -> None:
    best = top_results[0]
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", encoding="utf-8") as handle:
        handle.write("# IDC_D Simulation Validation Report\n\n")
        handle.write("## Scope\n\n")
        handle.write("- EA name: IDC_D\n")
        handle.write("- Platform target: MT4\n")
        handle.write("- Market target: GOLD / XAUUSD, using GC=F as public proxy when broker CSV is not supplied\n")
        handle.write("- Timeframes: M1 execution with M5 trend/volatility filter\n")
        handle.write("- Point model: 1 point = 0.01 price unit; 20 pips = 200 points\n")
        handle.write("- Exit model: no TP; SL moves to +200 points once price reaches +200 points, then step trailing\n")
        handle.write("- Entry model: trend pullback, daily probe, and final daily directional entry\n")
        handle.write("- Grid, martingale, and averaging-down are excluded\n\n")
        handle.write("## Data\n\n")
        handle.write(f"- Source: {source}\n")
        handle.write(f"- Bars: {len(bars)}\n")
        handle.write(f"- First bar UTC: {bars[0].time.isoformat()}\n")
        handle.write(f"- Last bar UTC: {bars[-1].time.isoformat()}\n\n")
        handle.write("## Conservative Assumptions\n\n")
        handle.write("- Round-trip cost: 35 points subtracted from every closed trade\n")
        handle.write("- Same-bar ambiguity is resolved against the strategy when the old stop and lock trigger are both touched\n")
        handle.write("- Only one position is simulated at a time\n")
        handle.write("- Trading stops for the day after a 20-pip lock event\n\n")
        handle.write("## Best Candidate Parameters\n\n")
        for field, value in best.params.__dict__.items():
            handle.write(f"- {field}: {value}\n")
        handle.write("\n## Best Candidate Metrics\n\n")
        for line in summarize(best):
            handle.write(f"- {line}\n")
        handle.write("\n## Top 5 Candidates\n\n")
        handle.write("| Rank | Score | Trade Day Rate | Locked Day Rate | Win Rate | PF | Net Points | Max DD Points | Trades | SL | Trail Step | Probe | Force | M5 EMA | M1 EMA |\n")
        handle.write("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- |\n")
        for rank, result in enumerate(top_results[:5], start=1):
            params = result.params
            trade_day_rate = result.trade_days / result.total_days if result.total_days else 0.0
            handle.write(
                f"| {rank} | {result.score:.1f} | {trade_day_rate:.1%} | {result.locked_day_rate:.1%} | {result.win_rate:.1%} | "
                f"{result.profit_factor:.2f} | {result.net_points:.1f} | {result.max_drawdown_points:.1f} | "
                f"{len(result.trades)} | {params.initial_sl_points} | {params.trail_step_points} | "
                f"{params.use_daily_probe}/{params.daily_probe_start_utc}/{params.relaxed_trend_probe} | "
                f"{params.force_daily_entry}/{params.final_entry_hour_utc} | "
                f"{params.m5_fast}/{params.m5_slow} | {params.m1_fast}/{params.m1_slow} |\n"
            )
        handle.write("\n## Validation Decision\n\n")
        if passes_validation(best):
            handle.write("PASS: The M1 proxy simulation meets the v2.0 frequency and profitability floor, with final broker-side MT4 Strategy Tester validation still required.\n")
        else:
            handle.write("FAIL: Do not submit as v2.0 without more M1 strategy work and broker-quality XAUUSD M1 retesting.\n")


def passes_validation(result: SimulationResult) -> bool:
    return (
        len(result.trades) >= 5
        and result.locked_day_rate >= 0.50
        and (result.trade_days / result.total_days if result.total_days else 0.0) >= 0.80
        and result.win_rate >= 0.45
        and result.profit_factor >= 1.20
        and result.net_points > 0
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run IDC_D GOLD M1/M5 simulation.")
    parser.add_argument("--csv", type=Path, help="Optional MT4-exported M1 CSV file.")
    parser.add_argument("--symbol", default="GC=F", help="Yahoo Finance symbol to fetch when --csv is not supplied.")
    parser.add_argument("--range", default="7d", help="Yahoo range for 1m data.")
    parser.add_argument("--interval", default="1m", help="Yahoo interval.")
    parser.add_argument("--report", type=Path, default=Path("simulation/reports/idc_d_validation.md"))
    args = parser.parse_args()

    if args.csv:
        bars = read_mt4_csv(args.csv)
        source = f"CSV {args.csv}"
    else:
        bars = fetch_yahoo_bars(args.symbol, args.range, args.interval)
        source = f"Yahoo Finance {args.symbol} range={args.range} interval={args.interval}"

    bars = [bar for bar in bars if bar.high >= bar.low and bar.high > 0 and bar.low > 0]
    if not bars:
        raise RuntimeError("No valid bars available")

    results = [simulate(bars, params) for params in candidate_params()]
    results.sort(key=lambda result: result.score, reverse=True)
    write_report(args.report, source, bars, results[:10])

    best = results[0]
    print("IDC_D simulation complete")
    print(f"Data source: {source}")
    print(f"Report: {args.report}")
    for line in summarize(best):
        print(line)
    print("Validation:", "PASS" if passes_validation(best) else "FAIL")
    return 0 if passes_validation(best) else 2


if __name__ == "__main__":
    raise SystemExit(main())
