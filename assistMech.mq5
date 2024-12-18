//+------------------------------------------------------------------+
//|                                                   assistMech.mq5 |
//|                           Copyright 2024, Automated Trading Ltd. |
//|                         https://github.com/H4ck3r217/AssistMech  |
//+------------------------------------------------------------------+
// God is Good 
#property copyright "Copyright 2024, Automated Trading Ltd."
#property link      "https://github.com/H4ck3r217/AssistMech"
#property version   "1.0"
#property description "OnChart-drawn support, resistance and trendlines"
#property description ""
#property description "NOTES FOR USAGE"
#property description ""
#property description "1. Timeframe set to 15M by default ie:- best signals DON'T CHANGE!!!"
#property description "2. Always rename lower trendline to l and upper trendlindline to u"
#property description "3. Always rename support zone to sup and resistant zone to res"
#property description "4. Toggle true on Signlas for AssistMech show signals"
#property description ""
#property description "VALID UNTIL 10 JAN 2025"

#property strict 
#property indicator_chart_window
#property indicator_buffers 2

#property indicator_plots 2

#define PLOT_MAXIMUM_BARS_BACK
#define OMIT_OLDEST_BARS 
#define LICENSED_TRADE_SYMBOLS {"AUDUSD","USDJPY","US30m","EURUSD","Boom 1000 Index","Boom 900 Index","Boom 600 Index","Boom 500 Index","Boom 300 Index","Crash 1000 Index","Crash 900 Index","Crash 600 Index","Crash 500 Index","Crash 300 Index"};               // Edit here for Symbols 
#define LICENSED_TRADE_MODES {ACCOUNT_TRADE_MODE_CONTEST,ACCOUNT_TRADE_MODE_DEMO};          // Edit here for Account Type
#define LICENSED_EXPIRY_DATE_START D'2024.12.25'
#define LICENSED_EXPIRY_DATE_COMPILE __DATETIME__
#define LICENSED_EXPIRY_DAYS 1                                                              // Edit here for days until expiry date

int PLOT_MAXIMUM_BARS_BACK maxBars = 200;
int OMIT_OLDEST_BARS oldBars = 50;
ENUM_TIMEFRAMES timeframe = PERIOD_M15;
int arrows_num = 50;
double ArrowDist = 2;

input group "====SIGNALS ===="
input bool isSupResActive = true;  // Show Support and Resistance Signals
input bool isTrendlineActive = true;  // Show Breakout Signals
bool isRetestActive = false;  // Show Retest Signals


bool Audible_Alerts = true;
datetime time_alert; //used when sending alert

//+------------------------------------------------------------------+
//| ACCOUNT COPY PROTECTION                                          |
//+------------------------------------------------------------------+

long current_AccountNo() { return AccountInfoInteger(ACCOUNT_LOGIN);}
long Current_Account_Mode(){ return AccountInfoInteger(ACCOUNT_TRADE_MODE);}
string Current_Chart_Symbol(){ return Symbol();}

// User Accounts
long Frank = 24202602;                           // Frank Demo account
long Lee = 76765853;                             // Lee Demo Account
long UserAccounts[] = {Frank, Lee};              // Edit here to add/remove Trading Accounts

// User Trading Account 
bool CheckAccountNo(long acc_Inp, long &accounts[], int accountCount){ 

  bool isValid = false; 
  for(int i = 0; i < accountCount; i++){

    if(acc_Inp == accounts[i]){
      isValid = true; 
      break; 
    }
  }

  if(!isValid){

    Print("Invalid Account Number, Revoking the Indicator Now!!!");
    return(false);
  }
  return(true);
}

// Symbols to trade for demo and trial version 
bool CheckTradeSymbols(){

  bool isValid = false;
  string validSymbols[] = LICENSED_TRADE_SYMBOLS;

  for(int i=ArraySize(validSymbols)-1; i>=0; i--){

    if(Current_Chart_Symbol()==validSymbols[i]){

      isValid = true;
      break;
    }
  }

  if(!isValid){

    Print("Negative: Trading is Restricted on Symbol ",Current_Chart_Symbol());
    return(false);
  }
  return(true);
}

// Account Type Restriction for demo and trial version
bool CheckTradeModes(){

  bool isValid = false;
  int validModes[] = LICENSED_TRADE_MODES;
  for(int i=ArraySize(validModes)-1; i>=0; i--){

    if(Current_Account_Mode()==validModes[i]){

      isValid = true;
      break;
    }
  }

  if(!isValid){

    Print("Negative: Trading is Restricted on this Account Type ");
    return(false);
  }
  return(true);
}

// Function to check the expiry date
bool CheckExpiryDate_CompileTime(){

  datetime expiryDate = LICENSED_EXPIRY_DATE_START + (LICENSED_EXPIRY_DAYS * 86400);
  int secondsRemaining = int(expiryDate - TimeCurrent());
  int days = secondsRemaining / (24 * 3600);
  int hours = (secondsRemaining % (24 * 3600)) / 3600;
  int mins = (secondsRemaining % 3600) / 60;

  if(TimeCurrent() > expiryDate){

    Print("Trial version expired on: ", TimeToString(expiryDate, TIME_DATE | TIME_MINUTES));
    return false;
  }

  Print("License started on: ", LICENSED_EXPIRY_DATE_COMPILE);                              // For Users Subscription
  //Print("Indicator expires on: ", TimeToString(expiryDate, TIME_DATE | TIME_MINUTES));
  Print("Indicator expires on: ",expiryDate);
  Print("Remaining: ", days, " Days ", hours, " Hours ", mins, " Minutes");
  return true;
}

//+------------------------------------------------------------------+
//| ACCOUNT COPY PROTECTION                                          |
//+------------------------------------------------------------------+

double Buffer1[];
double Buffer2[];
double Low[];
double High[];
double Close[];
datetime Time[];
string resistance;
string support;
string uppertrend;
string lowertrend;
int arrow_count = 0;
int lastArrowBarIndex = -1;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+

int OnInit(){

  if(!CheckAccountNo(current_AccountNo(), UserAccounts, ArraySize(UserAccounts))){
    ChartIndicatorDelete(0,0,"PriceAction"); 
    Print("Removing Indicator");
    return INIT_FAILED;
  }

  if(!CheckTradeSymbols()){  
    ChartIndicatorDelete(0,0,"PriceAction");
    Print("Removing Indicator");
    return INIT_FAILED;
  }

  if(!CheckTradeModes()){  
    ChartIndicatorDelete(0,0,"PriceAction");
    Print("Removing Indicator");
    return INIT_FAILED;
  }

  if(!CheckExpiryDate_CompileTime()){  
    ChartIndicatorDelete(0,0,"PriceAction");
    Print("Removing Indicator");
    return INIT_FAILED;
  }

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[]){
                
  if(!IsNewBar()) return 0; // Exit if it's not a new bar
  
  int limit = rates_total - prev_calculated;   
  // Ensure limit is valid
  if(limit <= 0) return rates_total;         

  if(CopyLow(Symbol(), PERIOD_CURRENT, 0, rates_total, Low) <= 0) return(rates_total);
  ArraySetAsSeries(Low, true);
  if(CopyHigh(Symbol(), PERIOD_CURRENT, 0, rates_total, High) <= 0) return(rates_total);
  ArraySetAsSeries(High, true);
  if(CopyClose(Symbol(), PERIOD_CURRENT, 0, rates_total, Close) <= 0) return(rates_total);
  ArraySetAsSeries(Close, true);
  if(CopyTime(Symbol(), Period(), 0, rates_total, Time) <= 0) return(rates_total);
  ArraySetAsSeries(Time, true);
              
  for(int i = limit-1; i >= 0; i--){

    if(i >= MathMin(maxBars-1, rates_total-1-oldBars)) continue; 

    double range = High[i] - Low[i];
    double arrow_dist = range * ArrowDist;
    resistance = "";
    support = "";
    double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);      // Current bid price
    int totalObjects = ObjectsTotal(0, 0, OBJ_RECTANGLE);
    int trendObjects = ObjectsTotal(0, 0, OBJ_TREND);  // Get total trendline objects

    // SUPPORT AND RESISTANCE ZONES SIGNALS
    for(int j=0; j<totalObjects; j++){

      if(isSupResActive){

        string objectName = ObjectName(0, j, 0, OBJ_RECTANGLE);

        // Sell Signals
        if(StringFind(objectName, "res")>-1){

          resistance = objectName;
          //Print("\nResistance: ", resistance);

          double resistanceHigh = ObjectGetDouble(0, resistance, OBJPROP_PRICE,0);
          double resistanceLow = ObjectGetDouble(0, resistance, OBJPROP_PRICE,1);
          double range = (resistanceHigh-resistanceLow)/2;
          double sellRange = resistanceLow-range;
          double sellStop = resistanceHigh+range;

          string name = "Res_Sell#"+string(arrow_count+1);
      
          datetime object_time = (datetime)ObjectGetInteger(0, resistance, OBJPROP_TIME);
          int object_bar = iBarShift(Symbol(), Period(), TimeLocal());
          double candle = iClose(Symbol(), Period(), object_bar); // Retrieve the low price of the candle where the sell arrow appears
          double candleHigh = iHigh(Symbol(), Period(), object_bar);
          double candleLow = iLow(Symbol(), Period(), object_bar);
          double arrowPrice = ObjectSetDouble(0, name, OBJPROP_PRICE, candle); // Attach the close price to the sell arrow object

          // Ensure object_bar is within the range of available bars
          if(object_bar < 0 || object_bar >= Bars(Symbol(), Period())){
            Print("Invalid object_bar index: ", object_bar);
            continue;
          }

          if(price<resistanceHigh && candleHigh>resistanceLow){ 
          
            //PrintFormat("\nEntered Resistance Zone: Time = %s, Price = %f", TimeToString(TimeLocal()), price);
          }
          
          //if(price < resistanceHigh && candleHigh > resistanceLow && price > sellRange && price < resistanceLow && arrow_count < arrows_num) continue;
          
          if(Close[2] > resistanceLow && Close[1] < resistanceLow && object_bar != lastArrowBarIndex){

            PrintFormat("Price below Resistance Zone: %s, (Sell Arrow should appear)",resistance);
            DrawArrowSell("Res_Sell", i, arrowPrice, clrRed, 10);
          }
          
          if(price<sellStop && price>resistanceHigh){
            PrintFormat("Price above Resistance Zone, Price=%f, Don't put SELL orders!!!",price);
          }

          if(price>sellStop){
            //Print("Stop Loss");
          }
        }
        
        // Buy Signals
        if(StringFind(objectName, "sup")>-1){

          support = objectName;
          //Print("\nSupport: ", support);
          double supportHigh = ObjectGetDouble(0, support, OBJPROP_PRICE,0);
          double supportLow = ObjectGetDouble(0, support, OBJPROP_PRICE,1);
          double range = (supportHigh-supportLow)/2;
          double buyRange = supportHigh+range;
          double buyStop = supportLow-range;

          string name = "Sup_Buy#"+string(arrow_count+1);
          
          datetime object_time = (datetime)ObjectGetInteger(0, support, OBJPROP_TIME);
          int object_bar = iBarShift(Symbol(), Period(), TimeLocal());
          double candle = iClose(Symbol(), Period(), object_bar); // Retrieve the low price of the candle where the sell arrow appears
          double candleHigh = iHigh(Symbol(), Period(), object_bar);
          double candleLow = iLow(Symbol(), Period(), object_bar);
          double arrowPrice = ObjectSetDouble(0, name, OBJPROP_PRICE, candle);

          // Ensure object_bar is within the range of available bars
          if(object_bar < 0 || object_bar >= Bars(Symbol(), Period())){

            Print("Invalid object_bar index: ", object_bar);
            continue;
          }

          if(price>supportLow && candleLow<supportHigh){ 
              
            //PrintFormat("\nEntered Support Zone: Time = %s, Price = %f", TimeToString(TimeLocal()), price);
          }
          //if(price > supportLow && candleLow < supportHigh && price < buyRange && price > supportHigh && arrow_count < arrows_num)continue;
              
          if(Close[2] < supportHigh && Close[1] > supportHigh && object_bar != lastArrowBarIndex){

            PrintFormat("Price above the Support Zone: %s,  (Buy Arrow should appear)",support);
            DrawArrowBuy("Sup_Buy", i, arrowPrice, clrBlue, 10);
          }  
          
          if(price>buyStop && price<supportLow){
            PrintFormat("Price below Support Zone, Price=%f, Don't put BUY orders!!!", price);
          }

          if(price<buyStop){
            //Print("Stop Loss");
          }
        }
      }
    }

    // TRENDLINE SIGNALS
    for(int j = trendObjects - 1; j >= 0; j--){

      if(isTrendlineActive){

        string objectName = ObjectName(0, i, 0, OBJ_TREND);
        // LOWER TRENDLINE
        if(StringFind(objectName, "l")>-1){

          lowertrend = objectName;

          datetime barTime = iTime(NULL, 0, 1);  // Current bar's time
          double trendlinePrice = ObjectGetValueByTime(0, lowertrend, barTime, 0);  // Trendline price
          
          datetime object_time = (datetime)ObjectGetInteger(0, lowertrend, OBJPROP_TIME);
          int object_bar = iBarShift(Symbol(), Period(), TimeCurrent());
          double candle = iClose(Symbol(), Period(), object_bar); // Retrieve the low price of the candle where the sell arrow appears
          double arrowPrice = High[i];

          // Ensure object_bar is within the range of available bars
          if(object_bar < 0 || object_bar >= Bars(Symbol(), Period())){

            //Print("Invalid object_bar index: ", object_bar);
            continue;
          }
          
          if(trendlinePrice > 0){  // Ensure a valid price is retrieved

            // Check for a downward cross (price breaks below trendline)
            if(Close[2] > trendlinePrice && Close[1] < trendlinePrice){

              Print("Price crossed below trendline: ", lowertrend, " | Trendline Price: ", trendlinePrice, " | Current Price: ", price);
              DrawArrowSell("Sell", i, arrowPrice, clrRed, 10);
            }
          }
        }
          
        // UPPER TRENDLINE
        if(StringFind(objectName, "u")>-1){

          uppertrend = objectName;
          datetime barTime = iTime(NULL, 0, 1);  // Current bar's time
          double trendlinePrice = ObjectGetValueByTime(0, uppertrend, barTime, 0);  // Trendline price

          string name = "Buy"+ IntegerToString(Time[i]);

          int object_bar = iBarShift(Symbol(), Period(), TimeLocal());
          double candle = iClose(Symbol(), Period(), object_bar); // Retrieve the low price of the candle where the sell arrow appears
          double candleHigh = iHigh(Symbol(), Period(), object_bar);
          double candleLow = iLow(Symbol(), Period(), object_bar);
          double arrowPrice = ObjectSetDouble(0, name, OBJPROP_PRICE, candle);
          
          // Ensure object_bar is within the range of available bars
          if(object_bar < 0 || object_bar >= Bars(Symbol(), Period())){

            //Print("Invalid object_bar index: ", object_bar);
            continue;
          }
          
          if(trendlinePrice > 0){  // Ensure a valid price is retrieved

          // Check for a upward cross (price breaks above trendline)
          if(Close[2] < trendlinePrice && Close[1] > trendlinePrice){

            Print("Price crossed above trendline: ", uppertrend, " | Trendline Price: ", trendlinePrice, " | Current Price: ", price);
            DrawArrowBuy("Buy", i,arrowPrice, clrBlue, 10);
          }
        }
        }
      }
    } 
  
    //+------------------------------------------------------------------+
    //| RETEST ENTRIES                                                   |
    //+------------------------------------------------------------------+

    if(isRetestActive){

      string objectName = ObjectName(0, i, 0, OBJ_TREND);
      string LowerTrendline = objectName;
      double currentPrice = SymbolInfoDouble(Symbol(),SYMBOL_BID);
      double arrowPrice = High[i];
      // Ensure the object exists and is a trendline
      if(ObjectFind(0, LowerTrendline) != -1 && ObjectGetInteger(0, LowerTrendline, OBJPROP_TYPE) == OBJ_TREND) {
        
        // Check if the trendline name contains 'l' (can be lowercase or uppercase)
        if(StringFind(LowerTrendline, "l") > -1 || StringFind(LowerTrendline, "L") > -1) {
          Print("Found trendline: ", LowerTrendline);  // Debugging output

          // Search for the previous green candlestick (resistance order block)
          int green_candle_index = FindPreviousGreenCandleAboveTrendline(LowerTrendline, currentPrice);

          // Debugging: check if green candle index is valid
          Print("Green candle index: ", green_candle_index);

          if(green_candle_index != -1) {
            // Draw the order block (resistance zone)
            DrawOrderBlock(green_candle_index, clrLime);
            Print("Drawing order block for index: ", green_candle_index);

            // Get high and low of the OB
            double ob_high = iHigh(_Symbol, _Period, green_candle_index);
            double ob_low = iLow(_Symbol, _Period, green_candle_index);

            // Debugging: check if high and low are correct
            Print("OB High: ", ob_high, " OB Low: ", ob_low);

            // Wait for price to retest the OB
            if(IsPriceRetestingOB(ob_high, ob_low)){
              // Retest confirmed, plot sell arrow
              
              DrawArrowSell("Retest_Sell", i, arrowPrice, clrBlack, 10);
            }
          }
        }
      }
      
      /*
      // LOWER TRENDLINE  
      if(ObjectFind(0, lowertrend) != -1 && ObjectGetInteger(0, lowertrend, OBJPROP_TYPE) == OBJ_TREND){
          
        // Check if the trendline name contains 'l' (can be lowercase or uppercase)
        if(StringFind(lowertrend, "l") > -1){

          //Print("Found trendline: ", LowerTrendline);  // Debugging output

          // Search for the previous green candlestick (resistance order block)
          int green_candle_index = FindPreviousGreenCandleAboveTrendline(lowertrend, price);

          // Debugging: check if green candle index is valid
          //Print("Green candle index: ", green_candle_index);

          if(green_candle_index != -1){

            //Print("should draw orderBlock here"); // Debugging output
            
            // Draw the order block (resistance zone)
            DrawOrderBlock(green_candle_index, clrBlack);
            //Print("Drawing order block for index: ", green_candle_index);

            // Get high and low of the OB
            double ob_high = iHigh(_Symbol, _Period, green_candle_index);
            double ob_low = iLow(_Symbol, _Period, green_candle_index);

            // Debugging: check if high and low are correct
            //Print("OB High: ", ob_high, " OB Low: ", ob_low);

            // Wait for price to retest the OB
            /*if(IsPriceRetestingOB(ob_high, ob_low)) {

              // Retest confirmed, plot sell arrow
              DrawArrowSell("LowerTrendSell", i, dynamic_arrow, clrBlack, arrowSellFilter);
            }
          }
        }
      }

      // UPPER TRENDLINE 
      if(ObjectFind(0, uppertrend) != -1 && ObjectGetInteger(0, uppertrend, OBJPROP_TYPE) == OBJ_TREND){
          
        // Check if the trendline name contains 'l' (can be lowercase or uppercase)
        if(StringFind(uppertrend, "u") > -1 || StringFind(uppertrend, "L") > -1){

          //Print("Found trendline: ", uppertrend);  // Debugging output

          // Search for the previous green candlestick (resistance order block)
          int green_candle_index = FindPreviousGreenCandleAboveTrendline(lowertrend, price);

          // Debugging: check if green candle index is valid
          //Print("Green candle index: ", green_candle_index);

          if(green_candle_index != -1){

            //Print("should draw orderBlock here"); // Debugging output
            
            // Draw the order block (resistance zone)
            //DrawOrderBlock(green_candle_index, clrBlack);
            //Print("Drawing order block for index: ", green_candle_index);

            // Get high and low of the OB
            //double ob_high = iHigh(_Symbol, _Period, green_candle_index);
            //double ob_low = iLow(_Symbol, _Period, green_candle_index);

            // Debugging: check if high and low are correct
            //Print("OB High: ", ob_high, " OB Low: ", ob_low);

            // Wait for price to retest the OB
            if(IsPriceRetestingOB(ob_high, ob_low)) {

              // Retest confirmed, plot sell arrow
              //DrawArrowSell("LowerTrendSell", i, dynamic_arrow, clrBlack, arrowSellFilter);
            }
          }
        }
      }
    */
    }
  }
  return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+

bool IsPriceRetestingOB(double high_price, double low_price){

  double current_price = iClose(_Symbol, _Period, 0); // Current price
  double price =  iHigh(_Symbol, _Period, 0);
  int retest=0;

  if(current_price < low_price && price > low_price){

    retest++;
    Print("Price retesting OB, retest count: ", retest);
    return true;  // Price is retesting the OB
  }
  return false;  // No retest detected
}

bool IsPriceWithinOB(double high_price, double low_price){

  double current_price = iClose(_Symbol, _Period, 0); // Current price

  // Check if price is within the OB range
  if(current_price >= low_price && current_price <= high_price){

    Print("Price within OB");
    return true;  // Price is within the OB
  }
  return false;  // No retest detected
}

int FindPreviousGreenCandleAboveTrendline(string trendlineName, double currentPrice){
    
  // Get current bar count
  int totalBars = Bars(_Symbol, _Period);

  // Check if the trendline object exists
  if(ObjectFind(0, trendlineName) < 0){

    Print("Trendline not found: ", trendlineName);
    return -1;
  }

  // Start looking from the most recent bar and move backwards
  for(int i = 0; i <= 10; i++) {

    // Get the price of the trendline at this bar's time
    double trendlinePrice = TrendlinePriceLower(i);
    if(trendlinePrice == 0) continue;
    double close_price = iClose(_Symbol, _Period, i);

    // Check if the close price is below the trendline
    if(Close[2] > trendlinePrice && Close[1] < trendlinePrice){

      //Debugging
      Alert("Close price is below trendline");

      // Check the previous 50 bars for a green candle
      for(int j = i; j <= i + 10 && j < totalBars; j++){

        double prev_open_price = iOpen(_Symbol, _Period, j);
        double prev_close_price = iClose(_Symbol, _Period, j);
        double ob_high = iHigh(_Symbol, _Period, j);
        double ob_low = iLow(_Symbol, _Period, j);

        // Check for a green (bullish) candle
        if(prev_open_price < prev_close_price) {
          Print("Found green candle at index: ", j, " with OB High: ", ob_high, " OB Low: ", ob_low);
          return j;  // Return the index of the green candle
        }
      }
    }
  }

  // Return -1 if no green candle was found above the trendline
  //Print("No green candle found above the trendline within the last 10 bars.");
  return -1;
}

void DrawOrderBlock(int candle_index, color block_color){

  // Access high and low of the candlestick
  double high_price = iHigh(_Symbol, _Period, candle_index);
  double low_price = iLow(_Symbol, _Period, candle_index);

  // Create object name
  string obj_name = "OrderBlock_" + IntegerToString(TimeCurrent()) + "_" + IntegerToString(candle_index);

  // Create order block rectangle
  if(ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, Time[candle_index], high_price, Time[2]+36000, low_price)){
    
    // Set the properties of the rectangle (order block)
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, block_color);    // Set color
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);              // Border width
    ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);    // Line style
    ObjectSetInteger(0, obj_name, OBJPROP_RAY_RIGHT, true);       // Extend the rectangle to the right
  }

  else{
        
    Print("Error creating order block: ", GetLastError());
    return;
  }
}

//+------------------------------------------------------------------+
//| OPTIMIZED FUNCTIONS                                              |
//+------------------------------------------------------------------+

void NewObject(string name){
    
  // Only on name matching test_arrow_*
  if(StringSubstr(name, 0, StringLen(uppertrend))!=uppertrend) return;
  if(StringSubstr(name, 0, StringLen(lowertrend))!=lowertrend) return;

  // Quick check that the object exists in the correct window
  // I'm looking at window 0
  int sub_window = ObjectFind(0, name);
  if (sub_window!=0)   return;
  
  // Only buy arrows or sell arrows
  long type = ObjectGetInteger(0, name, OBJPROP_TYPE);
  if(type!=OBJ_ARROW_BUY && type!=OBJ_ARROW_SELL) return;

  // Report the object found
  ReportObject("New", name);
    
}
 
void ReportObject(string event, string name){
    
  // Now I have an object, grab some properties but what you do depends on the strategy
  datetime object_time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
  ENUM_OBJECT object_type = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
  int object_bar = iBarShift(Symbol(), Period(), object_time);
  double object_price = ObjectGetDouble(0, name, OBJPROP_PRICE);
  double bar_high = iHigh(Symbol(), Period(), object_bar);
  double bar_low = iLow(Symbol(), Period(), object_bar);

  PrintFormat("This is where you trade on your strategy using information from the object");   
  PrintFormat("Event = %s", event);   
  PrintFormat("Object name = %s", name);
  PrintFormat("Object type = %s", EnumToString(object_type));
  PrintFormat("time=%s, bar=%i, price=%f, high=%f, low=%f", TimeToString(object_time), object_bar, object_price, bar_high, bar_low);  
 
}

double TrendlinePriceLower(int shift){
  
  int obj_total = ObjectsTotal(0);  // Total number of objects on the chart
  double minprice = DBL_MAX;        // Initialize with the highest possible value
  datetime barTime = iTime(NULL, 0, shift);  // Time of the bar at 'shift'
  
  for (int i = 0; i < obj_total; i++){

    string name = ObjectName(0, i);  // Get the object name
    int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);

    // Debug: Log all object names and types
    //Print("Object Name: ", name, " | Type: ", type);

    // Check if the object is a trendline and contains "l" (or "l1")
    if(type == OBJ_TREND && StringFind(name, "l") > -1){

      double price = ObjectGetValueByTime(0, name, barTime, 0);  // Get trendline price
      // Debug: Log the price retrieval
      Print("Checking Lower Trendline: ", name, " | Time: ", TimeToString(barTime), " | Price: ", price);

      if (price > 0 && price < minprice) {
        minprice = price;  // Update the minimum price
      }
    }
  }

  return (minprice == DBL_MAX) ? -1 : minprice;  // Return the lowest price, or -1 if none found
}

double TrendlinePriceUpper(int shift){
  
  int obj_total = ObjectsTotal(0);  // Total number of objects on the chart
  double maxprice = -DBL_MAX;       // Initialize with the lowest possible value
  datetime barTime = iTime(NULL, 0, shift);  // Time of the bar at 'shift'
  
  for (int i = 0; i < obj_total; i++){

    string name = ObjectName(0, i);  // Get the object name
    int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);

    // Debug: Log all object names and types
    //Print("Object Name: ", name, " | Type: ", type);

    // Check if the object is a trendline and contains "l" (or "l1")
    if(type == OBJ_TREND && StringFind(name, "u") > -1){

      double price = ObjectGetValueByTime(0, name, barTime, 0);  // Get trendline price
      // Debug: Log the price retrieval
      Print("Checking Upper Trendline: ", name, " | Time: ", TimeToString(barTime), " | Price: ", price);

      if(price > 0 && price > maxprice){

        maxprice = price;  // Update the maximum price
      }
    }
  }
  
  return (maxprice == -DBL_MAX) ? -1 : maxprice;  // Return the highest price, or -1 if none found
}

bool IsArrowSellExists(string arrowName, datetime time){

  // Iterate through all objects on the chart
  int totalObjects = ObjectsTotal(0, 0, OBJ_ARROW);
  for(int i = 0; i < totalObjects; i++){

    string name = ObjectName(0, i);  // Get the object's name
    // Check if the object name matches the arrow name
    if(StringFind(name, arrowName) > -1){

      datetime arrowTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
      // Check if the time matches the arrow's time
      if(arrowTime == time){
      
        return true;  // Arrow already exists
      }
    }
  }
  return false;  // No matching arrow found
}

bool IsArrowBuyExists(string arrowName, datetime time){

  // Iterate through all objects on the chart
  int totalObjects = ObjectsTotal(0, 0, OBJ_ARROW);
  for(int i = 0; i < totalObjects; i++){

    string name = ObjectName(0, i);  // Get the object's name
    // Check if the object name matches the arrow name
    if(StringFind(name, arrowName) > -1){

      datetime arrowTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
      // Check if the time matches the arrow's time
      if(arrowTime == time){

        return true;  // Buy arrow already exists
      }
    }
  }
  return false;  // No matching buy arrow found
}

void DrawArrowSell(string arrowPrefix, int i, double arrowPrice, color arrowColor, int arrowFilter){
  
  bool arrowExists = false;
  for(int k = 0; k < maxBars - oldBars; k++){

    string arrowName = ObjectName(0, k);
    if(StringFind(arrowName, arrowPrefix) > -1){

      datetime arrowTime = (datetime)ObjectGetInteger(0, arrowName, OBJPROP_TIME);
      if(Time[i] - arrowTime < PeriodSeconds(PERIOD_CURRENT) * arrowFilter){
        
        arrowExists = true;
        break;
      }
    }
  }

  if(!arrowExists){
    
    string arrowName = arrowPrefix + "#" + IntegerToString(Time[i]);
    if(!IsArrowSellExists(arrowName, Time[i]) && !IsArrowBuyExists(arrowName, Time[i])){

      if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, Time[i], arrowPrice)){

        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 234); // Downward arrow
        ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR, ANCHOR_TOP);
        ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      } 
      else{
        Print("Error creating arrow: ", GetLastError());
      }
    }
  }
}

void DrawArrowBuy(string arrowPrefix, int i, double arrowPrice, color arrowColor, int arrowFilter){
  
  bool arrowExists = false;
  for(int k = 0; k < maxBars - oldBars; k++){

    string arrowName = ObjectName(0, k);
    if(StringFind(arrowName, arrowPrefix) > -1){

      datetime arrowTime = (datetime)ObjectGetInteger(0, arrowName, OBJPROP_TIME);
      if(Time[i] - arrowTime < PeriodSeconds(PERIOD_CURRENT) * arrowFilter){

        arrowExists = true;
        break;
      }
    }
  }

  if(!arrowExists){
        
    string arrowName = arrowPrefix + "#" + IntegerToString(Time[i]);
    if(!IsArrowSellExists(arrowName, Time[i]) && !IsArrowBuyExists(arrowName, Time[i])){

      if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, Time[i], arrowPrice)){

        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 233); // Upward arrow
        ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
        ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      } 
      else{
        Print("Error creating buy arrow: ", GetLastError());
      }
    }
  }
}

bool IsNewBar(){
  static datetime previousTime = 0;
  datetime currentTime = iTime(_Symbol,PERIOD_CURRENT,0);
  if(previousTime != currentTime){

    previousTime = currentTime;
    return true;
  }
  return false;
}

void myAlert(string type, string message){

  if(type == "print"){
    
    Print(message);
  }
  else if(type == "error"){

    Print(type+" | trendlines @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
  }
  else if(type == "order"){

  }
  else if(type == "modify"){

  }
}