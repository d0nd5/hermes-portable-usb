# ==============================================================================
# HERMES PORTABLE USB BUILDER -- Bad Systems Syndicate / CRL
# NousResearch/hermes-agent v0.14.x | MIT License
# Run ONCE from USB drive root on Windows with local admin + internet access.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\hermes-usb-build.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

function Write-Step  { param($msg) Write-Host "`n[>>] $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "[OK] $msg"   -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[!!] $msg"   -ForegroundColor Yellow }
function Write-Fatal { param($msg) Write-Host "[XX] $msg"   -ForegroundColor Red; exit 1 }

# -- Paths --
$USB_ROOT    = Split-Path -Parent $MyInvocation.MyCommand.Path
$HERMES_HOME = "$USB_ROOT\hermes-portable"
$HERMES_DATA = "$HERMES_HOME\data"
$HERMES_REPO = "$HERMES_HOME\hermes-agent"

Write-Host ""
Write-Host "  HERMES PORTABLE USB BUILDER"   -ForegroundColor Magenta
Write-Host "  Bad Systems Syndicate / CRL"   -ForegroundColor Magenta
Write-Host "  NousResearch hermes-agent v0.14.x" -ForegroundColor Magenta
Write-Host "  --------------------------------" -ForegroundColor DarkGray
Write-Host "  USB Root   : $USB_ROOT"
Write-Host "  HERMES_HOME: $HERMES_HOME"
Write-Host "  HERMES_DATA: $HERMES_DATA"
Write-Host ""

$confirm = Read-Host "Proceed with installation? (yes/no)"
if ($confirm -notin @("yes","y")) { Write-Warn "Aborted by user."; exit 0 }

# -- Step 1: Directory structure --
Write-Step "Creating directory structure on USB..."
$dirs = @(
    $HERMES_HOME,
    $HERMES_DATA,
    "$HERMES_DATA\sessions",
    "$HERMES_DATA\memory",
    "$HERMES_DATA\skills",
    "$HERMES_HOME\logs"
)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-OK "Created: $d"
    } else {
        Write-Warn "Exists (skipped): $d"
    }
}

# -- Step 2: Prerequisites --
Write-Step "Checking prerequisites..."

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Fatal "PowerShell 5.1+ required. Current: $($PSVersionTable.PSVersion)"
}
Write-OK "PowerShell $($PSVersionTable.PSVersion)"

try {
    $null = Invoke-WebRequest -Uri "https://raw.githubusercontent.com" -UseBasicParsing -TimeoutSec 10
    Write-OK "Internet connectivity confirmed"
} catch {
    Write-Fatal "No internet access. Cannot proceed -- installer downloads ~600MB."
}

$gitAvail = Get-Command git -ErrorAction SilentlyContinue
if ($gitAvail) {
    Write-OK "Git found: $(git --version)"
} else {
    Write-Warn "Git not found -- official installer will download PortableGit (~50MB) automatically"
}

$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted") {
    Write-Warn "Execution policy is Restricted. Setting to RemoteSigned for CurrentUser..."
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-OK "ExecutionPolicy set to RemoteSigned"
}

# -- Step 3: Run official installer --
Write-Step "Setting HERMES_HOME and running official Nous Research installer..."

$env:HERMES_HOME = $HERMES_HOME
$env:HERMES_DATA = $HERMES_DATA
[System.Environment]::SetEnvironmentVariable("HERMES_HOME", $HERMES_HOME, "User")
[System.Environment]::SetEnvironmentVariable("HERMES_DATA", $HERMES_DATA, "User")

Write-OK "HERMES_HOME set to: $HERMES_HOME"
Write-Warn "Starting official installer -- downloading ~600MB (Python, Node.js, runtimes)"
Write-Warn "Do NOT close this window during installation."

try {
    $installerScript = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1" -UseBasicParsing).Content
    Invoke-Expression $installerScript
} catch {
    Write-Fatal "Official installer failed: $_"
}
Write-OK "Official installer completed."

# -- Step 4: Verify binary --
Write-Step "Verifying Hermes binary..."

$hermesPath = $null
$candidates = @(
    "$HERMES_REPO\venv\Scripts\hermes.exe",
    "$HERMES_HOME\venv\Scripts\hermes.exe"
)
foreach ($c in $candidates) {
    if (Test-Path $c) { $hermesPath = $c; break }
}
if (-not $hermesPath) {
    $found = Get-ChildItem -Path $HERMES_HOME -Filter "hermes.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $hermesPath = $found.FullName }
}

if ($hermesPath) {
    Write-OK "Found binary: $hermesPath"
} else {
    Write-Warn "hermes.exe not found in expected locations -- run 'hermes doctor' after first launch."
    $hermesPath = "hermes"
}

# -- Step 5: .env scaffold --
Write-Step "Creating .env scaffold..."

$envFile = "$HERMES_DATA\.env"
if (-not (Test-Path $envFile)) {
    $envContent = @'
# ==============================================================================
# HERMES PORTABLE -- API KEY CONFIGURATION
# Bad Systems Syndicate / CRL
# WARNING: Raw credentials stored here.
#          ENCRYPT THIS DRIVE with VeraCrypt before event use.
# ==============================================================================

# -- Choose ONE primary provider (uncomment and fill in) ----------------------

# Anthropic Claude (API key -- pay per token)
# ANTHROPIC_API_KEY=sk-ant-...

# OpenRouter (200+ models, one key -- RECOMMENDED for ops)
# OPENROUTER_API_KEY=sk-or-v1-...

# DeepSeek (cheap, fast reasoning)
# DEEPSEEK_API_KEY=sk-...

# Local Ollama endpoint (no API key needed)
# HERMES_ENDPOINT=http://localhost:11434/v1
# HERMES_MODEL=llama3

# -- Optional tools -----------------------------------------------------------
# TELEGRAM_BOT_TOKEN=
# DISCORD_BOT_TOKEN=
# OPENWEATHER_API_KEY=

# After editing, run: launch-windows.ps1 model
'@
    [System.IO.File]::WriteAllText($envFile, $envContent, [System.Text.Encoding]::ASCII)
    Write-OK ".env scaffold created: $envFile"
} else {
    Write-Warn ".env already exists -- skipping (not overwriting your keys)"
}

# -- Step 6: launch-windows.ps1 --
Write-Step "Writing launch-windows.ps1..."

$launchWinContent = @'
# ==============================================================================
# HERMES PORTABLE LAUNCHER -- Windows
# Usage: powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 [args]
# Examples:
#   .\launch-windows.ps1
#   .\launch-windows.ps1 model
#   .\launch-windows.ps1 doctor
#   .\launch-windows.ps1 chat
# ==============================================================================
param([Parameter(ValueFromRemainingArguments)][string[]]$HermesArgs)

$DRIVE       = Split-Path -Parent $MyInvocation.MyCommand.Path
$HERMES_HOME = "$DRIVE\hermes-portable"
$HERMES_DATA = "$HERMES_HOME\data"

$env:HERMES_HOME = $HERMES_HOME
$env:HERMES_DATA = $HERMES_DATA

foreach ($p in @(
    "$HERMES_HOME\hermes-agent\venv\Scripts",
    "$HERMES_HOME\venv\Scripts",
    "$HERMES_HOME\git\bin"
)) {
    if (Test-Path $p) { $env:PATH = "$p;$env:PATH" }
}

Write-Host "[BSS] Hermes portable | Drive: $DRIVE"    -ForegroundColor Cyan
Write-Host "[BSS] HERMES_HOME    : $HERMES_HOME"      -ForegroundColor DarkCyan
Write-Host "[BSS] HERMES_DATA    : $HERMES_DATA"      -ForegroundColor DarkCyan
Write-Host ""

if ($HermesArgs.Count -gt 0) {
    & hermes @HermesArgs
} else {
    & hermes
}
'@
$launchWin = "$USB_ROOT\launch-windows.ps1"
[System.IO.File]::WriteAllText($launchWin, $launchWinContent, [System.Text.Encoding]::ASCII)
Write-OK "Created: $launchWin"

# -- Step 7: launch-linux.sh --
Write-Step "Writing launch-linux.sh..."

$launchLinContent = "#!/usr/bin/env bash`n" +
"# ==============================================================================`n" +
"# HERMES PORTABLE LAUNCHER -- Linux`n" +
"# Usage: ./launch-linux.sh [hermes args]`n" +
"# ==============================================================================`n" +
'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"' + "`n" +
'export HERMES_HOME="$SCRIPT_DIR/hermes-portable"' + "`n" +
'export HERMES_DATA="$HERMES_HOME/data"' + "`n" +
"`n" +
'for venv in "$HERMES_HOME/hermes-agent/venv/bin" "$HERMES_HOME/venv/bin" "$HOME/.local/bin"; do' + "`n" +
'    [ -d "$venv" ] && export PATH="$venv:$PATH"' + "`n" +
"done`n" +
"`n" +
'echo "[BSS] Hermes portable | Drive: $SCRIPT_DIR"' + "`n" +
'echo "[BSS] HERMES_HOME    : $HERMES_HOME"' + "`n" +
'echo ""' + "`n" +
'exec hermes "$@"' + "`n"

$launchLin = "$USB_ROOT\launch-linux.sh"
# Write with LF line endings only
$launchLinContent = $launchLinContent -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($launchLin, $launchLinContent, [System.Text.Encoding]::ASCII)
Write-OK "Created: $launchLin (LF line endings)"

# -- Step 8: README --
Write-Step "Writing README.txt..."

$buildDate = Get-Date -Format "yyyy-MM-dd HH:mm"
$readmeContent = @"
HERMES PORTABLE -- BAD SYSTEMS SYNDICATE / CRL
NousResearch hermes-agent | MIT License
Built: $buildDate
USB Root: $USB_ROOT
================================================

FIRST-TIME SETUP:
1. Edit hermes-portable\data\.env -- add your API key(s)
2. Open new PowerShell window
3. powershell -ExecutionPolicy Bypass -File launch-windows.ps1 model
4. powershell -ExecutionPolicy Bypass -File launch-windows.ps1 doctor
5. powershell -ExecutionPolicy Bypass -File launch-windows.ps1

WINDOWS (subsequent use):
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1 model
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1 doctor
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1 chat

LINUX (plug in USB, then):
  chmod +x launch-linux.sh
  ./launch-linux.sh
  ./launch-linux.sh model

OPSEC:
  hermes-portable\data\.env     -- raw API keys
  hermes-portable\data\sessions -- full chat history
  ENCRYPT THIS DRIVE with VeraCrypt before event use.
  Do NOT store production keys on unencrypted portable drives.

HERMES COMMANDS:
  hermes           -- interactive chat (TUI)
  hermes model     -- configure LLM provider
  hermes doctor    -- diagnose install issues
  hermes tools     -- configure enabled tools
  hermes gateway   -- setup Telegram/Discord/Slack
  hermes config    -- view/set config values
  hermes update    -- update to latest version

DOCS:
  https://hermes-agent.nousresearch.com/docs
  https://github.com/NousResearch/hermes-agent
  Discord: https://discord.gg/NousResearch
"@
[System.IO.File]::WriteAllText("$USB_ROOT\README.txt", $readmeContent, [System.Text.Encoding]::ASCII)
Write-OK "Created: $USB_ROOT\README.txt"

# -- Step 9: Health check --
Write-Step "Running post-install health check..."

$refreshedPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$env:PATH = "$refreshedPath;$env:PATH"

try {
    $v = & hermes --version 2>&1
    Write-OK "hermes --version: $v"
} catch {
    Write-Warn "hermes not yet in PATH for this shell -- open a new PowerShell window and use launch-windows.ps1"
}

# -- Done --
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  NEXT STEPS:"
Write-Host "  1. Edit hermes-portable\data\.env -- add your API key"
Write-Host "  2. Open a NEW PowerShell window"
Write-Host "  3. powershell -ExecutionPolicy Bypass -File launch-windows.ps1 model"
Write-Host "  4. powershell -ExecutionPolicy Bypass -File launch-windows.ps1 doctor"
Write-Host "  5. powershell -ExecutionPolicy Bypass -File launch-windows.ps1"
Write-Host ""
Write-Host "  OPSEC: Encrypt drive with VeraCrypt before field use." -ForegroundColor Yellow
Write-Host "  Docs : https://hermes-agent.nousresearch.com/docs"
Write-Host ""
