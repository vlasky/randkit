# Changelog

## 1.1.0 (2026-07-05)

### Fixed

- `geometric` crashed with `ZeroDivisionError` for p below ~1e-16 and silently lost precision for all small p; the inverse transform now uses `log1p(-p)`.
- The shared uniform construction in the Python samplers could round to exactly 1.0 (probability ~2^-54), letting `geometric` return 0, `binomial --p 1` return less than n, and `exponential` print `-0`. All samplers now use `((u >> 12) + 0.5) * 2^-52`, which is exact in double arithmetic and strictly inside (0, 1).
- `bellcurve` tail sampling was inaccurate in extreme tails (at `--tail-pct 1e-300` samples were misplaced by ~0.6σ): Newton refinement of the inverse CDF now iterates on ln(CDF), restoring full 50-digit accuracy out to ~37σ (verified against mpmath).
- `choose`, `weighted`, and `randstr` printed nothing for items or output that looked like `echo` flags (such as `-n`); they now print via `printf`.
- `weighted` reported a confusing error for arguments missing the `:WEIGHT` suffix.

### Changed

- The bash tools now stream entropy from a single `od` process through a shared awk library (`lib/rand-awk.sh`) instead of forking `od` per sample (per character, in `randstr`). Batch generation is ~50-100x faster.
- `bellcurve` uses the stdlib `Decimal` ln/exp/sqrt (correctly rounded) in place of hand-rolled AGM/Taylor implementations.
- `uuid` v7 and `ulid` take timestamps from `time.time_ns()`, matching `uuid` v6.
- The skill's `allowed-tools` patterns use the word-boundary form `Bash(tool:*)`.

### Added

- MIT LICENSE (the README had claimed MIT with no licence text).
- Functional, statistical, and lint test suites with CI on Ubuntu and macOS (including a system bash 3.2 run).
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
