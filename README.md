# GMC — the signal service, before it exists

**G Money Core** is an autonomous trading system for gold (XAUUSD, 1-minute timeframe). It runs as an Expert Advisor on MetaTrader 5 and takes its own trades — and when the service launches, every trade it takes will be published to subscribers as a signal, in the moment it happens.

This repo is the public specification of that service: what a signal will look like, who gets what, and the order things will happen in. It exists so the plan is on record **before** launch — the same discipline the system itself is built with.

> **Status: Phase 0 — verification.** No signals are published yet, and none will be sold until the system's live forward-test is verifiably on record.

---

## The signal

Every signal is a trade the system has actually taken — not a call someone typed into a chat. Published within seconds of execution, numbered, timestamped, archived. When the system exits, the exit is published too.

```text
GMC · TRACK B                       [SIGNAL]

XAUUSD — LONG

entry    2412.40
stop     2409.10
target   2418.90

#0184 · 14:32:07 UTC
```

*Illustrative format only — not a live signal.*

**The record stands.** Every signal is numbered and archived, exits included. The full history stays public and auditable. Nothing is edited, nothing is deleted.

## Access

| | **The channel** (free) | **The service** (VIP) |
|---|---|---|
| Selected signals after the trade closes | ✔ | ✔ |
| The complete running record | ✔ | ✔ |
| Every signal in real time | | ✔ |
| Exits & management updates live | | ✔ |
| Price | Free, forever | Announced at launch |

The free channel is the proof layer — it exists so anyone can check the record before paying for anything.

## Roadmap

| Phase | What happens | State |
|---|---|---|
| **0 — Verification** | The system trades a live account under independent, third-party tracking. Nothing is sold. | 🟡 **now** |
| **1 — The channel** | The free channel opens, carrying the verified record. | |
| **2 — VIP launch** | Real-time signals for founding members — only once the record justifies charging. | |
| **3 — Beyond** | Further tracks and instruments, each held to the same bar: frozen, validated, verified live. | |

**Verification tooling.** The honest forward-test rig that every candidate must pass — correct risk-based sizing, real commission and slippage, no look-ahead, and a forward-locked window — is public: [`ForwardTest_Framework.pine`](ForwardTest_Framework.pine) ([how to use](ForwardTest_Framework_README.md)). It is the *instrument*, not a strategy: drop a signal in and it reports the truth, green or red. This is Phase 0's discipline made concrete — the strategy code stays private, the standard it's held to does not.

## The system behind it

Built and run under four rules:

1. **Versioned lineage** — validated configurations are frozen as numbered versions (current line: Track B `v2.9.5 → v3.0 frozen → v3.1 active`). New work always branches from the last frozen state.
2. **Earned change** — every change is validated against the prior frozen version before adoption.
3. **Anti-repaint discipline** — all higher-timeframe reads use fully closed bars only; the live system sees exactly what development saw.
4. **Proof before promises** — no performance claims without a verified live record.

The strategy code itself is private. The discipline around it is the public part.

---

<sub>GMC is a personal research and engineering project. Everything here describes a planned service; the example signal is illustrative only. Nothing in this repository is financial advice, an offer of any service, or a claim of trading performance. Markets involve risk.</sub>
