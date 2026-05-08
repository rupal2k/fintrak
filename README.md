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
- Docker Desktop installed and running
- Telegram account
- Google account

### Setup

1. Clone this repo:
   ```
   git clone https://github.com/rupal2k/fintrak.git
   cd fintrak
   ```

2. Copy env template and fill in your values:
   ```
   cp .env.example .env
   ```
   See `setup/google-service-account.md` for how to get Google credentials.

3. Start n8n:
   ```
   docker compose up -d
   ```

4. Open http://localhost:5678 (admin / your N8N_PASSWORD)

5. Import all 4 workflows from `n8n-workflows/` folder

6. Add credentials in n8n (Telegram, Google Sheets, Google Drive)

7. Add environment variables in n8n Settings → Variables

8. Activate all workflows

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
├── docker-compose.yml          # n8n container
├── .env.example                # Environment template
├── n8n-workflows/              # Import these into n8n
│   ├── workflow-a-receipt.json # Photo processor
│   ├── workflow-b-text.json    # Text entry
│   ├── workflow-c-commands.json # /summary /search /report
│   └── workflow-d-daily-cron.json # 9 PM daily summary
└── setup/
    ├── sheets-schema.md        # Google Sheets column guide
    ├── categorization-rules.md # Expense category keywords
    └── google-service-account.md # Google API setup guide
```

## Future Phases

- Phase 2: AI categorization (OpenAI), voice input
- Phase 3: Dashboard, PDF reports, GST tracking
- Phase 4: Multi-user, mobile app
- Phase 5: Postgres database, accounting exports
