#!/usr/bin/env python3
"""IDC_3 v1.03 logic checks — close break + body>sum(wicks)."""

def is_inside(h1, l1, h2, l2):
    return h2 < h1 and l2 > l1

def close_break_buy(c3, h2):
    return c3 > h2

def close_break_sell(c3, l2):
    return c3 < l2

def wick_only_buy(h3, c3, h2):
    return h3 > h2 and c3 <= h2

def wick_only_sell(l3, c3, l2):
    return l3 < l2 and c3 >= l2

def body_gt_wicks(o, h, l, c):
    body = abs(c - o)
    upper = max(0.0, h - max(o, c))
    lower = max(0.0, min(o, c) - l)
    if body <= upper:
        return False
    if body <= lower:
        return False
    if body <= (upper + lower):
        return False
    return True

def main():
    fails = []

    # wick-only must NOT be close break
    if not wick_only_buy(110, 105, 108):
        fails.append("wick-only buy detect")
    if close_break_buy(105, 108):
        fails.append("wick-only must not close-break buy")
    if not wick_only_sell(90, 95, 92):
        fails.append("wick-only sell detect")
    if close_break_sell(95, 92):
        fails.append("wick-only must not close-break sell")

    # real close breaks
    if not close_break_buy(109, 108):
        fails.append("close buy")
    if not close_break_sell(91, 92):
        fails.append("close sell")

    # old weak filter would pass body=30, up=20, dn=15 — NEW must FAIL (30 <= 35)
    if body_gt_wicks(100, 150, 85, 130):  # body30 up20 dn15
        fails.append("weak body must fail vs sum wicks")

    # body=40, up=10, dn=10 → 40>20 pass
    if not body_gt_wicks(100, 150, 100, 140):
        fails.append("strong body must pass")

    # body > each but not sum: body=12, up=10, dn=5 → fail
    if body_gt_wicks(100, 122, 95, 112):
        fails.append("body>each but not sum must fail")

    # doji fail
    if body_gt_wicks(100, 110, 90, 100):
        fails.append("doji fail")

    if fails:
        print("FAIL:")
        for f in fails:
            print(" -", f)
        raise SystemExit(1)
    print("PASS: close-break only + body>sum(wicks) v1.03")

if __name__ == "__main__":
    main()
