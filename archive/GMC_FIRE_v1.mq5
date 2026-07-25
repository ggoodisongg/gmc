//+------------------------------------------------------------------+
//|  GMC_FIRE_v1.mq5                                                 |
//|  Maximum-frequency baseline EA. Fast EMA cross, risk-based lots. |
//|  Work-backwards dials: cooldown, session window, HTF trend.      |
//|  Reads CLOSED bars only (no repaint). Real broker cost applies.  |
//+------------------------------------------------------------------+
#property copyright "GMC"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

input group "Risk & Sizing"
input double RiskPercent   = 1.0;    // Risk per trade (% of balance)
input double RRRatio       = 1.0;    // Reward : Risk
input int    ATRPeriod     = 14;     // ATR period
input double ATRMult       = 1.0;    // ATR stop multiplier
input double MinStopPrice  = 20.0;   // Min stop distance in price units (0 = max trades, risky)

input group "Signal (mass trades)"
input int    FastEMA       = 3;      // Fast EMA (lower = more trades)
input int    SlowEMA       = 8;      // Slow EMA

input group "Filters (dial UP to work backwards)"
input int    CooldownBars  = 0;      // Min bars between entries (0 = off)
input bool   UseSession    = false;  // Restrict to session window
input int    SessionStart  = 13;     // Session start hour (server time)
input int    SessionEnd    = 20;     // Session end hour
input bool   UseTrendFilter= false;  // Only trade with higher-TF trend
input ENUM_TIMEFRAMES TrendTF = PERIOD_H1;
input int    TrendFast     = 20;
input int    TrendSlow     = 50;

input group "General"
input long   MagicNumber   = 20260722;

int      hFast, hSlow, hATR, hTFast=INVALID_HANDLE, hTSlow=INVALID_HANDLE;
datetime lastBarTime = 0;
int      barIndex = 0;
int      lastEntryBar = -100000;

//+------------------------------------------------------------------+
int OnInit()
  {
   hFast = iMA(_Symbol, _Period, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, _Period, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hATR  = iATR(_Symbol, _Period, ATRPeriod);
   if(UseTrendFilter)
     {
      hTFast = iMA(_Symbol, TrendTF, TrendFast, 0, MODE_EMA, PRICE_CLOSE);
      hTSlow = iMA(_Symbol, TrendTF, TrendSlow, 0, MODE_EMA, PRICE_CLOSE);
     }
   if(hFast==INVALID_HANDLE || hSlow==INVALID_HANDLE || hATR==INVALID_HANDLE)
      return(INIT_FAILED);
   trade.SetExpertMagicNumber(MagicNumber);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(hFast);
   IndicatorRelease(hSlow);
   IndicatorRelease(hATR);
   if(hTFast!=INVALID_HANDLE) IndicatorRelease(hTFast);
   if(hTSlow!=INVALID_HANDLE) IndicatorRelease(hTSlow);
  }
//+------------------------------------------------------------------+
double Buf(int handle, int shift)
  {
   double b[];
   if(CopyBuffer(handle, 0, shift, 1, b) <= 0) return(EMPTY_VALUE);
   return(b[0]);
  }
//+------------------------------------------------------------------+
bool PositionOpen()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(PositionSelectByTicket(tk))
         if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
            PositionGetInteger(POSITION_MAGIC)==MagicNumber)
            return(true);
     }
   return(false);
  }
//+------------------------------------------------------------------+
bool InSession()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(SessionStart <= SessionEnd) return(h>=SessionStart && h<SessionEnd);
   return(h>=SessionStart || h<SessionEnd);
  }
//+------------------------------------------------------------------+
double CalcLots(double stopDist)
  {
   double bal      = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney= bal * RiskPercent/100.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0 || stopDist<=0) return(0.0);
   double perPricePerLot = tickVal / tickSize;      // money per 1.0 price move per 1 lot
   double lots = riskMoney / (stopDist * perPricePerLot);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step>0) lots = MathFloor(lots/step)*step;
   lots = MathMax(minL, MathMin(maxL, lots));
   return(lots);
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime t = iTime(_Symbol, _Period, 0);
   if(t==lastBarTime) return;   // act once per closed bar
   lastBarTime = t;
   barIndex++;

   if(PositionOpen()) return;   // one trade at a time; SL/TP manages the exit

   double f1=Buf(hFast,1), f2=Buf(hFast,2);
   double s1=Buf(hSlow,1), s2=Buf(hSlow,2);
   double atr=Buf(hATR,1);
   if(f1==EMPTY_VALUE || s1==EMPTY_VALUE || atr==EMPTY_VALUE) return;

   bool crossUp = (f2<=s2 && f1>s1);
   bool crossDn = (f2>=s2 && f1<s1);
   if(!crossUp && !crossDn) return;

   bool okSession = !UseSession || InSession();
   bool cool = (barIndex - lastEntryBar) >= CooldownBars;
   bool trendUp=true, trendDn=true;
   if(UseTrendFilter)
     {
      double tf=Buf(hTFast,1), ts=Buf(hTSlow,1);
      if(tf==EMPTY_VALUE || ts==EMPTY_VALUE) return;
      trendUp = tf>ts; trendDn = tf<ts;
     }
   if(!okSession || !cool) return;

   double stopDist = MathMax(atr*ATRMult, MinStopPrice);
   double lots = CalcLots(stopDist);
   if(lots<=0) return;

   if(crossUp && trendUp)
     {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = price - stopDist;
      double tp = price + stopDist*RRRatio;
      if(trade.Buy(lots, _Symbol, price, sl, tp)) lastEntryBar=barIndex;
     }
   else if(crossDn && trendDn)
     {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = price + stopDist;
      double tp = price - stopDist*RRRatio;
      if(trade.Sell(lots, _Symbol, price, sl, tp)) lastEntryBar=barIndex;
     }
  }
//+------------------------------------------------------------------+
