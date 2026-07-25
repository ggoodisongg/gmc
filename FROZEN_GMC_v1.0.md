# GMC v1.0 — the one strategy (frozen & validated)

**This is the single, canonical strategy. One name, one number: `GMC v1.0`.**
File: `GMC_v1.0.mq5`. Everything else in this repo is prior research and lives
in `archive/` (kept for the record, not for use).

Confluence entry (MA50/RSI/volume/rejection-wick score 6/6 + H4/H1 trend gates
+ session + cascade) with a risk-managed engine (risk-% sizing, ATR stop with
pip caps, staged exits: break-even -> partial -> trailing runner, daily-loss
halt, consecutive-loss cooldown). Instrument: XAUUSD, M5.

## Validated results (XAUUSD M5, real ticks, £5,000)
| Window | Profit Factor | Net | Max DD | Recovery | Data quality |
|---|---|---|---|---|---|
| Recent (2025-26) | 1.97 | +£1,633 | 5.8% | 3.83 | 99-100% |
| 4 years (2022-26) | 1.40 | +£2,905 (+58%) | 11.65% | 4.20 | 99% |
| ~11 years | 1.10 | +£2,062 (+41%) | 22.9% | 1.52 | 82% (gappy — least reliable) |

Trend-leaning: strongest in trending gold (~2.0), solidly positive over 4 years,
never turns into a loser even over a decade. Stable across a range of settings
(SL 1.5-2.0 all land ~1.4 / ~1.97) — a sign of a real edge, not curve-fit.

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
