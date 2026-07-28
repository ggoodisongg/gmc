# Test 1 — kill the breakeven move (`InpBankR0Pct = 0`)

**Run:** GMC EXCLUSIVE ONE v1.00 · XAUUSD **M1** · 2026.01.01–2026.07.27 · 56% real ticks · £1,000
**Single input changed** from the baseline in
[`BACKTEST_EXCLUSIVE_ONE_2026.md`](BACKTEST_EXCLUSIVE_ONE_2026.md): `InpBankR0Pct 33 → 0`.

**Result: −£581.10 (−58.1%). PF 0.73. 585 trades. Hypothesis 1 failed.**

The baseline lost £585.23. This lost £581.10. **£4.13 of a £585 loss — 0.7%.** On
585 trades that is not an improvement, it is the same number.

---

## 1. Side by side

| | Baseline `BankR0=33` | Test 1 `BankR0=0` | Δ |
|---|---|---|---|
| Net profit | −£585.23 | **−£581.10** | +£4.13 |
| Profit factor | 0.72 | **0.73** | +0.01 |
| Trades | 643 | 585 | −58 |
| Win rate | 38.41% | **32.65%** | **−5.76 pts** |
| Average win / loss | +£6.21 / −£5.20 | **+£8.20 / −£5.30** | — |
| Reward:risk | 1.19 | **1.55** | **+30%** |
| Breakeven WR needed | 45.57% | **39.26%** | **−6.31 pts** |
| **Gap to breakeven** | 7.16 pts | **6.61 pts** | 0.55 pts |
| Expected payoff | −£0.91 | −£0.99 | worse |
| LR correlation | −0.94 | **−0.94** | unchanged |
| Max consecutive losses | 21 | **21** | unchanged |
| Sharpe | −5.00 | −5.00 | unchanged |

## 2. What this actually proves

The mechanical predictions in §4 of the baseline note **all landed**:

- winners stopped being capped at +0.33R → average win rose £6.21 → £8.20;
- reward:risk went 1.19 → 1.55, a 30% improvement;
- the required win rate fell 45.57% → 39.26%, 6.31 points, "sharply" as predicted.

And the actual win rate fell **5.76 points** at the same time — because the trades
that used to be scratched at breakeven now run back through entry and stop out at
−1R. The two effects cancel almost exactly. The gap to breakeven closed by
**0.55 of a point** and the P/L moved £4.

**The breakeven move was expectancy-neutral. It converted variance, not edge.**
It was moving money between the win-rate column and the reward:risk column,
which is what a breakeven stop does when there is no edge to protect. Calling it
"the mechanism" was wrong — it was a *symptom* of the exit scheme being the only
thing under examination.

## 3. The number that ends the search: pre-cost P/L

| | Volume | Commission | Spread @ $0.15 | Total costs | **Pre-cost P/L** |
|---|---|---|---|---|---|
| Baseline `BankR0=33` | 16.6 lots | £116.94 | ~£184 | £301 (51%) | **−£285** |
| Test 1 `BankR0=0` | 16.8 lots | ~£119 | ~£186 | £305 (52%) | **−£277** |

Two **materially different exit schemes** — one banks a third at +1R and moves to
breakeven, the other holds the whole position to its stop or its target — produce
a pre-cost result within **£8 of each other**.

If the exit scheme can be changed that fundamentally and the pre-cost P/L doesn't
move, then the exit scheme is not what is losing the money. **The entries have no
directional edge.** You cannot manage your way out of a coin flip; you can only
choose which shape of losing curve you prefer.

## 4. Hypothesis 2 is now predictably insufficient

The plan called for `InpSellsEnabled = false` as the second and last test. Test 1
already tells us what it will find:

| | Baseline | Test 1 |
|---|---|---|
| Longs won | 41.15% (401) | 33.71% |
| Shorts won | 33.88% (242) | 31.03% |
| **Long/short gap** | **7.27 pts** | **2.68 pts** |

The 7-point long/short gap that made hypothesis 2 look interesting **collapsed to
2.68 points** the moment the exit scheme changed. A 7-point edge that survives one
input change as a 2.68-point edge was mostly an artifact of how the exits
interacted with an uptrending market, not a property of the direction.

And the arithmetic is unforgiving: longs-only under this exit scheme needs
**39.26%** and delivers **33.71%** — still short by **5.55 points**. Removing the
shorts removes 261 trades and roughly £250 of loss; it does not create an edge.

It remains one input and one run. Run it to close the plan out honestly. Do not
expect it to clear PF 1.0, and do not run a third variation on the strength of it
being "closer".

## 5. The record so far

| Test | Config | PF | WR | vs breakeven |
|---|---|---|---|---|
| 2022 M5 | baseline | 0.56 | 33.09% | −12.2 pts |
| 2026 M1 | baseline | 0.72 | 38.41% | −7.2 pts |
| 2026 M1 | `BankR0=0` | **0.73** | 32.65% | −6.6 pts |
| v10.x line ([`REALITY_CHECK.md`](REALITY_CHECK.md)) | look-ahead off | 0.75 | 31.8% | — |

Four results, two strategy lines, two regimes, two exit schemes. Every one lands
in **PF 0.56–0.75** with a win rate **6–12 points below breakeven**, and both 2026
runs decay with an **LR correlation of −0.94**.

That is not a tuning problem and it is not variance. The Track B entry signal does
not have an edge on XAUUSD M1.

## 6. What this does not mean

- It does not mean the engine is broken. F1/F3/F5/F10 are all visible working in
  both runs; the build executes its specification faithfully.
- It does not mean gold M1 is untradeable. It means *this breakout signal*,
  measured honestly, is not it.
- It does not mean the live +9.89% was fake. It was real money on a real demo —
  it was just leverage applied to a signal with no measurable edge, over a window
  the backtest shows as flat.

The next honest step is not another parameter. It is a different entry hypothesis,
tested this way — one run, stated prediction, recorded whatever it says.

Nothing here clears the bar for Phase 1. The record stands — including this.
