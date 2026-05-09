# Fintrak — Claude Code Rules

Read this before touching any file. These rules are permanent and override all defaults.

---

## Response Style

- One sentence per update while working. End of task: two sentences max (what changed, what's next).
- No trailing summaries — Rupal reads the diff herself.
- Flag deviations from spec immediately. Never apply a silent workaround.
- Reference code locations as `file:line_number` (e.g. `setup.ps1:42`) — VS Code makes them clickable.

---

## Secrets — NEVER Commit

The following are gitignored and must stay that way:

| File | Why |
|------|-----|
| `.env` | Contains all credentials — password, tokens, API keys, sheet IDs |
| `setup/google-credentials.json` | Service account private key — full Google access |

Never suggest committing, echoing, or logging any value from `.env`. If a credential is needed for debugging, read it from `.env` and display only the first 4 characters.

---

## Architecture — Know Before Editing

```
User Phone
    │ Telegram message / photo / command
    ▼
n8n (Docker, localhost:5678, Basic Auth: admin / N8N_PASSWORD)
    ├── Workflow A — Receipt photo → OCR.Space → parse → Sheets + Drive
    ├── Workflow B — Text input → parse → Sheets
    ├── Workflow C — /commands → read Sheets → reply
    └── Workflow D — Cron 9 PM IST → daily summary → Telegram
```

**Ports:**
| Service | Port |
|---------|------|
| n8n UI + webhook | 5678 |

**n8n data** lives in Docker volume `n8n_data`. If you delete the volume, all workflows and credentials are lost. To recover: re-run `.\setup.ps1`.

---

## Docker Rules

**Restart n8n after config changes:**
```powershell
docker compose restart n8n
```

**View live logs:**
```powershell
docker compose logs n8n --follow --tail 50
```

**Never** run `docker compose down -v` — the `-v` flag deletes the `n8n_data` volume and destroys all workflows and credentials.

**Health check endpoint:** `http://localhost:5678/healthz`

---

## Workflow Editing Rules

Workflows live in two places: the n8n database (active) and `n8n-workflows/*.json` (source-controlled backup).

**After editing a workflow in the n8n UI, always export it:**
1. n8n → open workflow → ⋮ menu → Download
2. Save over the matching file in `n8n-workflows/`
3. Commit the updated JSON

**Workflow file map:**
| File | Workflow |
|------|----------|
| `n8n-workflows/workflow-a-receipt.json` | Workflow A — Receipt photo processor |
| `n8n-workflows/workflow-b-text.json` | Workflow B — Text entry processor |
| `n8n-workflows/workflow-c-commands.json` | Workflow C — Command handler |
| `n8n-workflows/workflow-d-daily-cron.json` | Workflow D — Daily 9 PM summary |

**Never** edit the JSON files and expect n8n to pick them up live — n8n reads from its internal DB. Changes to JSON files only take effect after re-import.

**To re-import a workflow:**
```powershell
docker cp n8n-workflows\workflow-a-receipt.json fintrak-n8n:/tmp/
docker exec fintrak-n8n n8n import:workflow --input=/tmp/workflow-a-receipt.json
```

---

## Categorization Rules

Rules live inside n8n Code nodes in Workflow A and Workflow B. **Not** read from Google Sheets.

- 12 categories, **first match wins**, case-insensitive
- Checks: raw OCR text + merchant name + user caption
- `b:` prefix in message → forces **Type = Business** regardless of category
- To add/edit a category: edit the `rules` array in the **Categorize** Code node in both Workflow A and Workflow B

See `setup/categorization-rules.md` for the full keyword table.

---

## Google Sheets Schema

**Spreadsheet name:** "Fintrak Expenses" — 4 tabs in this order:

| Tab | Purpose |
|-----|---------|
| `Expenses` | 13-column log — all expense rows |
| `Categories` | Keyword reference (display only — rules live in n8n) |
| `Summary` | Formula-driven monthly totals (auto-updates) |
| `Config` | Currency (INR), timezone (Asia/Kolkata), settings |

**Expenses tab columns (A–M):** ID · Date · Merchant · Amount · Currency · Category · Type · Payment Method · Notes · Receipt URL · Source · Raw OCR · Timestamp

Never change column order — n8n workflows address columns by letter. See `setup/sheets-schema.md` for full schema and formulas.

---

## Setup Wizard Rules

The wizard (`setup.ps1` / `setup.sh` / `setup.bat`) is **re-runnable** — it skips phases already completed.

| Phase | Skipped when |
|-------|-------------|
| 1 — Collect credentials | `.env` already has all keys |
| 2 — Start Docker | n8n container running and healthy |
| 3 — Import Google creds | Credentials already in n8n |
| 4 — Provision Sheet + Drive | `GOOGLE_SHEET_ID` already in `.env` |
| 5 — Import + activate workflows | All 4 workflows already active |

If a phase fails, fix the issue and re-run — it will resume from where it left off.

**Never** manually edit `.env` while the wizard is running.

---

## n8n API Access (for scripting)

Base auth header is required on all REST calls:
```powershell
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$env:N8N_PASSWORD"))
$headers = @{ Authorization = "Basic $b64"; "Content-Type" = "application/json" }
Invoke-RestMethod -Uri "http://localhost:5678/rest/workflows" -Headers $headers
```

**Key endpoints:**
| Action | Method + Path |
|--------|--------------|
| List workflows | `GET /rest/workflows` |
| Activate workflow | `POST /rest/workflows/{id}/activate` |
| List credentials | `GET /rest/credentials` |
| Set variable | `POST /rest/variables` |
| Trigger webhook | `POST /webhook/{path}` |

---

## Android (Termux) Deployment

`setup-android.sh` is the Android counterpart to `setup.sh`. Key differences:

| | Desktop (setup.sh / setup.ps1) | Android (setup-android.sh) |
|--|--|--|
| Runtime | Docker + n8n container | n8n via Node.js (no Docker) |
| Start command | `docker compose up -d` | `nohup n8n start &` |
| PID tracking | Docker manages it | `~/.n8n/fintrak.pid` |
| Logs | `docker compose logs n8n` | `tail -f ~/.n8n/fintrak.log` |
| Credential import | `docker exec n8n import:credentials` + CLI | REST API `POST /rest/credentials` |
| Workflow import | `docker exec n8n import:workflow` + CLI | `n8n import:workflow` CLI (while stopped) |
| Package manager | Docker Desktop | Termux `pkg` |
| Auto-start | Docker restart policy | Termux:Boot + `~/.termux/boot/` |

**Detection:** Script checks `$PREFIX` env variable — Termux always sets it to `/data/data/com.termux/files/usr`.

**n8n data dir on Android:** `~/.n8n/` (same as desktop, but Termux home = `/data/data/com.termux/files/home/`)

**Google JSON file path on Android:** User copies to phone storage. Accessible at `/sdcard/Download/filename.json` in Termux.

**Battery exemption:** Android kills background processes without it. Users must set Termux → Battery → Unrestricted.

**Stop/restart commands:**
```bash
kill $(cat ~/.n8n/fintrak.pid)        # stop
cd ~/fintrak && ./setup-android.sh    # restart / re-run
```

---

## Obsidian Vault

Vault location: `C:\Rupalprojects\Obsidian Vault\Fintrak\`

After significant work (new workflow, schema change, setup fix), update the vault without asking. Write to the appropriate note — Current Status, Architecture, Troubleshooting, or Checkpoint files.

---

## Git Rules

- Branch: `master`
- Remote: `https://github.com/rupal2k/fintrak.git`
- Never commit `.env` or `setup/google-credentials.json` (both gitignored)
- Never force-push to master
- Commit message style: `type: short description` (e.g. `fix: cross-platform sed in setup.sh`)
- All deployment changes (setup scripts, workflows, docker-compose) go to master — this is a public repo for end users to clone

---

## Environment Variables Reference

| Variable | Description |
|----------|-------------|
| `N8N_PASSWORD` | n8n admin UI password (you choose at setup) |
| `TELEGRAM_BOT_TOKEN` | From BotFather — `7234567890:AAFxxxxxxx` |
| `YOUR_TELEGRAM_CHAT_ID` | Your numeric Telegram ID from @userinfobot |
| `OCR_SPACE_API_KEY` | From ocr.space free account — starts with `K8` |
| `GOOGLE_SHEET_ID` | Long ID from Sheet URL between `/d/` and `/edit` |
| `GOOGLE_DRIVE_FOLDER_ID` | From Drive folder URL after `/folders/` |
