# randkit

A Claude Code plugin providing unbiased random sampling tools. All tools use `/dev/urandom` as their entropy source.

## Plugin structure

```
.claude-plugin/plugin.json   # Plugin manifest
bin/                         # Tool scripts (added to PATH when plugin is active)
skills/random/SKILL.md       # Skill that teaches Claude when/how to use these tools
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
| `uniform` | Uniform float in [MIN, MAX] | Float |
| `bellcurve` | Normal (Gaussian) | Float |
| `binomial` | Binomial(n, p) | Integer in [0, n] |
| `poisson` | Poisson(λ) | Non-negative integer |
| `exponential` | Exponential(λ) | Non-negative float |
| `geometric` | Geometric(p) | Positive integer |
| `weighted` | Weighted discrete choice | Selected item |
| `randstr` | Random string from alphabet | String |
| `uuid` | UUID v4 (random), v6 (time-ordered, 100ns), or v7 (time-ordered, ms) | UUID string |
| `ulid` | ULID (time-sortable, Crockford Base32) | 26-char string |
| `shuffle` | Uniform permutation | Input items reordered |
| `choose` | Uniform subset selection (with/without replacement) | N items |

## Language

- `randint`, `cointoss`, `diceroll`, `weighted`, `randstr`, `shuffle`, and `choose` are bash scripts (no dependencies beyond POSIX + awk).
- `bellcurve`, `binomial`, `poisson`, `exponential`, `geometric`, `uniform`, `uuid`, and `ulid` are Python 3 (no external packages).

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

- `randint`: Rejection sampling with adaptive byte width (1/2/4 bytes). Exactly uniform. Ranges up to 2^32 - 1.
- `cointoss`: Single byte mod 2. Exactly 50/50 (256 divides evenly by 2).
- `diceroll`: Calls `randint 1 6`.
- `uniform`: Inverse transform, 64-bit entropy, IEEE 754 double output.
- `bellcurve` (full distribution): Box-Muller transform, 64-bit entropy, IEEE 754 double output.
- `bellcurve` (tail sampling): Inverse CDF via an asymptotic initial guess + Newton-Raphson, using Python `Decimal` (50 significant digits). Supports tails as extreme as ~37σ (--tail-pct 1e-300). Arbitrary-precision erf/erfc, exp, and ln (AGM-based).
- `binomial`: Direct Bernoulli trials (one 64-bit uniform per trial). Exact, O(n) per sample.
- `poisson` (λ < 10): Inversion method (product of uniforms). Exact, O(λ) per sample.
- `poisson` (λ >= 10): Hörmann's PTRS (transformed rejection). Exact, O(1) per sample. Maximum λ is 2^53 (beyond that float64 cannot represent consecutive integer counts).
- `exponential`: Inverse transform (-ln(U)/λ). Exact, one 64-bit read per sample.
- `geometric`: Inverse transform (ceil(ln(U)/ln(1-p))). Exact, one 64-bit read per sample.
- `weighted`: Cumulative distribution + uniform float. Selection probabilities match the given weights to double precision (awk float arithmetic).
- `randstr`: Per-character rejection sampling from alphabet. Exactly uniform over charset.
- `uuid` v4: 122 random bits with version/variant bits set. Exactly as specified in RFC 9562.
- `uuid` v6: 60-bit timestamp (100ns since UUID epoch) + 14-bit random clock_seq + 48-bit random node.
- `uuid` v7: 48-bit ms timestamp + 74 random bits. Lexicographically time-sortable.
- `ulid`: 48-bit ms timestamp + 80-bit random. Monotonic mode increments random within same ms.
- `shuffle`: Fisher-Yates with per-swap rejection sampling. Scales byte width (1/2/4 bytes) to index range. Supports lists up to ~4 billion items.
- `choose`: Partial Fisher-Yates to select indices, then sorts to preserve input order. Same rejection sampling as `shuffle`. With `--replace`: independent uniform draws.

## Piping

Tools that output one item per line can be piped into each other:
- `seq 1 100 | choose 10 | shuffle` — pick 10 from 1–100 in order, then randomize them.

## Future ideas

- **Weighted choice without replacement** — select N items with unequal probabilities, no repeats.
