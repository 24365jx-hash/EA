"""
Research runner: download FX data, grid-search single-MA configs,
walk-forward validate, and write submission artifacts.
"""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path

import pandas as pd
import yfinance as yf

from .backtest import StrategyConfig, run_backtest, walk_forward

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "results"
DATA = ROOT / "data"


def download_pair(symbol: str, years: int = 10) -> pd.DataFrame:
    DATA.mkdir(parents=True, exist_ok=True)
    ticker = f"{symbol}=X"
    raw = yf.download(ticker, period=f"{years}y", interval="1d", auto_adjust=True, progress=False)
    if isinstance(raw.columns, pd.MultiIndex):
        raw.columns = raw.columns.get_level_values(0)
    df = raw[["Open", "High", "Low", "Close"]].dropna().copy()
    df.index = pd.to_datetime(df.index)
    path = DATA / f"{symbol}_D1.csv"
    df.to_csv(path)
    return df


def pip_settings(symbol: str) -> dict:
    if symbol.endswith("JPY"):
        return {"pip_size": 0.01, "pip_value_per_lot": 100000 * 0.01 / 150.0}  # approx USD
    # XXXUSD pairs: $10/pip per standard lot
    return {"pip_size": 0.0001, "pip_value_per_lot": 10.0}


def grid_search(df: pd.DataFrame, symbol: str) -> pd.DataFrame:
    pip = pip_settings(symbol)
    rows = []
    for ma_type in ("ema", "sma", "wma", "jma"):
        for period in (21, 34, 50, 55, 89, 100):
            for mode in ("flip", "slope_flip", "pullback"):
                for rr in (1.5, 2.0, 2.5):
                    cfg = StrategyConfig(
                        ma_type=ma_type,
                        ma_period=period,
                        mode=mode,
                        rr=rr,
                        initial_capital=4000.0,
                        **pip,
                    )
                    res = run_backtest(df, cfg)
                    rows.append(
                        {
                            "symbol": symbol,
                            "ma_type": ma_type,
                            "ma_period": period,
                            "mode": mode,
                            "rr": rr,
                            "trades": res["trades"],
                            "win_rate": round(res["win_rate"], 4),
                            "profit_factor": round(res["profit_factor"], 4)
                            if res["profit_factor"] != float("inf")
                            else None,
                            "total_return": round(res["total_return"], 4),
                            "max_drawdown": round(res["max_drawdown"], 4),
                            "positive_month_rate": round(res["positive_month_rate"], 4),
                            "avg_monthly_pnl": round(res["avg_monthly_pnl"], 2),
                            "median_monthly_pnl": round(res["median_monthly_pnl"], 2),
                            "monthly_pnl_std": round(res["monthly_pnl_std"], 2),
                            "withdrawn_total": round(res["withdrawn_total"], 2),
                            "final_equity": round(res["final_equity"], 2),
                            "total_wealth": round(res["total_wealth"], 2),
                            "consistency_score": round(res["consistency_score"], 6),
                        }
                    )
    return pd.DataFrame(rows)


def select_champion(grid: pd.DataFrame) -> pd.Series:
    """
    Selection rules for monthly-income objective:
    1) enough trades (>= 40)
    2) positive expectancy (PF > 1.1, total_return > 0)
    3) max DD <= 35%
    4) maximize consistency_score, then positive_month_rate, then median monthly pnl
    """
    eligible = grid[
        (grid["trades"] >= 40)
        & (grid["profit_factor"].fillna(0) > 1.1)
        & (grid["total_return"] > 0)
        & (grid["max_drawdown"] <= 0.35)
        & (grid["positive_month_rate"] >= 0.45)
    ].copy()
    if eligible.empty:
        # Soft fallback: best consistency among PF>1 and DD<=40%
        eligible = grid[
            (grid["trades"] >= 30)
            & (grid["profit_factor"].fillna(0) > 1.0)
            & (grid["max_drawdown"] <= 0.40)
        ].copy()
    if eligible.empty:
        return grid.sort_values("consistency_score", ascending=False).iloc[0]
    return eligible.sort_values(
        ["consistency_score", "positive_month_rate", "median_monthly_pnl"],
        ascending=[False, False, False],
    ).iloc[0]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pairs = ["EURUSD", "GBPUSD", "USDJPY"]
    all_grids = []
    champions = []
    wf_summaries = []

    for symbol in pairs:
        print(f"=== {symbol} ===")
        df = download_pair(symbol, years=10)
        print(f"bars={len(df)} from {df.index.min().date()} to {df.index.max().date()}")
        grid = grid_search(df, symbol)
        all_grids.append(grid)
        grid_path = OUT / f"grid_{symbol}.csv"
        grid.to_csv(grid_path, index=False)

        champ = select_champion(grid)
        champions.append(champ.to_dict())
        print(
            "champion:",
            champ["ma_type"],
            champ["ma_period"],
            champ["mode"],
            "rr",
            champ["rr"],
            "pos_month",
            champ["positive_month_rate"],
            "avg_month$",
            champ["avg_monthly_pnl"],
            "dd",
            champ["max_drawdown"],
        )

        pip = pip_settings(symbol)
        cfg = StrategyConfig(
            ma_type=champ["ma_type"],
            ma_period=int(champ["ma_period"]),
            mode=champ["mode"],
            rr=float(champ["rr"]),
            initial_capital=4000.0,
            **pip,
        )
        full = run_backtest(df, cfg)
        full["monthly_df"].to_csv(OUT / f"monthly_{symbol}.csv", index=False)
        full["trades_df"].to_csv(OUT / f"trades_{symbol}.csv", index=False)
        full["equity_df"].to_csv(OUT / f"equity_{symbol}.csv")

        # Walk-forward with fixed MA type from champion (optimize period/mode OOS)
        wf_cfg = StrategyConfig(ma_type=champ["ma_type"], initial_capital=4000.0, rr=float(champ["rr"]), **pip)
        wf = walk_forward(df, wf_cfg, train_years=3, test_years=1)
        wf_summaries.append(
            {
                "symbol": symbol,
                "ma_type": champ["ma_type"],
                "oos_months": wf["oos_months"],
                "oos_positive_month_rate": round(wf["oos_positive_month_rate"], 4),
                "oos_avg_monthly_pnl": round(wf["oos_avg_monthly_pnl"], 2),
                "oos_median_monthly_pnl": round(wf["oos_median_monthly_pnl"], 2),
                "oos_trades": wf["oos_trades"],
                "folds": wf["folds"],
            }
        )
        if not wf["monthly_df"].empty:
            wf["monthly_df"].to_csv(OUT / f"wf_monthly_{symbol}.csv", index=False)

        # Persist champion detail without bulky frames
        detail = {
            k: v
            for k, v in full.items()
            if k not in {"trades_df", "monthly_df", "equity_df", "config"}
        }
        detail["config"] = asdict(cfg)
        detail["in_sample_grid_rank_metrics"] = champ.to_dict()
        with open(OUT / f"champion_{symbol}.json", "w", encoding="utf-8") as f:
            json.dump(detail, f, indent=2, default=str)

    grid_all = pd.concat(all_grids, ignore_index=True)
    grid_all.to_csv(OUT / "grid_all.csv", index=False)
    with open(OUT / "champions.json", "w", encoding="utf-8") as f:
        json.dump(champions, f, indent=2)
    with open(OUT / "walk_forward.json", "w", encoding="utf-8") as f:
        json.dump(wf_summaries, f, indent=2)

    # Portfolio view: trade only the best pair by OOS consistency then IS median month
    best_symbol = max(
        wf_summaries,
        key=lambda x: (x["oos_positive_month_rate"], x["oos_median_monthly_pnl"]),
    )["symbol"]
    primary = next(c for c in champions if c["symbol"] == best_symbol)
    summary = {
        "objective": "monthly_income_consistency_single_ma",
        "initial_capital_usd": 4000,
        "primary_pair": best_symbol,
        "primary_strategy": primary,
        "all_champions": champions,
        "walk_forward": wf_summaries,
        "selection_notes": [
            "Exactly one MA series is used for signals and MA-exit.",
            "Stop distance is derived from entry-to-MA gap (same MA), not a second indicator.",
            "Champion chosen for consistency_score under PF/DD/trade-count gates.",
            "Walk-forward re-selects period/mode annually on a 3y train / 1y test schedule.",
        ],
    }
    with open(OUT / "summary.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, default=str)

    print("\nPRIMARY:", best_symbol)
    print(json.dumps(primary, indent=2))
    print("Wrote artifacts to", OUT)


if __name__ == "__main__":
    main()
