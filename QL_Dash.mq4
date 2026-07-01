//+------------------------------------------------------------------+
//|                                                       QL_Dash.mq4  |
//|                            MT4 QuickLine Suite v1.0                |
//+------------------------------------------------------------------+
#property copyright   "QuickLine Suite"
#property link        ""
#property version     "1.10"
#property description "QL_Dash - Dashed line, Width 1"
#property description "Drop on chart, line appears at clicked price."
#property description "Color auto-switches by Bid position."
#property description "Length = BaseLength * throwCount * ScaleMultiplier."
#property description "LengthMode lets you measure in Bars / Sec / Min / Hour / Day"
#property description "so the same line width looks the same on M1..D1."
#property strict

//+------------------------------------------------------------------+
//| Engine: shared across all QL_*.mq4 scripts.                      |
//| Per-script differences:                                          |
//|   - STYLE: STYLE_DASH                                            |
//|   - WIDTH: 1                                                     |
//|   - Default ColorAbove=Yellow, ColorBelow=Purple.                |
//+------------------------------------------------------------------+

enum ENUM_QL_LENGTH_MODE
  {
   MODE_BARS  = 0,
   MODE_SECS  = 1,
   MODE_MINS  = 2,
   MODE_HOURS = 3,
   MODE_DAYS  = 4,
  };

input int              BaseLength      = 30;
input ENUM_QL_LENGTH_MODE LengthMode    = MODE_BARS;
input int              ScaleMultiplier = 1;
input color            ColorAbove      = clrYellow;      // Color when dropped ABOVE Bid
input color            ColorBelow      = clrPurple;      // Color when dropped BELOW Bid
input bool             Selectable      = true;
input bool             Back            = false;
input bool             Hidden          = false;
input bool             Ray             = false;

const int    STYLE       = STYLE_DASH;
const int    WIDTH       = 1;
const string PREFIX      = "QL_Dash_";

string GvCounterName()  { return(PREFIX + "counter"); }

int NextCounter()
  {
   string gv = GvCounterName();
   int n = 0;
   if(GlobalVariableCheck(gv)) n = (int)GlobalVariableGet(gv);
   n = n + 1;
   GlobalVariableSet(gv, (double)n);
   return(n);
  }

string MakeName()
  {
   string base = PREFIX + TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS);
   StringReplace(base, " ", "_");
   StringReplace(base, ":", "");
   StringReplace(base, ".", "");
   return(base);
  }

int BarsForSeconds(int targetSeconds)
  {
   if(targetSeconds <= 0) return(0);
   datetime t0 = iTime(Symbol(), Period(), 0);
   int maxBars = Bars(Symbol(), Period());
   if(maxBars <= 0) return(0);
   for(int i = 1; i < maxBars; i++)
     {
      datetime tBar = iTime(Symbol(), Period(), i);
      if(tBar == 0) break;
      if((long)(t0 - tBar) >= targetSeconds) return(i);
     }
   return(maxBars - 1);
  }

int ComputeLeftBar()
  {
   int throwCount    = NextCounter();
   long multiplier   = (long)ScaleMultiplier;
   if(multiplier < 1)  multiplier = 1;
   if(multiplier > 10) multiplier = 10;
   long raw = (long)BaseLength * (long)throwCount * multiplier;
   if(raw < 1) raw = 1;

   int leftBar = 0;
   switch(LengthMode)
     {
      case MODE_BARS:  leftBar = (int)raw;                          break;
      case MODE_SECS:  leftBar = BarsForSeconds((int)raw);          break;
      case MODE_MINS:  leftBar = BarsForSeconds((int)raw * 60);     break;
      case MODE_HOURS: leftBar = BarsForSeconds((int)raw * 3600);  break;
      case MODE_DAYS:  leftBar = BarsForSeconds((int)raw * 86400);  break;
     }

   int maxBars = Bars(Symbol(), Period());
   if(maxBars > 0 && leftBar >= maxBars) leftBar = maxBars - 1;
   if(leftBar < 0) leftBar = 0;
   return(leftBar);
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

void OnStart()
  {
   if(ChartID() == 0) return;

   double price = WindowPriceOnDropped();
   if(price == 0.0) price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   color  lineColor = (price >= bid) ? ColorBelow : ColorAbove;

   int leftBar    = ComputeLeftBar();
   int rightBar   = 0;
   int throwCount = (int)GlobalVariableGet(GvCounterName());

   string name = MakeName();

   if(!ObjectCreate(ChartID(), name, OBJ_TREND, 0,
                    iTime(Symbol(), Period(), leftBar),  price,
                    iTime(Symbol(), Period(), rightBar), price))
     {
      Print("QL_Dash: failed to create object '", name, "'. Error=", GetLastError());
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

   Print("QL_Dash placed @ ", DoubleToString(price, Digits),
         " | span=", leftBar, " bars (", BaseLength, " ", UnitLabel(),
         " x", throwCount, " throws x", ScaleMultiplier, ")",
         " | color=", (price >= bid ? "Below" : "Above"));
  }
//+------------------------------------------------------------------+
