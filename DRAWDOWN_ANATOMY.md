# Anatomy of the equity drop — and the inverted strength ladder

Source: test 3 ([`BACKTEST_EXCLUSIVE_ONE_2026_TEST3.md`](BACKTEST_EXCLUSIVE_ONE_2026_TEST3.md)),
BREAK-only, longs-only, 2026 M1, 251 positions, −£194.98, PF 0.89.

---

## 1. There is no "drop". There is a six-month grind.

The reported max balance drawdown is **£310.77 (29.43%)**. Reconstructed from the deal log it
is **£310.59 (29.41%)** — a match, so the window below is the real one:

| | |
|---|---|
| Peak | position **#5**, £1,055.99 — **5 January** |
| Trough | position **#230**, £745.40 — **early July** |
| Span | **225 of 251 positions** — 90% of the entire run |
| Inside it | 60 wins / 165 losses (WR 26.7%) |
| Won / lost | +£1,296.05 / −£1,606.64 |

**The drawdown is the backtest.** The account peaked on the fifth trade and spent the next six
months grinding down. Looking for the moment it broke is looking for something that isn't there:

- Longest losing streak inside the window: **10**
- Positions losing more than £10: **103**, totalling **−£1,357**
- Positions losing £0–10: **62**, totalling **−£249**

No crash, no gap, no single bad day. A hundred separate £10–17 losses.

## 2. What is causing it: grade S3

Decomposing the same 225-position window by setup grade:

| Grade | N | Net | Share of the £310.59 drop |
|---|---|---|---|
| S0 | 15 | −£44.62 | 14.4% |
| S1 | 40 | **+£52.28** | −16.8% |
| S2 | 94 | **+£22.89** | −7.4% |
| **S3** | **76** | **−£341.14** | **109.8%** |

**S3 is more than the whole drawdown.** Take S3 out of that exact window and the other 149
positions make **+£30.55** instead of losing £310.59. Nine of the ten worst single trades in
the window are S3 or S2.

## 3. Why S3 — the mechanism, in the code

`GMC_EXCLUSIVE_ONE.mq5:1281`:

```mql5
int strength = (bodyPct >= 70 ? 1 : 0)
             + ((rng > 0.0 && decis >= 0.30 * rng) ? 1 : 0)
             + (atrNow > atrOld ? 1 : 0);
```

**S3 means all three conditions true — it is the grade the build calls "strongest".** It is
the worst performer in every run measured.

And `:1311`:

```mql5
double strengthMult = (strength >= 3) ? InpStrongMult : (strength <= 1) ? 0.5 : 1.0;
```

With `InpStrongMult = 1.0`: **S2 and S3 trade at full risk; S0 and S1 trade at half.**

The trade data confirms the sizing exactly — average loss per position, test 3:

| Grade | avg loss | risk multiplier |
|---|---|---|
| S0 | £5.71 | 0.5 |
| S1 | £4.72 | 0.5 |
| S2 | £10.80 | 1.0 |
| S3 | £11.61 | 1.0 |

A clean 2:1 split, exactly as the code specifies. **The build is betting double on the grade
that loses, and half on the two grades that make money.** The strength ladder is inverted
relative to what the data does.

There is also a reason to doubt the third component on its own terms. `atrNow > atrOld` is
**volatility expanding**. So S3 is: a large-bodied, decisive candle, fired while volatility is
already rising — entered on a stop order $0.10 beyond the extreme. That is a description of
buying the end of an impulse, not the start of one. The score treats "the move has already
gone" as a quality mark.

**Stated plainly: this explanation was formed after seeing S3 lose.** It is a plausible
mechanism, not proof. What separates it from ordinary bucket-picking is that it names a
specific code path, predicts the *magnitude* (the 2:1 loss ratio) and not merely the sign, and
is falsifiable by a single existing input.

## 4. How to remove it

**Test 4 — `InpStrongMult = 0.5`.** One existing input. Everything else unchanged.

This makes S3 size like S0/S1 instead of double. Crucially it **deletes no trades**, so it is a
sizing correction rather than a signal claim — and unlike the FVG change it is close to
separable, because lot size does not decide which signals fire. The same ~251 positions should
appear.

**Prediction, before the run:** ~251 positions, net **−£40 to −£60**, PF **0.96–0.98**.
S3's −£309 halves to ≈ −£155. **This will not clear PF 1.0** and is not expected to. It tests
whether the sizing ladder is really inverted, at zero curve-fitting cost.

**What would remove the drop entirely — filtering S3 out — is not being done.** It needs a code
change (no input exists), and more importantly it still has no out-of-sample support. That
remains blocked behind a confirmation run on a year other than 2026.

## 5. The thing this does not fix

Every number here is from one seven-month window. S3 being the worst grade has now reproduced
across two runs on that window — which is a consistency check, not a second test. Until the
config is confirmed on 2025 or 2022, "get rid of the drop" means "get rid of the drop *in the
data used to find it*", which is not the same as getting rid of it.

Nothing here clears the bar for Phase 1. The record stands — including this.
