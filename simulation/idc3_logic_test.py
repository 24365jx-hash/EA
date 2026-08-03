#!/usr/bin/env python3
"""IDC_3 v1.06 locks: strict inside, body>each (NO sum), trail Start+step."""

def strict_inside(h1, l1, h2, l2):
    return h2 < h1 and l2 > l1

def body_each(o, h, l, c):
    b = abs(c - o)
    u = max(0.0, h - max(o, c))
    d = max(0.0, min(o, c) - l)
    return b > u and b > d

def body_sum_bug(o, h, l, c):
    """v1.04 wrongful extra filter."""
    b = abs(c - o)
    u = max(0.0, h - max(o, c))
    d = max(0.0, min(o, c) - l)
    return body_each(o, h, l, c) and b > (u + d)

def trail(profit, start, step):
    if profit < start:
        return None
    return start + int((profit - start) // step) * step

def main():
    fails = []
    # touch NOT inside
    if strict_inside(100, 90, 100, 92):
        fails.append("equal high must FAIL strict")
    if strict_inside(100, 90, 98, 90):
        fails.append("equal low must FAIL strict")
    if not strict_inside(100, 90, 98, 92):
        fails.append("clear cover must PASS")

    # v1.04 bug case: each PASS, sum FAIL
    if not body_each(100, 140, 88, 125):
        fails.append("each should pass")
    if body_sum_bug(100, 140, 88, 125):
        fails.append("sum should fail — proves v104 overfilter")
    # current rule uses each only → enter
    if not body_each(100, 140, 88, 125):
        fails.append("v106 must allow each-only")

    if trail(200, 200, 10) != 200:
        fails.append("trail")
    if fails:
        print("FAIL", fails)
        raise SystemExit(1)
    print("PASS: v1.06 strict inside + body>each (sum was the v1.04 bug)")

if __name__ == "__main__":
    main()
