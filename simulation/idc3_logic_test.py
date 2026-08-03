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

def body_gt_wicks(o, h, l, c):
    body = abs(c - o)
    upper = h - max(o, c)
    lower = min(o, c) - l
    if upper < 0:
        upper = 0
    if lower < 0:
        lower = 0
    return body > upper and body > lower

def trail_lock_from_be(profit, start, step):
    """원본: Start→본전(BE=0 from open), 이후 step 추종."""
    if profit < start:
        return None
    steps = int((profit - start) // step)
    return steps * step  # 0 at start = BE

def main():
    fails = []

    if not is_inside(2000, 1000, 1800, 1200):
        fails.append("R01 expect inside")
    if is_inside(2000, 1000, 2000, 1200):
        fails.append("R01 equal high must fail")
    if is_inside(2000, 1000, 1800, 1000):
        fails.append("R01 equal low must fail")

    if signal(1800, 1200, 1199) != "SELL":
        fails.append("R03 SELL")
    if signal(1800, 1200, 1801) != "BUY":
        fails.append("R03 BUY")
    if signal(1800, 1200, 1500) != "CANCEL":
        fails.append("R04 CANCEL")

    # R03c body > each wick
    # open=100, close=130, high=135, low=95 → body=30, up=5, dn=5 → OK
    if not body_gt_wicks(100, 135, 95, 130):
        fails.append("R03c expect pass body>wicks")
    # body=10, up=20, dn=5 → FAIL
    if body_gt_wicks(100, 130, 95, 110):
        fails.append("R03c expect fail upper wick")
    # body=10, up=2, dn=15 → FAIL
    if body_gt_wicks(100, 112, 85, 110):
        fails.append("R03c expect fail lower wick")
    # body == upper → FAIL (strict >)
    if body_gt_wicks(100, 120, 95, 110):
        fails.append("R03c equal upper must fail")
    # doji body=0 → FAIL
    if body_gt_wicks(100, 110, 90, 100):
        fails.append("R03c doji must fail")

    # Original trailing: BE then step
    if trail_lock_from_be(199, 200, 10) is not None:
        fails.append("trail < start")
    if trail_lock_from_be(200, 200, 10) != 0:
        fails.append("trail @200 => BE (0)")
    if trail_lock_from_be(209, 200, 10) != 0:
        fails.append("trail 209 => still BE")
    if trail_lock_from_be(210, 200, 10) != 10:
        fails.append("trail 210 => +10")
    if trail_lock_from_be(220, 200, 10) != 20:
        fails.append("trail 220 => +20")
    if trail_lock_from_be(231, 200, 10) != 30:
        fails.append("trail 231 => +30")

    if fails:
        print("FAIL:")
        for f in fails:
            print(" -", f)
        raise SystemExit(1)
    print("PASS: original BE-trail + R03c body>wicks")

if __name__ == "__main__":
    main()
