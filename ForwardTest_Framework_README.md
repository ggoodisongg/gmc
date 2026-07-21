# Forward-Test Risk Management Framework

An **honest** TradingView (Pine v6) rig for testing whether a trading signal actually has an edge — with correct position sizing, real costs, no look-ahead, and a live scorecard. It does **not** create an edge; it tells you the truth about whatever signal you plug into it.

This is the one tool in this repo worth keeping. Every *strategy* we tested failed honest validation (see `REALITY_CHECK.md`); this is the *instrument* that did the validating.

## What it does
- **1%-risk position sizing** — every trade risks the same fraction of equity (`qty = risk$ / ATR-stop`), so wins/losses are consistent and comparable.
- **Real costs modelled** — commission (0.015%) + slippage baked into the `strategy()` line.
- **No look-ahead** — `process_orders_on_close=false` (next-bar-open fills); signals evaluate on confirmed bar closes only.
- **Forward-test date lock** — trades only after `startDate`, so you test on data the signal wasn't built on.
- **Live dashboard** — Win %, **Profit Factor** (green ≥ 1, red < 1), Net P&L, trade count, live risk/size.

## How to use it
1. Paste `ForwardTest_Framework.pine` into the TradingView Pine Editor → Save → Add to chart.
2. **Set your real values:** `Account Size`, `Risk Per Trade %`, `Min Lot / Qty Step` (your broker's step), and confirm commission matches your broker.
3. **Drop your signal into Section 4** (the `>>> PLUG YOUR SIGNAL IN HERE <<<` block), replacing the EMA-crossover placeholder. It must be non-repainting (bar-close logic).
4. Read the **Profit Factor** cell.

## Two ways to test (do both)
- **Out-of-sample backtest:** leave the date lock on; it trades only the post-`startDate` window on history.
- **True live forward test (the real proof):** run it on a **paper/demo chart from today forward**. It keeps trading unseen future bars in real time — un-fakeable. This is the Phase-0 "verified live record" the project is built around.

## Reading the result honestly
- **PF > ~1.3, green, holding over a real forward window** = a genuine signal. Investigate hard.
- **PF < 1** = the signal has no edge. No amount of risk-tuning fixes a signal that isn't right often enough.
- **The break-even math:** at a 2:1 reward:risk you need to win **> 33%** of trades just to break even (before costs). The EMA placeholder wins ~30% — which is exactly why it prints red. That's the framework doing its job.

## Note
Modelled costs are only as honest as the values you enter. Set commission, slippage, and lot-step to your real broker. This tool reports the truth of a backtest/forward-test — it is not financial advice or a performance claim.
