//+------------------------------------------------------------------+
//|  SuerteFX_Trial.mqh                                              |
//|  Trial validation for SuerteFX Scanner Pro                       |
//|                                                                  |
//|  Include in the main indicator:                                  |
//|    #include "SuerteFX_Trial.mqh"                                 |
//|  Call at the top of OnInit():                                    |
//|    if(!SFX_CheckTrial()) return INIT_FAILED;                     |
//+------------------------------------------------------------------+
#ifndef SUERTEFX_TRIAL_MQH
#define SUERTEFX_TRIAL_MQH

// ── Server config ─────────────────────────────────────────────────
#define SFX_TRIAL_URL  "https://license-server-eight-zeta.vercel.app/api/mt5/check"
#define SFX_TRIAL_KEY  "Hhh35fQH7Lk6c07QXIQkR5a3cqHiucH91l4cRKRuc"
#define SFX_PRODUCT    "SuerteFX Scanner Pro"
#define SFX_TIMEOUT_MS 8000

// ── Internal helpers ──────────────────────────────────────────────

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

// ── Public API ────────────────────────────────────────────────────

bool SFX_CheckTrial()
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

   // ── Network error ─────────────────────────────────────────────
   if(code == -1)
   {
      int err = GetLastError();

      if(err == 5203 || err == 4014)
      {
         string setup_msg =
            SFX_PRODUCT + " needs internet access to verify your trial.\n\n"
            + "Please follow these steps:\n"
            + "  1. Go to Tools -> Options -> Expert Advisors\n"
            + "  2. Tick  'Allow WebRequest for listed URL'\n"
            + "  3. Click [ + ] and add the URL below:\n\n"
            + "  " + SFX_TRIAL_URL + "\n\n"
            + "  4. Click OK and re-attach the indicator.\n\n"
            + "This is a one-time setup.";
         MessageBox(setup_msg, SFX_PRODUCT + " - Setup Required",
                    MB_OK | MB_ICONINFORMATION);
         return false;
      }

      Print(SFX_PRODUCT, ": License server unreachable (err=", err, ") -- grace mode.");
      return true;
   }

   // ── HTTP error ────────────────────────────────────────────────
   if(code != 200)
   {
      Print(SFX_PRODUCT, ": License server returned HTTP ", code, " — grace mode.");
      return true;
   }

   // ── Parse JSON response ───────────────────────────────────────
   string json  = CharArrayToString(res_body, 0, WHOLE_ARRAY, CP_UTF8);
   bool   valid = (StringFind(json, "\"valid\":true") >= 0);
   int    days  = _sfx_json_int(json, "days_left");
   string msg   = _sfx_json_str(json, "message");

   // ── Trial expired ─────────────────────────────────────────────
   if(!valid)
   {
      string expired_msg =
         SFX_PRODUCT + " — Trial Expired\n\n"
         + (StringLen(msg) > 0 ? msg : "Your 7-day trial has ended.") + "\n\n"
         + "Purchase the full version on MQL5 Market to continue.";
      Alert(expired_msg);
      Print(SFX_PRODUCT, ": Trial expired. Purchase on MQL5 Market.");
      return false;
   }

   // ── Trial active ──────────────────────────────────────────────
   if(days <= 2)
      Print(SFX_PRODUCT, ": Trial expires in ", days, " day(s) — purchase soon on MQL5 Market.");
   else
      Print(SFX_PRODUCT, ": Trial active — ", days, " day(s) remaining.");

   return true;
}

#endif // SUERTEFX_TRIAL_MQH
