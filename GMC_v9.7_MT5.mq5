//+------------------------------------------------------------------+
//|                 GMC — G MONEY CORE v9.7 (MT5 EDITION)            |
//|  Native MQL5 port of Pine "G MONEY CORE v9.7 - LADDER EDITION"   |
//|  Chart: XAUUSD M15. The EA reads M15 signals itself — attach     |
//|  to any XAUUSD chart and it will use M15 data regardless.        |
//|                                                                  |
//|  Carries the full v9.7 risk engine:                              |
//|   - Risk-% sizing with hard notional leverage cap and low-vol    |
//|     sizing floor; if the broker minimum lot would over-risk      |
//|     the account the trade is SKIPPED, never force-sized          |
//|   - Real stop loss on every ticket at placement                  |
//|   - Profit ladder: TP1 33% @1.2R -> SL to BE+0.3xATR,            |
//|     TP2 33% @3R, runner trails 3.2xATR after 2.2R, TP 9R         |
//|   - LOSS FLOOR (flatten at -0.6% equity open loss)               |
//|   - EARLY ABORT (4 bars, worse than -0.45R, never ahead +0.3R)   |
//|   - TIME STOP (18 bars without reaching +0.5R)                   |
//|   - Drawdown governor: risk taper 50%/75%, daily 3% halt,        |
//|     monthly 8% halt, max 2 losing trades/day, hard               |
//|     flatten-and-freeze at 20% drawdown from peak equity          |
//+------------------------------------------------------------------+
#property copyright "G Money Systems"
#property version   "9.70"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//+------------------------------------------------------------------+
// INPUTS
//+------------------------------------------------------------------+
input group "--- Identity ---"
input int    Magic_Number       = 10097;
input int    Slippage_Points    = 20;

input group "--- Capital Allocation ---"
input double Risk_Percent       = 1.0;    // True risk % per trade
input double Daily_Loss_Limit   = 3.0;    // Daily max loss %
input double Max_Leverage       = 3.0;    // Max notional leverage (x equity)

input group "--- Drawdown Governor ---"
input double Monthly_Loss_Limit = 8.0;    // Monthly max loss %
input double DD_Scale_Start     = 5.0;    // Cut risk 50% at this drawdown %
input double DD_Scale_Deep      = 10.0;   // Cut risk 75% at this drawdown %
input double Hard_Stop_DD       = 20.0;   // HARD STOP: flatten & halt at drawdown %

input group "--- Core Filters (M15) ---"
input int    MA_Period          = 50;
input int    RSI_Period         = 14;
input int    Vol_Period         = 20;
input double Vol_Mult           = 1.8;    // Volume surge multiplier
input double Wick_Threshold     = 62.0;   // Min rejection wick %
input double Body_Threshold     = 33.0;   // Max candle body %
input double Max_Ext_ATR        = 3.0;    // Max distance from MA50 (x ATR)
input double Vola_ATR_Mult      = 6.0;    // Max 15-bar range (x ATR)
input double ATR_SL_Mult        = 1.8;    // Stop loss (x ATR14)
input double ATR_Trail_Mult     = 3.2;    // Trailing distance (x ATR14)

input group "--- Win Rate Control ---"
input bool   Use_Buffer         = true;   // MA buffer zone (0.35 x ATR)
input bool   Filter_Small_Wicks = true;
input int    Min_Score          = 6;      // Confluence score required (max 6)
input int    Cooldown_Bars      = 12;     // M15 bars after a closed trade
input bool   Use_Confirm_Bar    = true;   // Two same-direction closes
input int    Max_Daily_Losses   = 2;      // Losing trades per day -> flat till tomorrow
input int    Time_Stop_Bars     = 18;     // M15 bars
input double Time_Stop_Min_R    = 0.5;    // Progress threshold (x SL)

input group "--- Session (GMT) ---"
input bool   Use_Overlap_Only   = true;   // London-NY overlap only
input int    Overlap_Start_GMT  = 12;
input int    Overlap_End_GMT    = 17;

input group "--- Loss Floor & Early Abort ---"
input bool   Use_Loss_Floor     = true;
input double Max_Trade_Loss_Pct = 0.6;    // Flatten if open loss exceeds this % of equity
input bool   Use_Early_Abort    = true;
input int    Abort_Bars         = 4;
input double Abort_Adverse_R    = 0.45;
input double Abort_FE_R         = 0.30;

input group "--- Exit Ladder ---"
input double BE_Premium_ATR     = 0.3;    // Breakeven premium (x ATR)
input double TP1_R              = 1.2;    // TP1 target (x SL) — banks first 33%
input double TP2_R              = 3.0;    // TP2 target (x SL) — banks second 33%
input double TP3_R              = 9.0;    // Runner ticket TP (x SL)
input double Trail_Arm_R        = 2.2;    // Trailing arms at this profit (x SL)
input double Partial_Pct        = 33.0;   // Partial close % at TP1 and TP2

input group "--- H4 Bias Gate ---"
input bool   Use_H4_Gate        = true;

input group "--- Cascade System ---"
input bool   Use_Cascade        = true;
input double Cascade_Pip_1     = 20.0;
input double Cascade_Pip_2     = 30.0;
input double Cascade_Pip_3     = 50.0;
input int    Cascade_Bars      = 4;
input double Cascade_Vol       = 2.0;
input int    Cascade_Cooldown  = 6;       // M15 bars

//+------------------------------------------------------------------+
// GLOBAL STATE
//+------------------------------------------------------------------+
int      hATR14, hATR100, hMA50, hRSI, hMA_H4;
double   pipMult;
datetime lastSignalBar   = 0;

// Account protection
double   dayStartEquity   = 0.0;
double   monthStartEquity = 0.0;
double   peakEquity       = 0.0;
int      lossesToday      = 0;
bool     halted           = false;
int      lastDay          = -1;
int      lastMonth        = -1;
datetime lastCloseTime    = 0;

// Per-trade state
double   entryPrice   = 0.0;
double   riskAtEntry  = 0.0;   // SL distance in price at entry
double   maxFav       = 0.0;   // best favorable excursion (price)
datetime entryTime    = 0;
double   initialLots  = 0.0;
bool     tp1Done      = false;
bool     tp2Done      = false;
bool     beArmed      = false;
bool     trailOn      = false;

//+------------------------------------------------------------------+
void Log(string s) { Print("GMC v9.7 | " + s); }

//+------------------------------------------------------------------+
int OnInit()
{
   pipMult  = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;

   hATR14  = iATR(_Symbol, PERIOD_M15, 14);
   hATR100 = iATR(_Symbol, PERIOD_M15, 100);
   hMA50   = iMA(_Symbol, PERIOD_M15, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
   hRSI    = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
   hMA_H4  = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_SMA, PRICE_CLOSE);

   if(hATR14==INVALID_HANDLE || hATR100==INVALID_HANDLE || hMA50==INVALID_HANDLE ||
      hRSI==INVALID_HANDLE   || hMA_H4==INVALID_HANDLE)
   { Log("indicator init failed"); return INIT_FAILED; }

   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(Slippage_Points);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartEquity   = eq;
   monthStartEquity = eq;
   peakEquity       = eq;

   Log("initialized — GMC G MONEY CORE v9.7 MT5 edition ready");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hATR14); IndicatorRelease(hATR100);
   IndicatorRelease(hMA50);  IndicatorRelease(hRSI); IndicatorRelease(hMA_H4);
}

//+------------------------------------------------------------------+
// Helpers
//+------------------------------------------------------------------+
bool GetBuf(int handle, int shift, int count, double &out[])
{
   ArraySetAsSeries(out, true);
   return CopyBuffer(handle, 0, shift, count, out) == count;
}

double NormalizeLots(double lots)
{
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / vstep) * vstep;
   if(lots > vmax) lots = vmax;
   if(lots < vmin) return 0.0;   // SKIP — never force the broker minimum
   return NormalizeDouble(lots, 2);
}

bool PositionOpen()
{
   if(!PositionSelect(_Symbol)) return false;
   return (long)PositionGetInteger(POSITION_MAGIC) == Magic_Number;
}

int BarsInTrade()
{
   if(entryTime == 0) return 0;
   return (int)((TimeCurrent() - entryTime) / (15 * 60));
}

int BarsSinceClose()
{
   if(lastCloseTime == 0) return 99999;
   return (int)((TimeCurrent() - lastCloseTime) / (15 * 60));
}

void ResetTradeState()
{
   entryPrice = 0; riskAtEntry = 0; maxFav = 0; entryTime = 0; initialLots = 0;
   tp1Done = false; tp2Done = false; beArmed = false; trailOn = false;
}

//+------------------------------------------------------------------+
// Account protection — daily/monthly/drawdown governor
//+------------------------------------------------------------------+
double DDRiskScale()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > peakEquity) peakEquity = eq;
   double dd = (peakEquity - eq) / peakEquity * 100.0;
   if(dd >= DD_Scale_Deep)  return 0.25;
   if(dd >= DD_Scale_Start) return 0.50;
   return 1.0;
}

bool TradingAllowed()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   // day / month rollover (GMT)
   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   if(t.day != lastDay)
   {
      lastDay = t.day;
      dayStartEquity = eq;
      lossesToday = 0;
   }
   if(t.mon != lastMonth)
   {
      lastMonth = t.mon;
      monthStartEquity = eq;
   }

   if(eq > peakEquity) peakEquity = eq;
   double dd = (peakEquity - eq) / peakEquity * 100.0;

   // HARD STOP — flatten and freeze
   if(!halted && dd >= Hard_Stop_DD)
   {
      halted = true;
      Log("HARD STOP — max drawdown reached, flattening and freezing");
      if(PositionOpen()) trade.PositionClose(_Symbol);
   }
   if(halted) return false;

   if((dayStartEquity - eq)   >= dayStartEquity   * Daily_Loss_Limit   / 100.0) return false;
   if((monthStartEquity - eq) >= monthStartEquity * Monthly_Loss_Limit / 100.0) return false;
   if(lossesToday >= Max_Daily_Losses) return false;
   return true;
}

bool InSession()
{
   if(!Use_Overlap_Only) return true;
   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   return (t.hour >= Overlap_Start_GMT && t.hour < Overlap_End_GMT);
}

//+------------------------------------------------------------------+
// Position sizing — risk-first, leverage-capped, never force-sized
//+------------------------------------------------------------------+
double CalcLots(double slDist, double atr100)
{
   double eq        = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash  = eq * (Risk_Percent * DDRiskScale() / 100.0);
   double sizeDist  = MathMax(slDist, atr100 * 0.6 * ATR_SL_Mult); // low-vol floor

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0 || tickSize <= 0) return 0.0;

   double lossPerLot = sizeDist / tickSize * tickVal;
   if(lossPerLot <= 0) return 0.0;
   double lots = riskCash / lossPerLot;

   // hard notional leverage cap
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double price    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double capLots  = (eq * Max_Leverage) / (contract * price);
   lots = MathMin(lots, capLots);

   return NormalizeLots(lots);
}

//+------------------------------------------------------------------+
// SIGNAL ENGINE — evaluated once per new M15 bar
//+------------------------------------------------------------------+
void CheckSignals()
{
   datetime curBar = iTime(_Symbol, PERIOD_M15, 0);
   if(curBar == lastSignalBar) return;
   lastSignalBar = curBar;

   if(PositionOpen() || !TradingAllowed() || !InSession()) return;
   if(BarsSinceClose() < Cooldown_Bars && BarsSinceClose() < Cascade_Cooldown) return;

   // --- data (shift 1 = last closed M15 bar)
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 20, r) < 20) return;

   double atr14[], atr100[], ma[], rsi[], maH4[];
   if(!GetBuf(hATR14, 1, 2, atr14))   return;
   if(!GetBuf(hATR100, 1, 2, atr100)) return;
   if(!GetBuf(hMA50, 1, 14, ma))      return;
   if(!GetBuf(hRSI, 1, 2, rsi))       return;
   if(!GetBuf(hMA_H4, 0, 5, maH4))    return;

   double atr  = atr14[0];
   double ma50 = ma[0];
   double c1 = r[1].close, o1 = r[1].open, h1 = r[1].high, l1 = r[1].low;

   // --- H4 bias
   double h4close = iClose(_Symbol, PERIOD_H4, 0);
   bool h4Bull = !Use_H4_Gate || (h4close > maH4[0] && maH4[0] > maH4[3]);
   bool h4Bear = !Use_H4_Gate || (h4close < maH4[0] && maH4[0] < maH4[3]);

   // --- trend + stability (5 closed bars beyond buffer)
   double buf = Use_Buffer ? atr * 0.35 : 0.0;
   bool trendBuyStable = true, trendSellStable = true;
   for(int i = 1; i <= 5; i++)
   {
      if(!(r[i].close > ma50 + buf)) trendBuyStable  = false;
      if(!(r[i].close < ma50 - buf)) trendSellStable = false;
   }
   bool slopeUp   = ma50 > ma[12];
   bool slopeDown = ma50 < ma[12];

   // --- candle quality
   double range = h1 - l1;
   if(range <= 0) return;
   double lowerWick = MathMin(o1, c1) - l1;
   double upperWick = h1 - MathMax(o1, c1);
   double body      = MathAbs(c1 - o1);
   double avgRange  = 0; for(int i = 1; i <= 5; i++) avgRange += (r[i].high - r[i].low); avgRange /= 5.0;
   bool sizeOk = !Filter_Small_Wicks || (range > avgRange * 0.75);
   bool bullRej = (lowerWick / range * 100.0 >= Wick_Threshold) && (body / range * 100.0 <= Body_Threshold) && sizeOk;
   bool bearRej = (upperWick / range * 100.0 >= Wick_Threshold) && (body / range * 100.0 <= Body_Threshold) && sizeOk;

   // --- volume (tick volume)
   long avgVol = 0; for(int i = 1; i <= Vol_Period; i++) avgVol += (long)r[i].tick_volume; avgVol /= Vol_Period;
   bool volConfirmed = (double)r[1].tick_volume >= avgVol * Vol_Mult;
   bool cascVolOk    = (double)r[1].tick_volume >= avgVol * Cascade_Vol;

   // --- RSI windows with the v9.3 caps
   double rv = rsi[0];
   bool rsiBull = h4Bull ? (rv >= 45 && rv <= 65) : (rv >= 40 && rv <= 60);
   bool rsiBear = h4Bear ? (rv >= 35 && rv <= 55) : (rv >= 40 && rv <= 60);

   // --- volatility guard + extension filter
   double hh15 = r[1].high, ll15 = r[1].low;
   for(int i = 2; i <= 15; i++) { hh15 = MathMax(hh15, r[i].high); ll15 = MathMin(ll15, r[i].low); }
   bool volaOk      = (hh15 - ll15) <= Vola_ATR_Mult * atr;
   bool notExtended = MathAbs(c1 - ma50) <= Max_Ext_ATR * atr;

   // --- confluence scores
   int bullScore = (trendBuyStable?1:0) + (bullRej?1:0) + (volConfirmed?1:0) + (rsiBull?1:0) + (slopeUp?1:0)   + (h4Bull?1:0);
   int bearScore = (trendSellStable?1:0)+ (bearRej?1:0) + (volConfirmed?1:0) + (rsiBear?1:0) + (slopeDown?1:0) + (h4Bear?1:0);

   bool bullConfirmed = !Use_Confirm_Bar || (r[1].close > r[1].open && r[2].close > r[2].open);
   bool bearConfirmed = !Use_Confirm_Bar || (r[1].close < r[1].open && r[2].close < r[2].open);

   bool mainCoolOk = BarsSinceClose() >= Cooldown_Bars;
   bool buySignal  = bullScore >= Min_Score && bullConfirmed && volaOk && notExtended && mainCoolOk;
   bool sellSignal = bearScore >= Min_Score && bearConfirmed && volaOk && notExtended && mainCoolOk;

   // --- cascade
   double moveDown = 0, moveUp = 0;
   {
      double hh = r[1].high, ll = r[1].low;
      for(int i = 2; i <= Cascade_Bars; i++) { hh = MathMax(hh, r[i].high); ll = MathMin(ll, r[i].low); }
      moveDown = (hh - c1) / pipMult;
      moveUp   = (c1 - ll) / pipMult;
   }
   bool cascSizeOk = range > avgRange * 1.2;
   bool cascCoolOk = BarsSinceClose() >= Cascade_Cooldown;
   bool cascSell = Use_Cascade && cascCoolOk && cascVolOk && h4Bear && rv < 50 && c1 < ma50 && notExtended &&
                   ((moveDown >= Cascade_Pip_1 && cascSizeOk) || moveDown >= Cascade_Pip_3);
   bool cascBuy  = Use_Cascade && cascCoolOk && cascVolOk && h4Bull && rv > 50 && c1 > ma50 && notExtended &&
                   ((moveUp >= Cascade_Pip_1 && cascSizeOk) || moveUp >= Cascade_Pip_3);

   bool finalBuy  = buySignal  || cascBuy;
   bool finalSell = sellSignal || cascSell;
   if(!finalBuy && !finalSell) return;

   // --- sizing and entry with SL/TP on the ticket
   double slDist = atr * ATR_SL_Mult;
   double lots   = CalcLots(slDist, atr100[0]);
   if(lots <= 0) { Log("trade skipped — sizing below broker minimum or invalid"); return; }

   if(finalBuy)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = ask - slDist;
      double tp  = ask + slDist * TP3_R;
      if(trade.Buy(lots, _Symbol, ask, sl, tp, "GMC LONG v9.7"))
      {
         entryPrice = ask; riskAtEntry = slDist; entryTime = TimeCurrent();
         initialLots = lots; maxFav = 0; tp1Done = false; tp2Done = false; beArmed = false; trailOn = false;
         Log(StringFormat("LONG %.2f lots | SL %.2f | risk %.2f", lots, sl, slDist));
      }
   }
   else if(finalSell)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = bid + slDist;
      double tp  = bid - slDist * TP3_R;
      if(trade.Sell(lots, _Symbol, bid, sl, tp, "GMC SHORT v9.7"))
      {
         entryPrice = bid; riskAtEntry = slDist; entryTime = TimeCurrent();
         initialLots = lots; maxFav = 0; tp1Done = false; tp2Done = false; beArmed = false; trailOn = false;
         Log(StringFormat("SHORT %.2f lots | SL %.2f | risk %.2f", lots, sl, slDist));
      }
   }
}

//+------------------------------------------------------------------+
// TRADE MANAGEMENT — every tick
//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!PositionOpen()) { if(entryTime != 0) { lastCloseTime = TimeCurrent(); ResetTradeState(); } return; }
   if(riskAtEntry <= 0 || entryPrice <= 0) return;   // EA restarted mid-trade: ticket SL/TP still protect

   bool   isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double vol    = PositionGetDouble(POSITION_VOLUME);
   double curSL  = PositionGetDouble(POSITION_SL);
   double curTP  = PositionGetDouble(POSITION_TP);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price  = isLong ? bid : ask;
   double profitDist = isLong ? (price - entryPrice) : (entryPrice - price);
   maxFav = MathMax(maxFav, profitDist);

   double atr[]; if(!GetBuf(hATR14, 0, 1, atr)) return;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double openPnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

   // G. LOSS FLOOR
   if(Use_Loss_Floor && openPnl <= -(eq * Max_Trade_Loss_Pct / 100.0))
   { Log("LOSS FLOOR — flattening"); trade.PositionClose(_Symbol); return; }

   // H. EARLY ABORT
   if(Use_Early_Abort && !beArmed && BarsInTrade() >= Abort_Bars &&
      profitDist <= -riskAtEntry * Abort_Adverse_R && maxFav < riskAtEntry * Abort_FE_R)
   { Log("EARLY ABORT — never got going"); trade.PositionClose(_Symbol); return; }

   // E. TIME STOP
   if(!beArmed && BarsInTrade() >= Time_Stop_Bars && profitDist < riskAtEntry * Time_Stop_Min_R)
   { Log("TIME STOP — stalled trade cut"); trade.PositionClose(_Symbol); return; }

   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   // I. TP1 — bank first 33%, stop to BE + premium
   if(!tp1Done && profitDist >= riskAtEntry * TP1_R)
   {
      double closeVol = NormalizeLots(initialLots * Partial_Pct / 100.0);
      if(closeVol >= vmin && closeVol < vol) trade.PositionClosePartial(_Symbol, closeVol);
      double newSL = isLong ? entryPrice + atr[0] * BE_Premium_ATR : entryPrice - atr[0] * BE_Premium_ATR;
      if((isLong && newSL > curSL) || (!isLong && (newSL < curSL || curSL == 0)))
         trade.PositionModify(_Symbol, NormalizeDouble(newSL, _Digits), curTP);
      tp1Done = true; beArmed = true;
      Log("TP1 banked 33% @1.2R — stop locked at breakeven+premium");
   }

   // TP2 — bank second 33%
   if(tp1Done && !tp2Done && profitDist >= riskAtEntry * TP2_R)
   {
      if(PositionSelect(_Symbol))
      {
         vol = PositionGetDouble(POSITION_VOLUME);
         double closeVol = NormalizeLots(initialLots * Partial_Pct / 100.0);
         if(closeVol >= vmin && closeVol < vol) trade.PositionClosePartial(_Symbol, closeVol);
         tp2Done = true;
         Log("TP2 banked 33% @3R — runner trailing");
      }
   }

   // Trailing — arms at 2.2R, ratchets at 3.2xATR, never loosens
   if(profitDist >= riskAtEntry * Trail_Arm_R) trailOn = true;
   if(trailOn && PositionSelect(_Symbol))
   {
      curSL = PositionGetDouble(POSITION_SL);
      curTP = PositionGetDouble(POSITION_TP);
      double newSL = isLong ? price - atr[0] * ATR_Trail_Mult : price + atr[0] * ATR_Trail_Mult;
      if((isLong && newSL > curSL) || (!isLong && newSL < curSL))
         trade.PositionModify(_Symbol, NormalizeDouble(newSL, _Digits), curTP);
   }
}

//+------------------------------------------------------------------+
// Closed-deal tracking — daily loss counter + cooldown clock
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal = trans.deal;
   if(deal == 0) return;
   if(!HistoryDealSelect(deal)) return;
   if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != Magic_Number) return;
   if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   lastCloseTime = TimeCurrent();
   double p = HistoryDealGetDouble(deal, DEAL_PROFIT);
   // count a losing DAY-trade only when the position is fully flat and net-negative
   if(!PositionSelect(_Symbol) && p < 0)
   {
      lossesToday++;
      Log(StringFormat("losing trade closed | today's losses: %d/%d", lossesToday, Max_Daily_Losses));
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(PositionOpen()) { ManagePosition(); TradingAllowed(); return; }
   if(entryTime != 0) { lastCloseTime = MathMax(lastCloseTime, TimeCurrent() - 1); ResetTradeState(); }
   if(!TradingAllowed()) return;
   CheckSignals();
}
//+------------------------------------------------------------------+
