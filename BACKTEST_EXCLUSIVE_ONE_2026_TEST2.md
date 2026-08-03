# Test 2 — longs only (`InpSellsEnabled = false`)

**Run:** GMC EXCLUSIVE ONE v1.00 · XAUUSD **M1** · 2026.01.01–2026.07.27 · 56% real ticks · £1,000
**Inputs vs test 1:** `InpSellsEnabled true → false`. `InpBankR0Pct` stays at **0**, so this is
test 1's exit scheme with the short side switched off.

**Result: −£330.68 (−33.1%). PF 0.81. 360 trades. Hypothesis 2 failed its bar — and it is
the most informative run so far.**

The pre-registered bar in
[`BACKTEST_EXCLUSIVE_ONE_2026.md`](BACKTEST_EXCLUSIVE_ONE_2026.md) §8 was **PF > 1.0 on
2026 and 2022**. This is 0.81 on 2026, so 2022 is not required. It failed. But it moved
the numbers more than anything else tested, and the reason matters.

---

## 1. All three runs side by side

| | Baseline `BankR0=33`, both | Test 1 `BankR0=0`, both | **Test 2 `BankR0=0`, longs** |
|---|---|---|---|
| Net profit | −£585.23 | −£581.10 | **−£330.68** |
| Profit factor | 0.72 | 0.73 | **0.81** |
| Trades | 643 | 585 | 360 |
| Win rate | 38.41% | 32.65% | 34.72% |
| Average win / loss | 6.21 / 5.20 | 8.20 / 5.30 | **11.33 / 7.43** |
| Reward:risk | 1.19 | 1.55 | 1.52 |
| Breakeven WR needed | 45.57% | 39.26% | **39.62%** |
| **Gap to breakeven** | −7.16 pts | −6.61 pts | **−4.90 pts** |
| Expected payoff | −£0.91 | −£0.99 | −£0.92 |
| Max equity drawdown | 62.02% | — | **43.37%** |
| Max consecutive losses | 21 | 21 | **12** |
| Z-score | −6.15 | — | **−3.92** |
| LR correlation | −0.94 | −0.94 | **−0.94** |

Removing the shorts cut the loss almost in half, cut the drawdown by a third, and cut the
worst losing streak from 21 to 12. It did **not** change the per-trade expectancy —
−£0.92 against −£0.99. It removed 225 bad trades; it did not make the remaining ones good.

I predicted longs-only would land ~5.55 points short of breakeven. It landed **4.90 points**
short. Right conclusion, and this time the mechanism held.

## 2. The number that actually changed: pre-cost P/L

Commission is £99.23, implying ~14.2 round-turn lots. Spread is invisible on the report, so
it is bracketed:

| Assumed spread | Baseline pre-cost | Test 1 pre-cost | **Test 2 pre-cost** |
|---|---|---|---|
| $0.12 | −£320 | −£311 | **−£106** |
| $0.15 | −£283 | −£273 | **−£74** |
| $0.20 | −£221 | −£211 | **−£22** |

Per trade, before costs: **−£0.44 → −£0.47 → −£0.21.**

This is the first change that moved the pre-cost result. Test 1 established that the exit
scheme was not the problem — two very different exit schemes, same −£280 pre-cost. Test 2
establishes that **the two directions are not the same signal**: the long side is roughly
half as bad per trade, and the short side was actively destroying money.

At $0.20 spread the longs-only system is within £22 of breakeven before costs. That is not
an edge — it is a coin flip with a 78–94% cost load on top. But it is a materially different
object from the both-directions runs, and saying otherwise would misread the data.

## 3. The window was not a bull market

The obvious objection to a longs-only result is that it curve-fits an uptrend. Check the
prices in the order log:

`4354 (Jan) → 5380 (2 Mar, peak) → 4010 (1 Jul, trough) → ~4155 (22 Jul, last trade)`

Gold rose 23%, then fell 25%, and **finished the window below where it started**. A
longs-only configuration outperforming the two-sided one across a net-down window is not
the signature of a trend artifact. The short side genuinely underperformed on its own terms.

This does not clear it. One window is one window, and the 2022 confirmation was never run
because the 2026 bar was missed. But the standard objection does not apply cleanly here and
it would be dishonest to wave it through.

## 4. What would be needed to clear PF 1.0

At R:R 1.52, breakeven is 39.62%. The run delivered 34.72%. That is **18 more winning
trades out of 360** — converting 5% of the losers.

Cost reduction alone cannot do it: pre-cost P/L is negative at every spread assumption, so
even a zero-cost broker leaves the system losing. The gap has to come from the entry.

## 5. Execution finding: one trade survived the weekend and gapped through its stop

`2026.07.10 23:00` — long 0.04 @ 4108.55, SL 4107.01. Partial banked at 23:01 (+£5.99).
The runner then sat open across the weekend and closed `2026.07.13 01:02` at **4095.71**
against a stop at **4117.22** — the only swap charge in the run (−£0.81) and a −£19.20
loss, within pennies of the worst trade in the entire test (−£20.08).

The mechanism is in `GMC_EXCLUSIVE_ONE.mq5:920`:

```mql5
if(InpUseTimeStop && !gSt0 && prog <= 0.0 &&
   gEntryTime > 0 && TimeCurrent() - gEntryTime >= InpTimeStopMin * 60)
```

The 20-minute time stop only fires on a trade that is **flat or losing and has not banked**.
This trade had banked a partial and was in profit, so it was exempt — and with
`InpManageOnTick = false`, management only runs on a new M1 bar, of which there are none
while the market is shut. A winning runner therefore has **no time-based exit at all** and
can carry weekend gap risk with a stop that the market is free to jump.

This is a defect in the build, not in the strategy, and it is separate from everything above.
It is logged here and not fixed, because fixing it changes the build mid-evidence.

**Fix when the time comes:** a session-end flat rule — close or fully protect any open
position before the weekly close, independent of `gSt0` and `prog`.

## 6. Where the record now stands

| Test | Config | PF | WR vs breakeven |
|---|---|---|---|
| 2022 M5 | baseline | 0.56 | 33.09% vs 45.25% (−12.2) |
| 2026 M1 | baseline | 0.72 | 38.41% vs 45.57% (−7.2) |
| 2026 M1 | `BankR0=0` | 0.73 | 32.65% vs 39.26% (−6.6) |
| 2026 M1 | `BankR0=0`, longs only | **0.81** | 34.72% vs 39.62% (**−4.9**) |
| v10.x line ([`REALITY_CHECK.md`](REALITY_CHECK.md)) | look-ahead off | 0.75 | 31.8% |

Both pre-registered hypotheses have now been tested. **Neither cleared PF 1.0.** By the rule
written down before the tests were run, the conclusion is: **the Track B approach does not
have an edge on XAUUSD M1 at any configuration tested.** That stands, and it is recorded.

What the two tests bought is a sharper statement than "it doesn't work":

- The **exit scheme is not the problem** (test 1: two schemes, same pre-cost result).
- The **short side is the worse half** (test 2: removing it halves the loss and halves the
  per-trade pre-cost damage, in a window that finished down).
- The **long entry is close to a coin flip, not a losing bet** — pre-cost −£0.21/trade
  against a −£0.71/trade cost load.

That is a much better starting point for the next hypothesis than where this began. It is
not permission to keep tuning this one. **Do not run a third variation.** The next honest
step is a different long-side entry hypothesis, tested the same way: one input, one run,
stated prediction, recorded whatever it says — and confirmed on 2022 before it counts.

## 7. Do not put this on an account

PF 0.81 is a −33% year. Nothing here changes that. The forward test on the demo should not
be restarted on any of these three configurations.

Nothing here clears the bar for Phase 1. The record stands — including this.
