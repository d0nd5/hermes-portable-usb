# ==============================================================================
# HERMES PORTABLE USB BUILDER -- Windows
# Bad Systems Syndicate / CRL
# NousResearch/hermes-agent v0.14.x | MIT License
#
# IMPORTANT: exFAT USBs do not support symlinks. This script installs Hermes
# runtimes/venv on the HOST (%LOCALAPPDATA%\hermes-usb\) and keeps only DATA
# (sessions, memory, skills, .env) on the USB. The launcher sets HERMES_HOME
# to the host cache and HERMES_DATA to the USB on every invocation.
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
$USB_DATA    = "$USB_ROOT\hermes-portable\data"
# Runtimes on HOST (NTFS, supports symlinks/junctions)
$HOST_HERMES = "$env:LOCALAPPDATA\hermes-usb"

Write-Host ""
Write-Host "  HERMES PORTABLE USB BUILDER (Windows)"  -ForegroundColor Magenta
Write-Host "  Bad Systems Syndicate / CRL"             -ForegroundColor Magenta
Write-Host "  NousResearch hermes-agent v0.14.x"       -ForegroundColor Magenta
Write-Host "  --------------------------------"         -ForegroundColor DarkGray
Write-Host "  USB Root    : $USB_ROOT"
Write-Host "  USB Data    : $USB_DATA"
Write-Host "  Host Cache  : $HOST_HERMES"
Write-Host "  (exFAT-safe: runtimes on host, data on USB)"
Write-Host ""

$confirm = Read-Host "Proceed? (yes/no)"
if ($confirm -notin @("yes","y")) { Write-Warn "Aborted."; exit 0 }

# -- Step 1: Create USB data dirs (no symlinks needed -- flat files only) ------
Write-Step "Creating USB data directories..."
foreach ($d in @(
    "$USB_ROOT\hermes-portable",
    $USB_DATA,
    "$USB_DATA\sessions",
    "$USB_DATA\memory",
    "$USB_DATA\skills",
    "$USB_ROOT\hermes-portable\logs"
)) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-OK "Created: $d"
    } else {
        Write-Warn "Exists: $d"
    }
}

# -- Step 2: Create host runtime directory -------------------------------------
Write-Step "Creating host runtime directory..."
if (-not (Test-Path $HOST_HERMES)) {
    New-Item -ItemType Directory -Path $HOST_HERMES -Force | Out-Null
}
Write-OK "Host dir ready: $HOST_HERMES"

# -- Step 3: Prerequisites -----------------------------------------------------
Write-Step "Checking prerequisites..."

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Fatal "PowerShell 5.1+ required."
}
Write-OK "PowerShell $($PSVersionTable.PSVersion)"

try {
    $null = Invoke-WebRequest -Uri "https://raw.githubusercontent.com" -UseBasicParsing -TimeoutSec 10
    Write-OK "Internet OK"
} catch {
    Write-Fatal "No internet access."
}

$gitAvail = Get-Command git -ErrorAction SilentlyContinue
if ($gitAvail) {
    Write-OK "Git: $(git --version)"
} else {
    Write-Warn "Git not found -- installer will download PortableGit (~50MB)"
}

$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted") {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-OK "ExecutionPolicy set to RemoteSigned"
}

# -- Step 4: Run official installer with HOST as HERMES_HOME -------------------
Write-Step "Running official installer (runtimes -> host at $HOST_HERMES)..."
Write-Warn "Downloading ~600MB -- do not close this window."

$env:HERMES_HOME = $HOST_HERMES
$env:HERMES_DATA = $USB_DATA
[System.Environment]::SetEnvironmentVariable("HERMES_HOME", $HOST_HERMES, "User")
[System.Environment]::SetEnvironmentVariable("HERMES_DATA", $USB_DATA, "User")

try {
    $script = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1" -UseBasicParsing).Content
    Invoke-Expression $script
} catch {
    Write-Fatal "Official installer failed: $_"
}
Write-OK "Installer complete. Hermes runtimes at: $HOST_HERMES"

# -- Step 5: Junction from host data to USB data dir ---------------------------
Write-Step "Creating junction: host data -> USB data..."

$hostDataLink = "$HOST_HERMES\data"

if (Test-Path $hostDataLink) {
    if ((Get-Item $hostDataLink).LinkType -eq "Junction") {
        Remove-Item $hostDataLink -Force
    } else {
        Rename-Item $hostDataLink "${hostDataLink}.bak" -Force
        Write-Warn "Backed up existing data dir to ${hostDataLink}.bak"
    }
}

cmd /c "mklink /J `"$hostDataLink`" `"$USB_DATA`"" | Out-Null
Write-OK "Junction created: $hostDataLink -> $USB_DATA"

# -- Step 6: .env scaffold -----------------------------------------------------
Write-Step "Creating .env scaffold on USB..."
$envFile = "$USB_DATA\.env"
if (-not (Test-Path $envFile)) {
    $envContent = @'
# ==============================================================================
# HERMES PORTABLE -- API KEY CONFIGURATION
# Bad Systems Syndicate / CRL
# WARNING: Encrypt this USB with VeraCrypt before event use.
# ==============================================================================

# -- Choose ONE primary provider (uncomment + fill in) ------------------------

# Anthropic Claude (pay per token)
# ANTHROPIC_API_KEY=sk-ant-...

# OpenRouter (200+ models, one key -- RECOMMENDED for ops)
# OPENROUTER_API_KEY=sk-or-v1-...

# DeepSeek
# DEEPSEEK_API_KEY=sk-...

# Local Ollama (no key needed)
# HERMES_ENDPOINT=http://localhost:11434/v1
# HERMES_MODEL=llama3

# -- Optional tools -----------------------------------------------------------
# TELEGRAM_BOT_TOKEN=
# DISCORD_BOT_TOKEN=

# After editing, run: launch-windows.ps1 model
'@
    [System.IO.File]::WriteAllText($envFile, $envContent, [System.Text.Encoding]::ASCII)
    Write-OK ".env scaffold created: $envFile"
} else {
    Write-Warn ".env exists -- not overwriting"
}

# -- Step 7: launch-windows.ps1 ------------------------------------------------
Write-Step "Writing launch-windows.ps1..."
$launchContent = @'
# ==============================================================================
# HERMES PORTABLE LAUNCHER -- Windows
# Runtimes: %LOCALAPPDATA%\hermes-usb\ (host, NTFS)
# Data:     <USB>\hermes-portable\data\ (USB, exFAT-safe)
# Usage: powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 [args]
# ==============================================================================
param([Parameter(ValueFromRemainingArguments)][string[]]$HermesArgs)

$DRIVE       = Split-Path -Parent $MyInvocation.MyCommand.Path
$USB_DATA    = "$DRIVE\hermes-portable\data"
$HOST_HERMES = "$env:LOCALAPPDATA\hermes-usb"

if (-not (Test-Path $HOST_HERMES)) {
    Write-Host "[XX] Host runtime not found: $HOST_HERMES" -ForegroundColor Red
    Write-Host "[!!] Run hermes-usb-build.ps1 on this machine first." -ForegroundColor Yellow
    exit 1
}

# Re-verify junction points to current USB path
$junctionPath = "$HOST_HERMES\data"
$currentTarget = if (Test-Path $junctionPath) { (Get-Item $junctionPath).Target } else { "" }
if ($currentTarget -ne $USB_DATA) {
    Write-Host "[!!] Re-linking data junction to USB..." -ForegroundColor Yellow
    if (Test-Path $junctionPath) { Remove-Item $junctionPath -Force -Recurse }
    cmd /c "mklink /J `"$junctionPath`" `"$USB_DATA`"" | Out-Null
    Write-Host "[OK] Junction updated: $junctionPath -> $USB_DATA" -ForegroundColor Green
}

$env:HERMES_HOME = $HOST_HERMES
$env:HERMES_DATA = $USB_DATA

foreach ($p in @(
    "$HOST_HERMES\hermes-agent\venv\Scripts",
    "$HOST_HERMES\venv\Scripts",
    "$HOST_HERMES\git\bin"
)) { if (Test-Path $p) { $env:PATH = "$p;$env:PATH" } }

Write-Host "[BSS] Hermes portable"           -ForegroundColor Cyan
Write-Host "[BSS] Runtimes : $HOST_HERMES"   -ForegroundColor DarkCyan
Write-Host "[BSS] Data     : $USB_DATA"      -ForegroundColor DarkCyan
Write-Host ""

if ($HermesArgs.Count -gt 0) { & hermes @HermesArgs } else { & hermes }
'@
[System.IO.File]::WriteAllText("$USB_ROOT\launch-windows.ps1", $launchContent, [System.Text.Encoding]::ASCII)
Write-OK "Created: $USB_ROOT\launch-windows.ps1"

# -- Step 8: launch-linux.sh ---------------------------------------------------
Write-Step "Writing launch-linux.sh..."
$linuxContent = "#!/usr/bin/env bash`n" +
"# HERMES PORTABLE LAUNCHER -- Linux`n" +
"# Runtimes: ~/.hermes-usb/ (host)  Data: <USB>/hermes-portable/data/ (USB)`n" +
'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"' + "`n" +
'USB_DATA="$SCRIPT_DIR/hermes-portable/data"' + "`n" +
'HOST_HERMES="$HOME/.hermes-usb"' + "`n" +
'HOST_DATA_LINK="$HOST_HERMES/data"' + "`n" +
'if [[ ! -d "$HOST_HERMES" ]]; then' + "`n" +
'    echo "[XX] Host runtime not found. Run hermes-usb-build.sh on this machine first."' + "`n" +
'    exit 1' + "`n" +
'fi' + "`n" +
'if [[ ! -L "$HOST_DATA_LINK" ]] || [[ "$(readlink "$HOST_DATA_LINK")" != "$USB_DATA" ]]; then' + "`n" +
'    echo "[!!] Re-linking data dir to USB..."' + "`n" +
'    [[ -d "$HOST_DATA_LINK" && ! -L "$HOST_DATA_LINK" ]] && mv "$HOST_DATA_LINK" "${HOST_DATA_LINK}.bak.$(date +%s)"' + "`n" +
'    ln -sfn "$USB_DATA" "$HOST_DATA_LINK"' + "`n" +
'fi' + "`n" +
'export HERMES_HOME="$HOST_HERMES"' + "`n" +
'export HERMES_DATA="$USB_DATA"' + "`n" +
'for venv in "$HOST_HERMES/hermes-agent/venv/bin" "$HOST_HERMES/venv/bin" "$HOME/.local/bin"; do' + "`n" +
'    [[ -d "$venv" ]] && export PATH="$venv:$PATH"' + "`n" +
'done' + "`n" +
'echo "[BSS] Runtimes: $HOST_HERMES | Data: $USB_DATA"' + "`n" +
'exec hermes "$@"' + "`n"

$linuxContent = $linuxContent -replace "`r`n", "`n"
[System.IO.File]::WriteAllText("$USB_ROOT\launch-linux.sh", $linuxContent, [System.Text.Encoding]::ASCII)
Write-OK "Created: $USB_ROOT\launch-linux.sh (LF line endings)"

# -- Step 9: BOOTSTRAP-NEW-MACHINE.txt -----------------------------------------
Write-Step "Writing BOOTSTRAP-NEW-MACHINE.txt..."
$bootstrapContent = @"
HERMES PORTABLE -- NEW MACHINE SETUP
Bad Systems Syndicate / CRL
================================================

IMPORTANT: exFAT USB does not support symlinks.
Hermes runtimes install to the HOST machine each time.
Your DATA (sessions, memory, keys) stays on the USB.

ON A NEW WINDOWS MACHINE:
  1. Plug in USB
  2. powershell -ExecutionPolicy Bypass -File <drive>:\hermes-usb-build.ps1
     (installs runtimes to %LOCALAPPDATA%\hermes-usb\, ~600MB, once per machine)
  3. powershell -ExecutionPolicy Bypass -File <drive>:\launch-windows.ps1

ON A NEW LINUX MACHINE:
  1. Plug in USB, cd to mount point
  2. chmod +x hermes-usb-build.sh && ./hermes-usb-build.sh
     (installs runtimes to ~/.hermes-usb/, ~600MB, once per machine)
  3. ./launch-linux.sh

YOUR DATA IS ALWAYS ON THE USB:
  hermes-portable\data\.env       -- API keys
  hermes-portable\data\sessions\  -- conversation history
  hermes-portable\data\memory\    -- agent memory
  hermes-portable\data\skills\    -- custom skills

OPSEC: Encrypt this USB with VeraCrypt before event use.
"@
[System.IO.File]::WriteAllText("$USB_ROOT\BOOTSTRAP-NEW-MACHINE.txt", $bootstrapContent, [System.Text.Encoding]::ASCII)
Write-OK "Created: BOOTSTRAP-NEW-MACHINE.txt"

# -- Step 10: README -----------------------------------------------------------
$buildDate = Get-Date -Format "yyyy-MM-dd HH:mm"
[System.IO.File]::WriteAllText("$USB_ROOT\README.txt", @"
HERMES PORTABLE -- BAD SYSTEMS SYNDICATE / CRL
Built: $buildDate on $env:COMPUTERNAME
================================================
DAILY USE:
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1 model
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1 doctor

NEW MACHINE: See BOOTSTRAP-NEW-MACHINE.txt
OPSEC: Encrypt with VeraCrypt. Docs: https://hermes-agent.nousresearch.com/docs
"@, [System.Text.Encoding]::ASCII)
Write-OK "Created: README.txt"

# -- Step 11: Health check -----------------------------------------------------
Write-Step "Health check..."
$refreshedPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$env:PATH = "$refreshedPath;$env:PATH"
try {
    $v = & hermes --version 2>&1
    Write-OK "hermes: $v"
} catch {
    Write-Warn "hermes not in PATH yet -- open new PowerShell and use launch-windows.ps1"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Runtimes : $HOST_HERMES"
Write-Host "  Data     : $USB_DATA"
Write-Host ""
Write-Host "  NEXT STEPS:"
Write-Host "  1. Edit hermes-portable\data\.env -- add API key"
Write-Host "  2. Open NEW PowerShell window"
Write-Host "  3. powershell -ExecutionPolicy Bypass -File launch-windows.ps1 model"
Write-Host "  4. powershell -ExecutionPolicy Bypass -File launch-windows.ps1 doctor"
Write-Host "  5. powershell -ExecutionPolicy Bypass -File launch-windows.ps1"
Write-Host ""
Write-Host "  NEW MACHINE: run hermes-usb-build.ps1 on it first" -ForegroundColor Yellow
Write-Host "  OPSEC: Encrypt USB with VeraCrypt before events"    -ForegroundColor Yellow
Write-Host ""
