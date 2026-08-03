//+------------------------------------------------------------------+
//|                                                                  |
//|            G M C   E X C L U S I V E   O N E                      |
//|                                                                  |
//|   XAUUSD M1 · MetaTrader 5 · Raw Trading Ltd (IC Markets)         |
//|   Build 1.00                                                      |
//|                                                                  |
//|   Lineage: GMC Track B v3.1 (MTF ANTI-REPAINT FIX) MQL5 port,     |
//|            hardened after the 3-week live forward test on demo    |
//|            52961700 (15 Jul - 27 Jul 2026, +9.89%, PF 1.37,       |
//|            15.96% peak-to-trough drawdown).                      |
//|                                                                  |
//+------------------------------------------------------------------+
//|                                                                  |
//|   B U I L D   N A M E   L A D D E R                              |
//|                                                                  |
//|     GMC EXCLUSIVE ONE        <- THIS BUILD        version 1.x    |
//|     G MONEY EXCLUSIVE TWO                         version 2.x    |
//|     G MONEY EXCLUSIVE THREE                       version 3.x    |
//|     G MONEY EXCLUSIVE FOUR                        version 4.x    |
//|     G MONEY EXCLUSIVE FIVE                        version 5.x    |
//|     ... and so on.                                               |
//|                                                                  |
//|   The build name is the heading of the file, the heading of the   |
//|   on-chart HUD, and the heading of every section and input group  |
//|   below. When a new build is cut, change GMC_NAME / GMC_VER once  |
//|   (section 01) and every heading, the HUD, the log file and the   |
//|   trade comments follow automatically.                            |
//|                                                                  |
//+------------------------------------------------------------------+
//|                                                                  |
//|   W H A T   C H A N G E D   F R O M   v 3 . 1                    |
//|                                                                  |
//|   The signal engine is BYTE-FOR-BYTE UNCHANGED. Momentum          |
//|   lookback, body %, BREAK / FVG / SWEEP classes, the shift=1      |
//|   MTF gates, the Kaufman ER regime gate, the strength score, the  |
//|   ATR stop clamp, TP1 / partials / R-locks / runner give-back /   |
//|   time-stop thresholds are all identical. Only EXECUTION,         |
//|   ACCOUNTING, PROTECTION and OBSERVABILITY were rebuilt.          |
//|                                                                  |
//|   FIXED (defect -> fix)                                          |
//|   F1  Positions were submitted with sl=0 and the stop was only    |
//|       attached on the NEXT M1 bar - up to ~60s naked, and         |
//|       indefinitely naked if the terminal dropped after a fill.    |
//|       -> The stop now travels WITH the order request, and a       |
//|          tick-level guard re-asserts it if the broker rejects it. |
//|   F2  All trade state lived in memory. After a restart the stop   |
//|       distance fell back to InpMinSLUsd ($1.00), which was then   |
//|       written as a real broker stop - tightening a $3 stop to $1  |
//|       and mis-scaling every R milestone by up to 4x.              |
//|       -> State is persisted per position and reloaded on init;    |
//|          if it is ever missing it is reconstructed from the live   |
//|          broker stop, and only then from ATR, and it is logged.   |
//|   F3  Kelly and the consecutive-loss counter counted DEALS, not   |
//|       TRADES. Partial closes are deals, so a winner that banked   |
//|       at +1R, again at TP1 and then ran produced THREE positive   |
//|       records while a loser produced ONE. Win rate structurally   |
//|       inflated, average win understated.                          |
//|       -> History is now aggregated by POSITION_ID. One position   |
//|          = one trade. Both code paths use the same P/L basis      |
//|          (profit + swap + commission).                            |
//|   F4  ManagePosition() selected by SYMBOL, then checked magic.    |
//|       On a hedging account another XAUUSD position could be       |
//|       returned, the magic check bailed, and this EA's own trade   |
//|       ran with no stop management, no partials, no time stop.     |
//|       -> Everything is now addressed by POSITION TICKET.          |
//|   F5  Every trade-server return code was discarded except the     |
//|       pending-order result. A rejected stop modification failed   |
//|       silently. Three weeks live produced no trail, which is why  |
//|       the 22-24 Jul no-trade gap could not be explained.          |
//|       -> Every request is checked, logged with its retcode, and   |
//|          mirrored to CSV. Blocked signals log WHICH gate blocked  |
//|          them, so the cost of every gate is measurable.           |
//|   F6  iHighest()/iLowest() return -1 on a history error; that fed |
//|       a price lookup returning 0.0, and the breakout test was     |
//|       then true for any price - a trade fabricated from nothing.  |
//|       -> Indices and bar counts are validated before use.        |
//|   F7  The full deal history was re-selected and looped twice per  |
//|       M1 bar. Negligible at 40 trades, ~10k iterations/minute at  |
//|       several thousand.                                           |
//|       -> Rebuilt only when OnTradeTransaction says it changed.    |
//|   F8  (found while porting) Buf() returned 0.0 when CopyBuffer    |
//|       failed. A failed H1 EMA read therefore became "EMA = 0",    |
//|       and the bullish MTF gate "close > 0" PASSED. Silent bad     |
//|       entries on any indicator hiccup. Same for ATR: a failed     |
//|       read became slDist = min stop.                              |
//|       -> Reads are checked; a failed read skips the bar.          |
//|   F9  (found while porting) Kelly's payoff was 0 when the window  |
//|       contained ZERO losses, so k=0 and risk dropped to the       |
//|       FLOOR after a perfect run - exactly backwards.              |
//|       -> A loss-free window now sizes at the ceiling, not floor.  |
//|   F10 The lot cap capped SIZE, not RISK, so realised risk swung   |
//|       ~1% to ~4% with stop width - largest risk in the hottest    |
//|       markets. Sub-minimum lots were silently rounded UP to       |
//|       min lot, breaking the risk model from below.                |
//|       -> A hard risk ceiling in account currency is enforced      |
//|          after sizing, margin is pre-checked, and a trade that    |
//|          cannot be sized inside its risk budget is SKIPPED and    |
//|          logged rather than forced to min lot.                    |
//|   F11 gPeak was seeded from the previous bar's high/low, which    |
//|       can predate the entry, so the runner give-back trailed      |
//|       from a peak the trade never reached.                        |
//|       -> Peak only tracks price at or after the entry time.       |
//|                                                                  |
//|   DEFAULTS CHANGED (all revertible - one input each)              |
//|     InpBaseRiskPct     3.0  -> 1.5   forward test drew down 16%   |
//|                                      in ~2 weeks; the strategy's  |
//|                                      own validation shows 33%.    |
//|     InpMaxRiskPct      4.0  -> 2.0   ceiling is now hard.         |
//|     InpUseKelly        true -> false Kelly stays OFF until F3 has |
//|                                      fed it clean trade-level     |
//|                                      stats for a full window.     |
//|     InpMaxSpreadPips   25   -> 15    25 points ($0.25) is ~2x a   |
//|                                      normal raw gold spread; at   |
//|                                      that ceiling spread alone is |
//|                                      ~half the per-trade edge.    |
//|     InpLotCapPer1000   0.10 -> 0.00  (disabled) superseded by the |
//|                                      hard risk ceiling in F10.    |
//|   Set these four back to 3.0 / 4.0 / true / 25 / 0.10 to run the   |
//|   exact v3.1 risk profile with the execution fixes only.          |
//|                                                                  |
//|   BEHAVIOUR DELIBERATELY *NOT* CHANGED                            |
//|     Milestone management still evaluates on M1 bar close, the     |
//|     same as the Pine model. Moving it to tick level would bank    |
//|     more open profit but would no longer match the backtest, so   |
//|     it is opt-in via InpManageOnTick (default false). The stop    |
//|     SAFETY guard runs every tick regardless - that is F1, not a   |
//|     strategy change.                                              |
//|                                                                  |
//|   STILL OPEN - NOT a code problem                                 |
//|     At a per-trade Sharpe of 0.13 the forward test's t-statistic  |
//|     is 0.8-1.2 against a 1.645 threshold. The result is not yet   |
//|     distinguishable from no edge. ~160 trades (~8 weeks at 21 a   |
//|     week) are needed before it means anything. Do not re-tune on  |
//|     the strength of the 16-17 Jul two-day burst.                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "G Money Core"
#property link      ""
#property version   "1.00"
#property strict
#property description "GMC EXCLUSIVE ONE - XAUUSD M1 - hardened execution build"

#include <Trade\Trade.mqh>

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  01 · IDENTITY                              //
//==================================================================//
// Change these two lines to cut the next build in the ladder
// (G MONEY EXCLUSIVE TWO / THREE / FOUR / FIVE ...). Every heading,
// the HUD, the log file name and the trade comments follow.
#define GMC_NAME  "GMC EXCLUSIVE ONE"
#define GMC_VER   "1.00"
#define GMC_TAG   "GMC1"          // short prefix: comments, globals, objects

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  02 · INPUTS                                //
//==================================================================//

input group "GMC EXCLUSIVE ONE — Entry Engine (unchanged from v3.1)"
input int    InpMomLookback   = 3;      // Momentum lookback (M1 bars)
input double InpMinBodyPct    = 50;     // Min trigger body % of range
input bool   InpUseH1Filter   = true;   // H1 EMA50 master direction
input bool   InpUseM15Filter  = true;   // M15 EMA50 filter
input bool   InpUseM5Confirm  = true;   // M5 EMA50 confirm
input bool   InpUseRegime     = true;   // Regime gate (Kaufman ER)
input int    InpERPeriod      = 30;     // ER period (M1 bars)
input double InpERMin         = 0.40;   // ER minimum - FROZEN
input bool   InpEnableBreak   = true;   // Class A: BREAK
input bool   InpEnableFVG     = false;  // Class B: FVG          [TEST 4: false]
input bool   InpEnableSweep   = false;  // Class C: SWEEP
input bool   InpSellsEnabled  = false;  // Sells enabled          [TEST 4: false]

input group "GMC EXCLUSIVE ONE — Execution"
input bool   InpUsePending     = true;  // Pending stop-order entry
input double InpEntryOffsetUsd = 0.10;  // Entry stop offset ($ beyond price)
input int    InpPendExpiry     = 2;     // Pending expiry (M1 bars)
input int    InpMaxSpreadPips  = 15;    // Max spread (points) to trade [v3.1: 25]
input int    InpSlippagePts    = 30;    // Max deviation (points)

input group "GMC EXCLUSIVE ONE — Stops & Targets (unchanged from v3.1)"
input int    InpATRPeriod      = 14;    // ATR period (M1)
input double InpStopAtrMult    = 1.5;   // Stop = mult x ATR
input double InpMinSLUsd       = 1.00;  // Min SL ($)
input double InpMaxSLUsd       = 4.00;  // Max SL ($) - skip if hotter
input double InpTP1R           = 1.5;   // TP1 (R) - partial
input double InpBankR0Pct      = 0;     // Bank % at +1.0R        [TEST 4: 0]
input double InpPartialPct     = 50;    // Partial % at TP1
input double InpLock25R        = 1.25;  // Lock (R) at +2.5R
input double InpLock40R        = 2.0;   // Lock (R) at +4.0R
input double InpRunnerGiveBack = 30;    // Runner give-back % of peak
input bool   InpManageOnTick   = false; // Milestones on every tick (OFF = match backtest)

input group "GMC EXCLUSIVE ONE — Risk"
input double InpBaseRiskPct    = 1.5;   // Base risk %/trade         [v3.1: 3.0]
input double InpStrongMult     = 0.5;   // Strong-signal risk mult - FROZEN [TEST 4: 0.5]
input bool   InpUseKelly       = false; // Adaptive Kelly            [v3.1: true]
input int    InpKellyWindow    = 30;    // Kelly window (closed TRADES, not deals)
input double InpKellyFrac      = 0.5;   // Kelly fraction
input double InpMinRiskPct     = 1.0;   // Risk floor %
input double InpMaxRiskPct     = 2.0;   // Risk ceiling % (HARD)     [v3.1: 4.0]
input double InpLotCapPer1000  = 0.00;  // Lot cap per $1000 (0=off) [v3.1: 0.10]
input double InpMaxMarginPct   = 20.0;  // Max margin per trade (% of equity)
input bool   InpAllowMinLot    = false; // Force min lot if risk-lot is smaller

input group "GMC EXCLUSIVE ONE — Sessions & Protection"
input int    InpSesStart       = 0;     // Session start hour (server) - FROZEN 24h
input int    InpSesEnd         = 24;    // Session end hour (server) - FROZEN 24h
input double InpDailyLossPct   = 8;     // Daily loss halt %
input double InpDailyLockPct   = 10;    // Daily profit lock %
input int    InpMaxConsecL     = 3;     // Max consecutive losing TRADES
input int    InpCooldownMin    = 45;    // Cooldown minutes
input bool   InpUseTimeStop    = true;  // Time-stop flat trades
input int    InpTimeStopMin    = 20;    // Time-stop (minutes)
input long   InpMagic          = 10100; // Magic number (Exclusive One)

input group "GMC EXCLUSIVE ONE — Observability"
input bool   InpLogToFile      = true;  // Mirror log to CSV in MQL5\Files
input bool   InpLogBlocked     = true;  // Log signals killed by a gate
input bool   InpShowHUD        = true;  // On-chart heading + live state
input color  InpHudColor       = clrGold;
input int    InpHudFont        = 9;

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  03 · STATE                                 //
//==================================================================//
CTrade trade;

//--- indicator handles
int hEmaH1  = INVALID_HANDLE;
int hEmaM15 = INVALID_HANDLE;
int hEmaM5  = INVALID_HANDLE;
int hATR    = INVALID_HANDLE;

//--- symbol facts, cached in OnInit
double gTickVal = 0.0, gTickSize = 0.0, gMinLot = 0.0, gMaxLot = 0.0, gLotStep = 0.0;
int    gStopsLevel = 0;
bool   gExpirySupported = false;

//--- daily / protection state
double   gDayStartEq   = 0.0;
bool     gHaltedDay    = false;
bool     gLockedProfit = false;
int      gConsecLosses = 0;
datetime gCooldownUntil = 0;
int      gDayOfMonth   = -1;

//--- per-position state (F2: mirrored to terminal globals)
ulong    gPosTicket  = 0;      // ticket we are managing, 0 = none
long     gPosId      = 0;      // position id, for history exclusion
double   gEntryPrice = 0.0;
double   gSlDist     = 0.0;    // R, in price
double   gLogicalSL  = 0.0;
bool     gSt0 = false, gSt1 = false, gSt25 = false, gSt40 = false;
double   gPeak       = 0.0;
datetime gEntryTime  = 0;
double   gInitVolume = 0.0;
double   gPendingSlDist = 0.0; // stop distance staged for the order in flight

//--- pending order state
datetime gPendPlaced = 0;

//--- closed-trade history, aggregated by POSITION_ID (F3/F7)
struct GmcTrade
  {
   long     posId;
   double   pnl;          // profit + swap + commission
   datetime closed;
  };
GmcTrade gTrades[];
bool     gHistDirty     = true;
long     gLastCountedId = 0;

//--- bar clock, logging, HUD
datetime gLastBarTime  = 0;
int      gLogHandle    = INVALID_HANDLE;
string   gLastBlock    = "";
datetime gLastStopTry  = 0;
int      gBlockedSpread = 0, gBlockedVol = 0, gBlockedGate = 0, gBlockedRisk = 0;

//--- forward declarations (so the reading order below is top-down)
void   LookForEntry(const MqlDateTime &dt, double eq, bool inCooldown);
void   PlaceEntry(bool isLong, double lots, double c1, double slDist,
                  double ask, double bid, const string cm);
void   ManagePosition(ulong ticket);
void   DrawHUD();
double KellyRiskPct();
string GKey(const string leaf);
void   SaveState();

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  04 · LOGGING  (F5)                         //
//==================================================================//
void Log(const string tag, const string msg)
  {
   string line = StringFormat("[%s %s] %-14s %s", GMC_NAME, GMC_VER, tag, msg);
   Print(line);
   if(gLogHandle != INVALID_HANDLE)
     {
      FileWrite(gLogHandle,
                TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                tag, msg,
                DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
                DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
      FileFlush(gLogHandle);
     }
  }

void OpenLog()
  {
   if(!InpLogToFile) return;
   string fn = StringFormat("%s_%I64d_%s.csv", GMC_TAG,
                            AccountInfoInteger(ACCOUNT_LOGIN), _Symbol);
   gLogHandle = FileOpen(fn, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
   if(gLogHandle == INVALID_HANDLE)
     {
      PrintFormat("[%s] log file open failed (%d) - console logging only", GMC_NAME, GetLastError());
      return;
     }
   if(FileSize(gLogHandle) == 0)
      FileWrite(gLogHandle, "time", "tag", "detail", "equity", "balance");
   else
      FileSeek(gLogHandle, 0, SEEK_END);
  }

//--- report a CTrade result, whatever it was (F5)
bool Sent(const string what)
  {
   uint rc = trade.ResultRetcode();
   bool ok = (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED ||
              rc == TRADE_RETCODE_DONE_PARTIAL);
   Log(ok ? "OK" : "REJECT",
       StringFormat("%s rc=%u (%s) deal=%I64u order=%I64u price=%.2f vol=%.2f",
                    what, rc, trade.ResultRetcodeDescription(),
                    trade.ResultDeal(), trade.ResultOrder(),
                    trade.ResultPrice(), trade.ResultVolume()));
   return ok;
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  05 · SAFE READS  (F6 / F8)                 //
//==================================================================//
// A failed CopyBuffer used to return 0.0, which made "close > EMA"
// trivially TRUE and let bad entries through. Now a failed read is
// visible to the caller and the bar is skipped.
bool BufOk(int handle, int shift, double &out)
  {
   double b[1];
   out = 0.0;
   if(handle == INVALID_HANDLE) return false;
   if(CopyBuffer(handle, 0, shift, 1, b) != 1) return false;
   if(!MathIsValidNumber(b[0]) || b[0] == 0.0) return false;
   out = b[0];
   return true;
  }

bool PriceOk(double p) { return (MathIsValidNumber(p) && p > 0.0); }

bool EnoughBars()
  {
   int need = MathMax(InpERPeriod + 5, MathMax(InpMomLookback + 5, 60));
   if(Bars(_Symbol, PERIOD_M1) < need) return false;
   if(Bars(_Symbol, PERIOD_M5) < 55)  return false;
   if(Bars(_Symbol, PERIOD_M15) < 55) return false;
   if(Bars(_Symbol, PERIOD_H1) < 55)  return false;
   return true;
  }

bool NewM1Bar()
  {
   datetime t = iTime(_Symbol, PERIOD_M1, 0);
   if(t <= 0) return false;
   if(t != gLastBarTime) { gLastBarTime = t; return true; }
   return false;
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  06 · POSITION / ORDER LOOKUP  (F4)         //
//==================================================================//
// Addressed by ticket, never by symbol. On a hedging account the old
// PositionSelect(_Symbol) could hand back someone else's trade and
// this EA's own position would run completely unmanaged.
ulong FindMyPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      return tk;
     }
   return 0;
  }

bool HasMyPending()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      return true;
     }
   return false;
  }

void CancelMyPendings(const string why)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      trade.OrderDelete(tk);
      Sent(StringFormat("OrderDelete #%I64u (%s)", tk, why));
     }
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  07 · TRADE-LEVEL HISTORY  (F3 / F7)        //
//==================================================================//
// One POSITION = one trade. Partial closes are deals, not trades:
// counting deals inflated the win rate (a banked winner produced
// three positive records, a loser one negative record) and fed Kelly
// statistics that described nothing.
void MarkHistoryDirty() { gHistDirty = true; }

void RebuildHistory()
  {
   if(!gHistDirty) return;
   gHistDirty = false;

   if(!HistorySelect(0, TimeCurrent()))
     {
      Log("HISTORY", "HistorySelect failed - keeping previous aggregation");
      gHistDirty = true;
      return;
     }

   long   ids[];
   double pnl[];
   long   times[];
   ArrayResize(ids, 0); ArrayResize(pnl, 0); ArrayResize(times, 0);

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;

      ENUM_DEAL_ENTRY de = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk, DEAL_ENTRY);
      bool isOut = (de == DEAL_ENTRY_OUT || de == DEAL_ENTRY_OUT_BY);

      long pid = (long)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
      if(pid == 0) continue;
      if(pid == gPosId) continue;              // still open - not a closed trade

      double p = HistoryDealGetDouble(tk, DEAL_PROFIT)
               + HistoryDealGetDouble(tk, DEAL_SWAP)
               + HistoryDealGetDouble(tk, DEAL_COMMISSION);
      long   t = (long)HistoryDealGetInteger(tk, DEAL_TIME);

      // entry deals carry commission too, so they must be folded in,
      // but only OUT deals may establish the close time
      int found = -1;
      for(int k = ArraySize(ids) - 1; k >= 0; k--)
         if(ids[k] == pid) { found = k; break; }

      if(found < 0)
        {
         int n = ArraySize(ids);
         ArrayResize(ids, n + 1); ArrayResize(pnl, n + 1); ArrayResize(times, n + 1);
         ids[n] = pid; pnl[n] = p; times[n] = isOut ? t : 0;
        }
      else
        {
         pnl[found] += p;
         if(isOut && t > times[found]) times[found] = t;
        }
     }

   // keep only positions that actually closed, then sort by close time
   ArrayResize(gTrades, 0);
   for(int i = 0; i < ArraySize(ids); i++)
     {
      if(times[i] == 0) continue;
      int n = ArraySize(gTrades);
      ArrayResize(gTrades, n + 1);
      gTrades[n].posId  = ids[i];
      gTrades[n].pnl    = pnl[i];
      gTrades[n].closed = (datetime)times[i];
     }
   int n = ArraySize(gTrades);
   for(int i = 1; i < n; i++)                    // insertion sort, n is small
     {
      GmcTrade key = gTrades[i];
      int j = i - 1;
      while(j >= 0 && gTrades[j].closed > key.closed) { gTrades[j+1] = gTrades[j]; j--; }
      gTrades[j+1] = key;
     }
  }

//--- consecutive LOSING TRADES, and the cooldown they trigger
void UpdateStreak()
  {
   int n = ArraySize(gTrades);
   if(n == 0) return;

   int start = -1;                               // -1 = count every trade we hold
   if(gLastCountedId != 0)
      for(int i = n - 1; i >= 0; i--)
         if(gTrades[i].posId == gLastCountedId) { start = i; break; }

   if(start + 1 >= n) return;                    // nothing new closed

   for(int i = start + 1; i < n; i++)
     {
      gConsecLosses = (gTrades[i].pnl < 0.0) ? gConsecLosses + 1 : 0;
      Log("TRADE CLOSED",
          StringFormat("pos=%I64d pnl=%.2f consecutive losses=%d",
                       gTrades[i].posId, gTrades[i].pnl, gConsecLosses));
      if(gConsecLosses >= InpMaxConsecL)
        {
         gCooldownUntil = TimeCurrent() + InpCooldownMin * 60;
         gConsecLosses  = 0;
         Log("COOLDOWN", StringFormat("%d losing trades in a row -> paused until %s",
                                      InpMaxConsecL, TimeToString(gCooldownUntil, TIME_DATE|TIME_SECONDS)));
        }
     }
   gLastCountedId = gTrades[n-1].posId;
   GlobalVariableSet(GKey("lastid"), (double)gLastCountedId);
   GlobalVariableSet(GKey("cool"),   (double)gCooldownUntil);
  }

//--- window stats over TRADES
int TradeStats(int windowN, double &wr, double &payoff, bool &noLosses)
  {
   wr = 0.0; payoff = 0.0; noLosses = false;
   int n = ArraySize(gTrades);
   if(n < windowN) return n;

   int w = 0; double gw = 0.0, gl = 0.0;
   for(int i = n - windowN; i < n; i++)
     {
      if(gTrades[i].pnl > 0.0) { w++; gw += gTrades[i].pnl; }
      else                       gl += MathAbs(gTrades[i].pnl);
     }
   int losses = windowN - w;
   wr = (double)w / (double)windowN;
   if(losses == 0) { noLosses = true; payoff = 0.0; }        // F9
   else if(w > 0 && gl > 0.0) payoff = (gw / w) / (gl / losses);
   return n;
  }

double KellyRiskPct()
  {
   if(!InpUseKelly) return InpBaseRiskPct;

   double wr, payoff; bool noLosses;
   int n = TradeStats(InpKellyWindow, wr, payoff, noLosses);
   if(n < InpKellyWindow) return InpBaseRiskPct;             // not enough TRADES yet

   if(noLosses) return InpMaxRiskPct;                        // F9: was the FLOOR
   if(payoff <= 0.0) return InpMinRiskPct;

   double k = wr - (1.0 - wr) / payoff;
   if(k <= 0.0) return InpMinRiskPct;
   return MathMin(InpMaxRiskPct, MathMax(InpMinRiskPct, k * InpKellyFrac * 100.0));
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  08 · SIZING  (F10)                         //
//==================================================================//
double LossPerLot(double slDistUsd)
  {
   if(gTickVal <= 0.0 || gTickSize <= 0.0 || slDistUsd <= 0.0) return 0.0;
   return slDistUsd / gTickSize * gTickVal;
  }

// Returns lots, or 0 if the trade cannot be sized inside its risk
// budget. The old build rounded sub-minimum lots UP to min lot, which
// silently broke the risk model from below; that is now a logged skip.
double LotsForRisk(double riskUsd, double slDistUsd, bool isLong, double refPrice)
  {
   double lpl = LossPerLot(slDistUsd);
   if(lpl <= 0.0) { Log("SIZE", "loss-per-lot unavailable - trade skipped"); return 0.0; }

   double lots = riskUsd / lpl;

   //--- optional legacy exposure cap
   if(InpLotCapPer1000 > 0.0)
     {
      double cap = AccountInfoDouble(ACCOUNT_EQUITY) / 1000.0 * InpLotCapPer1000;
      if(lots > cap) lots = cap;
     }

   lots = MathFloor(lots / gLotStep) * gLotStep;
   if(lots > gMaxLot) lots = MathFloor(gMaxLot / gLotStep) * gLotStep;

   if(lots < gMinLot)
     {
      if(!InpAllowMinLot)
        {
         Log("SKIP risk-lot",
             StringFormat("risk $%.2f over SL $%.2f needs %.4f lots < min %.2f - skipped",
                          riskUsd, slDistUsd, riskUsd / lpl, gMinLot));
         gBlockedRisk++;
         return 0.0;
        }
      lots = gMinLot;
     }

   //--- HARD risk ceiling in account currency (this is the real fix)
   double eq      = AccountInfoDouble(ACCOUNT_EQUITY);
   double ceiling = eq * InpMaxRiskPct / 100.0;
   while(lots >= gMinLot && lots * lpl > ceiling + 1e-8)
      lots = NormalizeDouble(lots - gLotStep, 2);
   if(lots < gMinLot)
     {
      Log("SKIP risk-ceiling",
          StringFormat("min lot %.2f would risk $%.2f > ceiling $%.2f (%.1f%%) - skipped",
                       gMinLot, gMinLot * lpl, ceiling, InpMaxRiskPct));
      gBlockedRisk++;
      return 0.0;
     }

   //--- margin pre-check
   double margin = 0.0;
   ENUM_ORDER_TYPE ot = isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(ot, _Symbol, lots, refPrice, margin) && margin > 0.0)
     {
      double marginCap = eq * InpMaxMarginPct / 100.0;
      while(lots >= gMinLot && margin > marginCap)
        {
         lots = NormalizeDouble(lots - gLotStep, 2);
         if(lots < gMinLot) break;
         if(!OrderCalcMargin(ot, _Symbol, lots, refPrice, margin)) break;
        }
      if(lots < gMinLot)
        {
         Log("SKIP margin",
             StringFormat("min lot needs $%.2f margin > cap $%.2f - skipped", margin, marginCap));
         gBlockedRisk++;
         return 0.0;
        }
     }

   return NormalizeDouble(lots, 2);
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  09 · STATE PERSISTENCE  (F2)               //
//==================================================================//
string GKey(const string leaf)
  { return StringFormat("%s_%I64d_%s", GMC_TAG, InpMagic, leaf); }

void SaveState()
  {
   GlobalVariableSet(GKey("ticket"), (double)gPosTicket);
   GlobalVariableSet(GKey("posid"),  (double)gPosId);
   GlobalVariableSet(GKey("entry"),  gEntryPrice);
   GlobalVariableSet(GKey("sldist"), gSlDist);
   GlobalVariableSet(GKey("logsl"),  gLogicalSL);
   GlobalVariableSet(GKey("peak"),   gPeak);
   GlobalVariableSet(GKey("etime"),  (double)gEntryTime);
   GlobalVariableSet(GKey("ivol"),   gInitVolume);
   GlobalVariableSet(GKey("flags"),  (gSt0?1:0) + (gSt1?2:0) + (gSt25?4:0) + (gSt40?8:0));
   GlobalVariableSet(GKey("lastid"), (double)gLastCountedId);
   GlobalVariableSet(GKey("cool"),   (double)gCooldownUntil);
  }

bool LoadState(ulong wantTicket)
  {
   if(!GlobalVariableCheck(GKey("ticket"))) return false;
   if((ulong)GlobalVariableGet(GKey("ticket")) != wantTicket) return false;

   gPosTicket  = wantTicket;
   gPosId      = (long)GlobalVariableGet(GKey("posid"));
   gEntryPrice = GlobalVariableGet(GKey("entry"));
   gSlDist     = GlobalVariableGet(GKey("sldist"));
   gLogicalSL  = GlobalVariableGet(GKey("logsl"));
   gPeak       = GlobalVariableGet(GKey("peak"));
   gEntryTime  = (datetime)GlobalVariableGet(GKey("etime"));
   gInitVolume = GlobalVariableGet(GKey("ivol"));
   int f       = (int)GlobalVariableGet(GKey("flags"));
   gSt0 = (f & 1) != 0; gSt1 = (f & 2) != 0; gSt25 = (f & 4) != 0; gSt40 = (f & 8) != 0;
   return (gSlDist > 0.0 && gEntryPrice > 0.0);
  }

void LoadPersistentCounters()
  {
   if(GlobalVariableCheck(GKey("lastid"))) gLastCountedId = (long)GlobalVariableGet(GKey("lastid"));
   if(GlobalVariableCheck(GKey("cool")))   gCooldownUntil = (datetime)GlobalVariableGet(GKey("cool"));
  }

void ClearTradeState()
  {
   gPosTicket = 0; gPosId = 0;
   gEntryPrice = 0.0; gSlDist = 0.0; gLogicalSL = 0.0;
   gSt0 = false; gSt1 = false; gSt25 = false; gSt40 = false;
   gPeak = 0.0; gEntryTime = 0; gInitVolume = 0.0;
   GlobalVariableSet(GKey("ticket"), 0);
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  10 · STOP HELPERS  (F1)                    //
//==================================================================//
double MinStopDist()
  { return (double)gStopsLevel * _Point; }

// Clamp a stop so the server cannot reject it for being too close.
double SafeStop(bool isLong, double sl)
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double gap = MinStopDist();
   if(gap <= 0.0) return NormalizeDouble(sl, _Digits);
   if(isLong  && sl > bid - gap) sl = bid - gap;
   if(!isLong && sl < ask + gap) sl = ask + gap;
   return NormalizeDouble(sl, _Digits);
  }

bool PushStop(ulong ticket, bool isLong, double sl, const string why)
  {
   if(!PositionSelectByTicket(ticket)) return false;
   double cur = PositionGetDouble(POSITION_SL);
   double want = SafeStop(isLong, sl);
   if(cur != 0.0 && MathAbs(cur - want) < _Point * 0.5) return true;   // already there
   double tp = PositionGetDouble(POSITION_TP);
   trade.PositionModify(ticket, want, tp);
   return Sent(StringFormat("PositionModify #%I64u SL %.2f -> %.2f (%s)", ticket, cur, want, why));
  }

// Runs on EVERY tick. This is the F1 safety net: if a position is
// open with no broker stop - fresh fill mid-bar, rejected modify,
// terminal restart - a stop goes on NOW rather than next bar.
void EnsureProtectiveStop(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket)) return;
   if(PositionGetDouble(POSITION_SL) != 0.0) return;
   if(TimeCurrent() == gLastStopTry) return;         // one attempt per second
   gLastStopTry = TimeCurrent();

   bool   isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double open   = PositionGetDouble(POSITION_PRICE_OPEN);

   double d = gSlDist;
   if(d <= 0.0) d = gPendingSlDist;
   if(d <= 0.0)
     {
      double atr;                                  // last resort, never min-stop by default
      if(BufOk(hATR, 1, atr)) d = MathMin(MathMax(InpStopAtrMult * atr, InpMinSLUsd), InpMaxSLUsd);
      else                    d = InpMinSLUsd;
      Log("WARN", StringFormat("no stop distance in state for #%I64u - reconstructed $%.2f from ATR", ticket, d));
     }

   double sl = isLong ? open - d : open + d;
   if(PushStop(ticket, isLong, sl, "naked-position guard"))
     {
      if(gSlDist <= 0.0) { gSlDist = d; SaveState(); }
     }
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  11 · ADOPT A NEW POSITION                  //
//==================================================================//
void AdoptPosition(ulong ticket)
  {
   if(gPosTicket == ticket) return;
   if(!PositionSelectByTicket(ticket)) return;

   bool   isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double open   = PositionGetDouble(POSITION_PRICE_OPEN);
   long   pid    = (long)PositionGetInteger(POSITION_IDENTIFIER);

   if(LoadState(ticket))                                   // F2: survive a restart
     {
      gPosId = pid;
      Log("STATE RESTORED",
          StringFormat("#%I64u entry %.2f R $%.2f flags %d%d%d%d peak %.2f",
                       ticket, gEntryPrice, gSlDist,
                       (int)gSt0, (int)gSt1, (int)gSt25, (int)gSt40, gPeak));
      return;
     }

   gPosTicket  = ticket;
   gPosId      = pid;
   gEntryPrice = open;
   gEntryTime  = (datetime)PositionGetInteger(POSITION_TIME);
   gInitVolume = PositionGetDouble(POSITION_VOLUME);
   gSt0 = gSt1 = gSt25 = gSt40 = false;
   gPeak = open;

   //--- stop distance: staged value, else the live broker stop, else ATR
   double d = gPendingSlDist;
   string src = "signal";
   if(d <= 0.0)
     {
      double bsl = PositionGetDouble(POSITION_SL);
      if(bsl > 0.0) { d = MathAbs(open - bsl); src = "broker SL"; }
     }
   if(d <= 0.0)
     {
      double atr;
      if(BufOk(hATR, 1, atr)) { d = MathMin(MathMax(InpStopAtrMult * atr, InpMinSLUsd), InpMaxSLUsd); src = "ATR"; }
      else                    { d = InpMinSLUsd; src = "min-SL fallback"; }
      Log("WARN", "adopting position with no staged stop distance");
     }
   gSlDist    = d;
   gLogicalSL = isLong ? open - d : open + d;
   gPendingSlDist = 0.0;

   SaveState();
   Log("ENTRY",
       StringFormat("#%I64u %s %.2f lots @ %.2f  R=$%.2f (%s)  SL %.2f",
                    ticket, isLong ? "BUY" : "SELL", gInitVolume, open, d, src, gLogicalSL));
   PushStop(ticket, isLong, gLogicalSL, "entry stop");
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  12 · POSITION MANAGEMENT                   //
//==================================================================//
// Thresholds and sequencing are identical to v3.1. The differences are
// mechanical: addressed by ticket (F4), every request checked (F5),
// state persisted after each transition (F2), peak measured only from
// the entry forward (F11).
void ManagePosition(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket)) return;

   bool   isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double vol    = PositionGetDouble(POSITION_VOLUME);
   double R      = gSlDist;
   if(R <= 0.0) return;

   double close0 = iClose(_Symbol, PERIOD_M1, 1);
   if(!PriceOk(close0)) return;

   double prog = isLong ? (close0 - gEntryPrice) / R : (gEntryPrice - close0) / R;

   //--- F11: peak only from the entry bar forward
   datetime bt1 = iTime(_Symbol, PERIOD_M1, 1);
   if(bt1 >= gEntryTime)
     {
      double hi1 = iHigh(_Symbol, PERIOD_M1, 1);
      double lo1 = iLow(_Symbol, PERIOD_M1, 1);
      if(PriceOk(hi1) && PriceOk(lo1))
         gPeak = isLong ? MathMax(gPeak, hi1) : MathMin(gPeak, lo1);
     }
   double px = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(PriceOk(px)) gPeak = isLong ? MathMax(gPeak, px) : MathMin(gPeak, px);

   //--- +1.0R : bank a slice, stop to breakeven
   if(!gSt0 && prog >= 1.0)
     {
      gSt0 = true;
      double closeVol = MathFloor((vol * InpBankR0Pct / 100.0) / gLotStep) * gLotStep;
      if(closeVol >= gMinLot && vol - closeVol >= gMinLot)
        {
         trade.PositionClosePartial(ticket, NormalizeDouble(closeVol, 2));
         Sent(StringFormat("bank %.0f%% at +1.0R (%.2f lots)", InpBankR0Pct, closeVol));
        }
      else
         Log("SKIP partial", StringFormat("+1.0R slice %.2f not viable (vol %.2f, min %.2f)",
                                          closeVol, vol, gMinLot));
      gLogicalSL = gEntryPrice;
      PushStop(ticket, isLong, gLogicalSL, "breakeven at +1.0R");
      SaveState();
     }

   if(!PositionSelectByTicket(ticket)) { ClearTradeState(); return; }
   vol = PositionGetDouble(POSITION_VOLUME);

   //--- TP1 : second partial
   if(gSt0 && !gSt1 && prog >= InpTP1R)
     {
      gSt1 = true;
      double closeVol = MathFloor((vol * InpPartialPct / 100.0) / gLotStep) * gLotStep;
      if(closeVol >= gMinLot && vol - closeVol >= gMinLot)
        {
         trade.PositionClosePartial(ticket, NormalizeDouble(closeVol, 2));
         Sent(StringFormat("partial %.0f%% at TP1 %.2fR (%.2f lots)", InpPartialPct, InpTP1R, closeVol));
        }
      else
         Log("SKIP partial", StringFormat("TP1 slice %.2f not viable (vol %.2f)", closeVol, vol));
      SaveState();
     }

   //--- R-locks
   if(gSt1 && !gSt25 && prog >= 2.5)
     {
      gSt25 = true;
      gLogicalSL = isLong ? gEntryPrice + InpLock25R * R : gEntryPrice - InpLock25R * R;
      Log("LOCK", StringFormat("+2.5R reached -> lock %.2fR", InpLock25R));
      SaveState();
     }
   if(gSt25 && !gSt40 && prog >= 4.0)
     {
      gSt40 = true;
      gLogicalSL = isLong ? gEntryPrice + InpLock40R * R : gEntryPrice - InpLock40R * R;
      Log("LOCK", StringFormat("+4.0R reached -> lock %.2fR", InpLock40R));
      SaveState();
     }

   //--- runner give-back trail
   if(gSt40)
     {
      double gb  = MathAbs(gPeak - gEntryPrice) * InpRunnerGiveBack / 100.0;
      double rSL = isLong ? gPeak - gb : gPeak + gb;
      gLogicalSL = isLong ? MathMax(gLogicalSL, rSL) : MathMin(gLogicalSL, rSL);
     }

   //--- time stop on a flat trade
   if(InpUseTimeStop && !gSt0 && prog <= 0.0 &&
      gEntryTime > 0 && TimeCurrent() - gEntryTime >= InpTimeStopMin * 60)
     {
      trade.PositionClose(ticket);
      if(Sent(StringFormat("time stop after %d min flat", InpTimeStopMin)))
        { ClearTradeState(); return; }
     }

   //--- push the stop only when it improves
   if(PositionSelectByTicket(ticket))
     {
      double curSL = PositionGetDouble(POSITION_SL);
      double newSL = NormalizeDouble(gLogicalSL, _Digits);
      bool improve = isLong ? (curSL == 0.0 || newSL > curSL + _Point)
                            : (curSL == 0.0 || newSL < curSL - _Point);
      if(improve)
        {
         PushStop(ticket, isLong, newSL, "trail");
         SaveState();
        }
     }
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  13 · HUD  (chart heading)                  //
//==================================================================//
void HudLine(const string name, int row, const string text, color c)
  {
   string obj = GMC_TAG + "_hud_" + name;
   if(ObjectFind(0, obj) < 0)
     {
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, 12);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
      ObjectSetString(0, obj, OBJPROP_FONT, "Consolas");
     }
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, 16 + row * (InpHudFont + 7));
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, row == 0 ? InpHudFont + 3 : InpHudFont);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, c);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
  }

void DrawHUD()
  {
   if(!InpShowHUD) return;

   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double day = (gDayStartEq > 0.0) ? (eq - gDayStartEq) / gDayStartEq * 100.0 : 0.0;

   string state = "flat";
   if(gPosTicket > 0 && PositionSelectByTicket(gPosTicket))
     {
      bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double c1 = iClose(_Symbol, PERIOD_M1, 1);
      double prog = (gSlDist > 0.0 && PriceOk(c1))
                    ? (isLong ? (c1 - gEntryPrice) / gSlDist : (gEntryPrice - c1) / gSlDist) : 0.0;
      state = StringFormat("%s %.2f lots @ %.2f  %+.2fR  R=$%.2f  %s%s%s%s",
                           isLong ? "LONG" : "SHORT",
                           PositionGetDouble(POSITION_VOLUME), gEntryPrice, prog, gSlDist,
                           gSt0 ? "BE " : "", gSt1 ? "TP1 " : "",
                           gSt25 ? "L2.5 " : "", gSt40 ? "L4.0" : "");
     }
   else if(HasMyPending()) state = "pending stop order working";

   string guard = "";
   if(gHaltedDay)    guard += "DAY-HALT ";
   if(gLockedProfit) guard += "DAY-LOCK ";
   if(TimeCurrent() < gCooldownUntil) guard += "COOLDOWN ";
   if(guard == "") guard = "clear";

   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;

   HudLine("00", 0, GMC_NAME + "   v" + GMC_VER, InpHudColor);
   HudLine("01", 1, StringFormat("%s M1   magic %I64d", _Symbol, InpMagic), clrSilver);
   HudLine("02", 2, StringFormat("equity %.2f   day %+.2f%%   closed trades %d",
                                 eq, day, ArraySize(gTrades)), clrSilver);
   HudLine("03", 3, "position: " + state, clrSilver);
   HudLine("04", 4, "guards:   " + guard,
           (guard == "clear") ? clrSilver : clrOrange);
   HudLine("05", 5, StringFormat("spread %.0f pt (max %d)   risk %.2f%%%s",
                                 spread, InpMaxSpreadPips,
                                 InpUseKelly ? KellyRiskPct() : InpBaseRiskPct,
                                 InpUseKelly ? " kelly" : " flat"),
           (spread > InpMaxSpreadPips) ? clrOrange : clrSilver);
   HudLine("06", 6, StringFormat("blocked: spread %d  vol %d  gate %d  risk %d",
                                 gBlockedSpread, gBlockedVol, gBlockedGate, gBlockedRisk), clrSilver);
   HudLine("07", 7, gLastBlock == "" ? "" : "last block: " + gLastBlock, clrDimGray);
   ChartRedraw(0);
  }

void ClearHUD()
  { ObjectsDeleteAll(0, GMC_TAG + "_hud_"); }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  14 · INIT / DEINIT                         //
//==================================================================//
int OnInit()
  {
   OpenLog();

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_ERRORS);

   hEmaH1  = iMA(_Symbol, PERIOD_H1,  50, 0, MODE_EMA, PRICE_CLOSE);
   hEmaM15 = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   hEmaM5  = iMA(_Symbol, PERIOD_M5,  50, 0, MODE_EMA, PRICE_CLOSE);
   hATR    = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   if(hEmaH1 == INVALID_HANDLE || hEmaM15 == INVALID_HANDLE ||
      hEmaM5 == INVALID_HANDLE || hATR == INVALID_HANDLE)
     {
      Log("FATAL", "indicator handle creation failed");
      return INIT_FAILED;
     }

   gTickVal    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   gTickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   gMinLot     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   gMaxLot     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   gLotStep    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   gStopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int expMode = (int)SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
   gExpirySupported = (expMode & SYMBOL_EXPIRATION_SPECIFIED) != 0;

   if(gTickVal <= 0.0 || gTickSize <= 0.0 || gLotStep <= 0.0)
     {
      Log("FATAL", "symbol tick value / size / lot step unavailable");
      return INIT_FAILED;
     }

   gDayStartEq = AccountInfoDouble(ACCOUNT_EQUITY);
   MqlDateTime dt; TimeToStruct(TimeTradeServer(), dt);
   gDayOfMonth = dt.day;

   LoadPersistentCounters();
   MarkHistoryDirty();
   RebuildHistory();

   //--- adopt pre-existing history without replaying it into a cooldown
   int nh = ArraySize(gTrades);
   if(gLastCountedId == 0 && nh > 0)
     {
      gLastCountedId = gTrades[nh-1].posId;
      GlobalVariableSet(GKey("lastid"), (double)gLastCountedId);
      Log("HISTORY", StringFormat("adopted %d pre-existing closed trades; streak starts clean", nh));
     }

   ulong t = FindMyPosition();
   if(t > 0) AdoptPosition(t);                       // F2: pick the trade back up

   Log("INIT", StringFormat("tickVal %.4f tickSize %.4f point %.4f digits %d stopsLevel %d "
                            "minLot %.2f step %.2f expirySpecified %s | risk %.2f%% kelly %s "
                            "maxSpread %d | closed trades on record %d",
                            gTickVal, gTickSize, _Point, _Digits, gStopsLevel,
                            gMinLot, gLotStep, gExpirySupported ? "yes" : "no",
                            InpBaseRiskPct, InpUseKelly ? "ON" : "OFF",
                            InpMaxSpreadPips, ArraySize(gTrades)));
   DrawHUD();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   Log("DEINIT", StringFormat("reason=%d - state persisted, positions untouched", reason));
   SaveState();
   ClearHUD();
   if(gLogHandle != INVALID_HANDLE) { FileClose(gLogHandle); gLogHandle = INVALID_HANDLE; }
  }

//--- F7: history is only rebuilt when the server says it changed
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   if(trans.symbol != _Symbol && trans.symbol != "") return;
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD ||
      trans.type == TRADE_TRANSACTION_HISTORY_ADD)
      MarkHistoryDirty();
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  15 · MAIN LOOP                             //
//==================================================================//
void OnTick()
  {
   //--- (a) every tick: keep the open position protected. This is F1.
   ulong ticket = FindMyPosition();
   if(ticket > 0)
     {
      AdoptPosition(ticket);
      EnsureProtectiveStop(ticket);
      if(InpManageOnTick) ManagePosition(ticket);
     }
   else if(gPosTicket != 0)
     {
      Log("EXIT", StringFormat("#%I64u no longer open - clearing trade state", gPosTicket));
      ClearTradeState();
      MarkHistoryDirty();
     }

   //--- (b) everything else is bar-gated, exactly as v3.1 was
   if(!NewM1Bar()) return;
   if(!EnoughBars()) { Log("WAIT", "insufficient bar history on one or more timeframes"); return; }

   RebuildHistory();
   UpdateStreak();

   //--- daily reset & protection ------------------------------------
   MqlDateTime dt; TimeToStruct(TimeTradeServer(), dt);
   if(dt.day != gDayOfMonth)
     {
      gDayOfMonth   = dt.day;
      gDayStartEq   = AccountInfoDouble(ACCOUNT_EQUITY);
      gHaltedDay    = false;
      gLockedProfit = false;
      gConsecLosses = 0;
      Log("NEW DAY", StringFormat("day start equity %.2f", gDayStartEq));
     }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!gHaltedDay && eq - gDayStartEq <= -gDayStartEq * InpDailyLossPct / 100.0)
     {
      gHaltedDay = true;
      Log("DAY HALT", StringFormat("equity %.2f is %.2f%% below day start %.2f - no new entries today",
                                   eq, (eq - gDayStartEq) / gDayStartEq * 100.0, gDayStartEq));
     }
   bool hasPos = (ticket > 0);
   if(!hasPos && !gLockedProfit && eq - gDayStartEq >= gDayStartEq * InpDailyLockPct / 100.0)
     {
      gLockedProfit = true;
      Log("DAY LOCK", StringFormat("equity %.2f is +%.2f%% on the day - profit locked",
                                   eq, (eq - gDayStartEq) / gDayStartEq * 100.0));
     }
   bool inCooldown = (TimeCurrent() < gCooldownUntil);

   //--- pending expiry safety net -----------------------------------
   if(!hasPos && HasMyPending() && gPendPlaced > 0 &&
      TimeCurrent() - gPendPlaced >= InpPendExpiry * 60)
     {
      CancelMyPendings("local expiry");
      gPendPlaced = 0;
      gPendingSlDist = 0.0;
     }

   //--- manage, then stop (never sign a new trade with one open) ----
   if(hasPos) { ManagePosition(ticket); DrawHUD(); return; }

   DrawHUD();
   LookForEntry(dt, eq, inCooldown);
  }

//==================================================================//
//  GMC EXCLUSIVE ONE  ·  16 · SIGNAL + ENTRY                        //
//==================================================================//
// The signal block below is unchanged from v3.1 apart from validity
// guards (F6/F8) and the fact that every rejection is now logged.
void Block(const string why, int &counter)
  {
   counter++;
   gLastBlock = why;
   if(InpLogBlocked) Log("BLOCKED", why);
  }

void LookForEntry(const MqlDateTime &dt, double eq, bool inCooldown)
  {
   //--- closed-bar M1 facts ---------------------------------------
   double o1 = iOpen(_Symbol, PERIOD_M1, 1), h1 = iHigh(_Symbol, PERIOD_M1, 1);
   double l1 = iLow (_Symbol, PERIOD_M1, 1), c1 = iClose(_Symbol, PERIOD_M1, 1);
   double h3 = iHigh(_Symbol, PERIOD_M1, 3), l3 = iLow  (_Symbol, PERIOD_M1, 3);
   if(!PriceOk(o1) || !PriceOk(h1) || !PriceOk(l1) || !PriceOk(c1) ||
      !PriceOk(h3) || !PriceOk(l3)) return;

   double rng     = h1 - l1;
   double bodyPct = (rng > 0.0) ? MathAbs(c1 - o1) / rng * 100.0 : 0.0;
   bool   bullC   = (c1 > o1);

   //--- F6: -1 from iHighest/iLowest used to become price 0.0, and
   //--- "close > 0" is true for every price - a signal from nothing.
   int hhIx  = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, InpMomLookback, 2);
   int llIx  = iLowest (_Symbol, PERIOD_M1, MODE_LOW,  InpMomLookback, 2);
   int hh5Ix = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, 5, 2);
   int ll5Ix = iLowest (_Symbol, PERIOD_M1, MODE_LOW,  5, 2);
   if(hhIx < 0 || llIx < 0 || hh5Ix < 0 || ll5Ix < 0)
     { Log("DATA", "iHighest/iLowest returned -1 - bar skipped"); return; }

   double hh  = iHigh(_Symbol, PERIOD_M1, hhIx);
   double ll  = iLow (_Symbol, PERIOD_M1, llIx);
   double hh5 = iHigh(_Symbol, PERIOD_M1, hh5Ix);
   double ll5 = iLow (_Symbol, PERIOD_M1, ll5Ix);
   if(!PriceOk(hh) || !PriceOk(ll) || !PriceOk(hh5) || !PriceOk(ll5)) return;

   //--- signal classes --------------------------------------------
   bool sigBreakBull = InpEnableBreak && bodyPct >= InpMinBodyPct &&  bullC && c1 > hh;
   bool sigBreakBear = InpEnableBreak && bodyPct >= InpMinBodyPct && !bullC && c1 < ll;
   bool sigFVGBull   = InpEnableFVG   && l1 > h3 &&  bullC;
   bool sigFVGBear   = InpEnableFVG   && h1 < l3 && !bullC;
   bool sigSwpBull   = InpEnableSweep && l1 < ll5 && c1 > ll5 &&  bullC;
   bool sigSwpBear   = InpEnableSweep && h1 > hh5 && c1 < hh5 && !bullC;

   bool rawBull = sigBreakBull || sigFVGBull || sigSwpBull;
   bool rawBear = sigBreakBear || sigFVGBear || sigSwpBear;
   if(!rawBull && !rawBear) return;

   string sigClass = (sigBreakBull || sigBreakBear) ? "BREAK"
                   : (sigFVGBull   || sigFVGBear)   ? "FVG" : "SWEEP";

   //--- MTF gates, shift=1 (the v3.1 anti-repaint fix, unchanged) ---
   // F8: a failed EMA read used to be 0.0, which made the bullish gate
   // "close > 0" pass. Now a failed read kills the bar.
   double emaH1v, emaM15v, emaM5v;
   if(!BufOk(hEmaH1, 1, emaH1v) || !BufOk(hEmaM15, 1, emaM15v) || !BufOk(hEmaM5, 1, emaM5v))
     { Log("DATA", "MTF EMA read failed - bar skipped (v3.1 would have traded on EMA=0)"); return; }

   double cM15 = iClose(_Symbol, PERIOD_M15, 1);
   double cM5  = iClose(_Symbol, PERIOD_M5,  1);
   if(!PriceOk(cM15) || !PriceOk(cM5))
     { Log("DATA", "MTF close read failed - bar skipped"); return; }

   bool gateBull = (!InpUseH1Filter  || c1   > emaH1v)
                && (!InpUseM15Filter || cM15 > emaM15v)
                && (!InpUseM5Confirm || cM5  > emaM5v);
   bool gateBear = (!InpUseH1Filter  || c1   < emaH1v)
                && (!InpUseM15Filter || cM15 < emaM15v)
                && (!InpUseM5Confirm || cM5  < emaM5v);

   //--- Kaufman ER regime gate -------------------------------------
   double cEr = iClose(_Symbol, PERIOD_M1, InpERPeriod + 1);
   if(!PriceOk(cEr)) return;
   double num = MathAbs(c1 - cEr);
   double den = 0.0;
   for(int i = 1; i <= InpERPeriod; i++)
     {
      double a = iClose(_Symbol, PERIOD_M1, i);
      double b = iClose(_Symbol, PERIOD_M1, i + 1);
      if(!PriceOk(a) || !PriceOk(b)) return;
      den += MathAbs(a - b);
     }
   double er = (den > 0.0) ? num / den : 0.0;
   bool regimeOK = (!InpUseRegime || er >= InpERMin);

   bool longSig  = rawBull && gateBull && regimeOK;
   bool shortSig = rawBear && gateBear && regimeOK && InpSellsEnabled;
   if(!longSig && !shortSig)
     {
      Block(StringFormat("%s %s killed by %s (ER %.2f)", sigClass, rawBull ? "bull" : "bear",
                         !regimeOK ? "regime" : "MTF gate", er), gBlockedGate);
      return;
     }

   //--- strength & stop distance -----------------------------------
   double atrNow, atrOld;
   if(!BufOk(hATR, 1, atrNow))
     { Log("DATA", "ATR read failed - bar skipped (v3.1 would have used the min stop)"); return; }
   if(!BufOk(hATR, 11, atrOld)) atrOld = atrNow;

   double decis = (sigClass == "BREAK") ? (rawBull ? c1 - hh  : ll  - c1)
                : (sigClass == "FVG")   ? (rawBull ? l1 - h3  : l3  - h1)
                :                         (rawBull ? c1 - ll5 : hh5 - c1);
   int strength = (bodyPct >= 70 ? 1 : 0)
                + ((rng > 0.0 && decis >= 0.30 * rng) ? 1 : 0)
                + (atrNow > atrOld ? 1 : 0);

   double slDist0 = InpStopAtrMult * atrNow;
   double slDist  = MathMin(MathMax(slDist0, InpMinSLUsd), InpMaxSLUsd);
   bool volTooHot = (slDist0 > InpMaxSLUsd);

   //--- gates, each logged separately so its cost is measurable -----
   bool inSession = (InpSesStart == 0 && InpSesEnd == 24)
                    ? true : (dt.hour >= InpSesStart && dt.hour < InpSesEnd);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!PriceOk(ask) || !PriceOk(bid)) return;
   double spreadPts = (ask - bid) / _Point;

   if(!inSession)  { Block("outside session", gBlockedGate); return; }
   if(gHaltedDay)  { Block("daily loss halt active", gBlockedGate); return; }
   if(gLockedProfit) { Block("daily profit lock active", gBlockedGate); return; }
   if(inCooldown)  { Block(StringFormat("cooldown until %s",
                          TimeToString(gCooldownUntil, TIME_MINUTES)), gBlockedGate); return; }
   if(HasMyPending()) { Block("pending order already working", gBlockedGate); return; }
   if(volTooHot)   { Block(StringFormat("%s S%d skipped: 1.5xATR $%.2f > max SL $%.2f",
                          sigClass, strength, slDist0, InpMaxSLUsd), gBlockedVol); return; }
   if(spreadPts > InpMaxSpreadPips)
     { Block(StringFormat("%s S%d skipped: spread %.0f pt > max %d",
             sigClass, strength, spreadPts, InpMaxSpreadPips), gBlockedSpread); return; }

   //--- sizing ------------------------------------------------------
   double strengthMult = (strength >= 3) ? InpStrongMult : (strength <= 1) ? 0.5 : 1.0;
   double riskPct = KellyRiskPct() * strengthMult;
   double riskUsd = eq * riskPct / 100.0;
   bool   isLong  = longSig;
   double refPx   = isLong ? ask : bid;

   double lots = LotsForRisk(riskUsd, slDist, isLong, refPx);
   if(lots <= 0.0) return;                       // already logged inside

   string cm = StringFormat("%s %s S%d", GMC_TAG, sigClass, strength);
   gPendingSlDist = slDist;                       // staged for AdoptPosition / F1 guard

   Log("SIGNAL",
       StringFormat("%s %s S%d | ER %.2f body %.0f%% | R $%.2f | risk %.2f%% ($%.2f) | %.2f lots | spread %.0f pt",
                    sigClass, isLong ? "LONG" : "SHORT", strength, er, bodyPct,
                    slDist, riskPct, riskUsd, lots, spreadPts));

   PlaceEntry(isLong, lots, c1, slDist, ask, bid, cm);
  }

//------------------------------------------------------------------//
//  F1: the protective stop travels WITH the order request.          //
//------------------------------------------------------------------//
void PlaceEntry(bool isLong, double lots, double c1, double slDist,
                double ask, double bid, const string cm)
  {
   double gap = MinStopDist();

   if(InpUsePending)
     {
      double px = isLong ? c1 + InpEntryOffsetUsd : c1 - InpEntryOffsetUsd;
      //--- a stop order must sit beyond the market by at least stopsLevel
      if(isLong  && px <= ask + gap) px = ask + gap + 2 * _Point;
      if(!isLong && px >= bid - gap) px = bid - gap - 2 * _Point;
      px = NormalizeDouble(px, _Digits);

      double sl = NormalizeDouble(isLong ? px - slDist : px + slDist, _Digits);

      datetime exp = 0;
      ENUM_ORDER_TYPE_TIME tt = ORDER_TIME_GTC;
      if(gExpirySupported && InpPendExpiry > 0)
        { tt = ORDER_TIME_SPECIFIED; exp = TimeCurrent() + InpPendExpiry * 60; }

      bool ok = isLong ? trade.BuyStop (lots, px, _Symbol, sl, 0.0, tt, exp, cm)
                       : trade.SellStop(lots, px, _Symbol, sl, 0.0, tt, exp, cm);
      Sent(StringFormat("%sStop %.2f lots @ %.2f SL %.2f", isLong ? "Buy" : "Sell", lots, px, sl));
      if(ok) gPendPlaced = TimeCurrent();
      else   gPendingSlDist = 0.0;
      return;
     }

   //--- market entry: stop derived from the live price, corrected to
   //--- the true fill by AdoptPosition on the next tick
   double ref = isLong ? ask : bid;
   double sl  = NormalizeDouble(isLong ? ref - slDist : ref + slDist, _Digits);
   sl = SafeStop(isLong, sl);

   bool ok = isLong ? trade.Buy (lots, _Symbol, 0.0, sl, 0.0, cm)
                    : trade.Sell(lots, _Symbol, 0.0, sl, 0.0, cm);
   Sent(StringFormat("%s market %.2f lots SL %.2f", isLong ? "Buy" : "Sell", lots, sl));
   if(!ok) gPendingSlDist = 0.0;
  }
//+------------------------------------------------------------------+
//|                  end of GMC EXCLUSIVE ONE                        |
//+------------------------------------------------------------------+
