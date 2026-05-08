# Fintrak Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Telegram-first personal + business expense tracker that extracts data from receipt photos via OCR and stores everything in Google Sheets + Drive, running entirely on Docker with zero monthly cost.

**Architecture:** User sends receipt photos or text to a Telegram bot → n8n (self-hosted Docker) receives via polling → OCR.Space extracts text → n8n parses and categorizes → Google Sheets stores the row → Google Drive stores the receipt image → Telegram confirms back to user.

**Tech Stack:** Docker Desktop (Windows), n8n 1.x (self-hosted), Telegram Bot API, Google Sheets API v4, Google Drive API v3, OCR.Space REST API, Node.js function nodes inside n8n.

---

## File Map

| File | Purpose |
|------|---------|
| `docker-compose.yml` | n8n container definition |
| `.env` | Secrets (gitignored) |
| `.env.example` | Template committed to git |
| `.gitignore` | Excludes .env, volumes, receipts |
| `README.md` | Setup guide for the repo |
| `n8n-workflows/workflow-a-receipt.json` | Photo/receipt processor workflow (importable) |
| `n8n-workflows/workflow-b-text.json` | Text entry processor workflow (importable) |
| `n8n-workflows/workflow-c-commands.json` | /summary /search /report handler (importable) |
| `n8n-workflows/workflow-d-daily-cron.json` | 9 PM daily summary cron (importable) |
| `setup/sheets-schema.md` | Column definitions for Google Sheets |
| `setup/categorization-rules.md` | Keyword rules reference |
| `setup/google-service-account.md` | Step-by-step Google API setup |

---

## Task 0: Git Repository Initialization

**Files:**
- Create: `.gitignore`
- Create: `.env.example`
- Create: `README.md`

- [ ] **Step 1: Initialize git repo**

Open PowerShell, `cd C:\Rupalprojects\Fintrak`, then:

```powershell
cd C:\Rupalprojects\Fintrak
git init
git remote add origin https://github.com/rupal2k/fintrak.git
```

Expected: `Initialized empty Git repository in C:/Rupalprojects/Fintrak/.git/`

- [ ] **Step 2: Create `.gitignore`**

Create file `C:\Rupalprojects\Fintrak\.gitignore` with this exact content:

```
# Secrets
.env

# n8n Docker volume data
n8n_data/

# Receipt downloads (local temp)
receipts/

# Logs
*.log
npm-debug.log*

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/settings.json
*.swp
```

- [ ] **Step 3: Create `.env.example`**

Create file `C:\Rupalprojects\Fintrak\.env.example`:

```
# n8n admin password — choose something strong
N8N_PASSWORD=changeme

# From BotFather after creating your bot
TELEGRAM_BOT_TOKEN=

# Your personal Telegram numeric chat ID (get via @userinfobot)
YOUR_TELEGRAM_CHAT_ID=

# From ocr.space free account
OCR_SPACE_API_KEY=

# The long ID in your Google Sheet URL
GOOGLE_SHEET_ID=

# Google Drive folder ID for receipts (from folder URL)
GOOGLE_DRIVE_FOLDER_ID=
```

- [ ] **Step 4: Create `README.md`**

Create file `C:\Rupalprojects\Fintrak\README.md`:

```markdown
# Fintrak — Personal + Business Payment Tracker

Telegram-first expense tracking. Send a receipt photo → auto-logged to Google Sheets.

## Quick Start

1. Copy `.env.example` to `.env` and fill in all values
2. Run `docker compose up -d`
3. Open http://localhost:5678 (admin / your N8N_PASSWORD)
4. Import workflows from `n8n-workflows/` folder
5. Add credentials in n8n (Telegram, Google, OCR)

## Stack

- n8n (self-hosted, Docker) — automation
- Telegram Bot — user interface
- Google Sheets — expense database
- Google Drive — receipt storage
- OCR.Space — receipt text extraction

## Usage

Send to your Telegram bot:
- A photo → auto-extracted and logged
- `250 starbucks coffee` → manual text entry
- `b:500 vendor xyz` → business expense (b: prefix)
- `/summary` → this month's totals
- `/search coffee` → find entries matching "coffee"
- `/report` → full monthly breakdown
```

- [ ] **Step 5: Initial commit**

```powershell
git add .gitignore .env.example README.md
git commit -m "chore: initialize fintrak repo with gitignore and readme"
```

Expected: `[main (root-commit) xxxxxxx] chore: initialize fintrak repo with gitignore and readme`

---

## Task 1: Telegram Bot Creation

**External service. No files created here. Produces: BOT_TOKEN + YOUR_CHAT_ID.**

- [ ] **Step 1: Open Telegram and find BotFather**

On your phone or desktop Telegram, search for `@BotFather` and open the chat. It has a blue verified checkmark.

- [ ] **Step 2: Create the bot**

Send this message to BotFather:
```
/newbot
```

BotFather replies: "Alright, a new bot. How are we going to call it?"

Send:
```
Fintrak
```

BotFather asks for username. Send:
```
fintrak_rupal_bot
```
(Must end in `_bot`. If taken, try `fintrak_rupal2k_bot` or similar.)

BotFather replies with your token. It looks like:
```
7234567890:AAFxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Copy it. This is your `TELEGRAM_BOT_TOKEN`.

- [ ] **Step 3: Register bot commands**

Send to BotFather:
```
/setcommands
```

Select your bot when prompted. Then send:
```
start - Welcome and quick guide
summary - This month totals
search - Search expenses (usage: /search keyword)
report - Full monthly breakdown by category
help - Show all commands
```

- [ ] **Step 4: Get your personal chat ID**

Search for `@userinfobot` in Telegram. Send it any message. It replies with:
```
Id: 123456789
First: Rupal
...
```

Copy the `Id` number. This is your `YOUR_TELEGRAM_CHAT_ID`.

- [ ] **Step 5: Update .env**

Copy `.env.example` to `.env`:

```powershell
Copy-Item .env.example .env
```

Open `.env` and fill in the two Telegram values:
```
TELEGRAM_BOT_TOKEN=7234567890:AAFxxxxxxxxxxxxxxxxxxxxxxxxxxx
YOUR_TELEGRAM_CHAT_ID=123456789
```

---

## Task 2: Google Sheets Setup

**External service. Produces: GOOGLE_SHEET_ID + spreadsheet structure.**

- [ ] **Step 1: Create the spreadsheet**

Go to https://sheets.google.com → click `+` (Blank spreadsheet). Name it: **Fintrak Expenses**.

Copy the Sheet ID from the URL. The URL looks like:
```
https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/edit
```
The part between `/d/` and `/edit` is your Sheet ID. Add it to `.env`:
```
GOOGLE_SHEET_ID=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms
```

- [ ] **Step 2: Rename Sheet1 to "Expenses" and set up columns**

Right-click the tab at the bottom named `Sheet1` → Rename → type `Expenses`.

Click cell A1 and enter these headers across row 1 (one per cell):

```
ID | Date | Merchant | Amount | Currency | Category | Type | Payment Method | Notes | Receipt URL | Source | Raw OCR | Timestamp
```

Exact values for A1 through M1:
- A1: `ID`
- B1: `Date`
- C1: `Merchant`
- D1: `Amount`
- E1: `Currency`
- F1: `Category`
- G1: `Type`
- H1: `Payment Method`
- I1: `Notes`
- J1: `Receipt URL`
- K1: `Source`
- L1: `Raw OCR`
- M1: `Timestamp`

Bold row 1: select A1:M1 → Ctrl+B. Freeze row 1: View → Freeze → 1 row.

- [ ] **Step 3: Add Categories tab**

Click `+` at bottom to add new sheet. Name it `Categories`.

Enter this data starting at A1 (copy-paste the whole block):

```
Category	Keywords	Default Type
Food & Drink	zomato,swiggy,starbucks,cafe,restaurant,biryani,pizza,food,eat,dominos,mcdonald,kfc,burger	Personal
Transport	uber,ola,rapido,petrol,fuel,toll,parking,auto,cab,rickshaw,metro,bus,train	Personal
Shopping	amazon,flipkart,myntra,mall,store,shop,meesho,snapdeal,ajio	Personal
Bills & Utilities	electricity,water,broadband,jio,airtel,bsnl,recharge,bill,internet,wifi,gas	Personal
Medical	pharmacy,hospital,doctor,clinic,medicine,apollo,medplus,1mg,netmeds,health	Personal
Business - Software	aws,google cloud,notion,slack,zoom,adobe,subscription,saas,github,figma,canva	Business
Business - Travel	flight,hotel,train ticket,business travel,airport,cab booking	Business
Business - Meals	client lunch,vendor meeting,team lunch,business meal,office lunch	Business
Business - Supplies	office,stationery,equipment,printer,laptop,monitor	Business
Vendor Payment	vendor,supplier,contractor,invoice,payment received,advance	Business
Cash	atm,cash withdrawal,cash	Personal
Other	(catch-all)	Personal
```

- [ ] **Step 4: Add Summary tab**

Add a new sheet, name it `Summary`. In cell A1 enter: `Fintrak Monthly Summary`

In A3: `Month` | B3: `Personal Total` | C3: `Business Total` | D3: `Grand Total`

In A4 enter this formula (pulls current month summary from Expenses):
```
=TEXT(TODAY(),"MMMM YYYY")
```

In B4:
```
=SUMPRODUCT((MONTH(Expenses!B2:B1000)=MONTH(TODAY()))*(YEAR(Expenses!B2:B1000)=YEAR(TODAY()))*(Expenses!G2:G1000="Personal")*(Expenses!D2:D1000))
```

In C4:
```
=SUMPRODUCT((MONTH(Expenses!B2:B1000)=MONTH(TODAY()))*(YEAR(Expenses!B2:B1000)=YEAR(TODAY()))*(Expenses!G2:G1000="Business")*(Expenses!D2:D1000))
```

In D4:
```
=B4+C4
```

- [ ] **Step 5: Add Config tab**

Add a new sheet, name it `Config`. Enter:

```
Key	Value
currency	INR
timezone	Asia/Kolkata
business_prefix	b:
daily_summary_hour	21
```

---

## Task 3: Google API — Service Account Setup

**Produces: `setup/google-credentials.json` (gitignored) + Drive folder ID.**

- [ ] **Step 1: Go to Google Cloud Console**

Open https://console.cloud.google.com. Sign in with the same Google account that owns the spreadsheet.

- [ ] **Step 2: Create a new project**

Click the project dropdown at the top (next to "Google Cloud" logo) → "New Project".
- Project name: `Fintrak`
- Leave organization as-is
- Click "Create"

Wait ~10 seconds, then select the new "Fintrak" project from the dropdown.

- [ ] **Step 3: Enable Google Sheets API**

In the search bar at top, type `Google Sheets API` → click the result → click "Enable".

- [ ] **Step 4: Enable Google Drive API**

In the search bar, type `Google Drive API` → click the result → click "Enable".

- [ ] **Step 5: Create a Service Account**

In left sidebar: APIs & Services → Credentials → "Create Credentials" → "Service Account".

Fill in:
- Service account name: `fintrak-automation`
- Service account ID: auto-fills as `fintrak-automation`
- Description: `n8n automation for Fintrak`

Click "Create and Continue". Skip the optional steps (click "Done").

- [ ] **Step 6: Download the JSON key**

Click on the service account you just created (it appears in the list). Go to the "Keys" tab → "Add Key" → "Create new key" → JSON → "Create".

A `.json` file downloads automatically. Rename it to `google-credentials.json` and move it to `C:\Rupalprojects\Fintrak\setup\google-credentials.json`.

Add to `.gitignore` (open `.gitignore` and add):
```
setup/google-credentials.json
```

The file contains a `client_email` field like `fintrak-automation@fintrak-xxxxx.iam.gserviceaccount.com`. Copy this email address.

- [ ] **Step 7: Share the Google Sheet with the service account**

Open your Fintrak Expenses spreadsheet. Click "Share" (top right). Paste the `client_email` from Step 6. Set permission to "Editor". Uncheck "Notify people". Click "Share".

- [ ] **Step 8: Create Google Drive receipts folder**

Go to https://drive.google.com. Create a new folder: "Fintrak" → inside it create "Receipts".

Right-click the "Receipts" folder → "Share" → paste the same `client_email` → Editor → Share.

Open the "Receipts" folder. The URL looks like:
```
https://drive.google.com/drive/folders/1ABC2DEFxxxxxxxxxxxxxxxx
```

Copy the ID after `/folders/`. Add to `.env`:
```
GOOGLE_DRIVE_FOLDER_ID=1ABC2DEFxxxxxxxxxxxxxxxx
```

---

## Task 4: OCR.Space API Key

**Produces: OCR_SPACE_API_KEY in .env.**

- [ ] **Step 1: Sign up at OCR.Space**

Go to https://ocr.space/ocrapi → click "Register for free API key". Enter your email. You'll receive the key by email within a minute.

Free plan limits: 25,000 requests/month, 1 MB max file size, 3 requests/second.

- [ ] **Step 2: Add to .env**

```
OCR_SPACE_API_KEY=K8xxxxxxxxxxxxxxxxxxxxxxx
```

---

## Task 5: Docker + n8n Setup

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Verify Docker Desktop is installed**

```powershell
docker --version
docker compose version
```

Expected output like:
```
Docker version 27.x.x, build xxxxxxx
Docker Compose version v2.x.x
```

If not installed: download from https://www.docker.com/products/docker-desktop/ → install → restart PC → open Docker Desktop → wait for it to say "Running".

- [ ] **Step 2: Create `docker-compose.yml`**

Create file `C:\Rupalprojects\Fintrak\docker-compose.yml`:

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
      - N8N_METRICS=false
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168
    volumes:
      - n8n_data:/home/node/.n8n
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  n8n_data:
    driver: local
```

- [ ] **Step 3: Start n8n**

```powershell
cd C:\Rupalprojects\Fintrak
docker compose up -d
```

Expected output:
```
[+] Running 2/2
 ✔ Volume "fintrak_n8n_data"  Created
 ✔ Container fintrak-n8n      Started
```

- [ ] **Step 4: Verify n8n is running**

```powershell
docker ps
```

Expected: `fintrak-n8n` listed with status `Up X seconds (healthy)` after ~30 seconds.

Open browser: http://localhost:5678

You should see the n8n login page. Login: `admin` / your `N8N_PASSWORD` value.

If you see the n8n dashboard, n8n is working correctly.

- [ ] **Step 5: Commit docker-compose.yml**

```powershell
git add docker-compose.yml
git commit -m "feat: add n8n docker-compose setup"
```

---

## Task 6: n8n Credentials Setup

**No files created. All configuration inside n8n UI at http://localhost:5678.**

- [ ] **Step 1: Add Telegram credential**

In n8n: click your avatar (bottom-left) → "Credentials" → "Add Credential" → search "Telegram" → select "Telegram API".

- Name: `Fintrak Telegram Bot`
- Access Token: paste your `TELEGRAM_BOT_TOKEN` value
- Click "Save"

- [ ] **Step 2: Add Google Sheets credential (Service Account)**

"Add Credential" → search "Google" → select "Google Sheets API".

- Name: `Fintrak Google Sheets`
- Authentication: select "Service Account"
- Service Account Email: the `client_email` from your `google-credentials.json`
- Private Key: open `google-credentials.json`, find the `"private_key"` field, copy its entire value (including `-----BEGIN PRIVATE KEY-----` ... `-----END PRIVATE KEY-----\n`)
- Click "Save"

- [ ] **Step 3: Add Google Drive credential (Service Account)**

"Add Credential" → "Google Drive API".

- Name: `Fintrak Google Drive`
- Authentication: "Service Account"
- Same Service Account Email and Private Key as Step 2
- Click "Save"

- [ ] **Step 4: Verify credentials**

Back in Credentials list, all three should show a green checkmark. If any shows red, re-check the values.

---

## Task 7: Workflow A — Photo/Receipt Processor

**Files:**
- Create: `n8n-workflows/workflow-a-receipt.json`

This is the most important workflow. It handles the primary user flow: photo → OCR → Sheets.

- [ ] **Step 1: Create the workflow JSON file**

Create `C:\Rupalprojects\Fintrak\n8n-workflows\workflow-a-receipt.json`:

```json
{
  "name": "Fintrak A - Receipt Photo Processor",
  "nodes": [
    {
      "parameters": {
        "updates": ["message"],
        "additionalFields": {}
      },
      "id": "telegram-trigger",
      "name": "Telegram Trigger",
      "type": "n8n-nodes-base.telegramTrigger",
      "typeVersion": 1,
      "position": [240, 300],
      "credentials": {
        "telegramApi": {
          "name": "Fintrak Telegram Bot"
        }
      }
    },
    {
      "parameters": {
        "conditions": {
          "options": {
            "caseSensitive": false,
            "leftValue": "",
            "typeValidation": "loose"
          },
          "conditions": [
            {
              "id": "chat-id-check",
              "leftValue": "={{ $json.message.chat.id.toString() }}",
              "rightValue": "={{ $env.YOUR_TELEGRAM_CHAT_ID }}",
              "operator": {
                "type": "string",
                "operation": "equals"
              }
            }
          ],
          "combinator": "and"
        }
      },
      "id": "guard-chat-id",
      "name": "Guard: Only My Chat",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2,
      "position": [460, 300]
    },
    {
      "parameters": {
        "conditions": {
          "conditions": [
            {
              "id": "has-photo",
              "leftValue": "={{ $json.message.photo }}",
              "rightValue": "",
              "operator": {
                "type": "string",
                "operation": "exists",
                "singleValue": true
              }
            }
          ],
          "combinator": "and"
        }
      },
      "id": "check-has-photo",
      "name": "Has Photo?",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2,
      "position": [680, 240]
    },
    {
      "parameters": {
        "resource": "file",
        "operation": "get",
        "fileId": "={{ $json.message.photo[$json.message.photo.length - 1].file_id }}"
      },
      "id": "get-file-info",
      "name": "Get File Info",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [900, 180],
      "credentials": {
        "telegramApi": {
          "name": "Fintrak Telegram Bot"
        }
      }
    },
    {
      "parameters": {
        "url": "=https://api.telegram.org/file/bot{{ $env.TELEGRAM_BOT_TOKEN }}/{{ $json.result.file_path }}",
        "options": {
          "response": {
            "response": {
              "responseFormat": "file"
            }
          }
        }
      },
      "id": "download-image",
      "name": "Download Image",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [1120, 180]
    },
    {
      "parameters": {
        "operation": "upload",
        "name": "={{ $now.format('YYYYMMDD-HHmmss') }}-receipt.jpg",
        "driveId": {
          "__rl": true,
          "value": "My Drive",
          "mode": "list"
        },
        "folderId": {
          "__rl": true,
          "value": "={{ $env.GOOGLE_DRIVE_FOLDER_ID }}",
          "mode": "id"
        },
        "options": {
          "ocrLanguage": {
            "ocrLanguageValues": {}
          }
        }
      },
      "id": "upload-to-drive",
      "name": "Upload to Drive",
      "type": "n8n-nodes-base.googleDrive",
      "typeVersion": 3,
      "position": [1340, 180],
      "credentials": {
        "googleDriveOAuth2Api": {
          "name": "Fintrak Google Drive"
        }
      }
    },
    {
      "parameters": {
        "method": "POST",
        "url": "https://api.ocr.space/parse/image",
        "sendBody": true,
        "contentType": "multipart-form-data",
        "bodyParameters": {
          "parameters": [
            {
              "name": "apikey",
              "value": "={{ $env.OCR_SPACE_API_KEY }}"
            },
            {
              "name": "OCREngine",
              "value": "2"
            },
            {
              "name": "isTable",
              "value": "true"
            },
            {
              "name": "language",
              "value": "eng"
            }
          ]
        },
        "options": {
          "allowUnauthorizedCerts": false
        }
      },
      "id": "ocr-extract",
      "name": "OCR Extract Text",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [1560, 180]
    },
    {
      "parameters": {
        "jsCode": "const driveFileId = $('Upload to Drive').item.json.id;\nconst driveLink = `https://drive.google.com/file/d/${driveFileId}/view`;\nconst ocrResponse = $input.item.json;\nconst rawText = ocrResponse.ParsedResults?.[0]?.ParsedText || '';\nconst lines = rawText.split('\\n').map(l => l.trim()).filter(Boolean);\n\n// Extract amount — find all numbers, take the largest as total\nconst amountRegex = /(?:rs\\.?|inr|₹|total|amount)[\\s:]*([\\d,]+(?:\\.\\d{2})?)|([\\d,]{3,}(?:\\.\\d{2})?)/gi;\nconst amounts = [];\nlet m;\nwhile ((m = amountRegex.exec(rawText)) !== null) {\n  const val = parseFloat((m[1] || m[2]).replace(/,/g, ''));\n  if (!isNaN(val) && val > 0 && val < 1000000) amounts.push(val);\n}\nconst amount = amounts.length > 0 ? Math.max(...amounts) : 0;\n\n// Extract date\nconst dateRegex = /(\\d{1,2})[\\/-](\\d{1,2})[\\/-](\\d{2,4})/;\nconst dateMatch = rawText.match(dateRegex);\nlet date;\nif (dateMatch) {\n  const y = dateMatch[3].length === 2 ? '20' + dateMatch[3] : dateMatch[3];\n  date = `${y}-${dateMatch[2].padStart(2,'0')}-${dateMatch[1].padStart(2,'0')}`;\n} else {\n  date = new Date().toISOString().split('T')[0];\n}\n\n// Extract merchant — first meaningful line\nconst skipWords = ['gstin','gst','tax','invoice','receipt','bill','total','amount','date','thank','welcome'];\nlet merchant = 'Unknown';\nfor (const line of lines) {\n  const lower = line.toLowerCase();\n  const hasSkip = skipWords.some(w => lower.includes(w));\n  const hasDigit = /\\d{5,}/.test(line);\n  if (!hasSkip && !hasDigit && line.length > 2 && line.length < 50) {\n    merchant = line;\n    break;\n  }\n}\n\n// Extract payment method\nconst payMap = { upi: 'UPI', gpay: 'UPI', paytm: 'UPI', phonepe: 'UPI', cash: 'Cash', card: 'Card', credit: 'Card', debit: 'Card', neft: 'NEFT', rtgs: 'RTGS', cheque: 'Cheque' };\nlet paymentMethod = 'Unknown';\nconst lowerText = rawText.toLowerCase();\nfor (const [key, val] of Object.entries(payMap)) {\n  if (lowerText.includes(key)) { paymentMethod = val; break; }\n}\n\n// Get user's caption note if any\nconst userNote = $('Telegram Trigger').item.json.message?.caption || '';\n\nreturn [{ json: { amount, date, merchant, paymentMethod, userNote, driveLink, rawText, ocrSuccess: rawText.length > 10 } }];"
      },
      "id": "parse-ocr",
      "name": "Parse OCR Result",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [1780, 180]
    },
    {
      "parameters": {
        "jsCode": "const input = $input.item.json;\nconst text = (input.rawText + ' ' + input.merchant).toLowerCase();\nconst userNote = (input.userNote || '').toLowerCase();\nconst forceBusiness = userNote.startsWith('b:');\n\nconst rules = [\n  { category: 'Food & Drink', type: 'Personal', keywords: ['zomato','swiggy','starbucks','cafe','restaurant','biryani','pizza','food','eat','dominos','mcdonald','kfc','burger','dine'] },\n  { category: 'Transport', type: 'Personal', keywords: ['uber','ola','rapido','petrol','fuel','toll','parking','auto','cab','rickshaw','metro','bus fare','train fare'] },\n  { category: 'Shopping', type: 'Personal', keywords: ['amazon','flipkart','myntra','mall','store','shop','meesho','snapdeal','ajio','retail'] },\n  { category: 'Bills & Utilities', type: 'Personal', keywords: ['electricity','water','broadband','jio','airtel','bsnl','recharge','bill','internet','wifi','gas cylinder','piped gas'] },\n  { category: 'Medical', type: 'Personal', keywords: ['pharmacy','hospital','doctor','clinic','medicine','apollo','medplus','1mg','netmeds','health','dental','lab test'] },\n  { category: 'Business - Software', type: 'Business', keywords: ['aws','google cloud','notion','slack','zoom','adobe','subscription','saas','github','figma','canva','digitalocean','heroku'] },\n  { category: 'Business - Travel', type: 'Business', keywords: ['flight','hotel','train ticket','business travel','airport','business cab'] },\n  { category: 'Business - Meals', type: 'Business', keywords: ['client lunch','vendor meeting','team lunch','business meal','office lunch','client dinner'] },\n  { category: 'Business - Supplies', type: 'Business', keywords: ['office supplies','stationery','equipment','printer','laptop','monitor','business supplies'] },\n  { category: 'Vendor Payment', type: 'Business', keywords: ['vendor','supplier','contractor','invoice payment','advance payment'] },\n  { category: 'Cash', type: 'Personal', keywords: ['atm','cash withdrawal','cash advance'] },\n];\n\nlet category = 'Other';\nlet type = 'Personal';\n\nfor (const rule of rules) {\n  if (rule.keywords.some(kw => text.includes(kw) || userNote.includes(kw))) {\n    category = rule.category;\n    type = rule.type;\n    break;\n  }\n}\n\nif (forceBusiness) type = 'Business';\n\nreturn [{ json: { ...input, category, type } }];"
      },
      "id": "categorize",
      "name": "Categorize",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [2000, 180]
    },
    {
      "parameters": {
        "operation": "append",
        "documentId": {
          "__rl": true,
          "value": "={{ $env.GOOGLE_SHEET_ID }}",
          "mode": "id"
        },
        "sheetName": {
          "__rl": true,
          "value": "Expenses",
          "mode": "name"
        },
        "columns": {
          "mappingMode": "defineBelow",
          "value": {
            "Date": "={{ $json.date }}",
            "Merchant": "={{ $json.merchant }}",
            "Amount": "={{ $json.amount }}",
            "Currency": "INR",
            "Category": "={{ $json.category }}",
            "Type": "={{ $json.type }}",
            "Payment Method": "={{ $json.paymentMethod }}",
            "Notes": "={{ $json.userNote }}",
            "Receipt URL": "={{ $json.driveLink }}",
            "Source": "Telegram Photo",
            "Raw OCR": "={{ $json.rawText.substring(0, 500) }}",
            "Timestamp": "={{ $now.toISO() }}"
          }
        },
        "options": {}
      },
      "id": "save-to-sheets",
      "name": "Save to Sheets",
      "type": "n8n-nodes-base.googleSheets",
      "typeVersion": 4.4,
      "position": [2220, 180],
      "credentials": {
        "googleSheetsOAuth2Api": {
          "name": "Fintrak Google Sheets"
        }
      }
    },
    {
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "=✅ *Saved!*\n\n🏪 *Merchant:* {{ $('Categorize').item.json.merchant }}\n💰 *Amount:* ₹{{ $('Categorize').item.json.amount }}\n📂 *Category:* {{ $('Categorize').item.json.category }}\n🏷️ *Type:* {{ $('Categorize').item.json.type }}\n💳 *Payment:* {{ $('Categorize').item.json.paymentMethod }}\n📅 *Date:* {{ $('Categorize').item.json.date }}\n\n_Not right? Just reply with: merchant amount category_",
        "additionalFields": {
          "parse_mode": "Markdown"
        }
      },
      "id": "reply-success",
      "name": "Reply: Saved",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [2440, 180],
      "credentials": {
        "telegramApi": {
          "name": "Fintrak Telegram Bot"
        }
      }
    },
    {
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "⚠️ Unauthorized access attempt blocked.",
        "additionalFields": {}
      },
      "id": "reply-unauthorized",
      "name": "Reply: Unauthorized",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [680, 440],
      "credentials": {
        "telegramApi": {
          "name": "Fintrak Telegram Bot"
        }
      }
    }
  ],
  "connections": {
    "Telegram Trigger": {
      "main": [[{ "node": "Guard: Only My Chat", "type": "main", "index": 0 }]]
    },
    "Guard: Only My Chat": {
      "main": [
        [{ "node": "Has Photo?", "type": "main", "index": 0 }],
        [{ "node": "Reply: Unauthorized", "type": "main", "index": 0 }]
      ]
    },
    "Has Photo?": {
      "main": [
        [{ "node": "Get File Info", "type": "main", "index": 0 }],
        []
      ]
    },
    "Get File Info": {
      "main": [[{ "node": "Download Image", "type": "main", "index": 0 }]]
    },
    "Download Image": {
      "main": [[{ "node": "Upload to Drive", "type": "main", "index": 0 }]]
    },
    "Upload to Drive": {
      "main": [[{ "node": "OCR Extract Text", "type": "main", "index": 0 }]]
    },
    "OCR Extract Text": {
      "main": [[{ "node": "Parse OCR Result", "type": "main", "index": 0 }]]
    },
    "Parse OCR Result": {
      "main": [[{ "node": "Categorize", "type": "main", "index": 0 }]]
    },
    "Categorize": {
      "main": [[{ "node": "Save to Sheets", "type": "main", "index": 0 }]]
    },
    "Save to Sheets": {
      "main": [[{ "node": "Reply: Saved", "type": "main", "index": 0 }]]
    }
  },
  "settings": {
    "executionOrder": "v1"
  }
}
```

- [ ] **Step 2: Import workflow A into n8n**

In n8n UI: top-right menu (three lines) → "Import from File" → select `n8n-workflows/workflow-a-receipt.json`.

The workflow opens in the editor. You should see nodes connected left to right.

- [ ] **Step 3: Add environment variables to n8n**

n8n can't directly read your `.env` file — you must add them as n8n environment variables.

In n8n: Settings (bottom-left gear) → "Variables" → add these one by one:

| Key | Value |
|-----|-------|
| `YOUR_TELEGRAM_CHAT_ID` | your chat ID number |
| `TELEGRAM_BOT_TOKEN` | your bot token |
| `OCR_SPACE_API_KEY` | your OCR key |
| `GOOGLE_SHEET_ID` | your sheet ID |
| `GOOGLE_DRIVE_FOLDER_ID` | your Drive folder ID |

- [ ] **Step 4: Activate the workflow**

In the workflow editor, toggle the "Active" switch (top-right of editor) from grey to green. The workflow is now listening for Telegram messages.

- [ ] **Step 5: Test with a real receipt photo**

Send any receipt photo to your Telegram bot. Within 5-10 seconds you should receive a confirmation like:
```
✅ Saved!
🏪 Merchant: Starbucks
💰 Amount: ₹250
📂 Category: Food & Drink
🏷️ Type: Personal
💳 Payment: UPI
📅 Date: 2026-05-08
```

Open Google Sheets — you should see a new row in the Expenses tab.
Open Google Drive Receipts folder — you should see the image.

- [ ] **Step 6: Commit**

```powershell
git add n8n-workflows/workflow-a-receipt.json
git commit -m "feat: add receipt photo processor workflow A"
```

---

## Task 8: Workflow B — Text Entry Processor

**Files:**
- Create: `n8n-workflows/workflow-b-text.json`

- [ ] **Step 1: Create the workflow JSON file**

Create `C:\Rupalprojects\Fintrak\n8n-workflows\workflow-b-text.json`:

```json
{
  "name": "Fintrak B - Text Entry Processor",
  "nodes": [
    {
      "parameters": {
        "updates": ["message"],
        "additionalFields": {}
      },
      "id": "telegram-trigger-b",
      "name": "Telegram Trigger",
      "type": "n8n-nodes-base.telegramTrigger",
      "typeVersion": 1,
      "position": [240, 300],
      "credentials": {
        "telegramApi": {
          "name": "Fintrak Telegram Bot"
        }
      }
    },
    {
      "parameters": {
        "conditions": {
          "conditions": [
            {
              "leftValue": "={{ $json.message.chat.id.toString() }}",
              "rightValue": "={{ $env.YOUR_TELEGRAM_CHAT_ID }}",
              "operator": { "type": "string", "operation": "equals" }
            }
          ],
          "combinator": "and"
        }
      },
      "id": "guard-b",
      "name": "Guard: Only My Chat",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2,
      "position": [460, 300]
    },
    {
      "parameters": {
        "conditions": {
          "conditions": [
            {
              "leftValue": "={{ $json.message.text }}",
              "rightValue": "",
              "operator": { "type": "string", "operation": "exists", "singleValue": true }
            },
            {
              "leftValue": "={{ $json.message.text }}",
              "rightValue": "/",
              "operator": { "type": "string", "operation": "startsWith", "not": true }
            },
            {
              "leftValue": "={{ $json.message.photo }}",
              "rightValue": "",
              "operator": { "type": "string", "operation": "notExists", "singleValue": true }
            }
          ],
          "combinator": "and"
        }
      },
      "id": "is-text-entry",
      "name": "Is Text Entry?",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2,
      "position": [680, 300]
    },
    {
      "parameters": {
        "jsCode": "const text = ($input.item.json.message?.text || '').trim();\n\n// Check business prefix\nconst forceBusiness = text.toLowerCase().startsWith('b:');\nconst cleanText = forceBusiness ? text.substring(2).trim() : text;\n\n// Extract payment method if first word matches known methods\nconst methodWords = ['cash','upi','card','neft','rtgs','cheque','gpay','paytm','phonepe'];\nconst words = cleanText.split(/\\s+/);\nlet paymentMethod = 'UPI';\nlet remaining = cleanText;\nif (methodWords.includes(words[0].toLowerCase())) {\n  const methodMap = { cash: 'Cash', upi: 'UPI', card: 'Card', neft: 'NEFT', rtgs: 'RTGS', cheque: 'Cheque', gpay: 'UPI', paytm: 'UPI', phonepe: 'UPI' };\n  paymentMethod = methodMap[words[0].toLowerCase()] || 'UPI';\n  remaining = words.slice(1).join(' ');\n}\n\n// Extract amount — first number found in remaining\nconst amountMatch = remaining.match(/([\\d,]+(?:\\.\\d{2})?)/);\nconst amount = amountMatch ? parseFloat(amountMatch[1].replace(/,/g, '')) : 0;\n\n// Everything after the amount is merchant + notes\nconst afterAmount = remaining.replace(amountMatch?.[0] || '', '').trim();\nconst afterWords = afterAmount.split(/\\s+/);\nconst merchant = afterWords.slice(0, 2).join(' ') || 'Unknown';\nconst notes = afterWords.slice(2).join(' ') || '';\n\nreturn [{ json: {\n  amount,\n  date: new Date().toISOString().split('T')[0],\n  merchant,\n  paymentMethod,\n  userNote: forceBusiness ? 'b:' + notes : notes,\n  forceBusiness,\n  rawText: text,\n  driveLink: '',\n  ocrSuccess: true\n} }];"
      },
      "id": "parse-text",
      "name": "Parse Text Input",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [900, 240]
    },
    {
      "parameters": {
        "jsCode": "const input = $input.item.json;\nconst text = (input.rawText + ' ' + input.merchant).toLowerCase();\nconst userNote = (input.userNote || '').toLowerCase();\nconst forceBusiness = input.forceBusiness;\n\nconst rules = [\n  { category: 'Food & Drink', type: 'Personal', keywords: ['zomato','swiggy','starbucks','cafe','restaurant','biryani','pizza','food','eat','dominos','mcdonald','kfc','burger','dine'] },\n  { category: 'Transport', type: 'Personal', keywords: ['uber','ola','rapido','petrol','fuel','toll','parking','auto','cab','rickshaw','metro'] },\n  { category: 'Shopping', type: 'Personal', keywords: ['amazon','flipkart','myntra','mall','store','shop','meesho','retail'] },\n  { category: 'Bills & Utilities', type: 'Personal', keywords: ['electricity','water','broadband','jio','airtel','bsnl','recharge','bill','internet','wifi'] },\n  { category: 'Medical', type: 'Personal', keywords: ['pharmacy','hospital','doctor','clinic','medicine','apollo','medplus','health'] },\n  { category: 'Business - Software', type: 'Business', keywords: ['aws','notion','slack','zoom','adobe','subscription','saas','github','figma'] },\n  { category: 'Business - Travel', type: 'Business', keywords: ['flight','hotel','train ticket','business travel','airport'] },\n  { category: 'Business - Meals', type: 'Business', keywords: ['client lunch','vendor meeting','team lunch','business meal'] },\n  { category: 'Vendor Payment', type: 'Business', keywords: ['vendor','supplier','contractor','invoice','advance'] },\n  { category: 'Cash', type: 'Personal', keywords: ['atm','cash withdrawal'] },\n];\n\nlet category = 'Other';\nlet type = 'Personal';\n\nfor (const rule of rules) {\n  if (rule.keywords.some(kw => text.includes(kw) || userNote.includes(kw))) {\n    category = rule.category;\n    type = rule.type;\n    break;\n  }\n}\n\nif (forceBusiness) type = 'Business';\n\nreturn [{ json: { ...input, category, type } }];"
      },
      "id": "categorize-b",
      "name": "Categorize",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [1120, 240]
    },
    {
      "parameters": {
        "operation": "append",
        "documentId": { "__rl": true, "value": "={{ $env.GOOGLE_SHEET_ID }}", "mode": "id" },
        "sheetName": { "__rl": true, "value": "Expenses", "mode": "name" },
        "columns": {
          "mappingMode": "defineBelow",
          "value": {
            "Date": "={{ $json.date }}",
            "Merchant": "={{ $json.merchant }}",
            "Amount": "={{ $json.amount }}",
            "Currency": "INR",
            "Category": "={{ $json.category }}",
            "Type": "={{ $json.type }}",
            "Payment Method": "={{ $json.paymentMethod }}",
            "Notes": "={{ $json.userNote }}",
            "Receipt URL": "",
            "Source": "Telegram Text",
            "Raw OCR": "",
            "Timestamp": "={{ $now.toISO() }}"
          }
        },
        "options": {}
      },
      "id": "save-to-sheets-b",
      "name": "Save to Sheets",
      "type": "n8n-nodes-base.googleSheets",
      "typeVersion": 4.4,
      "position": [1340, 240],
      "credentials": {
        "googleSheetsOAuth2Api": { "name": "Fintrak Google Sheets" }
      }
    },
    {
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "=✅ *Logged!*\n\n🏪 *{{ $('Categorize').item.json.merchant }}* — ₹{{ $('Categorize').item.json.amount }}\n📂 {{ $('Categorize').item.json.category }} | 🏷️ {{ $('Categorize').item.json.type }}",
        "additionalFields": { "parse_mode": "Markdown" }
      },
      "id": "reply-logged",
      "name": "Reply: Logged",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [1560, 240],
      "credentials": {
        "telegramApi": { "name": "Fintrak Telegram Bot" }
      }
    }
  ],
  "connections": {
    "Telegram Trigger": {
      "main": [[{ "node": "Guard: Only My Chat", "type": "main", "index": 0 }]]
    },
    "Guard: Only My Chat": {
      "main": [
        [{ "node": "Is Text Entry?", "type": "main", "index": 0 }],
        []
      ]
    },
    "Is Text Entry?": {
      "main": [
        [{ "node": "Parse Text Input", "type": "main", "index": 0 }],
        []
      ]
    },
    "Parse Text Input": {
      "main": [[{ "node": "Categorize", "type": "main", "index": 0 }]]
    },
    "Categorize": {
      "main": [[{ "node": "Save to Sheets", "type": "main", "index": 0 }]]
    },
    "Save to Sheets": {
      "main": [[{ "node": "Reply: Logged", "type": "main", "index": 0 }]]
    }
  },
  "settings": { "executionOrder": "v1" }
}
```

- [ ] **Step 2: Import and activate Workflow B**

In n8n: menu → "Import from File" → select `workflow-b-text.json` → toggle Active to green.

- [ ] **Step 3: Test text entry**

Send these messages one by one to your bot and verify each logs correctly:

```
250 starbucks coffee
```
Expected reply: `✅ Logged! Starbucks — ₹250 | Food & Drink | Personal`

```
b:500 vendor payment xyz
```
Expected reply: `✅ Logged! vendor payment — ₹500 | Vendor Payment | Business`

```
upi 1200 electricity bill jio
```
Expected reply: `✅ Logged! electricity bill — ₹1200 | Bills & Utilities | Personal`

Check Google Sheets — three new rows should appear.

- [ ] **Step 4: Commit**

```powershell
git add n8n-workflows/workflow-b-text.json
git commit -m "feat: add text entry processor workflow B"
```

---

## Task 9: Workflow C — Command Handler

**Files:**
- Create: `n8n-workflows/workflow-c-commands.json`

- [ ] **Step 1: Create the workflow JSON file**

Create `C:\Rupalprojects\Fintrak\n8n-workflows\workflow-c-commands.json`:

```json
{
  "name": "Fintrak C - Command Handler",
  "nodes": [
    {
      "parameters": {
        "updates": ["message"],
        "additionalFields": {}
      },
      "id": "telegram-trigger-c",
      "name": "Telegram Trigger",
      "type": "n8n-nodes-base.telegramTrigger",
      "typeVersion": 1,
      "position": [240, 300],
      "credentials": {
        "telegramApi": { "name": "Fintrak Telegram Bot" }
      }
    },
    {
      "parameters": {
        "conditions": {
          "conditions": [
            {
              "leftValue": "={{ $json.message.chat.id.toString() }}",
              "rightValue": "={{ $env.YOUR_TELEGRAM_CHAT_ID }}",
              "operator": { "type": "string", "operation": "equals" }
            },
            {
              "leftValue": "={{ $json.message.text }}",
              "rightValue": "/",
              "operator": { "type": "string", "operation": "startsWith" }
            }
          ],
          "combinator": "and"
        }
      },
      "id": "is-my-command",
      "name": "Is My Command?",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2,
      "position": [460, 300]
    },
    {
      "parameters": {
        "dataPropertyName": "command",
        "rules": {
          "rules": [
            { "value": "/summary" },
            { "value": "/report" },
            { "value": "/search" },
            { "value": "/start" },
            { "value": "/help" }
          ]
        },
        "fallbackOutput": "extra"
      },
      "id": "route-command",
      "name": "Route Command",
      "type": "n8n-nodes-base.switch",
      "typeVersion": 3,
      "position": [680, 240],
      "onError": "continueRegularOutput"
    },
    {
      "parameters": {
        "operation": "read",
        "documentId": { "__rl": true, "value": "={{ $env.GOOGLE_SHEET_ID }}", "mode": "id" },
        "sheetName": { "__rl": true, "value": "Expenses", "mode": "name" },
        "filters": {},
        "options": {}
      },
      "id": "read-for-summary",
      "name": "Read Expenses",
      "type": "n8n-nodes-base.googleSheets",
      "typeVersion": 4.4,
      "position": [900, 160],
      "credentials": {
        "googleSheetsOAuth2Api": { "name": "Fintrak Google Sheets" }
      }
    },
    {
      "parameters": {
        "jsCode": "const rows = $input.all();\nconst now = new Date();\nconst thisMonth = now.getMonth();\nconst thisYear = now.getFullYear();\n\nlet personalTotal = 0, businessTotal = 0;\nconst categoryTotals = {};\n\nfor (const row of rows) {\n  const r = row.json;\n  if (!r.Date || !r.Amount) continue;\n  const d = new Date(r.Date);\n  if (d.getMonth() !== thisMonth || d.getFullYear() !== thisYear) continue;\n  const amt = parseFloat(r.Amount) || 0;\n  if (r.Type === 'Business') businessTotal += amt;\n  else personalTotal += amt;\n  categoryTotals[r.Category] = (categoryTotals[r.Category] || 0) + amt;\n}\n\nconst monthName = now.toLocaleString('en-IN', { month: 'long', year: 'numeric' });\nconst sortedCats = Object.entries(categoryTotals).sort((a,b) => b[1]-a[1]).slice(0, 5);\nconst catLines = sortedCats.map(([cat, amt]) => `  ${cat}: ₹${amt.toFixed(0)}`).join('\\n');\n\nconst msg = `📊 *${monthName} Summary*\\n\\n👤 Personal: ₹${personalTotal.toFixed(0)}\\n💼 Business: ₹${businessTotal.toFixed(0)}\\n💰 Total: ₹${(personalTotal+businessTotal).toFixed(0)}\\n\\n*Top Categories:*\\n${catLines || '  No data yet'}`;\n\nreturn [{ json: { message: msg } }];"
      },
      "id": "build-summary",
      "name": "Build Summary",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [1120, 160]
    },
    {
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "={{ $json.message }}",
        "additionalFields": { "parse_mode": "Markdown" }
      },
      "id": "reply-summary",
      "name": "Reply Summary",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [1340, 160],
      "credentials": {
        "telegramApi": { "name": "Fintrak Telegram Bot" }
      }
    },
    {
      "parameters": {
        "operation": "read",
        "documentId": { "__rl": true, "value": "={{ $env.GOOGLE_SHEET_ID }}", "mode": "id" },
        "sheetName": { "__rl": true, "value": "Expenses", "mode": "name" },
        "filters": {},
        "options": {}
      },
      "id": "read-for-report",
      "name": "Read for Report",
      "type": "n8n-nodes-base.googleSheets",
      "typeVersion": 4.4,
      "position": [900, 300],
      "credentials": {
        "googleSheetsOAuth2Api": { "name": "Fintrak Google Sheets" }
      }
    },
    {
      "parameters": {
        "jsCode": "const rows = $input.all();\nconst now = new Date();\nconst thisMonth = now.getMonth();\nconst thisYear = now.getFullYear();\n\nconst catTotals = {};\nlet total = 0;\nfor (const row of rows) {\n  const r = row.json;\n  if (!r.Date || !r.Amount) continue;\n  const d = new Date(r.Date);\n  if (d.getMonth() !== thisMonth || d.getFullYear() !== thisYear) continue;\n  const amt = parseFloat(r.Amount) || 0;\n  const key = `${r.Category} (${r.Type})`;\n  catTotals[key] = (catTotals[key] || 0) + amt;\n  total += amt;\n}\n\nconst sorted = Object.entries(catTotals).sort((a,b) => b[1]-a[1]);\nconst lines = sorted.map(([cat, amt]) => `${cat}: ₹${amt.toFixed(0)}`).join('\\n');\nconst monthName = now.toLocaleString('en-IN', { month: 'long', year: 'numeric' });\n\nconst msg = `📋 *${monthName} Full Report*\\n\\n${lines || 'No expenses this month'}\\n\\n*Grand Total: ₹${total.toFixed(0)}*`;\nreturn [{ json: { message: msg } }];"
      },
      "id": "build-report",
      "name": "Build Report",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [1120, 300]
    },
    {
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "={{ $json.message }}",
        "additionalFields": { "parse_mode": "Markdown" }
      },
      "id": "reply-report",
      "name": "Reply Report",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [1340, 300],
      "credentials": {
        "telegramApi": { "name": "Fintrak Telegram Bot" }
      }
    },
    {
      "parameters": {
        "operation": "read",
        "documentId": { "__rl": true, "value": "={{ $env.GOOGLE_SHEET_ID }}", "mode": "id" },
        "sheetName": { "__rl": true, "value": "Expenses", "mode": "name" },
        "filters": {},
        "options": {}
      },
      "id": "read-for-search",
      "name": "Read for Search",
      "type": "n8n-nodes-base.googleSheets",
      "typeVersion": 4.4,
      "position": [900, 440],
      "credentials": {
        "googleSheetsOAuth2Api": { "name": "Fintrak Google Sheets" }
      }
    },
    {
      "parameters": {
        "jsCode": "const rows = $input.all();\nconst cmdText = $('Telegram Trigger').item.json.message.text || '';\nconst term = cmdText.replace('/search', '').trim().toLowerCase();\n\nif (!term) {\n  return [{ json: { message: '🔍 Usage: /search keyword\\nExample: /search starbucks' } }];\n}\n\nconst matches = rows\n  .map(r => r.json)\n  .filter(r => r.Merchant && (r.Merchant.toLowerCase().includes(term) || (r.Notes || '').toLowerCase().includes(term) || (r.Category || '').toLowerCase().includes(term)))\n  .slice(-10)\n  .reverse();\n\nif (matches.length === 0) {\n  return [{ json: { message: `🔍 No results for \"${term}\"` } }];\n}\n\nconst lines = matches.map(r => `📅 ${r.Date} | ${r.Merchant} | ₹${r.Amount} | ${r.Category}`).join('\\n');\nreturn [{ json: { message: `🔍 *Results for \"${term}\":*\\n\\n${lines}` } }];"
      },
      "id": "build-search",
      "name": "Build Search Results",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [1120, 440]
    },
    {
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "={{ $json.message }}",
        "additionalFields": { "parse_mode": "Markdown" }
      },
      "id": "reply-search",
      "name": "Reply Search",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [1340, 440],
      "credentials": {
        "telegramApi": { "name": "Fintrak Telegram Bot" }
      }
    },
    {
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "👋 *Welcome to Fintrak!*\n\n*How to log expenses:*\n📸 Send a receipt photo → auto-extracted\n✍️ Or type: `250 starbucks coffee`\n💼 Business prefix: `b:500 vendor xyz`\n💳 Payment method first: `cash 300 lunch`\n\n*Commands:*\n/summary — this month totals\n/report — breakdown by category\n/search keyword — find expenses\n/help — show this message",
        "additionalFields": { "parse_mode": "Markdown" }
      },
      "id": "reply-start",
      "name": "Reply Start/Help",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [900, 560],
      "credentials": {
        "telegramApi": { "name": "Fintrak Telegram Bot" }
      }
    }
  ],
  "connections": {
    "Telegram Trigger": {
      "main": [[{ "node": "Is My Command?", "type": "main", "index": 0 }]]
    },
    "Is My Command?": {
      "main": [
        [{ "node": "Route Command", "type": "main", "index": 0 }],
        []
      ]
    },
    "Route Command": {
      "main": [
        [{ "node": "Read Expenses", "type": "main", "index": 0 }],
        [{ "node": "Read for Report", "type": "main", "index": 0 }],
        [{ "node": "Read for Search", "type": "main", "index": 0 }],
        [{ "node": "Reply Start/Help", "type": "main", "index": 0 }],
        [{ "node": "Reply Start/Help", "type": "main", "index": 0 }]
      ]
    },
    "Read Expenses": {
      "main": [[{ "node": "Build Summary", "type": "main", "index": 0 }]]
    },
    "Build Summary": {
      "main": [[{ "node": "Reply Summary", "type": "main", "index": 0 }]]
    },
    "Read for Report": {
      "main": [[{ "node": "Build Report", "type": "main", "index": 0 }]]
    },
    "Build Report": {
      "main": [[{ "node": "Reply Report", "type": "main", "index": 0 }]]
    },
    "Read for Search": {
      "main": [[{ "node": "Build Search Results", "type": "main", "index": 0 }]]
    },
    "Build Search Results": {
      "main": [[{ "node": "Reply Search", "type": "main", "index": 0 }]]
    }
  },
  "settings": { "executionOrder": "v1" }
}
```

- [ ] **Step 2: Import and activate Workflow C**

In n8n: menu → "Import from File" → select `workflow-c-commands.json` → toggle Active.

- [ ] **Step 3: Test commands**

Send these to your bot:
- `/start` — should show welcome message with all commands
- `/summary` — should show monthly totals (from your test entries)
- `/search starbucks` — should find the starbucks entry you tested
- `/report` — should show breakdown by category

- [ ] **Step 4: Commit**

```powershell
git add n8n-workflows/workflow-c-commands.json
git commit -m "feat: add command handler workflow C"
```

---

## Task 10: Workflow D — Daily Summary Cron

**Files:**
- Create: `n8n-workflows/workflow-d-daily-cron.json`

- [ ] **Step 1: Create the workflow JSON file**

Create `C:\Rupalprojects\Fintrak\n8n-workflows\workflow-d-daily-cron.json`:

```json
{
  "name": "Fintrak D - Daily Summary Cron",
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 21 * * *"
            }
          ]
        }
      },
      "id": "cron-trigger",
      "name": "Daily 9PM Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.2,
      "position": [240, 300]
    },
    {
      "parameters": {
        "operation": "read",
        "documentId": { "__rl": true, "value": "={{ $env.GOOGLE_SHEET_ID }}", "mode": "id" },
        "sheetName": { "__rl": true, "value": "Expenses", "mode": "name" },
        "filters": {},
        "options": {}
      },
      "id": "read-today",
      "name": "Read Expenses",
      "type": "n8n-nodes-base.googleSheets",
      "typeVersion": 4.4,
      "position": [460, 300],
      "credentials": {
        "googleSheetsOAuth2Api": { "name": "Fintrak Google Sheets" }
      }
    },
    {
      "parameters": {
        "jsCode": "const rows = $input.all();\nconst today = new Date().toISOString().split('T')[0];\n\nlet personalToday = 0, businessToday = 0;\nlet countToday = 0;\nconst topItems = [];\n\nfor (const row of rows) {\n  const r = row.json;\n  if (r.Date !== today || !r.Amount) continue;\n  const amt = parseFloat(r.Amount) || 0;\n  if (r.Type === 'Business') businessToday += amt;\n  else personalToday += amt;\n  countToday++;\n  topItems.push(`  • ${r.Merchant} ₹${amt.toFixed(0)} (${r.Category})`);\n}\n\nconst totalToday = personalToday + businessToday;\n\nlet msg;\nif (countToday === 0) {\n  msg = `📊 *Daily Summary — ${today}*\\n\\n✅ No expenses logged today!`;\n} else {\n  const itemLines = topItems.slice(0, 5).join('\\n');\n  msg = `📊 *Daily Summary — ${today}*\\n\\n${countToday} expense(s) logged\\n👤 Personal: ₹${personalToday.toFixed(0)}\\n💼 Business: ₹${businessToday.toFixed(0)}\\n💰 Total: ₹${totalToday.toFixed(0)}\\n\\n*Today's expenses:*\\n${itemLines}`;\n}\n\nreturn [{ json: { message: msg, hasExpenses: countToday > 0 } }];"
      },
      "id": "build-daily",
      "name": "Build Daily Summary",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [680, 300]
    },
    {
      "parameters": {
        "chatId": "={{ $env.YOUR_TELEGRAM_CHAT_ID }}",
        "text": "={{ $json.message }}",
        "additionalFields": { "parse_mode": "Markdown" }
      },
      "id": "send-daily",
      "name": "Send Daily Summary",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1.2,
      "position": [900, 300],
      "credentials": {
        "telegramApi": { "name": "Fintrak Telegram Bot" }
      }
    }
  ],
  "connections": {
    "Daily 9PM Trigger": {
      "main": [[{ "node": "Read Expenses", "type": "main", "index": 0 }]]
    },
    "Read Expenses": {
      "main": [[{ "node": "Build Daily Summary", "type": "main", "index": 0 }]]
    },
    "Build Daily Summary": {
      "main": [[{ "node": "Send Daily Summary", "type": "main", "index": 0 }]]
    }
  },
  "settings": { "executionOrder": "v1" }
}
```

- [ ] **Step 2: Import and activate Workflow D**

In n8n: menu → "Import from File" → select `workflow-d-daily-cron.json` → toggle Active.

- [ ] **Step 3: Test the cron manually**

In the workflow editor, click "Execute Workflow" (play button). You should receive a Telegram message immediately with today's summary.

- [ ] **Step 4: Commit**

```powershell
git add n8n-workflows/workflow-d-daily-cron.json
git commit -m "feat: add daily 9PM cron summary workflow D"
```

---

## Task 11: Setup Documentation

**Files:**
- Create: `setup/sheets-schema.md`
- Create: `setup/categorization-rules.md`

- [ ] **Step 1: Create sheets schema reference**

Create `C:\Rupalprojects\Fintrak\setup\sheets-schema.md`:

```markdown
# Google Sheets Schema Reference

## Tab: Expenses (13 columns)

| Col | Header | Type | Example | Notes |
|-----|--------|------|---------|-------|
| A | ID | Auto-number | 1 | Not used yet — n8n appends without ID |
| B | Date | YYYY-MM-DD | 2026-05-08 | Extracted from OCR or today's date |
| C | Merchant | Text | Starbucks | First non-numeric line from OCR |
| D | Amount | Number | 250.00 | Largest number found in receipt |
| E | Currency | Text | INR | Always INR in Phase 1 |
| F | Category | Text | Food & Drink | From categorization rules |
| G | Type | Personal/Business | Personal | From rules + b: prefix override |
| H | Payment Method | Text | UPI | Detected from receipt or text |
| I | Notes | Text | Coffee | User caption or text after merchant |
| J | Receipt URL | URL | https://drive... | Google Drive view link |
| K | Source | Text | Telegram Photo | Telegram Photo / Telegram Text |
| L | Raw OCR | Text | (raw) | First 500 chars of OCR output |
| M | Timestamp | ISO datetime | 2026-05-08T10:30:00 | When logged to Sheets |

## Tab: Categories
Editable keyword lookup. n8n reads from code nodes, not from this tab directly.
To update categories, edit the categorization code in Workflow A (Parse OCR) and Workflow B (Categorize) nodes.

## Tab: Summary
Formula-driven. Auto-updates as Expenses rows are added. No manual editing needed.

## Tab: Config
Reference only. Values not read by n8n in Phase 1.
```

- [ ] **Step 2: Create categorization rules reference**

Create `C:\Rupalprojects\Fintrak\setup\categorization-rules.md`:

```markdown
# Categorization Rules Reference

Rules are applied in order. First match wins. Edit these in the "Categorize" Code nodes in n8n.

| Category | Type | Keywords (any match triggers) |
|----------|------|-------------------------------|
| Food & Drink | Personal | zomato, swiggy, starbucks, cafe, restaurant, biryani, pizza, food, eat, dominos, mcdonald, kfc, burger, dine |
| Transport | Personal | uber, ola, rapido, petrol, fuel, toll, parking, auto, cab, rickshaw, metro |
| Shopping | Personal | amazon, flipkart, myntra, mall, store, shop, meesho, retail |
| Bills & Utilities | Personal | electricity, water, broadband, jio, airtel, bsnl, recharge, bill, internet, wifi |
| Medical | Personal | pharmacy, hospital, doctor, clinic, medicine, apollo, medplus, health |
| Business - Software | Business | aws, notion, slack, zoom, adobe, subscription, saas, github, figma |
| Business - Travel | Business | flight, hotel, train ticket, business travel, airport |
| Business - Meals | Business | client lunch, vendor meeting, team lunch, business meal |
| Vendor Payment | Business | vendor, supplier, contractor, invoice, advance |
| Cash | Personal | atm, cash withdrawal |
| Other | Personal | catch-all |

## Business Override
Any text starting with `b:` forces Type = Business regardless of category rules.
Example: `b:250 lunch` → logs as Business even though "lunch" would normally be Personal.

## To Add a New Category
1. Open Workflow A in n8n editor
2. Click the "Categorize" Code node
3. Add a new rule object to the `rules` array:
   ```js
   { category: 'Your Category', type: 'Personal', keywords: ['keyword1', 'keyword2'] }
   ```
4. Do the same in Workflow B's "Categorize" node
5. Save and the workflow is live immediately
```

- [ ] **Step 3: Commit setup docs**

```powershell
git add setup/sheets-schema.md setup/categorization-rules.md
git commit -m "docs: add sheets schema and categorization rules reference"
```

---

## Task 12: End-to-End Test + Git Push

- [ ] **Step 1: Full end-to-end receipt test**

Take a real receipt photo from your phone. Open Telegram, send it to your bot.

Expected within 10 seconds:
1. Bot replies with extracted merchant, amount, category, type, payment method
2. Google Sheets Expenses tab has a new row
3. Google Drive Receipts folder has the image

If extraction is wrong (wrong amount or merchant), you can correct it manually in Google Sheets. The OCR quality improves with clearer photos.

- [ ] **Step 2: Full text test**

Send: `b:1500 vendor payment sharma enterprises invoice`

Expected: Bot replies confirming `Vendor Payment | Business | ₹1500`

- [ ] **Step 3: Full command test**

Send `/summary`. Expected: Shows totals including all your test entries.
Send `/search vendor`. Expected: Shows the vendor payment entry.
Send `/report`. Expected: Full category breakdown.

- [ ] **Step 4: Wait for daily cron OR manually trigger it**

Either wait until 9 PM, or in n8n open Workflow D and click "Execute Workflow". Expected: Telegram message with today's expense summary.

- [ ] **Step 5: Verify n8n restarts cleanly**

```powershell
docker compose restart
```

Wait 30 seconds, then send a test message to your bot. All workflows should still be active after restart (because `restart: unless-stopped` is set and workflows are persisted in the volume).

- [ ] **Step 6: Final commit and push to GitHub**

```powershell
git add .
git status
```

Verify `.env` is NOT in the list. Then:

```powershell
git commit -m "feat: complete fintrak phase 1 MVP"
git push -u origin main
```

- [ ] **Step 7: Verify GitHub repo**

Open https://github.com/rupal2k/fintrak — you should see all files. Confirm `.env` is NOT there (only `.env.example`).

---

## Troubleshooting Reference

### Telegram bot not responding
- Check n8n is running: `docker ps`
- Check workflow is Active (green toggle in n8n)
- Check credentials are saved (green checkmark in n8n Credentials)
- Check YOUR_TELEGRAM_CHAT_ID variable matches your actual chat ID

### OCR returning wrong amount
- OCR.Space Engine 2 works best with clear, well-lit photos
- Try taking photo in good lighting, flat on surface
- For printed receipts, Engine 2 is best; for handwritten, try Engine 1 (change `"OCREngine": "1"` in the OCR node)

### Google Sheets not updating
- Verify service account has Editor access on the sheet
- Verify GOOGLE_SHEET_ID variable is correct (no extra characters)
- Check n8n execution log (click the execution in n8n) for error details

### n8n crashes / won't start
```powershell
docker compose down
docker compose up -d
docker logs fintrak-n8n --tail 50
```

### Environment variables not working in n8n
Variables set via Settings → Variables are available as `$env.VARIABLE_NAME` in expressions. If a variable shows as empty, re-save it in the Variables panel and reload the workflow.
