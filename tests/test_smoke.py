import pandas as pd

from strategy.backtest import StrategyConfig, run_backtest
from strategy.indicators import compute_ma


def test_ma_types_finite():
    s = pd.Series(range(1, 80), dtype=float)
    for ma_type in ("sma", "ema", "wma", "jma"):
        out = compute_ma(s, ma_type, 21)
        assert out.dropna().shape[0] > 0


def test_backtest_runs():
    idx = pd.date_range("2020-01-01", periods=300, freq="B")
    close = pd.Series(1.1 + (pd.Series(range(300)) * 0.0001).values, index=idx)
    df = pd.DataFrame(
        {
            "Open": close,
            "High": close + 0.001,
            "Low": close - 0.001,
            "Close": close,
        }
    )
    res = run_backtest(df, StrategyConfig(ma_type="wma", ma_period=21, mode="flip"))
    assert res["total_months"] > 0
    assert "consistency_score" in res
