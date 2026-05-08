#!/usr/bin/env pwsh
# Fintrak Setup Wizard - Windows
# Runs all 5 deployment phases automatically.
# Re-runnable: skips already-completed phases.

$ErrorActionPreference = "Stop"

# ── Colors ─────────────────────────────────────────────────────────────────
function Write-Success($msg) { Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Fail($msg)    { Write-Host "✗ $msg" -ForegroundColor Red }
function Write-Info($msg)    { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Warn($msg)    { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Phase($msg)   { Write-Host "`n══ $msg ══" -ForegroundColor Magenta }

# ── Banner ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Fintrak Setup Wizard            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Pre-flight: Docker ──────────────────────────────────────────────────────
Write-Info "Checking prerequisites..."
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Success "Docker is running"
} catch {
    Write-Fail "Docker is not running. Start Docker Desktop and re-run setup."
    exit 1
}

$ENV_PATH = Join-Path $PSScriptRoot ".env"

# ── Helpers ─────────────────────────────────────────────────────────────────
function Read-Env {
    $map = @{}
    if (Test-Path $ENV_PATH) {
        foreach ($line in (Get-Content $ENV_PATH)) {
            if ($line -match "^([^#=]+)=(.*)$") { $map[$matches[1].Trim()] = $matches[2].Trim() }
        }
    }
    return $map
}

function Write-Env($map) {
    $lines = $map.Keys | ForEach-Object { "$_=$($map[$_])" }
    Set-Content -Path $ENV_PATH -Value $lines
}

function Get-N8nHeaders($password) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$password"))
    return @{ "Authorization" = "Basic $b64"; "Content-Type" = "application/json" }
}

function Wait-N8nHealthy {
    Write-Info "Waiting for n8n to be ready..."
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "http://localhost:5678/healthz" -UseBasicParsing -ErrorAction SilentlyContinue
            if ($r.StatusCode -eq 200) { return $true }
        } catch {}
        Start-Sleep -Seconds 2
    }
    return $false
}

function Prompt-Validated($label, $attempts, [scriptblock]$validate) {
    for ($i = 0; $i -lt $attempts; $i++) {
        $val = Read-Host $label
        $err = & $validate $val
        if (-not $err) { return $val }
        Write-Fail $err
        if ($i -eq $attempts - 1) { Write-Fail "Too many failed attempts. Exiting."; exit 1 }
    }
}

function Prompt-Secret($label, $attempts, [scriptblock]$validate) {
    for ($i = 0; $i -lt $attempts; $i++) {
        $ss  = Read-Host $label -AsSecureString
        $val = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                   [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
        $err = & $validate $val
        if (-not $err) { return $val }
        Write-Fail $err
        if ($i -eq $attempts - 1) { Write-Fail "Too many failed attempts. Exiting."; exit 1 }
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1 — Collect credentials
# ═══════════════════════════════════════════════════════════════════════════
Write-Phase "Phase 1: Collecting Credentials"

$env = Read-Env
$requiredKeys = @("N8N_PASSWORD","TELEGRAM_BOT_TOKEN","YOUR_TELEGRAM_CHAT_ID","OCR_SPACE_API_KEY")
$phase1Done = $requiredKeys | ForEach-Object { $env.ContainsKey($_) -and $env[$_] -ne "" } | Where-Object { $_ -eq $false }

if (-not $phase1Done) {
    Write-Success "Phase 1 already complete — skipping"
} else {
    Write-Info ""
    Write-Info "You will need:"
    Write-Info "  • Google service account JSON key file"
    Write-Info "  • Telegram bot token (from @BotFather)"
    Write-Info "  • OCR.Space API key (free at ocr.space/ocrapi)"
    Write-Info ""

    # 1/6 — n8n password
    $n8nPass = Prompt-Secret "[1/6] n8n admin password (min 8 chars, no spaces)" 3 {
        param($v)
        if ($v.Length -lt 8)       { return "Must be at least 8 characters" }
        if ($v -match "\s")         { return "Must not contain spaces" }
        return $null
    }

    # 2/6 — Google JSON
    $googleEmail = ""; $googleKey = ""
    $jsonPath = Prompt-Validated "[2/6] Path to Google service account JSON" 3 {
        param($p)
        $p = $p -replace "^~", $HOME
        if (-not (Test-Path $p)) { return "File not found: $p" }
        try {
            $j = Get-Content $p -Raw | ConvertFrom-Json
            if (-not $j.client_email -or -not $j.private_key) { return "Missing client_email or private_key in JSON" }
            $script:googleEmail = $j.client_email
            $script:googleKey   = $j.private_key
            return $null
        } catch { return "Invalid JSON file: $_" }
    }

    # 3/6 — Personal Google email
    $userEmail = Prompt-Validated "[3/6] Your personal Google email (to access the sheet)" 3 {
        param($v)
        if ($v -notmatch "@") { return "Invalid email format" }
        return $null
    }

    # 4/6 — Telegram token
    $telegramToken = Prompt-Validated "[4/6] Telegram bot token" 3 {
        param($v)
        if ($v -notmatch "^\d{8,10}:[\w\-]{35,}$") { return "Invalid format (expected: 123456789:ABC...)" }
        return $null
    }

    # 5/6 — Telegram chat ID
    $chatId = Prompt-Validated "[5/6] Your Telegram chat ID (numeric)" 3 {
        param($v)
        if ($v -notmatch "^\d+$") { return "Must be numeric only" }
        return $null
    }

    # 6/6 — OCR.Space key
    $ocrKey = Prompt-Validated "[6/6] OCR.Space API key" 3 {
        param($v)
        if ($v -notmatch "^K8[\w]{8,}$") { return "Invalid format (should start with K8)" }
        return $null
    }

    # Write .env (GOOGLE_SHEET_ID and GOOGLE_DRIVE_FOLDER_ID filled in Phase 4)
    $env = @{
        N8N_PASSWORD          = $n8nPass
        TELEGRAM_BOT_TOKEN    = $telegramToken
        YOUR_TELEGRAM_CHAT_ID = $chatId
        OCR_SPACE_API_KEY     = $ocrKey
        GOOGLE_USER_EMAIL     = $userEmail
        GOOGLE_CLIENT_EMAIL   = $googleEmail
        GOOGLE_PRIVATE_KEY    = $googleKey
        GOOGLE_SHEET_ID       = ""
        GOOGLE_DRIVE_FOLDER_ID = ""
    }
    Write-Env $env
    Write-Success "Credentials saved to .env"
}

$env = Read-Env

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2 — Launch n8n
# ═══════════════════════════════════════════════════════════════════════════
Write-Phase "Phase 2: Launching n8n"

$containerUp = (docker ps --filter "name=fintrak-n8n" --format "{{.Status}}" 2>$null) -like "Up*"

if ($containerUp) {
    Write-Success "n8n already running — skipping"
} else {
    Write-Info "Starting n8n container..."
    docker compose up -d 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Fail "docker compose up failed"; exit 1 }

    if (-not (Wait-N8nHealthy)) {
        Write-Fail "n8n did not become healthy within 60 seconds"
        Write-Info "Last container logs:"
        docker compose logs n8n 2>&1 | Select-Object -Last 20 | ForEach-Object { Write-Info $_ }
        exit 1
    }
    Write-Success "n8n is ready at http://localhost:5678"
}

$headers = Get-N8nHeaders $env["N8N_PASSWORD"]

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3 — Configure Google credentials in n8n
# ═══════════════════════════════════════════════════════════════════════════
Write-Phase "Phase 3: Configuring Google Credentials"

$existingCreds = try {
    (Invoke-RestMethod -Uri "http://localhost:5678/rest/credentials" -Headers $headers -ErrorAction SilentlyContinue).data
} catch { @() }

$sheetsExists = $existingCreds | Where-Object { $_.name -eq "Fintrak Google Sheets" }
$driveExists  = $existingCreds | Where-Object { $_.name -eq "Fintrak Google Drive" }

if ($sheetsExists -and $driveExists) {
    Write-Success "Phase 3 already complete — skipping"
} else {
    $clientEmail = $env["GOOGLE_CLIENT_EMAIL"]
    $privateKey  = $env["GOOGLE_PRIVATE_KEY"]

    $tmpDir = $env:TEMP

    foreach ($pair in @(
        @{ template = "setup\credentials-template\google-sheets-cred.json"; tmp = "gs-cred.json" },
        @{ template = "setup\credentials-template\google-drive-cred.json";  tmp = "gd-cred.json" }
    )) {
        $tpl = Get-Content (Join-Path $PSScriptRoot $pair.template) -Raw
        $tpl = $tpl -replace "\{\{CLIENT_EMAIL\}\}", $clientEmail
        $tpl = $tpl -replace "\{\{PRIVATE_KEY\}\}",  $privateKey

        $tmpFile = Join-Path $tmpDir $pair.tmp
        Set-Content -Path $tmpFile -Value $tpl

        docker cp $tmpFile "fintrak-n8n:/tmp/$($pair.tmp)" 2>&1 | Out-Null
        docker exec fintrak-n8n n8n import:credentials --input="/tmp/$($pair.tmp)" 2>&1 | Out-Null
        docker exec fintrak-n8n rm -f "/tmp/$($pair.tmp)" 2>&1 | Out-Null
        Remove-Item $tmpFile -Force
    }

    Write-Success "Google Sheets credential imported"
    Write-Success "Google Drive credential imported"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4 — Provision Google Sheet + Drive folder
# ═══════════════════════════════════════════════════════════════════════════
Write-Phase "Phase 4: Provisioning Google Resources"

$env = Read-Env
if ($env["GOOGLE_SHEET_ID"] -ne "" -and $env["GOOGLE_DRIVE_FOLDER_ID"] -ne "") {
    Write-Success "Phase 4 already complete — skipping"
} else {
    # Import setup workflow
    $setupWf = Join-Path $PSScriptRoot "n8n-workflows\workflow-setup.json"
    docker cp $setupWf "fintrak-n8n:/tmp/workflow-setup.json" 2>&1 | Out-Null
    docker exec fintrak-n8n n8n import:workflow --input="/tmp/workflow-setup.json" 2>&1 | Out-Null
    docker exec fintrak-n8n rm -f "/tmp/workflow-setup.json" 2>&1 | Out-Null

    # Activate the setup workflow so webhook is live
    $workflows = (Invoke-RestMethod -Uri "http://localhost:5678/rest/workflows" -Headers $headers).data
    $setupWfId = ($workflows | Where-Object { $_.name -like "*Provision Google*" }).id

    if (-not $setupWfId) {
        Write-Fail "Could not find setup workflow in n8n after import"
        exit 1
    }

    $null = Invoke-RestMethod -Uri "http://localhost:5678/rest/workflows/$setupWfId/activate" -Method Post -Headers $headers -ErrorAction Stop

    Write-Info "Running setup workflow (creating Sheet + Drive folder)..."

    $body = @{
        userEmail      = $env["GOOGLE_USER_EMAIL"]
        sheetName      = "Fintrak Expenses"
        driveFolderName = "Fintrak/Receipts"
    } | ConvertTo-Json

    try {
        $result = Invoke-RestMethod -Uri "http://localhost:5678/webhook/fintrak-setup" `
            -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop

        $sheetId  = $result.sheetId
        $folderId = $result.driveFolderId

        if (-not $sheetId -or -not $folderId) { throw "Response missing sheetId or driveFolderId" }

        Write-Success "Google Sheet created: $sheetId"
        Write-Success "Drive folder created: $folderId"

        # Update .env
        $env["GOOGLE_SHEET_ID"]        = $sheetId
        $env["GOOGLE_DRIVE_FOLDER_ID"] = $folderId
        Write-Env $env

    } catch {
        Write-Fail "Setup workflow failed: $_"
        Write-Info "n8n is still running at http://localhost:5678 — check workflow logs for details."
        exit 1
    }

    # Deactivate + delete setup workflow
    $null = Invoke-RestMethod -Uri "http://localhost:5678/rest/workflows/$setupWfId/deactivate" -Method Post -Headers $headers -ErrorAction SilentlyContinue
    $null = Invoke-RestMethod -Uri "http://localhost:5678/rest/workflows/$setupWfId" -Method Delete  -Headers $headers -ErrorAction SilentlyContinue
    Write-Info "Setup workflow cleaned up"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5 — Activate main workflows
# ═══════════════════════════════════════════════════════════════════════════
Write-Phase "Phase 5: Activating Workflows"

$env = Read-Env

$existingWfs    = (Invoke-RestMethod -Uri "http://localhost:5678/rest/workflows" -Headers $headers).data
$activeMainWfs  = $existingWfs | Where-Object { $_.active -eq $true -and $_.name -like "Fintrak [A-D]*" }

if (($activeMainWfs | Measure-Object).Count -ge 4) {
    Write-Success "Phase 5 already complete — skipping"
} else {
    # Set n8n Variables
    Write-Info "Setting n8n variables..."
    $variables = @{
        YOUR_TELEGRAM_CHAT_ID  = $env["YOUR_TELEGRAM_CHAT_ID"]
        TELEGRAM_BOT_TOKEN     = $env["TELEGRAM_BOT_TOKEN"]
        OCR_SPACE_API_KEY      = $env["OCR_SPACE_API_KEY"]
        GOOGLE_SHEET_ID        = $env["GOOGLE_SHEET_ID"]
        GOOGLE_DRIVE_FOLDER_ID = $env["GOOGLE_DRIVE_FOLDER_ID"]
    }
    foreach ($kv in $variables.GetEnumerator()) {
        $body = @{ key = $kv.Key; value = $kv.Value } | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri "http://localhost:5678/rest/variables" -Method Post `
                -Body $body -Headers $headers -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
    Write-Success "n8n variables set"

    # Import Telegram credential
    Write-Info "Importing Telegram credential..."
    $tplContent = Get-Content (Join-Path $PSScriptRoot "setup\credentials-template\telegram-cred.json") -Raw
    $tplContent = $tplContent -replace "\{\{TELEGRAM_BOT_TOKEN\}\}", $env["TELEGRAM_BOT_TOKEN"]
    $tmpTg = Join-Path $env:TEMP "tg-cred.json"
    Set-Content -Path $tmpTg -Value $tplContent

    docker cp $tmpTg "fintrak-n8n:/tmp/tg-cred.json" 2>&1 | Out-Null
    docker exec fintrak-n8n n8n import:credentials --input="/tmp/tg-cred.json" 2>&1 | Out-Null
    docker exec fintrak-n8n rm -f "/tmp/tg-cred.json" 2>&1 | Out-Null
    Remove-Item $tmpTg -Force
    Write-Success "Telegram credential imported"

    # Import + activate 4 main workflows
    Write-Info "Importing main workflows..."
    $wfFiles = @(
        "n8n-workflows\workflow-a-receipt.json",
        "n8n-workflows\workflow-b-text.json",
        "n8n-workflows\workflow-c-commands.json",
        "n8n-workflows\workflow-d-daily-cron.json"
    )
    foreach ($wf in $wfFiles) {
        $full     = Join-Path $PSScriptRoot $wf
        $basename = Split-Path $wf -Leaf
        docker cp $full "fintrak-n8n:/tmp/$basename" 2>&1 | Out-Null
        docker exec fintrak-n8n n8n import:workflow --input="/tmp/$basename" 2>&1 | Out-Null
        docker exec fintrak-n8n rm -f "/tmp/$basename" 2>&1 | Out-Null
    }
    Write-Success "Workflows imported"

    # Activate all 4
    $allWfs = (Invoke-RestMethod -Uri "http://localhost:5678/rest/workflows" -Headers $headers).data
    foreach ($wf in ($allWfs | Where-Object { $_.name -like "Fintrak [A-D]*" })) {
        if (-not $wf.active) {
            Invoke-RestMethod -Uri "http://localhost:5678/rest/workflows/$($wf.id)/activate" `
                -Method Post -Headers $headers -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Write-Success "All workflows activated"

    # Telegram test message
    Write-Info "Sending test message to Telegram..."
    try {
        $telegramUrl  = "https://api.telegram.org/bot$($env["TELEGRAM_BOT_TOKEN"])/sendMessage"
        $telegramBody = @{
            chat_id = $env["YOUR_TELEGRAM_CHAT_ID"]
            text    = "✅ Fintrak is live! Send me a receipt photo to get started."
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $telegramUrl -Method Post -Body $telegramBody `
            -ContentType "application/json" -ErrorAction Stop | Out-Null
        Write-Success "Test message sent"
    } catch {
        Write-Warn "Could not send Telegram test message — check your bot token and chat ID."
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# Done!
# ═══════════════════════════════════════════════════════════════════════════
$env = Read-Env
Write-Host ""
Write-Host "🎉 Fintrak is live!" -ForegroundColor Green
Write-Host ""
Write-Info "   n8n dashboard : http://localhost:5678"
Write-Info "   Username      : admin / (your password)"
Write-Info "   Google Sheet  : https://docs.google.com/spreadsheets/d/$($env["GOOGLE_SHEET_ID"])"
Write-Info "   Telegram      : Send a receipt photo to your bot to get started"
Write-Host ""
