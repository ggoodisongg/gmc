# Setup forensics — decomposing the test 2 order log

**Source:** the test 2 run ([`BACKTEST_EXCLUSIVE_ONE_2026_TEST2.md`](BACKTEST_EXCLUSIVE_ONE_2026_TEST2.md))
— XAUUSD M1, 2026, longs only, `InpBankR0Pct=0`, PF 0.81, −£330.68.

**No new backtest was run.** Every position was reconstructed from the deal log by
walking the balance column, keyed to the setup tag in the entry comment
(`GMC1 BREAK S2`, `GMC1 FVG S1`, …). The reconstruction terminates at **£669.32**,
matching the report exactly, so the decomposition below is arithmetic, not estimation.

This document contains one **finding** and one **hypothesis**. They are labelled, because
the hypothesis was formed after seeing the data and has not been tested.

---

## 1. Finding: MT5's "Total Trades" is not trades

| | Report says | Actually |
|---|---|---|
| Total Deals | 648 | 648 ✔ |
| Total Trades | **360** | **288 positions** |
| Win rate | **34.72%** | **24.65%** |
| Average win / loss | 11.33 / 7.43 | **19.64 / 7.95** |
| Reward:risk | 1.52 | **2.47** |
| Breakeven WR needed | 39.62% | **28.81%** |
| Gap to breakeven | −4.90 pts | **−4.16 pts** |
| Profit factor | 0.81 | **0.81** ✔ |

288 entry deals + 360 exit deals = 648. **MT5's Strategy Tester counts closing deals as
trades**, so every partial close is counted as its own "trade" — and a partial bank is
almost always a winner. The reported win rate is inflated and the reported average win is
understated, by construction.

This is the same accounting error as defect **P2** in
[`FORWARD_TEST_TrackB_v3.1.md`](FORWARD_TEST_TrackB_v3.1.md), which **F3** fixed *inside*
the EA. It was never wrong in the build. It is wrong in the report, and it has therefore
been wrong in every win-rate figure quoted in this repo.

**Correction to the earlier records** (profit factor and net profit are unaffected — those
are deal-sums either way):

| Run | Reported "trades" | Real positions | Reported WR | Real WR |
|---|---|---|---|---|
| 2026 baseline | 643 | **482** (1,125 − 643) | 38.41% | — |
| 2026 test 2 | 360 | **288** | 34.72% | **24.65%** |

The direction of every conclusion so far survives the correction — the gap to breakeven at
position level is 4.16 points where the deal-level figure said 4.90 — but the numbers
themselves were wrong and are now corrected.

## 2. Finding: the FVG setups are the loss

Per position, by entry tag:

| Setup | N | Won | WR | avg win | avg loss | R:R | **PF** | **Net** | per trade |
|---|---|---|---|---|---|---|---|---|---|
| **BREAK** | 236 | 66 | 27.97% | 20.22 | 8.45 | 2.39 | **0.93** | **−£102** | −£0.43 |
| **FVG** | 52 | 5 | **9.62%** | 12.05 | 6.14 | 1.96 | **0.21** | **−£228** | **−£4.39** |

**FVG is 18% of the trades and 69% of the loss.** Five wins in fifty-two.

That is not a marginal underperformance. FVG needs 33.77% to break even and delivered 9.62%.
If the FVG signal were genuinely break-even, the probability of 5 or fewer wins in 52 is
**0.0055%**. Even benchmarked against the *system-wide* 24.65% win rate — i.e. asking only
"is FVG worse than the rest of this system?" — it is **0.56%**.

Strip FVG out and BREAK-only is **PF 0.93** against **PF 0.81** for the pair.

## 3. Hypothesis (untested): BREAK-only is positive before costs

Applying the same cost model used in the previous three records, scaled to BREAK's share of
volume (236/288 → ~11.6 round-turn lots, ~£81 commission):

| Assumed spread | Costs | Net | **Pre-cost P/L** |
|---|---|---|---|
| $0.12 | £184 | −£102 | **+£82** |
| $0.15 | £210 | −£102 | **+£108** |
| $0.20 | £253 | −£102 | **+£151** |

**This is the first positive pre-cost number in the entire investigation.** Every prior run
was −£210 to −£320 before costs. If it holds, the problem changes shape completely:

> Not "there is no edge." Rather: *a small edge of ~+£0.46/trade being eaten by ~£0.89/trade
> of friction.*

Those are different problems with different fixes. The first is unfixable. The second is a
cost and trade-selection problem.

## 4. Why this is a hypothesis and not a result

**The FVG split was chosen after seeing which side lost.** That is the definition of
in-sample selection and it is exactly how curve fits are born. Three things stop me
throwing it away, and none of them stop it needing an out-of-sample test:

1. It is a **pre-existing structural distinction** with its own input flag
   (`InpEnableFVG`), not a threshold tuned to the data. There was one binary choice to
   make, not a parameter to slide.
2. The effect is **far outside noise** — 0.0055% against its own breakeven requirement.
3. It is **one input and one run** to check, which is the same protocol every other test in
   this repo has followed.

What would kill it: FVG performing normally on 2022, or BREAK-only failing to reproduce
PF ≈ 0.93 on 2026.

## 5. What is deliberately NOT being acted on

The grade decomposition is more tempting and much less trustworthy:

| Grade | N | WR | PF | Net |
|---|---|---|---|---|
| BREAK S2 | 95 | 35.79% | **1.34** | **+£199** |
| BREAK S1 | 41 | 29.27% | 1.26 | +£29 |
| BREAK S0 | 14 | 21.43% | 0.41 | −£34 |
| **BREAK S3** | 86 | 19.77% | **0.57** | **−£297** |

Dropping BREAK S3 as well as FVG would leave 136 positions at PF 1.33 and +£228. **Do not
do this.** Four grades × two types is eight buckets; picking the winners out of eight after
the fact will produce a beautiful equity curve on any random data. BREAK S3's shortfall sits
at p = 0.019 against its own breakeven and p = 0.18 against the system rate — a tenth as
convincing as the FVG result, on a selection space eight times larger, and with no input to
switch it off without editing the build.

Recorded here so it is on the record that it was seen and declined. If BREAK-only survives
2026 and 2022, the grade question can be asked properly — with a hypothesis stated first.

## 6. Next test

`InpEnableFVG = false`, everything else as test 2.

**Stated prediction, before the run:** PF ≈ 0.93, net ≈ −£100, ~236 positions,
per-position win rate ≈ 28%. **This will not clear PF 1.0** and is not expected to. It is
run to confirm the decomposition is real and that the pre-cost figure turns positive — which
is what decides whether the cost work in step 2 is worth doing or is polishing a corpse.

Nothing here clears the bar for Phase 1. The record stands — including this.
