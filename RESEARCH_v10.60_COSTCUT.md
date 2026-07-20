# 🔬 Research branch — v10.60_COSTCUT

**Goal:** lift the 20-year **net** profit factor (1.90) without touching the gross edge, by cutting the commission drag. Branched from frozen v10.52; **nothing here is adopted until a sweep beats 1.90 net PF on the 20-year sample with the gross edge intact.**

## The finding that motivates this (20-year log, 86,343 trades)

Hour-of-day and weekday filters are dead ends (only 2 negative hours; cutting them = +£131). The signal is **trade duration**:

| Duration | Trades | Net PnL | Win% |
|---|---|---|---|
| 0 bars | 15,194 | **−£2,928** | 3% |
| 1–2 bars | 32,509 | **+£90** | 46% |
| 3–5 bars | 23,518 | +£26,474 | 65% |
| 6–15 bars | 8,633 | +£9,338 | 49% |
| 16+ bars | 6,489 | +£13,178 | 80% |

**55% of all trades (0–2 bars) net ≈ −£2,838** — they only pay commission. **All £48,990 of profit comes from 3+ bar trades.** Cutting the short-lived churn should roughly halve commission (£51k → ~£23k) while keeping the profit engine.

## Levers in this file (all default OFF → reproduces frozen v10.52)

1. **Min Volatility Floor** (`Min_ATR_Points`, existing) — low-vol entries flip fastest. Sweep **1.5 → 2.5 → 3.5 → 5.0**.
2. **Min Candle Body** (`Use_Body_Filter` + `Min_Body_ATR`, new) — weak/doji entries are the churn. Sweep body **0.10 → 0.20 → 0.30 ATR**.

Enable **one at a time** (the discipline that saved us from the cooldown mistake).

## Test plan (run each on the 20-year XAUUSD 15m sample)

| Run | Change | Watch |
|---|---|---|
| Baseline | all cost-cut OFF | must reproduce PF 1.90, +£46k (sanity) |
| A1–A3 | Min_ATR_Points = 2.5 / 3.5 / 5.0 | trade count ↓, **net PF**, gross win kept? |
| B1–B3 | Body filter ON, 0.10 / 0.20 / 0.30 | same |
| Best combo | winner of A + winner of B | net PF vs 1.90 |

**Success = net PF up AND gross-win-per-3+bar-trade unchanged** (i.e. we cut churn, not the edge). If a filter also drops the 3+ bar winners, reject it.

## Guardrails (do not touch — proven)
- Cooldown stays **1** (2 collapsed PF to 0.79).
- Bars-before-cut stays **4**.
- 15m timeframe only (edge dies below 15m — commission > net).
