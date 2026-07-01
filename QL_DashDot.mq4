//+------------------------------------------------------------------+
//|                                                       QL_DashDot.mq4 |
//|                            MT4 QuickLine Suite v1.0                |
//+------------------------------------------------------------------+
#property copyright   "QuickLine Suite"
#property link        ""
#property version     "1.20"
#property description "QL_DashDot - Dash-Dot line, Width 1"
#property description "Drop on chart -> line appears at clicked price."
#property description "Color auto-switches by Bid position."
#property description "Length = BaseLength * throwCount * ScaleMultiplier."
#property description "LengthMode lets you measure in Bars / Sec / Min / Hour / Day"
#property description "so the same line width looks the same on M1..D1."
#property description "Counter resets when you Remove the script from the chart."
#property strict

//+------------------------------------------------------------------+
//| Engine: shared across all QL_*.mq4 scripts.                      |
//| Per-script differences:                                           |
//|   - STYLE                                                       |
//|   - WIDTH                                                       |
//|   - Default ColorAbove / ColorBelow                             |
//+------------------------------------------------------------------+

enum ENUM_QL_LENGTH_MODE
  {
   MODE_BARS  = 0,
   MODE_SECS  = 1,
   MODE_MINS  = 2,
   MODE_HOURS = 3,
   MODE_DAYS  = 4,
  };

input int              BaseLength      = 10;
input ENUM_QL_LENGTH_MODE LengthMode    = MODE_BARS;
input int              ScaleMultiplier = 1;
input color            ColorAbove      = clrAqua;
input color            ColorBelow      = clrSilver;
input bool             Selectable      = true;
input bool             Back            = false;
input bool             Hidden          = false;
input bool             Ray             = false;
input bool             ResetOnRemove   = true;

const int    STYLE       = STYLE_DASHDOT;
const int    WIDTH       = 1;
const string PREFIX      = "QL_DashDot_";

string GvCounterName()
  {
   return(PREFIX + "counter_" + IntegerToString(ChartID()));
  }

int CurrentCounter()
  {
   string gv = GvCounterName();
   if(GlobalVariableCheck(gv)) return((int)GlobalVariableGet(gv));
   return(0);
  }

int GetNextCounter()
  {
   string gv = GvCounterName();
   int value = CurrentCounter() + 1;
   GlobalVariableSet(gv, (double)value);
   return(value);
  }

void ResetCounter()
  {
   string gv = GvCounterName();
   if(GlobalVariableCheck(gv)) GlobalVariableDel(gv);
  }

string MakeName(int throwCount)
  {
   string base = PREFIX + TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS);
   StringReplace(base, " ", "_");
   StringReplace(base, ":", "");
   StringReplace(base, ".", "");
   return(base + "_" + IntegerToString(ChartID()) + "_" + IntegerToString(throwCount) + "_" + IntegerToString(GetTickCount()));
  }

int BarsForSeconds(int targetSeconds, int fromBar)
  {
   if(targetSeconds <= 0 || fromBar < 0) return(1);
   int maxBars = Bars(Symbol(), Period());
   if(maxBars <= 0 || fromBar >= maxBars) return(1);

   datetime tBase = iTime(Symbol(), Period(), fromBar);
   if(tBase == 0) return(1);

   for(int i = fromBar + 1; i < maxBars; i++)
     {
      datetime tBar = iTime(Symbol(), Period(), i);
      if(tBar == 0) break;
      if((long)(tBase - tBar) >= targetSeconds) return(i - fromBar);
     }

   return(maxBars - 1 - fromBar);
  }

int ComputeBarCount(int dropBar, int throwCount)
  {
   long multiplier = (long)ScaleMultiplier;
   if(multiplier < 1) multiplier = 1;
   if(multiplier > 10) multiplier = 10;

   long raw = (long)BaseLength * (long)throwCount * multiplier;
   if(raw < 1) raw = 1;

   int barCount = 1;
   switch(LengthMode)
     {
      case MODE_BARS:  barCount = (int)raw; break;
      case MODE_SECS:  barCount = BarsForSeconds((int)raw, dropBar); break;
      case MODE_MINS:  barCount = BarsForSeconds((int)raw * 60, dropBar); break;
      case MODE_HOURS: barCount = BarsForSeconds((int)raw * 3600, dropBar); break;
      case MODE_DAYS:  barCount = BarsForSeconds((int)raw * 86400, dropBar); break;
     }

   int maxBars = Bars(Symbol(), Period());
   if(maxBars > 0 && dropBar + barCount >= maxBars)
      barCount = maxBars - 1 - dropBar;
   if(barCount < 1) barCount = 1;
   return(barCount);
  }

string UnitLabel()
  {
   switch(LengthMode)
     {
      case MODE_BARS:  return("candles");
      case MODE_SECS:  return("seconds");
      case MODE_MINS:  return("minutes");
      case MODE_HOURS: return("hours");
      case MODE_DAYS:  return("days");
     }
   return("candles");
  }

bool GetDropLocation(double &price, datetime &dropTime, int &dropBar)
  {
   price = WindowPriceOnDropped();
   dropTime = WindowTimeOnDropped();

   if(dropTime <= 0)
     {
      dropTime = iTime(Symbol(), Period(), 0);
      Print("QL_DashDot - Dash-Dot line, Width 1: dropped outside chart area; using current bar time fallback.");
     }

   dropBar = iBarShift(Symbol(), Period(), dropTime, true);
   if(dropBar == -1)
      dropBar = iBarShift(Symbol(), Period(), dropTime, false);
   if(dropBar == -1)
      dropBar = 0;

   if(price <= 0.0)
     {
      price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      if(price <= 0.0 && dropBar >= 0)
         price = iClose(Symbol(), Period(), dropBar);
     }

   if(price <= 0.0)
     {
      Print("QL_DashDot - Dash-Dot line, Width 1: invalid price at drop location, aborting.");
      return(false);
     }

   int maxBars = Bars(Symbol(), Period());
   if(dropBar < 0 || dropBar >= maxBars)
     {
      Print("QL_DashDot - Dash-Dot line, Width 1: invalid drop bar index ", dropBar, ", aborting.");
      return(false);
     }

   return(true);
  }

int OnInit()
  {
   int cur = CurrentCounter();
   Print("QL_DashDot - Dash-Dot line, Width 1 attached. Current throw count = ", cur,
         " (next drop length = ", BaseLength, " ", UnitLabel(),
         " x", (cur + 1), " throws x", ScaleMultiplier, ")");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(ResetOnRemove && reason == REASON_REMOVE)
     {
      int cur = CurrentCounter();
      ResetCounter();
      Print("QL_DashDot - Dash-Dot line, Width 1 removed. Counter reset (was ", cur, "). Next attach will start at 1.");
     }
   else
     {
      int cur = CurrentCounter();
      Print("QL_DashDot - Dash-Dot line, Width 1 deinit (reason=", reason, "). Counter preserved = ", cur);
     }
  }

void OnStart()
  {
   if(ChartID() == 0) return;

   double price;
   datetime dropTime;
   int dropBar;
   if(!GetDropLocation(price, dropTime, dropBar))
      return;

   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(bid <= 0.0) bid = price;

   color lineColor = (price >= bid) ? ColorAbove : ColorBelow;
   int throwCount = GetNextCounter();
   int barCount   = ComputeBarCount(dropBar, throwCount);
   int leftBar    = dropBar + barCount;
   int rightBar   = dropBar;

   int maxBars = Bars(Symbol(), Period());
   if(leftBar >= maxBars)
      leftBar = maxBars - 1;

   if(leftBar <= rightBar)
     {
      Print("QL_DashDot - Dash-Dot line, Width 1: not enough history to create a line of the requested length.");
      return;
     }

   string name = MakeName(throwCount);
   if(!ObjectCreate(ChartID(), name, OBJ_TREND, 0,
                    iTime(Symbol(), Period(), leftBar), price,
                    iTime(Symbol(), Period(), rightBar), price))
     {
      Print("QL_DashDot - Dash-Dot line, Width 1: failed to create object '", name, "'. Error=", GetLastError());
      return;
     }

   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR,      lineColor);
   ObjectSetInteger(ChartID(), name, OBJPROP_STYLE,      STYLE);
   ObjectSetInteger(ChartID(), name, OBJPROP_WIDTH,      WIDTH);
   ObjectSetInteger(ChartID(), name, OBJPROP_RAY_RIGHT,  Ray);
   ObjectSetInteger(ChartID(), name, OBJPROP_RAY_LEFT,   Ray);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, Selectable);
   ObjectSetInteger(ChartID(), name, OBJPROP_HIDDEN,     Hidden);
   ObjectSetInteger(ChartID(), name, OBJPROP_BACK,       Back);

   ChartRedraw(ChartID());

   Print("QL_DashDot - Dash-Dot line, Width 1 placed @ ", DoubleToString(price, Digits),
         " | dropBar=", dropBar, " | span=", barCount, " bars (", BaseLength, " ", UnitLabel(),
         " x", throwCount, " throws x", ScaleMultiplier, ")",
         " | color=", (price >= bid ? "Above" : "Below"));
  }
//+------------------------------------------------------------------+
