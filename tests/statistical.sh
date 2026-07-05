#!/bin/bash
# Statistical smoke tests for randkit. Bounds are deliberately generous
# (roughly 6-7 standard deviations), so a failure indicates a genuine bias
# or broken sampler, not bad luck: the false-positive rate per check is
# below 1 in 10^9.
set -u

BIN="$(cd "$(dirname "$0")/../bin" && pwd)"
PATH="$BIN:$PATH"
export PATH

passes=0
failures=0

pass() { passes=$(( passes + 1 )); echo "ok: $1"; }
fail() { failures=$(( failures + 1 )); echo "FAIL: $1" >&2; }

# assert_between <desc> <value> <lo> <hi>
assert_between() {
    local desc=$1 val=$2 lo=$3 hi=$4
    if awk -v v="$val" -v lo="$lo" -v hi="$hi" 'BEGIN { exit !(v >= lo && v <= hi) }'; then
        pass "$desc ($val in [$lo, $hi])"
    else
        fail "$desc: $val outside [$lo, $hi]"
    fi
}

mean_of() { awk '{ s += $1 } END { printf "%.6f", s / NR }'; }

# cointoss: 2000 flips, expect ~1000 heads (sigma ~22.4; bounds are 6.7 sigma)
heads=$(cointoss -c 2000 | grep -c Heads)
assert_between "cointoss balance" "$heads" 850 1150

# randint 1..6: 3000 draws, each face expected 500 (sigma ~20.4; 7.3 sigma)
counts_ok=1
face_counts=$(randint -c 3000 1 6 | sort | uniq -c)
while read -r count face; do
    if (( count < 350 || count > 650 )); then
        counts_ok=0
        fail "randint face $face count $count outside [350, 650]"
    fi
done <<< "$face_counts"
(( counts_ok )) && pass "randint 1-6 uniformity"

# weighted a:3 b:1 — 1000 draws, expect ~750 a (sigma ~13.7; 7.3 sigma)
a_count=$(weighted -c 1000 a:3 b:1 | grep -cx a)
assert_between "weighted 3:1 ratio" "$a_count" 650 850

# uniform(0,1): mean of 4000 expected 0.5 (sigma of mean ~0.0046; 11 sigma)
assert_between "uniform mean" "$(uniform -c 4000 | mean_of)" 0.45 0.55

# bellcurve N(0,1): mean of 4000 expected 0 (sigma of mean ~0.0158; 6.3 sigma)
assert_between "bellcurve mean" "$(bellcurve -n 4000 | mean_of)" -0.1 0.1

# exponential(1): mean of 4000 expected 1 (sigma of mean ~0.0158; 6.3 sigma)
assert_between "exponential mean" "$(exponential --lambda 1 -c 4000 | mean_of)" 0.9 1.1

# geometric(0.5): mean of 4000 expected 2 (sigma of mean ~0.0224; 6.7 sigma)
assert_between "geometric mean" "$(geometric --p 0.5 -c 4000 | mean_of)" 1.85 2.15

# poisson(100): mean of 1000 expected 100 (sigma of mean ~0.316; 6.3 sigma)
assert_between "poisson mean" "$(poisson --lambda 100 -c 1000 | mean_of)" 98 102

# binomial(100, 0.3): mean of 1000 expected 30 (sigma of mean ~0.145; 6.9 sigma)
assert_between "binomial mean" "$(binomial --n 100 --p 0.3 -c 1000 | mean_of)" 29 31

# bellcurve tail: every sample beyond 3 sigma must actually be beyond 3 sigma
tail_ok=1
while read -r v; do
    if awk -v v="$v" 'BEGIN { exit !(v < 3) }'; then
        tail_ok=0
        fail "bellcurve --tail-sigma 3 --right produced $v (< 3)"
    fi
done < <(bellcurve --tail-sigma 3 --right -n 20)
(( tail_ok )) && pass "bellcurve right tail respects cutoff"

echo
echo "passed: $passes, failed: $failures"
(( failures == 0 ))
