#!/usr/bin/env bash
# ==============================================================================
# HERMES PORTABLE USB BUILDER -- Linux
# Bad Systems Syndicate / CRL
# NousResearch/hermes-agent v0.14.x | MIT License
#
# IMPORTANT: exFAT USBs do not support symlinks. This script installs Hermes
# runtimes/venv on the HOST (under ~/.hermes-usb/) and keeps only DATA
# (sessions, memory, skills, .env) on the USB. The launcher sets HERMES_HOME
# to the host cache and HERMES_DATA to the USB on every invocation.
#
# Usage:
#   chmod +x hermes-usb-build.sh
#   ./hermes-usb-build.sh
# ==============================================================================

set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
step()  { echo -e "\n${CYAN}[>>] $*${NC}"; }
ok()    { echo -e "${GREEN}[OK] $*${NC}"; }
warn()  { echo -e "${YELLOW}[!!] $*${NC}"; }
fatal() { echo -e "${RED}[XX] $*${NC}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -- Paths --
# DATA stays on the USB (no symlinks needed -- only flat files/dirs)
USB_DATA="$SCRIPT_DIR/hermes-portable/data"
# RUNTIME lives on the HOST (supports symlinks, native FS)
HOST_HERMES="$HOME/.hermes-usb"
HOST_DATA_LINK="$HOST_HERMES/data"   # symlink on host pointing to USB data

echo -e "${CYAN}
  HERMES PORTABLE USB BUILDER (Linux)
  Bad Systems Syndicate / CRL
  NousResearch hermes-agent v0.14.x
  ----------------------------------
  USB Root   : $SCRIPT_DIR
  USB Data   : $USB_DATA
  Host Cache : $HOST_HERMES
  (exFAT-safe: runtimes on host, data on USB)
${NC}"

read -rp "Proceed? (yes/no): " confirm
[[ "$confirm" =~ ^(yes|y)$ ]] || { warn "Aborted."; exit 0; }

# -- Step 1: Create USB data directories (no symlinks, flat files only) --------
step "Creating USB data directories..."
mkdir -p "$USB_DATA/sessions"
mkdir -p "$USB_DATA/memory"
mkdir -p "$USB_DATA/skills"
mkdir -p "$SCRIPT_DIR/hermes-portable/logs"
ok "USB data dirs ready"

# -- Step 2: Create host runtime directory -------------------------------------
step "Creating host runtime directory at $HOST_HERMES..."
mkdir -p "$HOST_HERMES"
ok "Host dir ready: $HOST_HERMES"

# -- Step 3: Prerequisites -----------------------------------------------------
step "Checking prerequisites..."

command -v curl &>/dev/null || fatal "curl not found. Install: sudo apt install curl"

if command -v git &>/dev/null; then
    ok "Git: $(git --version)"
else
    warn "Git not found -- attempting install..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y git && ok "git installed"
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git && ok "git installed"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git && ok "git installed"
    else
        fatal "Cannot auto-install git. Install manually and re-run."
    fi
fi

curl -fsSL --max-time 10 https://raw.githubusercontent.com &>/dev/null \
    && ok "Internet OK" \
    || fatal "No internet access."

# -- Step 4: Run official installer with HOST as HERMES_HOME -------------------
step "Running official Nous Research installer (runtimes -> host)..."
warn "HERMES_HOME set to HOST: $HOST_HERMES"
warn "This avoids the exFAT symlink limitation."
warn "Downloading ~600MB -- do not close terminal."

export HERMES_HOME="$HOST_HERMES"
export HERMES_DATA="$USB_DATA"

curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash \
    || fatal "Official installer failed."

ok "Installer complete. Hermes runtimes at: $HOST_HERMES"

# -- Step 5: Link host data dir to USB data dir --------------------------------
step "Linking host data pointer to USB data dir..."

# Remove any data dir the installer may have created on the host
if [[ -d "$HOST_DATA_LINK" && ! -L "$HOST_DATA_LINK" ]]; then
    warn "Backing up host data dir created by installer: ${HOST_DATA_LINK}.bak"
    mv "$HOST_DATA_LINK" "${HOST_DATA_LINK}.bak"
fi

# Create symlink on host FS pointing to USB data (symlink itself lives on ext4)
ln -sfn "$USB_DATA" "$HOST_DATA_LINK"
ok "Linked: $HOST_DATA_LINK -> $USB_DATA"

# -- Step 6: .env scaffold -----------------------------------------------------
step "Creating .env scaffold on USB..."
ENV_FILE="$USB_DATA/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    cat > "$ENV_FILE" << 'ENVEOF'
# ==============================================================================
# HERMES PORTABLE -- API KEY CONFIGURATION
# Bad Systems Syndicate / CRL
# WARNING: Encrypt this USB with VeraCrypt before event use.
# ==============================================================================

# -- Choose ONE primary provider (uncomment + fill in) ------------------------

# Anthropic Claude (API key -- pay per token)
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

# After editing, run: ./launch-linux.sh model
ENVEOF
    chmod 600 "$ENV_FILE"
    ok ".env scaffold created (chmod 600)"
else
    warn ".env exists -- not overwriting"
fi

# -- Step 7: Write launch-linux.sh to USB root ---------------------------------
step "Writing launch-linux.sh..."
LAUNCH="$SCRIPT_DIR/launch-linux.sh"
cat > "$LAUNCH" << 'LAUNCHEOF'
#!/usr/bin/env bash
# ==============================================================================
# HERMES PORTABLE LAUNCHER -- Linux
# Runtimes: ~/.hermes-usb/ (host, supports symlinks)
# Data:      <USB>/hermes-portable/data/ (USB, exFAT-safe)
# Usage: ./launch-linux.sh [hermes args]
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USB_DATA="$SCRIPT_DIR/hermes-portable/data"
HOST_HERMES="$HOME/.hermes-usb"
HOST_DATA_LINK="$HOST_HERMES/data"

# -- Verify host install exists ------------------------------------------------
if [[ ! -d "$HOST_HERMES" ]]; then
    echo -e "\033[0;31m[XX] Host runtime not found: $HOST_HERMES\033[0m"
    echo -e "\033[1;33m[!!] Run hermes-usb-build.sh on this machine first.\033[0m"
    exit 1
fi

# -- Re-link data dir to USB (in case USB was replugged or path changed) -------
if [[ ! -L "$HOST_DATA_LINK" ]] || [[ "$(readlink "$HOST_DATA_LINK")" != "$USB_DATA" ]]; then
    echo -e "\033[1;33m[!!] Re-linking data dir to USB...\033[0m"
    [[ -d "$HOST_DATA_LINK" && ! -L "$HOST_DATA_LINK" ]] && mv "$HOST_DATA_LINK" "${HOST_DATA_LINK}.bak.$(date +%s)"
    ln -sfn "$USB_DATA" "$HOST_DATA_LINK"
    echo -e "\033[0;32m[OK] Linked: $HOST_DATA_LINK -> $USB_DATA\033[0m"
fi

# -- Set env -------------------------------------------------------------------
export HERMES_HOME="$HOST_HERMES"
export HERMES_DATA="$USB_DATA"

# Add venv to PATH
for venv in \
    "$HOST_HERMES/hermes-agent/venv/bin" \
    "$HOST_HERMES/venv/bin" \
    "$HOME/.local/bin"; do
    [[ -d "$venv" ]] && export PATH="$venv:$PATH"
done

echo -e "\033[0;36m[BSS] Hermes portable\033[0m"
echo -e "\033[0;36m[BSS] Runtimes : $HOST_HERMES\033[0m"
echo -e "\033[0;36m[BSS] Data     : $USB_DATA\033[0m"
echo ""

exec hermes "$@"
LAUNCHEOF
chmod +x "$LAUNCH"
ok "Created: $LAUNCH"

# -- Step 8: Write launch-windows.ps1 to USB root (for cross-platform) ---------
step "Writing launch-windows.ps1..."
WIN_LAUNCH="$SCRIPT_DIR/launch-windows.ps1"
cat > "$WIN_LAUNCH" << 'WINEOF'
# ==============================================================================
# HERMES PORTABLE LAUNCHER -- Windows
# NOTE: On Windows, runtimes also install to host (%LOCALAPPDATA%\hermes-usb\)
#       to avoid exFAT symlink limitations. Run hermes-usb-build.ps1 first.
# Usage: powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 [args]
# ==============================================================================
param([Parameter(ValueFromRemainingArguments)][string[]]$HermesArgs)

$DRIVE    = Split-Path -Parent $MyInvocation.MyCommand.Path
$USB_DATA = "$DRIVE\hermes-portable\data"
$HOST_HERMES = "$env:LOCALAPPDATA\hermes-usb"

if (-not (Test-Path $HOST_HERMES)) {
    Write-Host "[XX] Host runtime not found: $HOST_HERMES" -ForegroundColor Red
    Write-Host "[!!] Run hermes-usb-build.ps1 on this machine first." -ForegroundColor Yellow
    exit 1
}

$env:HERMES_HOME = $HOST_HERMES
$env:HERMES_DATA = $USB_DATA

foreach ($p in @(
    "$HOST_HERMES\hermes-agent\venv\Scripts",
    "$HOST_HERMES\venv\Scripts",
    "$HOST_HERMES\git\bin"
)) { if (Test-Path $p) { $env:PATH = "$p;$env:PATH" } }

Write-Host "[BSS] Hermes portable"               -ForegroundColor Cyan
Write-Host "[BSS] Runtimes : $HOST_HERMES"       -ForegroundColor DarkCyan
Write-Host "[BSS] Data     : $USB_DATA"          -ForegroundColor DarkCyan
Write-Host ""

if ($HermesArgs.Count -gt 0) { & hermes @HermesArgs } else { & hermes }
WINEOF
ok "Created: $WIN_LAUNCH"

# -- Step 9: Write per-machine bootstrap note ----------------------------------
step "Writing BOOTSTRAP-NEW-MACHINE.txt..."
cat > "$SCRIPT_DIR/BOOTSTRAP-NEW-MACHINE.txt" << BSEOF
HERMES PORTABLE -- NEW MACHINE SETUP
Bad Systems Syndicate / CRL
================================================

IMPORTANT: Because this USB is exFAT, Hermes runtimes (Python venv,
Node.js) must be installed on each new host machine. Your DATA
(sessions, memory, API keys) stays on this USB and is never touched.

ON A NEW LINUX MACHINE:
  1. Plug in USB
  2. cd to USB mount point
  3. chmod +x hermes-usb-build.sh
  4. ./hermes-usb-build.sh
     (installs runtimes to ~/.hermes-usb/ on host, ~600MB, once per machine)
  5. ./launch-linux.sh

ON A NEW WINDOWS MACHINE:
  1. Plug in USB
  2. Run hermes-usb-build.ps1 (installs to %LOCALAPPDATA%\hermes-usb\)
  3. Run launch-windows.ps1

YOUR DATA IS ALWAYS ON THE USB:
  hermes-portable/data/.env       -- API keys
  hermes-portable/data/sessions/  -- conversation history
  hermes-portable/data/memory/    -- agent memory
  hermes-portable/data/skills/    -- custom skills

OPSEC: Encrypt this USB with VeraCrypt before event use.
BSEOF
ok "Created: $SCRIPT_DIR/BOOTSTRAP-NEW-MACHINE.txt"

# -- Step 10: README -----------------------------------------------------------
step "Writing README.txt..."
cat > "$SCRIPT_DIR/README.txt" << READMEEOF
HERMES PORTABLE -- BAD SYSTEMS SYNDICATE / CRL
NousResearch hermes-agent | MIT License
Built: $(date '+%Y-%m-%d %H:%M') on $(hostname)
================================================

DAILY USE (this machine):
  ./launch-linux.sh
  ./launch-linux.sh model
  ./launch-linux.sh doctor

NEW MACHINE: See BOOTSTRAP-NEW-MACHINE.txt

OPSEC: Encrypt with VeraCrypt before event use.
Docs: https://hermes-agent.nousresearch.com/docs
READMEEOF
ok "Created: README.txt"

# -- Step 11: Health check -----------------------------------------------------
step "Post-install health check..."
export PATH="$HOME/.local/bin:$PATH"
if command -v hermes &>/dev/null; then
    ok "hermes: $(hermes --version 2>&1 || echo 'installed')"
else
    warn "hermes not in PATH yet -- open new terminal and run ./launch-linux.sh"
fi

echo -e "${GREEN}
================================================
  BUILD COMPLETE
================================================
  Runtimes : $HOST_HERMES  (host)
  Data     : $USB_DATA  (USB)

  NEXT STEPS:
  1. nano hermes-portable/data/.env -- add API key
  2. Open new terminal
  3. ./launch-linux.sh model
  4. ./launch-linux.sh doctor
  5. ./launch-linux.sh

  NEW MACHINE: run hermes-usb-build.sh again on it
  OPSEC: Encrypt USB with VeraCrypt before events
  Docs: https://hermes-agent.nousresearch.com/docs
================================================
${NC}"
