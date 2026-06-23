#ifndef SUERTEFX_TRIAL_MQH
#define SUERTEFX_TRIAL_MQH

#define SFX_PRODUCT "SuerteFX Scanner Pro"
#define SFX_GV      "SFX_TRIAL_DAYS"

// -1 = License Manager EA not attached (show setup panel)
//  0 = Trial expired
//  1 = Trial active
int g_sfx_status = 1;

// ── Setup panel drawing ───────────────────────────────────────────────────────

void _sfx_obj_label(const string name, const string text,
                    int x, int y, color clr, int sz, bool bold)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   sz);
   ObjectSetString(0,  name, OBJPROP_FONT,       bold ? "Segoe UI Semibold" : "Segoe UI");
   ObjectSetString(0,  name, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER,     10);
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

   int bw = 520, bh = 230;
   int bx = (int)MathMax(20, (cw - bw) / 2);
   int by = (int)MathMax(20, (ch - bh) / 2);

   color bg     = C'8,14,26';
   color border = C'245,158,11';
   color yellow = C'245,158,11';
   color white  = C'241,245,249';
   color muted  = C'148,163,184';
   color blue   = C'96,165,250';
   color dim    = C'71,85,105';

   _sfx_obj_rect("SFX_SETUP_SH", bx+4, by+4, bw, bh, C'0,0,0',   C'0,0,0');
   _sfx_obj_rect("SFX_SETUP_BG", bx,   by,   bw, bh, bg,         border);
   _sfx_obj_rect("SFX_SETUP_AC", bx,   by,   bw, 4,  yellow,     yellow);

   int lx = bx + 22;
   _sfx_obj_label("SFX_SETUP_L0", "! License Manager Not Running",           lx, by+14,  yellow, 12, true);
   _sfx_obj_label("SFX_SETUP_L1", SFX_PRODUCT+" requires the License Manager EA to be attached.", lx, by+44, muted, 8, false);
   _sfx_obj_label("SFX_SETUP_L2", "One-time setup per MT5 session:",         lx, by+64,  white,  8, false);
   _sfx_obj_label("SFX_SETUP_S1", "1.  In Navigator, find  SuerteFX_LicenseMgr  under Expert Advisors", lx, by+90,  white, 9, false);
   _sfx_obj_label("SFX_SETUP_S2", "2.  Drag it onto  any one chart  (e.g. EURUSD M1)",                  lx, by+112, white, 9, false);
   _sfx_obj_label("SFX_SETUP_S3", "3.  Allow WebRequest in its settings when prompted",                  lx, by+134, white, 9, false);
   _sfx_obj_label("SFX_SETUP_S4", "4.  Re-attach this indicator",                                        lx, by+156, white, 9, false);
   _sfx_obj_label("SFX_SETUP_FT", "Indicator is paused until the License Manager EA is running.",        lx, by+192, dim,   7, false);

   ChartRedraw(0);
}

void SFX_ClearSetupPanel()
{
   string names[] = {
      "SFX_SETUP_SH","SFX_SETUP_BG","SFX_SETUP_AC",
      "SFX_SETUP_L0","SFX_SETUP_L1","SFX_SETUP_L2",
      "SFX_SETUP_S1","SFX_SETUP_S2","SFX_SETUP_S3",
      "SFX_SETUP_S4","SFX_SETUP_FT"
   };
   for(int i = 0; i < ArraySize(names); i++)
      ObjectDelete(0, names[i]);
   ChartRedraw(0);
}

// ── Trial check ───────────────────────────────────────────────────────────────
//  Returns:  1 = active   |  0 = expired   |  -1 = manager EA not running

int SFX_CheckTrial()
{
   if(!GlobalVariableCheck(SFX_GV))
   {
      Print(SFX_PRODUCT, ": License Manager EA not detected — attach SuerteFX_LicenseMgr to any chart.");
      SFX_DrawSetupPanel();
      return -1;
   }

   double days = GlobalVariableGet(SFX_GV);

   if(days <= 0)
   {
      Alert(SFX_PRODUCT + " - Trial Expired\n\n"
            + "Your 7-day trial has ended.\n\n"
            + "Purchase the full version on MQL5 Market to continue.");
      Print(SFX_PRODUCT, ": Trial expired.");
      return 0;
   }

   if(days <= 2)
      Print(SFX_PRODUCT, ": Trial expires in ", (int)days, " day(s) — purchase soon on MQL5 Market.");
   else
      Print(SFX_PRODUCT, ": Trial active — ", (int)days, " day(s) remaining.");

   return 1;
}

#endif // SUERTEFX_TRIAL_MQH
