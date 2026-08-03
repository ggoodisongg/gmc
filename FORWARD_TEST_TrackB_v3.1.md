# Forward test — Track B v3.1 (MQL5), demo account 52961700

**Broker:** Raw Trading Ltd (IC Markets) · **Symbol:** XAUUSD M1 · **Start capital:** $1,000
**Report window:** 2026.07.01 → 2026.07.27 22:42 · **Recorded:** 2026-07-27

This is Phase 0 evidence. It goes on the record whatever it says.

---

## 1. Headline result

| | |
|---|---|
| Balance / Equity | **$1,098.88** |
| Net profit | **+$98.88 (+9.89%)** |
| Gross profit / gross loss | +$425.70 / −$310.84 |
| Commissions | −$15.98 |
| Profit factor | **1.37** (1.30 including commission) |
| Sharpe ratio (per trade) | **0.13** |
| Recovery factor | **0.48** |
| Max equity drawdown | **15.96%** (peak $1,287 → trough $1,082, −$205) |
| Trades per week | 21 |
| Average hold time | 12 minutes |

**+9.89% is not the result. The shape is the result.**

## 2. The equity curve, day by day

Reconstructed from the report's growth chart. Balance is $0 until ~15 July, so the
smooth ramp the chart draws before that is a rendering artifact, not trading.

| Date | Growth | Equity | Change |
|---|---|---|---|
| Wed 15 Jul | 11.07% | $1,110 | — |
| Thu 16 Jul | 18.11% | $1,181 | **+7.04 pp** |
| Fri 17 Jul | **28.73%** | **$1,287** | **+10.61 pp** ← peak |
| Sat–Sun 18–19 | 28.73% | $1,287 | market closed |
| Mon 20 Jul | 22.19% | $1,222 | −6.54 pp |
| Tue 21 Jul | 20.46% | $1,205 | −1.73 pp |
| Wed 22 Jul | 12.69% | $1,127 | −7.77 pp |
| Thu 23 Jul | 12.69% | $1,127 | **flat — no trading** |
| Fri 24 Jul | 8.28% | $1,083 | −4.41 pp |
| Sat–Sun 25–26 | 8.22% | $1,082 | market closed |
| Mon 27 Jul | 9.89% | $1,099 | +1.67 pp |

Three facts follow:

1. **65% of peak profit has been given back.** $287 made, $205 lost.
2. **Two days are the entire account.** 16–17 July contributed +17.65 pp. Everything
   since 15 July's close nets to **−1.18 pp**. Remove that two-day burst and the
   forward test is negative.
3. **A ~2-day mid-week gap on 22–24 July is unexplained.** At 21 trades/week the
   system should have taken ~7 trades in that span and took none. Daily-loss halt
   only lasts one session, so this was something else — terminal down, EA removed,
   or a gate state that never cleared. There is no logging to say which. That is
   itself a finding.

The summary block's "Max. Drawdown 4.41%" gauge is a different measure and should
not be read as comfort. The number that reconciles with the equity curve is 15.96%.

## 3. Is the edge real? No — not yet, and not close.

MT5 reports a **per-trade Sharpe of 0.13**. The t-statistic on net profit is
`t = 0.13 × √N`. The exact trade count doesn't matter:

| Trades so far | t-statistic | Significant? |
|---|---|---|
| 39 | 0.84 | no |
| 60 | 1.04 | no |
| 81 | 1.21 | no |

The 95% one-sided threshold is 1.645. **This result is statistically
indistinguishable from a system with no edge at all.**

At 0.13 per trade and 21 trades/week:

| Confidence | Trades needed | Time at current rate |
|---|---|---|
| 90% | ~97 | ~5 weeks |
| 95% | ~160 | ~8 weeks |
| 99% | ~320 | ~15 weeks |

**Nothing about this run should change a decision until roughly 160 trades.** The
forward test is doing its job; it just hasn't finished.

## 4. Cost drag

Total round-turn volume implied by commission (~$3.50/lot/side): **~2.3 lots**,
so average position size ~0.03–0.06 lots.

| Cost | Amount | Share of pre-cost edge |
|---|---|---|
| Commission (visible on the report) | $15.98 | ~10% |
| Spread (invisible — already inside gross P/L) | ~$27–57 | 19–33% |
| **Total friction** | **~$43–73** | **~30–43%** |

The pre-cost edge is roughly $145–170; between a third and a half of it goes to the
broker. Spread is 2–4× commission and is the cost nobody sees on this report. The
spread ceiling is currently set at 25 points ($0.25) — roughly double a normal raw
XAUUSD spread. On trades taken at that ceiling, spread alone costs about half the
per-trade expectancy.

**Action:** tighten the spread gate toward 15 points and log every signal the gate
rejects, so the cost of the gate is measurable instead of assumed.

## 5. Engineering defects found in the running build

Ranked by what can actually hurt the account. Signal logic is deliberately not
described here; these are all execution and accounting issues.

### P0 — Positions are opened with no stop loss

Entry orders are submitted with `sl = 0`. The protective stop is attached by the
management routine, which is gated behind a new-M1-bar check — so a fill at second 5
of a bar sits **unprotected for ~55 seconds**, and a terminal or VPS disconnect after
a fill leaves the position unprotected indefinitely. On M1 gold a one-minute spike of
$5–10 is not rare; at 0.06 lots that is $30–60 against an intended risk of ~$17.

**Fix:** compute the stop at order-submission time and pass it into the order request.
The stop level is already known — it is derived from ATR before the order is placed.
This also removes the restart problem in P1.

### P1 — All trade state is lost on restart, and the fallback is wrong

Stop distance, milestone flags, peak and entry time live only in memory. After a
recompile, terminal restart or VPS reboot with a position open, the routine falls
back to the **minimum** stop distance ($1.00). It then writes that as a real broker
stop — potentially tightening a $3 stop to $1 mid-trade — and every R-milestone
afterwards is scaled wrong by up to 4×.

**Fix:** persist per-trade state (global variables or the position comment), or
reconstruct the stop distance from the broker-side stop when one already exists.

### P2 — Kelly sizing is fed corrupted trade statistics

Trade history is counted by *deal*, and partial closes are deals. A winner that banks
at +1R, again at TP1, and then runs produces **three** positive records; a loser
produces **one** negative record. So the win rate in the Kelly window is structurally
inflated and the average win is understated. The Kelly fraction being computed is not
the Kelly fraction of anything.

The same miscount drives the consecutive-loss cooldown: it counts losing *deals*, not
losing *trades*, so the cooldown fires on the wrong condition. The two code paths are
also inconsistent — one includes commission and swap in trade P/L, the other doesn't.

**Fix:** aggregate deals by position ID and treat one position as one trade. Until
that lands, **turn Kelly off and run a flat risk percentage** — a broken adaptive
sizer is worse than a fixed one.

### P3 — Risk per trade swings 4:1 with volatility, in the wrong direction

The lot cap (0.10 lots per $1,000) caps *size*, not *risk*. With the stop clamped to
a $1–$4 band, a capped trade risks 1.0% when the stop is at the floor and 4.0% when
it is at the ceiling — i.e. **maximum risk is taken in the hottest markets**. The 4%
risk ceiling is therefore soft, and the 3% base risk on a strategy whose own
validation shows a 32.71% drawdown is aggressive for a live account.

### P4 — Position lookup is by symbol, not by magic number

The management routine selects the position by symbol and then checks the magic
number. On a **hedging** account (common on IC Markets) another position on XAUUSD
can be returned instead, and the routine silently returns — leaving this EA's own
position with no stop management, no partials and no time stop, for as long as the
other position is open. Select by the ticket already found rather than by symbol.

### P5 — No error handling and no logging, anywhere

Every trade-server return code is discarded except the pending-order result. A
rejected stop modification (invalid stops, too close to market) fails silently and
leaves the position unprotected with nothing in the journal. Three weeks in, there is
no trail to explain the 22–24 July gap. **This is why the gap is unexplainable.**

### P6 — Unhandled index-error path can fabricate a signal

The highest/lowest-bar lookups return −1 on a history error; the code feeds that
straight into a price lookup, which returns 0.0, and the breakout comparison is then
true for any price. Rare, but it generates a trade out of nothing. Guard the index.

### P7 — History is rescanned twice per bar

The full deal history is re-selected and looped twice every M1 bar. Negligible at 40
trades; at several thousand deals it is ~10,000 iterations per minute on the tick
thread. Cache it.

## 6. Backtest vs live — the population is not the same

Two things break the link between the Pine v3.1 validation figures quoted in the
build header (PF 1.148 / WR 53.15% / DD 32.71%) and this live record:

1. **Trade rate.** The validation implies ~31 trades/week; live is running 21/week —
   about two-thirds. The live system uses stop-entry orders with a 2-bar expiry, so
   any signal where price doesn't immediately continue is simply never filled. That
   is a *selection effect*: the trades that fill are the ones that already moved in
   the right direction, which plausibly explains live PF 1.37 > backtest PF 1.148.
   It also means the live system is trading a different, smaller population than the
   one that was validated. The backtest numbers do not describe this system.

2. **Look-ahead.** [`REALITY_CHECK.md`](REALITY_CHECK.md) (2026-07-20) voided every
   backtest figure in this repo for carrying look-ahead bias — same-bar target and
   stop on one exit call, with the tester crediting the target. v3.1 has exactly that
   shape: a partial target plus a stop. Until the v3.1 Pine is re-run with look-ahead
   off and Bar Magnifier on, **the header's PF 1.148 is subject to the same
   correction** and should not be treated as validated.

Also on the record: the build header carries `*** WARNING: UNTESTED MQL5 PORT ***` and
instructs a Strategy Tester run before demo use. That step was skipped. This live run
is the first test the port has had.

## 7. What happens next

1. **Fix P0 before the next session.** It is the one defect that can produce a loss
   the model has no concept of.
2. **Turn Kelly off** until P2 is fixed. Flat risk, and drop the base from 3%.
3. **Add logging** — every signal, every gate rejection, every fill and no-fill, every
   management action, to CSV. Without it the next anomaly is as unexplainable as the
   22–24 July gap.
4. **Keep running.** Do not stop, do not re-tune, do not restart the counter on the
   strength of a two-day burst. The next decision point is ~160 trades, roughly
   8 weeks out.
5. **Re-run the v3.1 Pine backtest with look-ahead off** and put the corrected figures
   next to this record.

Nothing here clears the bar for Phase 1. The record stands — including this.
