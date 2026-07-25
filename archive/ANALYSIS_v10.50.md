# Track B — log analysis & v10.50 changes

Analysis of 5 Strategy Tester exports (OANDA XAUUSD), 6,121 closed trades total.

## Findings (consistent across all 5 runs)

- **Already net-positive**, PF 1.41–1.78, win rate ~36–42%. It wins because avg win (£8–10) ≈ 2.5× avg loss (£3–4). Not a losing system — a leaking one.
- **Leak 1 — over-trading / commission.** Commission paid ≈ net profit (e.g. file 10: £4,442 comm vs £4,920 net). Driven by hundreds of **zero-bar flip trades** (file 10: 808 flips = −£400; file 14: 489 = −£217).
- **Leak 2 — the "Macro Run" runner gives profit back.** `L/S Macro Run` are the worst legs everywhere (`S Macro Run` −£587 in file 10, `L Macro Run` wins only 5.6–39%). Trades reaching +0.3–0.7% favorable still close red. The **Partial (Tier-1) exits are the entire edge** (win 50–57%, all net positive).
- **Leak 3 — non-monotonic trailing stop** (ATR expansion loosened the stop mid-trade).

## v10.50 changes

1. **Churn control** — `Cooldown_Bars` + `Block_Instant_Reverse` gate every entry, killing same-bar flips → removes the commission bleed.
2. **Break-even lock after Tier 1** — once the partial is taken, the runner's stop floors at break-even (+ small ATR buffer). Keeps the fat right tail, removes the losing round-trips. *Primary fix for Leak 2.*
3. **Monotonic trailing stop** — ratchets toward profit only, resets when flat. *Fix for Leak 3.*
4. **Confirmed-candle loss cut** — cancels a losing trade early, but only on a **closed** adverse candle (`barstate.isconfirmed`), never on intrabar noise — reads the full candle before acting.
5. **`Partial_Close_Pct`** input — the edge lives in the partial; lets you weight size toward it (try 60–70%).

## Caveat

These are hypotheses derived from the logs, implemented in Pine v5. They are **not yet backtested** — run v10.50 in the TradingView Strategy Tester over the same period and compare net PnL, PF, and commission before freezing.
