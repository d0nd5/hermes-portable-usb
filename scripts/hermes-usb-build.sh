#!/usr/bin/env bash
# =============================================================================
# HERMES PORTABLE USB BUILDER — Linux companion
# Bad Systems Syndicate / CRL
# Run ONCE from the USB mount point on a Linux machine with internet access.
#
# Usage:
#   chmod +x hermes-usb-build.sh
#   ./hermes-usb-build.sh
#
# Requires: bash, curl, git (installer handles Python/Node)
# =============================================================================

set -euo pipefail

# ── Color helpers ─────────────────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
step()  { echo -e "\n${CYAN}[>>] $*${NC}"; }
ok()    { echo -e "${GREEN}[OK] $*${NC}"; }
warn()  { echo -e "${YELLOW}[!!] $*${NC}"; }
fatal() { echo -e "${RED}[XX] $*${NC}"; exit 1; }

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="$SCRIPT_DIR/hermes-portable"
HERMES_DATA="$HERMES_HOME/data"

echo -e "${CYAN}
  ██████╗ ███████╗███████╗
  ██╔══██╗██╔════╝██╔════╝
  ██████╔╝███████╗███████╗
  ██╔══██╗╚════██║╚════██║
  ██████╔╝███████║███████║
  ╚═════╝ ╚══════╝╚══════╝
  HERMES PORTABLE USB BUILDER (Linux)
  Bad Systems Syndicate / CRL
  NousResearch hermes-agent v0.14.x
  ──────────────────────────────────
  USB Root   : $SCRIPT_DIR
  HERMES_HOME: $HERMES_HOME
  HERMES_DATA: $HERMES_DATA
${NC}"

read -rp "Proceed with installation? (yes/no): " confirm
[[ "$confirm" =~ ^(yes|y)$ ]] || { warn "Aborted."; exit 0; }

# ── Step 1: Directory structure ───────────────────────────────────────────────
step "Creating directory structure..."
for d in "$HERMES_HOME" "$HERMES_DATA" "$HERMES_DATA/sessions" "$HERMES_DATA/memory" "$HERMES_DATA/skills" "$HERMES_HOME/logs"; do
    mkdir -p "$d"
    ok "Ensured: $d"
done

# ── Step 2: Check prerequisites ───────────────────────────────────────────────
step "Checking prerequisites..."

command -v curl  &>/dev/null || fatal "curl not found. Install it: sudo apt install curl"
command -v bash  &>/dev/null || fatal "bash not found."

if command -v git &>/dev/null; then
    ok "Git: $(git --version)"
else
    warn "Git not found — installer will attempt to install it."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y git && ok "git installed via apt"
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git && ok "git installed via pacman"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git && ok "git installed via dnf"
    else
        fatal "Cannot install git automatically. Install manually and re-run."
    fi
fi

# Internet check
curl -fsSL --max-time 10 https://raw.githubusercontent.com &>/dev/null && ok "Internet connectivity confirmed" \
    || fatal "No internet access. Cannot proceed."

# ── Step 3: Export HERMES_HOME and run official installer ────────────────────
step "Setting HERMES_HOME and running official Nous Research installer..."

export HERMES_HOME
export HERMES_DATA

warn "Starting official installer (~600MB download: Python, Node.js, runtimes)"
warn "Do NOT close this terminal during installation."

curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash \
    || fatal "Official installer failed."

ok "Official installer completed."

# ── Step 4: Verify binary ────────────────────────────────────────────────────
step "Verifying Hermes binary..."

HERMES_BIN=""
for candidate in \
    "$HERMES_HOME/hermes-agent/venv/bin/hermes" \
    "$HERMES_HOME/venv/bin/hermes" \
    "$HOME/.local/bin/hermes"; do
    if [[ -x "$candidate" ]]; then
        HERMES_BIN="$candidate"
        ok "Found binary: $HERMES_BIN"
        break
    fi
done

[[ -z "$HERMES_BIN" ]] && warn "hermes binary not found in expected locations — run 'hermes doctor' after launching."

# ── Step 5: Create .env scaffold ─────────────────────────────────────────────
step "Creating .env scaffold..."

ENV_FILE="$HERMES_DATA/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    cat > "$ENV_FILE" << 'ENVEOF'
# ─────────────────────────────────────────────────────────────────────────────
# HERMES PORTABLE — API KEY CONFIGURATION
# Bad Systems Syndicate / CRL
# WARNING: This file contains sensitive credentials.
#          ENCRYPT THIS DRIVE with VeraCrypt before use at events.
# ─────────────────────────────────────────────────────────────────────────────

# ── Choose ONE primary provider (uncomment and fill in) ──────────────────────

# Anthropic Claude (API key — pay per token)
# ANTHROPIC_API_KEY=sk-ant-...

# OpenRouter (200+ models, one key — RECOMMENDED for ops)
# OPENROUTER_API_KEY=sk-or-v1-...

# DeepSeek (cheap, fast reasoning)
# DEEPSEEK_API_KEY=sk-...

# Local Ollama endpoint (no API key needed)
# HERMES_ENDPOINT=http://localhost:11434/v1
# HERMES_MODEL=llama3

# ── Optional tools ────────────────────────────────────────────────────────────
# TELEGRAM_BOT_TOKEN=
# DISCORD_BOT_TOKEN=
# OPENWEATHER_API_KEY=

# ─────────────────────────────────────────────────────────────────────────────
# After editing, run: ./launch-linux.sh model
# ─────────────────────────────────────────────────────────────────────────────
ENVEOF
    chmod 600 "$ENV_FILE"
    ok ".env scaffold created (chmod 600): $ENV_FILE"
else
    warn ".env already exists — skipping (not overwriting your keys)"
fi

# ── Step 6: Write launch-linux.sh ────────────────────────────────────────────
step "Writing launch-linux.sh..."

LAUNCH="$SCRIPT_DIR/launch-linux.sh"
cat > "$LAUNCH" << 'LAUNCHEOF'
#!/usr/bin/env bash
# =============================================================================
# HERMES PORTABLE LAUNCHER — Linux
# Usage: ./launch-linux.sh [hermes args]
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HERMES_HOME="$SCRIPT_DIR/hermes-portable"
export HERMES_DATA="$HERMES_HOME/data"

for venv in \
    "$HERMES_HOME/hermes-agent/venv/bin" \
    "$HERMES_HOME/venv/bin" \
    "$HOME/.local/bin"; do
    [[ -d "$venv" ]] && export PATH="$venv:$PATH"
done

echo -e "\033[0;36m[BSS] Hermes portable | Drive: $SCRIPT_DIR\033[0m"
echo -e "\033[0;36m[BSS] HERMES_HOME: $HERMES_HOME\033[0m"

exec hermes "$@"
LAUNCHEOF

chmod +x "$LAUNCH"
ok "Created: $LAUNCH"

# ── Step 7: Write launch-windows.ps1 ─────────────────────────────────────────
step "Writing launch-windows.ps1 (for cross-platform USB use)..."

WIN_LAUNCH="$SCRIPT_DIR/launch-windows.ps1"
cat > "$WIN_LAUNCH" << 'WINEOF'
# =============================================================================
# HERMES PORTABLE LAUNCHER — Windows
# Usage: powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 [args]
# =============================================================================
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
)) { if (Test-Path $p) { $env:PATH = "$p;$env:PATH" } }

Write-Host "[BSS] Hermes portable | Drive: $DRIVE" -ForegroundColor Cyan
Write-Host "[BSS] HERMES_HOME: $HERMES_HOME"        -ForegroundColor DarkCyan

if ($HermesArgs.Count -gt 0) { & hermes @HermesArgs } else { & hermes }
WINEOF

# Fix to CRLF for Windows
sed -i 's/$/\r/' "$WIN_LAUNCH" 2>/dev/null || true
ok "Created: $WIN_LAUNCH"

# ── Step 8: Write README ──────────────────────────────────────────────────────
step "Writing README..."
cat > "$SCRIPT_DIR/README.txt" << READMEEOF
HERMES PORTABLE — BAD SYSTEMS SYNDICATE / CRL
NousResearch hermes-agent | MIT License
Built: $(date '+%Y-%m-%d %H:%M')
USB Root: $SCRIPT_DIR
════════════════════════════════════════════════

FIRST-TIME SETUP:
1. Edit hermes-portable/data/.env — add your API key(s)
2. ./launch-linux.sh model     (configure LLM provider)
3. ./launch-linux.sh doctor    (verify install)
4. ./launch-linux.sh           (start chatting)

LINUX USE:
  ./launch-linux.sh
  ./launch-linux.sh model
  ./launch-linux.sh doctor
  ./launch-linux.sh gateway setup

WINDOWS USE:
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1
  powershell -ExecutionPolicy Bypass -File launch-windows.ps1 model

OPSEC REMINDER:
  hermes-portable/data/.env contains raw API keys (chmod 600 set).
  hermes-portable/data/sessions/ contains full chat history.
  ENCRYPT THIS DRIVE with VeraCrypt before field/event use.
  Do NOT store production keys on unencrypted portable drives.

HERMES COMMANDS:
  hermes           — Interactive chat (TUI)
  hermes model     — Switch/configure LLM provider
  hermes doctor    — Diagnose installation issues
  hermes tools     — Configure enabled tools
  hermes gateway   — Set up Telegram/Discord/Slack
  hermes config    — View/set config values
  hermes update    — Update to latest version

DOCS:
  https://hermes-agent.nousresearch.com/docs
  https://github.com/NousResearch/hermes-agent
READMEEOF
ok "Created: $SCRIPT_DIR/README.txt"

# ── Step 9: Post-install health check ────────────────────────────────────────
step "Running post-install check..."

export PATH="$HOME/.local/bin:$PATH"

if command -v hermes &>/dev/null; then
    ok "hermes version: $(hermes --version 2>&1 || echo 'unknown')"
else
    warn "hermes not yet in PATH for this shell — open new terminal and use launch-linux.sh"
fi

echo -e "${GREEN}
════════════════════════════════════════════════
  BUILD COMPLETE
════════════════════════════════════════════════

  NEXT STEPS:
  1. Edit hermes-portable/data/.env — add your API key
  2. Open a new terminal
  3. cd to USB mount and: ./launch-linux.sh model
  4. ./launch-linux.sh doctor
  5. ./launch-linux.sh

  OPSEC: Encrypt this drive with VeraCrypt before field use.
  Docs  : https://hermes-agent.nousresearch.com/docs
════════════════════════════════════════════════
${NC}"
