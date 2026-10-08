# randkit

A Claude Code plugin providing unbiased random sampling tools. All tools use `/dev/urandom` as their entropy source.

## Plugin structure

```
.claude-plugin/plugin.json   # Plugin manifest
bin/                         # Tool scripts (added to PATH when plugin is active)
lib/rand-awk.sh              # Shared awk sampling runtime sourced by the bash tools
lib/randkit.py               # Shared uniform construction + process setup for the Python tools
skills/random/SKILL.md       # Skill that teaches Claude when/how to use these tools
tests/                       # Functional, statistical, and lint test suites
.github/workflows/ci.yml     # CI: lint + tests on Ubuntu and macOS
ruff.toml                    # Pinned lint rule set (so results don't drift with ruff versions)
CLAUDE.md                    # This file
```

## Installation

```
/plugin marketplace add vlasky/randkit
/plugin install randkit
```

Or test locally:
```
claude --plugin-dir /path/to/randkit
```

## Tools

| Tool | Distribution | Output |
|------|-------------|--------|
| `randint` | Uniform integer in [MIN, MAX] | Integer |
| `cointoss` | Fair coin (50/50) | "Heads" or "Tails" |
| `diceroll` | Uniform integer 1–6 (shorthand for `randint 1 6`) | Integer |
| `uniform` | Uniform float in (MIN, MAX) | Float |
| `bellcurve` | Normal (Gaussian) | Float |
| `binomial` | Binomial(n, p) | Integer in [0, n] |
| `poisson` | Poisson(λ) | Non-negative integer |
| `exponential` | Exponential(λ) | Non-negative float |
| `geometric` | Geometric(p) | Positive integer |
| `weighted` | Weighted discrete choice | Selected item |
| `randstr` | Random string from alphabet | String |
| `uuid` | UUID v4 (random), v6 (time-ordered, 100ns), or v7 (time-ordered, ms; `--monotonic` available) | UUID string |
| `ulid` | ULID (time-sortable, Crockford Base32) | 26-char string |
| `shuffle` | Uniform permutation | Input items reordered |
| `choose` | Uniform subset selection (with/without replacement) | N items |

## Language

- `randint`, `cointoss`, `diceroll`, `weighted`, `randstr`, `shuffle`, and `choose` are bash scripts (no dependencies beyond POSIX + awk).
- `bellcurve`, `binomial`, `poisson`, `exponential`, `geometric`, `uniform`, `uuid`, and `ulid` are Python 3 (no external packages). They import `lib/randkit.py` (located relative to the tool's real path) for the uniform construction and `cli_setup()`, which restores the default SIGPIPE disposition so `tool -c 1000000 | head` exits quietly instead of printing a `BrokenPipeError` traceback.
- The bash tools source `lib/rand-awk.sh`, which starts one `od` process streaming `/dev/urandom` as decimal bytes on FD 3 and provides awk functions (`rand_byte`, `rand_range`) that consume it. A tool therefore forks od and awk once per invocation, no matter how many samples it draws.
- Target bash 3.2 (macOS system bash): no `mapfile`, no associative arrays; `shift 2 || shift` for flag pairs.

## Design principles

- No external dependencies — only `/dev/urandom`, standard Python, and POSIX tools.
- Unbiased sampling: rejection sampling or exact transforms where needed.
- One sample per line; sampling tools generate multiple samples via `-c` / `--count` (or `-n` for `bellcurve`). `shuffle` and `choose` are exceptions — see "Multi-sample flag" below.
- Help screens (`--help`) are written to be parseable by LLMs — they describe output format, value ranges, and include examples.

## Multi-sample flag

- `bellcurve` uses `-n` for sample count.
- All other sampling tools use `-c` / `--count`, except:
- `shuffle` outputs all items (one per line) in random order — no count flag.
- `choose` takes N as first argument (not `-c`); outputs N selected items.

## Algorithms and accuracy

- All Python samplers derive U(0,1) as `((u >> 12) + 0.5) * 2^-52` from a 64-bit read: every step is exact in double arithmetic (52 bits + the half fit in the 53-bit significand) and the result is strictly inside (0, 1), so no sampler can see U = 0.0 or 1.0. (A 53-bit variant is NOT safe: (2^53 - 1) + 0.5 rounds up to 2^53, producing exactly 1.0.)
- `randint`: Rejection sampling with adaptive byte width (1/2/4 bytes). Exactly uniform. Ranges up to 2^32 - 1. awk draws offsets; bash adds MIN with exact 64-bit integer arithmetic (18-digit bounds).
- `cointoss`: Single byte mod 2. Exactly 50/50 (256 divides evenly by 2).
- `diceroll`: Calls `randint 1 6`.
- `uniform`: Inverse transform, IEEE 754 double output printed with `repr` (shortest round-trip form; every float tool prints this way so a printed sample parses back to the exact double drawn), open interval. Scaling the exact (0, 1) draw to (MIN, MAX) rounds, and for most ranges the extreme draws round onto an endpoint (1 + (1 - 2^-53) is 2.0), so the tool redraws when that happens. The endpoints carry zero probability mass, so this is not a bias. Any test that feeds constant extreme entropy into a rejection loop must switch to benign entropy after the first draw or it will spin forever.
- `bellcurve` (full distribution): Box-Muller transform, IEEE 754 double output.
- `bellcurve` (tail sampling): Inverse CDF via an asymptotic initial guess + Newton-Raphson on ln(CDF), using Python `Decimal` (50 significant digits). Newton on the raw CDF creeps at ~1/x per step in extreme tails; iterating on ln(CDF) keeps quadratic convergence out to ~37σ (--tail-pct 1e-300), verified against mpmath to ~50 digits. The asymptotic guess `-sqrt(-2 ln p - ln 2π)` is undefined for p > 1/sqrt(2π) ≈ 0.399 (negative radicand, which `Decimal.sqrt` raises on); near the centre the guess is the linearised CDF `(p - 0.5) * sqrt(2π)` instead. Arbitrary-precision erf/erfc built on stdlib Decimal exp/ln/sqrt; erfc uses the Taylor series below x = 4 and a continued fraction (3 × prec terms) above, a crossover chosen by measuring against mpmath (a crossover at 6 lost ~10 digits just below it).
- `binomial`: Direct Bernoulli trials (one 64-bit uniform per trial, read in 4096-draw batches). Exact, O(n) per sample; n is capped at 10^8 (~25 s) so a huge n fails fast instead of appearing to hang.
- `poisson` (λ < 10): Inversion method (product of uniforms). Exact, O(λ) per sample.
- `poisson` (λ >= 10): Hörmann's PTRS (transformed rejection). Exact, O(1) per sample. Maximum λ is 2^53 (beyond that float64 cannot represent consecutive integer counts).
- `exponential`: Inverse transform (-ln(U)/λ). Exact, one 64-bit read per sample.
- `geometric`: Inverse transform (ceil(ln(U)/log1p(-p))). log1p keeps precision for tiny p, where ln(1-p) rounds to 0. Exact, one 64-bit read per sample.
- `weighted`: Cumulative distribution + uniform float. The uniform is (52 bits + 0.5) / 2^52 — exact in awk doubles and strictly inside (0, 1) — so selection probabilities match the given weights to double precision.
- `randstr`: Per-character rejection sampling from alphabet. Exactly uniform over charset. bash counts and slices characters only under a UTF-8 locale; for a non-ASCII alphabet in the C/POSIX locale the tool switches to C.UTF-8 or en_*.UTF-8 when available and errors otherwise.
- `uuid` v4: 122 random bits with version/variant bits set. Exactly as specified in RFC 9562.
- `uuid` v6: 60-bit timestamp (100ns since UUID epoch) + 14-bit random clock_seq + 48-bit random node with the multicast bit set (RFC 9562 section 6.10 MUST).
- `uuid` v7: 48-bit ms timestamp + 74 random bits (rand_a 12 bits, rand_b 62 bits). Lexicographically time-sortable. `--monotonic` treats the 74 bits as a randomly seeded counter incremented by 1 within a millisecond (RFC 9562 section 6.2, Method 2; the RFC permits +1 but notes neighbouring IDs are then guessable from each other). A counter rollover or a clock that steps backwards holds the last timestamp and waits for the clock to pass it, so output never goes out of order. `ulid --monotonic` behaves the same way.
- `ulid`: 48-bit ms timestamp + 80-bit random. Monotonic mode increments random within same ms (and holds the timestamp if the clock steps back).
- `shuffle`: Fisher-Yates with per-swap rejection sampling. Scales byte width (1/2/4 bytes) to index range. Index arithmetic supports up to 2^32 items; the practical limit is awk's in-memory array.
- `choose`: Partial Fisher-Yates to select indices, then sorts to preserve input order. Same rejection sampling as `shuffle`. With `--replace`: independent uniform draws. Stdin without `--replace` uses reservoir sampling (Vitter's Algorithm R) keyed by line number, emitted in one linear pass; an earlier insertion sort of the reservoir was O(N²) and took minutes at N = 20000.

## Piping

Tools that output one item per line can be piped into each other:
- `seq 1 100 | choose 10 | shuffle` — pick 10 from 1–100 in order, then randomize them.

## Testing

- `tests/run.sh` — functional tests (contracts, argument validation, regressions). Also run it under `/bin/bash` to verify bash 3.2 compatibility on macOS. Includes `tests/edge_cases.py` (extreme entropy through every uniform construction) and `tests/known_values.py` (bellcurve tail maths against mpmath-derived reference values pinned to ~45+ digits, so the accuracy claim above stays verified in CI without an mpmath dependency).
- `tests/statistical.sh` — statistical smoke tests with ~6-7σ bounds (false-positive rate below 1e-9 per check).
- `tests/lint.sh` — shellcheck + ruff (+ pyright when installed; CI installs it on Linux); copies the extension-less Python tools and `lib/randkit.py` to a temp dir as `.py` first. Rules are pinned in `ruff.toml` because ruff's default rule set changes between versions.
- CI (`.github/workflows/ci.yml`) runs all three on Ubuntu (GNU coreutils, mawk) and macOS (BSD od/awk, system bash 3.2).

## Future ideas

- **Weighted choice without replacement** — select N items with unequal probabilities, no repeats.
- **Binomial for large n** — BTPE (or normal-approximation rejection) to replace O(n) Bernoulli trials when n is huge.
