# ❄️ FROZEN — Track B v10.52_MACRO_STRIKE

**Frozen:** 2026-07-20 · **Instrument:** OANDA XAUUSD, 15m · **File:** `GMC_TrackB_v10.52_MACRO_STRIKE.pine`

This is the current **validated, frozen** configuration. Per the versioned-lineage
rule, it is not edited in place — new work branches from here as **v10.53**.

## Validated performance
Confirmed across a ~1,000-trade sample, with 88- and 357-trade runs matching.

| Metric | Value |
|---|---|
| Win rate | **51.5%** |
| Profit factor | **2.33** |
| Expectancy / trade | **£2.67** |
| Net PnL (993-trade sample) | **+£2,650** |
| Best exit cohort | Partial (Tier-1) exits — 83–92% win |

## Required inputs (the state that was validated)
- ✅ **Enter only on CLOSED candles** — the change that lifted win% from 40% → 51%
- ✅ **Pyramid into WINNERS only** — never averages into a loser (risk hygiene)
- ✅ **Break-even lock after Tier-1 partial** — runners can no longer round-trip to a loss
- ✅ **Confirmed-candle loss cut** — cuts losers only on a closed adverse candle
- **Cooldown = 1** — LOCKED. Raising it holds losers into reversals and destroys the edge (tested: PF 2.44 → 0.79).
- **Bars-before-cut = 4** — tested slightly better than 8.

## How it was earned (lineage)
| Version | Change | Result |
|---|---|---|
| v10.49 | Baseline — dead entry throttle, non-monotonic trail | PF ~1.7, 41% win |
| v10.50 | Break-even lock, monotonic trail, churn guards | PF ~2.0 |
| v10.51 | **Enter-on-closed-candles gate** | Win 40%→51%, PF 2.44 |
| **v10.52** | Pyramid-into-winners (risk hygiene) | PF 2.33 — perf-neutral vs 10.51, adopted for safer live behaviour |

## Note
Frozen on backtest validation. This is not a live-forward-tested record and is not a
performance claim — it is the validated development baseline from which the next
iteration branches. Markets involve risk.
