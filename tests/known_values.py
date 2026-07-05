#!/usr/bin/env python3
"""Known-answer regression tests for bellcurve's arbitrary-precision tail
maths. Reference values were computed with mpmath at 80 decimal digits (via
a cancellation-free root solve of ln(CDF)); pinning them here keeps the
"~50 significant digits out to ~37 sigma" claim verifiable in CI without
adding mpmath as a dependency."""

import os
import sys
from decimal import Decimal, getcontext

BIN = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'bin')
failures = 0


def check(desc, got, want_str, rel_tol):
    global failures
    want = Decimal(want_str)
    rel = abs((got - want) / want)
    if rel < Decimal(rel_tol):
        print(f"ok: {desc} (rel err {rel:.1e})")
    else:
        failures += 1
        print(f"FAIL: {desc}: got {got}, want {want_str} (rel err {rel:.1e})",
              file=sys.stderr)


with open(os.path.join(BIN, 'bellcurve')) as f:
    src = f.read()
src = src.replace('if __name__ == "__main__":\n    main()', '')
ns = {}
exec(compile(src, 'bellcurve', 'exec'), ns)
getcontext().prec = 50

# Standard normal inverse CDF, mpmath reference at 80 dps. bellcurve works
# at 50 significant digits; observed agreement is ~1e-47 or better.
INV_CDF = [
    ('0.3', '-0.5244005127080407840382893250251225543253780354499781689'),
    ('0.025', '-1.959963984540054235524594430520551527955550077869548398'),
    ('0.01', '-2.326347874040841100885606163346911723351817141532013069'),
    ('1e-10', '-6.361340902404056204695375828265221679203937350915836132'),
    ('1e-50', '-14.93333753478848898116596939987278419187292863643970474'),
    ('1e-100', '-21.27345356096532429511721218866222641864876548625167797'),
    ('1e-300', '-37.04709629936119923722296250786043684434528843801194293'),
]

# Standard normal CDF (exercises the erfc series and continued fraction).
# The continued fraction is weakest near its x=6/sqrt(2) switchover, where
# agreement is ~1e-44; elsewhere ~1e-47 or better.
CDF = [
    ('-1.5', '0.06680720126885806600449404097988607952289518566122144241'),
    ('-8', '6.220960574271784123515995172588188422488717278900275802e-16'),
    ('-15', '3.670966199312750885786089655334743486416251628040157475e-51'),
    ('-37', '5.725571222524576822683192548273201656432786242832901882e-300'),
]

for p_str, want in INV_CDF:
    got = ns['inv_normal_cdf_decimal'](Decimal(p_str))
    check(f"inv_normal_cdf({p_str})", got, want, '1e-40')

for x_str, want in CDF:
    got = ns['dec_normal_cdf'](Decimal(x_str))
    check(f"normal_cdf({x_str})", got, want, '1e-42')

print()
print(f"known values: {'FAILED' if failures else 'passed'}")
sys.exit(1 if failures else 0)
