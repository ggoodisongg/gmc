# ⚠️ Reality check — the backtests carried look-ahead bias

**Date:** 2026-07-20 · **Status: do NOT trade or publish any version in this repo.**

This note exists because the whole point of Phase 0 is *"proof before promises."* An honest
test broke the promise, so it goes on the record.

## What happened

Every backtest in this repo was run with `calc_on_every_tick=true` and
`calc_on_order_fills=true`, and every trade used a same-bar take-profit (`limit`)
**and** stop (`stop`) on one `strategy.exit`. TradingView flagged this directly:

> *"Caution! This strategy may use look-ahead bias, which can lead to unrealistically profitable results."*

On historical bars the tester could not tell whether the target or the stop was hit
**first** inside a bar, and it credited the **target**. That single assumption produced
the entire apparent edge.

## Inflated vs. realistic (same config: cost-cut floor 5.0, last 365 days, £5k start)

| Metric | Look-ahead ON (reported earlier) | Look-ahead OFF (truth) |
|---|---|---|
| Win rate | 49.7% | **31.8%** |
| Profit factor | 2.30 | **0.75** |
| Net P&L | +£10,375 | **−£1,744** |
| Return on £5k | +207% | **−35%** |
| Final balance | £15,375 | **£3,256** |

Realistic fills were produced with `calc_on_every_tick=false`,
`calc_on_order_fills=false`, and the Strategy Tester **Bar Magnifier** on.

## Volatility-floor sweep with look-ahead OFF — flat and negative

| Floor | Trades | Win% | Profit Factor | Net |
|---|---|---|---|---|
| lower | 1,725 | 31.4% | 0.74 | −£1,896 |
| mid | 1,693 | 31.5% | 0.74 | −£1,856 |
| 5.0 | 1,567 | 31.8% | 0.75 | −£1,744 |

The floor — the lever that "worked" with the bias on — changes nothing once it is off.

## Conclusion

**As built, this strategy has no real edge on XAUUSD 15m.** At a genuine ~31% win rate the
average winner (~1.7× the average loser) is not large enough to be profitable; PF sits at
~0.75 across every configuration.

**All earlier "validated" figures in this repo are therefore void**, including:
- v10.52 frozen "PF 2.33 / 51% win"
- the "20-year PF 1.90" result
- the cost-cut "PF 2.27 / floor 5.0"

They were all measured under look-ahead bias and do not survive a realistic-fill test.

## What must happen before any performance is claimed or any money is risked

1. A genuine edge must be demonstrated **with look-ahead off + Bar Magnifier on** — no
   version in this repo currently clears PF 1.0 under those conditions.
2. That edge must then hold on a **live forward test** against real broker spread + slippage.

Until both are true, nothing here is a signal service, a performance claim, or tradeable.
The record stands — including this.
