#!/usr/bin/env bash
# Fintrak Setup Wizard - Windows (Git Bash / WSL) + Mac + Linux
# Runs all 5 deployment phases automatically.
# Re-runnable: skips already-completed phases.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$SCRIPT_DIR/.env"

# ── OS detection ────────────────────────────────────────────────────────────
case "$OSTYPE" in
    msys*|cygwin*|win32*) IS_WINDOWS=true ;;
    *)                    IS_WINDOWS=false ;;
esac

# ── Python detection (python3 vs python on Windows) ─────────────────────────
if command -v python3 &>/dev/null; then
    PYTHON=python3
elif command -v python &>/dev/null && python -c "import sys; assert sys.version_info[0]==3" 2>/dev/null; then
    PYTHON=python
else
    echo "Python 3 is required. Install from python.org and re-run."
    exit 1
fi

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; MAGENTA='\033[0;35m'; NC='\033[0m'

write_success() { printf "${GREEN}✓ %s${NC}\n" "$1"; }
write_fail()    { printf "${RED}✗ %s${NC}\n" "$1"; }
write_info()    { printf "${CYAN}  %s${NC}\n" "$1"; }
write_warn()    { printf "${YELLOW}⚠ %s${NC}\n" "$1"; }
write_phase()   { printf "\n${MAGENTA}══ %s ══${NC}\n" "$1"; }

# ── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      Fintrak Setup Wizard            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# ── Pre-flight: Docker ────────────────────────────────────────────────────────
write_info "Checking prerequisites..."
if ! command -v docker &>/dev/null; then
    write_fail "Docker is not installed. Install from docker.com/get-started and re-run."
    exit 1
fi
if ! docker info &>/dev/null; then
    write_fail "Docker is not running. Start Docker and re-run setup."
    exit 1
fi
write_success "Docker is running"

# ── Helpers ──────────────────────────────────────────────────────────────────
read_env_key() {
    local key="$1"
    if [ -f "$ENV_PATH" ]; then
        grep -E "^${key}=(.*)$" "$ENV_PATH" | head -1 | sed "s/^${key}=//"
    fi
}

write_env() {
    # $1 = associative array name (passed as nameref)
    # Called after building ENV_KEYS / ENV_VALS arrays
    : # implemented inline below to avoid bash 3 issues on older Mac
}

n8n_auth_header() {
    local pass="$1"
    local b64
    b64=$($PYTHON -c "import base64; print(base64.b64encode(b'admin:$pass').decode())")
    echo "Authorization: Basic $b64"
}

wait_n8n_healthy() {
    write_info "Waiting for n8n to be ready..."
    for i in $(seq 1 30); do
        if curl -sf http://localhost:5678/healthz &>/dev/null; then
            return 0
        fi
        sleep 2
    done
    return 1
}

prompt_validated() {
    local label="$1" max="$2" varname="$3"
    shift 3
    local validator_fn="$1"
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
        read -r -s -p "$label: " value
        echo ""
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

# Validators (return error string or empty string)
validate_password() {
    local v="$1"
    [ ${#v} -lt 8 ] && echo "Must be at least 8 characters" && return
    [[ "$v" =~ [[:space:]] ]] && echo "Must not contain spaces" && return
    echo ""
}

validate_json_path() {
    local p="${1/#\~/$HOME}"
    [ ! -f "$p" ] && echo "File not found: $p" && return
    $PYTHON -c "
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

validate_email() {
    [[ "$1" != *"@"* ]] && echo "Invalid email format" || echo ""
}

validate_telegram_token() {
    [[ "$1" =~ ^[0-9]{8,10}:[A-Za-z0-9_-]{35,}$ ]] && echo "" || echo "Invalid format (expected: 123456789:ABC...)"
}

validate_chat_id() {
    [[ "$1" =~ ^[0-9]+$ ]] && echo "" || echo "Must be numeric only"
}

validate_ocr_key() {
    [[ "$1" =~ ^K8[A-Za-z0-9]{8,}$ ]] && echo "" || echo "Invalid format (should start with K8)"
}

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
    write_info "  • Google service account JSON key file"
    write_info "  • Telegram bot token (from @BotFather)"
    write_info "  • OCR.Space API key (free at ocr.space/ocrapi)"
    write_info ""

    # 1/6 — n8n password
    prompt_secret "[1/6] n8n admin password (min 8 chars, no spaces)" 3 N8N_PASSWORD validate_password

    # 2/6 — Google JSON
    while true; do
        read -r -p "[2/6] Path to Google service account JSON: " json_path
        json_path="${json_path/#\~/$HOME}"
        if [ ! -f "$json_path" ]; then
            write_fail "File not found: $json_path"
            continue
        fi
        err=$(validate_json_path "$json_path")
        if [ -n "$err" ]; then
            write_fail "$err"
            continue
        fi
        GOOGLE_CLIENT_EMAIL=$($PYTHON -c "import json; print(json.load(open('$json_path'))['client_email'])")
        GOOGLE_PRIVATE_KEY=$($PYTHON -c "import json; print(json.load(open('$json_path'))['private_key'])")
        write_success "Google credentials validated"
        break
    done

    # 3/6 — Personal Google email
    prompt_validated "[3/6] Your personal Google email (to access the sheet)" 3 GOOGLE_USER_EMAIL validate_email

    # 4/6 — Telegram token
    prompt_validated "[4/6] Telegram bot token" 3 TELEGRAM_BOT_TOKEN validate_telegram_token

    # 5/6 — Telegram chat ID
    prompt_validated "[5/6] Your Telegram chat ID (numeric)" 3 YOUR_TELEGRAM_CHAT_ID validate_chat_id

    # 6/6 — OCR.Space key
    prompt_validated "[6/6] OCR.Space API key" 3 OCR_SPACE_API_KEY validate_ocr_key

    # Write .env
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
# PHASE 2 — Launch n8n
# ═══════════════════════════════════════════════════════════════════════════
write_phase "Phase 2: Launching n8n"

if docker ps --filter "name=fintrak-n8n" --format "{{.Status}}" 2>/dev/null | grep -q "^Up"; then
    write_success "n8n already running — skipping"
else
    write_info "Starting n8n container..."
    docker compose up -d >/dev/null 2>&1 || { write_fail "docker compose up failed"; exit 1; }

    if ! wait_n8n_healthy; then
        write_fail "n8n did not become healthy within 60 seconds"
        write_info "Last container logs:"
        docker compose logs n8n 2>&1 | tail -20
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
sheets_exists=$(echo "$creds_response" | $PYTHON -c"import json,sys; d=json.load(sys.stdin); print('yes' if any(c['name']=='Fintrak Google Sheets' for c in d.get('data',[])) else '')" 2>/dev/null)
drive_exists=$(echo "$creds_response"  | $PYTHON -c"import json,sys; d=json.load(sys.stdin); print('yes' if any(c['name']=='Fintrak Google Drive'  for c in d.get('data',[])) else '')" 2>/dev/null)

if [ -n "$sheets_exists" ] && [ -n "$drive_exists" ]; then
    write_success "Phase 3 already complete — skipping"
else
    TMP_DIR=$(mktemp -d)

    for pair in "google-sheets-cred.json:gs-cred.json" "google-drive-cred.json:gd-cred.json"; do
        template="${pair%%:*}"
        tmpfile="${pair##*:}"
        sed -e "s|{{CLIENT_EMAIL}}|${GOOGLE_CLIENT_EMAIL}|g" \
            -e "s|{{PRIVATE_KEY}}|${GOOGLE_PRIVATE_KEY}|g" \
            "$SCRIPT_DIR/setup/credentials-template/$template" > "$TMP_DIR/$tmpfile"

        docker cp "$TMP_DIR/$tmpfile" "fintrak-n8n:/tmp/$tmpfile" >/dev/null 2>&1
        docker exec fintrak-n8n n8n import:credentials --input="/tmp/$tmpfile" >/dev/null 2>&1
        docker exec fintrak-n8n rm -f "/tmp/$tmpfile" >/dev/null 2>&1
    done

    rm -rf "$TMP_DIR"
    write_success "Google Sheets credential imported"
    write_success "Google Drive credential imported"
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
    # Import setup workflow
    docker cp "$SCRIPT_DIR/n8n-workflows/workflow-setup.json" "fintrak-n8n:/tmp/workflow-setup.json" >/dev/null 2>&1
    docker exec fintrak-n8n n8n import:workflow --input="/tmp/workflow-setup.json" >/dev/null 2>&1
    docker exec fintrak-n8n rm -f "/tmp/workflow-setup.json" >/dev/null 2>&1

    # Find and activate the setup workflow
    all_wfs=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null || echo '{"data":[]}')
    setup_wf_id=$(echo "$all_wfs" | $PYTHON -c"
import json, sys
data = json.load(sys.stdin).get('data', [])
match = [w for w in data if 'Provision Google' in w.get('name', '')]
print(match[0]['id'] if match else '')
" 2>/dev/null)

    if [ -z "$setup_wf_id" ]; then
        write_fail "Could not find setup workflow in n8n after import"
        exit 1
    fi

    curl -sf -X POST -H "$AUTH_HEADER" "http://localhost:5678/rest/workflows/$setup_wf_id/activate" >/dev/null 2>&1

    write_info "Running setup workflow (creating Sheet + Drive folder)..."

    result=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"userEmail\":\"${GOOGLE_USER_EMAIL}\",\"sheetName\":\"Fintrak Expenses\",\"driveFolderName\":\"Fintrak/Receipts\"}" \
        http://localhost:5678/webhook/fintrak-setup 2>/dev/null || echo '{}')

    GOOGLE_SHEET_ID=$(echo "$result" | $PYTHON -c"import json,sys; print(json.load(sys.stdin).get('sheetId',''))" 2>/dev/null)
    GOOGLE_DRIVE_FOLDER_ID=$(echo "$result" | $PYTHON -c"import json,sys; print(json.load(sys.stdin).get('driveFolderId',''))" 2>/dev/null)

    if [ -z "$GOOGLE_SHEET_ID" ] || [ -z "$GOOGLE_DRIVE_FOLDER_ID" ]; then
        write_fail "Setup workflow did not return Sheet ID or Folder ID"
        write_info "n8n is still running at http://localhost:5678 — check workflow logs."
        exit 1
    fi

    write_success "Google Sheet created: $GOOGLE_SHEET_ID"
    write_success "Drive folder created: $GOOGLE_DRIVE_FOLDER_ID"

    # Update .env with IDs (use Python for cross-platform in-place edit)
    $PYTHON - "$ENV_PATH" "$GOOGLE_SHEET_ID" "$GOOGLE_DRIVE_FOLDER_ID" << 'PYEOF'
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
# PHASE 5 — Activate main workflows
# ═══════════════════════════════════════════════════════════════════════════
write_phase "Phase 5: Activating Workflows"

all_wfs=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null || echo '{"data":[]}')
active_count=$(echo "$all_wfs" | $PYTHON -c"
import json, sys, re
data = json.load(sys.stdin).get('data', [])
print(sum(1 for w in data if w.get('active') and re.match(r'Fintrak [A-D]', w.get('name',''))))
" 2>/dev/null)

if [ "${active_count:-0}" -ge 4 ]; then
    write_success "Phase 5 already complete — skipping"
else
    # Set n8n Variables
    write_info "Setting n8n variables..."
    for kv in \
        "YOUR_TELEGRAM_CHAT_ID:${YOUR_TELEGRAM_CHAT_ID}" \
        "TELEGRAM_BOT_TOKEN:${TELEGRAM_BOT_TOKEN}" \
        "OCR_SPACE_API_KEY:${OCR_SPACE_API_KEY}" \
        "GOOGLE_SHEET_ID:${GOOGLE_SHEET_ID}" \
        "GOOGLE_DRIVE_FOLDER_ID:${GOOGLE_DRIVE_FOLDER_ID}"; do
        key="${kv%%:*}"
        val="${kv#*:}"
        curl -sf -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
            -d "{\"key\":\"$key\",\"value\":\"$val\"}" \
            http://localhost:5678/rest/variables >/dev/null 2>&1 || true
    done
    write_success "n8n variables set"

    # Import Telegram credential
    write_info "Importing Telegram credential..."
    TMP_DIR=$(mktemp -d)
    sed "s|{{TELEGRAM_BOT_TOKEN}}|${TELEGRAM_BOT_TOKEN}|g" \
        "$SCRIPT_DIR/setup/credentials-template/telegram-cred.json" > "$TMP_DIR/tg-cred.json"

    docker cp "$TMP_DIR/tg-cred.json" "fintrak-n8n:/tmp/tg-cred.json" >/dev/null 2>&1
    docker exec fintrak-n8n n8n import:credentials --input="/tmp/tg-cred.json" >/dev/null 2>&1
    docker exec fintrak-n8n rm -f "/tmp/tg-cred.json" >/dev/null 2>&1
    rm -rf "$TMP_DIR"
    write_success "Telegram credential imported"

    # Import 4 main workflows
    write_info "Importing main workflows..."
    for wf in workflow-a-receipt workflow-b-text workflow-c-commands workflow-d-daily-cron; do
        src="$SCRIPT_DIR/n8n-workflows/${wf}.json"
        docker cp "$src" "fintrak-n8n:/tmp/${wf}.json" >/dev/null 2>&1
        docker exec fintrak-n8n n8n import:workflow --input="/tmp/${wf}.json" >/dev/null 2>&1
        docker exec fintrak-n8n rm -f "/tmp/${wf}.json" >/dev/null 2>&1
    done
    write_success "Workflows imported"

    # Activate all 4
    all_wfs=$(curl -sf -H "$AUTH_HEADER" http://localhost:5678/rest/workflows 2>/dev/null || echo '{"data":[]}')
    wf_ids=$(echo "$all_wfs" | $PYTHON -c"
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
    write_info "Sending test message to Telegram..."
    tg_result=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\":\"${YOUR_TELEGRAM_CHAT_ID}\",\"text\":\"✅ Fintrak is live! Send me a receipt photo to get started.\"}" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" 2>/dev/null || echo '{}')

    ok=$(echo "$tg_result" | $PYTHON -c"import json,sys; print(json.load(sys.stdin).get('ok',''))" 2>/dev/null)
    if [ "$ok" = "True" ]; then
        write_success "Test message sent"
    else
        write_warn "Could not send Telegram test message — check your bot token and chat ID."
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# Done!
# ═══════════════════════════════════════════════════════════════════════════
SHEET_ID=$(read_env_key "GOOGLE_SHEET_ID")

echo ""
echo -e "${GREEN}🎉 Fintrak is live!${NC}"
echo ""
write_info "   n8n dashboard : http://localhost:5678"
write_info "   Username      : admin / (your password)"
write_info "   Google Sheet  : https://docs.google.com/spreadsheets/d/${SHEET_ID}"
write_info "   Telegram      : Send a receipt photo to your bot to get started"
echo ""
