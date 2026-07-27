# GMC — the one strategy (frozen & validated)

**This is the single, canonical strategy. Current version: `GMC v1.3`.**
File: `GMC_v1.3.mq5`. Everything else in this repo is prior research and lives
in `archive/` (kept for the record, not for use).

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
4. Regime-aware exits + anti-martingale risk throttle

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
