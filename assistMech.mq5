//+------------------------------------------------------------------+
//|                                                   AssistMech.mq5 |
//|                           Copyright 2025, Automated Trading Ltd. |
//|                        https://github.com/H4ck3r217/Trading-Bots |
//+------------------------------------------------------------------+
// God is Good 
#property copyright "Copyright 2024, Automated Trading Ltd."
#property link      "https://github.com/H4ck3r217/Trading-Bots"
#property version   "2.3"

#property description "OnChart-drawn support, resistance and trendlines"
#property description ""
#property description "NOTES FOR USAGE"
#property description ""
#property description "1. Timeframe set to 15M by default ie:- best signals DON'T CHANGE!!!"
#property description "2. Always rename lower trendline to l and upper trendlindline to u"
#property description "3. Always rename support zone to sup and resistant zone to res"
#property description "4. Toggle true on Signlas for AssistMech show signals"
#property strict 

#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots 14

#define PLOT_MAXIMUM_BARS_BACK
#define OMIT_OLDEST_BARS 
#define LICENSED_TRADE_SYMBOLS {"EURAUDmicro","Volatility 50 Index","Volatility 75 Index","AUDUSD","USDCHF","USDJPY","US30m","GBPUSD","EURUSD","XAUUSD","Boom 1000 Index","Boom 900 Index","Boom 600 Index","Boom 500 Index","Boom 300 Index","Crash 1000 Index","Crash 900 Index","Crash 600 Index","Crash 500 Index","Crash 300 Index"};               // Edit here for Symbols 
#define LICENSED_TRADE_MODES {ACCOUNT_TRADE_MODE_CONTEST,ACCOUNT_TRADE_MODE_DEMO};          // Edit here for Account Type
#define LICENSED_EXPIRY_DATE_START D'2025.12.31'
#define LICENSED_EXPIRY_DATE_COMPILE __DATETIME__
#define LICENSED_EXPIRY_DAYS 1                                                              // Edit here for days until expiry date

input group "==== Number of Bars ===="
input int barsToCheck = 5;  // Number of bars to check
input int PLOT_MAXIMUM_BARS_BACK maxBars = 200;
input int OMIT_OLDEST_BARS oldBars = 50;
input ENUM_TIMEFRAMES timeframe = PERIOD_M15;
input int arrows_num = 50;
input double ArrowDist = 2;

input group "====SIGNALS ===="
input bool isSupResActive = false;       // Show Support and Resistance Signals
input bool isTrendlineActive = false;    // Show Trendline Signals
input bool isRetestActive = false;       // Show Retest Signals
input bool isMAArrowActive = false;      // Show MA  Signals 
input bool isRsiMaActive = false;        // Show RSI-MA Signals
input bool isMacdRsiActive = false;      // Show MACD-RSI Signals
input bool isMMRActive = false;          // Show MMR Signals
input bool isMMRetestActive = false;     // Show MMR Retest Signals

input group "==== Moving Average INPUTS ===="
input int ema21 = 21;                                           // EMA 21 Period
input int ema50 = 50;                                           // EMA 50 Period
input int ema200 = 200;                                           // EMA 200 Period
input ENUM_MA_METHOD EMAMode = MODE_EMA;                        // Type of Moving Average
input ENUM_APPLIED_PRICE EMAAppPrice = PRICE_CLOSE;             // MA applied Price

input group "==== RSI_MA INPUTS ===="
input int    RSI_Period = 14;        // RSI Period
input double RSI_Level = 50;         // RSI Level

input group "==== Signal Confirmation INPUTS ===="
input int TrendConfirmationBars = 3;                           // Number of bars for trend confirmation
input int SignalConfirmationBars = 2;                          // Number of bars to confirm a signal
input int SignalFilterPeriod = 10;                             // Bars to filter duplicate signals
input bool CleanupOldSignals = true;                           // Clean up old signals
input int MaxSignalsToKeep = 50;                               // Maximum signals to keep on chart

input group "==== Retest Confirmation INPUTS ===="
input int RetestConfirmationBars = 3;                          // Bars to confirm a retest
input double MinimumVolumeIncrease = 1.5;                      // Minimum volume increase during retest (multiplier)
input bool RequirePriceActionConfirmation = true;              // Require price action patterns
input bool RequireTrendAlignment = true;                       // Require trend direction alignment
input bool RequireVolumeConfirmation = true;                   // Require volume confirmation

input group "==== VARIABLE INPUTS ===="
input bool Audible_Alerts = true;
datetime time_alert; //used when sending alert

//+------------------------------------------------------------------+
//| ACCOUNT COPY PROTECTION                                          |
//+------------------------------------------------------------------+

long current_AccountNo(){ return AccountInfoInteger(ACCOUNT_LOGIN);}
long Current_Account_Mode(){ return AccountInfoInteger(ACCOUNT_TRADE_MODE);}
string Current_Chart_Symbol(){ return Symbol();}

// User Accounts
long Frank = 24202602;                           // Frank Demo account
long Lee = 40506991;                             // Lee Demo Account
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

    Print("Invalid Account Number, Revoking the Indicator !!!");
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
  Print("Remaining: ", days, " Days ", hours, " Hours ", mins, " Minutes\n");
  return true;
}

//+------------------------------------------------------------------+
//| ACCOUNT COPY PROTECTION                                          |
//+------------------------------------------------------------------+

double Buffer1[];
double Buffer2[];
double BufferMABuy[];
double BufferMASell[];
double BufferSup[];
double BufferRes[];
double BufferRsi1[];
double BufferRsi2[];
double BufferMacd1[];
double BufferMacd2[];

double Low[];
double High[];
double Close[];
double Open[];
double ema[];
double RSI[];
double MACD_Signal[];
double MACD_Main[];
double MA21[]; 
double MA50[];
double MA200[];
double MA800[];
datetime Time[];
long Volume[];
string resistance;
string support;
string uppertrend;
string lowertrend;
int MA50_handle;
int MACD_handle;
int RSI_handle;
int MA21_handle;
int MA200_handle;
int MA800_handle;
int arrow_count = 0;
int lastArrowBarIndex = -1;
double level = 50;

// Arrays to store signal data for filtering
datetime lastSupportBuySignal = 0;
datetime lastResistanceSellSignal = 0;
datetime lastTrendlineBuySignal = 0;
datetime lastTrendlineSellSignal = 0;
datetime lastMABuySignal = 0;
datetime lastMASellSignal = 0;
datetime lastRetestBuySignal = 0;
datetime lastRetestSellSignal = 0;

//+------------------------------------------------------------------+
//| INITIALIZATION AND MAIN FUNCTIONS                                |
//+------------------------------------------------------------------+

int OnInit(){

  //+------------------------------------------------------------------+
  //| ACCOUNT PROTECTION FUNCTION                                      |
  //+------------------------------------------------------------------+

  if(!CheckAccountNo(current_AccountNo(), UserAccounts, ArraySize(UserAccounts))){

    ChartIndicatorDelete(0,0,"PriceAction"); 
    //Print("Removing Indicator");
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

  //+------------------------------------------------------------------+
  //| ACCOUNT PROTECTION FUNCTION                                      |
  //+------------------------------------------------------------------+

  SetIndexBuffer(0,Buffer1);
  SetIndexBuffer(1,Buffer2);
  SetIndexBuffer(2,BufferMABuy);
  SetIndexBuffer(3,BufferMASell);
  SetIndexBuffer(4,BufferSup);
  SetIndexBuffer(5,BufferRes);
  SetIndexBuffer(6,BufferRsi1);
  SetIndexBuffer(7,BufferRsi2);
  SetIndexBuffer(8,BufferMacd1);
  SetIndexBuffer(9,BufferMacd2);

  ArraySetAsSeries(BufferMABuy, true);
  ArraySetAsSeries(BufferMASell, true);
  ArraySetAsSeries(BufferSup, true);
  ArraySetAsSeries(BufferRes, true);
  ArraySetAsSeries(Buffer1, true);
  ArraySetAsSeries(Buffer2, true);
  ArraySetAsSeries(BufferRsi1, true);
  ArraySetAsSeries(BufferRsi2, true);
  ArraySetAsSeries(BufferMacd1, true);
  ArraySetAsSeries(BufferMacd2, true);

  RSI_handle = iRSI(NULL, timeframe, RSI_Period, PRICE_CLOSE);
  if(RSI_handle < 0){

    Print("The creation of iRSI has failed: RSI_handle=", INVALID_HANDLE);
    Print("Runtime error = ", GetLastError());
    return(INIT_FAILED);
  }

  MACD_handle = iMACD(NULL, timeframe, 12, 26, 9, PRICE_CLOSE);
  if(MACD_handle < 0){

    Print("The creation of iMACD has failed: MACD_handle=", INVALID_HANDLE);
    Print("Runtime error = ", GetLastError());
    return(INIT_FAILED);
  }

  MA21_handle = iMA(NULL, timeframe, ema21, 0, EMAMode, EMAAppPrice);
  if(MA21_handle< 0){

    Print("The creation of iMA has failed: MA21_handle=", INVALID_HANDLE);
    Print("Runtime error = ", GetLastError());
    return(INIT_FAILED);
  }

  MA50_handle = iMA(_Symbol,timeframe,ema50,0,EMAMode,EMAAppPrice);
  if(MA50_handle < 0){

    Print("The creation of EMA50 has failed: MA50_handle=", INVALID_HANDLE);
    Print("Runtime error = ", GetLastError());
    return(INIT_FAILED);
  }
  
  MA200_handle = iMA(NULL, timeframe, ema200, 0, EMAMode, EMAAppPrice);
  if(MA200_handle< 0){

    Print("The creation of iMA has failed: MA200_handle=", INVALID_HANDLE);
    Print("Runtime error = ", GetLastError());
    return(INIT_FAILED);
  }

  MA800_handle = iMA(NULL, timeframe, 800, 0, EMAMode, EMAAppPrice);
  if(MA800_handle< 0){

    Print("The creation of iMA has failed: MA800_handle=", INVALID_HANDLE);
    Print("Runtime error = ", GetLastError());
    return(INIT_FAILED);
  }

  return(INIT_SUCCEEDED);
}

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
  if(CopyOpen(Symbol(), PERIOD_CURRENT, 0, rates_total, Open) <= 0) return(rates_total);
  ArraySetAsSeries(Open, true);
  if(CopyTime(Symbol(), Period(), 0, rates_total, Time) <= 0) return(rates_total);
  ArraySetAsSeries(Time, true);
  if(CopyTickVolume(Symbol(), PERIOD_CURRENT, 0, rates_total, Volume) <= 0){

    Print("Error getting volume data: ", GetLastError());
    return(rates_total);
  }
  ArraySetAsSeries(Volume, true);

  if(BarsCalculated(MACD_handle) <= 0) return(0);
  if(CopyBuffer(MACD_handle, SIGNAL_LINE, 0, rates_total, MACD_Signal) <= 0) return(rates_total);
  ArraySetAsSeries(MACD_Signal, true);

  if(BarsCalculated(MACD_handle) <= 0) return(0);
  if(CopyBuffer(MACD_handle, MAIN_LINE, 0, rates_total, MACD_Main) <= 0) return(rates_total);
  ArraySetAsSeries(MACD_Main, true);

  if(BarsCalculated(RSI_handle) <= 0) return(0);
  if(CopyBuffer(RSI_handle, 0, 0, rates_total, RSI) <= 0) return(rates_total);
  ArraySetAsSeries(RSI, true);
  
  if(BarsCalculated(MA21_handle) <= 0) return(0);
  if(CopyBuffer(MA21_handle, 0, 0, rates_total, MA21) <= 0) return(rates_total);
  ArraySetAsSeries(MA21, true);

  if(BarsCalculated(MA200_handle) <= 0) return(0);
  if(CopyBuffer(MA200_handle, 0, 0, rates_total, MA200) <= 0) return(rates_total);
  ArraySetAsSeries(MA200, true);

  if(BarsCalculated(MA800_handle) <= 0) return(0);
  if(CopyBuffer(MA800_handle, 0, 0, rates_total, MA800) <= 0) return(rates_total);
  ArraySetAsSeries(MA800, true);

  ArraySetAsSeries(BufferRsi1, true);
  ArraySetAsSeries(BufferRsi2, true);
  if(BarsCalculated(MA50_handle) <= 0) return(0);
  if(CopyBuffer(MA50_handle, MAIN_LINE, 0, rates_total, ema) <= 0) return(rates_total);
  ArraySetAsSeries(ema, true);
  if(CopyTickVolume(Symbol(), PERIOD_CURRENT, 0, rates_total, Volume) <= 0){

    Print("Error getting volume data: ", GetLastError());
    return(rates_total);
  }
  ArraySetAsSeries(Volume, true);

  // Add volume validation
  for(int i = 0; i < rates_total; i++){

    if(Volume[i] < 0){
      Print("Invalid volume data detected at bar ", i);
      Volume[i] = 0;  // Reset invalid volume to 0
    }
  }

  // Clean up old signals if enabled
  if(CleanupOldSignals){
    RemoveOldSignals();
  }

  if(prev_calculated < 1){
   
    ArrayInitialize(BufferMABuy, EMPTY_VALUE);
    ArrayInitialize(BufferMASell, EMPTY_VALUE);
    ArrayInitialize(Volume, 0);  // Initialize Volume array with zeros
    Print("Volume array initialized");
  }
  else{
    limit++;
  }

  // Main Loop            
  for(int i = limit-1; i >= 0; i--){

    if(i >= MathMin(maxBars-1, rates_total-1-oldBars)) continue; 

    double range = High[i] - Low[i];
    double arrow_dist = range * ArrowDist;
    double dynamic_arrow_dist = range * ArrowDist;
    resistance = "";
    support = "";
    double price = SymbolInfoDouble(Symbol(),SYMBOL_BID);      // Current bid price
    int totalObjects = ObjectsTotal(0, 0, OBJ_RECTANGLE);
    int trendObjects = ObjectsTotal(0, 0, OBJ_TREND);         // Get total trendline objects

    
    //+------------------------------------------------------------------+
    // SUPPORT AND RESISTANCE ZONES SIGNALS                              |
    //+------------------------------------------------------------------+
    if(isSupResActive){

      for(int j = totalObjects-1; j >= 0; j--){

        string objectName = ObjectName(0, j, 0, OBJ_RECTANGLE);

        // Sell Signals
        if(StringFind(objectName, "res") > -1){
          resistance = objectName;
          
          double resistanceHigh = ObjectGetDouble(0, resistance, OBJPROP_PRICE, 1);
          double resistanceLow = ObjectGetDouble(0, resistance, OBJPROP_PRICE, 0);
          double range = (resistanceHigh - resistanceLow) / 2;
          double sellRange = resistanceLow - range;
          double sellStop = resistanceHigh + range;
          
          string res = "Res_Sell#" + string(arrow_count);
          
          datetime object_time = (datetime)ObjectGetInteger(0, resistance, OBJPROP_TIME);
          int object_bar = iBarShift(Symbol(), Period(), object_time);
          double candle = iClose(Symbol(), Period(), object_bar); // Retrieve the close price of the candle where the sell arrow appears
          double candleHigh = iHigh(Symbol(), Period(), object_bar);
          double candleLow = iLow(Symbol(), Period(), object_bar);
          
          ObjectSetDouble(0, res, OBJPROP_PRICE, candle); // Attach the close price to the sell arrow object
          
          if(price < resistanceHigh && candleHigh > resistanceLow){ 

            PrintFormat("\nEntered Resistance Zone: Time = %s, Price = %f", TimeToString(TimeLocal()), price);
          }
          
          if(High[object_bar + 2] > resistanceLow && Close[object_bar+1] < resistanceLow && object_bar != lastArrowBarIndex){
            
            //PrintFormat("Price below Resistance Zone: %s, (Sell Arrow should appear)", resistance);
            
            color SellColor = clrBlack;
            string res_name = "Res_Sell#" + IntegerToString(Time[object_bar]);

            if(!IsArrowSellExists(res_name, Time[object_bar])){

              ObjectCreate(0, res_name, OBJ_ARROW, 0, Time[object_bar], High[object_bar] + arrow_dist);
              ObjectSetInteger(0, res_name, OBJPROP_COLOR, SellColor);
              ObjectSetInteger(0, res_name, OBJPROP_WIDTH, 3); // Adjust width as needed
              ObjectSetInteger(0, res_name, OBJPROP_ARROWCODE, 234);
              ObjectSetInteger(0, res_name, OBJPROP_ANCHOR, ANCHOR_TOP);
              ObjectSetInteger(0, res_name, OBJPROP_HIDDEN, false);
              ObjectSetInteger(0, res_name, OBJPROP_BACK, true);
            } 
          }
          
          if(price < sellStop && price > resistanceHigh){

            PrintFormat("Price above Resistance Zone, Price = %f, Don't put SELL orders!!!", price);
          }

          if(price > sellStop){

            //Print("Stop Loss");
          }
        }

        // Buy Signals
        if(StringFind(objectName, "sup")>-1){
          support = objectName;
          
          double supportHigh = ObjectGetDouble(0, support, OBJPROP_PRICE,1);
          double supportLow = ObjectGetDouble(0, support, OBJPROP_PRICE,0);
          double range = (supportHigh-supportLow)/2;
          double buyRange = supportHigh+range;
          double buyStop = supportLow-range;

          string name = "Sup_Buy#"+string(arrow_count);
          
          datetime object_time = (datetime)ObjectGetInteger(0, support, OBJPROP_TIME);
          int object_bar = iBarShift(Symbol(), Period(), TimeLocal());
          double candle = iClose(Symbol(), Period(), object_bar); // Retrieve the low price of the candle where the sell arrow appears
          double candleHigh = iHigh(Symbol(), Period(), object_bar);
          double candleLow = iLow(Symbol(), Period(), object_bar);
          ObjectSetDouble(0, name, OBJPROP_PRICE, candle);

          // Ensure object_bar is within the range of available bars
          if(object_bar < 0 || object_bar >= Bars(Symbol(), Period())){

            Print("Invalid object_bar index: ", object_bar);
            continue;
          }

          if(price>supportLow && candleLow<supportHigh){ 
              
            //PrintFormat("\nEntered Support Zone: Time = %s, Price = %f", TimeToString(TimeLocal()), price);
          }
              
          if(Low[object_bar + 2] < supportHigh && Close[object_bar + 1] > supportHigh && object_bar != lastArrowBarIndex){

            //PrintFormat("Price above the Support Zone: %s,  (Buy Arrow should appear)",support);

            color BuyColor = clrBlack;
            string sup_name = "Sup_Buy#" + IntegerToString(Time[object_bar]);

            if(!IsArrowSellExists(sup_name, Time[object_bar])){

              ObjectCreate(0, sup_name, OBJ_ARROW, 0, Time[object_bar], Low[object_bar] - arrow_dist);
              ObjectSetInteger(0, sup_name, OBJPROP_COLOR, BuyColor);
              ObjectSetInteger(0, sup_name, OBJPROP_WIDTH, 3); // Adjust width as needed
              ObjectSetInteger(0, sup_name, OBJPROP_ARROWCODE, 233);
              ObjectSetInteger(0, sup_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
              ObjectSetInteger(0, sup_name, OBJPROP_HIDDEN, false);
              ObjectSetInteger(0, sup_name, OBJPROP_BACK, true);

            }  
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
    
    //+------------------------------------------------------------------+
    // TRENDLINE SIGNALS                                                 |
    //+------------------------------------------------------------------+
    if(isTrendlineActive){

      for(int j = trendObjects - 1; j >= 0; j--){

        string objectName = ObjectName(0, j, 0, OBJ_TREND);
        if(objectName == NULL || objectName == "") continue;
        
        // LOWER TRENDLINE SIGNALS (Marked with "l")
        if(StringFind(objectName, "l") > -1){
        

          lowertrend = objectName;

          // Iterate over historical bars
          int barsTocheck = 50;  // Number of bars to check
          for(int barIndex = barsTocheck; barIndex >= 1; barIndex--){

            // Get time of current bar
            datetime barTime = Time[barIndex];
            
            // Get trendline price at this bar
            // Iterate over historical bars
            int barsTocheck = 50;  // Number of bars to check
            for(int barIndex = barsTocheck; barIndex >= 1; barIndex--){

              // Get time of current bar
              datetime barTime = Time[barIndex];
              
              // Get trendline price at this bar
              double trendlinePrice = ObjectGetValueByTime(0, lowertrend, barTime);
              
              // Skip invalid trendline prices
              if(trendlinePrice <= 0) continue;
              
              // Enhanced signal detection with multiple candle confirmation
              bool priceBreakingDown = false;
              bool downwardTrend = true;
              
              // Check for price breaking below trendline with multiple confirmation candles
              if(Close[barIndex + SignalConfirmationBars] > trendlinePrice && Close[barIndex] < trendlinePrice){
                
                priceBreakingDown = true;
                
                // Confirm downward trend using multiple bars
                for(int trendCheck = barIndex; trendCheck < barIndex + TrendConfirmationBars && trendCheck < barsToCheck; trendCheck++){

                  if(Close[trendCheck] > Close[trendCheck + 1]){

                    downwardTrend = false;
                    break;
                  }
                }
              }
              
              // Filter frequent signals
              bool signalTimeFilter = Time[barIndex] - lastTrendlineSellSignal > PeriodSeconds(PERIOD_CURRENT) * SignalFilterPeriod;
              
              // Only draw if all conditions are met
              if(priceBreakingDown && downwardTrend && signalTimeFilter){

              // Record signal time
              lastTrendlineSellSignal = Time[barIndex];
              
              // Get multiple price confirmations
              double currentPrice = Close[barIndex];
              double currentLow = Low[barIndex];
              double trendlinePrice = ObjectGetValueByTime(0, lowertrend, Time[barIndex]);
              
              // Only proceed if we have valid price data
              if(trendlinePrice > 0){

                // Require both close and low to be below trendline for confirmation
                bool isBreakConfirmed = currentPrice < trendlinePrice && currentLow < trendlinePrice;
                
                // Additional check: at least 2 consecutive closes below trendline
                bool consecutiveCloses = Close[barIndex] < trendlinePrice && Close[barIndex+1] < trendlinePrice;
                
                // Only alert if price is confirmed below trendline with additional validations
                if(isBreakConfirmed && consecutiveCloses && Audible_Alerts){

                  // Use real-time price confirmations
                  double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);  // Current real-time price
                  double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
                  double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
                  double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
                  double prevLow = iLow(_Symbol, PERIOD_CURRENT, 1);
                  
                  // Get trendline price for current and previous bars
                  double currentTrendlinePrice = ObjectGetValueByTime(0, lowertrend, Time[0]);
                  double prevTrendlinePrice = ObjectGetValueByTime(0, lowertrend, Time[1]);
                    
                    
                
                  // Draw the sell arrow only on confirmed break
                  if(isBreakConfirmed){

                      double range = High[barIndex] - Low[barIndex];
                      double dynamic_arrow_dist = range * ArrowDist;
                      double arrowPrice = High[barIndex] + dynamic_arrow_dist;
                      DrawArrowSell("Trendline_Sell", barIndex, arrowPrice, clrRed, 10);
                      
                      Alert("Price broke below lower trendline - Potential SELL Signal at price: ", currentPrice);
            
                    }
                }
              }
            }
            }
          }
        }
        
        // UPPER TRENDLINE SIGNALS (Marked with "u")
        if(StringFind(objectName, "u") > -1){

          uppertrend = objectName;

          // Iterate over historical bars
          int barsTocheck = 50;  // Number of bars to check
          for(int barIndex = barsTocheck; barIndex >= 1; barIndex--){

            // Get time of current bar
            datetime barTime = Time[barIndex];
            
            // Get trendline price at this bar
            double trendlinePrice = ObjectGetValueByTime(0, uppertrend, barTime);
            
            // Skip invalid trendline prices
            if(trendlinePrice <= 0) continue;
            
            // Enhanced signal detection with multiple candle confirmation
            bool priceBreakingUp = false;
            bool upwardTrend = true;
            
            // Check for price breaking above trendline with multiple confirmation candles
            if(Close[barIndex + SignalConfirmationBars] < trendlinePrice && Close[barIndex] > trendlinePrice){
              
              priceBreakingUp = true;
              
              // Confirm upward trend using multiple bars
              for(int trendCheck = barIndex; trendCheck < barIndex + TrendConfirmationBars && trendCheck < barsToCheck; trendCheck++){

                if(Close[trendCheck] < Close[trendCheck + 1]){

                  upwardTrend = false;
                  break;
                }
              }
            }
            
            // Filter frequent signals
            bool signalTimeFilter = Time[barIndex] - lastTrendlineBuySignal > PeriodSeconds(PERIOD_CURRENT) * SignalFilterPeriod;
            
            // Only draw if all conditions are met
            if(priceBreakingUp && upwardTrend && signalTimeFilter){

              // Record signal time
              lastTrendlineBuySignal = Time[barIndex];
              
              // Get multiple price confirmations
              double currentPrice = Close[barIndex];
              double currentHigh = High[barIndex];
              double trendlinePrice = ObjectGetValueByTime(0, uppertrend, Time[barIndex]);
              
              // Only proceed if we have valid price data
              if(trendlinePrice > 0){

                // Require both close and high to be above trendline for confirmation
                bool isBreakConfirmed = currentPrice > trendlinePrice && currentHigh > trendlinePrice;
                
                // Additional check: at least 2 consecutive closes above trendline
                bool consecutiveCloses = Close[barIndex] > trendlinePrice && Close[barIndex+1] > trendlinePrice;
                
                // Draw the buy arrow only on confirmed break
                if(isBreakConfirmed){

                    double range = High[barIndex] - Low[barIndex];
                    double dynamic_arrow_dist = range * ArrowDist;
                    double arrowPrice = Low[barIndex] - dynamic_arrow_dist;
                    DrawArrowBuy("Trendline_Buy", barIndex, arrowPrice, clrBlue, 10);

                    Alert("Price broke above uppeer trendline - Potential BUY Signal at price: ", currentPrice);
                  }
              }
            }
          }
        }
      }
    }
    
    //+------------------------------------------------------------------+
    // MOVING AVERAGE SIGNALS                                            |
    //+------------------------------------------------------------------+
    if(isMAArrowActive){
      
      // Iterate over historical bars (e.g., last 50 bars)
      int barsTocheck = 50;  // Adjust as needed
      
      for(int barIndex = barsTocheck; barIndex >= 1; barIndex--){

        datetime barTime = Time[barIndex];  // Time of the current bar in the loop

        // EMA 34 SELL
        if(ema[barIndex+3]<Close[barIndex+3] && ema[barIndex+1]>Close[barIndex+1]){
        
          double arrowPrice = High[barIndex];
          Print("Price crossed below Moving Average at bar: ", barIndex);
          DrawArrowSell("EMA_Sell", barIndex, arrowPrice+dynamic_arrow_dist, clrRed, 16);
        }

        // EMA BUY
        if(ema[barIndex+3]>Close[barIndex+3] && ema[barIndex+1]<Close[barIndex+1]){
        
          double arrowPrice = Low[barIndex];
          Print("Price crossed Above Moving Average at bar: ", barIndex);
          DrawArrowBuy("EMA_Buy", barIndex, arrowPrice-dynamic_arrow_dist, clrBlue, 16);
        }
      }
    }
    
    //+------------------------------------------------------------------+
    //| RETEST SIGNALS                                                   |
    //+------------------------------------------------------------------+
    if(isRetestActive){

      string objectName = ObjectName(0, i, 0, OBJ_TREND);
      string LowerTrendline = objectName;
      string UpperTrendline = objectName;
      double arrowPrice = High[i];

      // LOWER TRENDLINE
      if(ObjectFind(0, LowerTrendline) != -1 && ObjectGetInteger(0, LowerTrendline, OBJPROP_TYPE) == OBJ_TREND){
        
        // Check if the trendline name contains 'l' (can be lowercase or uppercase)
        if(StringFind(LowerTrendline, "l") > -1 || StringFind(LowerTrendline, "L") > -1){
          
          //Print("Found trendline: ", LowerTrendline);  // Debugging output
          // Search for the previous green candlestick (resistance order block)
          int green_candle_index = FindPreviousGreenCandleAboveTrendline(LowerTrendline, price);

          // Debugging: check if green candle index is valid
          //Print("Green candle index: ", green_candle_index);

          if(green_candle_index != -1){

            // Draw the order block (resistance zone)
            //DrawOrderBlock("Upper OB",green_candle_index,i, clrLime,15);
            DrawOrderBlock(green_candle_index, clrLime);
            Print("Drawing order block for index: ", green_candle_index);

            // Get high and low of the OB
            double ob_high = iHigh(_Symbol, _Period, green_candle_index);
            double ob_low = iLow(_Symbol, _Period, green_candle_index);

            // Debugging: check if high and low are correct
            Print("OB High: ", ob_high, " OB Low: ", ob_low);

            // Wait for price to retest the OB with enhanced confirmation
            double signalStrength = 0;
            if(IsPriceRetestingOB(ob_high, ob_low, i, signalStrength, false)){

              // Wait for price to retest the OB with enhanced confirmation
              double signalStrength = 0;
              if(IsPriceRetestingOB(ob_high, ob_low, i, signalStrength, false)){

              // Retest confirmed, plot sell arrow
              string arrowName = "Retest_Sell_" + DoubleToString(signalStrength*10, 0);
              DrawArrowSell(arrowName, i, arrowPrice, clrBlack, 10);
              
              if(Audible_Alerts && Time[0] - time_alert > 300){

                Alert("Confirmed Retest SELL Signal with strength: " + DoubleToString(signalStrength, 2));
                time_alert = Time[0];
              }
            }
            }
          }
        }
      }

      // UPPER TRENDLINE  
      if(ObjectFind(0, UpperTrendline) != -1 && ObjectGetInteger(0, UpperTrendline, OBJPROP_TYPE) == OBJ_TREND){
        
        // Check if the trendline name contains 'l' (can be lowercase or uppercase)
        if(StringFind(UpperTrendline, "u") > -1 || StringFind(UpperTrendline, "U") > -1){
          
          //Print("Found trendline: ", LowerTrendline);  // Debugging output
          // Search for the previous green candlestick (resistance order block)
          int red_candle_index = FindPreviousRedCandleBelowTrendline(UpperTrendline, price);

          // Debugging: check if green candle index is valid
          //Print("Red  candle index: ", green_candle_index);

          if(red_candle_index != -1){

            // Draw the order block (resistance zone)
            //DrawOrderBlock("Upper OB",green_candle_index,i, clrLime,15);
            DrawOrderBlock(red_candle_index, clrTomato);
            Print("Drawing order block for index: ", red_candle_index);

            // Get high and low of the OB
            double ob_high = iHigh(_Symbol, _Period, red_candle_index);
            double ob_low = iLow(_Symbol, _Period, red_candle_index);

            // Debugging: check if high and low are correct
            Print("OB High: ", ob_high, " OB Low: ", ob_low);

            // Wait for price to retest the OB with enhanced confirmation
            double signalStrength = 0;
            if(IsPriceRetestingOB(ob_high, ob_low, i, signalStrength, true)){

              // Retest confirmed, plot buy arrow
              string arrowName = "Retest_Buy_" + DoubleToString(signalStrength*10, 0);
              DrawArrowBuy(arrowName, i, arrowPrice, clrBlack, 10);
              
              if(Audible_Alerts && Time[0] - time_alert > 300){

                Alert("Confirmed Retest BUY Signal with strength: " + DoubleToString(signalStrength, 2));
                time_alert = Time[0];
              }
            }
          }
        }
      }
    }
  
    //+------------------------------------------------------------------+
    //| RSI-MA SIGNALS                                                   |
    //+------------------------------------------------------------------+
    if(isRsiMaActive){

      // Iterate over historical bars (e.g., last 50 bars)
      
      
      for(int barIndex = barsToCheck; barIndex >= 1; barIndex--){

        datetime barTime = Time[barIndex];  // Time of the current bar in the loop

        // Buy Signal
        //if(Close[barIndex] > MA800[barIndex]){

          if(RSI[barIndex+2] <= RSI_Level && RSI[barIndex] >= RSI_Level && MA21[barIndex+2] > Close[barIndex+2] && MA21[barIndex+1] < Close[barIndex+1]){

            double arrowPrice = Low[barIndex];
            DrawArrowBuy("RSI-MA_Buy", barIndex, arrowPrice-dynamic_arrow_dist, clrBlue, 16);
            MessageBox("Buy Now on ",Symbol());
          }
        //}

        // Sell Signal
        //if(Close[barIndex]<MA800[barIndex]){

          if(RSI[barIndex+2] >= RSI_Level && RSI[barIndex] <= RSI_Level && MA21[barIndex+2] < Close[barIndex+2] && MA21[barIndex+1] > Close[barIndex+1]){

            double arrowPrice = High[barIndex];
            DrawArrowSell("RSI-MA_Sell", barIndex, arrowPrice+dynamic_arrow_dist, clrRed, 16);
            MessageBox("Sell Now on ",Symbol());
          }        
        //}
      }
    }
  
    //+------------------------------------------------------------------+
    //| MACD-RSI SIGNALS                                                 |
    //+------------------------------------------------------------------+
    if(isMacdRsiActive){

      // Iterate over historical bars (e.g., last 50 bars)
      for(int barIndex = barsToCheck; barIndex >= 1; barIndex--){

        datetime barTime = Time[barIndex];  // Time of the current bar in the loop

        // Buy Signal
        if(RSI[barIndex] > level && MACD_Signal[barIndex] <= MACD_Main[barIndex]){
        
          if(MACD_Main[barIndex] > 0 && MACD_Main[barIndex+1] < 0){
          
            double arrowPrice = Low[barIndex];
            DrawArrowBuy("MACD-RSI_Buy", barIndex, arrowPrice-dynamic_arrow_dist, clrPurple, 16);
            MessageBox("Buy Now on ",Symbol());
          }
        }
          
        // Sell Signal
        if(RSI[barIndex] < level && MACD_Signal[barIndex] >= MACD_Main[i]){
        
          if(MACD_Main[barIndex] < 0 && MACD_Main[barIndex+1] > 0){
          
            double arrowPrice = High[barIndex];
            DrawArrowSell("MACD-RSI_Sell", barIndex, arrowPrice+dynamic_arrow_dist, clrPurple, 16);
            MessageBox("Sell Now on ",Symbol());
          }
        }
      
        // Alerts on when to close profitable positions
        if(MACD_Signal[barIndex+1] > MACD_Main[barIndex+1] && MACD_Signal[barIndex] < MACD_Main[barIndex]){
        
          MessageBox("!!! WARNING !!! Close Sell Profitable Positions");
        }
        if(MACD_Signal[barIndex+1] < MACD_Main[barIndex+1] && MACD_Signal[barIndex] > MACD_Main[barIndex]){
        
          MessageBox("!!! WARNING !!! Close Buy Profitable Positions");
        } 
      }
    }

    //+------------------------------------------------------------------+
    //|  MACD-RSI-MA SIGNALS                                             |
    //+------------------------------------------------------------------+
    if(isMMRActive){

      // Iterating through historical bars for signal calculations
      for(int barIndex = barsToCheck; barIndex >= 1; barIndex--){

        // Buy Signal Logic
        // Confirming RSI is above specified level and a bullish crossover occurs
        if(RSI[barIndex] >= RSI_Level + 5 && MACD_Signal[barIndex] < MACD_Main[barIndex]){

          if(MACD_Main[barIndex] > 0 && MACD_Main[barIndex+1] <= 0 && Close[barIndex] > ema200){
          
            double arrowPrice = Low[barIndex];
            DrawArrowBuy("MMR_Buy", barIndex, arrowPrice-dynamic_arrow_dist, clrBlue, 16);
            
          }
        }
      
        // Sell Signal Logic
        // Confirming RSI is below specified level and a bearish crossover occurs
        if(RSI[barIndex] <= RSI_Level - 5 && MACD_Signal[barIndex] > MACD_Main[barIndex]){

          if(MACD_Main[barIndex] < 0 && MACD_Main[barIndex+1] >= 0){

            double arrowPrice = High[barIndex];
            DrawArrowSell("MMR_Sell", barIndex, arrowPrice+dynamic_arrow_dist, clrRed, 16);

          }
        }
      
        // Alerts on when to close profitable positions
        if(MACD_Signal[barIndex+1] > MACD_Main[barIndex+1] && MACD_Signal[barIndex] < MACD_Main[barIndex]){
        
          MessageBox("!!! WARNING !!! Close Sell Profitable Positions");
        }
        if(MACD_Signal[barIndex+1] < MACD_Main[barIndex+1] && MACD_Signal[barIndex] > MACD_Main[barIndex]){
        
          MessageBox("!!! WARNING !!! Close Buy Profitable Positions");
        } 
      }
    }
  
    //+------------------------------------------------------------------+
    //|  MACD-RSI-MA RETEST SIGNALS                                      |
    //+------------------------------------------------------------------+
    if(isMMRetestActive){

      // Iterate over historical bars (e.g., last 50 bars)
      for(int barIndex = barsToCheck - 1; barIndex >= 1; barIndex--){

        datetime barTime = Time[barIndex];  // Time of the current bar in the loop

        // Buy Signal
        if(RSI[barIndex] > level && MACD_Signal[barIndex] <= MACD_Main[barIndex]){

          if(MACD_Main[barIndex] > 0 && MACD_Main[barIndex+1] < 0 && Close[barIndex] > ema50){
          
            double arrowPrice = Low[barIndex];
            DrawArrowBuy("MMR_Buy", barIndex, arrowPrice-dynamic_arrow_dist, clrBlack, 16);
            
          }
        }
          
        // Sell Signal
        if(RSI[barIndex] < level && MACD_Signal[barIndex] >= MACD_Main[barIndex]){
        
          if(MACD_Main[barIndex] < 0 && MACD_Main[barIndex+1] > 0 && Close[barIndex] < ema50){
          
            double arrowPrice = High[barIndex];
            DrawArrowSell("MMR_Sell", barIndex, arrowPrice+dynamic_arrow_dist, clrBlack, 16);
            Print("Sell Now on ",Symbol());
          }
        }
      }
    }  
  
  }
  
  return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+

bool IsPriceRetestingOB(double high_price, double low_price, int barIndex, double &signalStrength, bool isBuySignal){

  // Starting point for signal strength calculation (0.0 to 1.0 scale)
  signalStrength = 0.0;
  int confirmationCount = 0;
  double maxSignalStrength = 5.0; // Total possible points from all confirmations
  
  // Basic price retest check
  bool priceRetesting = false;
  
  if(isBuySignal){
    // For BUY signal: Price should retest the upper OB from below
    double current_price = Close[barIndex];
    double high_price_bar = High[barIndex];
    
    if(current_price > low_price && high_price_bar < high_price){

      priceRetesting = true;
      confirmationCount++;
      signalStrength += 1.0;
      Print("Basic price retest detected for BUY");
    }
  } 
  else{

    // For SELL signal: Price should retest the lower OB from above
    double current_price = Close[barIndex];
    double low_price_bar = Low[barIndex];
    
    if(current_price < high_price && low_price_bar > low_price){

      priceRetesting = true;
      confirmationCount++;
      signalStrength += 1.0;
      Print("Basic price retest detected for SELL");
    }
  }
  
  // If basic retest not detected, no need to check further
  if(!priceRetesting) return false;
  
  // 1. Multiple candle confirmation
  bool multipleCandles = CheckMultipleCandleConfirmation(barIndex, RetestConfirmationBars, isBuySignal);
  if(multipleCandles){

    confirmationCount++;
    signalStrength += 1.0;
    Print("Multiple candle confirmation passed");
  }
  
  // 2. Volume confirmation if required
  if(RequireVolumeConfirmation){

    bool volumeConfirmed = CheckVolumeConfirmation(barIndex, MinimumVolumeIncrease);
    if(volumeConfirmed){

      confirmationCount++;
      signalStrength += 1.0;
      Print("Volume confirmation passed");
    }
  } 
  else{

    // If not required, automatically consider it a pass
    confirmationCount++;
    signalStrength += 0.5; // Half point for skipping this check
  }
  
  // 3. Price action pattern confirmation if required
  if(RequirePriceActionConfirmation){

    bool patternConfirmed = CheckPriceActionPattern(barIndex, isBuySignal);
    if(patternConfirmed){

      confirmationCount++;
      signalStrength += 1.0;
      Print("Price action pattern confirmation passed");
    }
  } 
  else{

    // If not required, automatically consider it a pass
    confirmationCount++;
    signalStrength += 0.5; // Half point for skipping this check
  }
  
  // 4. Trend direction alignment if required
  if(RequireTrendAlignment){

    bool trendAligned = IsTrendAligned(barIndex, isBuySignal);
    if(trendAligned){

      confirmationCount++;
      signalStrength += 1.0;
      Print("Trend alignment confirmation passed");
    }
  } 
  else{

    // If not required, automatically consider it a pass
    confirmationCount++;
    signalStrength += 0.5; // Half point for skipping this check
  }
  
  // Normalize signal strength to 0-1 scale
  signalStrength = signalStrength / maxSignalStrength;
  
  // Require at least 3 confirmations for a valid signal
  bool validSignal = (confirmationCount >= 3);
  
  if(validSignal){

    string direction = isBuySignal ? "BUY" : "SELL";
    Print("Valid retest signal detected for ", direction, " with strength: ", signalStrength);
    return true;
  }
  
  return false;
}

// Helper function to check for multiple candle confirmation
bool CheckMultipleCandleConfirmation(int barIndex, int barsTocheck, bool isBuySignal){
  
  int confirmedBars = 0;
  
  for(int i = barIndex; i < barIndex + barsTocheck && i < Bars(_Symbol, _Period) - 1; i++){

    if(isBuySignal){

      // For buy signals, check if price is moving up
      if(Close[i] > Close[i+1]){
        confirmedBars++;
      } 
      else{
        break; // Consecutive confirmation required
      }
    } 
    else{
      // For sell signals, check if price is moving down
      if(Close[i] < Close[i+1]){
        confirmedBars++;
      } 
      else{
        break; // Consecutive confirmation required
      }
    }
  }
  
  // Require at least half of the bars to confirm the direction
  int minConfirmation = MathMax(2, (int)MathFloor(barsToCheck / 2.0));
  return confirmedBars >= minConfirmation;
}

// Helper function to check volume confirmation
bool CheckVolumeConfirmation(int barIndex, double minimumIncrease){

  // We need at least 3 bars of volume data
  if(barIndex + 2 >= Bars(_Symbol, _Period)){
    return false;
  }
  
  // Calculate average volume for the previous 5 bars
  double avgVolume = 0;
  int volumeBars = MathMin(5, Bars(_Symbol, _Period) - barIndex - 1);
  
  for(int i = barIndex + 1; i < barIndex + 1 + volumeBars; i++){
    avgVolume += (double)Volume[i];
  }
  
  if(volumeBars > 0){
    avgVolume /= volumeBars;
  } 
  else{
    return false;
  }
  
  // Validate volume data
  if(Volume[barIndex] <= 0 || avgVolume <= 0){

    Print("Invalid volume data detected");
    return false;
  }
  
  // Check if current volume exceeds the average by the minimum increase factor
  bool volumeIncreased = Volume[barIndex] >= avgVolume * minimumIncrease;
  
  if(volumeIncreased){

    Print("Volume confirmation: Current volume (", Volume[barIndex], 
    ") exceeds average (", avgVolume, ") by factor of ", 
    Volume[barIndex] / (avgVolume > 0 ? avgVolume : 1));
  }
  
  return volumeIncreased;
}

// Helper function to detect price action patterns
bool CheckPriceActionPattern(int barIndex, bool isBuySignal){

  // We need at least 3 bars of data
  if(barIndex + 3 >= Bars(_Symbol, _Period)){
    return false;
  }
  
  bool patternConfirmed = false;
  
  if(isBuySignal){
    // For buy signals, look for bullish patterns
    
    // Check for bullish engulfing pattern
    bool bullishEngulfing = (Open[barIndex] < Close[barIndex]) &&             // Current bar is bullish
    (Open[barIndex+1] > Close[barIndex+1]) &&          // Previous bar is bearish
    (Open[barIndex] <= Close[barIndex+1]) &&            // Current open below or equal to previous close
    (Close[barIndex] > Open[barIndex+1]);               // Current close above previous open
    
    // Check for morning star pattern (simplified)
    bool morningStar = (Open[barIndex] < Close[barIndex]) &&                   // Current bar is bullish
    (Open[barIndex+2] > Close[barIndex+2]) &&               // Bar before previous is bearish
    (MathAbs(Open[barIndex+1] - Close[barIndex+1]) <        // Middle bar has small body
    0.3 * MathAbs(Open[barIndex+2] - Close[barIndex+2]));
    
    // Check for hammer pattern
    double bodySize = MathAbs(Open[barIndex] - Close[barIndex]);
    double lowerWick = MathMin(Open[barIndex], Close[barIndex]) - Low[barIndex];
    double upperWick = High[barIndex] - MathMax(Open[barIndex], Close[barIndex]);
    bool hammer = (Open[barIndex] < Close[barIndex]) &&                        // Current bar is bullish
    (lowerWick >= 2 * bodySize) &&                               // Lower wick at least 2x body size
    (upperWick <= 0.2 * bodySize);                               // Very small or no upper wick
    
    patternConfirmed = bullishEngulfing || morningStar || hammer;
    
    if(patternConfirmed){

      if(bullishEngulfing) Print("Bullish Engulfing pattern detected at bar ", barIndex);
      if(morningStar) Print("Morning Star pattern detected at bar ", barIndex);
      if(hammer) Print("Hammer pattern detected at bar ", barIndex);
    }
  } 
  else{
    // For sell signals, look for bearish patterns
    
    // Check for bearish engulfing pattern
    bool bearishEngulfing = (Open[barIndex] > Close[barIndex]) &&             // Current bar is bearish
    (Open[barIndex+1] < Close[barIndex+1]) &&          // Previous bar is bullish
    (Open[barIndex] >= Close[barIndex+1]) &&            // Current open above or equal to previous close
    (Close[barIndex] < Open[barIndex+1]);               // Current close below previous open
    
    // Check for evening star pattern (simplified)
    bool eveningStar = (Open[barIndex] > Close[barIndex]) &&                   // Current bar is bearish
    (Open[barIndex+2] < Close[barIndex+2]) &&               // Bar before previous is bullish
    (MathAbs(Open[barIndex+1] - Close[barIndex+1]) <        // Middle bar has small body
    0.3 * MathAbs(Open[barIndex+2] - Close[barIndex+2]));
    
    // Check for shooting star pattern
    double bodySize = MathAbs(Open[barIndex] - Close[barIndex]);
    double upperWick = High[barIndex] - MathMax(Open[barIndex], Close[barIndex]);
    double lowerWick = MathMin(Open[barIndex], Close[barIndex]) - Low[barIndex];
    bool shootingStar = (Open[barIndex] > Close[barIndex]) &&                  // Current bar is bearish
    (upperWick >= 2 * bodySize) &&                         // Upper wick at least 2x body size
    (lowerWick <= 0.2 * bodySize);                         // Very small or no lower wick
    
    patternConfirmed = bearishEngulfing || eveningStar || shootingStar;
    
    if(patternConfirmed){

      if(bearishEngulfing) Print("Bearish Engulfing pattern detected at bar ", barIndex);
      if(eveningStar) Print("Evening Star pattern detected at bar ", barIndex);
      if(shootingStar) Print("Shooting Star pattern detected at bar ", barIndex);
    }
  }
  return patternConfirmed;
}

// Helper function to check trend alignment with the signal
bool IsTrendAligned(int barIndex, bool isBuySignal){

  // Check the ema to determine the overall trend
  int barsTocheck = 10; // Look back 10 bars to determine the trend
  bool trendAligned = false;
  
  // Make sure we have enough bars
  if(barIndex + barsTocheck >= Bars(_Symbol, _Period)){

    barsTocheck = Bars(_Symbol, _Period) - barIndex - 1;
  }
  
  if(barsTocheck < 3) return false; // Not enough bars to determine trend
  
  // Count bars where price is above/below ema
  int barsAboveEMA = 0;
  int barsBelowEMA = 0;
  
  for(int i = barIndex; i < barIndex + barsTocheck; i++){

    if(Close[i] > ema[i]) barsAboveEMA++;
    if(Close[i] < ema[i]) barsBelowEMA++;
  }
  
  // For a buy signal, we want to see an uptrend (more bars above EMA)
  if(isBuySignal){

    trendAligned = barsAboveEMA > (barsToCheck * 0.6); // At least 60% of bars above EMA
    if(trendAligned) Print("Uptrend confirmed: ", barsAboveEMA, " of ", barsToCheck, " bars above EMA");
  } 
  
  // For a sell signal, we want to see a downtrend (more bars below EMA)
  else{

    trendAligned = barsBelowEMA > (barsToCheck * 0.6); // At least 60% of bars below EMA
    if(trendAligned) Print("Downtrend confirmed: ", barsBelowEMA, " of ", barsToCheck, " bars below EMA");
  }
  
  return trendAligned;
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

  // Get total bars
  int totalBars = Bars(_Symbol, _Period);
  if(totalBars < 2) return -1;

  // Check if the trendline object exists
  if(ObjectFind(0, trendlineName) < 0){

    Print("Trendline not found: ", trendlineName);
    return -1;
  }

  // Start looking from the most recent bar and move backwards
  for(int i = 0; i < totalBars - 2; i++){

    // Get the price of the trendline at this bar's time
    double trendlinePrice = TrendlinePriceLower(i);
    if(trendlinePrice == 0) continue;

    // Check if the close price crosses the trendline
    if(Close[i + 2] > trendlinePrice && Close[i + 1] < trendlinePrice){
      // Debugging
      //Print("Close price crossed trendline at index: ", i+1);

      // Check the previous 10 bars for a green candle
      for(int j = i; j < i + 20 && j < totalBars; j++){

        double prev_open_price = iOpen(_Symbol, _Period, j);
        double prev_close_price = iClose(_Symbol, _Period, j);
        double ob_high = iHigh(_Symbol, _Period, j);
        double ob_low = iLow(_Symbol, _Period, j);

        // Check for a green (bullish) candle
        if(prev_open_price < prev_close_price){

          Print("Found green candle at index: ", j, " with OB High: ", ob_high, " OB Low: ", ob_low);
          return j;  // Return the index of the green candle
        }
      }
    }
  }

  // If no green candle is found, return -1
  Print("No green candle found above the trendline.");
  return -1;               
}

int FindPreviousRedCandleBelowTrendline(string trendlineName, double currentPrice){
  
  // Get total bars
  int totalBars = Bars(_Symbol, _Period);
  if(totalBars < 2) return -1;

  // Check if the trendline object exists
  if(ObjectFind(0, trendlineName) < 0){

    Print("Trendline not found: ", trendlineName);
    return -1;
  }

  // Start from the latest bar and move backwards
  for(int i = 1; i < totalBars - 2; i++){

    double trendlinePrice = TrendlinePriceUpper(i);
    if(trendlinePrice <= 0) continue;  // Skip invalid trendline values

    // Check if the price crossed above the trendline
    if(Close[i + 1] < trendlinePrice && Close[i] > trendlinePrice){
      
      // Look for a bearish (red) candle within the last 10 bars
      for(int j = i; j < i + 10 && j < totalBars; j++){

        double prevOpen = iOpen(_Symbol, _Period, j);
        double prevClose = iClose(_Symbol, _Period, j);
        if(prevOpen > prevClose){  // Red candle condition

          double obHigh = iHigh(_Symbol, _Period, j);
          double obLow = iLow(_Symbol, _Period, j);

          Print("Found red candle at index: ", j, " OB High: ", obHigh, " OB Low: ", obLow);
          return j;
        }
      }
      break;  // Stop after the first crossing event
    }
  }

  Print("No red candle found below the trendline.");
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
    
  // Check if the name contains either upper or lower trendline identifiers
  if(StringFind(name, "u") == -1 && StringFind(name, "l") == -1) return;
  if(StringFind(name, "res") == -1 && StringFind(name, "sup") == -1) return;

  // Quick check that the object exists in the correct window
  // I'm looking at window 0
  int sub_window = ObjectFind(0, name);
  if(sub_window!=0)   return;
  
  
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
  
  for(int i = 0; i < obj_total; i++){

    string name = ObjectName(0, i);  // Get the object name
    int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);

    // Debug: Log all object names and types
    //Print("Object Name: ", name, " | Type: ", type);

    // Check if the object is a trendline and contains "l" (or "l1")
    if(type == OBJ_TREND && StringFind(name, "l") > -1){

      double price = ObjectGetValueByTime(0, name, barTime, 0);  // Get trendline price
      // Debug: Log the price retrieval
      //Print("Checking Lower Trendline: ", name, " | Time: ", TimeToString(barTime), " | Price: ", price);

      if(price > 0 && price < minprice){
        minprice = price;  // Update the minimum price
      }
    }
  }
  return(minprice == DBL_MAX) ? -1 : minprice;  // Return the lowest price, or -1 if none found
}

double TrendlinePriceUpper(int shift){
  
  int obj_total = ObjectsTotal(0);  // Total number of objects on the chart
  double maxprice = -DBL_MAX;       // Initialize with the lowest possible value
  datetime barTime = iTime(NULL, 0, shift);  // Time of the bar at 'shift'
  
  for(int i = 0; i < obj_total; i++){

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

bool IsOBExists(string arrowName, datetime time){

  // Iterate through all objects on the chart
  int totalObjects = ObjectsTotal(0, 0, OBJ_RECTANGLE);
  for(int i = 0; i < totalObjects; i++){

    string name = ObjectName(0, i);  // Get the object's name
    // Check if the object name matches the arrow name
    if(StringFind(name, arrowName) > -1){

      datetime OB_Time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
      // Check if the time matches the arrow's time
      if(OB_Time == time){

        return true;  // OB already exists
      }
    }
  }
  return false;  // No matching OB found
}

void DrawArrowSell(string arrowPrefix, int i, double arrowPrice, color arrowColor, int arrowFilter){
  
  bool arrowExists = false;
  for(int k = 0; k < maxBars - oldBars; k++){

    // Add bounds check to prevent accessing beyond valid objects
    if(k >= ObjectsTotal(0, 0, -1)) break;
    // Add bounds check to prevent accessing beyond valid objects
    if(k >= ObjectsTotal(0, 0, -1)) break;

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

    // Add bounds check to prevent accessing beyond valid objects
    if(k >= ObjectsTotal(0, 0, -1)) break;
    // Add bounds check to prevent accessing beyond valid objects
    if(k >= ObjectsTotal(0, 0, -1)) break;

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

void RemoveOldSignals(){

  datetime buyTimes[], sellTimes[];
  string buyNames[], sellNames[];
  int buyCount = 0, sellCount = 0;
  
  // First collect and separate buy/sell signals
  int totalArrows = ObjectsTotal(0, 0, OBJ_ARROW);
  for(int i = 0; i < totalArrows; i++){
    
    string name = ObjectName(0, i);
    if(StringLen(name) == 0) continue;
    
    long arrowCode = ObjectGetInteger(0, name, OBJPROP_ARROWCODE);
    datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
    
    if(arrowCode == (long)233){  // Buy arrow

      ArrayResize(buyTimes, buyCount + 1);
      ArrayResize(buyNames, buyCount + 1);
      buyTimes[buyCount] = objTime;
      buyNames[buyCount] = name;
      buyCount++;
    }
    else if(arrowCode == (long)234){  // Sell arrow

      ArrayResize(sellTimes, sellCount + 1);
      ArrayResize(sellNames, sellCount + 1);
      sellTimes[sellCount] = objTime;
      sellNames[sellCount] = name;
      sellCount++;
    }
  }
  
  // Process buy signals if we have too many
  if(buyCount > MaxSignalsToKeep){

    ArraySort(buyTimes);  // Sort times (oldest first)
    int toRemove = buyCount - MaxSignalsToKeep;
    for(int i = 0; i < toRemove; i++){

      // Find and remove signal with matching time
      for(int j = 0; j < buyCount; j++){

        if(buyTimes[i] == (datetime)ObjectGetInteger(0, buyNames[j], OBJPROP_TIME)){

          ObjectDelete(0, buyNames[j]);
          break;
        }
      }
    }
  }
  
  // Process sell signals if we have too many
  if(sellCount > MaxSignalsToKeep){

    ArraySort(sellTimes);  // Sort times (oldest first)
    int toRemove = sellCount - MaxSignalsToKeep;
    for(int i = 0; i < toRemove; i++){

      // Find and remove signal with matching time
      for(int j = 0; j < sellCount; j++){

        if(sellTimes[i] == (datetime)ObjectGetInteger(0, sellNames[j], OBJPROP_TIME)){
          ObjectDelete(0, sellNames[j]);
          break;
        }
      }
    }
  }
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