//+------------------------------------------------------------------+
//|                                         GMoneyCore_v1_8_Fixed.mq5|
//|  G MONEY CORE v1.8 - Fixed & Optimized Version                   |
//+------------------------------------------------------------------+
#property copyright "G MONEY CORE v1.8 Fixed"
#property version   "1.82"
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//--- Inputs ---
input group "== Core Ruleset =="
input int    InpSwingBars        = 3;     // fractal bars each side
input int    InpZoneLookback     = 100;   // bars scanned for zones
input double InpZoneTolATR       = 0.5;   // zone tolerance in ATR multiples
input double InpMaxSpreadPips    = 1.5;   // #5 spread control
input double InpVolMultiplier    = 1.2;   // #6 volume vs 20MA
input double InpMaxSpikePips     = 50.0;  // #11 volatility filter
input int    InpVolSpikeBars     = 15;
input double InpRSILower         = 25.0;  // #10 momentum filter
input double InpRSIUpper         = 75.0;
input int    InpMAPeriod        = 50;    // #9 MA alignment
input int    InpRSIPeriod       = 14;
input int    InpATRPeriod       = 14;
input double InpImpulseATRMult   = 2.0;   // #13 order-block threshold
input ENUM_TIMEFRAMES InpHigherTF = PERIOD_M15;

input group "== Scoring =="
input int    InpMaxScorePoints   = 8;     // number of scored criteria (#1,#2,#3,#4,#6,#9,#10,#16)
input int    InpMinScoreOfMax    = 6;     // minimum earned points (out of InpMaxScorePoints) to trade
input bool   InpRequireSweepGate = true;  // require #16 (Sweep + FVG) to pass, in addition to score
input int    InpIsolateCriterion = 0;     // 0=composite score; else trade ONLY on this rule #

input group "== Trade Management =="
input double InpRiskPercent      = 1.0;   // % of equity risked per trade
input double InpMinStopPips      = 15.0;  // minimum SL distance
input double InpStopATRMult      = 1.0;   // stop distance in ATR multiples
input double InpTP1_RR           = 1.0;   // TP1 risk:reward
input double InpTP2_RR           = 3.0;   // TP2 risk:reward
input bool   InpUseTP1Partial    = true;  // close 50% at TP1, move SL to BE
input double InpTP1ClosePercent  = 50.0;
input bool   InpUseEarlyCandleExit = false;// Turn off aggressive 2-candle exit rule
input int    InpMagicNumber      = 18180;

//--- Globals ---
double   g_pip;
datetime g_lastBarTime = 0;
bool     g_tp1Done = false;
int      g_atrHandle, g_rsiHandle, g_maHandle;

int OnInit()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   bool tenPointPip = (digits == 3 || digits == 5 || StringFind(_Symbol, "XAU") >= 0);
   g_pip = tenPointPip ? point * 10 : point;

   trade.SetExpertMagicNumber(InpMagicNumber);

   // Persistent Indicator Handles
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   g_rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_maHandle  = iMA(_Symbol, PERIOD_CURRENT, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

   if(g_atrHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE || g_maHandle == INVALID_HANDLE)
   {
      Print("Error initializing indicator handles.");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(g_atrHandle);
   IndicatorRelease(g_rsiHandle);
   IndicatorRelease(g_maHandle);
}

bool IsSwingHigh(const double &high[], int idx, int total, int bars)
{
   if(idx - bars < 0 || idx + bars >= total) return false;
   double h = high[idx];
   for(int k = idx - bars; k <= idx + bars; k++)
      if(k != idx && high[k] > h) return false;
   return true;
}

bool IsSwingLow(const double &low[], int idx, int total, int bars)
{
   if(idx - bars < 0 || idx + bars >= total) return false;
   double l = low[idx];
   for(int k = idx - bars; k <= idx + bars; k++)
      if(k != idx && low[k] < l) return false;
   return true;
}

bool RecentSwings(const double &high[], const double &low[], int total, int lookbackStart,
                 double &sh1, double &sh2, double &sl1, double &sl2)
{
   int foundH = 0, foundL = 0;
   sh1 = sh2 = sl1 = sl2 = 0;
   for(int i = lookbackStart; i >= InpSwingBars; i--)
   {
      if(foundH < 2 && IsSwingHigh(high, i, total, InpSwingBars))
      {
         if(foundH == 0) sh1 = high[i]; else if(foundH == 1) sh2 = high[i];
         foundH++;
      }
      if(foundL < 2 && IsSwingLow(low, i, total, InpSwingBars))
      {
         if(foundL == 0) sl1 = low[i]; else if(foundL == 1) sl2 = low[i];
         foundL++;
      }
      if(foundH >= 2 && foundL >= 2) break;
   }
   return (foundH >= 2 && foundL >= 2);
}

struct ScoreResult
{
   int    earned;
   int    evaluated;
   double entryZonePrice;
   bool   sweepFound;
   bool   ok1, ok2, ok3, ok4, ok6, ok9, ok10, ok16;
};

bool CriterionPassed(const ScoreResult &res, int criterionNum)
{
   switch(criterionNum)
   {
      case 1:  return res.ok1;
      case 2:  return res.ok2;
      case 3:  return res.ok3;
      case 4:  return res.ok4;
      case 6:  return res.ok6;
      case 9:  return res.ok9;
      case 10: return res.ok10;
      case 16: return res.ok16;
      default: return false;
   }
}

bool ScoreSetup(int direction, ScoreResult &res)
{
   res.earned = 0; res.evaluated = 0; res.sweepFound = false;

   MqlRates rates[];
   // Start scan from Bar 1 (closed bar) to eliminate repainting
   int total = CopyRates(_Symbol, PERIOD_CURRENT, 1, InpZoneLookback + InpSwingBars + 10, rates);
   if(total < InpZoneLookback) return false;

   double high[], low[], close[], open[];
   ArrayResize(high, total); ArrayResize(low, total);
   ArrayResize(close, total); ArrayResize(open, total);

   for(int i = 0; i < total; i++)
   {
      high[i]  = rates[i].high;
      low[i]   = rates[i].low;
      close[i] = rates[i].close;
      open[i]  = rates[i].open;
   }

   int lastIdx = total - 1; // Closed bar (Bar 1)

   double atrBuf[1], rsiBuf[1], maBuf[1];
   if(CopyBuffer(g_atrHandle, 0, 1, 1, atrBuf) <= 0) return false;
   if(CopyBuffer(g_rsiHandle, 0, 1, 1, rsiBuf) <= 0) return false;
   if(CopyBuffer(g_maHandle, 0, 1, 1, maBuf) <= 0) return false;

   double atr = atrBuf[0];
   double rsi = rsiBuf[0];
   double ma  = maBuf[0];
   double currentClose = close[lastIdx];

   //--- #2 Trend Structure ---
   double sh1, sh2, sl1, sl2;
   bool haveSwings = RecentSwings(high, low, total, lastIdx - InpSwingBars, sh1, sh2, sl1, sl2);
   {
      res.evaluated++;
      bool ok = false;
      if(haveSwings)
      {
         bool hh_hl = (sh1 > sh2) && (sl1 > sl2);
         bool lh_ll = (sh1 < sh2) && (sl1 < sl2);
         ok = (direction == 1 && hh_hl) || (direction == -1 && lh_ll);
      }
      res.ok2 = ok;
      if(ok) res.earned++;
   }

   //--- #1 MTF Alignment ---
   {
      res.evaluated++;
      MqlRates htf[];
      int htfTotal = CopyRates(_Symbol, InpHigherTF, 1, InpZoneLookback, htf);
      bool ok = false;
      if(htfTotal >= 20)
      {
         double hSh1=0,hSh2=0,hSl1=0,hSl2=0; int fH=0, fL=0;
         double hHigh[], hLow[];
         ArrayResize(hHigh, htfTotal); ArrayResize(hLow, htfTotal);
         for(int i=0; i<htfTotal; i++) { hHigh[i]=htf[i].high; hLow[i]=htf[i].low; }
         for(int i = htfTotal - 1 - InpSwingBars; i >= InpSwingBars; i--)
         {
            if(fH < 2 && IsSwingHigh(hHigh, i, htfTotal, InpSwingBars)) { if(fH==0) hSh1=hHigh[i]; else if(fH==1) hSh2=hHigh[i]; fH++; }
            if(fL < 2 && IsSwingLow(hLow, i, htfTotal, InpSwingBars))   { if(fL==0) hSl1=hLow[i];  else if(fL==1) hSl2=hLow[i];  fL++; }
            if(fH>=2 && fL>=2) break;
         }
         if(fH>=2 && fL>=2)
         {
            bool hh_hl = (hSh1>hSh2)&&(hSl1>hSl2);
            bool lh_ll = (hSh1<hSh2)&&(hSl1<hSl2);
            ok = (direction==1 && hh_hl) || (direction==-1 && lh_ll);
         }
      }
      res.ok1 = ok;
      if(ok) res.earned++;
   }

   //--- #4 Candle confirmation ---
   {
      res.evaluated++;
      double o = open[lastIdx], c = close[lastIdx], h = high[lastIdx], l = low[lastIdx];
      double range = h - l;
      bool ok = false;
      if(range > 0)
      {
         double body = MathAbs(c - o);
         double upperWick = h - MathMax(o, c);
         double lowerWick = MathMin(o, c) - l;
         double wickRatio = (MathMax(upperWick,0) + MathMax(lowerWick,0)) / range;
         double bodyRatio = body / range;
         ok = (wickRatio >= 0.70 && bodyRatio <= 0.30);
      }
      res.ok4 = ok;
      if(ok) res.earned++;
   }

   //--- #5 Spread Control ---
   {
      long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double spreadPips = spreadPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / g_pip;
      if(spreadPips > InpMaxSpreadPips) return false;
   }

   //--- #6 Volume Confirmation ---
   {
      long volBuf[];
      int volTotal = CopyTickVolume(_Symbol, PERIOD_CURRENT, 1, 20, volBuf);
      if(volTotal >= 20)
      {
         res.evaluated++;
         double avgVol = 0;
         for(int i=0; i<volTotal; i++) avgVol += (double)volBuf[i];
         avgVol /= volTotal;
         res.ok6 = ((double)volBuf[volTotal-1] >= InpVolMultiplier * avgVol);
         if(res.ok6) res.earned++;
      }
   }

   //--- #9 MA Alignment ---
   {
      res.evaluated++;
      res.ok9 = (direction == 1 && currentClose > ma) || (direction == -1 && currentClose < ma);
      if(res.ok9) res.earned++;
   }

   //--- #10 Momentum Filter ---
   {
      res.evaluated++;
      res.ok10 = (rsi > InpRSILower && rsi < InpRSIUpper);
      if(res.ok10) res.earned++;
   }

   //--- #3 Zone Confirmed ---
   double zoneLevel = (direction == 1) ? sl1 : sh1;
   {
      res.evaluated++;
      res.ok3 = haveSwings && atr > 0 && MathAbs(currentClose - zoneLevel) <= InpZoneTolATR * atr;
      if(res.ok3) res.earned++;
      res.entryZonePrice = zoneLevel;
   }

   //--- #16 Sweep + FVG ---
   {
      res.evaluated++;
      bool swept = false, fvg = false;
      if(lastIdx >= 4 && haveSwings)
      {
         double priorExtHigh = sh2 > 0 ? MathMax(sh1, sh2) : sh1;
         double priorExtLow  = sl2 > 0 ? MathMin(sl1, sl2) : sl1;
         if(direction == -1) swept = (high[lastIdx] > priorExtHigh) && (close[lastIdx] < priorExtHigh);
         else                swept = (low[lastIdx]  < priorExtLow)  && (close[lastIdx] > priorExtLow);

         double c1h = high[lastIdx-2], c1l = low[lastIdx-2];
         double c3h = high[lastIdx],   c3l = low[lastIdx];
         if(direction == 1)  fvg = (c3l > c1h);
         else                fvg = (c3h < c1l);
      }
      res.sweepFound = swept && fvg;
      res.ok16 = res.sweepFound;
      if(res.sweepFound) res.earned++;
   }

   return true;
}

// Returns the sized lot, and reports via lotWasClamped whether the
// risk-derived size had to be capped to the broker's min/max lot --
// i.e. whether this trade is under- or over-risked relative to InpRiskPercent.
double CalcLotSize(double stopDistancePrice, bool &lotWasClamped)
{
   lotWasClamped = false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize <= 0 || tickValue <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lossPerLot = (stopDistancePrice / tickSize) * tickValue;
   if(lossPerLot <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lots = riskAmount / lossPerLot;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / step) * step;
   double clamped = MathMax(minLot, MathMin(maxLot, lots));

   if(clamped != lots)
   {
      lotWasClamped = true;
      Print(StringFormat(
         "GMC lot size clamped: risk-derived=%.2f lots -> capped to %.2f lots (broker min=%.2f max=%.2f). "
         "Actual risk this trade is %.2f%% of the intended %.2f%%.",
         lots, clamped, minLot, maxLot,
         (clamped / MathMax(lots, 0.0000001)) * InpRiskPercent, InpRiskPercent));
   }

   return clamped;
}

void ManageOpenPosition()
{
   if(!PositionSelect(_Symbol)) { g_tp1Done = false; return; }
   if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   long type = PositionGetInteger(POSITION_TYPE);

   double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopDist = MathAbs(openPrice - sl);
   if(stopDist <= 0) return;

   // FIXED Syntax Error (* operator added)
   double tp1Price = (type == POSITION_TYPE_BUY) ? openPrice + (InpTP1_RR * stopDist) : openPrice - (InpTP1_RR * stopDist);

   if(!g_tp1Done && InpUseTP1Partial)
   {
      bool hit = (type == POSITION_TYPE_BUY) ? currentPrice >= tp1Price : currentPrice <= tp1Price;
      if(hit)
      {
         double closeVol = NormalizeDouble(volume * (InpTP1ClosePercent/100.0), 2);
         if(closeVol >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            trade.PositionClosePartial(_Symbol, closeVol);
         }
         // Move SL to Break Even
         trade.PositionModify(_Symbol, openPrice, PositionGetDouble(POSITION_TP));
         g_tp1Done = true;
      }
   }

   // Optional Early Candlestick Exit
   if(InpUseEarlyCandleExit)
   {
      MqlRates r[2];
      if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, r) == 2)
      {
         bool bothBear = (r[0].close < r[0].open) && (r[1].close < r[1].open);
         bool bothBull = (r[0].close > r[0].open) && (r[1].close > r[1].open);
         bool bigBody0 = MathAbs(r[0].close-r[0].open) > 0.5*(r[0].high-r[0].low);
         bool bigBody1 = MathAbs(r[1].close-r[1].open) > 0.5*(r[1].high-r[1].low);

         if(bigBody0 && bigBody1)
         {
            if(type == POSITION_TYPE_BUY && bothBear) trade.PositionClose(_Symbol);
            if(type == POSITION_TYPE_SELL && bothBull) trade.PositionClose(_Symbol);
         }
      }
   }
}

void OnTick()
{
   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   ManageOpenPosition();

   if(PositionSelect(_Symbol)) return;
   if(curBarTime == g_lastBarTime) return;
   g_lastBarTime = curBarTime;

   for(int dir = 1; dir >= -1; dir -= 2)
   {
      ScoreResult res;
      if(!ScoreSetup(dir, res)) continue;
      if(res.evaluated == 0) continue;

      bool filterPassed = false;
      if(InpIsolateCriterion > 0)
         filterPassed = CriterionPassed(res, InpIsolateCriterion);
      else
         filterPassed = (res.earned >= InpMinScoreOfMax) && (!InpRequireSweepGate || res.ok16);

      if(!filterPassed) continue;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double entryPrice = (dir == 1) ? ask : bid;

      double atrBuf[1];
      CopyBuffer(g_atrHandle, 0, 1, 1, atrBuf);
      double stopDistPips = MathMax(InpMinStopPips, (atrBuf[0] * InpStopATRMult) / g_pip);
      double stopDistPrice = stopDistPips * g_pip;

      double slPrice = (dir == 1) ? entryPrice - stopDistPrice : entryPrice + stopDistPrice;
      double tpPrice = (dir == 1) ? entryPrice + (InpTP2_RR * stopDistPrice) : entryPrice - (InpTP2_RR * stopDistPrice);

      bool lotWasClamped = false;
      double lotSize = CalcLotSize(stopDistPrice, lotWasClamped);

      if(dir == 1)
         trade.Buy(lotSize, _Symbol, ask, slPrice, tpPrice, "GMoney Core Buy");
      else
         trade.Sell(lotSize, _Symbol, bid, slPrice, tpPrice, "GMoney Core Sell");

      break;
   }
}
