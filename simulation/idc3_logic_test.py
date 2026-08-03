#!/usr/bin/env python3
"""IDC_3 v1.04 — close break, body>sum(wicks), trail=Start+steps*Step (NOT BE)."""

def close_break_buy(c3, h2):
    return c3 > h2

def close_break_sell(c3, l2):
    return c3 < l2

def wick_only_buy(h3, c3, h2):
    return h3 > h2 and c3 <= h2

def body_gt_wicks(o, h, l, c):
    body = abs(c - o)
    upper = max(0.0, h - max(o, c))
    lower = max(0.0, min(o, c) - l)
    return body > upper and body > lower and body > (upper + lower)

def trail_lock(profit, start, step):
    """User lock: @Start → SL at +/-Start; then +step from that point."""
    if profit < start:
        return None
    steps = int((profit - start) // step)
    return start + steps * step

def main():
    fails = []

    if not wick_only_buy(110, 105, 108):
        fails.append("wick-only buy")
    if close_break_buy(105, 108):
        fails.append("wick-only must not close-break")
    if not close_break_buy(109, 108):
        fails.append("close buy")
    if not close_break_sell(91, 92):
        fails.append("close sell")

    if body_gt_wicks(100, 150, 85, 130):  # 30 vs 20+15
        fails.append("weak body must fail")
    if not body_gt_wicks(100, 150, 100, 140):  # 40 vs 10+10
        fails.append("strong body must pass")

    # USER TRAIL COMMAND — NOT BE
    if trail_lock(199, 200, 10) is not None:
        fails.append("<start no trail")
    if trail_lock(200, 200, 10) != 200:
        fails.append("@200 must lock 200 (NOT 0/BE)")
    if trail_lock(209, 200, 10) != 200:
        fails.append("209 still 200")
    if trail_lock(210, 200, 10) != 210:
        fails.append("210 => 210")
    if trail_lock(220, 200, 10) != 220:
        fails.append("220 => 220")
    if trail_lock(231, 200, 10) != 230:
        fails.append("231 => 230")
    if trail_lock(200, 200, 10) == 0:
        fails.append("REGRESSION: BE formula forbidden")

    if fails:
        print("FAIL:")
        for f in fails:
            print(" -", f)
        raise SystemExit(1)
    print("PASS: trail=Start+steps*Step (user command) + close/body locks")

if __name__ == "__main__":
    main()
