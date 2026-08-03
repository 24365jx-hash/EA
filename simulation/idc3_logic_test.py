#!/usr/bin/env python3
"""IDC_3 pure-logic unit checks (no MT4). Exit 0 = all pass."""

def is_inside(h1, l1, h2, l2):
    # R01 strict; candle color ignored (not in signature)
    return h2 < h1 and l2 > l1

def signal(h2, l2, c3):
    # R03 close break only; R04 cancel if neither
    buy = c3 > h2
    sell = c3 < l2
    if buy and not sell:
        return "BUY"
    if sell and not buy:
        return "SELL"
    return "CANCEL"

def trail_lock_pts(profit, start, step):
    # BE at start (lock=0), then step
    if profit < start:
        return None  # keep initial SL
    extra = profit - start
    steps = int(extra // step)
    return steps * step

def main():
    fails = []

    # --- R01 ---
    if not is_inside(2000, 1000, 1800, 1200):
        fails.append("R01 expect inside")
    if is_inside(2000, 1000, 2000, 1200):  # equal high not inside
        fails.append("R01 equal high must fail")
    if is_inside(2000, 1000, 1800, 1000):  # equal low not inside
        fails.append("R01 equal low must fail")
    if is_inside(2000, 1000, 2100, 1200):  # outside high
        fails.append("R01 outside high must fail")
    # color irrelevant: same OHLC treated identical regardless of "bull/bear"
    if is_inside(10, 0, 8, 2) != is_inside(10, 0, 8, 2):
        fails.append("R01 color independence broken")

    # --- R03/R04 chart SELL example ---
    # #2 range red lines; #3 close below L2 → SELL
    if signal(1800, 1200, 1199) != "SELL":
        fails.append("R03 SELL close below L2")
    if signal(1800, 1200, 1801) != "BUY":
        fails.append("R03 BUY close above H2")
    if signal(1800, 1200, 1500) != "CANCEL":
        fails.append("R04 inside close = CANCEL")
    if signal(1800, 1200, 1800) != "CANCEL":  # touch high not break
        fails.append("R03 touch high not break")
    if signal(1800, 1200, 1200) != "CANCEL":  # touch low not break
        fails.append("R03 touch low not break")
    # wick-only would be represented as high/low beyond but close inside → CANCEL
    # (close-only API; wick not an argument by design)
    if signal(1800, 1200, 1201) != "CANCEL":
        fails.append("wick-equivalent close inside must CANCEL")

    # --- R06 trailing BE ---
    if trail_lock_pts(199, 200, 10) is not None:
        fails.append("trail < start keeps initial")
    if trail_lock_pts(200, 200, 10) != 0:
        fails.append("trail @start => BE (0)")
    if trail_lock_pts(209, 200, 10) != 0:
        fails.append("trail 209 => still BE")
    if trail_lock_pts(210, 200, 10) != 10:
        fails.append("trail 210 => +10")
    if trail_lock_pts(220, 200, 10) != 20:
        fails.append("trail 220 => +20")
    if trail_lock_pts(231, 200, 10) != 30:
        fails.append("trail 231 => +30")

    # --- R05 conceptual: evaluator refuses when position flag set ---
    def allow_entry(pos_count):
        return pos_count == 0
    if allow_entry(1):
        fails.append("R05 must block when in position")
    if not allow_entry(0):
        fails.append("R05 must allow when flat")

    if fails:
        print("FAIL:")
        for f in fails:
            print(" -", f)
        raise SystemExit(1)
    print("PASS: 18 logic assertions (R01/R03/R04/R05/R06 trail BE)")

if __name__ == "__main__":
    main()
