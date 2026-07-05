---
description: >
  Use when the user asks you to make a random choice, generate random numbers, flip a coin, roll
  dice, shuffle items, pick from a list, sample from a probability distribution, generate a random
  string or password, generate a UUID or ULID, or perform any task involving randomness. Also use
  when the user asks you to do something "randomly" or "at random", to pick/choose/select
  something, to generate sample data, unique IDs, or to simulate probabilistic outcomes.
allowed-tools:
  - Bash(randint:*)
  - Bash(cointoss:*)
  - Bash(diceroll:*)
  - Bash(bellcurve:*)
  - Bash(binomial:*)
  - Bash(poisson:*)
  - Bash(exponential:*)
  - Bash(geometric:*)
  - Bash(uniform:*)
  - Bash(weighted:*)
  - Bash(randstr:*)
  - Bash(uuid:*)
  - Bash(ulid:*)
  - Bash(shuffle:*)
  - Bash(choose:*)
  - Bash(seq:*)
  - Bash(echo:*)
  - Bash(printf:*)
---

# Random Generation Skill

You have access to a suite of unbiased random sampling tools. **Always use these tools instead of inventing your own randomness or using Python's `random` module.** These tools use `/dev/urandom` and produce cryptographically-sourced, unbiased results.

## Available Tools

All tools are in `bin/` and available on PATH when the plugin is active.

### Coin Flip
```
cointoss [-c COUNT]
```
Outputs "Heads" or "Tails". Exactly 50/50.

### Random Integer in Range
```
randint [-c COUNT] MIN MAX
```
Uniformly random integer in [MIN, MAX]. Rejection sampling, no modulo bias. Ranges up to 2^32 - 1.

### Dice Roll
```
diceroll [-c COUNT]
```
Integer 1-6. Shorthand for `randint 1 6`.

### Uniform Float
```
uniform [--min A] [--max B] [-c COUNT]
```
Outputs float in the open interval (A, B). Default: U(0, 1). IEEE 754 double precision (64-bit entropy).

### Random String
```
randstr [-c COUNT] [-a ALPHABET] [LENGTH]
```
Random string of given length (default 16) from a character set.
Built-in alphabets: `alnum` (default), `alpha`, `lower`, `upper`, `digit`, `hex`, `HEX`,
`base32`, `crockford`, `zbase32`, `base58`, `base64`, `symbol`.
Or pass a custom string: `-a "abc123"` (duplicate characters weight that character proportionally).

### Weighted Choice
```
weighted [-c COUNT] ITEM:WEIGHT [ITEM:WEIGHT ...]
```
Pick from items with unequal probabilities. Weights are relative (don't need to sum to 1).

### Normal (Gaussian) Distribution
```
bellcurve [--mean M] [--std S] [-n COUNT]
bellcurve --tail-sigma K [--left|--right] [-n COUNT]
bellcurve --tail-pct P [--left|--right] [-n COUNT]    # P is a percentage (5 = 5%, not 0.05)
bellcurve --tail-above X [--mean M --std S] [-n COUNT]
bellcurve --tail-below X [--mean M --std S] [-n COUNT]
```
Floating-point numbers. Default: N(0,1). Supports tail sampling for extreme values.

### Binomial Distribution
```
binomial [--n TRIALS] [--p PROB] [-c COUNT]
```
Integers in [0, n]. Default: Binomial(10, 0.5). Models "number of successes in n trials".

### Poisson Distribution
```
poisson --lambda L [-c COUNT]
```
Non-negative integers. `--lambda` is required (λ fully determines the distribution; there is no canonical default). Models "number of events in an interval". Maximum λ is 2^53 (≈9.0e15); beyond that float64 cannot represent consecutive integer counts.

### Exponential Distribution
```
exponential [--lambda L] [-c COUNT]
```
Non-negative floats. Default: Exponential(1). Models "time between events".

### Geometric Distribution
```
geometric [--p P] [-c COUNT]
```
Positive integers (minimum 1). Default: Geometric(0.5). Models "trials until first success". Expected value is 1/p.

### UUID
```
uuid [--version 4|6|7] [-c COUNT]
```
Generate UUIDs in standard `8-4-4-4-12` hex format.
- **v4** (default): 122 random bits. No time component.
- **v6**: Time-ordered (RFC 9562). 60-bit timestamp at 100ns precision + random node. Sorts lexicographically by creation time.
- **v7**: Time-ordered (RFC 9562). 48-bit ms timestamp + 74 random bits. Simpler than v6, preferred for new applications.

### ULID
```
ulid [-c COUNT] [--monotonic]
```
Generate ULIDs: 26 chars of Crockford's Base32 encoding 48-bit ms timestamp + 80-bit random.
Sorts chronologically. With `--monotonic`, increments the random part within the same millisecond to guarantee strict ordering.

### Shuffle Items
```
shuffle ITEM1 ITEM2 ITEM3 ...
printf 'a\nb\nc\n' | shuffle
seq 1 52 | shuffle
```
All items in uniformly random order, one per line. Fisher-Yates algorithm.
If the first item could be mistaken for a flag (e.g. `-h`), put `--` before the items.

### Choose N Items
```
choose N ITEM1 ITEM2 ITEM3 ...
choose --replace N ITEM1 ITEM2 ...
seq 1 100 | choose 10
```
Without `--replace`: selects N items, preserving original input order. Each item chosen at most once. If the user expects a randomized order (e.g. drawing cards from a deck), pipe through `shuffle`: `choose 10 ... | shuffle`.
With `--replace`: selects N items independently (repeats possible). Output in selection order.

## Decision Guide

| User wants... | Tool to use |
|---|---|
| Yes/no, heads/tails, binary choice | `cointoss` |
| Multiple coin flips | `cointoss -c 10` |
| Pick a number 1-6 | `diceroll` |
| Multiple dice rolls | `diceroll -c 10` |
| Random integer in range [a,b] | `randint a b` |
| Multiple random integers in range | `randint -c 10 a b` |
| Multiple random integers (no replacement) | `seq a b \| choose N` |
| Multiple random integers (with replacement) | `randint -c N a b` or `choose --replace N ...` |
| Random float in [a,b] | `uniform --min a --max b` |
| Pick one item from a list | `choose 1 item1 item2 ...` |
| Pick N items (no repeats) | `choose N item1 item2 ...` |
| Pick N items (repeats ok) | `choose --replace N item1 item2 ...` |
| Weighted/biased random choice | `weighted item1:0.7 item2:0.2 item3:0.1` |
| Randomize order of items | `shuffle item1 item2 ...` |
| Random string/password | `randstr` or `randstr -a symbol 20` |
| Random hex token | `randstr -a hex 32` |
| Random PIN / digits | `randstr -a digit 6` |
| Gaussian/normal samples | `bellcurve --mean M --std S -n COUNT` |
| Count successes (coin-flip model) | `binomial --n TRIALS --p PROB` |
| Count rare events | `poisson --lambda L` |
| Time between events | `exponential --lambda L` |
| Trials until first success | `geometric --p P` |
| UUID (random) | `uuid` or `uuid --version 4` |
| UUID (time-sortable, 100ns) | `uuid --version 6` |
| UUID (time-sortable, ms, preferred) | `uuid --version 7` |
| ULID (time-sortable ID) | `ulid` |
| Batch of ordered ULIDs | `ulid --monotonic -c 10` |
| Extreme / tail values | `bellcurve --tail-sigma K` or `--tail-pct P` |

## Piping Patterns

Tools output one item per line and compose well:
```bash
# Pick 5 random numbers from 1-100, then shuffle their order
seq 1 100 | choose 5 | shuffle

# Sum of 3 dice
diceroll -c 3 | paste -sd+ | bc

# Generate 20 normal samples and pick the top 5
bellcurve -n 20 | sort -n | tail -5

# Random password: 20 chars with symbols
randstr -a symbol 20
```

## Important Rules

1. **Never fake randomness.** Don't say "I'll randomly pick X" without actually running a tool. Always invoke the appropriate command and use its output.
2. **Show your work.** When making a random choice, show the user what command you ran and what result you got.
3. **Use the right tool.** Don't use `shuffle` when you mean `choose` (shuffle reorders everything; choose selects a subset).
4. **Use multi-sample flags.** Most tools support `-c COUNT` (or `-n` for bellcurve) — use them instead of loops. Exceptions: `shuffle` reorders all items, and `choose` takes N as its first argument.
5. **`weighted` for biased choices.** Don't use `choose` or custom logic when probabilities aren't equal — use `weighted`.
