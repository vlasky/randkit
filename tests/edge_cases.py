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
    # __file__ lets the tool locate lib/ the way it does when executed.
    ns = {'__file__': os.path.join(BIN, tool)}
    exec(compile(src, tool, 'exec'), ns)
    return ns


def patch_seq(chunks):
    """os.urandom stand-in serving `chunks` in order; the last chunk repeats
    forever (so rejection loops terminate). A one-byte chunk is repeated to
    the requested length; longer chunks must match it exactly."""
    queue = list(chunks)

    def fake(n):
        chunk = queue.pop(0) if len(queue) > 1 else queue[0]
        if len(chunk) == 1:
            return chunk * n
        assert len(chunk) == n, f"chunk of {len(chunk)} bytes, {n} requested"
        return chunk

    os.urandom = fake


def patch(first, then=b'\x00'):
    patch_seq([first, then])


try:
    for tool in ['binomial', 'exponential', 'geometric', 'poisson']:
        ns = load(tool)
        # binomial draws through the batched reader; the others one at a time.
        draw = ns['uniform'] if 'uniform' in ns else (lambda ns=ns: next(ns['uniforms'](1)))
        for pattern, name in ((b'\xff', 'all-ones'), (b'\x00', 'all-zeros')):
            patch(pattern, then=pattern)
            u = draw()
            check(f"{tool} uniform() {name} strictly inside (0,1)", 0.0 < u < 1.0)
    # The batched reader must build each value exactly as uniform() does,
    # across a chunk boundary too.
    import randkit
    for pattern, name in ((b'\xff', 'all-ones'), (b'\x00', 'all-zeros')):
        patch(pattern, then=pattern)
        vals = list(randkit.uniforms(4097))
        check(f"uniforms(4097) {name} all strictly inside (0,1)",
              len(vals) == 4097 and all(0.0 < v < 1.0 for v in vals))
        check(f"uniforms(4097) {name} matches uniform()",
              all(v == randkit.uniform() for v in vals[:2]))

    ns = load('uniform')
    # Scaling and translating the exact (0,1) uniform rounds, and for most
    # ranges the extreme draws round onto an endpoint (1 + (1 - 2^-53) is
    # 2.0); uniform_sample must redraw rather than emit it. The extreme
    # chunk is served once and a mid-range one after it, so a correct
    # rejection loop terminates while a missing one returns the endpoint.
    for pattern, name in ((b'\xff', 'all-ones'), (b'\x00', 'all-zeros')):
        for lo, hi in ((0.0, 1.0), (1.0, 2.0), (5.0, 6.0), (0.1, 0.2),
                       (100.0, 115.0), (-1.0, 1.0), (1e300, 1e301)):
            patch(pattern, then=b'\x80')
            t = ns['uniform_sample'](lo, hi)
            check(f"uniform_sample({lo:g},{hi:g}) {name} strictly inside", lo < t < hi)

    # RFC 9562 6.10: a random v6 node MUST have its multicast bit set. With
    # all-zero entropy the bit is set only if the code sets it.
    ns = load('uuid')
    patch(b'\x00', then=b'\x00')
    u6 = ns['uuid6']()
    check("uuid6 sets the node multicast bit under all-zero entropy",
          int(u6[24:26], 16) & 1 == 1 and u6[14] == '6')

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

    # The largest u accepted by the u < 1 check can still land the final
    # lo + width * u exactly on hi once the addition rounds to context
    # precision (1 + 0.99...97 -> 2 at prec 50). The candidate itself must
    # be range-checked, not just u.
    nb = (50 * 4) // 8 + 10          # n_bytes used by uniform_in_range
    cap = 2 ** (nb * 8)
    raw_edge = (10**50 - 1) * cap // 10**50
    patch_seq([raw_edge.to_bytes(nb, 'big'), b'\x00'])
    v = ns['uniform_in_range'](Decimal(1), Decimal(2))
    check("bellcurve uniform_in_range rejects candidates that round onto hi",
          Decimal(1) < v < Decimal(2))
finally:
    os.urandom = REAL_URANDOM

print()
print(f"edge cases: {'FAILED' if failures else 'passed'}")
sys.exit(1 if failures else 0)
