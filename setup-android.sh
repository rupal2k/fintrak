#!/usr/bin/env bash
# Fintrak Setup Wizard - Android (Termux)
# Guided, step-by-step install for non-technical users.
# Re-runnable: skips already-completed phases.
#
# How to get started:
#   1. Install Termux from F-Droid: https://f-droid.org/packages/com.termux/
#   2. In Termux run:
#        pkg update && pkg install -y git
#        git clone https://github.com/rupal2k/fintrak.git ~/fintrak
#        cd ~/fintrak && chmod +x setup-android.sh && ./setup-android.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$SCRIPT_DIR/.env"
N8N_PID_FILE="$HOME/.n8n/fintrak.pid"
N8N_LOG_FILE="$HOME/.n8n/fintrak.log"
DOWNLOADS="/storage/emulated/0/Download"

# ── Termux check ──────────────────────────────────────────────────────────────
if [ -z "${PREFIX:-}" ] || [[ "$PREFIX" != *"termux"* ]]; then
    echo "This script is for Android (Termux) only."
    echo "On Windows: run setup.bat or setup.ps1"
    echo "On Mac/Linux: run setup.sh"
    exit 1
fi

# ── Colors ────────────────────────────────────────────────────────────────────
GRN='\033[0;32m'; RED='\033[0;31m'; CYN='\033[0;36m'
YLW='\033[1;33m'; MGT='\033[0;35m'; BLD='\033[1m'; NC='\033[0m'

ok()    { printf "${GRN}  ✓ %s${NC}\n" "$1"; }
fail()  { printf "${RED}  ✗ %s${NC}\n" "$1"; }
info()  { printf "${CYN}  %s${NC}\n" "$1"; }
warn()  { printf "${YLW}  ⚠ %s${NC}\n" "$1"; }
phase() { printf "\n${MGT}${BLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${MGT}${BLD}  %s${NC}\n${MGT}${BLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" "$1"; }
box()   { printf "\n${CYN}${BLD}  ┌──────────────────────────────────────┐${NC}\n${CYN}${BLD}  │  %-36s│${NC}\n${CYN}${BLD}  └──────────────────────────────────────┘${NC}\n\n" "$1"; }
pause() { printf "\n"; read -r -p "  Press Enter to continue..." _; printf "\n"; }

# Animated spinner for long-running background jobs
spinner() {
    local pid=$1 msg="$2" i=0
    local f=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYN}  %s  %s${NC}" "${f[$((i % 10))]}" "$msg"
        i=$((i + 1)); sleep 0.12
    done
    printf "\r                                                  \r"
}

# ── Helpers ───────────────────────────────────────────────────────────────────
read_env_key() {
    [ -f "$ENV_PATH" ] && grep -E "^${1}=(.*)$" "$ENV_PATH" 2>/dev/null | head -1 | sed "s/^${1}=//" || true
}

n8n_auth_header() {
    python3 -c "import base64; print('Authorization: Basic ' + base64.b64encode(b'admin:$1').decode())"
}

n8n_is_running() {
    [ -f "$N8N_PID_FILE" ] && kill -0 "$(cat "$N8N_PID_FILE")" 2>/dev/null
}

start_n8n() {
    mkdir -p "$HOME/.n8n"
    N8N_BASIC_AUTH_ACTIVE=true \
    N8N_BASIC_AUTH_USER=admin \
    N8N_BASIC_AUTH_PASSWORD="$1" \
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
        kill "$(cat "$N8N_PID_FILE")" 2>/dev/null || true
        sleep 3; rm -f "$N8N_PID_FILE"
    fi
}

wait_n8n_healthy() {
    local i=0
    while [ $i -lt 54 ]; do
        curl -sf http://localhost:5678/healthz &>/dev/null && return 0
        sleep 5; i=$((i + 1))
        printf "\r${CYN}  ⏳ Starting up... (%d/54 checks)${NC}" "$i"
    done
    printf "\n"; return 1
}

validate_json_file() {
    python3 -c "
import json, sys
try:
    d = json.load(open('$1'))
    if 'client_email' not in d or 'private_key' not in d:
        print('Missing fields — this may not be a service account key file')
    else:
        print('')
except Exception as e:
    print('Cannot read file: {}'.format(e))
" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════════
# Welcome screen
# ═══════════════════════════════════════════════════════════════════════════════
clear
printf "${CYN}${BLD}\n"
printf "  ╔══════════════════════════════════════════╗\n"
printf "  ║                                          ║\n"
printf "  ║      💰  Fintrak — Android Setup        ║\n"
printf "  ║                                          ║\n"
printf "  ╚══════════════════════════════════════════╝\n"
printf "${NC}\n"
printf "  Welcome! This wizard sets up Fintrak on\n"
printf "  your Android phone, one step at a time.\n"
printf "  ${BLD}Total time: about 10 minutes.${NC}\n"
printf "\n"
printf "  ${CYN}Before you start, have these ready:${NC}\n"
printf "\n"
printf "  1. ${BLD}google-credentials.json${NC}\n"
printf "     (save it to your Downloads folder)\n"
printf "\n"
printf "  2. ${BLD}Telegram bot token${NC} from @BotFather\n"
printf "     (see README → 'Thing 2' for steps)\n"
printf "\n"
printf "  3. ${BLD}Your Telegram chat ID${NC} from @userinfobot\n"
printf "     (see README → 'Thing 3' for steps)\n"
printf "\n"
printf "  4. ${BLD}OCR.Space API key${NC} (free at ocr.space/ocrapi)\n"
printf "     (see README → 'Thing 5' for steps)\n"
printf "\n"
printf "  Don't have everything yet? That's fine —\n"
printf "  the wizard explains where to get each one.\n"
printf "\n"
pause

# ── Storage access ─────────────────────────────────────────────────────────────
if [ ! -d "$DOWNLOADS" ]; then
    printf "\n"
    printf "  ${YLW}${BLD}Storage access needed${NC}\n"
    printf "\n"
    printf "  Fintrak needs to read your google-credentials.json\n"
    printf "  from your Downloads folder.\n"
    printf "\n"
    printf "  ${BLD}You will see a permission popup — tap Allow.${NC}\n"
    printf "\n"
    pause
    termux-setup-storage || true
    sleep 3
    [ ! -d "$DOWNLOADS" ] && warn "Could not access Downloads. You can type the full file path manually."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1 of 5 — Install packages + n8n
# ═══════════════════════════════════════════════════════════════════════════════
phase "Phase 1 of 5 — Installing Fintrak Engine"

pkgs_needed=()
command -v node    &>/dev/null || pkgs_needed+=(nodejs)
command -v curl    &>/dev/null || pkgs_needed+=(curl)
command -v python3 &>/dev/null || pkgs_needed+=(python)

if [ ${#pkgs_needed[@]} -gt 0 ]; then
    info "Installing required packages: ${pkgs_needed[*]}"
    pkg update -y &>/dev/null
    pkg install -y "${pkgs_needed[@]}" &>/dev/null
    ok "Packages installed"
else
    ok "Required packages already installed"
fi

if ! command -v n8n &>/dev/null; then
    info "Installing Fintrak engine — this takes 5-10 minutes."
    info "Your screen may look frozen — that's normal. Please wait."
    printf "\n"
    npm install -g n8n > /tmp/n8n-install.log 2>&1 &
    NPM_PID=$!
    spinner $NPM_PID "Installing Fintrak engine..."
    wait $NPM_PID || { fail "Installation failed. See /tmp/n8n-install.log"; exit 1; }
    ok "Fintrak engine installed ($(n8n --version 2>/dev/null | head -1))"
else
    ok "Fintrak engine already installed ($(n8n --version 2>/dev/null | head -1))"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2 of 5 — Collect credentials
# ═══════════════════════════════════════════════════════════════════════════════
phase "Phase 2 of 5 — Your Credentials"

N8N_PASSWORD=$(read_env_key "N8N_PASSWORD")
TELEGRAM_BOT_TOKEN=$(read_env_key "TELEGRAM_BOT_TOKEN")
YOUR_TELEGRAM_CHAT_ID=$(read_env_key "YOUR_TELEGRAM_CHAT_ID")
OCR_SPACE_API_KEY=$(read_env_key "OCR_SPACE_API_KEY")
GOOGLE_USER_EMAIL=$(read_env_key "GOOGLE_USER_EMAIL")
GOOGLE_CLIENT_EMAIL=$(read_env_key "GOOGLE_CLIENT_EMAIL")
GOOGLE_PRIVATE_KEY=$(read_env_key "GOOGLE_PRIVATE_KEY")

if [ -n "$N8N_PASSWORD" ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && \
   [ -n "$YOUR_TELEGRAM_CHAT_ID" ] && [ -n "$OCR_SPACE_API_KEY" ] && \
   [ -n "$GOOGLE_CLIENT_EMAIL" ]; then
    ok "Credentials already saved — skipping"
else

    # ── Step 1 / 6 — Password ─────────────────────────────────────────────────
    box "Step 1 of 6 — Create a password"
    printf "  Fintrak has a private dashboard you can open in\n"
    printf "  your phone's browser. Create a password for it.\n"
    printf "\n"
    printf "  ${YLW}Rules:${NC} At least 8 characters. No spaces.\n"
    printf "  ${YLW}Tip:${NC}  Write it down — you'll use it to log in.\n"
    printf "\n"

    while true; do
        read -r -s -p "  Create a password: " N8N_PASSWORD; printf "\n"
        [ ${#N8N_PASSWORD} -lt 8 ] && fail "Too short — needs at least 8 characters" && continue
        [[ "$N8N_PASSWORD" == *" "* ]] && fail "No spaces allowed" && continue
        read -r -s -p "  Confirm password:  " _confirm; printf "\n"
        [ "$N8N_PASSWORD" != "$_confirm" ] && fail "Passwords don't match — try again" && continue
        ok "Password set"
        break
    done

    # ── Step 2 / 6 — Google credentials file ──────────────────────────────────
    box "Step 2 of 6 — Google credentials file"
    printf "  This file lets Fintrak save expenses to your\n"
    printf "  Google Sheet and store receipt photos in Drive.\n"
    printf "\n"
    printf "  ${YLW}Where to get it:${NC}\n"
    printf "  Follow the guide in setup/google-service-account.md\n"
    printf "  or README → 'Thing 4 — Google service account key'.\n"
    printf "\n"
    printf "  Once you have the file, save it to your phone's\n"
    printf "  ${BLD}Downloads folder${NC}, then come back here.\n"
    printf "\n"

    # Auto-detect JSON files in Downloads
    json_files=()
    if [ -d "$DOWNLOADS" ]; then
        while IFS= read -r f; do
            json_files+=("$f")
        done < <(find "$DOWNLOADS" -maxdepth 2 -name "*.json" 2>/dev/null | sort)
    fi

    if [ ${#json_files[@]} -gt 0 ]; then
        printf "  ${GRN}Found JSON files in Downloads — pick one:${NC}\n\n"
        for idx in "${!json_files[@]}"; do
            printf "  ${BLD}%d.${NC} %s\n" "$((idx + 1))" "$(basename "${json_files[$idx]}")"
        done
        printf "  ${BLD}0.${NC} Enter path manually\n\n"

        while true; do
            read -r -p "  Enter number: " pick
            if [ "$pick" = "0" ]; then
                read -r -p "  Full path to JSON file: " json_path
                json_path="${json_path/#\~/$HOME}"
            elif [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#json_files[@]}" ]; then
                json_path="${json_files[$((pick - 1))]}"
            else
                fail "Enter a number from the list above"; continue
            fi
            [ ! -f "$json_path" ] && fail "File not found: $json_path" && continue
            _err=$(validate_json_file "$json_path")
            [ -n "$_err" ] && fail "$_err" && continue
            GOOGLE_CLIENT_EMAIL=$(python3 -c "import json; print(json.load(open('$json_path'))['client_email'])")
            GOOGLE_PRIVATE_KEY=$(python3 -c "import json; print(json.load(open('$json_path'))['private_key'])")
            ok "Google credentials file accepted"
            break
        done
    else
        printf "  ${YLW}No JSON files found in Downloads yet.${NC}\n"
        printf "\n"
        printf "  Once you have the file saved to Downloads,\n"
        printf "  enter the path below:\n"
        printf "  ${CYN}Example: /storage/emulated/0/Download/google-credentials.json${NC}\n\n"

        while true; do
            read -r -p "  Path to JSON file: " json_path
            json_path="${json_path/#\~/$HOME}"
            [ ! -f "$json_path" ] && fail "File not found: $json_path" && continue
            _err=$(validate_json_file "$json_path")
            [ -n "$_err" ] && fail "$_err" && continue
            GOOGLE_CLIENT_EMAIL=$(python3 -c "import json; print(json.load(open('$json_path'))['client_email'])")
            GOOGLE_PRIVATE_KEY=$(python3 -c "import json; print(json.load(open('$json_path'))['private_key'])")
            ok "Google credentials file accepted"
            break
        done
    fi

    # ── Step 3 / 6 — Google email ─────────────────────────────────────────────
    box "Step 3 of 6 — Your Gmail address"
    printf "  Fintrak will create an expense sheet in Google\n"
    printf "  Sheets and share it with your Gmail so you can\n"
    printf "  open it on any device.\n"
    printf "\n"
    printf "  ${YLW}Enter your personal Gmail address.${NC}\n"
    printf "  Example: yourname@gmail.com\n\n"

    while true; do
        read -r -p "  Your Gmail: " GOOGLE_USER_EMAIL
        [[ "$GOOGLE_USER_EMAIL" != *"@"* ]] && fail "That doesn't look like an email address" && continue
        ok "Gmail address saved"
        break
    done

    # ── Step 4 / 6 — Telegram token ───────────────────────────────────────────
    box "Step 4 of 6 — Telegram bot token"
    printf "  Your Telegram bot is how you send receipts and\n"
    printf "  commands to Fintrak.\n"
    printf "\n"
    printf "  ${YLW}How to create your bot (takes 2 minutes):${NC}\n"
    printf "  1. Open Telegram on your phone\n"
    printf "  2. Search for ${BLD}@BotFather${NC} (blue verified checkmark)\n"
    printf "  3. Tap it and send: ${BLD}/newbot${NC}\n"
    printf "  4. When asked for a name, send: ${BLD}Fintrak${NC}\n"
    printf "  5. When asked for username: ${BLD}fintrak_yourname_bot${NC}\n"
    printf "     (must end in _bot, make it unique)\n"
    printf "  6. BotFather sends you a token like:\n"
    printf "     ${CYN}7234567890:AAFxxxxxxxxxxxxxxxxxxxxxxx${NC}\n"
    printf "  7. Copy that token and paste it below\n\n"

    while true; do
        read -r -p "  Paste bot token: " TELEGRAM_BOT_TOKEN
        [[ ! "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]{8,10}:[A-Za-z0-9_-]{35,}$ ]] && \
            fail "That doesn't look right. Should be: numbers:letters  e.g. 7234567890:AAFxxx" && continue
        ok "Bot token accepted"
        break
    done

    # ── Step 5 / 6 — Telegram chat ID ─────────────────────────────────────────
    box "Step 5 of 6 — Your Telegram chat ID"
    printf "  This number makes sure only ${BLD}you${NC} can control\n"
    printf "  the bot — no one else can send it commands.\n"
    printf "\n"
    printf "  ${YLW}How to get your chat ID (takes 1 minute):${NC}\n"
    printf "  1. Open Telegram\n"
    printf "  2. Search for ${BLD}@userinfobot${NC}\n"
    printf "  3. Send it any message (e.g. ${BLD}hi${NC})\n"
    printf "  4. It replies with your ID, like: ${CYN}Id: 123456789${NC}\n"
    printf "  5. Copy just the number and paste it below\n\n"

    while true; do
        read -r -p "  Paste chat ID: " YOUR_TELEGRAM_CHAT_ID
        [[ ! "$YOUR_TELEGRAM_CHAT_ID" =~ ^-?[0-9]+$ ]] && \
            fail "Chat ID must be numbers only (e.g. 123456789)" && continue
        ok "Chat ID accepted"
        break
    done

    # ── Step 6 / 6 — OCR.Space key ────────────────────────────────────────────
    box "Step 6 of 6 — OCR.Space API key"
    printf "  This free service reads the text from your\n"
    printf "  receipt photos so Fintrak can log the amount.\n"
    printf "  Free plan: 25,000 receipts per month.\n"
    printf "\n"
    printf "  ${YLW}How to get your free key (takes 2 minutes):${NC}\n"
    printf "  1. Open your browser and go to:\n"
    printf "     ${CYN}ocr.space/ocrapi${NC}\n"
    printf "  2. Tap ${BLD}Register for free API key${NC}\n"
    printf "  3. Enter your email and submit\n"
    printf "  4. Check your email — the key starts with ${BLD}K8${NC}\n"
    printf "  5. Copy the key and paste it below\n\n"

    while true; do
        read -r -p "  Paste OCR key: " OCR_SPACE_API_KEY
        [[ ! "$OCR_SPACE_API_KEY" =~ ^K8[A-Za-z0-9]{8,}$ ]] && \
            fail "Should start with K8 (e.g. K8abc12345). Check your email." && continue
        ok "OCR key accepted"
        break
    done

    # Save .env
    printf "\n"
    info "Saving your credentials..."
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
    ok "All credentials saved"
fi

# Reload from .env if needed
[ -z "${N8N_PASSWORD:-}" ]          && N8N_PASSWORD=$(read_env_key "N8N_PASSWORD")
[ -z "${TELEGRAM_BOT_TOKEN:-}" ]    && TELEGRAM_BOT_TOKEN=$(read_env_key "TELEGRAM_BOT_TOKEN")
[ -z "${YOUR_TELEGRAM_CHAT_ID:-}" ] && YOUR_TELEGRAM_CHAT_ID=$(read_env_key "YOUR_TELEGRAM_CHAT_ID")
[ -z "${OCR_SPACE_API_KEY:-}" ]     && OCR_SPACE_API_KEY=$(read_env_key "OCR_SPACE_API_KEY")
[ -z "${GOOGLE_USER_EMAIL:-}" ]     && GOOGLE_USER_EMAIL=$(read_env_key "GOOGLE_USER_EMAIL")
[ -z "${GOOGLE_CLIENT_EMAIL:-}" ]   && GOOGLE_CLIENT_EMAIL=$(read_env_key "GOOGLE_CLIENT_EMAIL")
[ -z "${GOOGLE_PRIVATE_KEY:-}" ]    && GOOGLE_PRIVATE_KEY=$(read_env_key "GOOGLE_PRIVATE_KEY")

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3 of 5 — Start n8n
# ═══════════════════════════════════════════════════════════════════════════════
phase "Phase 3 of 5 — Starting Fintrak Engine"

if n8n_is_running && curl -sf http://localhost:5678/healthz &>/dev/null; then
    ok "Fintrak engine already running"
else
    [ -f "$N8N_PID_FILE" ] && rm -f "$N8N_PID_FILE"
    info "Starting Fintrak engine..."
    start_n8n "$N8N_PASSWORD"

    if ! wait_n8n_healthy; then
        printf "\n"
        fail "Fintrak engine did not start. Last 5 log lines:"
        tail -5 "$N8N_LOG_FILE" 2>/dev/null || true
        printf "\n"
        info "Run this script again — it will pick up from here."
        exit 1
    fi
    printf "\n"
    ok "Fintrak engine is ready"
fi

AUTH_HEADER=$(n8n_auth_header "$N8N_PASSWORD")

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4 of 5 — Connect Google account + create Sheet/Drive
# ═══════════════════════════════════════════════════════════════════════════════
phase "Phase 4 of 5 — Connecting Google Account"

creds_response=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/credentials 2>/dev/null || echo '{"data":[]}')
sheets_exists=$(echo "$creds_response" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('yes' if any(c['name']=='Fintrak Google Sheets' for c in d.get('data',[])) else '')
" 2>/dev/null)
drive_exists=$(echo "$creds_response" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('yes' if any(c['name']=='Fintrak Google Drive'  for c in d.get('data',[])) else '')
" 2>/dev/null)

if [ -n "$sheets_exists" ] && [ -n "$drive_exists" ]; then
    ok "Google account already connected"
else
    info "Connecting your Google account..."
    gs_body=$(python3 -c "
import json
print(json.dumps({'name':'Fintrak Google Sheets','type':'googleSheetsServiceAccount',
    'data':{'email':'''${GOOGLE_CLIENT_EMAIL}''','privateKey':'''${GOOGLE_PRIVATE_KEY}'''}}))
")
    gd_body=$(python3 -c "
import json
print(json.dumps({'name':'Fintrak Google Drive','type':'googleDriveServiceAccount',
    'data':{'email':'''${GOOGLE_CLIENT_EMAIL}''','privateKey':'''${GOOGLE_PRIVATE_KEY}'''}}))
")
    tg_body=$(python3 -c "
import json
print(json.dumps({'name':'Fintrak Telegram Bot','type':'telegramApi',
    'data':{'accessToken':'${TELEGRAM_BOT_TOKEN}'}}))
")
    curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
        -d "$gs_body" http://localhost:5678/rest/credentials >/dev/null 2>&1
    ok "Google Sheets connected"
    curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
        -d "$gd_body" http://localhost:5678/rest/credentials >/dev/null 2>&1
    ok "Google Drive connected"
    curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
        -d "$tg_body" http://localhost:5678/rest/credentials >/dev/null 2>&1
    ok "Telegram bot connected"
fi

# Create Google Sheet + Drive folder if not done yet
GOOGLE_SHEET_ID=$(read_env_key "GOOGLE_SHEET_ID")
GOOGLE_DRIVE_FOLDER_ID=$(read_env_key "GOOGLE_DRIVE_FOLDER_ID")

if [ -n "$GOOGLE_SHEET_ID" ] && [ -n "$GOOGLE_DRIVE_FOLDER_ID" ]; then
    ok "Google Sheet already created"
else
    info "Creating your Fintrak Expenses sheet in Google Drive..."

    stop_n8n; sleep 2
    n8n import:workflow --input="$SCRIPT_DIR/n8n-workflows/workflow-setup.json" >/dev/null 2>&1
    start_n8n "$N8N_PASSWORD"
    wait_n8n_healthy || { printf "\n"; fail "Engine failed to restart. Run this script again."; exit 1; }
    printf "\n"

    all_wfs=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null || echo '{"data":[]}')
    setup_wf_id=$(echo "$all_wfs" | python3 -c "
import json, sys
data = json.load(sys.stdin).get('data', [])
match = [w for w in data if 'Provision Google' in w.get('name', '')]
print(match[0]['id'] if match else '')
" 2>/dev/null)

    [ -z "$setup_wf_id" ] && fail "Could not find setup workflow" && exit 1

    curl -sf -X POST -H "$AUTH_HEADER" \
        "http://localhost:5678/rest/workflows/$setup_wf_id/activate" >/dev/null 2>&1

    result=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"userEmail\":\"${GOOGLE_USER_EMAIL}\",\"sheetName\":\"Fintrak Expenses\",\"driveFolderName\":\"Fintrak/Receipts\"}" \
        http://localhost:5678/webhook/fintrak-setup 2>/dev/null || echo '{}')

    GOOGLE_SHEET_ID=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('sheetId',''))" 2>/dev/null)
    GOOGLE_DRIVE_FOLDER_ID=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('driveFolderId',''))" 2>/dev/null)

    if [ -z "$GOOGLE_SHEET_ID" ] || [ -z "$GOOGLE_DRIVE_FOLDER_ID" ]; then
        fail "Could not create Google Sheet."
        info "Make sure Google Sheets API and Google Drive API are enabled in Google Cloud Console."
        info "See README → Troubleshooting → 'Setup wizard shows an error about Google APIs'"
        exit 1
    fi

    ok "Expense sheet created: Fintrak Expenses"
    ok "Receipt folder created: Fintrak/Receipts (Google Drive)"

    python3 - "$ENV_PATH" "$GOOGLE_SHEET_ID" "$GOOGLE_DRIVE_FOLDER_ID" << 'PYEOF'
import sys, re
path, sheet_id, folder_id = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, 'r') as f: content = f.read()
content = re.sub(r'^GOOGLE_SHEET_ID=.*$',        'GOOGLE_SHEET_ID='        + sheet_id,  content, flags=re.MULTILINE)
content = re.sub(r'^GOOGLE_DRIVE_FOLDER_ID=.*$', 'GOOGLE_DRIVE_FOLDER_ID=' + folder_id, content, flags=re.MULTILINE)
with open(path, 'w') as f: f.write(content)
PYEOF

    curl -sf -X POST   -H "$AUTH_HEADER" "http://localhost:5678/rest/workflows/$setup_wf_id/deactivate" >/dev/null 2>&1 || true
    curl -sf -X DELETE -H "$AUTH_HEADER" "http://localhost:5678/rest/workflows/$setup_wf_id" >/dev/null 2>&1 || true
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5 of 5 — Activate automations
# ═══════════════════════════════════════════════════════════════════════════════
phase "Phase 5 of 5 — Setting Up Automations"

all_wfs=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null || echo '{"data":[]}')
active_count=$(echo "$all_wfs" | python3 -c "
import json, sys, re
data = json.load(sys.stdin).get('data', [])
print(sum(1 for w in data if w.get('active') and re.match(r'Fintrak [A-D]', w.get('name',''))))
" 2>/dev/null)

if [ "${active_count:-0}" -ge 4 ]; then
    ok "All automations already active"
else
    GOOGLE_SHEET_ID=$(read_env_key "GOOGLE_SHEET_ID")
    GOOGLE_DRIVE_FOLDER_ID=$(read_env_key "GOOGLE_DRIVE_FOLDER_ID")

    info "Configuring automations..."
    for kv in \
        "YOUR_TELEGRAM_CHAT_ID:${YOUR_TELEGRAM_CHAT_ID}" \
        "TELEGRAM_BOT_TOKEN:${TELEGRAM_BOT_TOKEN}" \
        "OCR_SPACE_API_KEY:${OCR_SPACE_API_KEY}" \
        "GOOGLE_SHEET_ID:${GOOGLE_SHEET_ID}" \
        "GOOGLE_DRIVE_FOLDER_ID:${GOOGLE_DRIVE_FOLDER_ID}"; do
        _k="${kv%%:*}"; _v="${kv#*:}"
        curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
            -d "{\"key\":\"$_k\",\"value\":\"$_v\"}" \
            http://localhost:5678/rest/variables >/dev/null 2>&1 || true
    done

    stop_n8n; sleep 2
    info "Importing automation workflows..."
    for wf in workflow-a-receipt workflow-b-text workflow-c-commands workflow-d-daily-cron; do
        n8n import:workflow --input="$SCRIPT_DIR/n8n-workflows/${wf}.json" >/dev/null 2>&1
    done

    start_n8n "$N8N_PASSWORD"
    wait_n8n_healthy || { printf "\n"; fail "Engine failed to restart. Run this script again."; exit 1; }
    printf "\n"

    wf_ids=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null | python3 -c "
import json, sys, re
data = json.load(sys.stdin).get('data', [])
for w in data:
    if re.match(r'Fintrak [A-D]', w.get('name','')) and not w.get('active'):
        print(w['id'])
" 2>/dev/null)
    for id in $wf_ids; do
        curl -sf -X POST -H "$AUTH_HEADER" "http://localhost:5678/rest/workflows/$id/activate" >/dev/null 2>&1 || true
    done

    ok "Receipt photos → Google Sheet: active"
    ok "Text messages → Google Sheet: active"
    ok "Commands (/summary /today /last etc.): active"
    ok "Daily 9 PM summary: active"

    info "Sending a test message to your Telegram..."
    tg_result=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\":\"${YOUR_TELEGRAM_CHAT_ID}\",\"text\":\"✅ Fintrak is live on your Android!\\n\\nSend me a receipt photo, or type an expense like:\\n250 starbucks coffee\\n\\nCommands: /summary  /today  /last  /help\"}" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" 2>/dev/null || echo '{}')
    _ok=$(echo "$tg_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok',''))" 2>/dev/null)
    [ "$_ok" = "True" ] && ok "Check Telegram — Fintrak just messaged you!" || \
        warn "Could not send test message — check your bot token and chat ID."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Optional: Auto-start on phone reboot (Termux:Boot)
# ═══════════════════════════════════════════════════════════════════════════════
printf "\n"
printf "${CYN}${BLD}  ┌──────────────────────────────────────┐${NC}\n"
printf "${CYN}${BLD}  │  Optional: Keep running after reboot │${NC}\n"
printf "${CYN}${BLD}  └──────────────────────────────────────┘${NC}\n\n"
printf "  By default, Fintrak stops when you close\n"
printf "  Termux or restart your phone.\n"
printf "\n"
printf "  We can set it to start automatically on boot.\n"
printf "  (You'll also need ${BLD}Termux:Boot${NC} from F-Droid.)\n\n"

read -r -p "  Set up auto-start on reboot? (y/n): " _boot
if [[ "$_boot" =~ ^[Yy]$ ]]; then
    mkdir -p "$HOME/.termux/boot"
    cat > "$HOME/.termux/boot/start-fintrak.sh" << 'BOOT'
#!/data/data/com.termux/files/usr/bin/bash
source ~/fintrak/.env
N8N_BASIC_AUTH_ACTIVE=true \
N8N_BASIC_AUTH_USER=admin \
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD \
GENERIC_TIMEZONE=Asia/Kolkata \
TZ=Asia/Kolkata \
N8N_PORT=5678 \
N8N_HOST=localhost \
N8N_PROTOCOL=http \
nohup n8n start > ~/.n8n/fintrak.log 2>&1 &
echo $! > ~/.n8n/fintrak.pid
BOOT
    chmod +x "$HOME/.termux/boot/start-fintrak.sh"
    ok "Auto-start script created"
    printf "\n"
    printf "  ${YLW}Two more steps to finish:${NC}\n"
    printf "\n"
    printf "  1. Install ${BLD}Termux:Boot${NC} from F-Droid:\n"
    printf "     ${CYN}f-droid.org/packages/com.termux.boot${NC}\n"
    printf "     Then open it once to activate it.\n"
    printf "\n"
    printf "  2. In Android Settings:\n"
    printf "     Apps → Termux → Battery\n"
    printf "     → Set to ${BLD}Unrestricted${NC}\n"
    printf "\n"
    printf "  After that, Fintrak starts automatically\n"
    printf "  every time your phone boots.\n"
else
    info "Skipped. Run ./setup-android.sh anytime to set this up later."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Done!
# ═══════════════════════════════════════════════════════════════════════════════
SHEET_ID=$(read_env_key "GOOGLE_SHEET_ID")

printf "\n"
printf "${GRN}${BLD}"
printf "  ╔══════════════════════════════════════════╗\n"
printf "  ║                                          ║\n"
printf "  ║   🎉  Fintrak is live on your phone!   ║\n"
printf "  ║                                          ║\n"
printf "  ╚══════════════════════════════════════════╝\n"
printf "${NC}\n"
printf "  ${BLD}Your expense sheet:${NC}\n"
printf "  ${CYN}https://docs.google.com/spreadsheets/d/${SHEET_ID}${NC}\n"
printf "\n"
printf "  ${BLD}Open Telegram and try these:${NC}\n"
printf "  📷 Send a receipt photo\n"
printf "  ✏️  Type: ${CYN}250 starbucks coffee${NC}\n"
printf "  📊 Send: ${CYN}/summary${NC}\n"
printf "  ❓ Send: ${CYN}/help${NC}  (see all commands)\n"
printf "\n"
printf "  ${CYN}Useful Termux commands:${NC}\n"
printf "  Stop Fintrak : kill \$(cat ~/.n8n/fintrak.pid)\n"
printf "  Start again  : cd ~/fintrak && ./setup-android.sh\n"
printf "  View logs    : tail -f ~/.n8n/fintrak.log\n"
printf "\n"
