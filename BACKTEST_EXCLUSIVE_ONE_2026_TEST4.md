# Test 4 — `InpStrongMult = 0.5` (S3 sized like S0/S1 instead of double)

**Run:** GMC EXCLUSIVE ONE v1.00 · XAUUSD **M1** · 2026.01.01–2026.07.27 · 56% real ticks · £1,000
**Inputs vs test 3:** `InpStrongMult 1.0 → 0.5`. Everything else unchanged
(`InpEnableFVG = false`, `InpSellsEnabled = false`, `InpBankR0Pct = 0`).

**Result: +£28.15. PF 1.02. ~250 positions. First run in this lineage to clear PF 1.0, net of
real commission and slippage.**

This is the change proposed in [`DRAWDOWN_ANATOMY.md`](DRAWDOWN_ANATOMY.md): halve the risk
multiplier on setup grade S3, the grade shown to be the entire cause of the 29.4% drawdown in
test 3. The prediction was that this would help but not be enough. It was enough.

---

## 1. Prediction vs outcome

Stated in `DRAWDOWN_ANATOMY.md` §4 **before** the run:

| | Predicted | Actual | |
|---|---|---|---|
| Profit factor | 0.96–0.98 | **1.02** | **beat — cleared 1.0** |
| Net | −£40 to −£60 | **+£28.15** | **beat by ~£70–90** |
| Positions | ~251 | **~250** (derived, see §2) | landed |
| MT5 "Total Trades" | not predicted | **319 — identical to test 3** | confirms no trades were added or removed |

The position count and the identical MT5 "Total Trades" figure (319, exact match to test 3)
confirm the prediction's central claim: **this input changes nothing about which signals fire.**
Same entries, same exits by rule, only the lot size on S3 changed. That was the whole point of
choosing a sizing input over a filter — it isolates the sizing question from the signal-quality
question.

What was wrong was the *magnitude*. The prediction modeled the effect linearly — halve S3's
loss, everything else holds. The account did much better than that. See §3.

## 2. The result

| | Test 3 (S3 @ 1.0x) | **Test 4 (S3 @ 0.5x)** |
|---|---|---|
| Net profit | −£194.98 | **+£28.15** |
| Profit factor | 0.89 | **1.02** |
| Gross profit / loss | — | **£1,621.37 / −£1,593.22** |
| Positions (derived) | 251 | **~250** |
| MT5 "Total Trades" | 319 | **319** |
| Max balance drawdown | — | **£221.84 (18.82%)** |
| Max equity drawdown | 30.80% | **£249.85 (20.82%)** |
| Max consecutive losses | 10 | **10 (−£87.87)** |
| LR correlation | −0.85 | **−0.31** |
| Sharpe ratio | — | **1.21** |
| Expected payoff / trade | — | **£0.09** |
| Deal-level win rate | — | **37.62% (120/319)** |

Two figures matter more than the headline PF:

- **LR correlation moved from −0.85 to −0.31.** That statistic has been the signature of "a
  straight line down" since the very first backtest in this repo. At −0.31 the equity curve is
  no longer predominantly declining — it is closer to noisy-flat than to a trend.
- **Max drawdown fell from 30.80% to 20.82%.** Same trade sequence, same entries — the drawdown
  shrank by a third purely from not doubling risk on the setup grade that was losing.

Positions is *derived*, not read directly off the report: the report gives Total Deals (570,
including the opening balance record) and MT5 "Total Trades" (319, which counts each partial
close as its own trade — the F3 defect this build's own logic corrects for internally). Opening
deals = 570 − 1 (balance) − 319 (closing deals) = **250**. This is arithmetic, not a re-run of
the EA's own position aggregation, so treat it as a strong estimate rather than an exact figure
matched to test 3's 251 — the one-position difference is plausibly a risk-ceiling sizing edge
case, since equity path (and therefore lot sizing) now differs from test 3.

*Note:* the 37.62% win rate above is **deal-level** (319 basis, partials counted separately),
not the **per-position** win rate reported for tests 1–3 (which used a different aggregation).
The two are not directly comparable, and I have not reconstructed a per-position figure for this
run — that would need the EA's own CSV log (`GMC1_<login>_XAUUSD.csv`), which wasn't part of
this report. If it matters for the next step, that log is the thing to send.

## 3. Why the prediction undershot: compounding, not just arithmetic

`DRAWDOWN_ANATOMY.md` predicted the effect by halving S3's dollar loss in isolation:
−£309 → ≈−£155, net ≈−£40 to −£60. That treats every trade's risk as a fixed amount. It isn't —
`riskUsd = eq * riskPct / 100.0` at `LookForEntry` (`GMC_EXCLUSIVE_ONE.mq5:1313`) sizes every
position off **live equity**, not a static balance.

That makes the effect multiplicative, not additive. Avoiding an S3 loss early in the run doesn't
just remove that loss — it leaves more equity for every trade that follows, including the
winners, which now compound off a healthier base. The reverse also held in test 3: doubling risk
into a losing grade didn't just lose more on those trades, it silently under-sized every
subsequent trade by starving the account of equity. A linear estimate cannot see this; the
equity curve can, and did.

This is a real effect, but note what it does **not** mean: it doesn't mean the edge is bigger
than it looks. It means position sizing on a shared-equity book couples every trade to every
other trade's outcome, so a change this early in a 7-month run has leverage disproportionate to
its size. That cuts both ways.

## 4. What this does and doesn't prove

**Does:**
- Confirms the S3 mechanism from `DRAWDOWN_ANATOMY.md` — the setup grade the code scores as
  "strongest" was costing the account roughly double what correcting its sizing gives back.
- First run in this entire lineage — GMC EXCLUSIVE ONE or the earlier Track B line — to clear
  PF 1.0 with real commission and realistic fills included.

**Does not:**
- **PF 1.02 is razor-thin.** Expected payoff is £0.09 per trade. With ~250 positions and average
  win/loss sizes in the £8–14 range, this is well within the range that a modest change in
  execution assumptions (spread, slippage, a different tick sample) could erase. No proper
  significance test has been run against this figure — it should not be read as "the edge is
  real" without one.
- **The config was chosen after watching S3 lose in this exact window.** Halving S3's multiplier
  is a sizing correction, not a new signal claim, and it deletes no trades — both of which make
  it less prone to curve-fitting than picking trades out after the fact. But it is still a
  parameter chosen by looking at this data, on this data. That is the definition of in-sample.
- Per the standing rule in `BACKTEST_EXCLUSIVE_ONE_2022.md` §7: **no config goes near a live
  account without clearing PF 1.0 on a second regime it wasn't tuned on.** This result clears
  the first bar. It has not touched the second.

## 5. Next step

**Test 5 — same config, out-of-sample.** Re-run this exact build (`InpEnableFVG = false`,
`InpSellsEnabled = false`, `InpBankR0Pct = 0`, `InpStrongMult = 0.5`) on 2022 XAUUSD M1 — the
same window `BACKTEST_EXCLUSIVE_ONE_2022.md` used for the original engine sanity check, and a
different volatility regime than 2026 by every measure taken so far.

**Prediction, before the run:** the 2022 run at full risk multiplier already came back at PF
0.56 with no positive edge visible anywhere in the breakdown — a much worse starting point than
2026's test 3 (PF 0.89). Halving S3's risk there should reduce the loss the same way it did
here, but there is no basis yet to predict it clears 1.0; 2022's problem looked structural
(§5–6 of that doc), not concentrated in one grade the way 2026's was. If it doesn't clear 1.0 on
2022, that's the answer: the S3 fix is a 2026-specific correction, not a general one, and the
system does not clear Phase 1 on this config.

Nothing here clears the bar for Phase 1 on its own. The record stands — including this.
