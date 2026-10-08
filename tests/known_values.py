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
ns = {'__file__': os.path.join(BIN, 'bellcurve')}
exec(compile(src, 'bellcurve', 'exec'), ns)
getcontext().prec = 50

# Standard normal inverse CDF, mpmath reference at 80 dps. bellcurve works
# at 50 significant digits; observed agreement is ~1e-47 or better.
INV_CDF = [
    # Near the centre the asymptotic initial guess is undefined (its
    # radicand goes negative above p ~ 0.399); these pin the fallback path.
    ('0.4999', '-0.00025066283008803509892065010540783433921835585584322704438'),
    ('0.499', '-0.0025066308995717640053586570670195877905594301927030646146'),
    ('0.49', '-0.025068908258711035762363431834690420291735682013974659454'),
    ('0.45', '-0.12566134685507403421018438830079930339735064669002183422'),
    ('0.4', '-0.25334710313579979879819618142424393878721070628539536159'),
    ('0.3', '-0.5244005127080407840382893250251225543253780354499781689'),
    ('0.025', '-1.959963984540054235524594430520551527955550077869548398'),
    ('0.01', '-2.326347874040841100885606163346911723351817141532013069'),
    ('1e-10', '-6.361340902404056204695375828265221679203937350915836132'),
    ('1e-50', '-14.93333753478848898116596939987278419187292863643970474'),
    ('1e-100', '-21.27345356096532429511721218866222641864876548625167797'),
    ('1e-300', '-37.04709629936119923722296250786043684434528843801194293'),
]

# Standard normal CDF (exercises the erfc series and continued fraction).
# erfc switches from series to continued fraction at x = 4, i.e. z = -5.657;
# the points either side of it pin the crossover, where accuracy was worst.
CDF = [
    ('-1.5', '0.06680720126885806600449404097988607952289518566122144241'),
    ('-5.6', '0.00000001071759025831090735496089608281707225540129155538949112'),
    # Just below the old erfc crossover (x = 6, z = -8.49), where the old
    # series lost ~10 digits (rel err 6e-40 here); the new crossover at 4
    # holds ~1e-48. The 1e-42 tolerance separates the two.
    ('-8.4', '2.232393197288050341136354800806128874057312402537309678e-17'),
    ('-5.7', '0.000000005990371401063534429833946417850679728931907371716267081'),
    ('-8', '6.220960574271784123515995172588188422488717278900275802e-16'),
    ('-15', '3.670966199312750885786089655334743486416251628040157475e-51'),
    ('-37', '5.725571222524576822683192548273201656432786242832901882e-300'),
]

# p = 0.5 is the median; it used to recurse forever (reflecting 1 - p gives
# 0.5 again), and a tail crossing the mean can draw it.
got = ns['inv_normal_cdf_decimal'](Decimal('0.5'))
if got == 0:
    print("ok: inv_normal_cdf(0.5) is exactly 0")
else:
    failures += 1
    print(f"FAIL: inv_normal_cdf(0.5): got {got}, want 0", file=sys.stderr)

for p_str, want in INV_CDF:
    got = ns['inv_normal_cdf_decimal'](Decimal(p_str))
    check(f"inv_normal_cdf({p_str})", got, want, '1e-40')

for x_str, want in CDF:
    got = ns['dec_normal_cdf'](Decimal(x_str))
    check(f"normal_cdf({x_str})", got, want, '1e-42')

print()
print(f"known values: {'FAILED' if failures else 'passed'}")
sys.exit(1 if failures else 0)
