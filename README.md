# Fintrak — Personal + Business Payment Tracker

Telegram-first expense tracking. Send a receipt photo → auto-logged to Google Sheets. Zero monthly cost.

## How It Works

```
You → Telegram (photo/text) → n8n → OCR.Space → Google Sheets + Drive
```

- Send a **receipt photo** → amount, merchant, category extracted automatically
- Send a **text message** like `250 starbucks coffee` → logged instantly
- Use `b:` prefix for business: `b:500 vendor payment xyz`
- Use `/summary`, `/search`, `/report` commands

## Quick Start

### Prerequisites

Before running setup, have these ready:

| What | Where to get it |
|------|----------------|
| Docker Desktop (running) | [docker.com/get-started](https://www.docker.com/get-started) |
| Google service account JSON key | [Google Cloud Console](https://console.cloud.google.com) → IAM → Service Accounts → Keys (enable Sheets + Drive APIs first — see `setup/google-service-account.md`) |
| Telegram bot token | `@BotFather` in Telegram → `/newbot` |
| Telegram chat ID | `@userinfobot` in Telegram |
| OCR.Space API key | [ocr.space/ocrapi](https://ocr.space/ocrapi) (free, no credit card) |

### Setup (Automated — Recommended)

1. Clone this repo:
   ```bash
   git clone https://github.com/rupal2k/fintrak.git
   cd fintrak
   ```

2. Run the setup wizard:

   **Windows (PowerShell):**
   ```powershell
   .\setup.ps1
   ```

   **Windows (Git Bash / double-click):**
   ```bat
   setup.bat
   ```

   **Mac/Linux:**
   ```bash
   chmod +x setup.sh && ./setup.sh
   ```

The wizard collects your credentials, starts n8n, creates the Google Sheet and Drive folder, and activates all 4 workflows automatically. Takes ~2–3 minutes.

### Setup (Manual — Alternative)

If you prefer to configure services yourself, follow the step-by-step guides in `setup/`:
- `setup/google-service-account.md` — Google API credentials
- `setup/sheets-schema.md` — Google Sheets structure
- Then: `docker compose up -d` → open http://localhost:5678 → import workflows manually

## Usage

| Input | Example | Result |
|-------|---------|--------|
| Receipt photo | Send any receipt image | Auto-extracted + logged |
| Text entry | `250 starbucks coffee` | Logged as Personal |
| Business entry | `b:500 vendor xyz` | Logged as Business |
| Payment method | `cash 300 lunch` | Method = Cash |
| Summary | `/summary` | This month totals |
| Search | `/search coffee` | Matching entries |
| Report | `/report` | Category breakdown |

## Stack

| Tool | Role | Cost |
|------|------|------|
| n8n (Docker) | Automation | Free |
| Telegram Bot | User interface | Free |
| Google Sheets | Database | Free |
| Google Drive | Receipt storage | Free (15 GB) |
| OCR.Space | Text extraction | Free (25K req/month) |

**Total: ₹0/month**

## Files

```
fintrak/
├── setup.ps1                   # Windows setup wizard (run this first)
├── setup.sh                    # Mac/Linux setup wizard (run this first)
├── docker-compose.yml          # n8n container
├── .env.example                # Environment template
├── n8n-workflows/
│   ├── workflow-a-receipt.json     # Photo processor
│   ├── workflow-b-text.json        # Text entry
│   ├── workflow-c-commands.json    # /summary /search /report
│   ├── workflow-d-daily-cron.json  # 9 PM daily summary
│   └── workflow-setup.json         # One-time provisioning (auto-deleted after setup)
└── setup/
    ├── credentials-template/       # n8n credential templates (placeholders only)
    ├── sheets-schema.md            # Google Sheets column guide
    ├── categorization-rules.md     # Expense category keywords
    └── google-service-account.md   # Google API setup guide
```

## Future Phases

- Phase 2: AI categorization (OpenAI), voice input
- Phase 3: Dashboard, PDF reports, GST tracking
- Phase 4: Multi-user, mobile app
- Phase 5: Postgres database, accounting exports
