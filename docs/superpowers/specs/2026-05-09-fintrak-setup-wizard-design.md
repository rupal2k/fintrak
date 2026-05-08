# Fintrak Setup Wizard — Design Spec

**Date:** 2026-05-09
**Status:** Approved
**Scope:** End-user deployment wizard — replaces manual Checkpoint 1 & 2 steps with a single interactive script
**Author:** rupal2k

---

## 1. Goal

Replace the manual credential-gathering and n8n UI configuration steps (Checkpoints 1 & 2) with a single interactive setup script that any end user can run at deployment time. After running the script, Fintrak is fully live with no browser-based n8n configuration required.

**Target users:** Both the repo owner (Rupal, on new machines) and external users who clone the repo to run their own instance.

---

## 2. User Experience

The user runs one command from the project root:

**Windows:**
```powershell
.\setup.ps1
```

**Mac/Linux:**
```bash
./setup.sh
```

**What they see:**
```
╔══════════════════════════════════════╗
║         Fintrak Setup Wizard         ║
╚══════════════════════════════════════╝

Before we start, you'll need:
  • A Google service account JSON key file
  • A Telegram bot token (from @BotFather)
  • An OCR.Space API key (free at ocr.space/ocrapi)

[1/6] n8n admin password (min 8 chars): ••••••••
[2/6] Path to Google service account JSON: ~/Downloads/fintrak-key.json ✓
[3/6] Your personal Google email (to access the sheet): rupal@gmail.com
[4/6] Telegram bot token: 7234567890:AAFxxxxxxx
[5/6] Your Telegram chat ID (from @userinfobot): 123456789
[6/6] OCR.Space API key: K8xxxxxxx

✓ Credentials saved
✓ Starting n8n... (this takes ~20 seconds)
✓ n8n is ready
✓ Configuring Google credentials
✓ Creating "Fintrak Expenses" spreadsheet (4 tabs + formulas)
✓ Creating Google Drive folder "Fintrak/Receipts"
✓ Sharing sheet and folder with rupal@gmail.com
✓ Importing and activating 4 workflows
✓ Sending test message to your Telegram bot

🎉 Fintrak is live!
   n8n dashboard : http://localhost:5678  (admin / your-password)
   Google Sheet  : https://docs.google.com/spreadsheets/d/...
   Telegram bot  : Send a receipt photo to get started
```

Total time from command to live: ~2–3 minutes.

---

## 3. Prerequisites (user must have before running)

The script checks for these at startup and exits with a clear message if missing:

| Prerequisite | How to get it | Checked how |
|-------------|--------------|-------------|
| Docker Desktop running | docker.com/get-started | `docker info` exit code |
| Google service account JSON key | Google Cloud Console → IAM → Service Accounts → Keys | File path prompt with existence check |
| Telegram bot token | @BotFather in Telegram → /newbot | Prompted, format-validated (`\d+:[\w-]{35,}`) |
| Telegram chat ID | @userinfobot in Telegram | Prompted, validated (numeric) |
| OCR.Space API key | ocr.space/ocrapi free signup | Prompted, format-validated (`K8[\w]+`) |

The Google service account must have the following APIs enabled in its project before setup runs:
- Google Sheets API
- Google Drive API

The script cannot verify this in advance — it will fail at Phase 3 with a clear message if APIs are not enabled.

---

## 4. Files Added / Modified

```
fintrak/
├── setup.ps1                              ← NEW: Windows PowerShell setup script
├── setup.sh                               ← NEW: Mac/Linux bash setup script
├── docker-compose.yml                     ← MODIFIED: add ./setup:/setup:ro volume mount
├── n8n-workflows/
│   └── workflow-setup.json                ← NEW: one-time Google provisioning workflow
└── setup/
    ├── google-service-account.md          ← existing (no change)
    ├── sheets-schema.md                   ← existing (no change)
    ├── categorization-rules.md            ← existing (no change)
    └── credentials-template/
        ├── google-sheets-cred.json        ← NEW: n8n credential import template
        ├── google-drive-cred.json         ← NEW: n8n credential import template
        └── telegram-cred.json             ← NEW: n8n credential import template
```

`.env.example` and `README.md` are updated to reflect the new single-command setup.

---

## 5. Setup Flow (5 Phases)

### Phase 1 — Collect credentials

Prompt for all 6 inputs with inline validation. Re-prompt on invalid input (up to 3 attempts per field, then exit with a helpful message).

| Input | Validation |
|-------|-----------|
| n8n password | Min 8 chars, no spaces |
| Google JSON path | File exists, valid JSON, contains `client_email` and `private_key` |
| Personal Google email | Basic email format (`@` present) |
| Telegram bot token | Matches `\d{8,10}:[\w-]{35,}` |
| Telegram chat ID | Numeric only |
| OCR.Space key | Starts with `K8`, min 10 chars |

On success: write `.env` with all 6 values plus placeholder `GOOGLE_SHEET_ID=` and `GOOGLE_DRIVE_FOLDER_ID=` (filled in Phase 4).

### Phase 2 — Launch n8n

```
docker compose up -d
```

Poll `GET http://localhost:5678/healthz` every 2 seconds up to 60 seconds. If healthy: proceed. If timeout: print last 20 lines of `docker compose logs n8n` and exit with troubleshooting hint.

### Phase 3 — Configure Google credentials in n8n

1. Build `setup/credentials-template/google-sheets-cred.json` by injecting `client_email` and `private_key` from the user's JSON file into the template.
2. Build `setup/credentials-template/google-drive-cred.json` the same way.
3. Copy both files into the running container via `docker cp`.
4. Import via n8n CLI:
   ```
   docker exec fintrak-n8n n8n import:credentials --input=/tmp/google-sheets-cred.json
   docker exec fintrak-n8n n8n import:credentials --input=/tmp/google-drive-cred.json
   ```
5. Delete the temporary files from the container.

### Phase 4 — Provision Google Sheet and Drive folder

1. Copy `n8n-workflows/workflow-setup.json` into the container, import it via `docker exec`.
2. Activate the setup workflow via n8n REST API (basic auth: `admin` / `N8N_PASSWORD`).
3. Trigger the setup workflow via its webhook: `POST /webhook/fintrak-setup` with body:
   ```json
   {
     "userEmail": "<personal google email>",
     "sheetName": "Fintrak Expenses",
     "driveFolderName": "Fintrak/Receipts"
   }
   ```
4. The setup workflow (n8n built-in Google nodes) performs:
   - Creates Google Sheet "Fintrak Expenses" via Sheets API
   - Creates all 4 tabs (Expenses, Categories, Summary, Config) with headers and formulas
   - Creates Drive folder "Fintrak/Receipts"
   - Shares the sheet with the user's personal Google email (Editor)
   - Shares the Drive folder with the user's personal Google email (Editor)
   - Returns `{ "sheetId": "...", "driveFolderId": "..." }` as the webhook response
5. Script receives the IDs, updates `.env` with `GOOGLE_SHEET_ID` and `GOOGLE_DRIVE_FOLDER_ID`.
6. Deactivate and delete the setup workflow via n8n REST API (cleanup).

### Phase 5 — Activate all workflows

1. Set 5 n8n Variables via `POST /rest/variables` (basic auth):
   - `YOUR_TELEGRAM_CHAT_ID`
   - `TELEGRAM_BOT_TOKEN`
   - `OCR_SPACE_API_KEY`
   - `GOOGLE_SHEET_ID`
   - `GOOGLE_DRIVE_FOLDER_ID`

2. Build and import Telegram credential:
   ```
   docker exec fintrak-n8n n8n import:credentials --input=/tmp/telegram-cred.json
   ```

3. Copy and import all 4 main workflows:
   ```
   docker cp n8n-workflows/workflow-a-receipt.json fintrak-n8n:/tmp/
   docker exec fintrak-n8n n8n import:workflow --input=/tmp/workflow-a-receipt.json
   docker cp n8n-workflows/workflow-b-text.json fintrak-n8n:/tmp/
   docker exec fintrak-n8n n8n import:workflow --input=/tmp/workflow-b-text.json
   docker cp n8n-workflows/workflow-c-commands.json fintrak-n8n:/tmp/
   docker exec fintrak-n8n n8n import:workflow --input=/tmp/workflow-c-commands.json
   docker cp n8n-workflows/workflow-d-daily-cron.json fintrak-n8n:/tmp/
   docker exec fintrak-n8n n8n import:workflow --input=/tmp/workflow-d-daily-cron.json
   ```

4. Activate all 4 workflows via `PATCH /rest/workflows/{id}` with `{ "active": true }`.

5. Send a Telegram test message via the bot token to confirm the bot is live:
   ```
   POST https://api.telegram.org/bot{TOKEN}/sendMessage
   { "chat_id": "...", "text": "✅ Fintrak is live! Send me a receipt photo." }
   ```

6. Print the final success summary with n8n URL and Google Sheet URL.

---

## 6. Re-runnable Design

The script is safe to re-run after a partial failure. Before each phase it checks:

| Phase | Skip condition |
|-------|---------------|
| 1 (Collect) | `.env` exists, all 6 required keys present and non-empty |
| 2 (Launch) | `docker ps` shows `fintrak-n8n` with status `Up` and healthcheck passing |
| 3 (Google creds) | n8n REST API returns existing credentials named "Fintrak Google Sheets" and "Fintrak Google Drive" |
| 4 (Provision) | `.env` has non-empty `GOOGLE_SHEET_ID` and `GOOGLE_DRIVE_FOLDER_ID` |
| 5 (Activate) | n8n REST API returns all 4 main workflows in active state |

If a phase is skipped, the script prints `✓ [Phase name] already complete — skipping`.

---

## 7. Error Handling

| Failure point | Script behaviour |
|--------------|-----------------|
| Docker not running | "Docker is not running. Start Docker Desktop and re-run." → exit 1 |
| JSON file not found or invalid | Re-prompt up to 3 times, then exit with path tip |
| n8n unhealthy after 60s | Print last 20 lines of container logs → exit 1 |
| Google APIs not enabled (403) | "Enable Sheets API and Drive API in Google Cloud Console for this service account project." → exit 1 |
| Sheet creation fails | Show n8n execution error, print recovery instructions (n8n is left running for manual access) → exit 1 |
| Telegram token rejected | "Token not accepted by Telegram. Check with @BotFather." → exit 1 |
| n8n CLI import fails | Show stderr output → exit 1 |

All error messages include the next action the user should take, not just what went wrong.

---

## 8. docker-compose.yml Change

No changes required. All file transfers between the host and the n8n container use `docker cp`, which works without volume mounts.

For dynamically generated credential files (with injected secrets), the script:
1. Writes the file to the OS temp directory (`$env:TEMP` on Windows, `/tmp` on Mac/Linux)
2. `docker cp`s it into the container at `/tmp/`
3. Runs the n8n CLI import
4. Deletes the file from both the container and the host temp directory immediately after import

This avoids leaving secrets on disk any longer than necessary and requires no changes to `docker-compose.yml`.

---

## 9. Credential Template Format (n8n CLI import)

n8n CLI expects credentials in this JSON envelope:

```json
[
  {
    "name": "Fintrak Google Sheets",
    "type": "googleSheetsServiceAccount",
    "data": {
      "email": "{{CLIENT_EMAIL}}",
      "privateKey": "{{PRIVATE_KEY}}"
    }
  }
]
```

The setup script performs a simple string substitution of `{{CLIENT_EMAIL}}` and `{{PRIVATE_KEY}}` from the parsed JSON key file before importing. The templates live in `setup/credentials-template/` and are committed to the repo (with placeholders, no real values).

---

## 10. The Fintrak Setup Workflow (workflow-setup.json)

A purpose-built n8n workflow triggered by a single webhook call. It runs once during setup and is deleted immediately after.

```
[Webhook: POST /webhook/fintrak-setup]
    → [Google Sheets: Create Spreadsheet] "Fintrak Expenses"
    → [Google Sheets: Create Sheet] tab "Expenses" with 13 column headers
    → [Google Sheets: Create Sheet] tab "Categories" with keyword data
    → [Google Sheets: Create Sheet] tab "Summary" with SUMPRODUCT formulas
    → [Google Sheets: Create Sheet] tab "Config" with currency/timezone defaults
    → [Google Drive: Create Folder] "Fintrak/Receipts"
    → [Google Drive: Share File] sheet → userEmail (Editor)
    → [Google Drive: Share Folder] folder → userEmail (Editor)
    → [Respond to Webhook] { "sheetId": "...", "driveFolderId": "..." }
```

This workflow uses the "Fintrak Google Sheets" and "Fintrak Google Drive" credentials imported in Phase 3.

---

## 11. What Changes for Existing Users (Rupal)

The existing manual setup flow (Checkpoint 1 & 2 docs) remains in the repo as reference, but `README.md` is updated to lead with `setup.ps1` / `setup.sh` as the primary deployment path. Existing deployments are unaffected — the script is additive.

---

## 12. Out of Scope

- GUI/web-based wizard (Option C — not chosen)
- Multi-user or tenant-aware setup
- Automated Google Cloud project creation or API enablement (user must enable Sheets + Drive APIs manually before running the script)
- Windows Subsystem for Linux (WSL) — `setup.ps1` covers Windows natively
- Uninstall / teardown script
