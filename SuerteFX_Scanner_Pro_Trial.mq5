#property copyright         "SuerteFX"
#property version           "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "EMA 20"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_style1  STYLE_SOLID

#property indicator_label2  "EMA 50"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1
#property indicator_style2  STYLE_SOLID

#property indicator_label3  "EMA 200"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMagenta
#property indicator_width3  2
#property indicator_style3  STYLE_SOLID

#include "SuerteFX_Trial.mqh"

input int    InpPivotSpan     = 3;
input int    InpLookback      = 120;
input int    InpMaxSR         = 4;
input int    InpEMA20         = 20;
input int    InpEMA50         = 50;
input int    InpEMA200        = 200;
input bool   InpShowEMAs      = true;
input bool   InpShowSR        = true;
input bool   InpShowLiquidity = true;
input bool   InpShowStructure = true;
input int    InpATRPeriod     = 14;
input double InpLiqThresh     = 0.20;
input double InpSRCluster     = 0.25;
input double InpSLBufferATR   = 1.5;
input bool   InpEnableAlerts  = true;
input int    InpPanelCorner   = CORNER_LEFT_UPPER;
input int    InpPanelX        = 14;
input int    InpPanelY        = 18;
input double InpRiskPct       = 1.0;
input double InpAccountRisk   = 1.0;
input double InpMinRR         = 2.0;

double buf_ema20[];
double buf_ema50[];
double buf_ema200[];

int h_ema20  = INVALID_HANDLE;
int h_ema50  = INVALID_HANDLE;
int h_ema200 = INVALID_HANDLE;
int h_atr    = INVALID_HANDLE;

string   g_pfx            = "SuerteFX_PRO_";
datetime g_last_alert_bar = 0;
string   g_last_alert_sig = "";

struct SwingPt { datetime time; double price; bool is_high; int idx; };
struct SRLvl   { double price; bool is_res; int strength; datetime origin_time; int high_cnt; int low_cnt; };
struct LiqPool { double price; bool buy_side; };

struct TradingSetup
{
   string type;
   double entry;
   double sl;
   double tp;
   double rr;
   string reason;
   string bias;
   string structure;
};
struct TFSummary { string label; string bias; string structure; };

// ─── Helpers ────────────────────────────────────────────────────────────────

string TFLabel(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_MN1: return "MN";  case PERIOD_W1:  return "W1";
      case PERIOD_D1:  return "D1";  case PERIOD_H12: return "H12";
      case PERIOD_H8:  return "H8";  case PERIOD_H6:  return "H6";
      case PERIOD_H4:  return "H4";  case PERIOD_H3:  return "H3";
      case PERIOD_H2:  return "H2";  case PERIOD_H1:  return "H1";
      case PERIOD_M30: return "M30"; case PERIOD_M20: return "M20";
      case PERIOD_M15: return "M15"; case PERIOD_M12: return "M12";
      case PERIOD_M10: return "M10"; case PERIOD_M6:  return "M6";
      case PERIOD_M5:  return "M5";  case PERIOD_M4:  return "M4";
      case PERIOD_M3:  return "M3";  case PERIOD_M2:  return "M2";
      case PERIOD_M1:  return "M1";
   }
   return EnumToString(tf);
}

double GetATR()
{
   if(h_atr == INVALID_HANDLE) return _Point * 100.0;
   double b[2];
   if(CopyBuffer(h_atr, 0, 1, 2, b) < 1) return _Point * 100.0;
   return MathMax(b[0], _Point);
}

double GetEMAVal(int handle, int shift = 1)
{
   double b[1];
   if(CopyBuffer(handle, 0, shift, 1, b) != 1) return 0.0;
   return b[0];
}

int GetVolumeRatio()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(_Symbol, _Period, 1, 21, rates);
   if(n < 5) return 100;
   int cnt = MathMin(n - 1, 20);
   long avg = 0;
   for(int i = 1; i <= cnt; i++) avg += rates[i].tick_volume;
   if(cnt == 0 || avg == 0) return 100;
   avg /= cnt;
   return (int)(rates[0].tick_volume * 100 / avg);
}

void ClearObjs(const string prefix)
{
   int n = ObjectsTotal(0);
   for(int i = n - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

void SetLabel(const string id, const string text, int x, int y,
              color clr, int sz, bool bold = false)
{
   string name = g_pfx + "PNL_" + id;
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    InpPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + y);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  sz);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    false);
   ObjectSetString(0,  name, OBJPROP_FONT,      bold ? "Segoe UI Semibold" : "Segoe UI");
   ObjectSetString(0,  name, OBJPROP_TEXT,      text);
}

void SetLabelAt(const string scope, const string id, const string text,
                ENUM_BASE_CORNER corner, int x, int y,
                color clr, int sz, bool bold = false,
                ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
   string name = g_pfx + "PNL_" + scope + "_" + id;
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    corner);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,    anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  sz);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    false);
   ObjectSetString(0,  name, OBJPROP_FONT,      bold ? "Segoe UI Semibold" : "Segoe UI");
   ObjectSetString(0,  name, OBJPROP_TEXT,      text);
}

void DrawRect(const string id, int x, int y, int w, int h, color bg, color bdr)
{
   string name = g_pfx + "PNL_" + id;
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,      InpPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   InpPanelX + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   InpPanelY + y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       bdr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER,      0);
}

void DrawRectAt(const string scope, const string id,
                ENUM_BASE_CORNER corner, int x, int y, int w, int h,
                color bg, color bdr)
{
   string name = g_pfx + "PNL_" + scope + "_" + id;
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,      corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       bdr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER,      0);
}

void SetHLine(const string id, double price, color clr,
              ENUM_LINE_STYLE style, int width)
{
   string name = g_pfx + id;
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0,  name, OBJPROP_PRICE,     price);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE,     style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,     width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    false);
}

void SetText(const string id, const string text, datetime t, double price,
             color clr, int sz, ENUM_ANCHOR_POINT anchor, bool bold = false)
{
   string name = g_pfx + id;
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t);
   ObjectSetDouble(0,  name, OBJPROP_PRICE, 0, price);
   ObjectSetString(0,  name, OBJPROP_TEXT,  text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, sz);
   ObjectSetString(0,  name, OBJPROP_FONT,  bold ? "Segoe UI Semibold" : "Segoe UI");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

// ─── Swing collection ────────────────────────────────────────────────────────

int CollectSwings(MqlRates &rates[], int copied, SwingPt &out[])
{
   int span  = InpPivotSpan;
   int limit = MathMin(copied - span - 1, InpLookback + span);
   int n     = 0;
   ArrayResize(out, InpLookback * 2);

   for(int i = span + 1; i <= limit; i++)
   {
      bool ph = true, pl = true;
      for(int s = 1; s <= span && (ph || pl); s++)
      {
         if(rates[i].high <= rates[i - s].high || rates[i].high <= rates[i + s].high) ph = false;
         if(rates[i].low  >= rates[i - s].low  || rates[i].low  >= rates[i + s].low)  pl = false;
      }
      if(ph)
      {
         out[n].time    = rates[i].time;
         out[n].price   = rates[i].high;
         out[n].is_high = true;
         out[n].idx     = i;
         n++;
      }
      if(pl)
      {
         out[n].time    = rates[i].time;
         out[n].price   = rates[i].low;
         out[n].is_high = false;
         out[n].idx     = i;
         n++;
      }
   }
   ArrayResize(out, n);
   return n;
}

// ─── S/R clustering ──────────────────────────────────────────────────────────

int BuildSR(SwingPt &swings[], int sw_n, double atr, double price, SRLvl &out[])
{
   ArrayResize(out, 0);
   int n = 0;
   for(int i = 0; i < sw_n; i++)
   {
      double p    = swings[i].price;
      bool is_res = (p > price);
      bool merged   = false;
      int  merged_j = -1;
      for(int j = 0; j < n; j++)
      {
         if(out[j].is_res == is_res && MathAbs(out[j].price - p) <= atr * InpSRCluster)
         {
            out[j].price = (out[j].price * out[j].strength + p) / (out[j].strength + 1);
            out[j].strength++;
            merged   = true;
            merged_j = j;
            break;
         }
      }
      if(!merged)
      {
         ArrayResize(out, n + 1);
         out[n].price       = p;
         out[n].is_res      = is_res;
         out[n].strength    = 1;
         out[n].origin_time = swings[i].time;
         out[n].high_cnt    = swings[i].is_high ? 1 : 0;
         out[n].low_cnt     = swings[i].is_high ? 0 : 1;
         n++;
      }
      else if(merged_j >= 0)
      {
         if(swings[i].is_high) out[merged_j].high_cnt++;
         else                  out[merged_j].low_cnt++;
      }
   }
   for(int a = 0; a < n - 1; a++)
      for(int b = a + 1; b < n; b++)
         if(MathAbs(out[b].price - price) < MathAbs(out[a].price - price))
         { SRLvl tmp = out[a]; out[a] = out[b]; out[b] = tmp; }
   return n;
}

// ─── Market structure ────────────────────────────────────────────────────────

string AnalyzeStructure(SwingPt &swings[], int n,
                        SwingPt &last_sh, SwingPt &last_sl,
                        SwingPt &prev_sh, SwingPt &prev_sl,
                        const double close = 0.0)
{
   ZeroMemory(last_sh);
   ZeroMemory(last_sl);
   ZeroMemory(prev_sh);
   ZeroMemory(prev_sl);

   SwingPt highs[], lows[];
   int nh = 0, nl = 0;
   for(int i = 0; i < n; i++)
   {
      if(swings[i].is_high) { ArrayResize(highs, nh + 1); highs[nh++] = swings[i]; }
      else                  { ArrayResize(lows,  nl + 1); lows[nl++]  = swings[i]; }
   }
   if(nh < 2 || nl < 2) return "Neutral";

   last_sh = highs[0]; prev_sh = highs[1];
   last_sl = lows[0];  prev_sl = lows[1];

   bool hh = highs[0].price > highs[1].price;
   bool lh = highs[0].price < highs[1].price;
   bool hl = lows[0].price  > lows[1].price;
   bool ll = lows[0].price  < lows[1].price;
   bool bull_break = close > 0.0 && close > highs[1].price;
   bool bear_break = close > 0.0 && close < lows[1].price;
   bool had_bull_state = false;
   bool had_bear_state = false;

   if(nh >= 3 && nl >= 3)
   {
      bool prev_hh = highs[1].price > highs[2].price;
      bool prev_lh = highs[1].price < highs[2].price;
      bool prev_hl = lows[1].price  > lows[2].price;
      bool prev_ll = lows[1].price  < lows[2].price;
      had_bull_state = prev_hh && prev_hl;
      had_bear_state = prev_lh && prev_ll;
   }

   if(hh && hl && !had_bear_state) return "Bullish";
   if(lh && ll && !had_bull_state) return "Bearish";
   if(had_bear_state && hl && bull_break) return "CHoCH_Bull";
   if(had_bull_state && lh && bear_break) return "CHoCH_Bear";
   if(hh && hl) return "Bullish";
   if(lh && ll) return "Bearish";
   return "Neutral";
}

// ─── Liquidity ───────────────────────────────────────────────────────────────

int FindLiquidity(SwingPt &swings[], int n, double atr, LiqPool &out[])
{
   ArrayResize(out, 0);
   int count = 0;
   for(int i = 0; i < n; i++)
      for(int j = i + 1; j < n; j++)
      {
         if(swings[i].is_high != swings[j].is_high) continue;
         if(MathAbs(swings[i].price - swings[j].price) > atr * InpLiqThresh) continue;
         double mid = (swings[i].price + swings[j].price) * 0.5;
         bool dup = false;
         for(int k = 0; k < count; k++)
            if(MathAbs(out[k].price - mid) <= atr * InpLiqThresh) { dup = true; break; }
         if(!dup)
         {
            ArrayResize(out, count + 1);
            out[count].price    = mid;
            out[count].buy_side = swings[i].is_high;
            count++;
         }
      }
   return count;
}

// ─── Unified bias classifier ──────────────────────────────────────────────────

string ClassifyBias(bool ab20, bool ab50, bool ab200)
{
   if(ab200 && ab50 && ab20)         return "Strong Bullish";
   if(ab200 && (ab50 || ab20))       return "Weak Bullish";
   if(!ab200 && !ab50 && !ab20)      return "Strong Bearish";
   if(!ab200)                        return "Weak Bearish";
   return "Neutral";
}

int MinBarsForEMA(const int period)
{
   return period + 10;
}

// ─── Entry generation ────────────────────────────────────────────────────────

TradingSetup GenerateSetup(const string structure, double close, double atr,
                           SRLvl &sr[], int sr_n,
                           SwingPt &last_sh, SwingPt &last_sl,
                           SwingPt &prev_sh, SwingPt &prev_sl,
                           LiqPool &pools[], int pool_n,
                           double ema20, double ema50, double ema200)
{
   TradingSetup s;
   s.type = "NONE"; s.entry = 0; s.sl = 0; s.tp = 0;
   s.rr   = 0;      s.reason = ""; s.structure = structure;

   bool ab200 = close > ema200 && ema200 > 0;
   bool ab50  = close > ema50  && ema50  > 0;
   bool ab20  = close > ema20  && ema20  > 0;
   bool trend_bull = ema50 > 0 && ema200 > 0 && ema50 >= ema200;
   bool trend_bear = ema50 > 0 && ema200 > 0 && ema50 <= ema200;
   bool in_discount = ema50 > 0 && close <= (ema50 + atr * 0.15);
   bool in_premium  = ema50 > 0 && close >= (ema50 - atr * 0.15);
   bool bull_sweep = prev_sl.price > 0.0 && last_sl.price <= (prev_sl.price + atr * InpLiqThresh);
   bool bear_sweep = prev_sh.price > 0.0 && last_sh.price >= (prev_sh.price - atr * InpLiqThresh);

   s.bias = ClassifyBias(ab20, ab50, ab200);

   bool bull = (structure == "Bullish" || structure == "CHoCH_Bull") && ab200 && ab50 && trend_bull;
   bool bear = (structure == "Bearish" || structure == "CHoCH_Bear") && !ab200 && !ab50 && trend_bear;

   if(bull)
   {
      if(structure == "CHoCH_Bull" && !bull_sweep)
      { s.reason = "CHOCH bull - no sell-side sweep"; return s; }
      if(!in_discount)
      { s.reason = "Bullish context - wait for discount"; return s; }

      double cands[4]; int nc = 0;
      if(last_sl.price > 0 && last_sl.price < close - atr * 0.3) cands[nc++] = last_sl.price;
      if(ema50 > 0 && ema50 < close - atr * 0.3 && nc < 4)       cands[nc++] = ema50;
      if(ema20 > 0 && ema20 < close - atr * 0.3 && nc < 4)       cands[nc++] = ema20;
      for(int i = 0; i < sr_n && nc < 4; i++)
         if(!sr[i].is_res && sr[i].price < close - atr * 0.3) { cands[nc++] = sr[i].price; break; }
      if(nc == 0) { s.reason = "No demand zone found"; return s; }

      double best = cands[0]; string rlbl = "Support";
      for(int i = 1; i < nc; i++) if(cands[i] > best) best = cands[i];
      if(MathAbs(best - last_sl.price) < _Point * 10) rlbl = "Last HL";
      else if(MathAbs(best - ema50) < _Point * 10)    rlbl = "EMA 50";
      else if(MathAbs(best - ema20) < _Point * 10)    rlbl = "EMA 20";

      double sl_price = best - atr * InpSLBufferATR;
      double tp = 0; bool has_external_tp = false;
      for(int i = 0; i < sr_n; i++)
         if(sr[i].is_res && sr[i].price > close) { tp = sr[i].price; has_external_tp = true; break; }
      for(int i = 0; i < pool_n; i++)
         if(pools[i].buy_side && pools[i].price > close)
            if(tp == 0 || pools[i].price < tp) { tp = pools[i].price; has_external_tp = true; }
      if(!has_external_tp || tp <= 0) { s.reason = "No external liquidity target"; return s; }

      double risk = best - sl_price, reward = tp - best;
      if(risk <= 0.0 || reward <= 0.0) { s.reason = "Invalid bullish risk profile"; return s; }
      string struct_lbl_b = structure; StringReplace(struct_lbl_b, "_", " ");
      s.type = "BUY_LIMIT"; s.entry = best; s.sl = sl_price; s.tp = tp;
      s.rr = reward / risk; s.reason = struct_lbl_b + " + " + rlbl;
   }
   else if(bear)
   {
      if(structure == "CHoCH_Bear" && !bear_sweep)
      { s.reason = "CHOCH bear - no buy-side sweep"; return s; }
      if(!in_premium)
      { s.reason = "Bearish context - wait for premium"; return s; }

      double cands[4]; int nc = 0;
      if(last_sh.price > 0 && last_sh.price > close + atr * 0.3) cands[nc++] = last_sh.price;
      if(ema50 > 0 && ema50 > close + atr * 0.3 && nc < 4)       cands[nc++] = ema50;
      if(ema20 > 0 && ema20 > close + atr * 0.3 && nc < 4)       cands[nc++] = ema20;
      for(int i = 0; i < sr_n && nc < 4; i++)
         if(sr[i].is_res && sr[i].price > close + atr * 0.3) { cands[nc++] = sr[i].price; break; }
      if(nc == 0) { s.reason = "No supply zone found"; return s; }

      double best = cands[0]; string rlbl = "Resistance";
      for(int i = 1; i < nc; i++)
         if(cands[i] > 0 && cands[i] < best && cands[i] > close) best = cands[i];
      if(MathAbs(best - last_sh.price) < _Point * 10) rlbl = "Last SH";
      else if(MathAbs(best - ema50) < _Point * 10)    rlbl = "EMA 50";
      else if(MathAbs(best - ema20) < _Point * 10)    rlbl = "EMA 20";

      double sl_price = best + atr * InpSLBufferATR;
      double tp = 0; bool has_external_tp = false;
      for(int i = 0; i < sr_n; i++)
         if(!sr[i].is_res && sr[i].price < close) { tp = sr[i].price; has_external_tp = true; break; }
      for(int i = 0; i < pool_n; i++)
         if(!pools[i].buy_side && pools[i].price < close)
            if(tp == 0 || pools[i].price > tp) { tp = pools[i].price; has_external_tp = true; }
      if(!has_external_tp || tp <= 0) { s.reason = "No external liquidity target"; return s; }

      double risk = sl_price - best, reward = best - tp;
      if(risk <= 0.0 || reward <= 0.0) { s.reason = "Invalid bearish risk profile"; return s; }
      string struct_lbl_s = structure; StringReplace(struct_lbl_s, "_", " ");
      s.type = "SELL_LIMIT"; s.entry = best; s.sl = sl_price; s.tp = tp;
      s.rr = reward / risk; s.reason = struct_lbl_s + " + " + rlbl;
   }
   else
   {
      s.reason = "No confluence: " + ShortBias(s.bias);
   }

   if(s.type != "NONE" && s.rr < InpMinRR)
   {
      s.reason = "R:R too low (" + DoubleToString(s.rr, 2) + " < " + DoubleToString(InpMinRR, 1) + ") - wait";
      s.type   = "NONE";
   }
   return s;
}

// ─── Drawing ─────────────────────────────────────────────────────────────────

string ZoneType(const SRLvl &z)
{
   bool from_high = (z.high_cnt >= z.low_cnt);
   if(z.is_res  && !from_high) return "Turncoat Resistance";
   if(!z.is_res && from_high)  return "Turncoat Support";
   if(z.strength == 1) return z.is_res ? "Untested Resistance" : "Untested Support";
   if(z.strength <= 3) return z.is_res ? "Verified Resistance" : "Verified Support";
   return                      z.is_res ? "Weak Resistance"     : "Weak Support";
}

void ZoneColors(const string zt, color &bdr, color &fill)
{
   if(zt == "Untested Resistance")  { bdr = C'220,40,40';  fill = C'170,20,20';  return; }
   if(zt == "Verified Resistance")  { bdr = C'210,70,50';  fill = C'160,45,30';  return; }
   if(zt == "Weak Resistance")      { bdr = C'180,100,80'; fill = C'130,65,50';  return; }
   if(zt == "Turncoat Resistance")  { bdr = C'220,130,30'; fill = C'170,95,15';  return; }
   if(zt == "Untested Support")     { bdr = C'40,80,220';  fill = C'20,50,175';  return; }
   if(zt == "Verified Support")     { bdr = C'55,110,205'; fill = C'30,75,160';  return; }
   if(zt == "Weak Support")         { bdr = C'75,140,185'; fill = C'50,100,145'; return; }
   if(zt == "Turncoat Support")     { bdr = C'30,190,130'; fill = C'15,145,95';  return; }
   bdr = clrGray; fill = C'50,50,50';
}

string ProbabilityLabel(const int quality)
{
   if(quality >= 80) return "HIGH";
   if(quality >= 55) return "MED";
   return "LOW";
}

color ProbabilityColor(const int quality)
{
   if(quality >= 80) return C'79,211,113';
   if(quality >= 55) return C'212,170,96';
   return C'225,95,74';
}

int ClampInt(const int value, const int lo, const int hi)
{
   if(value < lo) return lo;
   if(value > hi) return hi;
   return value;
}

string UpperText(string value)
{
   StringToUpper(value);
   return value;
}

bool TextHas(const string value, const string needle)
{
   string lhs = value; string rhs = needle;
   StringToUpper(lhs); StringToUpper(rhs);
   return StringFind(lhs, rhs) >= 0;
}

string ShortText(const string value, const int max_len)
{
   if(max_len <= 3) return value;
   if((int)StringLen(value) <= max_len) return value;
   return StringSubstr(value, 0, max_len - 3) + "...";
}

string BiasHeadline(const string bias)
{
   if(StringFind(bias, "Bull") >= 0) return "BULLISH";
   if(StringFind(bias, "Bear") >= 0) return "BEARISH";
   return "NEUTRAL";
}

string StructureHeadline(const string structure)
{
   if(structure == "CHoCH_Bull") return "CHOCH BULL";
   if(structure == "CHoCH_Bear") return "CHOCH BEAR";
   if(structure == "Bullish")    return "HH / HL";
   if(structure == "Bearish")    return "LH / LL";
   return "RANGING";
}

string SentimentHeadline(const int buy_pct, const int sell_pct)
{
   if(sell_pct >= buy_pct + 15) return "Bearish Dominance";
   if(buy_pct  >= sell_pct + 15) return "Bullish Dominance";
   return "Balanced Flow";
}

string TradePanelTitle(const string decision)
{
   if(decision == "Buy")     return "BUY SETUP";
   if(decision == "Sell")    return "SELL SETUP";
   if(decision == "Wait")    return "WAIT STATE";
   if(decision == "Standby") return "STANDBY";
   if(decision == "Avoid")   return "STAND ASIDE";
   return "TRADE SETUP";
}

void DrawProgressBar(const string id, const int x, const int y, const int w, const int h,
                     const int pct, const color fill, const color bg, const color border)
{
   int safe_pct = ClampInt(pct, 0, 100);
   int inner_w  = MathMax(2, w - 4);
   int fill_w   = MathMax(2, (inner_w * safe_pct) / 100);
   DrawRect(id + "_BG", x, y, w, h, bg, border);
   DrawRect(id + "_FG", x + 2, y + 2, fill_w, MathMax(2, h - 4), fill, fill);
}

void DrawSR(SRLvl &sr[], int sr_n, double current_price)
{
   ClearObjs(g_pfx + "SR_");
   if(!InpShowSR) return;

   double   atr     = GetATR();
   double   half    = atr * 0.13;
   int      rs = 0, ss = 0;
   datetime t_right = TimeCurrent() + (datetime)(PeriodSeconds(_Period) * 20);

   for(int i = 0; i < sr_n; i++)
   {
      if(sr[i].is_res  && rs >= InpMaxSR) continue;
      if(!sr[i].is_res && ss >= InpMaxSR) continue;
      if(sr[i].is_res) rs++; else ss++;

      string zt = ZoneType(sr[i]);
      if(StringFind(zt, "Weak") >= 0)     continue;
      if(StringFind(zt, "Turncoat") >= 0) continue;
      color  bdr, fill;
      ZoneColors(zt, bdr, fill);

      double top      = sr[i].price + half;
      double bot      = sr[i].price - half;
      string id       = "SR_" + IntegerToString(i);
      datetime t_left = sr[i].origin_time;

      string bname = g_pfx + id + "_BOX";
      if(ObjectFind(0, bname) < 0)
         ObjectCreate(0, bname, OBJ_RECTANGLE, 0, t_left, top, t_right, bot);
      ObjectSetInteger(0, bname, OBJPROP_TIME,  0, t_left);
      ObjectSetDouble(0,  bname, OBJPROP_PRICE, 0, top);
      ObjectSetInteger(0, bname, OBJPROP_TIME,  1, t_right);
      ObjectSetDouble(0,  bname, OBJPROP_PRICE, 1, bot);
      ObjectSetInteger(0, bname, OBJPROP_COLOR, (color)ColorToARGB(fill, 38));
      ObjectSetInteger(0, bname, OBJPROP_FILL,  true);
      ObjectSetInteger(0, bname, OBJPROP_BACK,  true);
      ObjectSetInteger(0, bname, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, bname, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, bname, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bname, OBJPROP_HIDDEN, false);

      double edge  = sr[i].is_res ? top : bot;
      string ename = g_pfx + id + "_EDGE";
      if(ObjectFind(0, ename) < 0)
         ObjectCreate(0, ename, OBJ_HLINE, 0, 0, edge);
      ObjectSetDouble(0,  ename, OBJPROP_PRICE, edge);
      ObjectSetInteger(0, ename, OBJPROP_COLOR, (color)ColorToARGB(bdr, 160));
      ObjectSetInteger(0, ename, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, ename, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, ename, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ename, OBJPROP_HIDDEN, false);
   }
}

void DrawStructure(SwingPt &swings[], int n)
{
   ClearObjs(g_pfx + "STR_");
   if(!InpShowStructure) return;

   SwingPt hs[], ls[];
   int nh = 0, nl = 0;
   for(int i = 0; i < n && i < 20; i++)
   {
      if(swings[i].is_high) { ArrayResize(hs, nh + 1); hs[nh++] = swings[i]; }
      else                  { ArrayResize(ls, nl + 1); ls[nl++]  = swings[i]; }
   }
   double atr_off = GetATR() * 0.25;

   for(int i = 0; i < MathMin(nh - 1, 3); i++)
   {
      string lbl = (hs[i].price > hs[i + 1].price) ? "HH" : "LH";
      color  clr = (hs[i].price > hs[i + 1].price) ? C'80,210,80' : C'220,90,60';
      SetText("STR_H" + IntegerToString(i), lbl, hs[i].time,
              hs[i].price + atr_off, clr, 8, ANCHOR_LOWER, true);
   }
   for(int i = 0; i < MathMin(nl - 1, 3); i++)
   {
      string lbl = (ls[i].price > ls[i + 1].price) ? "HL" : "LL";
      color  clr = (ls[i].price > ls[i + 1].price) ? C'80,210,80' : C'220,90,60';
      SetText("STR_L" + IntegerToString(i), lbl, ls[i].time,
              ls[i].price - atr_off, clr, 8, ANCHOR_UPPER, true);
   }
}

void DrawLiquidity(LiqPool &pools[], int n)
{
   ClearObjs(g_pfx + "LIQ_");
   if(!InpShowLiquidity || n == 0) return;

   int bsl_cnt = 0, ssl_cnt = 0;
   for(int i = 0; i < n; i++)
   {
      string id  = "LIQ_" + IntegerToString(i);
      bool   bsl = pools[i].buy_side;
      if(bsl && bsl_cnt >= 1) continue;
      if(!bsl && ssl_cnt >= 1) continue;
      if(bsl) bsl_cnt++; else ssl_cnt++;
      color  clr = bsl ? C'220,180,50' : C'80,180,220';
      string lbl = bsl ? "BSL" : "SSL";
      SetHLine(id, pools[i].price, clr, STYLE_DOT, 1);
      datetime t = TimeCurrent() + (datetime)(PeriodSeconds(_Period) * 5);
      SetText(id + "_T", lbl, t, pools[i].price, clr, 7, ANCHOR_LEFT, false);
   }
}

void DrawEntryZone(const TradingSetup &setup)
{
   ClearObjs(g_pfx + "EZ_");
   if(setup.type == "NONE") return;

   bool   is_buy = (setup.type == "BUY_LIMIT");
   color  ec     = is_buy ? C'90,235,120' : C'245,104,78';
   color  sc     = C'255,110,95';
   color  tc     = C'98,226,126';
   datetime now  = TimeCurrent();
   int step      = PeriodSeconds(_Period);
   datetime t1   = now - (datetime)(step * 2);
   datetime t2   = now + (datetime)(step * 18);
   datetime t3   = now + (datetime)(step * 28);
   double risk   = MathAbs(setup.entry - setup.sl);
   double tp2    = is_buy ? (setup.entry + risk * 2.0) : (setup.entry - risk * 2.0);
   double tp3    = is_buy ? (setup.entry + risk * 3.0) : (setup.entry - risk * 3.0);
   double zone_h = MathMax(risk * 0.35, _Point * 40);
   double zone_top = setup.entry + zone_h;
   double zone_bot = setup.entry - zone_h;
   string zone_title = is_buy ? "BUY ZONE" : "SELL ZONE";

   SetHLine("EZ_ENTRY", setup.entry, ec, STYLE_DASH, 1);
   SetHLine("EZ_SL",    setup.sl,    sc, STYLE_DASH, 1);
   SetHLine("EZ_TP1",   setup.tp,    tc, STYLE_DASH, 1);
   SetHLine("EZ_TP2",   tp2,         tc, STYLE_DOT,  1);
   SetHLine("EZ_TP3",   tp3,         tc, STYLE_DOT,  1);

   string bn = g_pfx + "EZ_ZONE";
   if(ObjectFind(0, bn) < 0) ObjectCreate(0, bn, OBJ_RECTANGLE, 0, t1, zone_top, t2, zone_bot);
   ObjectSetInteger(0, bn, OBJPROP_TIME,  0, t1);  ObjectSetDouble(0, bn, OBJPROP_PRICE, 0, zone_top);
   ObjectSetInteger(0, bn, OBJPROP_TIME,  1, t2);  ObjectSetDouble(0, bn, OBJPROP_PRICE, 1, zone_bot);
   ObjectSetInteger(0, bn, OBJPROP_COLOR, (color)ColorToARGB(ec, 42));
   ObjectSetInteger(0, bn, OBJPROP_FILL, true); ObjectSetInteger(0, bn, OBJPROP_BACK, true);
   ObjectSetInteger(0, bn, OBJPROP_STYLE, STYLE_SOLID); ObjectSetInteger(0, bn, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bn, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, bn, OBJPROP_HIDDEN, false);

   string rn = g_pfx + "EZ_RISK";
   if(ObjectFind(0, rn) < 0) ObjectCreate(0, rn, OBJ_RECTANGLE, 0, t1, setup.entry, t3, setup.sl);
   ObjectSetInteger(0, rn, OBJPROP_TIME,  0, t1);  ObjectSetDouble(0, rn, OBJPROP_PRICE, 0, setup.entry);
   ObjectSetInteger(0, rn, OBJPROP_TIME,  1, t3);  ObjectSetDouble(0, rn, OBJPROP_PRICE, 1, setup.sl);
   ObjectSetInteger(0, rn, OBJPROP_COLOR, (color)ColorToARGB(sc, 28));
   ObjectSetInteger(0, rn, OBJPROP_FILL, true); ObjectSetInteger(0, rn, OBJPROP_BACK, true);
   ObjectSetInteger(0, rn, OBJPROP_STYLE, STYLE_SOLID); ObjectSetInteger(0, rn, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, rn, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, rn, OBJPROP_HIDDEN, false);

   string wn = g_pfx + "EZ_REWARD";
   if(ObjectFind(0, wn) < 0) ObjectCreate(0, wn, OBJ_RECTANGLE, 0, t1, setup.entry, t3, setup.tp);
   ObjectSetInteger(0, wn, OBJPROP_TIME,  0, t1);  ObjectSetDouble(0, wn, OBJPROP_PRICE, 0, setup.entry);
   ObjectSetInteger(0, wn, OBJPROP_TIME,  1, t3);  ObjectSetDouble(0, wn, OBJPROP_PRICE, 1, setup.tp);
   ObjectSetInteger(0, wn, OBJPROP_COLOR, (color)ColorToARGB(tc, 24));
   ObjectSetInteger(0, wn, OBJPROP_FILL, true); ObjectSetInteger(0, wn, OBJPROP_BACK, true);
   ObjectSetInteger(0, wn, OBJPROP_STYLE, STYLE_SOLID); ObjectSetInteger(0, wn, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, wn, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, wn, OBJPROP_HIDDEN, false);

   double hdr_y = is_buy ? (zone_top + risk * 0.12) : (zone_bot - risk * 0.10);
   SetText("EZ_HDR", "[" + zone_title + "]", t1 + (datetime)(step * 1), hdr_y, ec, 8,
           is_buy ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER, true);

   SetText("EZ_L1", "ENTRY " + DoubleToString(setup.entry, _Digits), t3, setup.entry, ec, 8, ANCHOR_LEFT, true);
   SetText("EZ_L2", "SL "    + DoubleToString(setup.sl, _Digits),    t3, setup.sl,    sc, 8, ANCHOR_LEFT, true);
   SetText("EZ_L3", "TP1 "   + DoubleToString(setup.tp, _Digits),    t3, setup.tp,    tc, 8, ANCHOR_LEFT, true);
   SetText("EZ_L4", "TP2 "   + DoubleToString(tp2, _Digits),         t3, tp2,         tc, 7, ANCHOR_LEFT, true);
   SetText("EZ_L5", "TP3 "   + DoubleToString(tp3, _Digits),         t3, tp3,         tc, 7, ANCHOR_LEFT, true);
}

string BiasBadge(const string bias)
{
   if(StringFind(bias, "Bull") >= 0) return "Bullish Bias";
   if(StringFind(bias, "Bear") >= 0) return "Bearish Bias";
   return "Balanced Bias";
}

string ShortBias(const string bias)
{
   if(bias == "Strong Bullish") return "Str Bull";
   if(bias == "Weak Bullish")   return "Wk Bull";
   if(bias == "Strong Bearish") return "Str Bear";
   if(bias == "Weak Bearish")   return "Wk Bear";
   return bias;
}

color BiasColor(const string bias)
{
   if(bias == "Strong Bullish") return C'70,210,80';
   if(bias == "Weak Bullish")   return C'110,175,110';
   if(bias == "Strong Bearish") return C'225,75,55';
   if(bias == "Weak Bearish")   return C'205,145,75';
   return clrSilver;
}

string GetConfluence(const string b1, const string b2, const string b3)
{
   int bulls = 0, bears = 0;
   string arr[3]; arr[0] = b1; arr[1] = b2; arr[2] = b3;
   for(int i = 0; i < 3; i++)
   {
      if(StringFind(arr[i], "Bull") >= 0) bulls++;
      else if(StringFind(arr[i], "Bear") >= 0) bears++;
   }
   if(bears == 3) return "STRONG SELL   3/3";
   if(bulls == 3) return "STRONG BUY    3/3";
   if(bears == 2) return "MODERATE SELL 2/3";
   if(bulls == 2) return "MODERATE BUY  2/3";
   return "MIXED - WAIT";
}

int GetConfluenceScore(const string b1, const string b2, const string b3)
{
   int bulls = 0, bears = 0;
   string arr[3]; arr[0] = b1; arr[1] = b2; arr[2] = b3;
   for(int i = 0; i < 3; i++)
   {
      if(StringFind(arr[i], "Bull") >= 0) bulls++;
      else if(StringFind(arr[i], "Bear") >= 0) bears++;
   }
   if(bulls == 3 || bears == 3) return 9;
   if(bulls == 2 || bears == 2) return 6;
   return 3;
}

string ConfidenceLabel(const int score)
{
   if(score >= 9) return "High Confidence";
   if(score >= 6) return "Developing Confidence";
   return "Low Confidence";
}

string TradeDecision(const TradingSetup &s, const int score)
{
   if(s.type == "BUY_LIMIT")  return (score >= 6) ? "Buy" : "Wait";
   if(s.type == "SELL_LIMIT") return (score >= 6) ? "Sell" : "Wait";
   if(TextHas(s.reason, "WAIT"))       return "Wait";
   if(TextHas(s.reason, "SESSION"))    return "Standby";
   if(TextHas(s.reason, "VOLATILITY")) return "Standby";
   if(TextHas(s.reason, "LIQUIDITY"))  return "Standby";
   return (score >= 6) ? "Standby" : "Avoid";
}

string VolatilityLabel(const double atr, const double price)
{
   if(price <= 0.0) return "Normal volatility";
   double pct = (atr / price) * 100.0;
   if(pct >= 1.00) return "High volatility";
   if(pct >= 0.45) return "Normal volatility";
   return "Compressed volatility";
}

int NthWeekday(int year, int mon, int weekday, int n)
{
   MqlDateTime dt; ZeroMemory(dt);
   dt.year = year; dt.mon = mon; dt.day = 1;
   MqlDateTime tmp;
   TimeToStruct(StructToTime(dt), tmp);
   return 1 + ((weekday - (int)tmp.day_of_week + 7) % 7) + (n - 1) * 7;
}

int LastWeekdayOfMonth(int year, int mon, int weekday)
{
   static int days[13] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
   int d = days[mon];
   if(mon == 2 && (year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))) d = 29;
   MqlDateTime dt; ZeroMemory(dt);
   dt.year = year; dt.mon = mon; dt.day = d;
   MqlDateTime tmp;
   TimeToStruct(StructToTime(dt), tmp);
   return d - (int)((tmp.day_of_week - weekday + 7) % 7);
}

bool IsUsDst(const MqlDateTime &gmt)
{
   if(gmt.mon < 3 || gmt.mon > 11) return false;
   if(gmt.mon > 3 && gmt.mon < 11) return true;
   if(gmt.mon == 3)
   {
      int spring = NthWeekday(gmt.year, 3, 0, 2);
      return gmt.day > spring || (gmt.day == spring && gmt.hour >= 7);
   }
   int fall = NthWeekday(gmt.year, 11, 0, 1);
   return gmt.day < fall || (gmt.day == fall && gmt.hour < 6);
}

bool IsUkDst(const MqlDateTime &gmt)
{
   if(gmt.mon < 3 || gmt.mon > 10) return false;
   if(gmt.mon > 3 && gmt.mon < 10) return true;
   if(gmt.mon == 3)
   {
      int spring = LastWeekdayOfMonth(gmt.year, 3, 0);
      return gmt.day > spring || (gmt.day == spring && gmt.hour >= 1);
   }
   int fall = LastWeekdayOfMonth(gmt.year, 10, 0);
   return gmt.day < fall || (gmt.day == fall && gmt.hour < 1);
}

string SessionStatus()
{
   MqlDateTime gmt;
   TimeToStruct(TimeGMT(), gmt);
   int mins = gmt.hour * 60 + gmt.min;
   int london_open  = IsUkDst(gmt) ? 6 * 60  : 7 * 60;
   int london_close = IsUkDst(gmt) ? 15 * 60 : 16 * 60;
   int ny_open      = IsUsDst(gmt) ? 12 * 60 : 13 * 60;
   int ny_close     = IsUsDst(gmt) ? 20 * 60 : 21 * 60;
   bool sydney = (mins >= 21 * 60 || mins < 6 * 60);
   bool tokyo  = (mins >= 0 && mins < 9 * 60);
   bool london = (mins >= london_open  && mins < london_close);
   bool ny     = (mins >= ny_open && mins < ny_close);
   if(london && ny)    return "London / New York overlap";
   if(tokyo && london) return "Asia / London transition";
   if(ny)              return "New York session";
   if(london)          return "London session";
   if(tokyo)           return "Asian session";
   if(sydney)          return "Pacific session";
   return "Session transition";
}

string LotSizeEst(const TradingSetup &setup)
{
   if(setup.type == "NONE" || setup.sl <= 0.0 || setup.entry <= 0.0) return "--";
   double sl_dist = MathAbs(setup.entry - setup.sl);
   if(sl_dist <= 0.0) return "--";
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_pct  = (InpAccountRisk > 0.0) ? InpAccountRisk : InpRiskPct;
   double risk_cash = balance * risk_pct / 100.0;
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_val  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_size <= 0.0 || tick_val <= 0.0 || balance <= 0.0) return "--";
   double lots = risk_cash / ((sl_dist / tick_size) * tick_val);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step > 0.0) lots = MathFloor(lots / step) * step;
   if(lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return "< min";
   return DoubleToString(lots, 2);
}

int QualityPercent(const TradingSetup &s, const int score)
{
   if(s.type == "NONE")
   {
      int idle = score * 7;
      if(TextHas(s.reason, "WAIT")) idle = MathMin(idle, 45);
      else                          idle = MathMin(idle, 28);
      if(idle < 5) idle = 5;
      return idle;
   }
   int pct = score * 10;
   if(s.rr >= 2.0) pct += 8;
   else if(s.rr >= 1.5) pct += 4;
   if(StringFind(s.structure, "Bullish") >= 0 || StringFind(s.structure, "Bearish") >= 0) pct += 2;
   if(pct > 99) pct = 99;
   if(pct < 20) pct = 20;
   return pct;
}

string SetupStatus(const TradingSetup &s, const int score)
{
   if(s.type == "NONE")
   {
      if(TextHas(s.reason, "DISCOUNT") || TextHas(s.reason, "PREMIUM")) return "Wait For Pullback";
      if(TextHas(s.reason, "SESSION"))    return "Wait For Session";
      if(TextHas(s.reason, "VOLATILITY")) return "Wait For Volatility";
      if(TextHas(s.reason, "LIQUIDITY"))  return "Need Liquidity";
      return (score >= 6) ? "Standby Filtered" : "Stand Aside";
   }
   if(score >= 8) return "Primary Setup";
   if(score >= 5) return "Developing Setup";
   return "Monitor Only";
}

double CalcEMA(MqlRates &rates[], int n, int period)
{
   if(n < MinBarsForEMA(period)) return 0.0;
   double ema = 0.0;
   for(int i = n - 1; i >= n - period; i--) ema += rates[i].close;
   ema /= period;
   double k = 2.0 / (period + 1.0);
   for(int i = n - period - 1; i >= 1; i--)
      ema = rates[i].close * k + ema * (1.0 - k);
   return ema;
}

void GetHigherTFs(ENUM_TIMEFRAMES &tf1, ENUM_TIMEFRAMES &tf2)
{
   switch(_Period)
   {
      case PERIOD_M1:  tf1 = PERIOD_M15; tf2 = PERIOD_H1;  break;
      case PERIOD_M5:  tf1 = PERIOD_H1;  tf2 = PERIOD_H4;  break;
      case PERIOD_M15: tf1 = PERIOD_H1;  tf2 = PERIOD_H4;  break;
      case PERIOD_M30: tf1 = PERIOD_H4;  tf2 = PERIOD_D1;  break;
      case PERIOD_H1:  tf1 = PERIOD_H4;  tf2 = PERIOD_D1;  break;
      case PERIOD_H4:  tf1 = PERIOD_D1;  tf2 = PERIOD_W1;  break;
      default:         tf1 = PERIOD_H1;  tf2 = PERIOD_H4;  break;
   }
}

TFSummary AnalyzeTF(ENUM_TIMEFRAMES tf)
{
   TFSummary s;
   s.label = TFLabel(tf); s.bias = "N/A"; s.structure = "-";
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(_Symbol, tf, 0, 250, rates);
   if(n < MinBarsForEMA(200)) return s;
   double close  = rates[1].close;
   double ema20  = CalcEMA(rates, n, 20);
   double ema50  = CalcEMA(rates, n, 50);
   double ema200 = CalcEMA(rates, n, 200);
   bool ab20  = ema20  > 0 && close > ema20;
   bool ab50  = ema50  > 0 && close > ema50;
   bool ab200 = ema200 > 0 && close > ema200;
   s.bias = ClassifyBias(ab20, ab50, ab200);
   SwingPt swings[];
   int sw_n = CollectSwings(rates, n, swings);
   SwingPt lsh, lsl, psh, psl;
   s.structure = AnalyzeStructure(swings, sw_n, lsh, lsl, psh, psl, close);
   return s;
}

void DrawPanelV2(const TradingSetup &s, const TFSummary &htf2, const TFSummary &htf1,
                 const double atr, const double close, const int pool_n, const int sr_n)
{
   ClearObjs(g_pfx + "PNL_");

   bool  has    = (s.type != "NONE");
   bool  buy    = (s.type == "BUY_LIMIT");
   color bull_c = C'79,211,113';
   color bear_c = C'225,95,74';
   color blue_c = C'86,174,255';
   color gold_c = C'212,170,96';
   color grey_c = C'126,136,156';
   color text_c = C'227,232,242';
   color muted  = C'120,131,171';
   color bg0    = C'8,10,18';
   color bg1    = C'12,16,27';
   color bg2    = C'15,21,34';
   color brd    = C'28,34,54';
   color accent = has ? (buy ? bull_c : bear_c) : grey_c;

   int    score        = GetConfluenceScore(htf2.bias, htf1.bias, s.bias);
   int    quality      = QualityPercent(s, score);
   string setup_status = SetupStatus(s, score);
   string decision     = TradeDecision(s, score);
   string volatility   = VolatilityLabel(atr, close);
   string session      = SessionStatus();
   bool   aligned      = (score >= 6);
   color  score_color  = (score >= 9) ? bull_c : (score >= 6) ? gold_c : bear_c;

   int bear_tfs = 0, bull_tfs = 0;
   if(StringFind(htf2.bias,"Bear") >= 0) bear_tfs++; else if(StringFind(htf2.bias,"Bull") >= 0) bull_tfs++;
   if(StringFind(htf1.bias,"Bear") >= 0) bear_tfs++; else if(StringFind(htf1.bias,"Bull") >= 0) bull_tfs++;
   if(StringFind(s.bias,"Bear")    >= 0) bear_tfs++; else if(StringFind(s.bias,"Bull")    >= 0) bull_tfs++;
   int active_tfs = bear_tfs + bull_tfs;

   string cons_bias = (bear_tfs > bull_tfs) ? ((bear_tfs == 3) ? "Strong Bearish" : "Weak Bearish") :
                      (bull_tfs > bear_tfs) ? ((bull_tfs == 3) ? "Strong Bullish" : "Weak Bullish") : "Neutral";
   color  cons_color = BiasColor(cons_bias);
   int buy_pct  = active_tfs > 0 ? ClampInt((int)MathRound((double)bull_tfs * 100.0 / active_tfs), 0, 100) : 50;
   int sell_pct = active_tfs > 0 ? ClampInt((int)MathRound((double)bear_tfs * 100.0 / active_tfs), 0, 100) : 50;

   double risk   = has ? MathAbs(s.entry - s.sl) : 0.0;
   double tp2val = has ? (buy ? s.entry + risk * 2.0 : s.entry - risk * 2.0) : 0.0;
   string entry_s = has ? DoubleToString(s.entry, _Digits) : "--";
   string sl_s    = has ? DoubleToString(s.sl, _Digits)    : "--";
   string tp1_s   = has ? DoubleToString(s.tp, _Digits) + " (" + DoubleToString(s.rr, 1) + "R)" : "--";
   string tp2_s   = has ? DoubleToString(tp2val, _Digits)  : "--";
   string rr_s    = has ? "1:" + DoubleToString(s.rr, 1)  : "--";
   double ema50v  = GetEMAVal(h_ema50, 1);

   bool htf2_valid = StringFind(htf2.bias,"Bull") >= 0 || StringFind(htf2.bias,"Bear") >= 0;
   bool htf_ok = htf2_valid ?
                 ((StringFind(htf2.bias,"Bull") >= 0 && StringFind(s.bias,"Bull") >= 0) ||
                  (StringFind(htf2.bias,"Bear") >= 0 && StringFind(s.bias,"Bear") >= 0)) :
                 ((StringFind(htf1.bias,"Bull") >= 0 && StringFind(s.bias,"Bull") >= 0) ||
                  (StringFind(htf1.bias,"Bear") >= 0 && StringFind(s.bias,"Bear") >= 0));

   bool bias_bear = StringFind(s.bias, "Bear") >= 0;
   bool bias_bull = StringFind(s.bias, "Bull") >= 0;
   bool bos_ok = (bias_bull && (s.structure == "Bullish" || s.structure == "CHoCH_Bull")) ||
                 (bias_bear && (s.structure == "Bearish" || s.structure == "CHoCH_Bear"));
   bool prd_ok = has ? (buy ? (close <= ema50v + atr * 0.15) : (close >= ema50v - atr * 0.15))
                     : (bias_bear ? (close > ema50v) : (bias_bull ? (close <= ema50v) : false));
   bool vol_ok = StringFind(volatility, "Normal") >= 0;
   bool ses_ok = StringFind(session, "London") >= 0 || StringFind(session, "New York") >= 0 ||
                 StringFind(session, "overlap") >= 0;
   string risk_status = (score >= 6 && vol_ok && ses_ok) ? "OPTIMAL" :
                        (score >= 6) ? "CAUTION" : "STANDBY";
   color  risk_clr = (risk_status == "OPTIMAL") ? bull_c :
                     (risk_status == "CAUTION") ? gold_c : bear_c;
   string sess_lbl = StringFind(session, "overlap") >= 0  ? "LDN / NEW YORK" :
                     StringFind(session, "London") >= 0   ? "LONDON" :
                     StringFind(session, "New York") >= 0 ? "NEW YORK" :
                     StringFind(session, "Asian") >= 0    ? "ASIA" :
                     StringFind(session, "Pacific") >= 0  ? "SYDNEY" : "TRANSITION";
   color  sess_clr = ses_ok ? blue_c :
                     (StringFind(session, "Asian") >= 0 ? C'104,190,166' : gold_c);
   int    vol_ratio = GetVolumeRatio();
   string vol_tick_lbl = vol_ratio >= 150 ? "EXPANDING" : vol_ratio >= 70 ? "BALANCED" : "THIN";
   bool   vol_tick_ok  = (vol_ratio >= 70);
   color  vol_tick_clr = vol_ratio >= 150 ? gold_c : vol_tick_ok ? blue_c : bear_c;
   string lot_s        = LotSizeEst(s);

   int factor_hits = 0;
   if(htf_ok)  factor_hits++;
   if(aligned) factor_hits++;
   if(bos_ok)  factor_hits++;
   if(prd_ok)  factor_hits++;
   if(ses_ok)  factor_hits++;
   if(vol_ok)  factor_hits++;
   int confluence_score = ClampInt((int)MathRound((double)factor_hits * 100.0 / 6.0), 0, 100);
   string bias_head = BiasHeadline(cons_bias);
   string signal_head = UpperText(decision);
   string market_sent = SentimentHeadline(buy_pct, sell_pct);
   int sentiment_pct = MathMax(buy_pct, sell_pct);
   color sentiment_clr = sell_pct > buy_pct ? bear_c : buy_pct > sell_pct ? bull_c : blue_c;
   bool   in_premium    = (close > ema50v);
   bool   zone_conflict = has && ((buy && in_premium) || (!buy && !in_premium));
   string zone_state    = (in_premium ? "PREMIUM" : "DISCOUNT") + (zone_conflict ? " (!)" : "");
   color  zone_clr      = zone_conflict ? bear_c : (in_premium ? gold_c : blue_c);
   string structure_head = StructureHeadline(s.structure);
   string setup_title     = TradePanelTitle(decision);
   string signal_status   = has ? (quality >= 80 ? "CONFIRMED" : score >= 6 ? "ACTIVE" : "WAIT")
                                : ShortText(UpperText(SetupStatus(s, score)), 16);
   string confluence_lbl  = confluence_score >= 80 ? "HIGH PROB" :
                            confluence_score >= 60 ? "BUILDING" : "CAUTION";
   string tf_stack        = htf2.label + " / " + htf1.label + " / " + TFLabel(_Period);
   string session_box     = ShortText(sess_lbl, 16);
   string tp_box          = has ? ShortText(tp1_s, 13) : "--";
   string reason_line     = StringLen(s.reason) > 0 ? ShortText(s.reason, 24) : "No setup available";
   string setup_headline  = has ? setup_title : "NO ACTIVE SETUP";
   string setup_subline   = has ? signal_status : "Conditions not aligned";
   string tf_box          = ShortText(tf_stack, 14);
   int    trend_strength  = MathMax(buy_pct, sell_pct);
   string trend_label     = (sell_pct > buy_pct) ? "BEARISH TREND" : (buy_pct > sell_pct) ? "BULLISH TREND" : "BALANCED";
   string cf1             = (htf_ok ? "[OK] " : "[  ] ") + "HTF Trend";
   string cf2             = (bos_ok ? "[OK] " : "[  ] ") + "BOS / CHOCH";
   string cf3             = (pool_n > 0 ? "[OK] " : "[  ] ") + "Liquidity";
   string cf4             = (prd_ok ? "[OK] " : "[  ] ") + zone_state;
   string cf5             = (ses_ok ? "[OK] " : "[  ] ") + "Session";
   color  setup_head_clr  = has ? accent : text_c;
   color  status_clr      = has ? accent : gold_c;

   DrawRect("BG",      -8,  -8, 676, 516, bg0, brd);
   DrawRect("HEADER",   8,   8, 648, 112, bg1, brd);
   DrawRect("ACCENT",   8,   8,   5, 112, accent, accent);
   DrawRect("HDR_LINE", 8,  52, 648,  1, brd, brd);

   DrawRect("BADGE_BIAS",  24, 66, 118, 30, bg2, cons_color);
   color conf_clr = confluence_score >= 80 ? bull_c : confluence_score >= 60 ? gold_c : bear_c;
   DrawRect("BADGE_CONF", 150, 66,  88, 30, bg2, conf_clr);
   DrawRect("BADGE_SIG",  246, 66,  94, 30, bg2, accent);
   DrawRect("BADGE_SES",  348, 66, 308, 30, bg2, sess_clr);

   SetLabel("H0", "SUERTEFX SCANNER PRO  [TRIAL]", 24, 10, text_c, 11, true);
   SetLabel("H1", "Institutional Smart Money Scanner — 7-Day Free Trial", 24, 39, muted, 5, false);
   SetLabel("H2", TFLabel(_Period) + "  |  " + _Symbol, 516, 16, muted, 8, true);
   SetLabel("HB0", "BIAS",    34,  69, muted, 6, true);
   SetLabel("HB1", bias_head, 34,  80, cons_color, 7, true);
   SetLabel("HB2", "CONF",   160,  69, muted, 6, true);
   SetLabel("HB3", IntegerToString(confluence_score) + "%", 160, 80, conf_clr, 7, true);
   SetLabel("HB4", "SIGNAL", 256,  69, muted, 6, true);
   SetLabel("HB5", signal_head, 256, 80, accent, 7, true);
   SetLabel("HB6", "SESSION", 358, 69, muted, 6, true);
   SetLabel("HB7", session_box, 358, 80, sess_clr, 7, true);

   DrawRect("BIAS_CARD",    8, 132, 216, 164, bg1, brd);
   DrawRect("SETUP_CARD", 232, 132, 244, 164, bg1, brd);
   DrawRect("GAUGE_CARD", 484, 132, 172, 204, bg1, brd);
   DrawRect("CONF_CARD",    8, 306, 318, 186, bg1, brd);
   DrawRect("CTX_CARD",   338, 306, 318, 186, bg1, brd);

   SetLabel("B0", "MARKET BIAS", 24, 146, muted, 7, true);
   SetLabel("B1", bias_head, 24, 165, cons_color, 18, true);
   SetLabel("B2", structure_head, 24, 216, accent, 8, true);
   SetLabel("B3", zone_state, 24, 238, zone_clr, 8, true);
   string mtf_lbl = score >= 9 ? "Aligned" : score >= 6 ? "Building" : "Mixed";
   SetLabel("B4", "MTF Align", 24, 268, muted, 7, true);
   SetLabel("B5", mtf_lbl, 110, 268, score_color, 7, true);

   SetLabel("S0", setup_headline, 248, 148, setup_head_clr, has ? 13 : 10, true);
   SetLabel("S1", setup_subline, 248, 178, muted, 6, false);
   if(has)
   {
      SetLabel("S2",  "Entry",     248, 194, muted,   7, true);
      SetLabel("S3",  entry_s,     248, 216, text_c, 11, true);
      SetLabel("S4",  "Stop Loss", 346, 194, muted,   7, true);
      SetLabel("S5",  sl_s,        346, 216, bear_c, 11, true);
      SetLabel("S6",  "Take Profit",248, 244, muted,  7, true);
      SetLabel("S7",  tp_box,      248, 266, bull_c, 11, true);
      SetLabel("S8",  "RR",        346, 244, muted,   7, true);
      SetLabel("S9",  rr_s,        346, 266, blue_c, 11, true);
      SetLabel("S10", reason_line, 248, 282, muted,   6, false);
      SetLabel("S11", " ", 248, 198, muted, 7, false);
      SetLabel("S12", " ", 248, 220, muted, 7, false);
      SetLabel("S13", " ", 248, 248, muted, 7, false);
      SetLabel("S14", " ", 248, 270, muted, 7, false);
   }
   else
   {
      SetLabel("S2",  " ", 248, 194, muted, 7, false);
      SetLabel("S3",  " ", 248, 216, muted, 7, false);
      SetLabel("S4",  " ", 346, 194, muted, 7, false);
      SetLabel("S5",  " ", 346, 216, muted, 7, false);
      SetLabel("S6",  " ", 248, 244, muted, 7, false);
      SetLabel("S7",  " ", 248, 266, muted, 7, false);
      SetLabel("S8",  " ", 346, 244, muted, 7, false);
      SetLabel("S9",  " ", 346, 266, muted, 7, false);
      SetLabel("S10", " ", 248, 282, muted, 6, false);
      SetLabel("S11", "Status",    248, 198, muted,       7, true);
      SetLabel("S12", signal_status,248, 220, status_clr, 11, true);
      SetLabel("S13", "Blocked By", 248, 248, muted,      7, true);
      SetLabel("S14", reason_line,  248, 270, text_c,     8, false);
   }

   SetLabel("G0", "SYSTEM STRENGTH", 500, 146, muted, 7, true);
   SetLabel("G1", IntegerToString(confluence_score) + "%", 500, 162, conf_clr, 16, true);
   SetLabel("G2", "Confluence", 500, 204, muted, 7, true);
   DrawProgressBar("G_CONF",  500, 220, 132, 12, confluence_score, conf_clr,   bg2, brd);
   SetLabel("G3", "Setup Quality", 500, 246, muted, 7, true);
   DrawProgressBar("G_CONF2", 500, 262, 132, 12, quality,          score_color, bg2, brd);
   SetLabel("G4", "Trend", 500, 288, muted, 7, true);
   DrawProgressBar("G_TREND", 500, 304, 132, 12, trend_strength,   cons_color,  bg2, brd);

   SetLabel("C0", "CONFLUENCE CHECKLIST", 24, 320, muted, 7, true);
   SetLabel("C1", IntegerToString(confluence_score) + " / 100", 24, 348, text_c, 18, true);
   SetLabel("C2", confluence_lbl, 170, 352, score_color, 8, true);
   SetLabel("C3", cf1, 24,  386, htf_ok   ? bull_c : grey_c, 8, false);
   SetLabel("C4", cf2, 24,  410, bos_ok   ? bull_c : grey_c, 8, false);
   SetLabel("C5", cf3, 24,  434, pool_n>0 ? bull_c : grey_c, 8, false);
   SetLabel("C6", cf4, 182, 386, prd_ok   ? bull_c : grey_c, 8, false);
   SetLabel("C7", cf5, 182, 410, ses_ok   ? bull_c : grey_c, 8, false);

   SetLabel("X0", "MARKET CONTEXT", 354, 320, muted, 7, true);
   SetLabel("X1", trend_label,   354, 348, cons_color, 10, true);
   SetLabel("X2", "MTF",         354, 384, muted,       7, true);
   SetLabel("X3", tf_box,        398, 384, blue_c,      8, true);
   SetLabel("X4", "Risk",        354, 410, muted,       7, true);
   SetLabel("X5", risk_status,   398, 410, risk_clr,   10, true);
   SetLabel("X6", "Lot",         354, 436, muted,       7, true);
   SetLabel("X7", lot_s,         398, 436, text_c,      9, true);
   SetLabel("X8", "Session",     520, 384, muted,       7, true);
   SetLabel("X9", ses_ok ? "ACTIVE" : "QUIET", 520, 410, ses_ok ? bull_c : gold_c, 10, true);
}

// ─── Main analysis ────────────────────────────────────────────────────────────

void Analyze()
{
   TradingSetup blank;
   blank.type = "NONE"; blank.entry = 0; blank.sl = 0; blank.tp = 0; blank.rr = 0;
   blank.bias = "-"; blank.structure = "-"; blank.reason = "Waiting for data...";
   TFSummary blank_tf; blank_tf.label = "-"; blank_tf.bias = "N/A"; blank_tf.structure = "-";

   ENUM_TIMEFRAMES htf1_period, htf2_period;
   GetHigherTFs(htf1_period, htf2_period);
   TFSummary htf1 = AnalyzeTF(htf1_period);
   TFSummary htf2 = AnalyzeTF(htf2_period);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, InpLookback + InpPivotSpan * 2 + 20, rates);
   if(copied < InpPivotSpan * 2 + 10) { DrawPanelV2(blank, blank_tf, blank_tf, 0.0, 0.0, 0, 0); return; }

   double atr   = GetATR();
   double close = rates[1].close;
   double e20   = GetEMAVal(h_ema20,  1);
   double e50   = GetEMAVal(h_ema50,  1);
   double e200  = GetEMAVal(h_ema200, 1);

   SwingPt swings[];
   int sw_n = CollectSwings(rates, copied, swings);
   SRLvl sr[];
   int sr_n = BuildSR(swings, sw_n, atr, close, sr);
   SwingPt last_sh, last_sl, prev_sh, prev_sl;
   string structure = AnalyzeStructure(swings, sw_n, last_sh, last_sl, prev_sh, prev_sl, close);
   LiqPool pools[];
   int pool_n = FindLiquidity(swings, sw_n, atr, pools);

   TradingSetup setup = GenerateSetup(structure, close, atr,
                                      sr, sr_n, last_sh, last_sl, prev_sh, prev_sl,
                                      pools, pool_n, e20, e50, e200);

   string session    = SessionStatus();
   string volatility = VolatilityLabel(atr, close);
   bool ses_ok = StringFind(session, "London") >= 0 || StringFind(session, "New York") >= 0 ||
                 StringFind(session, "overlap") >= 0;
   bool vol_ok = StringFind(volatility, "Normal") >= 0;
   bool liq_ok = (pool_n > 0);

   if(setup.type != "NONE" && !liq_ok)  { setup.type = "NONE"; setup.reason = "No liquidity confluence"; }
   if(setup.type != "NONE" && !vol_ok)  { setup.type = "NONE"; setup.reason = "Wait for normal volatility"; }
   if(setup.type != "NONE" && !ses_ok)  { setup.type = "NONE"; setup.reason = "Wait for London/New York"; }

   DrawSR(sr, sr_n, close);
   DrawStructure(swings, sw_n);
   DrawLiquidity(pools, pool_n);
   DrawEntryZone(setup);
   DrawPanelV2(setup, htf2, htf1, atr, close, pool_n, sr_n);

   if(InpEnableAlerts && setup.type != "NONE")
   {
      datetime lb = iTime(_Symbol, _Period, 1);
      string sig = setup.type + "|" +
                   DoubleToString(setup.entry, _Digits) + "|" +
                   DoubleToString(setup.sl, _Digits) + "|" +
                   DoubleToString(setup.tp, _Digits);
      if(lb != g_last_alert_bar || sig != g_last_alert_sig)
      {
         Alert(_Symbol + " " + TFLabel(_Period) + " " + setup.type +
               " @ " + DoubleToString(setup.entry, _Digits) +
               "  SL " + DoubleToString(setup.sl, _Digits) +
               "  TP " + DoubleToString(setup.tp, _Digits) +
               "  R:R " + DoubleToString(setup.rr, 2));
         g_last_alert_sig = sig;
         g_last_alert_bar = lb;
      }
   }
}

// ─── Lifecycle ───────────────────────────────────────────────────────────────

int OnInit()
{
   if(!SFX_CheckTrial()) return INIT_FAILED;

   SetIndexBuffer(0, buf_ema20,  INDICATOR_DATA);
   SetIndexBuffer(1, buf_ema50,  INDICATOR_DATA);
   SetIndexBuffer(2, buf_ema200, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   if(!InpShowEMAs)
   {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
   }

   h_ema20  = iMA(_Symbol, _Period, InpEMA20,  0, MODE_EMA, PRICE_CLOSE);
   h_ema50  = iMA(_Symbol, _Period, InpEMA50,  0, MODE_EMA, PRICE_CLOSE);
   h_ema200 = iMA(_Symbol, _Period, InpEMA200, 0, MODE_EMA, PRICE_CLOSE);
   h_atr    = iATR(_Symbol, _Period, InpATRPeriod);

   if(h_ema20  == INVALID_HANDLE || h_ema50  == INVALID_HANDLE ||
      h_ema200 == INVALID_HANDLE || h_atr    == INVALID_HANDLE)
   { Print("SuerteFX Scanner: handle creation failed"); return INIT_FAILED; }

   IndicatorSetString(INDICATOR_SHORTNAME, "SuerteFX Scanner Pro [TRIAL]");
   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 10) return 0;

   int to_copy = (prev_calculated > 1) ? rates_total - prev_calculated + 2 : rates_total;
   to_copy = MathMax(to_copy, 1);

   if(InpShowEMAs && rates_total > InpEMA200)
   {
      double tmp[];
      ArraySetAsSeries(tmp, true);
      int c;

      c = CopyBuffer(h_ema20, 0, 0, to_copy, tmp);
      for(int i = 0; i < c && (rates_total - 1 - i) >= 0; i++)
         buf_ema20[rates_total - 1 - i] = tmp[i];

      c = CopyBuffer(h_ema50, 0, 0, to_copy, tmp);
      for(int i = 0; i < c && (rates_total - 1 - i) >= 0; i++)
         buf_ema50[rates_total - 1 - i] = tmp[i];

      c = CopyBuffer(h_ema200, 0, 0, to_copy, tmp);
      for(int i = 0; i < c && (rates_total - 1 - i) >= 0; i++)
         buf_ema200[rates_total - 1 - i] = tmp[i];
   }

   static datetime last_bar = 0;
   datetime cur = iTime(_Symbol, _Period, 0);
   if(cur != last_bar) { last_bar = cur; Analyze(); }

   return rates_total;
}

void OnDeinit(const int reason)
{
   ClearObjs(g_pfx);
   if(h_ema20  != INVALID_HANDLE) { IndicatorRelease(h_ema20);  h_ema20  = INVALID_HANDLE; }
   if(h_ema50  != INVALID_HANDLE) { IndicatorRelease(h_ema50);  h_ema50  = INVALID_HANDLE; }
   if(h_ema200 != INVALID_HANDLE) { IndicatorRelease(h_ema200); h_ema200 = INVALID_HANDLE; }
   if(h_atr    != INVALID_HANDLE) { IndicatorRelease(h_atr);    h_atr    = INVALID_HANDLE; }
}
