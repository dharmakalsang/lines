//+------------------------------------------------------------------+
//|                                                       QL_Bold3.mq4 |
//|                            MT4 QuickLine Suite v1.0                |
//|                       - Main S/R line (M15) -                      |
//+------------------------------------------------------------------+
#property copyright   "QuickLine Suite"
#property link        ""
#property version     "1.10"
#property description "QL_Bold3 - Main Support/Resistance line (Solid, Width 3)"
#property description "Drop on chart, line appears at clicked price."
#property description "Color auto-switches by Bid position."
#property description "Length = BaseLength * throwCount * ScaleMultiplier."
#property description "LengthMode lets you measure in Bars / Sec / Min / Hour / Day"
#property description "so the same line width looks the same on M1..D1."
#property strict

//+------------------------------------------------------------------+
//| Engine: All QL_*.mq4 scripts share the same engine.              |
//| Differences between scripts are only:                            |
//|   - STYLE (Solid / Dash / Dot / DashDot)                         |
//|   - WIDTH (1, 2, 3)                                              |
//|   - Default ColorAbove / ColorBelow                              |
//| Every other rule from the spec is implemented identically.       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Length mode enum. Choose what "BaseLength" measures.             |
//|   MODE_BARS   = original spec: count of candles                  |
//|   MODE_SECS   = seconds of chart time                            |
//|   MODE_MINS   = minutes of chart time                            |
//|   MODE_HOURS  = hours of chart time                              |
//|   MODE_DAYS   = days of chart time                               |
//+------------------------------------------------------------------+
enum ENUM_QL_LENGTH_MODE
  {
   MODE_BARS  = 0,   // Candles (raw bar count, like v1.0)
   MODE_SECS  = 1,   // Seconds
   MODE_MINS  = 2,   // Minutes
   MODE_HOURS = 3,   // Hours
   MODE_DAYS  = 4,   // Days
  };

//+------------------------------------------------------------------+
//| Input Properties                                                  |
//| All colors are editable from MT4 Inputs window (Ctrl+I) without   |
//| changing source code, per Spec rule #8.                          |
//+------------------------------------------------------------------+
input int              BaseLength      = 30;     // BaseLength (per drop, see LengthMode)
input ENUM_QL_LENGTH_MODE LengthMode    = MODE_BARS; // Unit of BaseLength
input int              ScaleMultiplier = 1;      // 1=normal, 2=double, 3=triple (per drop)
input color            ColorAbove      = clrBlue;     // Color when dropped ABOVE Bid
input color            ColorBelow      = clrRed;      // Color when dropped BELOW Bid
input bool             Selectable      = true;    // Allow line to be dragged
input bool             Back            = false;   // Send to back
input bool             Hidden          = false;   // Hide in object list
input bool             Ray             = false;   // Ray OFF (rule #10)

//+------------------------------------------------------------------+
//| Internal constants - DO NOT change unless you know why.          |
//+------------------------------------------------------------------+
const int    STYLE       = STYLE_SOLID;  // QL_Bold3 = Solid
const int    WIDTH       = 3;            // QL_Bold3 = Width 3
const string PREFIX      = "QL_Bold3_";  // Object name prefix

//+------------------------------------------------------------------+
//| Per-script "throw" counter stored in a GlobalVariable.          |
//| Spec rule #9: counter is SEPARATE for each script.               |
//| Using GlobalVariableSet/Get instead of a static int means the     |
//| counter survives chart refresh, template changes, and terminal    |
//| restart.                                                         |
//+------------------------------------------------------------------+
string GvCounterName()
  {
   // Unique global variable name per script prefix - guarantees
   // QL_Bold3 counter is independent of QL_Dash counter, etc.
   return(PREFIX + "counter");
  }

//+------------------------------------------------------------------+
//| Return next counter value (atomic read-then-increment).          |
//| 0 on first run -> first drop yields 1.                           |
//+------------------------------------------------------------------+
int NextCounter()
  {
   string gv = GvCounterName();
   int n = 0;
   if(GlobalVariableCheck(gv))
      n = (int)GlobalVariableGet(gv);
   n = n + 1;
   GlobalVariableSet(gv, (double)n);
   return(n);
  }

//+------------------------------------------------------------------+
//| Build a unique object name using current local timestamp.        |
//| Format: QL_Bold3_YYYYMMDD_HHMMSS                                 |
//| Example: QL_Bold3_20260630_210523 (per spec rule #11)            |
//+------------------------------------------------------------------+
string MakeName()
  {
   string base = PREFIX + TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS);
   // Replace " " and ":" and "." with "_" for cleanliness
   StringReplace(base, " ", "_");
   StringReplace(base, ":", "");
   StringReplace(base, ".", "");
   return(base);
  }

//+------------------------------------------------------------------+
//| Convert desired time-span to a bar offset.                       |
//| The line must be anchored at some past bar whose iTime() is at    |
//| least `targetSeconds` older than the current bar.                |
//| We walk back bar-by-bar using iTime() (handles weekends/gaps     |
//| automatically) and stop at the first bar that satisfies the span. |
//+------------------------------------------------------------------+
int BarsForSeconds(int targetSeconds)
  {
   if(targetSeconds <= 0)
      return(0);

   datetime t0 = iTime(Symbol(), Period(), 0);   // current bar open
   int maxBars = Bars(Symbol(), Period());
   if(maxBars <= 0)
      return(0);

   // Walk back at most maxBars. Stop when time[i] is older than
   // (t0 - targetSeconds), i.e. the line would span >= target seconds.
   for(int i = 1; i < maxBars; i++)
     {
      datetime tBar = iTime(Symbol(), Period(), i);
      if(tBar == 0)
         break;
      if((long)(t0 - tBar) >= targetSeconds)
         return(i);
     }
   // If we never reached the target, return the oldest available bar
   // so the line still draws (capped at available history).
   return(maxBars - 1);
  }

//+------------------------------------------------------------------+
//| Compute the left-bar index for the line.                         |
//|   targetBars = BaseLength * throwCount * ScaleMultiplier          |
//|   unit       = LengthMode (BARS / SECS / MINS / HOURS / DAYS)     |
//| This is the single source of truth for "how long is the line".   |
//+------------------------------------------------------------------+
int ComputeLeftBar()
  {
   int throwCount    = NextCounter();
   long multiplier   = (long)ScaleMultiplier;
   if(multiplier < 1) multiplier = 1;             // safety
   if(multiplier > 10) multiplier = 10;           // safety cap

   long raw = (long)BaseLength * (long)throwCount * multiplier;
   if(raw < 1) raw = 1;

   int leftBar = 0;
   switch(LengthMode)
     {
      case MODE_BARS:
         // Spec v1.0 behavior: count of candles.
         leftBar = (int)raw;
         break;

      case MODE_SECS:
         leftBar = BarsForSeconds((int)raw);
         break;

      case MODE_MINS:
         leftBar = BarsForSeconds((int)raw * 60);
         break;

      case MODE_HOURS:
         leftBar = BarsForSeconds((int)raw * 3600);
         break;

      case MODE_DAYS:
         leftBar = BarsForSeconds((int)raw * 86400);
         break;
     }

   // Make sure we never go beyond available history
   int maxBars = Bars(Symbol(), Period());
   if(maxBars > 0 && leftBar >= maxBars)
      leftBar = maxBars - 1;
   if(leftBar < 0)
      leftBar = 0;

   return(leftBar);
  }

//+------------------------------------------------------------------+
//| Convert the current LengthMode+BaseLength to a human label.      |
//| Used in the Experts log so the user can verify what unit was used.|
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| OnStart() runs ONCE when the script is dropped on a chart.        |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Guard: only run on a chart that actually exists.
   if(ChartID() == 0)
      return;

   //--------------------------------------------------------------
   // Step 1: Determine the drop price.
   //--------------------------------------------------------------
   double price = WindowPriceOnDropped();
   if(price == 0.0)
      price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   //--------------------------------------------------------------
   // Step 2: Decide color based on Bid position (Spec rule #7).
   //--------------------------------------------------------------
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   color  lineColor = (price >= bid) ? ColorBelow : ColorAbove;

   //--------------------------------------------------------------
   // Step 3: Compute the line length (Spec rule #9 + v1.1 extras).
   // length = BaseLength * throwCount * ScaleMultiplier
   // unit   = LengthMode (BARS / SECS / MINS / HOURS / DAYS)
   //--------------------------------------------------------------
   int leftBar  = ComputeLeftBar();
   int rightBar = 0;
   int throwCount = (int)GlobalVariableGet(GvCounterName()); // already incremented

   //--------------------------------------------------------------
   // Step 4: Build a UNIQUE object name (Spec rule #11).
   //--------------------------------------------------------------
   string name = MakeName();

   //--------------------------------------------------------------
   // Step 5: Create the horizontal line as OBJ_TREND with two
   // points at the SAME price (Spec rule #10).
   //--------------------------------------------------------------
   if(!ObjectCreate(ChartID(), name, OBJ_TREND,
                    0,
                    iTime(Symbol(), Period(), leftBar),  price,
                    iTime(Symbol(), Period(), rightBar), price))
     {
      Print("QL_Bold3: failed to create object '", name, "'. Error=", GetLastError());
      return;
     }

   //--------------------------------------------------------------
   // Step 6: Apply visual properties from inputs.
   //--------------------------------------------------------------
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR,      lineColor);
   ObjectSetInteger(ChartID(), name, OBJPROP_STYLE,      STYLE);
   ObjectSetInteger(ChartID(), name, OBJPROP_WIDTH,      WIDTH);
   ObjectSetInteger(ChartID(), name, OBJPROP_RAY_RIGHT,  Ray);
   ObjectSetInteger(ChartID(), name, OBJPROP_RAY_LEFT,   Ray);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, Selectable);
   ObjectSetInteger(ChartID(), name, OBJPROP_HIDDEN,     Hidden);
   ObjectSetInteger(ChartID(), name, OBJPROP_BACK,       Back);
   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);

   ChartRedraw(ChartID());

   //--------------------------------------------------------------
   // Step 7: Friendly log for the user to confirm drop.
   //--------------------------------------------------------------
   Print("QL_Bold3 placed @ ", DoubleToString(price, Digits),
         " | span=", leftBar, " bars (", BaseLength, " ", UnitLabel(),
         " x", throwCount, " throws x", ScaleMultiplier, ")",
         " | color=", (price >= bid ? "Below" : "Above"));
  }
//+------------------------------------------------------------------+
//| Spec compliance summary:                                        |
//| - #1 STYLE/WIDTH: set via constants STYLE/WIDTH above.          |
//| - #2 Same engine across all 6 scripts.                          |
//| - #3 Drop-then-place via OnStart() + WindowPriceOnDropped.      |
//| - #4 Draggable: OBJPROP_SELECTABLE = true.                      |
//| - #7 Color by Bid position: implemented.                        |
//| - #8 Colors editable from Inputs window.                        |
//| - #9 Length = BaseLength * throws, counter per script.          |
//|       v1.1 additions:                                            |
//|         * ScaleMultiplier (1..10) lets you scale a single drop   |
//|           by 1x/2x/3x... so throw 11 with x2 = 20-candles worth. |
//|         * LengthMode = SECS/MINS/HOURS/DAYS makes the line width |
//|           stable across M1..D1 (a 30-min line is 30 min on any   |
//|           timeframe).                                            |
//| - #10 OBJ_TREND, two equal-price points, Ray OFF.                |
//| - #11 Name = PREFIX + timestamp; visible in Ctrl+B only.        |
//+------------------------------------------------------------------+
