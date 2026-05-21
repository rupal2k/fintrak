# Setup and Deployment Architecture

## Entry Scripts

- `setup.bat`: Windows launcher that prefers Git Bash (`setup.sh`) then falls back to PowerShell (`setup.ps1`).
- `setup.sh`: Mac/Linux/Git Bash wizard.
- `setup.ps1`: Native Windows PowerShell wizard.
- `setup-android.sh`: Android Termux wizard (no Docker dependency).

## 5-Phase Setup Model (Desktop)

Implemented in `setup.sh` and `setup.ps1`:

1. Collect credentials and write `.env`.
2. Start n8n (`docker compose up -d`) and health-check.
3. Import Google credentials into n8n.
4. Import and run setup provisioning workflow:
- create sheet + tabs + drive folder
- share resources with user
- retrieve `GOOGLE_SHEET_ID` + `GOOGLE_DRIVE_FOLDER_ID`
5. Set n8n variables, import Telegram credential, import 4 main workflows, activate workflows, send test Telegram message.

## 5-Phase Setup Model (Android)

Implemented in `setup-android.sh`:

1. Install dependencies (`nodejs`, `n8n`, tools).
2. Collect credentials (interactive steps with guided prompts).
3. Start local n8n process and health-check.
4. Provision Google resources via setup workflow.
5. Import and activate main workflows, optional boot auto-start helper.

## Runtime Options

1. Docker mode (desktop/server)
- n8n runs as `fintrak-n8n` container.
- Exposes `http://localhost:5678`.
- Uses named volume `n8n_data`.

2. Android local mode
- n8n runs as background process with PID/log files in `~/.n8n/`.

## Reliability Patterns in Setup

- Idempotent checks for already-completed phases.
- Health checks before API calls.
- Temporary setup workflow import followed by cleanup.
- Activation checks for required workflows.
