# Changelog

## 1.0.0 (2026-05-26)

Initial release.

### Tools

- `randint` — uniform integer in [MIN, MAX] with rejection sampling
- `cointoss` — fair coin flip (50/50)
- `diceroll` — fair 6-sided die (shorthand for `randint 1 6`)
- `uniform` — uniform float in [MIN, MAX]
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
