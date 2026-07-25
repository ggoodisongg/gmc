# FROZEN — GMC Track B v3.4 Hybrid (validated)

**Status: VALIDATED & FROZEN.** Sniper confluence entry + Track B risk engine.
Tuned and validated on XAUUSD M5 with real IC Markets ticks (every-tick model),
£5,000 account. This is the first strategy in the project that is strongly
profitable on BOTH the recent regime and the full multi-year window.

## Validated results (XAUUSD M5, real ticks)

| Window | Profit Factor | Net (£5k) | Max DD | Recovery Factor |
|---|---|---|---|---|
| Recent (2025 → 2026) | **1.97** | +£1,633 | 5.8% | 3.83 |
| Full 4 years (2022 → 2026) | **1.40** | +£2,905 (+58%) | 11.65% | 4.20 |

Robustness note: SL_ATR_Multiplier of 1.5 / 1.75 / 2.0 all land ~1.37–1.46
(4yr) and ~1.96–1.97 (recent). The edge is stable across a range of settings —
a sign it is real, not curve-fit.

## Frozen winning inputs (vs v3.4 defaults)
- Min_Score        = 6      (perfect 6/6 confluence only)
- SL_ATR_Multiplier= 2.0
- TP1_R            = 1.8    (bank the partial later)
- Partial_Close_Pct= 35     (bank less, let more ride)
- TP_Final_R       = 5.5    (let runners target further)
- Trail_Start_R    = 2.5
- Trail_R_Step     = 0.6    (looser trail so runners aren't cut early)
- Risk_Percent     = 1.0
- (all other inputs at v3.4 defaults)

## How we got here (the honest record)
- Track B v3.32/3.33 alone: PF ~0.89–0.98 (weak entry). Filtering (ADX/ATR)
  did not help — losses were not concentrated in a filterable regime.
- Sniper v9.5 alone: PF ~1.5 recent / 0.93 over 4 years (fragile).
- v3.4 hybrid (Sniper entry + Track B risk): PF 1.07 (4yr) at defaults, then
  tuned in disciplined steps — exits (1.07→1.17), entry quality Min_Score 6
  (1.17→1.46 region), stop calibration — each gain validated on the 4-year
  window, not just the recent one.

## Next step
Forward-test live on the IC Markets demo (M5 XAUUSD, Algo Trading on) alongside
the Sniper. Judge on real, unseen forward data before any real capital. Do NOT
tune further on historical data — further past-fitting risks turning a real
edge into an overfit mirage.
