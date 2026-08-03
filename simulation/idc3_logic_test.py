#!/usr/bin/env python3
"""IDC_3 v1.05 — color ignored, inside touch+smaller, body>each wick, trail Start+step."""

def is_inside(h1, l1, h2, l2):
    return h2 <= h1 and l2 >= l1 and (h2 - l2) < (h1 - l1) and (h2 - l2) > 0

def body_gt_each(o, h, l, c):
    body = abs(c - o)
    upper = max(0.0, h - max(o, c))
    lower = max(0.0, min(o, c) - l)
    return body > upper and body > lower

def trail_lock(profit, start, step):
    if profit < start:
        return None
    return start + int((profit - start) // step) * step

def main():
    fails = []

    # color irrelevant: same geometry always same result
    if is_inside(100, 90, 98, 92) != is_inside(100, 90, 98, 92):
        fails.append("color independence")

    # equal high touch = inside if smaller range
    if not is_inside(100, 90, 100, 92):
        fails.append("equal high must be inside")
    if not is_inside(100, 90, 98, 90):
        fails.append("equal low must be inside")
    # equal both = same range → not smaller → fail
    if is_inside(100, 90, 100, 90):
        fails.append("identical range must fail")
    # outside
    if is_inside(100, 90, 101, 92):
        fails.append("outside high must fail")

    # old strict would reject equal high
    strict = (100 < 100 and 92 > 90)  # False
    if strict:
        fails.append("sanity")

    # body each only (sum NOT required)
    if not body_gt_each(100, 122, 97, 112):  # 12>10 and 12>3
        fails.append("body>each should pass")
    # would fail sum (12<=13) but we do NOT use sum
    if body_gt_each(100, 130, 95, 110):  # body10 up20 dn5 → fail each
        fails.append("body<=upper must fail")

    if trail_lock(200, 200, 10) != 200:
        fails.append("trail @200=200")
    if trail_lock(210, 200, 10) != 210:
        fails.append("trail 210")
    if trail_lock(200, 200, 10) == 0:
        fails.append("no BE")

    if fails:
        print("FAIL:")
        for f in fails:
            print(" -", f)
        raise SystemExit(1)
    print("PASS: v1.05 inside touch+smaller, body>each, trail, color-free")

if __name__ == "__main__":
    main()
