![Version: 1.0](https://img.shields.io/badge/version-1.0-brightgreen.svg)
![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blueviolet.svg)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell: bash](https://img.shields.io/badge/shell-bash-green.svg)
![Python: 3](https://img.shields.io/badge/python-3-yellow.svg)
![Platform: Linux | macOS | WSL](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-lightgrey.svg)

# randkit

A Claude Code plugin that gives Claude access to unbiased random sampling tools. When installed, Claude will automatically use these tools whenever you ask it to make random choices, generate random numbers, flip coins, roll dice, shuffle items, or sample from probability distributions.

## Installation

Add the marketplace and install:

```
/plugin marketplace add vlasky/randkit
/plugin install randkit
```

Or test locally:

```
claude --plugin-dir /path/to/randkit
```

## Uninstallation

```
/plugin uninstall randkit
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
| `geometric` | Geometric(p) | Positive integer (trials until first success) |
| `weighted` | Weighted discrete choice | Selected item |
| `randstr` | Random string from alphabet | String |
| `uuid` | UUID v4 (random), v6 or v7 (time-ordered) | UUID string |
| `ulid` | ULID (time-sortable, Crockford Base32) | 26-char string |
| `shuffle` | Uniform permutation | Input items reordered |
| `choose` | Uniform subset selection | N items (with or without replacement) |

## Examples

Ask Claude things like:

- "Flip a coin" → `cointoss`
- "Roll a die 10 times" → `diceroll -c 10`
- "Pick 3 random items from: apple, banana, cherry, date, elderberry" → `choose 3 ...`
- "Pick a random item, but weight apple 3x higher" → `weighted apple:3 banana:1 cherry:1 ...`
- "Shuffle this list: red, green, blue, yellow" → `shuffle ...`
- "Give me a random number from 1 to 100" → `randint 1 100`
- "Random float between 0 and 1" → `uniform`
- "Generate 5 samples from a normal distribution with mean 50 and std 10" → `bellcurve --mean 50 --std 10 -n 5`
- "Simulate 20 Poisson events with lambda 3" → `poisson --lambda 3 -c 20`
- "How many coin flips until heads?" → `geometric --p 0.5`
- "Generate a random password" → `randstr -a symbol 20`
- "Give me a 32-character hex token" → `randstr -a hex 32`
- "Roll a d20 five times" → `randint -c 5 1 20`
- "Pick 10 items with replacement from a b c" → `choose --replace 10 a b c`
- "Generate a UUID" → `uuid`
- "Give me a time-sortable UUID" → `uuid --version 7`
- "Generate a ULID" → `ulid`
- "Generate 10 monotonic ULIDs" → `ulid --monotonic -c 10`

Claude will use the appropriate tool and show you the command and result.

## Design principles

- **No external dependencies** — only `/dev/urandom`, standard Python 3, and POSIX tools.
- **Unbiased sampling** — rejection sampling or exact transforms; no modulo bias.
- **One sample per line** — all tools compose via pipes.
- **Cryptographic entropy** — all randomness sourced from `/dev/urandom`.
- **Multi-sample support** — sampling tools accept `-c COUNT` / `--count` (or `-n` for bellcurve); `shuffle` reorders all items and `choose` takes N as its first argument.

## Algorithms

- `randint`: Rejection sampling with adaptive byte width (1/2/4 bytes). Exactly uniform. Ranges up to 2^32 - 1.
- `cointoss`: Single byte mod 2. Exactly 50/50.
- `diceroll`: Calls `randint 1 6`.
- `uniform`: 64-bit entropy mapped to IEEE 754 double in (MIN, MAX).
- `bellcurve`: Box-Muller transform (full distribution) or inverse CDF with 50-digit precision (tail sampling).
- `binomial`: Direct Bernoulli trials. Exact, O(n).
- `poisson`: Inversion (λ < 10) or Hörmann's PTRS (λ ≥ 10). Exact.
- `exponential`: Inverse transform −ln(U)/λ. Exact.
- `geometric`: Inverse transform ceil(ln(U)/ln(1−p)). Exact.
- `weighted`: Cumulative distribution function with 64-bit uniform float.
- `randstr`: Per-character rejection sampling. Exactly uniform over alphabet.
- `uuid` v4: 122 random bits, version/variant set per RFC 9562.
- `uuid` v6: 60-bit 100ns timestamp + random clock_seq and node. Lexicographically time-sortable.
- `uuid` v7: 48-bit ms timestamp + 74 random bits. Simpler than v6, preferred for new applications.
- `ulid`: 48-bit ms timestamp + 80-bit random, Crockford Base32. Monotonic mode increments within same ms.
- `shuffle`: Fisher-Yates with per-swap rejection sampling.
- `choose`: Partial Fisher-Yates (without replacement) or independent draws (with replacement).

## Piping

Tools output one item per line and compose naturally:

```bash
seq 1 100 | choose 10 | shuffle    # pick 10 from 1–100, then randomize
bellcurve -n 20 | sort -n | tail -5  # top 5 of 20 normal samples
diceroll -c 3 | paste -sd+ | bc      # sum of 3 dice
```

## Requirements

- Bash (for randint, cointoss, diceroll, weighted, randstr, shuffle, choose)
- Python 3 (for bellcurve, binomial, poisson, exponential, geometric, uniform, uuid, ulid)
- `/dev/urandom` (Linux, macOS, WSL)

## License

MIT
