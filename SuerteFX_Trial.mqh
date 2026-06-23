#ifndef SUERTEFX_TRIAL_MQH
#define SUERTEFX_TRIAL_MQH

#define SFX_TRIAL_URL  "https://license-server-eight-zeta.vercel.app/api/mt5/check"
#define SFX_TRIAL_KEY  "Hhh35fQH7Lk6c07QXIQkR5a3cqHiucH91l4cRKRuc"
#define SFX_PRODUCT    "SuerteFX Scanner Pro"
#define SFX_TIMEOUT_MS 8000

// -1 = needs WebRequest setup (stay on chart, show panel)
//  0 = trial expired / unauthorized (remove indicator)
//  1 = trial active (proceed normally)
int g_sfx_status = 1;

// ── JSON helpers ─────────────────────────────────────────────────────────────

int _sfx_json_int(const string json, const string field)
{
   string needle = "\"" + field + "\":";
   int pos = StringFind(json, needle);
   if(pos < 0) return -1;
   return (int)StringToInteger(StringSubstr(json, pos + StringLen(needle), 6));
}

string _sfx_json_str(const string json, const string field)
{
   string needle = "\"" + field + "\":\"";
   int pos = StringFind(json, needle);
   if(pos < 0) return "";
   int s = pos + StringLen(needle);
   int e = StringFind(json, "\"", s);
   return (e > s) ? StringSubstr(json, s, e - s) : "";
}

// ── Setup panel drawing ───────────────────────────────────────────────────────

void _sfx_obj_label(const string name, const string text,
                    int x, int y, color clr, int sz, bool bold)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  sz);
   ObjectSetString(0,  name, OBJPROP_FONT,      bold ? "Segoe UI Semibold" : "Segoe UI");
   ObjectSetString(0,  name, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER,    10);
}

void _sfx_obj_rect(const string name, int x, int y, int w, int h,
                   color bg, color border)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       border);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER,      9);
}

void SFX_DrawSetupPanel()
{
   long cw = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long ch = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   int bw = 520, bh = 256;
   int bx = (int)MathMax(20, (cw - bw) / 2);
   int by = (int)MathMax(20, (ch - bh) / 2);

   color bg     = C'8,14,26';
   color border = C'245,158,11';
   color yellow = C'245,158,11';
   color white  = C'241,245,249';
   color muted  = C'148,163,184';
   color blue   = C'96,165,250';
   color dim    = C'71,85,105';

   // shadow
   _sfx_obj_rect("SFX_SETUP_SH", bx+4, by+4, bw, bh, C'0,0,0', C'0,0,0');
   // main card
   _sfx_obj_rect("SFX_SETUP_BG", bx, by, bw, bh, bg, border);
   // top accent bar
   _sfx_obj_rect("SFX_SETUP_AC", bx, by, bw, 4, yellow, yellow);

   int lx = bx + 22;
   _sfx_obj_label("SFX_SETUP_L0", "! WebRequest Setup Required",          lx, by+14,  yellow, 12, true);
   _sfx_obj_label("SFX_SETUP_L1", SFX_PRODUCT+" needs internet access to verify your trial.", lx, by+44, muted, 8, false);
   _sfx_obj_label("SFX_SETUP_L2", "One-time setup — follow these steps:", lx, by+64,  white,  8, false);
   _sfx_obj_label("SFX_SETUP_S1", "1.  Tools  ->  Options  ->  Expert Advisors", lx, by+90,  white,  9, false);
   _sfx_obj_label("SFX_SETUP_S2", "2.  Tick     Allow WebRequest for listed URL", lx, by+112, white,  9, false);
   _sfx_obj_label("SFX_SETUP_S3", "3.  Click  [ + ]  and paste this URL:",       lx, by+134, white,  9, false);
   _sfx_obj_label("SFX_SETUP_URL", SFX_TRIAL_URL,                                lx+14, by+156, blue, 8, false);
   _sfx_obj_label("SFX_SETUP_S4", "4.  Click OK  then re-attach this indicator.", lx, by+178, white,  9, false);
   _sfx_obj_label("SFX_SETUP_FT", "Indicator is paused until WebRequest is enabled.", lx, by+212, dim, 7, false);

   ChartRedraw(0);
}

void SFX_ClearSetupPanel()
{
   string names[] = {
      "SFX_SETUP_SH","SFX_SETUP_BG","SFX_SETUP_AC",
      "SFX_SETUP_L0","SFX_SETUP_L1","SFX_SETUP_L2",
      "SFX_SETUP_S1","SFX_SETUP_S2","SFX_SETUP_S3",
      "SFX_SETUP_URL","SFX_SETUP_S4","SFX_SETUP_FT"
   };
   for(int i = 0; i < ArraySize(names); i++)
      ObjectDelete(0, names[i]);
   ChartRedraw(0);
}

// ── Trial check ───────────────────────────────────────────────────────────────
//  Returns:  1 = active   |  0 = expired   |  -1 = needs WebRequest setup

int SFX_CheckTrial()
{
   long   acct = AccountInfoInteger(ACCOUNT_LOGIN);
   string url  = SFX_TRIAL_URL
               + "?account=" + IntegerToString(acct)
               + "&k="       + SFX_TRIAL_KEY;

   string req_headers = "";
   char   req_body[], res_body[];
   string res_headers;

   int code = WebRequest("GET", url, req_headers, SFX_TIMEOUT_MS,
                         req_body, res_body, res_headers);

   if(code == -1)
   {
      int err = GetLastError();

      if(err == 4014 || err == 5203)
      {
         Print(SFX_PRODUCT, ": WebRequest not configured (err=", err, ") — showing setup panel.");
         SFX_DrawSetupPanel();
         return -1;
      }

      Print(SFX_PRODUCT, ": License server unreachable (err=", err, ") — grace mode.");
      return 1;
   }

   if(code != 200)
   {
      Print(SFX_PRODUCT, ": License server returned HTTP ", code, " — grace mode.");
      return 1;
   }

   string json  = CharArrayToString(res_body, 0, WHOLE_ARRAY, CP_UTF8);
   bool   valid = (StringFind(json, "\"valid\":true") >= 0);
   int    days  = _sfx_json_int(json, "days_left");
   string msg   = _sfx_json_str(json, "message");

   if(!valid)
   {
      string expired_msg =
         SFX_PRODUCT + " - Trial Expired\n\n"
         + (StringLen(msg) > 0 ? msg : "Your 7-day trial has ended.") + "\n\n"
         + "Purchase the full version on MQL5 Market to continue.";
      Alert(expired_msg);
      Print(SFX_PRODUCT, ": Trial expired. Purchase on MQL5 Market.");
      return 0;
   }

   if(days <= 2)
      Print(SFX_PRODUCT, ": Trial expires in ", days, " day(s) — purchase soon on MQL5 Market.");
   else
      Print(SFX_PRODUCT, ": Trial active — ", days, " day(s) remaining.");

   return 1;
}

#endif // SUERTEFX_TRIAL_MQH
