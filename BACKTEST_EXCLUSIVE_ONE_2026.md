# Backtest — GMC EXCLUSIVE ONE v1.00, XAUUSD M1, Jan–Jul 2026

**Run:** ICMarketsSC-Demo 6063 · £1,000 · M1 · 2026.01.01–2026.07.27 · 56% real ticks
**Result: −£585.23 (−58.5%). PF 0.72. 643 trades.**

This is the run that counts. Right timeframe, right regime, and — critically — the
same trade rate as the live account. The 2022 run
([`BACKTEST_EXCLUSIVE_ONE_2022.md`](BACKTEST_EXCLUSIVE_ONE_2022.md)) was
inadmissible on configuration. This one is admissible, and it is red.

---

## 1. Result

| | |
|---|---|
| Net profit | **−£585.23** (£1,000 → **£414.77**) |
| Profit factor | **0.72** |
| Win rate | **38.41%** (247 W / 396 L of 643) |
| Average win / loss | +£6.21 / −£5.20 (reward:risk **1.19**) |
| **Breakeven win rate needed** | **45.57%** — short by **7.2 points** |
| Expected payoff | −£0.91 per trade |
| Max drawdown | 62.02% |
| Sharpe | −5.00 · Recovery −0.88 · **LR correlation −0.94** |
| Z-score | −6.15 (99.74%) — max 21 consecutive losses |
| Longs / shorts won | **41.15%** (401) / **33.88%** (242) |
| Trades per week | **22.2** |

## 2. Why this run is admissible where the 2022 one wasn't

| | 2022 run | This run |
|---|---|---|
| Period | M5 (wrong) | **M1** ✔ |
| Tick quality | 7% | **56%** |
| Regime | gold ~$1,800 | **gold $4,000–5,400** ✔ matches live |
| Trades/week | 33.5 | **22.2** ✔ vs **21/wk live** |

The trade rate matching the live account to within 6% is the important one. The
backtest is now trading the *same population* the demo traded. The comparison is
meaningful.

56% real ticks is still not 99%. It is enough to trust the direction and the
magnitude; it is not enough to trust a marginal result. This result is not marginal.

## 3. The $1.00 stop-floor hypothesis is dead

The 2022 note named the `InpMinSLUsd = 1.00` floor as prime suspect. On 2026 gold
the stops actually used are:

`$2.17 · $2.16 · $2.32 · $3.26 · $3.65 · $2.94 · $3.21 · $3.91 · $3.67 · $3.63`

**The floor never binds.** 1.5 × ATR(M1) sits at $2–4 exactly as designed, the stop
is 3× wider than 2022 in absolute terms and far wider relative to spread — and the
system still loses. Whatever is wrong is not the stop width.

## 4. What is actually wrong: breakeven-at-+1R

Read the exit prices. This pattern repeats through the whole log:

```
in 4398.73  ->  out 4398.70   (sl 4398.73)
in 4419.34  ->  out 4419.31   (sl 4419.34)
in 4560.06  ->  out 4560.06   (sl 4560.06)
in 4580.78  ->  out 4580.77   (sl 4580.78)
in 5000.71  ->  out 5000.71   (sl 5000.71)
in 4817.73  ->  out 4817.73   (sl 4817.73)
in 4010.39  ->  out 4010.39   (sl 4010.39)
in 4126.02  ->  out 4126.02   (sl 4126.02)
```

That is the sequence working exactly as written: price reaches +1.0R → bank 33% →
**move stop to breakeven** → price retraces → the remaining 67% is scratched at
entry. The trade nets **+0.33R minus commission**.

Now the arithmetic. If a trade that reaches +1R yields **+0.33R** and a trade that
doesn't yields **−1R**, you need **75%** of all trades to reach +1R just to break
even on that pair. The runners (+2R to +8R) are supposed to make up the difference
and there are not enough of them: 482 of 1,125 deals are partial closes, so the
banking machinery fires constantly, and the result is still PF 0.72.

**The breakeven move caps the winners without protecting the losers.** A loser is
still −1R; a would-be winner is converted into a scratch. That is the mechanism,
and it is a design decision, not a bug — the code is executing the specification
faithfully.

## 5. Costs

Round-turn volume ~16.6 lots (avg 0.026/trade). Commission £116.94 = 20% of the loss.

| Assumed spread | Spread drag | Total costs | Share of loss | Pre-cost P/L |
|---|---|---|---|---|
| $0.12 | £147 | £264 | 45% | −£322 |
| $0.15 | £184 | £301 | 51% | −£285 |
| $0.20 | £245 | £362 | 62% | −£223 |

Costs are about half the damage. **Strip every penny of them out and the strategy
still loses ~£285 over 643 trades.** There is no edge underneath the friction.

## 6. This explains the live demo result

The live window sits inside this backtest. Over 15–24 July 2026 the backtest went
£411 → £414.77 — **flat**. The live demo over the same window made **+9.89%**.

The difference is not edge. It is:
- the live build ran **3% base risk** and Kelly on, vs 1.5% flat here — roughly 2×
  the size on the same signals;
- a wider spread gate (25 vs 15 points) admitting a different subset of trades;
- and a favourable two-day stretch that the earlier analysis already showed
  contributed +17.65pp of a +9.89pp total.

At 1.5% risk over the same days the system was flat. The +9.89% was leverage
applied to noise, exactly as the t-statistic (0.84–1.21 against a 1.645 threshold)
said it was.

## 7. Two regimes, same verdict

| | 2022 (M5, 7% ticks) | 2026 (M1, 56% ticks) |
|---|---|---|
| Profit factor | 0.56 | 0.72 |
| Win rate vs breakeven | 33.1% vs 45.2% | 38.4% vs 45.6% |
| Max drawdown | 95.2% | 62.0% |
| LR correlation | −0.94 | **−0.94** |

Four and a half years apart, different price level, different volatility, different
configuration — and the equity curve decays with the same −0.94 linearity both
times. Combined with [`REALITY_CHECK.md`](REALITY_CHECK.md) (v10.x line: 31.8% WR,
PF 0.75 with look-ahead off), that is **three independent tests across two
strategy lines all landing in PF 0.56–0.75 with a win rate 7–13 points below
breakeven.**

That is not variance. That is a finding.

## 8. What to do

**Do not put this on a live or demo account.** There is nothing left to learn from
running it; the question is now settled at this configuration.

Two structural hypotheses are worth **one test each** — not a parameter sweep, and
both must clear PF 1.0 on **2026 and 2022** to count:

1. **Kill the breakeven move.** `InpBankR0Pct = 0` (no bank, no BE at +1R), leaving
   TP1/locks/runner intact. This is the mechanism identified in §4 and it is a
   single input. If winners stop being capped at +0.33R, the required win rate
   falls sharply.
   > **Tested — failed.** PF 0.73, −£581.10. The required win rate did fall
   > sharply (45.57% → 39.26%) and the actual win rate fell almost as much
   > (38.41% → 32.65%), so the P/L moved £4 on a £585 loss. §4 named a symptom,
   > not the mechanism. See [`BACKTEST_EXCLUSIVE_ONE_2026_TEST1.md`](BACKTEST_EXCLUSIVE_ONE_2026_TEST1.md).
2. **Longs only.** `InpSellsEnabled = false`. Shorts win 33.88% vs longs 41.15% — a
   7-point gap across 242 vs 401 trades. Worth one test; be aware Jan–Jul 2026 gold
   trended up, so a longs-only result that only works in 2026 is a curve fit.

If neither clears PF 1.0 in both windows, the honest conclusion is that **the Track B
approach does not have an edge on XAUUSD M1**, and that belongs in this repo next to
REALITY_CHECK.md rather than being tuned around. Three tests pointing the same way
is enough evidence to stop rather than to keep searching.

Phase 0 is doing exactly what it was built to do. The record stands — including this.
