# Test 3 — BREAK only (`InpEnableFVG = false`)

**Run:** GMC EXCLUSIVE ONE v1.00 · XAUUSD **M1** · 2026.01.01–2026.07.27 · 56% real ticks · £1,000
**Inputs vs test 2:** `InpEnableFVG true → false`. Everything else unchanged
(`InpBankR0Pct = 0`, `InpSellsEnabled = false`).

**Result: −£194.98. PF 0.89. 251 positions. Zero FVG entries in the log.**

**The prediction that mattered came in: pre-cost P/L is positive for the first time.**

---

## 1. Prediction vs outcome

Stated in [`SETUP_FORENSICS_2026.md`](SETUP_FORENSICS_2026.md) §6 **before** the run:

| | Predicted | Actual | |
|---|---|---|---|
| Profit factor | ≈ 0.93 | **0.89** | close |
| Net | ≈ −£100 | **−£194.98** | **missed — see §3** |
| Positions | ≈ 236 | **251** | missed |
| MT5 "Total Trades" | 290–300 | **319** | missed |
| Per-position win rate | ≈ 28% | **27.09%** | landed |
| FVG entries | zero | **zero** | landed |
| **Pre-cost P/L** | **+£82 to +£151** | **+£35 to +£120** | **landed — same sign** |

## 2. The result

| | Test 2 (BREAK+FVG) | **Test 3 (BREAK only)** |
|---|---|---|
| Net profit | −£330.68 | **−£194.98** |
| Profit factor | 0.81 | **0.89** |
| Positions | 288 | 251 |
| Win rate (per position) | 24.65% | **27.09%** |
| Average win / loss | 19.64 / 7.95 | **23.07 / 9.64** |
| Reward:risk | 2.47 | 2.39 |
| Breakeven WR needed | 28.81% | 29.47% |
| **Gap to breakeven** | −4.16 pts | **−2.38 pts** |
| Max equity drawdown | 43.37% | **30.80%** |
| Max consecutive losses | 12 | **10** |
| **LR correlation** | −0.94 | **−0.85** |

The equity curve also spent the whole of January **above** starting capital, peaking at
**£1,020.87** on 23 January. Every prior run was underwater from the first week.

**LR correlation moving off −0.94 for the first time in five runs** matters. That figure has
been the signature of "a straight line down." At −0.85 the curve is still declining, but it
is no longer the same object.

## 3. Where the −£100 estimate went wrong, and why it does not invalidate the test

I projected −£100 by **summing the 236 BREAK positions out of test 2's log**. That assumed
the FVG trades were separable. They are not:

- The EA holds **one position at a time**. An FVG trade occupying the slot **blocks** any
  BREAK signal that fires while it is open. Remove the FVG trades and those blocked BREAK
  signals now fill — **15 net new positions** appear that exist in no earlier run
  (`2026.01.06 18:39`, `2026.01.13 19:01`, `2026.01.27 07:51` and `08:01`, `2026.02.19 07:47`,
  `2026.02.20 22:23`, `2026.02.23 16:30`, `2026.02.27 21:02`, `2026.03.02 08:00`, and more).
- Risk is **1.5% of live equity**, so a different equity path means different lot sizes on
  every subsequent trade. Test 3 traded **more volume** (14.47 lots) than test 2 (14.18)
  despite **37 fewer positions**, because the balance stayed higher throughout.

**Backtest runs of this EA are not additively decomposable.** Any future projection made by
summing a subset of a prior log carries the same error. Recorded here so it is not repeated.

The *sign* of the pre-cost result — the thing the test was run to check — was predicted
correctly and is unaffected.

## 4. Pre-cost P/L: positive

Commission £101.26 → ~14.47 round-turn lots.

| Assumed spread | Commission | Spread drag | Total costs | vs loss | **Pre-cost P/L** |
|---|---|---|---|---|---|
| $0.12 | £101 | £128 | £230 | 118% | **+£35** |
| $0.15 | £101 | £161 | £262 | 134% | **+£67** |
| $0.20 | £101 | £214 | £315 | 162% | **+£120** |

**Costs now exceed the entire loss at every spread assumption.** The strategy generates
**+£0.14 to +£0.48 per trade** of gross edge and pays **£0.92 to £1.26 per trade** in friction.

The full progression:

| Run | Pre-cost per trade @ $0.15 |
|---|---|
| 2026 baseline (both directions, banking) | **−£0.44** |
| Test 1 (both directions, no banking) | **−£0.47** |
| Test 2 (longs only) | **−£0.21** |
| **Test 3 (longs only, BREAK only)** | **+£0.27** |

This is now a **cost problem, not an edge problem** — a different kind of problem, with a
different kind of fix. It is not yet a working strategy: PF 0.89 is a −19.5% window, and
"positive before costs" is the minimum bar, not a passing grade.

## 5. What is NOT being acted on, again

The grade split reproduced almost exactly:

| Grade | N (t2 → t3) | PF (t2 → t3) | Net (t2 → t3) | gap to BE (t3) |
|---|---|---|---|---|
| BREAK S0 | 14 → 15 | 0.41 → **0.35** | −£34 → **−£45** | −21.7 pts |
| BREAK S1 | 41 → 47 | 1.26 → **1.24** | +£29 → **+£38** | +4.1 pts |
| BREAK S2 | 95 → 103 | 1.34 → **1.16** | +£199 → **+£121** | +3.2 pts |
| **BREAK S3** | **86 → 86** | **0.57 → 0.61** | **−£297 → −£309** | **−9.4 pts** |

S3 is 34% of the trades and, on its own, **more than the entire loss** — without it the run
is **+£114**. S1 and S2 are both above breakeven in both runs.

**This is still not evidence and is still not being acted on.** It is the *same window*
re-read, so the two rows are not independent observations — the stability across a materially
different trade path (251 vs 288 positions, 15 new trades, different lot sizes throughout) is
a consistency check, not a second test. Acting on it now would be selecting a bucket from
eight after seeing the answer, twice.

It goes in the queue *behind* the out-of-sample run, not in front of it.

## 6. Next: 2022, unchanged

Per the order set before test 3: **the 2022 confirmation run comes next, before any
optimisation work.**

`InpEnableFVG = false`, `InpSellsEnabled = false`, `InpBankR0Pct = 0` — identical config,
period **2022.01.01 → 2026.07.27**, **M1**, real ticks.

This is the kill-switch. Three of the four numbers above were chosen after looking at 2026
data. If BREAK-only fails on 2022, test 3 was a curve fit and the whole line stops there.
If it holds, then — and only then — the grade question gets asked properly, with the
hypothesis written down first.

**Do not run a cost-reduction variation before the 2022 result.** There is no point tuning
friction on a configuration that has not been shown to survive a second regime.

### 6a. A confound, written down before the run

2022 gold trades near **$1,800**. 1.5 × ATR(M1) there is well below **$1.00**, so
`InpMinSLUsd = 1.00` **binds on most trades** — the finding already recorded in
[`BACKTEST_EXCLUSIVE_ONE_2022.md`](BACKTEST_EXCLUSIVE_ONE_2022.md) §3. On 2026 gold the same
input never binds; stops run $2.16–$3.91.

That matters more now than it did then. Test 3 shows costs at **118–162% of the loss** and
the gross edge at **+£0.27/trade**. A stop three times tighter does not shrink the spread —
it triples the spread's share of every trade. A 2022 failure would therefore be **ambiguous**
between two causes:

1. BREAK-only has no edge outside 2026 → the configuration is a curve fit, stop.
2. The stop floor is eating the edge at a price level it was never calibrated for → the
   signal is untested, not refuted.

**The diagnostic, fixed in advance:** read the `S / L` column of the 2022 order list. If most
entries show a stop **exactly $1.00** from entry, cause 2 is live and the run does not settle
anything — it gets repeated **once**, with `InpMinSLUsd` scaled to the regime
(≈ $0.45, holding stop ÷ price constant against 2026's ~$2.80 on ~$4,700 gold) and nothing
else changed. If stops are comfortably above the floor and it still fails, that is cause 1
and the line stops there.

Stating this now so that a bad 2022 result cannot be rationalised after the fact, and so that
the one permitted follow-up is defined before its trigger is observed rather than after.

**Prediction for the 2022 run:** PF **0.65–0.85**, failing the bar, with the stop floor
binding on a majority of trades. If PF comes in above 1.0 on 2022 as configured, that is a
stronger result than anything predicted here and should be treated with suspicion, not
celebration, until the order list is read.

## 7. Standing

PF 0.89 is still a losing configuration and still does not go on any account. But this is the
first run in the entire investigation where the underlying signal makes money before the
broker takes its cut, and the first where the equity curve is not a −0.94 straight line down.

Nothing here clears the bar for Phase 1. The record stands — including this.
