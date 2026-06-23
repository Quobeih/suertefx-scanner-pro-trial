# SuerteFX Scanner Pro — User Manual
**Version 1.0 | Smart Money Concept (SMC) Scanner for MetaTrader 5**

---

## Table of Contents
1. [Overview](#1-overview)
2. [Installation](#2-installation)
3. [Input Parameters](#3-input-parameters)
4. [The Dashboard Panel](#4-the-dashboard-panel)
5. [Chart Visuals](#5-chart-visuals)
6. [How to Read a Signal](#6-how-to-read-a-signal)
7. [Confluence Scoring System](#7-confluence-scoring-system)
8. [Session Awareness](#8-session-awareness)
9. [Lot Size Calculator](#9-lot-size-calculator)
10. [Alerts](#10-alerts)
11. [Multi-Timeframe Logic](#11-multi-timeframe-logic)
12. [Best Practices](#12-best-practices)
13. [Frequently Asked Questions](#13-frequently-asked-questions)

---

## 1. Overview

**SuerteFX Scanner Pro** is a fully automated Smart Money Concept (SMC) scanner built for MetaTrader 5. It reads institutional market structure in real time and presents a complete trade decision directly on your chart — no external tools required.

The indicator combines:
- **Market structure** (HH/HL, LH/LL, CHoCH)
- **Multi-timeframe (MTF) bias** across 3 timeframes simultaneously
- **Premium / Discount zone** detection via EMA framework
- **Supply and demand zone** mapping (Untested and Verified only)
- **Liquidity pool** identification (BSL / SSL)
- **Session filtering** (London, New York, Overlap)
- **Volume / volatility** confirmation
- **Automatic lot size** calculation based on your account risk

Everything is displayed on a clean, dark-themed dashboard panel that refreshes on every new bar.

---

## 2. Installation

1. Copy `SuerteFX_Scanner_proV1.ex5` into your MetaTrader 5 data folder:
   `...\MQL5\Indicators\`
2. In MetaTrader 5, open **Navigator** (Ctrl+N).
3. Under **Indicators**, find **SuerteFX_Scanner_proV1**.
4. Drag it onto any chart, or double-click to attach.
5. Adjust the input parameters to your preference and click **OK**.
6. The dashboard and all chart objects will appear immediately.

> **Minimum recommended bars:** 250. Apply the indicator only to charts with sufficient price history.

---

## 3. Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpPivotSpan` | 3 | Number of candles left and right used to confirm a swing high or swing low. Higher = fewer but more significant swings. |
| `InpLookback` | 120 | How many bars back the scanner searches for swing points, S/R zones, and liquidity pools. |
| `InpMaxSR` | 4 | Maximum number of support zones AND resistance zones drawn on the chart simultaneously. |
| `InpEMA20` | 20 | Period for the fast EMA (blue line). |
| `InpEMA50` | 50 | Period for the mid EMA (orange line). Used as the premium/discount boundary. |
| `InpEMA200` | 200 | Period for the slow EMA (magenta line). Defines the macro trend direction. |
| `InpShowEMAs` | true | Toggle all three EMA lines on/off. |
| `InpShowSR` | true | Toggle S/R zone boxes on/off. |
| `InpShowLiquidity` | true | Toggle BSL/SSL liquidity lines on/off. |
| `InpShowStructure` | true | Toggle HH/HL/LH/LL structure labels on/off. |
| `InpATRPeriod` | 14 | Period for ATR calculation. ATR is used to scale zone height, SL buffer, and liquidity thresholds. |
| `InpLiqThresh` | 0.20 | ATR multiplier: two swing highs (or lows) within this distance are considered a liquidity pool. |
| `InpSRCluster` | 0.25 | ATR multiplier: swing points within this distance are merged into one S/R zone. |
| `InpSLBufferATR` | 1.5 | ATR multiplier added beyond the entry zone to place the Stop Loss. |
| `InpEnableAlerts` | true | Enable/disable popup + sound alerts when a new setup fires. |
| `InpPanelCorner` | Top-Left | Screen corner where the dashboard is anchored. |
| `InpPanelX` | 14 | Horizontal offset (pixels) from the selected corner. |
| `InpPanelY` | 18 | Vertical offset (pixels) from the selected corner. |
| `InpRiskPct` | 1.0 | Legacy risk field. Use `InpAccountRisk` instead (both do the same thing). |
| `InpAccountRisk` | 1.0 | Percentage of account balance risked per trade for lot size calculation. |
| `InpMinRR` | 2.0 | Minimum acceptable Risk:Reward ratio. Setups with R:R below this value are rejected. |

---

## 4. The Dashboard Panel

The dashboard is divided into six cards. All values update on every new bar.

---

### 4.1 Header Bar

Located at the top of the panel.

| Field | What it shows |
|-------|---------------|
| **Title** | "SUERTEFX SCANNER PRO" |
| **Subtitle** | "Institutional Smart Money Scanner" |
| **TF / Symbol** | Current timeframe and instrument (e.g. `H1 | XAUUSD`) |
| **BIAS badge** | Consolidated directional bias across all 3 timeframes: `BULLISH`, `BEARISH`, or `NEUTRAL` |
| **CONF badge** | Confluence score as a percentage (0–100%). Color: green ≥ 80%, gold ≥ 60%, red below. |
| **SIGNAL badge** | Current trade decision: `BUY`, `SELL`, `WAIT`, `STANDBY`, or `AVOID` |
| **SESSION badge** | Active trading session: `LONDON`, `NEW YORK`, `LDN / NEW YORK`, `ASIA`, `SYDNEY`, or `TRANSITION` |

---

### 4.2 Market Bias Card (left)

Shows the overall directional read on the current timeframe.

| Field | What it shows |
|-------|---------------|
| **MARKET BIAS** | `BULLISH`, `BEARISH`, or `NEUTRAL` in large text |
| **Structure** | Current swing structure: `HH / HL`, `LH / LL`, `CHOCH BULL`, `CHOCH BEAR`, or `RANGING` |
| **Zone** | Whether price is in `PREMIUM` (above EMA 50) or `DISCOUNT` (below EMA 50). A `(!)` warning appears if the zone conflicts with the active setup direction. |
| **MTF Align** | Multi-timeframe agreement: `Aligned` (9/9), `Building` (6/9), or `Mixed` (3/9) |

**Bias is determined by EMA position:**

| Price vs EMAs | Bias |
|--------------|------|
| Above EMA 20, 50, and 200 | Strong Bullish |
| Above EMA 200 and one of EMA 20/50 | Weak Bullish |
| Below EMA 20, 50, and 200 | Strong Bearish |
| Below EMA 200 | Weak Bearish |
| Mixed | Neutral |

---

### 4.3 Setup Card (center)

Displays the active trade setup, or explains why no setup is available.

**When a setup is active:**

| Field | What it shows |
|-------|---------------|
| **Setup title** | `BUY SETUP` or `SELL SETUP` in large text |
| **Status line** | `CONFIRMED`, `ACTIVE`, or `WAIT` |
| **Entry** | Exact entry price level |
| **Stop Loss** | Exact stop loss price level (red) |
| **Take Profit** | TP1 price with R:R ratio (e.g. `4198.50 (2.3R)`) |
| **RR** | Final Risk:Reward ratio (e.g. `1:2.3`) |
| **Reason** | What triggered the setup (e.g. `CHoCH Bull + Last HL`) |

**When no setup is active:**

| Field | What it shows |
|-------|---------------|
| **Title** | `NO ACTIVE SETUP` |
| **Status** | `Wait For Pullback`, `Wait For Session`, `Standby Filtered`, `Stand Aside` |
| **Blocked By** | Exact reason the scanner rejected a setup (e.g. `Bullish context - wait for discount`) |

---

### 4.4 System Strength Card (right)

Three progress bars that summarize current market conditions.

| Bar | What it measures |
|-----|-----------------|
| **Confluence** | 6-factor confluence score (0–100%). Same value as the CONF badge in the header. |
| **Setup Quality** | Quality of the current setup including R:R bonus. Capped at 99%. |
| **Trend** | Strength of the dominant directional bias across all 3 timeframes (0–100%). |

---

### 4.5 Confluence Checklist Card (bottom left)

Six individual confluence factors checked in real time. Each shows `[OK]` (green) or `[  ]` (grey).

| Factor | Passes when... |
|--------|----------------|
| **HTF Trend** | Higher timeframe bias agrees with current timeframe bias |
| **BOS / CHOCH** | Market structure direction matches the EMA bias |
| **Liquidity** | At least one liquidity pool (BSL or SSL) is detected |
| **Zone (PREMIUM/DISCOUNT)** | Price is on the correct side of EMA 50 for the bias direction (discount for buys, premium for sells) |
| **Session** | London, New York, or London/New York overlap is active |
| **Volume** | Volume is within normal range (not compressed or abnormally thin) |

The total score (X/100) is shown in large text. Label:
- **HIGH PROB** — 80% and above
- **BUILDING** — 60–79%
- **CAUTION** — below 60%

---

### 4.6 Market Context Card (bottom right)

| Field | What it shows |
|-------|---------------|
| **Trend label** | `BULLISH TREND`, `BEARISH TREND`, or `BALANCED` |
| **MTF** | The three timeframes being analysed (e.g. `H4 / D1 / H1`) |
| **Risk** | Overall risk environment: `OPTIMAL`, `CAUTION`, or `STANDBY` |
| **Lot** | Calculated lot size based on your account balance and risk % |
| **Session** | Whether the current session is `ACTIVE` (London/NY) or `QUIET` |

---

## 5. Chart Visuals

All chart objects are drawn automatically and refresh every bar.

---

### 5.1 EMA Lines

Three exponential moving averages plotted directly on price:

| Line | Color | Purpose |
|------|-------|---------|
| EMA 20 | Blue | Short-term momentum |
| EMA 50 | Orange | Premium/Discount midline |
| EMA 200 | Magenta | Macro trend direction |

Toggle all three with `InpShowEMAs = false`.

---

### 5.2 Support and Resistance Zones

Rectangular zones drawn from the origin of each swing cluster to 20 bars ahead.

**Only the two strongest zone types are shown:**

| Color | Zone Type | Meaning |
|-------|-----------|---------|
| **Blue** | Untested Support | Price has not returned to this demand area since forming |
| **Darker Blue** | Verified Support | Price returned and held once (confirmed demand) |
| **Red** | Untested Resistance | Price has not returned to this supply area since forming |
| **Dark Orange** | Verified Resistance | Price returned and was rejected once (confirmed supply) |

Weak zones (tested 3+ times) and Turncoat zones (role-reversed) are intentionally hidden to keep the chart clean.

Up to `InpMaxSR` zones are drawn per side (support and resistance separately).

---

### 5.3 Structure Labels

Labelled directly on swing points, offset above highs and below lows:

| Label | Color | Meaning |
|-------|-------|---------|
| **HH** | Green | Higher High — bullish continuation |
| **HL** | Green | Higher Low — bullish continuation |
| **LH** | Red/Orange | Lower High — bearish continuation |
| **LL** | Red/Orange | Lower Low — bearish continuation |

The last 3 swing highs and 3 swing lows are labelled.

---

### 5.4 Liquidity Lines

Dotted horizontal lines at price levels where liquidity pools are clustered:

| Label | Color | Meaning |
|-------|-------|---------|
| **BSL** | Gold/Yellow | Buy-Side Liquidity — resting stop losses above swing highs. Potential upside target. |
| **SSL** | Cyan/Blue | Sell-Side Liquidity — resting stop losses below swing lows. Potential downside target. |

Only the nearest 1 BSL and 1 SSL are shown to avoid clutter.

---

### 5.5 Entry Zone (Active Setups Only)

When a setup fires, the following are drawn on the chart:

| Object | Color | Description |
|--------|-------|-------------|
| Entry line | Green (buy) / Red (sell) | Dashed horizontal at the entry price |
| Stop Loss line | Red | Dashed horizontal at the SL price |
| TP1 line | Green | Dashed horizontal at Take Profit 1 |
| TP2 line | Green (dotted) | +2R extension target |
| TP3 line | Green (dotted) | +3R extension target |
| Entry zone box | Transparent green/red | Visual area around the entry price |
| Risk box | Transparent red | Entry to SL distance visualised |
| Reward box | Transparent green | Entry to TP distance visualised |
| Labels | On right edge | `ENTRY`, `SL`, `TP1`, `TP2`, `TP3` with exact prices |

---

## 6. How to Read a Signal

### Step 1 — Check the CONF badge
- **≥ 80% (green):** High probability conditions. Trade with full confidence.
- **60–79% (gold):** Developing conditions. Consider smaller size or wait for improvement.
- **< 60% (red):** Low confluence. Avoid trading.

### Step 2 — Check the SIGNAL badge
- **BUY / SELL:** A valid setup with entry, SL, and TP is available on the chart.
- **WAIT:** Conditions partially align but one or more factors are missing.
- **STANDBY:** Structure or liquidity aligns but session/volatility is not optimal.
- **AVOID:** Insufficient confluence — stay out.

### Step 3 — Check the Confluence Checklist
All 6 factors should ideally show `[OK]` for a primary trade. A minimum of 4 out of 6 (`BUILDING` level) is acceptable for a developing setup.

### Step 4 — Check the Setup Card
If a setup is active:
- Verify the **R:R** is at minimum 2.0 (set by `InpMinRR`).
- Note the **Entry**, **SL**, and **TP1** prices.
- Use the **Lot** value from the Market Context card for position sizing.

### Step 5 — Check the Entry Zone on the chart
The coloured zone box shows where price is expected to be when you enter. Wait for price to return to this zone before executing.

---

## 7. Confluence Scoring System

The confluence score is calculated from **6 binary factors**. Each factor is either passing (1) or failing (0). The final score is `factors_passed / 6 × 100`.

| Score | Label | Action |
|-------|-------|--------|
| 100% | HIGH PROB | Strong setup — trade with normal size |
| 80–99% | HIGH PROB | Very good — trade |
| 60–79% | BUILDING | Decent — consider reduced size |
| < 60% | CAUTION | Weak — wait or avoid |

**The same score drives:**
- The CONF badge in the header
- The Confluence progress bar in System Strength
- The large number in the Confluence Checklist card
- The color coding throughout the panel

---

## 8. Session Awareness

The scanner automatically detects the active trading session based on GMT time, with full DST (Daylight Saving Time) adjustment for both the UK and the US.

| Session | Hours (GMT, standard) | Quality |
|---------|----------------------|---------|
| London | 07:00 – 16:00 | Active — best |
| New York | 13:00 – 21:00 | Active — best |
| LDN / NY Overlap | 13:00 – 16:00 | Most active — highest liquidity |
| Asian | 00:00 – 09:00 | Quiet — avoid unless specifically trading Asia |
| Pacific (Sydney) | 21:00 – 06:00 | Very quiet — avoid |
| Transition | Between sessions | Avoid |

Setups generated outside of London and New York hours are automatically blocked (`Wait for London/New York` reason). The Session badge in the header shows the current session in real time.

---

## 9. Lot Size Calculator

The scanner automatically calculates the correct lot size for every setup based on:
- **Account balance** (read live from your account)
- **Risk percentage** (`InpAccountRisk`, default 1%)
- **Stop loss distance** in price points
- **Tick size and tick value** of the current symbol

The result is shown in the **Market Context card** under `Lot`. If no setup is active, or if minimum lot requirements cannot be met, `--` or `< min` is shown.

**Formula:**
```
Risk Cash = Account Balance × Risk%
Lot = Risk Cash ÷ (SL Distance ÷ Tick Size × Tick Value)
```

The result is rounded down to the nearest lot step permitted by the broker.

---

## 10. Alerts

When `InpEnableAlerts = true`, a MetaTrader popup alert fires once per bar when a new setup becomes active. The alert message contains:

```
XAUUSD H1 BUY_LIMIT @ 4185.00  SL 4178.50  TP 4198.00  R:R 2.00
```

Alerts are deduplicated — the same setup on the same bar will not trigger twice, even if the indicator recalculates.

To disable alerts: set `InpEnableAlerts = false` in the indicator settings.

---

## 11. Multi-Timeframe Logic

The scanner analyses **three timeframes simultaneously**: the chart timeframe plus two automatically selected higher timeframes.

| Chart Timeframe | HTF 1 | HTF 2 |
|-----------------|-------|-------|
| M1 | M15 | H1 |
| M5 | H1 | H4 |
| M15 | H1 | H4 |
| M30 | H4 | D1 |
| H1 | H4 | D1 |
| H4 | D1 | W1 |
| All others | H1 | H4 |

For each timeframe, the scanner calculates:
- **Bias** (Strong Bullish / Weak Bullish / Neutral / Weak Bearish / Strong Bearish)
- **Structure** (Bullish / Bearish / CHoCH Bull / CHoCH Bear / Neutral)

The **MTF Align** field shows how many of the 3 timeframes agree:
- **Aligned** — all 3 agree (score 9)
- **Building** — 2 of 3 agree (score 6)
- **Mixed** — only 1 or none agree (score 3)

A setup requires at minimum **2 of 3 timeframes** to align before a BUY or SELL signal is issued.

---

## 12. Best Practices

**Recommended timeframes:** M15, M30, H1 for intraday. H4 for swing trading.

**Best instruments:** Works on any instrument. Optimised for XAUUSD, EURUSD, GBPUSD, US30, and NASDAQ.

**Trade only during Active sessions.** The SESSION badge in the header must show `LONDON`, `NEW YORK`, or `LDN / NEW YORK`. Setups during `ASIA`, `SYDNEY`, or `TRANSITION` are automatically blocked.

**Wait for price to reach the Entry Zone.** The setup identifies a potential entry level. Do not chase price — wait for it to come to the zone before executing.

**Use the Lot field.** The built-in calculator accounts for your exact account balance. Do not override it with a larger size even if the setup looks strong.

**Monitor the Confluence Checklist.** If a setup fires but only 4/6 factors are green, consider waiting until a 5th factor clears before entering.

**Do not trade CAUTION signals.** A confluence score below 60% means conditions are fragmented. The scanner shows `AVOID` or `STANDBY` — respect it.

**Adjust `InpMinRR`.** The default is 2.0. If you are a conservative trader, increase to 2.5 or 3.0. The scanner will only signal setups that meet your R:R floor.

---

## 13. Frequently Asked Questions

**Q: Why is there no setup even though bias is Bullish?**
The scanner requires all conditions to align simultaneously — structure, zone (discount for buys), session, liquidity, and R:R. Check the "Blocked By" field in the Setup Card and the Confluence Checklist to see exactly which condition is not met.

---

**Q: Why does the Confluence score show 0% or very low?**
This usually means the current session is quiet (ASIA or SYDNEY), or the structure direction contradicts the EMA bias. The score reflects conditions right now — it will improve as market context develops.

---

**Q: The lot size shows "--". What does that mean?**
Either there is no active setup, or the broker's minimum lot size is larger than what the calculated risk allows. Try increasing `InpAccountRisk` slightly, or check that your account balance is sufficient for the instrument.

---

**Q: Why are some S/R zones not drawn even though price bounced there?**
The scanner shows only **Untested** and **Verified** zones — zones that have been tested 3 or more times are classified as Weak and intentionally hidden. This keeps the chart showing only fresh, high-probability levels.

---

**Q: Can I use this on multiple charts at the same time?**
Yes. Attach it to as many charts as you need. Each instance runs independently on its own symbol and timeframe.

---

**Q: The BSL/SSL line disappeared after a while. Is that normal?**
Yes. Liquidity pools are consumed when price sweeps through them. The scanner will find and draw the next nearest pool on the following bar.

---

**Q: Can I change the panel position?**
Yes. Use `InpPanelCorner` to choose any of the four screen corners, and `InpPanelX` / `InpPanelY` to fine-tune the exact pixel offset.

---

**Q: What does CHoCH mean?**
CHoCH stands for **Change of Character** — an institutional term for a structural shift. A **CHoCH Bull** occurs when price, previously making lower highs, breaks above the previous swing high after sweeping sell-side liquidity. This is often the earliest signal of a trend reversal to the upside. **CHoCH Bear** is the opposite.

---

**Q: Does the indicator repaint?**
No. The indicator recalculates on each new bar close. Swing points, zones, and setups are identified from closed bars only. The current (forming) bar does not influence the analysis.

---

*SuerteFX Scanner Pro — Powered by institutional Smart Money logic.*
*For support, contact the product page on MQL5 Market.*
