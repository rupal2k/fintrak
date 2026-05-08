# Fintrak Phase 1 — Payment Management System Design

**Date:** 2026-05-08  
**Status:** Draft  
**Scope:** Phase 1 MVP — Telegram-first expense tracking with n8n, Google Sheets, Google Drive, OCR, Docker  
**Author:** rupal2k

---

## 1. Project Goal

A personal + business payment management system where the primary workflow is:

1. Make a payment
2. Take a screenshot/photo of the receipt
3. Send it to a Telegram bot
4. The system automatically extracts, categorizes, stores, and logs the expense

**Zero manual data entry as the target.** Typing is the fallback, not the default.

---

## 2. Architecture Overview

```
User (Telegram)
     │
     │  photo / text / command
     ▼
Telegram Bot (BotFather token)
     │
     │  webhook POST
     ▼
n8n (Docker, self-hosted)
     │
     ├─ [If photo] ──► Download image
     │                      │
     │                      ▼
     │               Upload to Google Drive
     │                      │
     │                      ▼
     │               OCR.Space API → raw text
     │                      │
     │                      ▼
     │               Parse: amount / merchant / date
     │                      │
     │                      ▼
     │               Auto-categorize (keyword rules)
     │                      │
     │                      ▼
     │               Write row → Google Sheets
     │                      │
     │                      ▼
     │               Reply confirmation → Telegram
     │
     ├─ [If text]  ──► Parse structured text
     │                      │ ("150 coffee starbucks" or "b:500 vendor payment")
     │                      ▼
     │               Auto-categorize → Write → Reply
     │
     └─ [If command] → /summary / /search / /report
                            │
                            ▼
                       Query Google Sheets → Reply
```

### Why This Architecture

- **n8n as the brain**: Handles all automation visually, no code required, free self-hosted
- **Telegram**: Free, no API cost, reliable, works on any phone
- **Google Sheets**: Free database, accessible from phone/browser, easy manual edits
- **Google Drive**: Free 15 GB storage for receipt photos
- **OCR.Space**: 25,000 free API calls/month — enough for daily use
- **Docker**: Consistent environment, easy restart, portable to VPS later

---

## 3. Components

### 3.1 Telegram Bot

- Created via BotFather (free, takes 2 minutes)
- Commands registered: `/start`, `/summary`, `/search`, `/help`, `/report`
- n8n listens via **Telegram Trigger node** (polling mode — no public URL required initially)
- **Why polling**: Avoids needing ngrok or a public server for MVP. n8n polls Telegram every few seconds.

### 3.2 n8n (Self-hosted via Docker)

- Version: latest stable (`n8nio/n8n`)
- Runs on `localhost:5678`
- Data persisted in Docker named volume (`n8n_data`)
- Basic auth enabled (admin/password)
- Three workflows:
  - **Workflow A**: Receipt processor (photo input)
  - **Workflow B**: Text entry processor
  - **Workflow C**: Command handler (/summary, /search)

### 3.3 Google Sheets (Database)

Single spreadsheet with 4 tabs:

**Tab 1: Expenses** (main log)

| Column | Field | Example |
|--------|-------|---------|
| A | ID | 0001 |
| B | Date | 2026-05-08 |
| C | Merchant | Starbucks |
| D | Amount | 250.00 |
| E | Currency | INR |
| F | Category | Food & Drink |
| G | Type | Personal |
| H | Payment Method | UPI |
| I | Notes | Coffee with team |
| J | Receipt URL | https://drive.google.com/... |
| K | Source | Telegram |
| L | Raw OCR Text | (hidden col, debug) |
| M | Timestamp | 2026-05-08T10:30:00 |

**Tab 2: Categories** (keyword lookup table)

| Category | Keywords (comma-separated) | Default Type |
|----------|---------------------------|--------------|
| Food & Drink | zomato, swiggy, starbucks, cafe, restaurant, food | Personal |
| Transport | uber, ola, rapido, petrol, fuel, toll, parking | Personal |
| Shopping | amazon, flipkart, myntra, mall, store | Personal |
| Bills & Utilities | electricity, water, broadband, jio, airtel, recharge | Personal |
| Medical | pharmacy, hospital, doctor, clinic, medicine | Personal |
| Business - Software | aws, google, notion, slack, zoom, adobe, subscription | Business |
| Business - Travel | flight, hotel, train, business travel | Business |
| Business - Meals | client, vendor meeting, business lunch, team lunch | Business |
| Business - Supplies | office, stationery, equipment, printer | Business |
| Vendor Payment | vendor, supplier, contractor, payment | Business |
| Cash Withdrawal | atm, cash, withdrawal | Personal |
| Other | (catch-all) | Personal |

**Tab 3: Summary** (formula-driven, auto-updates)
- Monthly totals by category
- Personal vs Business split
- Top 5 merchants this month

**Tab 4: Config**
- Default currency: INR
- Business keyword trigger: "b:" prefix
- Timezone: Asia/Kolkata

### 3.4 Google Drive (Receipt Storage)

- Folder: `Fintrak/Receipts/YYYY-MM/`
- Organized by month automatically
- File naming: `YYYYMMDD-{merchant}-{amount}.jpg`
- Public link shared back in Sheets row

### 3.5 OCR.Space API

- Free plan: 25,000 requests/month
- API key: obtained from `ocr.space` (email signup, instant)
- Engine: OCR Engine 2 (best for receipts)
- Language: English (default); Hindi receipts may need Engine 1
- POST request with image file → returns JSON with parsed text

### 3.6 Categorization Engine (n8n Function Node)

Pure JavaScript inside n8n — no external service needed:

```javascript
// Run inside n8n Function node
const text = $input.item.json.ocrText.toLowerCase();
const merchant = $input.item.json.merchant.toLowerCase();
const combined = text + ' ' + merchant;

const rules = [
  { category: 'Food & Drink', type: 'Personal', 
    keywords: ['zomato','swiggy','starbucks','cafe','restaurant','biryani','pizza','food','eat'] },
  { category: 'Transport', type: 'Personal',
    keywords: ['uber','ola','rapido','petrol','fuel','toll','parking','auto','cab'] },
  { category: 'Shopping', type: 'Personal',
    keywords: ['amazon','flipkart','myntra','mall','store','shop'] },
  { category: 'Bills & Utilities', type: 'Personal',
    keywords: ['electricity','water','broadband','jio','airtel','bsnl','recharge','bill'] },
  { category: 'Medical', type: 'Personal',
    keywords: ['pharmacy','hospital','doctor','clinic','medicine','apollo','medplus'] },
  { category: 'Business - Software', type: 'Business',
    keywords: ['aws','google cloud','notion','slack','zoom','adobe','subscription','saas'] },
  { category: 'Business - Meals', type: 'Business',
    keywords: ['client lunch','vendor meeting','team lunch','business meal'] },
  { category: 'Vendor Payment', type: 'Business',
    keywords: ['vendor','supplier','contractor','invoice'] },
  { category: 'Cash', type: 'Personal',
    keywords: ['atm','cash withdrawal','cash'] },
];

// Check if user prefixed with "b:" for forced business
const forceBusinessNote = $input.item.json.userNote || '';
const forceBusiness = forceBusinessNote.toLowerCase().startsWith('b:');

for (const rule of rules) {
  if (rule.keywords.some(kw => combined.includes(kw))) {
    return [{
      json: {
        ...$input.item.json,
        category: rule.category,
        type: forceBusiness ? 'Business' : rule.type
      }
    }];
  }
}

return [{ json: { ...$input.item.json, category: 'Other', type: forceBusiness ? 'Business' : 'Personal' } }];
```

---

## 4. Text Input Format (No OCR Path)

When user types instead of sending a photo, the bot accepts these formats:

```
250 starbucks coffee          → amount merchant notes (personal default)
b:500 vendor payment xyz      → b: prefix = business
1200 electricity bill         → auto-categorizes as Bills & Utilities
cash 300 lunch                → payment method override
upi 450 amazon order          → payment method = UPI
```

Parsing logic in n8n (regex):
- Amount: first number found
- Business flag: starts with `b:` or `B:`
- Payment method: first word if it matches [cash, upi, card, neft, rtgs, cheque]
- Notes: everything after amount

---

## 5. Commands

| Command | Action |
|---------|--------|
| `/start` | Welcome message + quick guide |
| `/summary` | This month's total: personal, business, grand total |
| `/search coffee` | Last 5 entries matching "coffee" |
| `/report` | Full monthly breakdown by category |
| `/help` | List all commands |

---

## 6. Docker Setup

### File: `docker-compose.yml`

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: fintrak-n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=Asia/Kolkata
      - TZ=Asia/Kolkata
      - N8N_LOG_LEVEL=info
    volumes:
      - n8n_data:/home/node/.n8n
    restart: unless-stopped

volumes:
  n8n_data:
    driver: local
```

### File: `.env`

```
N8N_PASSWORD=choose_a_strong_password_here
TELEGRAM_BOT_TOKEN=your_bot_token_from_botfather
YOUR_TELEGRAM_CHAT_ID=your_numeric_chat_id
OCR_SPACE_API_KEY=your_ocr_space_api_key
GOOGLE_SHEET_ID=your_google_sheet_id
```

### File: `.env.example`

```
N8N_PASSWORD=changeme
TELEGRAM_BOT_TOKEN=
YOUR_TELEGRAM_CHAT_ID=
OCR_SPACE_API_KEY=
GOOGLE_SHEET_ID=
```

### File: `.gitignore`

```
.env
n8n_data/
receipts/
*.log
```

---

## 7. n8n Workflow Details

### Workflow A: Photo/Receipt Processor

```
[Telegram Trigger]
    → IF: message has photo
    → [Telegram: Get File] (get file_path from Telegram)
    → [HTTP Request] download image bytes from Telegram CDN
    → [Google Drive: Upload File] to Fintrak/Receipts/YYYY-MM/
    → [HTTP Request: OCR.Space] POST image → get text
    → [Function: Parse OCR] extract amount, merchant, date
    → [Function: Categorize] apply keyword rules
    → [Google Sheets: Append Row] write to Expenses tab
    → [Telegram: Send Message] "✅ Saved! {merchant} ₹{amount} → {category}"
```

### Workflow B: Text Entry Processor

```
[Telegram Trigger]
    → IF: message is text AND not a command
    → [Function: Parse Text] regex extraction
    → [Function: Categorize]
    → [Google Sheets: Append Row]
    → [Telegram: Send Message] confirmation
```

### Workflow C: Command Handler

```
[Telegram Trigger]
    → IF: message starts with /
    → [Switch node on command]
        → /summary → [Google Sheets: Read] → aggregate → Reply
        → /search {term} → [Google Sheets: Read] → filter → Reply top 5
        → /report → [Google Sheets: Read] → group by category → Reply
        → /help → Reply static text
```

### Workflow D: Daily Summary (Cron)

```
[Cron: Every day at 9:00 PM IST]
    → [Google Sheets: Read] today's rows
    → [Function: Aggregate] sum by type
    → [Telegram: Send Message] to your chat_id
    "📊 Today: Personal ₹X | Business ₹Y | Total ₹Z"
```

---

## 8. OCR Parsing Logic

The raw OCR text from receipts needs structured extraction. n8n Function node:

```javascript
const text = $input.item.json.ocrText || '';
const lines = text.split('\n').map(l => l.trim()).filter(Boolean);

// Extract amount — look for largest number with currency indicators
const amountRegex = /(?:rs\.?|inr|₹)?\s*(\d{1,6}(?:\.\d{2})?)/gi;
const amounts = [];
let match;
while ((match = amountRegex.exec(text)) !== null) {
  amounts.push(parseFloat(match[1]));
}
// Take the largest number as the total amount
const amount = amounts.length > 0 ? Math.max(...amounts) : 0;

// Extract date
const dateRegex = /(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})/;
const dateMatch = text.match(dateRegex);
const date = dateMatch 
  ? new Date(`${dateMatch[3]}-${dateMatch[2]}-${dateMatch[1]}`).toISOString().split('T')[0]
  : new Date().toISOString().split('T')[0];

// Extract merchant — usually first non-empty line or largest text
const merchant = lines[0] || 'Unknown';

// Extract payment method
const paymentMethods = { upi: 'UPI', cash: 'Cash', card: 'Card', gpay: 'UPI', paytm: 'UPI', phonepe: 'UPI', neft: 'NEFT' };
let paymentMethod = 'Unknown';
const lowerText = text.toLowerCase();
for (const [key, val] of Object.entries(paymentMethods)) {
  if (lowerText.includes(key)) { paymentMethod = val; break; }
}

return [{ json: { amount, date, merchant, paymentMethod, ocrText: text } }];
```

---

## 9. Security Practices

1. **Never commit `.env`** — `.gitignore` covers it
2. **n8n basic auth** — password-protected, never open without auth
3. **Telegram chat_id validation** — workflows check that incoming chat_id matches your personal chat_id (prevents strangers using your bot)
4. **Google Drive folder** — private by default, only you have access
5. **Google Sheets** — not publicly shared, API access via service account
6. **OCR.Space key** — stored as n8n credential, never in plaintext in workflow

### Chat ID Guard (add to ALL Telegram workflows)

```javascript
// In n8n IF node condition:
// {{ $json.message.chat.id }} equals YOUR_TELEGRAM_CHAT_ID
// If not matched → send "Unauthorized" and stop
```

---

## 10. Backup Strategy

| What | How | Frequency |
|------|-----|-----------|
| Google Sheets | Auto (Google handles it) + manual export monthly | Monthly |
| Google Drive receipts | Google handles redundancy | Continuous |
| n8n workflows | Export JSON from n8n UI → commit to git repo | After any workflow change |
| Docker volume | `docker cp fintrak-n8n:/home/node/.n8n ./backup-n8n/` | Weekly |

---

## 11. Cost Breakdown

| Service | Cost |
|---------|------|
| n8n self-hosted | FREE (Docker, your machine) |
| Telegram Bot | FREE |
| Google Sheets | FREE (15 GB Google account) |
| Google Drive | FREE (15 GB) |
| OCR.Space | FREE (25,000 req/month) |
| ngrok (if needed later) | FREE tier (1 tunnel) |
| **Total Phase 1** | **₹0 / month** |

---

## 12. Phase 1 Implementation Order

The implementation will proceed in this exact order:

1. **Step 1: Telegram Bot** — BotFather → get token → note your chat_id
2. **Step 2: Google Sheets** — Create spreadsheet → set up 4 tabs → structure columns
3. **Step 3: Google API** — Enable Sheets + Drive APIs → create service account → download JSON key
4. **Step 4: OCR.Space** — Sign up → get free API key
5. **Step 5: Docker + n8n** — Install Docker Desktop → create docker-compose.yml → `docker compose up`
6. **Step 6: n8n Credentials** — Add Telegram, Google Sheets, Google Drive, HTTP (OCR) credentials
7. **Step 7: Workflow A** — Photo receipt processor (the most important flow)
8. **Step 8: Workflow B** — Text entry processor
9. **Step 9: Workflow C** — Command handler (/summary, /search, /report)
10. **Step 10: Workflow D** — Daily summary cron
11. **Step 11: Test end-to-end** — Send real receipts, verify Sheets + Drive
12. **Step 12: Git setup** — Initialize repo, push to github.com/rupal2k/fintrak

---

## 13. Scalability Path (Future Phases)

These are NOT implemented now. Architecture is designed to accommodate them:

| Phase | Addition | How |
|-------|----------|-----|
| Phase 2 | OpenAI categorization | Replace JS categorizer with GPT-4o-mini node in n8n (~$0.001/receipt) |
| Phase 2 | Voice input | Telegram voice message → Whisper API → text → existing flow |
| Phase 3 | Dashboard | Grafana or Metabase pointed at Sheets or Postgres |
| Phase 3 | PDF reports | n8n HTTP call to Puppeteer or wkhtmltopdf container |
| Phase 3 | GST tracking | Add GST % column + GSTIN field to Sheets |
| Phase 4 | Multi-user | n8n with user registry, per-user Sheets |
| Phase 4 | Mobile app | Read from Sheets API (same data, new UI) |
| Phase 4 | Accounting export | n8n workflow → CSV/XLSX → Tally/QuickBooks format |
| Phase 5 | Replace Sheets | Postgres container in Docker Compose, same n8n flows |

---

## 14. Assumptions Made

Since you provided a comprehensive spec, these decisions were made on your behalf:

1. **Location**: India (INR default, IST timezone, UPI as primary payment method)
2. **n8n polling** (not webhook) for MVP — avoids needing a public URL initially
3. **OCR.Space** over Google Vision — simpler auth, generous free tier
4. **Service account** for Google APIs (not OAuth) — simpler for automation
5. **Single user** bot — chat_id guard ensures only you can use it
6. **English OCR** — if you have Hindi receipts, OCR Engine 1 will be needed

---

## 15. Folder Structure (Fintrak Repo)

```
fintrak/
├── docker-compose.yml          # n8n container definition
├── .env                        # secrets (gitignored)
├── .env.example                # template for .env
├── .gitignore
├── README.md
├── n8n-workflows/
│   ├── workflow-a-receipt.json # exported from n8n
│   ├── workflow-b-text.json
│   ├── workflow-c-commands.json
│   └── workflow-d-daily-cron.json
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-05-08-fintrak-phase1-design.md
└── setup/
    ├── sheets-schema.md        # exact column definitions
    └── categorization-rules.md # keyword rules reference
```
