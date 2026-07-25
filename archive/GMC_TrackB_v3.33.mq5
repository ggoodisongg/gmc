//+------------------------------------------------------------------+
//|                  G MONEY CORE — TRACK B v3.33                    |
//|  v3.32 + regime filters (ADX gate, volatility floor) as TOGGLES  |
//|  Nothing removed. Only bad-trade filters ADDED, default tunable. |
//+------------------------------------------------------------------+
#property copyright "G Money Systems"
#property version   "3.33"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//+------------------------------------------------------------------+
// INPUTS
//+------------------------------------------------------------------+
input group "--- EA Identity & Broker ---"
input string              EA_Name           = "GMC Track B v3.33";
input int                 Magic_Number      = 10033;
input int                 Slippage_Points   = 20;

input group "--- Risk & Lot Settings ---"
input double Risk_Percent                  = 0.5;      // Risk % per trade
input double Max_Lot_Size                  = 0.20;     // Max allowed lot
input double Min_Lot_Size                  = 0.01;     // Broker minimum (fixed)

input group "--- Trend Filters ---"
input int                EMA_Trend_Period  = 50;
input ENUM_TIMEFRAMES    Trend_Timeframe   = PERIOD_M15;
input int                EMA_Signal_Period = 20;
input ENUM_TIMEFRAMES    Signal_Timeframe  = PERIOD_M5;

input group "--- Regime Filters (bad-bit removers) ---"
input bool   Use_ADX_Filter                = true;     // Only trade in a real trend
input int    ADX_Period                    = 14;
input double ADX_Min                       = 23.0;     // Higher = stricter (skip chop)
input bool   Use_ATR_Floor                 = false;    // Skip dead/quiet markets
input double Min_ATR_Pips                   = 15.0;     // Require this much volatility

input group "--- Entry Rules ---"
input int    Momentum_Bars                 = 3;
input double Min_Candle_Body_Pct           = 65.0;
input double Max_Spread_Pips               = 12.0;

input group "--- Stop Loss & Take Profit ---"
input int    ATR_Period                    = 14;
input double SL_ATR_Multiplier             = 1.75;
input double TP1_ATR_Multiplier            = 1.2;
input double TP2_ATR_Multiplier            = 2.5;
input double TP3_ATR_Multiplier            = 3.8;
input double Min_SL_Pips                   = 70.0;
input double Max_SL_Pips                   = 380.0;

input group "--- Trade Management ---"
input double BE_Trigger_R                  = 1.0;
input double Partial_Close_Pct             = 50.0;
input double Trail_Start_R                 = 2.0;
input double Trail_ATR_Step                = 0.45;

input group "--- Daily & Session Protection ---"
input bool   Use_Session_Filter            = true;
input int    London_Open_Hour              = 10;
input int    London_Close_Hour             = 16;
input int    NY_Open_Hour                  = 16;
input int    NY_Close_Hour                 = 22;
input double Daily_Max_Loss_Pct            = 7.0;
input int    Max_Consec_Losses             = 4;
input int    Cooldown_Mins                 = 30;

//+------------------------------------------------------------------+
// GLOBAL VARIABLES
//+------------------------------------------------------------------+
double        pip;
int           handle_ema_trend, handle_ema_signal, handle_atr, handle_adx;
datetime      last_processed_bar = 0;
double        daily_start_balance = 0.0;
double        daily_max_loss = 0.0;
int           consecutive_losses = 0;
datetime      cooldown_until = 0;

ulong         g_ticket = 0;
double        g_risk_pips = 0.0;
bool          g_be = false, g_partial = false, g_trail = false;

//+------------------------------------------------------------------+
// HELPERS
//+------------------------------------------------------------------+
void Log(string text) { Print(EA_Name + " | " + text); }
double PipsToPrice(double pips) { return pips * pip; }
double PriceToPips(double price) { return price / pip; }

bool SelectMyPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(PositionSelectByTicket(tk))
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == Magic_Number)
            return true;
   }
   return false;
}

double CalculateLotSize(double sl_pips, bool &valid)
{
   valid = false;
   if(sl_pips <= 0) return 0.0;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * (Risk_Percent / 100.0);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lot_step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(tick_value <= 0 || tick_size <= 0 || lot_step <= 0) { Log("Invalid symbol data"); return 0.0; }
   double risk_per_lot = (sl_pips * pip / tick_size) * tick_value;
   if(risk_per_lot <= 0) return 0.0;
   double ideal_lot = risk_amount / risk_per_lot;
   ideal_lot = NormalizeDouble(MathFloor(ideal_lot / lot_step) * lot_step, 2);
   if(ideal_lot < Min_Lot_Size) ideal_lot = Min_Lot_Size;
   if(ideal_lot > Max_Lot_Size) ideal_lot = Max_Lot_Size;
   valid = true;
   return ideal_lot;
}

bool IsTradingSession()
{
   if(!Use_Session_Filter) return true;
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   int h = t.hour;
   return ((h >= London_Open_Hour && h < London_Close_Hour) || (h >= NY_Open_Hour && h < NY_Close_Hour));
}

bool SafetyChecks()
{
   if(daily_start_balance <= 0) return true;
   double current = AccountInfoDouble(ACCOUNT_BALANCE);
   if((daily_start_balance - current) >= daily_max_loss) { Log("Daily loss limit reached — paused"); return false; }
   if(consecutive_losses >= Max_Consec_Losses)
   {
      if(cooldown_until == 0) cooldown_until = TimeCurrent() + Cooldown_Mins * 60;
      if(TimeCurrent() < cooldown_until) return false;
      consecutive_losses = 0; cooldown_until = 0;
      Log("Cooldown finished — resumed");
   }
   return true;
}

//+------------------------------------------------------------------+
int OnInit()
{
   pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0) pip *= 10;
   handle_ema_trend   = iMA(_Symbol, Trend_Timeframe,  EMA_Trend_Period,   0, MODE_EMA, PRICE_CLOSE);
   handle_ema_signal  = iMA(_Symbol, Signal_Timeframe, EMA_Signal_Period,  0, MODE_EMA, PRICE_CLOSE);
   handle_atr         = iATR(_Symbol, Signal_Timeframe, ATR_Period);
   handle_adx         = iADX(_Symbol, Signal_Timeframe, ADX_Period);
   if(handle_ema_trend == INVALID_HANDLE || handle_ema_signal == INVALID_HANDLE ||
      handle_atr == INVALID_HANDLE || handle_adx == INVALID_HANDLE)
   { Log("Indicator init failed"); return INIT_FAILED; }
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(Slippage_Points);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetMarginMode();
   daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   daily_max_loss      = daily_start_balance * (Daily_Max_Loss_Pct / 100.0);
   Log("GMC v3.33 initialized | ADX filter: " + (Use_ADX_Filter?"ON":"off") + " | Ready");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(handle_ema_trend);
   IndicatorRelease(handle_ema_signal);
   IndicatorRelease(handle_atr);
   IndicatorRelease(handle_adx);
   Log("EA stopped");
}

//+------------------------------------------------------------------+
void OnTick()
{
   static datetime reset = 0;
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != reset)
   {
      reset = today;
      daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      daily_max_loss = daily_start_balance * (Daily_Max_Loss_Pct / 100.0);
      consecutive_losses = 0; cooldown_until = 0;
   }

   if(SelectMyPosition()) { ManagePosition(); return; }
   if(!SafetyChecks() || !IsTradingSession()) return;

   datetime current_bar = iTime(_Symbol, Signal_Timeframe, 1);
   if(current_bar == last_processed_bar) return;
   last_processed_bar = current_bar;

   double ema1[], ema2[], atr[], adx[], o[], h[], l[], c[];
   ArraySetAsSeries(ema1, true); ArraySetAsSeries(ema2, true); ArraySetAsSeries(atr, true); ArraySetAsSeries(adx, true);
   ArraySetAsSeries(o, true); ArraySetAsSeries(h, true); ArraySetAsSeries(l, true); ArraySetAsSeries(c, true);

   if(CopyBuffer(handle_ema_trend,  0, 1, 3, ema1) < 3) return;
   if(CopyBuffer(handle_ema_signal, 0, 1, 3, ema2) < 3) return;
   if(CopyBuffer(handle_atr,        0, 1, 3, atr)  < 3) return;
   if(CopyBuffer(handle_adx,        0, 1, 3, adx)  < 3) return;
   if(CopyOpen(_Symbol,  Signal_Timeframe, 0, 5, o) < 5) return;
   if(CopyHigh(_Symbol,  Signal_Timeframe, 0, 5, h) < 5) return;
   if(CopyLow(_Symbol,   Signal_Timeframe, 0, 5, l) < 5) return;
   if(CopyClose(_Symbol, Signal_Timeframe, 0, 5, c) < 5) return;

   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / pip;
   if(spread > Max_Spread_Pips) { Log("Spread too high: " + DoubleToString(spread,1) + "p"); return; }

   // --- REGIME FILTERS (bad-bit removers) ---
   if(Use_ADX_Filter && adx[1] < ADX_Min) return;          // skip chop: no real trend
   if(Use_ATR_Floor && (atr[1] / pip) < Min_ATR_Pips) return; // skip dead/quiet market

   double sl_pips = atr[1] * SL_ATR_Multiplier / pip;
   sl_pips = MathMax(Min_SL_Pips, MathMin(sl_pips, Max_SL_Pips));

   bool long_ok  = (c[1] > ema1[1] && c[1] > ema2[1]);
   bool short_ok = (c[1] < ema1[1] && c[1] < ema2[1]);
   if(!long_ok && !short_ok) return;

   double range = h[1] - l[1];
   if(range <= 0) return;
   if(MathAbs(c[1]-o[1]) / range * 100 < Min_Candle_Body_Pct) return;

   bool valid = false;
   double lot = CalculateLotSize(sl_pips, valid);
   if(!valid || lot < Min_Lot_Size) return;

   if(long_ok && c[1] > h[2])
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = entry - PipsToPrice(sl_pips);
      double tp = entry + PipsToPrice(sl_pips * TP3_ATR_Multiplier);
      if(trade.Buy(lot, _Symbol, entry, sl, tp, "GMC LONG"))
         Log("LONG opened | Lot: " + DoubleToString(lot,2) + " | SL: " + DoubleToString(sl_pips,0) + "p | ADX: " + DoubleToString(adx[1],1));
   }
   else if(short_ok && c[1] < l[2])
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = entry + PipsToPrice(sl_pips);
      double tp = entry - PipsToPrice(sl_pips * TP3_ATR_Multiplier);
      if(trade.Sell(lot, _Symbol, entry, sl, tp, "GMC SHORT"))
         Log("SHORT opened | Lot: " + DoubleToString(lot,2) + " | SL: " + DoubleToString(sl_pips,0) + "p | ADX: " + DoubleToString(adx[1],1));
   }
}

//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!SelectMyPosition()) return;
   ulong  ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl     = PositionGetDouble(POSITION_SL);
   double tp     = PositionGetDouble(POSITION_TP);
   double vol    = PositionGetDouble(POSITION_VOLUME);
   bool   is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double price  = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(ticket != g_ticket)
   {
      g_ticket = ticket; g_be = false; g_partial = false; g_trail = false;
      g_risk_pips = (sl > 0) ? MathAbs(entry - sl) / pip : 0.0;
   }
   double risk = g_risk_pips;
   if(risk <= 0) return;

   double profit = is_buy ? (price - entry) / pip : (entry - price) / pip;

   if(!g_be && profit >= risk * BE_Trigger_R)
   {
      double new_sl = is_buy ? MathMax(entry, sl) : (sl > 0 ? MathMin(entry, sl) : entry);
      if(new_sl != sl && trade.PositionModify(ticket, new_sl, tp)) { g_be = true; sl = new_sl; Log("Break-even activated"); }
   }

   if(!g_partial && profit >= risk * TP1_ATR_Multiplier)
   {
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double amt  = (step > 0) ? MathFloor((vol * Partial_Close_Pct/100.0)/step)*step : vol * Partial_Close_Pct/100.0;
      amt = NormalizeDouble(amt, 2);
      if(amt >= Min_Lot_Size && amt < vol) { if(trade.PositionClosePartial(ticket, amt)) { g_partial = true; Log("Partial close at TP1"); } }
      else g_partial = true;
   }

   if(!g_trail && profit >= risk * Trail_Start_R) { g_trail = true; Log("Trailing started"); }
   if(g_trail)
   {
      double dist = risk * Trail_ATR_Step;
      double new_sl = is_buy ? price - PipsToPrice(dist) : price + PipsToPrice(dist);
      new_sl = is_buy ? MathMax(new_sl, sl) : (sl > 0 ? MathMin(new_sl, sl) : new_sl);
      if(MathAbs(new_sl - sl) > pip * 0.1) trade.PositionModify(ticket, new_sl, tp);
   }
}

//+------------------------------------------------------------------+
void OnTrade()
{
   if(SelectMyPosition()) return;
   static ulong last_counted = 0;
   HistorySelect(TimeCurrent() - 86400, TimeCurrent());
   for(int i = HistoryDealsTotal()-1; i >= 0; i--)
   {
      ulong t = HistoryDealGetTicket(i);
      if(t == 0) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC) != Magic_Number) continue;
      if(HistoryDealGetInteger(t, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      if(t == last_counted) break;
      last_counted = t;
      double p = HistoryDealGetDouble(t, DEAL_PROFIT);
      if(p >= 0) consecutive_losses = 0; else consecutive_losses++;
      Log("Trade closed | P&L: " + DoubleToString(p,2) + " | Loss streak: " + IntegerToString(consecutive_losses));
      break;
   }
}
//+------------------------------------------------------------------+
