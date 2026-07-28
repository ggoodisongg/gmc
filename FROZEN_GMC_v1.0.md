# GMC — the one strategy (frozen & validated)

**This is the single, canonical strategy. Current version: `GMC v1.5`.**
File: `GMC_v1.5.mq5`. Everything else in this repo is prior research and lives
in `archive/` (kept for the record, not for use).

## v1.5 (current) — frequency boost: TESTED and REJECTED (switch stays OFF)
**Canonical setting: Use_Freq_Boost = false** (exact frozen gates).
The code stays in the file, switched off. Rejected on profit-per-unit-
of-drawdown: see the risk-normalised table below. More trades, less
efficiency. The route to more trades is more SYMBOLS, not looser gates.

Owner asked for more than 2-3 trades/week. Since GMC is a cascade engine
(v1.4 finding), the frequency levers are the cascade gates. Behind one
switch (`Use_Freq_Boost`): cascade min score 4 -> 3, volume spike
1.8x -> 1.4x, momentum trigger 8 -> 6 pips, both cooldowns 3 bars -> 1.
`Use_Freq_Boost = false` reproduces the exact baseline. A/B protocol:
same build, identical settings (M5, GBP 5,000, commissions on), run
switch OFF (control) then ON. Pass bar: meaningfully more trades AND
net profit >= control with DD not materially worse. HONEST WARNING
recorded up front: relaxed gates admit trades the frozen filters
rejected for a reason — expect lower per-trade quality; if profit
degrades, the levers get dialed back or the layer comes out.

A/B RESULT (M5, 2022.01.01-2026.07.27, GBP 5,000, commissions on,
7% tick quality, both runs same build):
| | OFF (control) | ON |
|---|---|---|
| Trades | 557 | 1,332 |
| Net | +£1,515.92 | +£2,598.15 |
| PF | 1.14 | 1.10 |
| Max DD | 19.18% | 38.21% |
| Sharpe | 3.35 | 2.54 |
| Worst streak | 15 | 17 |

Verdict: MIXED. Passes the trade-count and profit tests (2.4x trades,
+71% net) but fails the drawdown test decisively (38.21% vs the ~22%
ceiling set before the run). PF and Sharpe both fell, so the extra
trades are individually lower quality — the profit came from volume,
not from new edge. The boost adds leverage, not alpha.

DECIDING TEST (pending): boost ON with Risk_Percent = 0.5 instead of
1.0. Drawdown scales roughly linearly with risk, so this should bring
DD back to ~19-20% and make the comparison risk-matched. If profit at
matched drawdown still beats the control's £1,516, the layer is a
genuine improvement and stays; if not, it was borrowing from risk
tolerance and the frozen gates win.

THIRD DATA POINT (same build, boost OFF, Risk_Percent = 1.5):
+£2,190.12 / PF 1.13 / 28.30% balance DD (28.94% equity) / 557 trades
/ Sharpe 3.01 / worst streak 15 (-£964.41) / commissions -£395.62.
Versus the 1% control (+£1,515.92 / 19.18% DD) that is +44.5% profit
for +47.5% drawdown with PF flat (1.14 -> 1.13) — clean confirmation
that profit and drawdown both scale near-linearly with Risk_Percent.
Raising risk is a dial, not an edge.

RISK-NORMALISED READ (profit per 1% of max drawdown):
- frozen gates @ 1.0% risk: £1,516 / 19.18% = ~£79
- frozen gates @ 1.5% risk: £2,190 / 28.30% = ~£77
- freq boost   @ 1.0% risk: £2,598 / 38.21% = ~£68
The frozen gates are ~14% more drawdown-efficient than the boost at
every risk level tested. On the evidence in hand the boost buys trade
count and gross profit but no risk-adjusted improvement. The 0.5%-risk
boost run is still the cleanest confirmation, but the layer is already
failing on this measure.

## v1.4 (current) — signal-type sizing: TESTED, NO EFFECT (switch stays OFF)
Cascade entries keep full 1% risk; pure 6/6 confluence entries trade at
0.5x. First fully clean A/B: SAME build run twice on identical settings
(M5, 2022.01.01-2026.07.27, GBP 5,000, commissions on both). Result:
OFF +£1,515.92 / PF 1.14 / 19.18% DD vs ON +£1,516.32 / PF 1.15 /
19.22% DD — a 40p difference over 4.5 years. Pure noise; fails "beat
the control or come out". **Canonical setting: Use_Type_Sizing = false.**

KEY FINDING: trade-list comparison shows only a handful of trades ever
changed size — pure 6/6 confluence entries (score 6 without the cascade
condition also firing) are extremely rare. Nearly every entry GMC takes
also satisfies the cascade condition, so GMC is in practice a CASCADE
ENGINE. Any future layer keyed on confluence-vs-cascade type is dead on
arrival: there is nothing to re-weight. This also finalises the v1.2
finding.

BONUS: the control run is the first true commissions-on baseline for the
extended window: +£1,516 / PF 1.14 / 19.18% DD / 557 trades / Sharpe
3.35 (commissions ~£255 over the test, 7% tick quality). Use it as the
comparator for any future A/B run under identical conditions.

## v1.3 (current) — ATR-percentile adaptive SL: TESTED and REJECTED (switch stays OFF)
Ranks the entry bar's ATR against the last 500 M5 ATR values. Quiet market
(<=30th percentile) -> SL 1.6x ATR; volatile (>=70th) -> 2.6x ATR; else the
frozen 2.0x. Cash risk stays 1% (lots re-size to the stop); all targets are
in R so they scale with the stop. `Use_Adaptive_SL = false` reproduces the
exact baseline. `Use_Tiered_Risk` default is now false (rejected layer).

A/B result (XAUUSD M5, 2022.01.01-2026.07.27, GBP 5,000, 7% real-tick
quality on both runs): adaptive ON +£1,224 / PF 1.12 / 19.06% DD / 555
trades vs matched-conditions baseline OFF +£1,707 / PF 1.17 / 17.94% DD /
557 trades. Caveat noted honestly: the ON run charged commissions
(-£246.06) while the OFF control accidentally ran in "profit in pips"
mode with zero commissions — but even crediting the full £246 back
(~£1,470), adaptive SL still trails on profit, PF and drawdown, so the
rejection stands on every metric. Fails "beat the baseline or come out".
**Canonical setting: Use_Adaptive_SL = false** (exact baseline behaviour).
The code stays in the file, switched off. Both runs were at 7% tick
quality (comparable to each other, not to the 99% canonical baseline);
re-download tick history before future A/Bs.

## v1.2 (current) — score-tiered risk: TESTED and REJECTED (switch stays OFF)
A/B result (2022-2026, XAUUSD, near-identical trade list to baseline):
tiered ON gave +£599 / PF 1.09 / 12.4% DD vs baseline +£2,473 / PF 1.24 /
17.2% DD. Drawdown improved but profit collapsed ~75% — fails the rule
"beat the baseline or come out". **Canonical setting: Use_Tiered_Risk = false**
(exact v1.1 behaviour). The code stays in the file, switched off.

KEY FINDING from the failure: down-weighting score-4/5 entries gutted the
profit, which proves the cascade (momentum) entries at score 4-5 are the
strategy's most profitable subset — the "perfect 6/6" confluence entries
are the weaker ones. Confluence score is NOT a good per-trade quality
proxy. Any future sizing layer should key on signal TYPE (cascade vs
confluence), tested with the same A/B discipline.

Matched-conditions control run (tiered OFF, same H1 chart + extended dates
2022.01.01-2026.07.27 as the ON run): +£1,553 / PF 1.15 / 19.2% DD / 558
trades vs ON +£599 / PF 1.09 — rejection confirmed apples-to-apples (~3x
profit from switching it off). Note: control differs from the canonical
baseline (PF 1.24 / +£2,473 to 2026.07.01) mainly because the extra July
2026 weeks lost ~£425 (worst losing stretch in the test, incl. 15 consec
losses). Canonical baseline window stays 2022.01.01-2026.07.01 on an M5
chart for all future A/Bs.

## v1.1 (current) — adds the spread filter
Layer 1 of the adaptive roadmap: skip any new entry while the live XAUUSD
spread exceeds `Max_Spread_Points` (default 50 points = $0.50). Protects
against rollover/news/thin-liquidity fills. Set `Use_Spread_Filter = false`
to reproduce the exact frozen v1.0 baseline for A/B testing. All v1.0
validated numbers below were produced WITHOUT the spread filter.

Adaptive roadmap (one layer at a time, each must beat the frozen baseline
out-of-sample or it comes out):
1. Spread filter — DONE (v1.1, A/B validated: zero backtest impact, kept as live insurance)
2. Score-tiered risk — TESTED & REJECTED (v1.2 A/B: PF 1.09 vs 1.24 — switch stays OFF)
3. ATR-percentile adaptive SL/TP — TESTED & REJECTED (v1.3 A/B: PF 1.12 vs 1.17 matched control — switch stays OFF)
4. Signal-type sizing (cascade full risk / confluence reduced) — TESTED, NO EFFECT (v1.4 clean A/B: 40p difference — switch stays OFF; pure-confluence entries are near-nonexistent)
5. Frequency boost (relaxed cascade gates) — TESTED & REJECTED (v1.5 A/B: 2.4x trades but £68 vs £79 profit per 1% DD — switch stays OFF)
6. Multi-symbol expansion — the honest route to more trades: run the
   proven frozen gates on additional instruments (silver, EURUSD, an
   index), each validated separately with its own A/B. Four symbols at
   2-3 trades/week each = 8-12 trades/week with no quality dilution.
7. Regime-aware exits + anti-martingale risk throttle

Confluence entry (MA50/RSI/volume/rejection-wick score 6/6 + H4/H1 trend gates
+ session + cascade) with a risk-managed engine (risk-% sizing, ATR stop with
pip caps, staged exits: break-even -> partial -> trailing runner, daily-loss
halt, consecutive-loss cooldown). Instrument: XAUUSD, M5.

## Validated results (XAUUSD M5, real ticks, £5,000)
**Verified baseline (2025-07, input-audited via full tester reports):**
| Window | Profit Factor | Net | Max DD | Trades | Sharpe |
|---|---|---|---|---|---|
| 2022.01 - 2026.07 | 1.24 | +£2,473 (+49%) | 17.2% | 545 | 2.50 |

A/B result: spread filter ON@50 vs OFF produced IDENTICAL results (545
identical trades) — in-session historical spreads never exceeded 50 points.
Filter kept ON as live insurance (news spikes / feed glitches); it costs
nothing in backtest.

Earlier recorded numbers (PF 1.40 / 11.65% DD 4yr; PF 1.97 recent; PF 1.10
11yr) predate report-verified inputs and could NOT be reproduced once the
tester's cached-input drift was discovered and fixed. They are retired.
The table above is the only baseline any new layer must beat.

## Frozen settings (baked into GMC_v1.0.mq5 as defaults)
- Risk_Percent 1.0 | Signal M5 | H4 + H1 gates on
- Min_Score 6 | SL_ATR_Multiplier 2.0
- TP1_R 1.8 | Partial_Close_Pct 35 | TP_Final_R 5.5
- Trail_Start_R 2.5 | Trail_R_Step 0.6
- Session London 0700-1600 / NY 1300-2100 GMT
- Daily max loss 7% | max 4 consecutive losses | 30-min cooldown

## Status
Backtest-validated. NOT yet proven live. Next and only step: forward-test on
the IC Markets demo (M5 XAUUSD, Algo Trading on). No further tuning on history.
