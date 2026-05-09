#!/usr/bin/env bash
# Fintrak Setup Wizard - Android (Termux)
# Runs n8n directly via Node.js — no Docker required.
# Re-runnable: skips already-completed phases.
#
# Prerequisites (do this once before running):
#   1. Install Termux from F-Droid: https://f-droid.org/packages/com.termux/
#   2. In Termux: pkg update && pkg install -y git
#   3. git clone https://github.com/rupal2k/fintrak.git ~/fintrak
#   4. cd ~/fintrak && chmod +x setup-android.sh && ./setup-android.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$SCRIPT_DIR/.env"
N8N_PID_FILE="$HOME/.n8n/fintrak.pid"
N8N_LOG_FILE="$HOME/.n8n/fintrak.log"

# ── Termux check ─────────────────────────────────────────────────────────────
if [ -z "${PREFIX:-}" ] || [[ "$PREFIX" != *"termux"* ]]; then
    echo "This script is for Android (Termux) only."
    echo "On Windows: run setup.bat or setup.ps1"
    echo "On Mac/Linux: run setup.sh"
    exit 1
fi

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; MAGENTA='\033[0;35m'; NC='\033[0m'

write_success() { printf "${GREEN}✓ %s${NC}\n" "$1"; }
write_fail()    { printf "${RED}✗ %s${NC}\n" "$1"; }
write_info()    { printf "${CYAN}  %s${NC}\n" "$1"; }
write_warn()    { printf "${YELLOW}⚠ %s${NC}\n" "$1"; }
write_phase()   { printf "\n${MAGENTA}══ %s ══${NC}\n" "$1"; }

# ── Banner ───────────────────────────────────────────────────────────────────
printf "\n"
printf "${CYAN}╔══════════════════════════════════════╗${NC}\n"
printf "${CYAN}║   Fintrak Setup Wizard (Android)     ║${NC}\n"
printf "${CYAN}╚══════════════════════════════════════╝${NC}\n"
printf "\n"

# ── Helpers ──────────────────────────────────────────────────────────────────
read_env_key() {
    local key="$1"
    if [ -f "$ENV_PATH" ]; then
        grep -E "^${key}=(.*)$" "$ENV_PATH" | head -1 | sed "s/^${key}=//"
    fi
}

n8n_auth_header() {
    python3 -c "import base64; print('Authorization: Basic ' + base64.b64encode(b'admin:$1').decode())"
}

n8n_is_running() {
    if [ -f "$N8N_PID_FILE" ]; then
        local pid
        pid=$(cat "$N8N_PID_FILE")
        kill -0 "$pid" 2>/dev/null
    else
        return 1
    fi
}

start_n8n() {
    local pass="$1"
    write_info "Starting n8n..."
    mkdir -p "$HOME/.n8n"
    N8N_BASIC_AUTH_ACTIVE=true \
    N8N_BASIC_AUTH_USER=admin \
    N8N_BASIC_AUTH_PASSWORD="$pass" \
    GENERIC_TIMEZONE=Asia/Kolkata \
    TZ=Asia/Kolkata \
    N8N_PORT=5678 \
    N8N_HOST=localhost \
    N8N_PROTOCOL=http \
    WEBHOOK_URL=http://localhost:5678/ \
    N8N_LOG_LEVEL=info \
    EXECUTIONS_DATA_PRUNE=true \
    EXECUTIONS_DATA_MAX_AGE=168 \
    nohup n8n start > "$N8N_LOG_FILE" 2>&1 &
    echo $! > "$N8N_PID_FILE"
}

stop_n8n() {
    if n8n_is_running; then
        write_info "Stopping n8n..."
        kill "$(cat "$N8N_PID_FILE")" 2>/dev/null || true
        sleep 3
        rm -f "$N8N_PID_FILE"
    fi
}

wait_n8n_healthy() {
    write_info "Waiting for n8n to be ready (may take 2-3 minutes on first run)..."
    for i in $(seq 1 45); do
        if curl -sf http://localhost:5678/healthz &>/dev/null; then
            return 0
        fi
        sleep 5
    done
    return 1
}

prompt_validated() {
    local label="$1" max="$2" varname="$3" validator_fn="$4"
    local attempt=0
    while [ $attempt -lt "$max" ]; do
        read -r -p "$label: " value
        local err
        err=$($validator_fn "$value")
        if [ -z "$err" ]; then
            eval "$varname='$value'"
            return 0
        fi
        write_fail "$err"
        attempt=$((attempt + 1))
        [ $attempt -ge "$max" ] && { write_fail "Too many failed attempts. Exiting."; exit 1; }
    done
}

prompt_secret() {
    local label="$1" max="$2" varname="$3" validator_fn="$4"
    local attempt=0
    while [ $attempt -lt "$max" ]; do
        read -r -s -p "$label: " value; printf "\n"
        local err
        err=$($validator_fn "$value")
        if [ -z "$err" ]; then
            eval "$varname='$value'"
            return 0
        fi
        write_fail "$err"
        attempt=$((attempt + 1))
        [ $attempt -ge "$max" ] && { write_fail "Too many failed attempts. Exiting."; exit 1; }
    done
}

# Validators
validate_password()       { [ ${#1} -lt 8 ] && echo "Min 8 characters" || echo ""; }
validate_email()          { [[ "$1" != *"@"* ]] && echo "Invalid email" || echo ""; }
validate_telegram_token() { [[ "$1" =~ ^[0-9]{8,10}:[A-Za-z0-9_-]{35,}$ ]] && echo "" || echo "Invalid format (expected: 123456789:ABC...)"; }
validate_chat_id()        { [[ "$1" =~ ^[0-9]+$ ]] && echo "" || echo "Must be numeric only"; }
validate_ocr_key()        { [[ "$1" =~ ^K8[A-Za-z0-9]{8,}$ ]] && echo "" || echo "Invalid format (should start with K8)"; }
validate_json_path() {
    local p="${1/#\~/$HOME}"
    [ ! -f "$p" ] && echo "File not found: $p" && return
    python3 -c "
import json, sys
try:
    d = json.load(open('$p'))
    if 'client_email' not in d or 'private_key' not in d:
        print('Missing client_email or private_key in JSON')
    else:
        print('')
except Exception as e:
    print('Invalid JSON: {}'.format(e))
" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 0 — Install required packages
# ═══════════════════════════════════════════════════════════════════════════
write_phase "Phase 0: Checking Packages"

pkgs_needed=()
command -v node  &>/dev/null || pkgs_needed+=(nodejs)
command -v curl  &>/dev/null || pkgs_needed+=(curl)
command -v python3 &>/dev/null || pkgs_needed+=(python)

if [ ${#pkgs_needed[@]} -gt 0 ]; then
    write_info "Installing: ${pkgs_needed[*]}"
    pkg install -y "${pkgs_needed[@]}" 2>/dev/null
    write_success "Packages installed"
else
    write_success "All packages present"
fi

if ! command -v n8n &>/dev/null; then
    write_info "Installing n8n (this takes 5-10 minutes on first run)..."
    npm install -g n8n 2>/dev/null
    write_success "n8n installed: $(n8n --version 2>/dev/null | head -1)"
else
    write_success "n8n already installed: $(n8n --version 2>/dev/null | head -1)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1 — Collect credentials
# ═══════════════════════════════════════════════════════════════════════════
write_phase "Phase 1: Collecting Credentials"

N8N_PASSWORD=$(read_env_key "N8N_PASSWORD")
TELEGRAM_BOT_TOKEN=$(read_env_key "TELEGRAM_BOT_TOKEN")
YOUR_TELEGRAM_CHAT_ID=$(read_env_key "YOUR_TELEGRAM_CHAT_ID")
OCR_SPACE_API_KEY=$(read_env_key "OCR_SPACE_API_KEY")

if [ -n "$N8N_PASSWORD" ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && \
   [ -n "$YOUR_TELEGRAM_CHAT_ID" ] && [ -n "$OCR_SPACE_API_KEY" ]; then
    write_success "Phase 1 already complete — skipping"
    GOOGLE_USER_EMAIL=$(read_env_key "GOOGLE_USER_EMAIL")
    GOOGLE_CLIENT_EMAIL=$(read_env_key "GOOGLE_CLIENT_EMAIL")
    GOOGLE_PRIVATE_KEY=$(read_env_key "GOOGLE_PRIVATE_KEY")
else
    write_info ""
    write_info "You will need:"
    write_info "  • Google service account JSON key file (copy to phone storage)"
    write_info "  • Telegram bot token (from @BotFather)"
    write_info "  • OCR.Space API key (free at ocr.space/ocrapi)"
    write_info ""

    prompt_secret "[1/6] n8n admin password (min 8 chars)" 3 N8N_PASSWORD validate_password

    write_info "Tip: Copy your Google JSON file to phone storage first."
    write_info "     Then drag it into Termux or use the path: /sdcard/Downloads/filename.json"
    while true; do
        read -r -p "[2/6] Path to Google service account JSON: " json_path
        json_path="${json_path/#\~/$HOME}"
        [ ! -f "$json_path" ] && write_fail "File not found: $json_path" && continue
        err=$(validate_json_path "$json_path")
        [ -n "$err" ] && write_fail "$err" && continue
        GOOGLE_CLIENT_EMAIL=$(python3 -c "import json; print(json.load(open('$json_path'))['client_email'])")
        GOOGLE_PRIVATE_KEY=$(python3 -c "import json; print(json.load(open('$json_path'))['private_key'])")
        write_success "Google credentials validated"
        break
    done

    prompt_validated "[3/6] Your personal Google email" 3 GOOGLE_USER_EMAIL validate_email
    prompt_validated "[4/6] Telegram bot token" 3 TELEGRAM_BOT_TOKEN validate_telegram_token
    prompt_validated "[5/6] Your Telegram chat ID (numeric)" 3 YOUR_TELEGRAM_CHAT_ID validate_chat_id
    prompt_validated "[6/6] OCR.Space API key" 3 OCR_SPACE_API_KEY validate_ocr_key

    cat > "$ENV_PATH" << EOF
N8N_PASSWORD=${N8N_PASSWORD}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
YOUR_TELEGRAM_CHAT_ID=${YOUR_TELEGRAM_CHAT_ID}
OCR_SPACE_API_KEY=${OCR_SPACE_API_KEY}
GOOGLE_USER_EMAIL=${GOOGLE_USER_EMAIL}
GOOGLE_CLIENT_EMAIL=${GOOGLE_CLIENT_EMAIL}
GOOGLE_PRIVATE_KEY=${GOOGLE_PRIVATE_KEY}
GOOGLE_SHEET_ID=
GOOGLE_DRIVE_FOLDER_ID=
EOF
    write_success "Credentials saved to .env"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2 — Start n8n
# ═══════════════════════════════════════════════════════════════════════════
write_phase "Phase 2: Starting n8n"

if n8n_is_running && curl -sf http://localhost:5678/healthz &>/dev/null; then
    write_success "n8n already running — skipping"
else
    [ -f "$N8N_PID_FILE" ] && rm -f "$N8N_PID_FILE"
    start_n8n "$N8N_PASSWORD"

    if ! wait_n8n_healthy; then
        write_fail "n8n did not become healthy. Last 20 lines of log:"
        tail -20 "$N8N_LOG_FILE" 2>/dev/null || true
        exit 1
    fi
    write_success "n8n is ready at http://localhost:5678"
fi

AUTH_HEADER=$(n8n_auth_header "$N8N_PASSWORD")

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3 — Configure Google credentials in n8n
# ═══════════════════════════════════════════════════════════════════════════
write_phase "Phase 3: Configuring Google Credentials"

creds_response=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/credentials 2>/dev/null || echo '{"data":[]}')
sheets_exists=$(echo "$creds_response" | python3 -c "import json,sys; d=json.load(sys.stdin); print('yes' if any(c['name']=='Fintrak Google Sheets' for c in d.get('data',[])) else '')" 2>/dev/null)
drive_exists=$(echo "$creds_response"  | python3 -c "import json,sys; d=json.load(sys.stdin); print('yes' if any(c['name']=='Fintrak Google Drive'  for c in d.get('data',[])) else '')" 2>/dev/null)

if [ -n "$sheets_exists" ] && [ -n "$drive_exists" ]; then
    write_success "Phase 3 already complete — skipping"
else
    # Build credential JSON bodies using Python (handles private key newline encoding)
    gs_body=$(python3 -c "
import json
body = {
    'name': 'Fintrak Google Sheets',
    'type': 'googleSheetsServiceAccount',
    'data': {'email': '''${GOOGLE_CLIENT_EMAIL}''', 'privateKey': '''${GOOGLE_PRIVATE_KEY}'''}
}
print(json.dumps(body))
")
    gd_body=$(python3 -c "
import json
body = {
    'name': 'Fintrak Google Drive',
    'type': 'googleDriveServiceAccount',
    'data': {'email': '''${GOOGLE_CLIENT_EMAIL}''', 'privateKey': '''${GOOGLE_PRIVATE_KEY}'''}
}
print(json.dumps(body))
")
    tg_body=$(python3 -c "
import json
body = {
    'name': 'Fintrak Telegram Bot',
    'type': 'telegramApi',
    'data': {'accessToken': '${TELEGRAM_BOT_TOKEN}'}
}
print(json.dumps(body))
")

    curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
        -d "$gs_body" http://localhost:5678/rest/credentials >/dev/null 2>&1
    write_success "Google Sheets credential created"

    curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
        -d "$gd_body" http://localhost:5678/rest/credentials >/dev/null 2>&1
    write_success "Google Drive credential created"

    curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
        -d "$tg_body" http://localhost:5678/rest/credentials >/dev/null 2>&1
    write_success "Telegram credential created"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4 — Provision Google Sheet + Drive folder
# ═══════════════════════════════════════════════════════════════════════════
write_phase "Phase 4: Provisioning Google Resources"

GOOGLE_SHEET_ID=$(read_env_key "GOOGLE_SHEET_ID")
GOOGLE_DRIVE_FOLDER_ID=$(read_env_key "GOOGLE_DRIVE_FOLDER_ID")

if [ -n "$GOOGLE_SHEET_ID" ] && [ -n "$GOOGLE_DRIVE_FOLDER_ID" ]; then
    write_success "Phase 4 already complete — skipping"
else
    # Stop n8n → import setup workflow → restart
    stop_n8n
    sleep 2
    n8n import:workflow --input="$SCRIPT_DIR/n8n-workflows/workflow-setup.json" >/dev/null 2>&1
    start_n8n "$N8N_PASSWORD"
    wait_n8n_healthy || { write_fail "n8n failed to restart"; exit 1; }

    # Find + activate setup workflow
    all_wfs=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null || echo '{"data":[]}')
    setup_wf_id=$(echo "$all_wfs" | python3 -c "
import json, sys
data = json.load(sys.stdin).get('data', [])
match = [w for w in data if 'Provision Google' in w.get('name', '')]
print(match[0]['id'] if match else '')
" 2>/dev/null)

    [ -z "$setup_wf_id" ] && write_fail "Could not find setup workflow" && exit 1

    curl -sf -X POST -H "$AUTH_HEADER" "http://localhost:5678/rest/workflows/$setup_wf_id/activate" >/dev/null 2>&1
    write_info "Running setup workflow (creating Sheet + Drive folder)..."

    result=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"userEmail\":\"${GOOGLE_USER_EMAIL}\",\"sheetName\":\"Fintrak Expenses\",\"driveFolderName\":\"Fintrak/Receipts\"}" \
        http://localhost:5678/webhook/fintrak-setup 2>/dev/null || echo '{}')

    GOOGLE_SHEET_ID=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('sheetId',''))" 2>/dev/null)
    GOOGLE_DRIVE_FOLDER_ID=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('driveFolderId',''))" 2>/dev/null)

    if [ -z "$GOOGLE_SHEET_ID" ] || [ -z "$GOOGLE_DRIVE_FOLDER_ID" ]; then
        write_fail "Setup workflow did not return Sheet ID or Folder ID"
        write_info "Check n8n at http://localhost:5678 and ensure Google APIs are enabled."
        exit 1
    fi

    write_success "Google Sheet created: $GOOGLE_SHEET_ID"
    write_success "Drive folder created: $GOOGLE_DRIVE_FOLDER_ID"

    python3 - "$ENV_PATH" "$GOOGLE_SHEET_ID" "$GOOGLE_DRIVE_FOLDER_ID" << 'PYEOF'
import sys, re
path, sheet_id, folder_id = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, 'r') as f:
    content = f.read()
content = re.sub(r'^GOOGLE_SHEET_ID=.*$',        'GOOGLE_SHEET_ID='        + sheet_id,  content, flags=re.MULTILINE)
content = re.sub(r'^GOOGLE_DRIVE_FOLDER_ID=.*$', 'GOOGLE_DRIVE_FOLDER_ID=' + folder_id, content, flags=re.MULTILINE)
with open(path, 'w') as f:
    f.write(content)
PYEOF

    # Cleanup setup workflow
    curl -sf -X POST -H "$AUTH_HEADER" "http://localhost:5678/rest/workflows/$setup_wf_id/deactivate" >/dev/null 2>&1 || true
    curl -sf -X DELETE -H "$AUTH_HEADER" "http://localhost:5678/rest/workflows/$setup_wf_id" >/dev/null 2>&1 || true
    write_info "Setup workflow cleaned up"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5 — Set variables + import + activate workflows
# ═══════════════════════════════════════════════════════════════════════════
write_phase "Phase 5: Activating Workflows"

all_wfs=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null || echo '{"data":[]}')
active_count=$(echo "$all_wfs" | python3 -c "
import json, sys, re
data = json.load(sys.stdin).get('data', [])
print(sum(1 for w in data if w.get('active') and re.match(r'Fintrak [A-D]', w.get('name',''))))
" 2>/dev/null)

if [ "${active_count:-0}" -ge 4 ]; then
    write_success "Phase 5 already complete — skipping"
else
    # Set n8n Variables
    GOOGLE_SHEET_ID=$(read_env_key "GOOGLE_SHEET_ID")
    GOOGLE_DRIVE_FOLDER_ID=$(read_env_key "GOOGLE_DRIVE_FOLDER_ID")

    write_info "Setting n8n variables..."
    for kv in \
        "YOUR_TELEGRAM_CHAT_ID:${YOUR_TELEGRAM_CHAT_ID}" \
        "TELEGRAM_BOT_TOKEN:${TELEGRAM_BOT_TOKEN}" \
        "OCR_SPACE_API_KEY:${OCR_SPACE_API_KEY}" \
        "GOOGLE_SHEET_ID:${GOOGLE_SHEET_ID}" \
        "GOOGLE_DRIVE_FOLDER_ID:${GOOGLE_DRIVE_FOLDER_ID}"; do
        key="${kv%%:*}"; val="${kv#*:}"
        curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
            -d "{\"key\":\"$key\",\"value\":\"$val\"}" \
            http://localhost:5678/rest/variables >/dev/null 2>&1 || true
    done
    write_success "n8n variables set"

    # Stop n8n → import 4 workflows → restart
    stop_n8n
    sleep 2
    write_info "Importing workflows..."
    for wf in workflow-a-receipt workflow-b-text workflow-c-commands workflow-d-daily-cron; do
        n8n import:workflow --input="$SCRIPT_DIR/n8n-workflows/${wf}.json" >/dev/null 2>&1
    done
    write_success "Workflows imported"

    start_n8n "$N8N_PASSWORD"
    wait_n8n_healthy || { write_fail "n8n failed to restart after workflow import"; exit 1; }

    # Activate all 4
    all_wfs=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null || echo '{"data":[]}')
    wf_ids=$(echo "$all_wfs" | python3 -c "
import json, sys, re
data = json.load(sys.stdin).get('data', [])
for w in data:
    if re.match(r'Fintrak [A-D]', w.get('name','')) and not w.get('active'):
        print(w['id'])
" 2>/dev/null)

    for id in $wf_ids; do
        curl -sf -X POST -H "$AUTH_HEADER" "http://localhost:5678/rest/workflows/$id/activate" >/dev/null 2>&1 || true
    done
    write_success "All workflows activated"

    # Telegram test message
    write_info "Sending test message..."
    tg_result=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\":\"${YOUR_TELEGRAM_CHAT_ID}\",\"text\":\"✅ Fintrak is live on your Android! Send me a receipt photo to get started.\"}" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" 2>/dev/null || echo '{}')

    ok=$(echo "$tg_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok',''))" 2>/dev/null)
    [ "$ok" = "True" ] && write_success "Test message sent" || write_warn "Could not send test message — check bot token and chat ID."
fi

# ═══════════════════════════════════════════════════════════════════════════
# Done!
# ═══════════════════════════════════════════════════════════════════════════
SHEET_ID=$(read_env_key "GOOGLE_SHEET_ID")

printf "\n"
printf "${GREEN}🎉 Fintrak is live on your Android!${NC}\n"
printf "\n"
write_info "   n8n dashboard : http://localhost:5678  (open in Android browser)"
write_info "   Username      : admin / (your password)"
write_info "   Google Sheet  : https://docs.google.com/spreadsheets/d/${SHEET_ID}"
write_info "   Telegram      : Send a receipt photo to your bot to get started"
printf "\n"
write_warn "IMPORTANT: Fintrak runs while Termux is open and the phone is on."
write_warn "To keep it running in the background:"
write_warn "  1. Install Termux:Boot from F-Droid"
write_warn "  2. Create ~/.termux/boot/start-fintrak.sh (see README for contents)"
write_warn "  3. Enable battery optimization exemption for Termux in Android settings"
printf "\n"
write_info "To stop Fintrak:  kill \$(cat ~/.n8n/fintrak.pid)"
write_info "To restart:       cd ~/fintrak && ./setup-android.sh"
write_info "To view logs:     tail -f ~/.n8n/fintrak.log"
printf "\n"
