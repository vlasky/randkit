#!/usr/bin/env python3
"""Force extreme entropy bytes (all ones, all zeros) through each Python
sampler's uniform construction and check the open-interval contract holds.
These are the draws where a rounding mistake produces exactly 0.0 or 1.0."""

import os
import sys

BIN = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'bin')
REAL_URANDOM = os.urandom
failures = 0


def check(desc, cond):
    global failures
    if cond:
        print(f"ok: {desc}")
    else:
        failures += 1
        print(f"FAIL: {desc}", file=sys.stderr)


def load(tool):
    with open(os.path.join(BIN, tool)) as f:
        src = f.read()
    src = src.replace('if __name__ == "__main__":\n    main()', '')
    ns = {}
    exec(compile(src, tool, 'exec'), ns)
    return ns


def patch(first, then=b'\x00'):
    """os.urandom stand-in: first call returns `first` bytes, later calls
    return `then` bytes (so rejection loops terminate)."""
    state = {'calls': 0}

    def fake(n):
        state['calls'] += 1
        return (first if state['calls'] == 1 else then) * n

    os.urandom = fake


try:
    for tool in ['binomial', 'exponential', 'geometric', 'poisson']:
        ns = load(tool)
        for pattern, name in ((b'\xff', 'all-ones'), (b'\x00', 'all-zeros')):
            patch(pattern, then=pattern)
            u = ns['uniform']()
            check(f"{tool} uniform() {name} strictly inside (0,1)", 0.0 < u < 1.0)

    ns = load('uniform')
    for pattern, name in ((b'\xff', 'all-ones'), (b'\x00', 'all-zeros')):
        patch(pattern, then=pattern)
        t = ns['uniform_sample'](0.0, 1.0)
        check(f"uniform_sample(0,1) {name} strictly inside (0,1)", 0.0 < t < 1.0)

    ns = load('bellcurve')
    Decimal = ns['Decimal']
    for pattern, name in ((b'\xff', 'all-ones'), (b'\x00', 'all-zeros')):
        patch(pattern, then=pattern)
        u = ns['uniform_float']()
        check(f"bellcurve uniform_float() {name} strictly inside (0,1)", 0.0 < u < 1.0)

    # The Decimal paths reject top-edge draws that round to 1 at context
    # precision, so all-ones must be followed by other bytes to terminate.
    patch(b'\xff', then=b'\x00')
    u = ns['uniform']()
    check("bellcurve Decimal uniform() rejects the round-to-1 draw",
          Decimal(0) < u < Decimal(1))
    patch(b'\x00', then=b'\x00')
    u = ns['uniform']()
    check("bellcurve Decimal uniform() all-zeros strictly above 0",
          Decimal(0) < u < Decimal(1))
    patch(b'\xff', then=b'\x00')
    v = ns['uniform_in_range'](Decimal(0), Decimal(1))
    check("bellcurve uniform_in_range rejects the round-to-1 draw",
          Decimal(0) < v < Decimal(1))
finally:
    os.urandom = REAL_URANDOM

print()
print(f"edge cases: {'FAILED' if failures else 'passed'}")
sys.exit(1 if failures else 0)
