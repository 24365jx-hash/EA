"""Moving-average helpers. Strategy uses exactly one MA series."""

from __future__ import annotations

import numpy as np
import pandas as pd


def sma(series: pd.Series, period: int) -> pd.Series:
    return series.rolling(window=period, min_periods=period).mean()


def ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False, min_periods=period).mean()


def wma(series: pd.Series, period: int) -> pd.Series:
    weights = np.arange(1, period + 1, dtype=float)

    def _wma(window: np.ndarray) -> float:
        return float(np.dot(window, weights) / weights.sum())

    return series.rolling(window=period, min_periods=period).apply(_wma, raw=True)


def jma(series: pd.Series, period: int, phase: float = 50.0) -> pd.Series:
    """
    Jurik-style adaptive MA approximation (public recursive form).

    Not the proprietary Jurik Research binary; used only as a comparable
    single-MA candidate against EMA/SMA/WMA.
    """
    if period < 1:
        raise ValueError("period must be >= 1")

    phase_ratio = 0.5 if phase < -100 else (2.5 if phase > 100 else phase / 100.0 + 1.5)
    beta = 0.45 * (period - 1) / (0.45 * (period - 1) + 2.0)
    alpha = beta ** (phase_ratio if phase_ratio > 0 else 1.0)

    values = series.to_numpy(dtype=float)
    out = np.full(len(values), np.nan, dtype=float)
    e0 = e1 = e2 = jma_prev = 0.0
    started = False

    for i, price in enumerate(values):
        if np.isnan(price):
            continue
        if not started:
            e0 = e1 = e2 = jma_prev = price
            out[i] = price
            started = True
            continue

        e0 = (1 - alpha) * price + alpha * e0
        e1 = (price - e0) * (1 - beta) + beta * e1
        e2 = (e0 + phase_ratio * e1 - jma_prev) * ((1 - alpha) ** 2) + (
            alpha ** 2
        ) * jma_prev
        jma_prev = e2
        out[i] = jma_prev

    result = pd.Series(out, index=series.index, name=f"jma_{period}")
    # Warm-up: first `period` bars are unstable
    result.iloc[:period] = np.nan
    return result


MA_FUNCS = {
    "sma": sma,
    "ema": ema,
    "wma": wma,
    "jma": jma,
}


def compute_ma(close: pd.Series, ma_type: str, period: int) -> pd.Series:
    key = ma_type.lower()
    if key not in MA_FUNCS:
        raise ValueError(f"Unsupported MA type: {ma_type}. Choose from {list(MA_FUNCS)}")
    return MA_FUNCS[key](close, period)
