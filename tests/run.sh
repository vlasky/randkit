#!/bin/bash
# Functional tests for randkit: output contracts, argument validation,
# and regressions. Pure bash — no test framework required.
set -u

BIN="$(cd "$(dirname "$0")/../bin" && pwd)"
PATH="$BIN:$PATH"
export PATH

passes=0
failures=0
out=""

pass() { passes=$(( passes + 1 )); }
fail() { failures=$(( failures + 1 )); echo "FAIL: $1" >&2; }

# Expect the command to exit 0; capture stdout in $out.
run_ok() {
    local desc=$1; shift
    if out=$("$@" 2>&1); then pass; else fail "$desc: exit $? — $out"; fi
}

# Expect the command to exit nonzero.
run_fail() {
    local desc=$1; shift
    if out=$("$@" 2>&1); then fail "$desc: expected failure, got output: $out"; else pass; fi
}

# Every line of $out must match the extended regex.
lines_match() {
    local desc=$1 re=$2
    if [[ -n "$out" ]] && ! printf '%s\n' "$out" | grep -Evq "$re"; then
        pass
    else
        fail "$desc: output not all matching /$re/: $out"
    fi
}

# $out must have exactly N lines.
line_count() {
    local desc=$1 want=$2 got
    got=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
    if [[ "$got" == "$want" ]]; then pass; else fail "$desc: expected $want lines, got $got"; fi
}

# $out must equal the given string exactly.
out_is() {
    local desc=$1 want=$2
    if [[ "$out" == "$want" ]]; then pass; else fail "$desc: expected '$want', got '$out'"; fi
}

# Every line of $out must be numeric and within [lo, hi].
in_range() {
    local desc=$1 lo=$2 hi=$3
    if printf '%s\n' "$out" | awk -v lo="$lo" -v hi="$hi" \
        '$0 == "" || $1 + 0 < lo || $1 + 0 > hi { bad = 1 } END { exit bad }'; then
        pass
    else
        fail "$desc: value outside [$lo, $hi]: $out"
    fi
}

# --- randint ---------------------------------------------------------------
run_ok  "randint degenerate range" randint 5 5
out_is  "randint degenerate range value" "5"
run_ok  "randint basic" randint 1 6
in_range "randint basic range" 1 6
run_ok  "randint count" randint -c 10 1 6
line_count "randint count lines" 10
in_range "randint count range" 1 6
run_ok  "randint negative range" randint -10 -5
in_range "randint negative range values" -10 -5
run_ok  "randint full 32-bit range" randint 0 4294967295
in_range "randint full 32-bit value" 0 4294967295
run_ok  "randint 18-digit bounds" randint 999999999999999990 999999999999999999
in_range "randint 18-digit value" 999999999999999990 999999999999999999
run_fail "randint min > max" randint 6 1
run_fail "randint missing max" randint 1
run_fail "randint leading zero" randint 08 10
run_fail "randint non-integer" randint 1 abc
run_fail "randint range too large" randint 0 4294967296
run_fail "randint zero count" randint -c 0 1 6
run_fail "randint negative count" randint -c -3 1 6

# --- cointoss ---------------------------------------------------------------
run_ok  "cointoss basic" cointoss
lines_match "cointoss output" '^(Heads|Tails)$'
run_ok  "cointoss count" cointoss -c 5
line_count "cointoss count lines" 5
lines_match "cointoss count output" '^(Heads|Tails)$'
run_fail "cointoss extra arg" cointoss 3
run_fail "cointoss bad count" cointoss -c x

# --- diceroll ---------------------------------------------------------------
run_ok  "diceroll basic" diceroll
in_range "diceroll range" 1 6
run_ok  "diceroll count" diceroll -c 4
line_count "diceroll count lines" 4
in_range "diceroll count range" 1 6
run_fail "diceroll extra arg" diceroll 20

# --- uniform ----------------------------------------------------------------
run_ok  "uniform default" uniform
in_range "uniform default range" 0 1
run_ok  "uniform custom range" uniform --min 5 --max 6 -c 3
line_count "uniform custom lines" 3
in_range "uniform custom values" 5 6
run_fail "uniform min >= max" uniform --min 2 --max 2
run_fail "uniform bad count" uniform -c 0

# --- randstr ----------------------------------------------------------------
run_ok  "randstr default" randstr
lines_match "randstr default format" '^[A-Za-z0-9]{16}$'
run_ok  "randstr hex" randstr -a hex 32
lines_match "randstr hex format" '^[0-9a-f]{32}$'
run_ok  "randstr custom alphabet" randstr -a ab 20
lines_match "randstr custom format" '^[ab]{20}$'
run_ok  "randstr dash alphabet" randstr -a "-n" 4
lines_match "randstr dash format" '^[n-]{4}$'
run_ok  "randstr count" randstr -c 5 8
line_count "randstr count lines" 5
lines_match "randstr count format" '^[A-Za-z0-9]{8}$'
run_fail "randstr zero length" randstr 0
run_fail "randstr empty alphabet" randstr -a "" 5

# --- weighted ---------------------------------------------------------------
run_ok  "weighted single item" weighted only:1
out_is  "weighted single item value" "only"
run_ok  "weighted count" weighted -c 5 a:1
line_count "weighted count lines" 5
lines_match "weighted count output" '^a$'
run_ok  "weighted colon in item" weighted "a:b:2"
out_is  "weighted colon in item value" "a:b"
run_ok  "weighted dash item" weighted "-n:1"
out_is  "weighted dash item value" "-n"
run_fail "weighted zero weight" weighted a:1 b:0
run_fail "weighted negative weight" weighted a:-1
run_fail "weighted missing weight" weighted red
run_fail "weighted inf weight" weighted a:inf
run_fail "weighted no args" weighted

# --- geometric --------------------------------------------------------------
run_ok  "geometric p=1" geometric --p 1
out_is  "geometric p=1 value" "1"
run_ok  "geometric basic" geometric --p 0.5 -c 20
line_count "geometric lines" 20
lines_match "geometric positive integers" '^[1-9][0-9]*$'
run_ok  "geometric tiny p" geometric --p 1e-17
lines_match "geometric tiny p positive" '^[1-9][0-9]*$'
run_fail "geometric p=0" geometric --p 0
run_fail "geometric p>1" geometric --p 1.5

# --- binomial ---------------------------------------------------------------
run_ok  "binomial n=0" binomial --n 0
out_is  "binomial n=0 value" "0"
run_ok  "binomial p=0" binomial --n 10 --p 0
out_is  "binomial p=0 value" "0"
run_ok  "binomial p=1" binomial --n 10 --p 1 -c 3
lines_match "binomial p=1 values" '^10$'
run_ok  "binomial range" binomial --n 10 --p 0.5 -c 20
in_range "binomial values" 0 10
run_fail "binomial negative n" binomial --n -1
run_fail "binomial p>1" binomial --p 1.5

# --- poisson ----------------------------------------------------------------
run_ok  "poisson basic" poisson --lambda 3 -c 10
line_count "poisson lines" 10
lines_match "poisson non-negative integers" '^[0-9]+$'
run_ok  "poisson large lambda" poisson --lambda 1000000
lines_match "poisson large lambda integer" '^[0-9]+$'
run_fail "poisson lambda required" poisson
run_fail "poisson lambda=0" poisson --lambda 0
run_fail "poisson lambda too large" poisson --lambda 1e16

# --- exponential ------------------------------------------------------------
run_ok  "exponential basic" exponential --lambda 2 -c 10
line_count "exponential lines" 10
lines_match "exponential non-negative" '^[0-9]'
run_fail "exponential lambda=0" exponential --lambda 0

# --- bellcurve ----------------------------------------------------------------
run_ok  "bellcurve basic" bellcurve -n 5
line_count "bellcurve lines" 5
run_ok  "bellcurve mean/std" bellcurve --mean 100 --std 1 -n 10
in_range "bellcurve mean/std plausible range" 90 110
run_ok  "bellcurve right tail" bellcurve --tail-sigma 2 --right -n 5
in_range "bellcurve right tail cutoff" 2 9
run_ok  "bellcurve tail above" bellcurve --tail-above 120 --mean 100 --std 15 -n 5
in_range "bellcurve tail above cutoff" 120 200
# The outer 1e-300 percent of N(0,1) starts at |z| = 37.1897...; samples
# from the right half of that tail must sit just beyond the cutoff.
run_ok  "bellcurve extreme tail" bellcurve --tail-pct 1e-300 --right
in_range "bellcurve extreme tail quantile" 37.1897 38
run_fail "bellcurve tail-pct out of range" bellcurve --tail-pct 100
run_fail "bellcurve zero std" bellcurve --std 0
run_fail "bellcurve conflicting tails" bellcurve --tail-sigma 2 --tail-pct 5

# --- uuid -------------------------------------------------------------------
run_ok  "uuid v4" uuid
lines_match "uuid v4 format" '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
run_ok  "uuid v6" uuid --version 6
lines_match "uuid v6 format" '^[0-9a-f]{8}-[0-9a-f]{4}-6[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
run_ok  "uuid v7" uuid --version 7
lines_match "uuid v7 format" '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
run_ok  "uuid count" uuid -c 5
line_count "uuid count lines" 5
run_fail "uuid bad version" uuid --version 5

# --- ulid -------------------------------------------------------------------
run_ok  "ulid basic" ulid
lines_match "ulid format" '^[0-9A-HJKMNP-TV-Z]{26}$'
run_ok  "ulid count" ulid -c 5
line_count "ulid count lines" 5
run_ok  "ulid monotonic" ulid --monotonic -c 20
line_count "ulid monotonic lines" 20
if [[ "$(printf '%s\n' "$out" | sort)" == "$out" && \
      "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" == "20" ]]; then
    pass
else
    fail "ulid monotonic: output not strictly increasing: $out"
fi

# --- shuffle ----------------------------------------------------------------
run_ok  "shuffle args" shuffle c b a
if [[ "$(printf '%s\n' "$out" | sort | tr '\n' ' ')" == "a b c " ]]; then pass; else fail "shuffle permutation: $out"; fi
run_ok  "shuffle stdin" bash -c 'seq 1 100 | shuffle'
if [[ "$(printf '%s\n' "$out" | sort -n | tr '\n' ' ')" == "$(seq 1 100 | tr '\n' ' ')" ]]; then
    pass
else
    fail "shuffle stdin permutation broken"
fi
run_ok  "shuffle single item" shuffle solo
out_is  "shuffle single item value" "solo"
run_fail "shuffle empty stdin" bash -c ': | shuffle'

# --- choose -----------------------------------------------------------------
run_ok  "choose stdin" bash -c 'seq 1 100 | choose 10'
line_count "choose stdin lines" 10
in_range "choose stdin range" 1 100
if [[ "$(printf '%s\n' "$out" | sort -n | uniq | wc -l | tr -d ' ')" == "10" && \
      "$(printf '%s\n' "$out" | sort -n)" == "$out" ]]; then
    pass
else
    fail "choose stdin: not unique or not in input order: $out"
fi
run_ok  "choose all items preserves order" choose 3 a b c
out_is  "choose all items output" "$(printf 'a\nb\nc')"
run_ok  "choose args subset" choose 2 a b c d e
line_count "choose args subset lines" 2
run_ok  "choose dash item" choose 1 -n -n -n
out_is  "choose dash item value" "-n"
run_ok  "choose replace repeats" choose --replace 10 a
line_count "choose replace lines" 10
lines_match "choose replace output" '^a$'
run_ok  "choose large stdin reservoir" bash -c 'seq 1 100000 | choose 3'
line_count "choose large stdin lines" 3
in_range "choose large stdin range" 1 100000
run_fail "choose N > total" choose 5 a b
run_fail "choose N > total stdin" bash -c 'seq 1 3 | choose 5'
run_fail "choose zero N" choose 0 a b
run_fail "choose non-integer N" choose abc a b
run_fail "choose no args" choose

# --- piping -----------------------------------------------------------------
run_ok  "pipe choose into shuffle" bash -c 'seq 1 100 | choose 10 | shuffle'
line_count "pipe result lines" 10
in_range "pipe result range" 1 100

# --- summary ----------------------------------------------------------------
echo
echo "passed: $passes, failed: $failures"
(( failures == 0 ))
