#!/usr/bin/env python3
"""IDC_3 pure-logic unit checks (no MT4). Exit 0 = all pass."""

def is_inside(h1, l1, h2, l2):
    return h2 < h1 and l2 > l1

def signal(h2, l2, c3):
    buy = c3 > h2
    sell = c3 < l2
    if buy and not sell:
        return "BUY"
    if sell and not buy:
        return "SELL"
    return "CANCEL"

def trail_lock_pts(profit, start, step):
    """IDC standard: lock = Start + floor((profit-Start)/Step)*Step. NOT BE."""
    if profit < start:
        return None
    steps = int((profit - start) // step)
    return start + steps * step

def main():
    fails = []

    if not is_inside(2000, 1000, 1800, 1200):
        fails.append("R01 expect inside")
    if is_inside(2000, 1000, 2000, 1200):
        fails.append("R01 equal high must fail")
    if is_inside(2000, 1000, 1800, 1000):
        fails.append("R01 equal low must fail")
    if is_inside(2000, 1000, 2100, 1200):
        fails.append("R01 outside high must fail")

    if signal(1800, 1200, 1199) != "SELL":
        fails.append("R03 SELL close below L2")
    if signal(1800, 1200, 1801) != "BUY":
        fails.append("R03 BUY close above H2")
    if signal(1800, 1200, 1500) != "CANCEL":
        fails.append("R04 inside close = CANCEL")
    if signal(1800, 1200, 1800) != "CANCEL":
        fails.append("R03 touch high not break")
    if signal(1800, 1200, 1200) != "CANCEL":
        fails.append("R03 touch low not break")

    # IDC trailing (NOT BE / entry)
    if trail_lock_pts(199, 200, 10) is not None:
        fails.append("trail < start keeps initial")
    if trail_lock_pts(200, 200, 10) != 200:
        fails.append("trail @start => lock Start (200), NOT BE/0")
    if trail_lock_pts(209, 200, 10) != 200:
        fails.append("trail 209 => still 200")
    if trail_lock_pts(210, 200, 10) != 210:
        fails.append("trail 210 => 210")
    if trail_lock_pts(220, 200, 10) != 220:
        fails.append("trail 220 => 220")
    if trail_lock_pts(231, 200, 10) != 230:
        fails.append("trail 231 => 230")
    # reject old wrong BE formula
    if trail_lock_pts(200, 200, 10) == 0:
        fails.append("REGRESSION: BE formula must not return")

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
    print("PASS: trail=Start+steps*Step (NOT BE) + entry rules")

if __name__ == "__main__":
    main()
