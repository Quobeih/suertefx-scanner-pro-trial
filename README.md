# SuerteFX Scanner Pro — Free Trial

Smart Money Concept indicator for MetaTrader 5.

Download the latest trial from the [**Releases**](../../releases/latest) page.

---

## What's Included

| File | Type | Purpose |
|------|------|---------|
| `SuerteFX_Scanner_Pro_Trial.ex5` | Indicator | Main indicator — attach to your trading charts |
| `SuerteFX_LicenseMgr.ex5` | Expert Advisor | License manager — attach to any one chart per session |

---

## Installation

### Step 1 — Copy the files

- `SuerteFX_Scanner_Pro_Trial.ex5` → `MQL5/Indicators/`
- `SuerteFX_LicenseMgr.ex5` → `MQL5/Experts/`

In MetaTrader 5: **File → Open Data Folder**, then navigate to the folders above.

### Step 2 — Enable WebRequest

1. Go to **Tools → Options → Expert Advisors**
2. Tick **Allow WebRequest for listed URL**
3. Click **+** and add:
   ```
   https://license-server-eight-zeta.vercel.app
   ```
4. Click **OK**

### Step 3 — Attach the License Manager

In the **Navigator** panel, under **Expert Advisors**, drag `SuerteFX_LicenseMgr` onto **any one chart** (e.g. EURUSD M1).

You will see the trial status in that chart's top-left corner:
```
SuerteFX Trial — 7 day(s) left
```

### Step 4 — Attach the Indicator

Drag `SuerteFX_Scanner_Pro_Trial` onto your trading chart. The dashboard loads immediately.

> The License Manager EA must be running on at least one chart for the indicator to work. Repeat Step 3 each time you open MT5.

---

## Trial Details

- **Duration:** 7 days from first activation
- **Activation:** Recorded automatically on first attach using your MT5 account number
- **Expiry:** The indicator shows an alert when the trial ends

---

## Full Version

The full version is available on [MQL5 Market](https://www.mql5.com/en/market/product/182749) — one-time payment, lifetime access, no License Manager EA required.

---

## Support

Open an issue in this repository or visit [suertefx.com](https://suertefx.com) for documentation.
