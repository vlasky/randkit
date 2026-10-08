# Changelog

## 1.2.0 (2026-10-08)

### Added

- `uuid --version 7 --monotonic`: strictly increasing UUID v7s within the same millisecond, using the RFC 9562 section 6.2 "monotonic random" method (the 74 random bits are a randomly seeded counter incremented by 1; a rollover or a backwards clock step holds the timestamp and waits). Mirrors `ulid --monotonic`.

### Fixed

- `bellcurve` crashed with a `decimal.InvalidOperation` traceback whenever a tail region reached past ~40% of the distribution (`--tail-above 90 --mean 100 --std 15`, `--tail-pct 90`, `--tail-sigma 0.1`): the asymptotic initial guess for the inverse CDF takes a square root whose radicand is negative for p above 1/sqrt(2π). Near the centre the guess now comes from the linearised CDF; known-value tests pin p = 0.4 to 0.4999. A draw of exactly p = 0.5 (possible when a tail crosses the mean) recursed forever and now returns the mean.
- `uniform` could emit an endpoint for ranges other than (0, 1): scaling the exact (0, 1) draw rounds, so `--min 1 --max 2` could print exactly `2` (probability ~2^-52 per sample, but the help text promises never). It now redraws in that case, and the edge-case test covers scaled ranges. A range whose width overflows a double (`--min -1e308 --max 1e308`) printed `inf` and is now rejected, as is a range with no double strictly inside it (`--min 1 --max 1.0000000000000002`). Output is now printed at full double precision (shortest round-trip form) rather than 15 significant digits, so a value just inside the interval cannot print as an endpoint; `exponential` and `bellcurve` print the same way for consistency.
- The Python tools printed a `BrokenPipeError` traceback when a pipe cut their output short (`uuid -c 1000000 | head`); they now restore the default SIGPIPE disposition and exit quietly like other filters.
- `choose N` from stdin was O(N²) (an insertion sort of the reservoir: 57 s for N = 20000, 4 minutes for 40000). The reservoir is now keyed by line number and emitted in one linear pass (0.2 s).
- `randstr` produced invalid UTF-8 for multibyte custom alphabets under the C/POSIX locale (cron, CI, many subprocess contexts), where bash slices strings by byte; it now switches to an available UTF-8 locale or refuses with a clear error.
- `uuid --version 6` left the multicast bit of its random node clear, which RFC 9562 section 6.10 requires to be set.
- `ulid --monotonic` could emit an out-of-order value if the system clock stepped backwards between calls; it now holds the last timestamp.
- `bellcurve` erfc accuracy dipped to ~40 significant digits just below the series/continued-fraction crossover (erfc arguments 5.5 to 5.9, about 8σ); the crossover moved from 6 to 4 (about 5.7σ) with more continued-fraction terms and now holds more than 55 digits everywhere, measured against mpmath.

### Changed

- The Python tools share one runtime library (`lib/randkit.py`) for the uniform construction and process setup, mirroring `lib/rand-awk.sh` on the bash side; the six copies of the uniform construction are gone.
- `binomial` reads its entropy in batches (about 4x faster) and refuses n above 10^8, where a single O(n) sample would take minutes.
- Lint rules are pinned in `ruff.toml` so results do not drift with ruff's defaults; pyright now runs in CI on Linux; `actions/checkout` is pinned to a commit SHA.

## 1.1.0 (2026-07-06)

### Fixed

- `geometric` crashed with `ZeroDivisionError` for p below ~1e-16 and silently lost precision for all small p; the inverse transform now uses `log1p(-p)`.
- The shared uniform construction in the Python samplers could round to exactly 1.0 (probability ~2^-54), letting `geometric` return 0, `binomial --p 1` return less than n, and `exponential` print `-0`. All samplers now use `((u >> 12) + 0.5) * 2^-52`, which is exact in double arithmetic and strictly inside (0, 1). The `bellcurve` `Decimal` uniforms had the same edge (the top draw rounded to 1, and `lo + width * u` could round onto the interval bound); both now reject and redraw.
- `bellcurve` tail sampling was inaccurate in extreme tails (at `--tail-pct 1e-300` samples were misplaced by ~0.6σ): Newton refinement of the inverse CDF now iterates on ln(CDF), restoring full 50-digit accuracy out to ~37σ (verified against mpmath).
- The shared entropy stream deadlocked (and leaked a spinning `od`) in environments that ignore SIGPIPE, such as CI runners: `od` outlived its consumer instead of dying, and a bash process-substitution parent waited on it forever, hanging any caller that captured the tool's output. The stream now announces its producer's pid and is explicitly reaped on exit; `od`'s broken-pipe stderr is silenced. (Surfaced as a 6-hour CI hang on macOS.)
- `choose`, `weighted`, and `randstr` printed nothing for items or output that looked like `echo` flags (such as `-n`); they now print via `printf`.
- `weighted` reported a confusing error for arguments missing the `:WEIGHT` suffix.

### Changed

- The bash tools now stream entropy from a single `od` process through a shared awk library (`lib/rand-awk.sh`) instead of forking `od` per sample (per character, in `randstr`). Batch generation is ~50-100x faster.
- `bellcurve` uses the stdlib `Decimal` ln/exp/sqrt (correctly rounded) in place of hand-rolled AGM/Taylor implementations.
- `uuid` v7 and `ulid` take timestamps from `time.time_ns()`, matching `uuid` v6.
- The skill's `allowed-tools` patterns use the word-boundary form `Bash(tool:*)`.

### Added

- MIT LICENSE (the README had claimed MIT with no licence text).
- Functional, statistical, and lint test suites with CI on Ubuntu and macOS (including a system bash 3.2 run). CI is hardened with per-step timeouts (a hang fails fast instead of burning the 6-hour default), a least-privilege `contents: read` token, and a `concurrency` group that cancels superseded runs and dedupes the push + pull_request double trigger.
- Edge-case and known-value test files: `tests/edge_cases.py` drives extreme entropy through every uniform construction, and `tests/known_values.py` pins the `bellcurve` tail maths to mpmath-derived reference values so the accuracy claim stays enforced without an mpmath dependency.
- `--` end-of-options support in `shuffle`, `choose`, and `weighted`, so items may begin with a dash.
- `shuffle` and `choose` now print usage instead of hanging when stdin is an interactive terminal and no items were given.

## 1.0.0 (2026-05-26)

Initial release.

### Tools

- `randint` — uniform integer in [MIN, MAX] with rejection sampling
- `cointoss` — fair coin flip (50/50)
- `diceroll` — fair 6-sided die (shorthand for `randint 1 6`)
- `uniform` — uniform float in (MIN, MAX)
- `bellcurve` — normal (Gaussian) distribution with optional tail sampling
- `binomial` — binomial distribution (n trials, probability p)
- `poisson` — Poisson distribution (lambda)
- `exponential` — exponential distribution (lambda)
- `geometric` — geometric distribution (trials until first success)
- `weighted` — weighted discrete choice from items with unequal probabilities
- `randstr` — random string from built-in or custom alphabets (alnum, hex, base58, crockford, zbase32, base32, base64, symbol, etc.)
- `uuid` — UUID v4 (random), v6 (time-ordered, 100ns), v7 (time-ordered, ms)
- `ulid` — ULID with optional monotonic mode
- `shuffle` — Fisher-Yates uniform permutation
- `choose` — uniform subset selection with or without replacement

### Features

- Multi-sample output via `-c COUNT` / `--count` (or `-n` for bellcurve); `shuffle` and `choose` are exceptions (`shuffle` reorders all items, `choose` takes N as its first argument)
- All randomness sourced from `/dev/urandom`
- Unbiased: rejection sampling or exact transforms throughout
- Pipe-friendly: one item per line, tools compose via stdin/stdout
- Claude Code plugin packaging: installable via `/plugin install randkit`
- Skill (`skills/random/SKILL.md`) teaches Claude when and how to use the tools
