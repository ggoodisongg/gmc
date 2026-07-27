//+------------------------------------------------------------------+
//|                    G MONEY CORE — GMC v1.3                      |
//|  ENTRY  = Sniper v9.5 confluence (MA/RSI/Vol/Wick + H4/H1 + casc)|
//|  RISK   = Track B v3.33 engine (ATR stop, staged exits, safety)  |
//|  v1.1   = adds live spread filter (skip entries in thin markets) |
//|  v1.2   = score-tiered risk — A/B REJECTED, default OFF          |
//|  v1.3   = ATR-percentile adaptive SL: stop width scales with     |
//|           current volatility rank (quiet=tight, wild=wide);      |
//|           cash risk per trade stays constant at Risk_Percent     |
//|  Best-proven entry + best-proven risk management. Run on M5.     |
//+------------------------------------------------------------------+
#property copyright "G Money Systems"
#property version   "1.30"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//==================================================================
// INPUTS
//==================================================================
input group "--- EA Identity ---"
input string EA_Name           = "GMC v1.3";
input int    Magic_Number      = 10034;
input int    Slippage_Points   = 20;

input group "--- Risk & Lots (Track B engine) ---"
input double Risk_Percent      = 1.0;
input double Max_Lot_Size      = 0.20;
input double Min_Lot_Size      = 0.01;

input group "--- Score-Tiered Risk (v1.2 layer — A/B REJECTED, keep false) ---"
input bool   Use_Tiered_Risk   = false;  // REJECTED in A/B: leave false
input double Risk_Mult_Score6  = 1.00;   // perfect 6/6 confluence: full risk
input double Risk_Mult_Score5  = 0.75;   // strong cascade entry
input double Risk_Mult_Score4  = 0.50;   // minimum-evidence cascade entry

input group "--- Execution / HTF ---"
input ENUM_TIMEFRAMES Signal_TF = PERIOD_M5;   // run chart on this
input bool   Use_H4_Gate       = true;
input bool   Use_H1_Gate       = true;

input group "--- Sniper Entry: Confluence ---"
input int    MA_Period         = 50;
input int    RSI_Period        = 14;
input int    Vol_Period        = 20;
input double Vol_Mult          = 1.5;
input double Wick_Threshold    = 55.0;
input double Body_Threshold    = 38.0;
input double Vola_Dist_Pips    = 60.0;
input int    Min_Score         = 6;      // FROZEN: perfect 6/6 only
input bool   Use_Buffer        = true;
input bool   Filter_Small_Wicks= true;
input bool   Use_Confirm_Bar   = true;
input int    Cooldown_Bars     = 3;

input group "--- Sniper Entry: Cascade (momentum add-on) ---"
input bool   Use_Cascade       = true;
input double Casc_Pip1         = 8.0;
input double Casc_Pip2         = 15.0;
input double Casc_Pip3         = 25.0;
input int    Casc_Bars         = 6;
input double Casc_Vol          = 1.8;
input int    Casc_Cooldown     = 3;
input int    Casc_Min_Score    = 4;

input group "--- ATR-Percentile Adaptive SL (v1.3 layer — A/B REJECTED, keep false) ---"
input bool   Use_Adaptive_SL   = false;   // REJECTED in A/B: leave false (fixed 2.0x ATR stop)
input int    ATR_Pct_Lookback  = 500;     // Signal_TF bars of ATR history to rank against
input double ATR_Pct_Low       = 30.0;    // at/below this percentile = quiet market
input double ATR_Pct_High      = 70.0;    // at/above this percentile = volatile market
input double SL_Mult_LowVol    = 1.6;     // tighter stop when quiet
input double SL_Mult_HighVol   = 2.6;     // wider stop when volatile

input group "--- Stops & Targets (Track B) ---"
input int    ATR_Period        = 14;
input double SL_ATR_Multiplier = 2.0;    // FROZEN
input double TP1_R             = 1.8;   // FROZEN: bank partial later
input double TP_Final_R        = 5.5;   // FROZEN: let runners target further
input double Min_SL_Pips       = 70.0;
input double Max_SL_Pips       = 380.0;

input group "--- Trade Management (Track B) ---"
input double BE_Trigger_R      = 1.0;
input double Partial_Close_Pct = 35.0;   // FROZEN: bank less, ride more
input double Trail_Start_R     = 2.5;    // FROZEN
input double Trail_R_Step      = 0.6;    // FROZEN: looser trail

input group "--- Spread Filter ---"
input bool   Use_Spread_Filter = true;
input int    Max_Spread_Points = 50;    // XAUUSD points (0.01 each); skip entries above this

input group "--- Session (GMT) & Safety ---"
input bool   Use_Session_Filter= true;
input int    Lon_Start         = 700;   // HHMM GMT
input int    Lon_End           = 1600;
input int    NY_Start          = 1300;
input int    NY_End            = 2100;
input double Daily_Max_Loss_Pct= 7.0;
input int    Max_Consec_Losses = 4;
input int    Cooldown_Mins     = 30;

//==================================================================
// GLOBALS
//==================================================================
double   pip;
int      hMA, hRSI, hATR, hH4, hH1;
datetime last_bar_time = 0;
int      bar_idx = 0, last_entry_bar = -100000, last_casc_bar = -100000;
double   daily_start_balance = 0.0, daily_max_loss = 0.0;
int      consecutive_losses = 0;
datetime cooldown_until = 0;
ulong    g_ticket = 0;
double   g_risk_pips = 0.0;
bool     g_be=false, g_partial=false, g_trail=false;

//==================================================================
// HELPERS
//==================================================================
void   Log(string s){ Print(EA_Name+" | "+s); }
double P2Px(double p){ return p*pip; }

double Bf(int h,int sh){ double b[]; if(CopyBuffer(h,0,sh,1,b)<=0) return(EMPTY_VALUE); return(b[0]); }
double Hi(int per,int st){ double m=-DBL_MAX; for(int i=st;i<st+per;i++){double v=iHigh(_Symbol,Signal_TF,i); if(v>m)m=v;} return m; }
double Lo(int per,int st){ double m=DBL_MAX;  for(int i=st;i<st+per;i++){double v=iLow(_Symbol,Signal_TF,i);  if(v<m)m=v;} return m; }
double AvgVol(){ double s=0; for(int i=1;i<=Vol_Period;i++) s+=(double)iVolume(_Symbol,Signal_TF,i); return s/Vol_Period; }
double AvgRange(){ double s=0; for(int i=1;i<=5;i++) s+=(iHigh(_Symbol,Signal_TF,i)-iLow(_Symbol,Signal_TF,i)); return s/5.0; }
int    NowHHMM(){ MqlDateTime dt; TimeToStruct(TimeGMT(),dt); return dt.hour*100+dt.min; }
bool   InR(int t,int a,int b){ return (t>=a && t<b); }

bool SpreadOK()
{
   if(!Use_Spread_Filter) return true;
   long sp=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(sp<=Max_Spread_Points) return true;
   Log("Entry skipped — spread "+IntegerToString((int)sp)+" pts > cap "+IntegerToString(Max_Spread_Points));
   return false;
}

bool InSession()
{
   if(!Use_Session_Filter) return true;
   int t=NowHHMM();
   return InR(t,Lon_Start,Lon_End) || InR(t,NY_Start,NY_End);
}

bool SelectMyPosition()
{
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i);
      if(PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==Magic_Number) return true; }
   return false;
}

double TierMult(int score)
{
   if(!Use_Tiered_Risk) return 1.0;
   if(score>=6) return Risk_Mult_Score6;
   if(score==5) return Risk_Mult_Score5;
   return Risk_Mult_Score4;
}

// v1.3: rank last-closed-bar ATR against recent ATR history and pick the
// stop multiplier for the current volatility regime. Falls back to the
// frozen baseline multiplier if the switch is off or history is short.
double AdaptiveSLMult()
{
   if(!Use_Adaptive_SL) return SL_ATR_Multiplier;
   double a[];
   int n=CopyBuffer(hATR,0,1,ATR_Pct_Lookback,a);
   if(n<100) return SL_ATR_Multiplier;
   double cur=a[n-1];   // newest element (shift 1)
   int below=0;
   for(int i=0;i<n;i++) if(a[i]<=cur) below++;
   double pct=100.0*below/n;
   if(pct>=ATR_Pct_High) return SL_Mult_HighVol;
   if(pct<=ATR_Pct_Low)  return SL_Mult_LowVol;
   return SL_ATR_Multiplier;
}

double CalcLots(double sl_pips, double risk_mult, bool &valid)
{
   valid=false; if(sl_pips<=0||risk_mult<=0) return 0.0;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amt=bal*(Risk_Percent*risk_mult)/100.0;
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(tv<=0||ts<=0||step<=0) return 0.0;
   double risk_per_lot=(sl_pips*pip/ts)*tv;
   if(risk_per_lot<=0) return 0.0;
   double lot=risk_amt/risk_per_lot;
   lot=NormalizeDouble(MathFloor(lot/step)*step,2);
   if(lot<Min_Lot_Size) lot=Min_Lot_Size;
   if(lot>Max_Lot_Size) lot=Max_Lot_Size;
   valid=true; return lot;
}

bool SafetyChecks()
{
   if(daily_start_balance<=0) return true;
   double cur=AccountInfoDouble(ACCOUNT_BALANCE);
   if((daily_start_balance-cur)>=daily_max_loss){ Log("Daily loss limit — paused"); return false; }
   if(consecutive_losses>=Max_Consec_Losses)
   {
      if(cooldown_until==0) cooldown_until=TimeCurrent()+Cooldown_Mins*60;
      if(TimeCurrent()<cooldown_until) return false;
      consecutive_losses=0; cooldown_until=0; Log("Cooldown finished — resumed");
   }
   return true;
}

//==================================================================
int OnInit()
{
   pip=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(StringFind(_Symbol,"XAU")>=0 || StringFind(_Symbol,"GOLD")>=0) pip*=10;
   hMA = iMA(_Symbol, Signal_TF, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
   hRSI= iRSI(_Symbol, Signal_TF, RSI_Period, PRICE_CLOSE);
   hATR= iATR(_Symbol, Signal_TF, ATR_Period);
   hH4 = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_SMA, PRICE_CLOSE);
   hH1 = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE);
   if(hMA==INVALID_HANDLE||hRSI==INVALID_HANDLE||hATR==INVALID_HANDLE||hH4==INVALID_HANDLE||hH1==INVALID_HANDLE)
   { Log("Indicator init failed"); return INIT_FAILED; }
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(Slippage_Points);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetMarginMode();
   daily_start_balance=AccountInfoDouble(ACCOUNT_BALANCE);
   daily_max_loss=daily_start_balance*(Daily_Max_Loss_Pct/100.0);
   Log("GMC v1.3 ready (Sniper entry + Track B risk + spread filter + adaptive SL)");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r)
{
   IndicatorRelease(hMA); IndicatorRelease(hRSI); IndicatorRelease(hATR);
   IndicatorRelease(hH4); IndicatorRelease(hH1);
}

//==================================================================
// TRACK B RISK MANAGEMENT
//==================================================================
void ManagePosition()
{
   if(!SelectMyPosition()) return;
   ulong  ticket=(ulong)PositionGetInteger(POSITION_TICKET);
   double entry =PositionGetDouble(POSITION_PRICE_OPEN);
   double sl    =PositionGetDouble(POSITION_SL);
   double tp    =PositionGetDouble(POSITION_TP);
   double vol   =PositionGetDouble(POSITION_VOLUME);
   bool   is_buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double price =is_buy?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   if(ticket!=g_ticket){ g_ticket=ticket; g_be=false; g_partial=false; g_trail=false; g_risk_pips=(sl>0)?MathAbs(entry-sl)/pip:0.0; }
   double risk=g_risk_pips; if(risk<=0) return;
   double profit=is_buy?(price-entry)/pip:(entry-price)/pip;

   if(!g_be && profit>=risk*BE_Trigger_R)
   {
      double nsl=is_buy?MathMax(entry,sl):(sl>0?MathMin(entry,sl):entry);
      if(nsl!=sl && trade.PositionModify(ticket,nsl,tp)){ g_be=true; sl=nsl; Log("Break-even"); }
   }
   if(!g_partial && profit>=risk*TP1_R)
   {
      double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      double amt=(step>0)?MathFloor((vol*Partial_Close_Pct/100.0)/step)*step:vol*Partial_Close_Pct/100.0;
      amt=NormalizeDouble(amt,2);
      if(amt>=Min_Lot_Size && amt<vol){ if(trade.PositionClosePartial(ticket,amt)){ g_partial=true; Log("Partial @ TP1"); } }
      else g_partial=true;
   }
   if(!g_trail && profit>=risk*Trail_Start_R){ g_trail=true; Log("Trailing on"); }
   if(g_trail)
   {
      double dist=risk*Trail_R_Step;
      double nsl=is_buy?price-P2Px(dist):price+P2Px(dist);
      nsl=is_buy?MathMax(nsl,sl):(sl>0?MathMin(nsl,sl):nsl);
      if(MathAbs(nsl-sl)>pip*0.1) trade.PositionModify(ticket,nsl,tp);
   }
}

//==================================================================
// MAIN
//==================================================================
void OnTick()
{
   static datetime reset=0;
   datetime today=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));
   if(today!=reset){ reset=today; daily_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); daily_max_loss=daily_start_balance*(Daily_Max_Loss_Pct/100.0); consecutive_losses=0; cooldown_until=0; }

   if(SelectMyPosition()){ ManagePosition(); return; }
   if(!SafetyChecks()) return;

   datetime cb=iTime(_Symbol,Signal_TF,0);
   if(cb==last_bar_time) return;
   last_bar_time=cb; bar_idx++;

   double atr1=Bf(hATR,1); if(atr1==EMPTY_VALUE||atr1<=0) return;
   double c1=iClose(_Symbol,Signal_TF,1), o1=iOpen(_Symbol,Signal_TF,1), h1=iHigh(_Symbol,Signal_TF,1), l1=iLow(_Symbol,Signal_TF,1);
   double ma1=Bf(hMA,1), ma7=Bf(hMA,7);
   double rsi1=Bf(hRSI,1), rsi2=Bf(hRSI,2), rsi3=Bf(hRSI,3);
   if(ma1==EMPTY_VALUE||rsi1==EMPTY_VALUE) return;

   // HTF gates
   double h4c=iClose(_Symbol,PERIOD_H4,1), h4a=Bf(hH4,1), h4b=Bf(hH4,4);
   double h1c=iClose(_Symbol,PERIOD_H1,1), h1a=Bf(hH1,1), h1b=Bf(hH1,4);
   bool h4bull=Use_H4_Gate?(h4c>h4a && h4a>h4b):true;
   bool h4bear=Use_H4_Gate?(h4c<h4a && h4a<h4b):true;
   bool h1bull=Use_H1_Gate?(h1c>h1a && h1a>h1b):true;
   bool h1bear=Use_H1_Gate?(h1c<h1a && h1a<h1b):true;

   // trend stable 3 bars
   double maBuf=Use_Buffer?atr1*0.25:0.0;
   bool tBuy=true,tSell=true;
   for(int i=1;i<=3;i++){ double ci=iClose(_Symbol,Signal_TF,i); if(ci<=ma1+maBuf) tBuy=false; if(ci>=ma1-maBuf) tSell=false; }
   bool slopeUp=ma1>ma7, slopeDn=ma1<ma7;

   // rejection candle
   double rng=h1-l1, lw=MathMin(o1,c1)-l1, uw=h1-MathMax(o1,c1), body=MathAbs(o1-c1);
   double avgC=AvgRange();
   bool sizeOk=Filter_Small_Wicks?(rng>avgC*0.70):true;
   bool bullRej=rng>0 && (lw/rng*100>=Wick_Threshold) && (body/rng*100<=Body_Threshold) && sizeOk;
   bool bearRej=rng>0 && (uw/rng*100>=Wick_Threshold) && (body/rng*100<=Body_Threshold) && sizeOk;

   // volume + rsi
   double av=AvgVol(); bool volOk=(double)iVolume(_Symbol,Signal_TF,1)>=av*Vol_Mult;
   bool rsiBull=h4bull?(rsi1>=42 && rsi1<=75):(rsi1>=38 && rsi1<=62);
   bool rsiBear=h4bear?(rsi1>=25 && rsi1<=58):(rsi1>=38 && rsi1<=62);
   bool rsiUp=rsi1>rsi2 && rsi2>rsi3;
   bool rsiDn=rsi1<rsi2 && rsi2<rsi3;

   bool volaOk=((Hi(10,1)-Lo(10,1))/pip)<=Vola_Dist_Pips;

   // scores
   int bull=(tBuy?1:0)+(bullRej?1:0)+(volOk?1:0)+(rsiBull?1:0)+(slopeUp?1:0)+((h4bull&&h1bull)?1:0);
   int bear=(tSell?1:0)+(bearRej?1:0)+(volOk?1:0)+(rsiBear?1:0)+(slopeDn?1:0)+((h4bear&&h1bear)?1:0);
   bool bullPerfect=bull>=Min_Score, bearPerfect=bear>=Min_Score;
   bool bullConf=Use_Confirm_Bar?(c1>o1 && rsiUp):true;
   bool bearConf=Use_Confirm_Bar?(c1<o1 && rsiDn):true;

   bool sess=InSession();
   bool cool=(bar_idx-last_entry_bar)>=Cooldown_Bars;
   bool cascCool=(bar_idx-last_casc_bar)>=Casc_Cooldown;

   bool buySig =bullPerfect && bullConf && volaOk && sess && cool;
   bool sellSig=bearPerfect && bearConf && volaOk && sess && cool;

   // cascade
   double moveDn=(Hi(Casc_Bars,1)-c1)/pip, moveUp=(c1-Lo(Casc_Bars,1))/pip;
   bool cVol=(double)iVolume(_Symbol,Signal_TF,1)>=av*Casc_Vol;
   bool cSize=rng>avgC*1.1;
   bool cascSell=Use_Cascade && bear>=Casc_Min_Score && moveDn>=Casc_Pip1 && cVol && h4bear && h1bear && rsi1<50 && sess && cascCool && c1<ma1 && (moveDn>=Casc_Pip3 || cSize);
   bool cascBuy =Use_Cascade && bull>=Casc_Min_Score && moveUp>=Casc_Pip1 && cVol && h4bull && h1bull && rsi1>50 && sess && cascCool && c1>ma1 && (moveUp>=Casc_Pip3 || cSize);

   bool finalBuy =buySig || cascBuy;
   bool finalSell=sellSig || cascSell;
   if(!finalBuy && !finalSell) return;
   if(!SpreadOK()) return;

   // ---- Track B execution (v1.3: SL width adapts to volatility rank) ----
   int    entryScore=finalBuy?bull:bear;
   double rmult=TierMult(entryScore);
   double slmult=AdaptiveSLMult();
   double sl_pips=atr1*slmult/pip;
   sl_pips=MathMax(Min_SL_Pips,MathMin(sl_pips,Max_SL_Pips));
   bool valid=false; double lot=CalcLots(sl_pips,rmult,valid);
   if(!valid||lot<Min_Lot_Size) return;

   if(finalBuy)
   {
      double e=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=e-P2Px(sl_pips), tp=e+P2Px(sl_pips*TP_Final_R);
      if(trade.Buy(lot,_Symbol,e,sl,tp,"GMC LONG")){ last_entry_bar=bar_idx; if(cascBuy) last_casc_bar=bar_idx; Log("LONG | score "+IntegerToString(bull)+" | slx"+DoubleToString(slmult,2)+" | lot "+DoubleToString(lot,2)); }
   }
   else if(finalSell)
   {
      double e=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=e+P2Px(sl_pips), tp=e-P2Px(sl_pips*TP_Final_R);
      if(trade.Sell(lot,_Symbol,e,sl,tp,"GMC SHORT")){ last_entry_bar=bar_idx; if(cascSell) last_casc_bar=bar_idx; Log("SHORT | score "+IntegerToString(bear)+" | slx"+DoubleToString(slmult,2)+" | lot "+DoubleToString(lot,2)); }
   }
}

//==================================================================
void OnTrade()
{
   if(SelectMyPosition()) return;
   static ulong last_counted=0;
   HistorySelect(TimeCurrent()-86400,TimeCurrent());
   for(int i=HistoryDealsTotal()-1;i>=0;i--)
   {
      ulong t=HistoryDealGetTicket(i);
      if(t==0) continue;
      if(HistoryDealGetInteger(t,DEAL_MAGIC)!=Magic_Number) continue;
      if(HistoryDealGetInteger(t,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      if(t==last_counted) break;
      last_counted=t;
      double p=HistoryDealGetDouble(t,DEAL_PROFIT);
      if(p>=0) consecutive_losses=0; else consecutive_losses++;
      Log("Closed | P&L "+DoubleToString(p,2)+" | streak "+IntegerToString(consecutive_losses));
      break;
   }
}
//+------------------------------------------------------------------+
