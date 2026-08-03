#!/usr/bin/env python3
"""IDC_3 v1.07 locks: strict inside, body>each (NO sum), trail Start+step, close break."""

def strict_inside(h1, l1, h2, l2):
    return h2 < h1 and l2 > l1

def body_each(o, h, l, c):
    b = abs(c - o)
    u = max(0.0, h - max(o, c))
    d = max(0.0, min(o, c) - l)
    return b > u and b > d

def body_sum_bug(o, h, l, c):
    """v1.04 wrongful extra filter — must NOT be required."""
    b = abs(c - o)
    u = max(0.0, h - max(o, c))
    d = max(0.0, min(o, c) - l)
    return body_each(o, h, l, c) and b > (u + d)

def close_break_buy(c3, h2):
    return c3 > h2

def close_break_sell(c3, l2):
    return c3 < l2

def wick_only_buy(h3, c3, h2):
    return h3 > h2 and c3 <= h2

def wick_only_sell(l3, c3, l2):
    return l3 < l2 and c3 >= l2

def trail_lock(profit, start, step):
    if profit < start:
        return None
    return start + int((profit - start) // step) * step

def is_profit_side_sl(side, open_p, sl, point=0.01):
    if sl <= 0:
        return False
    if side == "BUY":
        return sl > open_p + point * 0.1
    if side == "SELL":
        return sl < open_p - point * 0.1
    return False

def main():
    fails = []

    # --- R01 strict inside ---
    if strict_inside(100, 90, 100, 92):
        fails.append("R01 equal high must FAIL")
    if strict_inside(100, 90, 98, 90):
        fails.append("R01 equal low must FAIL")
    if strict_inside(100, 90, 100, 90):
        fails.append("R01 equal both must FAIL")
    if not strict_inside(100, 90, 98, 92):
        fails.append("R01 clear cover must PASS")

    # --- R03 close break ---
    if not close_break_buy(101.0, 100.0):
        fails.append("R03 buy close break")
    if close_break_buy(100.0, 100.0):
        fails.append("R03 equal close must NOT buy")
    if not close_break_sell(99.0, 100.0):
        fails.append("R03 sell close break")
    if close_break_sell(100.0, 100.0):
        fails.append("R03 equal close must NOT sell")
    if not wick_only_buy(101.0, 100.0, 100.0):
        fails.append("R03b wick-only buy detect")
    if not wick_only_sell(99.0, 100.0, 100.0):
        fails.append("R03b wick-only sell detect")
    if wick_only_buy(101.0, 101.5, 100.0):
        fails.append("R03b real close buy is not wick-only")

    # --- R03c body > each wick ONLY (sum forbidden) ---
    # body=25, up=15, dn=12 → each PASS, sum 27 FAIL under old bug
    if not body_each(100, 140, 88, 125):
        fails.append("R03c each must PASS (v1.04 overfilter case)")
    if body_sum_bug(100, 140, 88, 125):
        fails.append("prove sum would reject — code must NOT use sum")
    # body smaller than one wick
    if body_each(100, 150, 99, 110):  # body=10, up=40, dn=1
        fails.append("R03c body<=upper must FAIL")
    if body_each(100, 105, 80, 104):  # body=4, up=1, dn=20
        fails.append("R03c body<=lower must FAIL")

    # --- Item 10 trail table ---
    cases = [
        (199, None),
        (200, 200),
        (209, 200),
        (210, 210),
        (220, 220),
        (231, 230),
        (240, 240),
        (241, 240),
    ]
    for profit, expect in cases:
        got = trail_lock(profit, 200, 10)
        if got != expect:
            fails.append(f"trail@{profit} got {got} expect {expect}")

    # MUST NOT be BE/0 at start
    if trail_lock(200, 200, 10) == 0:
        fails.append("trail@200 must NOT be 0/BE")

    # --- Guardian restart safety ---
    if not is_profit_side_sl("BUY", 2000.0, 2020.0):
        fails.append("BUY SL above open = profit lock")
    if is_profit_side_sl("BUY", 2000.0, 1990.0):
        fails.append("BUY SL below open = NOT profit lock")
    if not is_profit_side_sl("SELL", 2000.0, 1980.0):
        fails.append("SELL SL below open = profit lock")
    if is_profit_side_sl("SELL", 2000.0, 2010.0):
        fails.append("SELL SL above open = NOT profit lock")

    if fails:
        print("FAIL")
        for f in fails:
            print(" -", f)
        raise SystemExit(1)
    print("PASS: v1.07 strict inside | body>each(no sum) | close break | trail Start+step | profit-side SL")

if __name__ == "__main__":
    main()
