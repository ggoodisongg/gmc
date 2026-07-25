//+------------------------------------------------------------------+
//|  GMC_v9.5_Sniper.mq5  — MQL5 port of G MONEY CORE v9.5 (M5)      |
//|  Confluence sniper: MA50/RSI/Vol/Wick score(>=5/6) + H4/H1 gates |
//|  + cascade momentum + staged exits (40/40/runner). Run on M5.    |
//+------------------------------------------------------------------+
#property copyright "GMC"
#property version   "9.50"
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input group "Capital"
input double RiskPercent   = 2.0;
input group "Core Filters"
input int    MaPeriod      = 50;
input int    RsiPeriod     = 14;
input int    VolPeriod     = 20;
input double VolMult       = 1.5;
input double WickThreshold = 55.0;
input double BodyThreshold = 38.0;
input double VolaDistPips   = 60.0;
input double AtrSLMult      = 1.5;
input double AtrTrailMult   = 2.0;
input group "Win Rate Control"
input bool   UseBuffer      = true;
input bool   FilterSmallWicks = true;
input int    MinScore       = 5;
input int    CooldownBars   = 3;
input bool   UseConfirmBar  = true;
input group "Session (GMT)"
input bool   UsePrimeHours  = true;
input bool   UseFullSession = true;
input int    LonPrimeStart  = 700;
input int    LonPrimeEnd    = 930;
input int    NyPrimeStart   = 1300;
input int    NyPrimeEnd     = 1530;
input int    LonFullStart   = 700;
input int    LonFullEnd     = 1600;
input int    NyFullStart    = 1300;
input int    NyFullEnd      = 2100;
input group "Exits"
input bool   UseTrailing    = true;
input double BeTrigger      = 1.2;
input double BePremium      = 0.1;
input double Tp1Mult        = 1.2;
input double Tp2Mult        = 2.5;
input double Tp3Mult        = 6.0;
input group "HTF Gates"
input bool   UseH4Gate      = true;
input bool   UseH1Gate      = true;
input group "Cascade"
input bool   UseCascade     = true;
input double CascPip1       = 8.0;
input double CascPip2       = 15.0;
input double CascPip3       = 25.0;
input int    CascBars       = 6;
input double CascVol        = 1.8;
input int    CascCooldown   = 3;
input int    CascMinScore   = 4;
input group "General"
input long   MagicNumber    = 20260725;

int hMA, hRSI, hATR, hH4MA, hH1MA;
double pip;
datetime lastBar = 0;
int barIdx = 0, lastEntryBar = -100000, lastCascBar = -100000;
double sEntry=0, sSL=0, sSLdist=0, sTrailDist=0, sInitLots=0, sTP=0;
bool   sIsLong=false, sTp1=false, sTp2=false, sBE=false, sTrail=false;

int OnInit()
{
   hMA  = iMA(_Symbol,_Period,MaPeriod,0,MODE_SMA,PRICE_CLOSE);
   hRSI = iRSI(_Symbol,_Period,RsiPeriod,PRICE_CLOSE);
   hATR = iATR(_Symbol,_Period,14);
   hH4MA= iMA(_Symbol,PERIOD_H4,50,0,MODE_SMA,PRICE_CLOSE);
   hH1MA= iMA(_Symbol,PERIOD_H1,20,0,MODE_SMA,PRICE_CLOSE);
   if(hMA==INVALID_HANDLE||hRSI==INVALID_HANDLE||hATR==INVALID_HANDLE||hH4MA==INVALID_HANDLE||hH1MA==INVALID_HANDLE)
      return(INIT_FAILED);
   pip = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*10.0;
   if(pip<=0) pip=_Point*10.0;
   trade.SetExpertMagicNumber(MagicNumber);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ IndicatorRelease(hMA);IndicatorRelease(hRSI);IndicatorRelease(hATR);IndicatorRelease(hH4MA);IndicatorRelease(hH1MA); }

double Bf(int h,int sh){ double b[]; if(CopyBuffer(h,0,sh,1,b)<=0) return(EMPTY_VALUE); return(b[0]); }
double Hi(int per,int st){ double m=-DBL_MAX; for(int i=st;i<st+per;i++){double v=iHigh(_Symbol,_Period,i); if(v>m)m=v;} return m; }
double Lo(int per,int st){ double m=DBL_MAX; for(int i=st;i<st+per;i++){double v=iLow(_Symbol,_Period,i); if(v<m)m=v;} return m; }
double AvgVol(){ double s=0; for(int i=1;i<=VolPeriod;i++) s+=(double)iVolume(_Symbol,_Period,i); return s/VolPeriod; }
double AvgRange(){ double s=0; for(int i=1;i<=5;i++) s+=(iHigh(_Symbol,_Period,i)-iLow(_Symbol,_Period,i)); return s/5.0; }
int    NowHHMM(){ MqlDateTime dt; TimeToStruct(TimeGMT(),dt); return dt.hour*100+dt.min; }
bool   InR(int t,int a,int b){ return (t>=a && t<b); }

bool InSession()
{
   int t=NowHHMM();
   bool prime = InR(t,LonPrimeStart,LonPrimeEnd) || InR(t,NyPrimeStart,NyPrimeEnd);
   bool full  = InR(t,LonFullStart,LonFullEnd)   || InR(t,NyFullStart,NyFullEnd);
   return UsePrimeHours ? prime : (UseFullSession ? full : true);
}

double CalcLots(double stopDist)
{
   double bal=AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney=bal*RiskPercent/100.0;
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(ts<=0||stopDist<=0) return 0;
   double perPrice=tv/ts;
   double lots=riskMoney/(stopDist*perPrice);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step>0) lots=MathFloor(lots/step)*step;
   return MathMax(mn,MathMin(mx,lots));
}

bool HavePos()
{
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i);
      if(PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==MagicNumber) return true; }
   return false;
}

void ManagePos()
{
   if(!HavePos()) return;
   double vol=PositionGetDouble(POSITION_VOLUME);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double px = sIsLong ? bid : ask;
   double profit = sIsLong ? (px - sEntry) : (sEntry - px);
   double stepv=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double partial = (stepv>0) ? MathFloor((sInitLots*0.4)/stepv)*stepv : sInitLots*0.4;
   double minL = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(!sTp1 && profit >= sSLdist*Tp1Mult){ if(partial>=minL && vol>partial) trade.PositionClosePartial(_Symbol,partial); sTp1=true; }
   else if(!sTp2 && profit >= sSLdist*Tp2Mult){ if(partial>=minL && vol>partial) trade.PositionClosePartial(_Symbol,partial); sTp2=true; }
   double atr=Bf(hATR,1);
   if(!sBE && profit >= sSLdist*BeTrigger){ sSL = sIsLong ? sEntry+atr*BePremium : sEntry-atr*BePremium; sBE=true; trade.PositionModify(_Symbol,sSL,sTP); }
   if(UseTrailing && profit >= sSLdist*1.8) sTrail=true;
   if(sTrail){
      double nt = sIsLong ? px - sTrailDist : px + sTrailDist;
      if((sIsLong && nt>sSL) || (!sIsLong && nt<sSL)){ sSL=nt; trade.PositionModify(_Symbol,sSL,sTP); }
   }
}

void OnTick()
{
   ManagePos();
   datetime t=iTime(_Symbol,_Period,0);
   if(t==lastBar) return;
   lastBar=t; barIdx++;
   if(HavePos()) return;

   double c1=iClose(_Symbol,_Period,1), o1=iOpen(_Symbol,_Period,1), h1=iHigh(_Symbol,_Period,1), l1=iLow(_Symbol,_Period,1);
   double atr=Bf(hATR,1); if(atr==EMPTY_VALUE||atr<=0) return;
   double maBuf = UseBuffer ? atr*0.25 : 0.0;
   double ma1=Bf(hMA,1), ma7=Bf(hMA,7);
   double rsi1=Bf(hRSI,1), rsi2=Bf(hRSI,2), rsi3=Bf(hRSI,3);
   if(ma1==EMPTY_VALUE||rsi1==EMPTY_VALUE) return;

   double h4c=iClose(_Symbol,PERIOD_H4,1), h4ma1=Bf(hH4MA,1), h4ma4=Bf(hH4MA,4);
   double h1c=iClose(_Symbol,PERIOD_H1,1), h1ma1=Bf(hH1MA,1), h1ma4=Bf(hH1MA,4);
   bool h4bull = UseH4Gate ? (h4c>h4ma1 && h4ma1>h4ma4) : true;
   bool h4bear = UseH4Gate ? (h4c<h4ma1 && h4ma1<h4ma4) : true;
   bool h1bull = UseH1Gate ? (h1c>h1ma1 && h1ma1>h1ma4) : true;
   bool h1bear = UseH1Gate ? (h1c<h1ma1 && h1ma1<h1ma4) : true;

   bool tBuy=true,tSell=true;
   for(int i=1;i<=3;i++){ double ci=iClose(_Symbol,_Period,i); if(ci<=ma1+maBuf) tBuy=false; if(ci>=ma1-maBuf) tSell=false; }
   bool slopeUp = ma1>ma7, slopeDn = ma1<ma7;

   double rng=h1-l1, lw=MathMin(o1,c1)-l1, uw=h1-MathMax(o1,c1), body=MathAbs(o1-c1);
   double avgC=AvgRange();
   bool sizeOk = FilterSmallWicks ? (rng>avgC*0.70) : true;
   bool bullRej = rng>0 && (lw/rng*100>=WickThreshold) && (body/rng*100<=BodyThreshold) && sizeOk;
   bool bearRej = rng>0 && (uw/rng*100>=WickThreshold) && (body/rng*100<=BodyThreshold) && sizeOk;

   double av=AvgVol(); bool volOk = (double)iVolume(_Symbol,_Period,1) >= av*VolMult;

   bool rsiBull = h4bull ? (rsi1>=42 && rsi1<=75) : (rsi1>=38 && rsi1<=62);
   bool rsiBear = h4bear ? (rsi1>=25 && rsi1<=58) : (rsi1>=38 && rsi1<=62);
   bool rsiUp = rsi1>rsi2 && rsi2>rsi3;
   bool rsiDn = rsi1<rsi2 && rsi2<rsi3;

   bool volaOk = ((Hi(10,1)-Lo(10,1))/pip) <= VolaDistPips;

   int bull = (tBuy?1:0)+(bullRej?1:0)+(volOk?1:0)+(rsiBull?1:0)+(slopeUp?1:0)+((h4bull&&h1bull)?1:0);
   int bear = (tSell?1:0)+(bearRej?1:0)+(volOk?1:0)+(rsiBear?1:0)+(slopeDn?1:0)+((h4bear&&h1bear)?1:0);
   bool bullPerfect=bull>=MinScore, bearPerfect=bear>=MinScore;
   bool bullConf = UseConfirmBar ? (c1>o1 && rsiUp) : true;
   bool bearConf = UseConfirmBar ? (c1<o1 && rsiDn) : true;

   bool sess=InSession();
   bool coolOk = (barIdx-lastEntryBar)>=CooldownBars;
   bool cascCoolOk = (barIdx-lastCascBar)>=CascCooldown;

   bool buySig  = bullPerfect && bullConf && volaOk && sess && coolOk;
   bool sellSig = bearPerfect && bearConf && volaOk && sess && coolOk;

   double moveDn=(Hi(CascBars,1)-c1)/pip, moveUp=(c1-Lo(CascBars,1))/pip;
   bool cVol=(double)iVolume(_Symbol,_Period,1)>=av*CascVol;
   bool cSizeOk=rng>avgC*1.1;
   bool cascSell = UseCascade && bear>=CascMinScore && moveDn>=CascPip1 && cVol && h4bear && h1bear && rsi1<50 && sess && cascCoolOk && c1<ma1 && (moveDn>=CascPip3 || cSizeOk);
   bool cascBuy  = UseCascade && bull>=CascMinScore && moveUp>=CascPip1 && cVol && h4bull && h1bull && rsi1>50 && sess && cascCoolOk && c1>ma1 && (moveUp>=CascPip3 || cSizeOk);

   bool finalBuy  = buySig || cascBuy;
   bool finalSell = sellSig || cascSell;
   if(!finalBuy && !finalSell) return;

   double slDist=atr*AtrSLMult, trailDist=atr*AtrTrailMult;
   double lots=CalcLots(slDist); if(lots<=0) return;

   if(finalBuy){
      double price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=price-slDist, tp=price+slDist*Tp3Mult;
      if(trade.Buy(lots,_Symbol,price,sl,tp)){
         sEntry=price; sSL=sl; sTP=tp; sSLdist=slDist; sTrailDist=trailDist; sInitLots=lots;
         sIsLong=true; sTp1=false; sTp2=false; sBE=false; sTrail=false;
         lastEntryBar=barIdx; if(cascBuy) lastCascBar=barIdx;
      }
   } else if(finalSell){
      double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=price+slDist, tp=price-slDist*Tp3Mult;
      if(trade.Sell(lots,_Symbol,price,sl,tp)){
         sEntry=price; sSL=sl; sTP=tp; sSLdist=slDist; sTrailDist=trailDist; sInitLots=lots;
         sIsLong=false; sTp1=false; sTp2=false; sBE=false; sTrail=false;
         lastEntryBar=barIdx; if(cascSell) lastCascBar=barIdx;
      }
   }
}
//+------------------------------------------------------------------+
