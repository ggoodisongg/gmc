# Backtest — GMC EXCLUSIVE ONE v1.00, XAUUSD 2022

**Run:** ICMarketsSC-Demo build 6063 · £1,000 · 1:500 · requested 2022.01.01–2026.07.27
**Result: −£951.56 (−95.2%). PF 0.56. The build stopped itself after ~7.6 months.**

This is the first backtest any version of this system has had under the fixed
execution engine. It goes on the record red.

---

## 1. What came back

| | |
|---|---|
| Net profit | **−£951.56** (balance £1,000 → **£48.44**) |
| Profit factor | **0.56** |
| Win rate | **33.09%** (366 W / 740 L of 1,106 trades) |
| Average win / loss | +£3.34 / −£2.76 (reward:risk **1.21**) |
| Expected payoff | **−£0.86 per trade** |
| Max drawdown | 95.16% |
| Sharpe | −5.00 · Recovery factor −0.99 |
| Z-score | −10.28 (99.74%) — losses cluster, max 20 in a row |
| LR correlation | **−0.94** — near-linear decay, not noise |
| Commissions | −£262.34 |

**The arithmetic that matters:** at a 1.21 reward:risk ratio the strategy needs a
**45.25%** win rate to break even. It delivered **33.09%**. That is 12 points
short — a structural gap, not a tuning gap.

## 2. Two things make this run invalid as configured

Before drawing conclusions, the run itself has to be discounted:

1. **Period was M5. This is an M1 strategy.** The signal code hardcodes
   `PERIOD_M1`, so the *signals* were still computed off M1 data — but the
   tester only guarantees an accurate tick path at the working timeframe. Every
   trade in this system lives and dies inside a single M1 bar, so the intrabar
   sequence deciding stop-vs-target was modelled, not observed.
2. **History quality: 7% real ticks.** For a strategy running a **$1.00** stop
   on gold, fills are the whole game. 7% is not a test, it is an approximation.

Neither excuse makes the result good. They mean the result is **not yet
admissible** — the run has to be repeated properly before it either condemns or
clears the build.

## 3. The prime suspect: the $1.00 minimum stop, in the wrong decade

Read the order list and the pattern is immediate — trade after trade enters at
X and sets its stop at exactly **X ∓ 1.00**. The `InpMinSLUsd = 1.00` floor is
binding on most trades in the calm stretches.

That floor was inherited from a system calibrated on **2026 gold near $3,300+**,
where 1.5 × ATR(M1) genuinely lands around $2–4. On **2022 gold near $1,800**,
1.5 × ATR(M1) is far below $1.00, so the floor takes over and every trade is
risking roughly one M1 candle of noise.

A $1.00 stop against a $0.12–0.20 spread means **12–20% of the stop distance is
paid to the broker before the trade has an opinion.** That is the mechanism.

## 4. Cost decomposition

Total round-turn volume implied by commission: **~37 lots** (avg 0.034 lots/trade).

| Assumed spread | Spread drag | Costs (spread + commission) | Share of the £952 loss |
|---|---|---|---|
| $0.12 | ~£330 | £593 | 62% |
| $0.15 | ~£413 | £675 | 71% |
| $0.20 | ~£551 | £813 | 85% |

Commission alone is **27.6%** of the total loss.

**But costs are not the whole story.** Strip them out and the strategy is still
somewhere between −£140 and −£360 over 1,106 trades. There is no positive edge
hiding under the friction — costs turn a bad result into a catastrophic one.

## 5. This echoes REALITY_CHECK.md exactly

| | v10.x line (look-ahead OFF) | Exclusive One (this run) |
|---|---|---|
| Win rate | 31.8% | **33.1%** |
| Profit factor | 0.75 | **0.56** |
| Verdict | no real edge | no real edge |

Two separately developed strategy lines, on the same instrument, producing the
same signature the moment they meet realistic fills. That is not a coding
coincidence. It is the strongest evidence yet that the problem is in the
**approach**, not in any one implementation.

## 6. What the run does confirm — the fixes work

Every execution fix is visible in the order log:

- **F1** — every single pending order carries its stop loss in the submission
  (`buy stop 0.2 / 0.2 · 1830.73 · 1829.73`). Not one naked entry in 1,106 trades.
- **F10** — the test ends at £48.44 on 2022.08.22 rather than running to zero.
  At that equity a 1.5% risk budget over a $1.00 stop computes to 0.0098 lots,
  below the 0.01 minimum, so the risk-ceiling guard **refused to trade**. The
  build stopped itself. The guard works — but it caught the fall at −95%, not
  on the way down.
- Partial closes fire correctly: 1,966 deals across 1,106 positions = 860
  partial exits, all correctly aggregated as one trade each by F3.
- Pending expiry, cancellation and comments (`GMC1 BREAK S2`) all behave.

The engine is sound. What it is faithfully executing is a losing strategy on
this data.

## 7. Consequence: do not put this on a live account

The previous plan — smoke-test then switch the demo over — is withdrawn. The
smoke test came back red. The burden of proof has moved: **a valid backtest
showing PF > 1 is now required before either build goes back on any account.**

Order of work:

1. **Re-run properly.** Period **M1**, model **Every tick based on real ticks**,
   confirm History Quality reads ~99%. Anything less and the run is not evidence.
2. **Re-run on the live regime first** — 2026.01.01 → 2026.07.27, £1,000. That
   is the only window comparable to the demo record. If the edge is
   regime-dependent, this is where it shows.
3. **Sweep the stop floor.** `InpMinSLUsd` at 1.00 / 1.50 / 2.00 / 3.00. This is
   the prime suspect and it is one input.
4. **Then re-run 2022** to see whether any setting survives both regimes. A
   configuration that only works in one is a curve fit, not an edge.
5. If nothing clears PF 1.0 with honest fills, **that is the answer**, and it
   should be recorded here next to REALITY_CHECK.md rather than tuned around.

Nothing here clears the bar for Phase 1. The record stands — including this.
