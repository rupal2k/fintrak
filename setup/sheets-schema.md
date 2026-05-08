# Google Sheets Schema Reference

## Spreadsheet: "Fintrak Expenses"

Create a Google Sheet with 4 tabs in this exact order:

---

## Tab 1: Expenses (Main Log)

13 columns, row 1 = headers (bold, frozen).

| Col | Header | Type | Example | Source |
|-----|--------|------|---------|--------|
| A | ID | (unused in Phase 1) | — | — |
| B | Date | YYYY-MM-DD | 2026-05-08 | OCR or today |
| C | Merchant | Text | Starbucks | OCR line 1 or text parse |
| D | Amount | Number | 250.00 | Largest number in OCR |
| E | Currency | Text | INR | Always INR |
| F | Category | Text | Food & Drink | Keyword rules |
| G | Type | Personal/Business | Personal | Rules + `b:` override |
| H | Payment Method | Text | UPI | OCR detection or text |
| I | Notes | Text | Coffee with team | User caption/text |
| J | Receipt URL | URL | https://drive... | Google Drive view link |
| K | Source | Text | Telegram Photo | Workflow writes this |
| L | Raw OCR | Text | (raw OCR output) | First 500 chars, debug |
| M | Timestamp | ISO datetime | 2026-05-08T10:30:00 | When logged |

**Setup steps:**
1. Rename Sheet1 to `Expenses`
2. Enter headers A1:M1 exactly as above
3. Bold row 1: select A1:M1 → Ctrl+B
4. Freeze row 1: View → Freeze → 1 row

---

## Tab 2: Categories (Reference)

This tab is for your reference. Category rules live in n8n Code nodes (not read from Sheets).

| Column A: Category | Column B: Keywords | Column C: Default Type |
|--------------------|--------------------|------------------------|
| Food & Drink | zomato,swiggy,starbucks,cafe,restaurant | Personal |
| Transport | uber,ola,rapido,petrol,fuel,toll,parking | Personal |
| Shopping | amazon,flipkart,myntra,mall,store,shop | Personal |
| Bills & Utilities | electricity,water,broadband,jio,airtel,bsnl,recharge | Personal |
| Medical | pharmacy,hospital,doctor,clinic,medicine,apollo | Personal |
| Business - Software | aws,notion,slack,zoom,adobe,subscription,saas | Business |
| Business - Travel | flight,hotel,train ticket,business travel,airport | Business |
| Business - Meals | client lunch,vendor meeting,team lunch | Business |
| Business - Supplies | office,stationery,equipment,printer | Business |
| Vendor Payment | vendor,supplier,contractor,invoice,advance | Business |
| Cash | atm,cash withdrawal | Personal |
| Other | (catch-all) | Personal |

---

## Tab 3: Summary (Auto-computed)

Formula-driven. Add these formulas once — they auto-update as rows are added.

**Cell A1:** `Fintrak Monthly Summary`
**Row 3 headers:** A3=`Month` | B3=`Personal Total` | C3=`Business Total` | D3=`Grand Total`

**Row 4 formulas:**

A4: `=TEXT(TODAY(),"MMMM YYYY")`

B4:
```
=SUMPRODUCT((MONTH(Expenses!B2:B1000)=MONTH(TODAY()))*(YEAR(Expenses!B2:B1000)=YEAR(TODAY()))*(Expenses!G2:G1000="Personal")*(Expenses!D2:D1000))
```

C4:
```
=SUMPRODUCT((MONTH(Expenses!B2:B1000)=MONTH(TODAY()))*(YEAR(Expenses!B2:B1000)=YEAR(TODAY()))*(Expenses!G2:G1000="Business")*(Expenses!D2:D1000))
```

D4: `=B4+C4`

---

## Tab 4: Config (Reference)

| Key | Value |
|-----|-------|
| currency | INR |
| timezone | Asia/Kolkata |
| business_prefix | b: |
| daily_summary_hour | 21 |

---

## Getting Your Sheet ID

The Sheet ID is in the URL:
```
https://docs.google.com/spreadsheets/d/THIS_IS_YOUR_SHEET_ID/edit
```
Copy the string between `/d/` and `/edit`. Add to your `.env` as `GOOGLE_SHEET_ID`.
