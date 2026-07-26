# GMC — the one strategy (frozen & validated)

**This is the single, canonical strategy. Current version: `GMC v1.2`.**
File: `GMC_v1.2.mq5`. Everything else in this repo is prior research and lives
in `archive/` (kept for the record, not for use).

## v1.2 (current) — score-tiered risk (adaptive layer 2, IN TEST)
Position size now scales with entry-signal strength: score 6/6 confluence
risks the full 1.0%, cascade entries at score 5 risk 0.75x, minimum-evidence
score-4 cascades risk 0.50x. Anti-martingale by construction — weaker
evidence always means a smaller bet, never a bigger one. Same trades, same
entries/exits as v1.1; only sizing changes. Set `Use_Tiered_Risk = false`
to reproduce the exact v1.1/baseline behaviour for A/B testing.
Status: pending A/B vs the verified baseline (must beat PF 1.24 / 17.2% DD).

## v1.1 (current) — adds the spread filter
Layer 1 of the adaptive roadmap: skip any new entry while the live XAUUSD
spread exceeds `Max_Spread_Points` (default 50 points = $0.50). Protects
against rollover/news/thin-liquidity fills. Set `Use_Spread_Filter = false`
to reproduce the exact frozen v1.0 baseline for A/B testing. All v1.0
validated numbers below were produced WITHOUT the spread filter.

Adaptive roadmap (one layer at a time, each must beat the frozen baseline
out-of-sample or it comes out):
1. Spread filter — DONE (v1.1, A/B validated: zero backtest impact, kept as live insurance)
2. Score-tiered risk — BUILT (v1.2, pending A/B validation)
3. ATR-percentile adaptive SL/TP
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
