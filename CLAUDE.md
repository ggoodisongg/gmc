# CLAUDE.md

Guidance for AI assistants working in this repository.

## What this repo is

This is the **public specification** of GMC ("G Money Core") — an autonomous
trading system for gold (XAUUSD, 1-minute timeframe) that runs as an Expert
Advisor on MetaTrader 5. When the signal service launches, every trade the
system takes will be published to subscribers as a signal.

**This repo does not contain the trading system.** The strategy/EA code is
private and is not here. What lives here is the *public record of intent*: what
a signal will look like, who gets what, and the order things happen in —
committed **before** launch, on purpose.

Current project state: **Phase 0 — verification.** No signals are published
yet; nothing is sold.

## Repository structure

```
README.md    The entire public specification (signal format, access tiers, roadmap, principles)
CLAUDE.md    This file
```

That is the whole repo. There is **no source code, build system, test suite,
package manifest, or CI**. Do not add or scaffold any of these unless
explicitly asked — this is a documentation repo, and its value is that the
record is clean and deliberate.

## Working conventions

Because the only artifact is prose, "development" here means editing the
specification carefully. Match the existing document, don't reshape it.

**Voice and framing**
- The README's premise is *"the signal service, before it exists."* Keep the
  future/planned framing intact. Do not rewrite planned features as if they are
  live.
- Tone is disciplined and understated — no hype, no marketing superlatives, no
  urgency. Preserve it.

**Hard content rules (these mirror the system's own discipline):**
1. **No performance claims** without a verified live record. Never add win
   rates, returns, pip counts, or backtest numbers.
2. **Examples are illustrative only.** The sample signal block is labeled
   *"Illustrative format only — not a live signal."* Keep any such labels on any
   example you touch or add.
3. **Nothing is edited or deleted from the record.** The document states the
   published signal history "stays public and auditable. Nothing is edited,
   nothing is deleted." Honor that spirit — don't quietly rewrite claims the
   project has committed to.
4. **Don't leak the private strategy.** The strategy code is deliberately not
   public. Do not invent, describe, or infer strategy internals, parameters, or
   logic beyond what the README already states.

**The four project principles** (from the README — keep changes consistent with them):
1. **Versioned lineage** — validated configs are frozen as numbered versions
   (current: Track B `v2.9.5 → v3.0 frozen → v3.1 active`). New work branches
   from the last frozen state.
2. **Earned change** — every change is validated against the prior frozen
   version before adoption.
3. **Anti-repaint discipline** — higher-timeframe reads use fully closed bars
   only.
4. **Proof before promises** — no claims without a verified live record.

When you update roadmap phases, access tiers, or the version lineage, keep the
Markdown tables and the fenced example block formatted exactly as they are.

## Git workflow

- Develop on the designated feature branch; never push to `main` without
  explicit permission.
- Push with `git push -u origin <branch-name>`.
- Commit messages are short and descriptive of the specification change (see the
  existing history, e.g. *"Public service specification: signal format, access
  tiers, roadmap"*). Describe *what part of the spec changed*, not internal
  tooling.
- Do **not** open a pull request unless explicitly asked.

## Quick orientation for a new task

1. Read `README.md` in full — it is the single source of truth.
2. Figure out which section the request touches (signal format / access /
   roadmap / principles / disclaimer).
3. Edit in place, preserving voice, framing, and the hard content rules above.
4. Commit with a clear message and push to the feature branch.
