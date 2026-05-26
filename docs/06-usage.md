# 06 - Usage Guide

## Launching Hermes

### Windows

```powershell
cd E:\
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1
```

With arguments:

```powershell
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 chat
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 model
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 doctor
```

### Linux

```bash
cd /media/$USER/HERMESUSB
./launch-linux.sh
./launch-linux.sh model
./launch-linux.sh doctor
```

---

## Core Commands

| Command | Description |
|---------|-------------|
| `hermes` | Open interactive TUI chat |
| `hermes chat` | Alias for interactive chat |
| `hermes model` | Switch or reconfigure LLM provider/model |
| `hermes setup` | Run full setup wizard |
| `hermes doctor` | Diagnose install and config issues |
| `hermes tools` | Enable/disable available tools |
| `hermes gateway` | Messaging platform management |
| `hermes gateway setup` | Configure Telegram/Discord/Slack/etc |
| `hermes gateway start` | Start gateway in background |
| `hermes gateway stop` | Stop gateway |
| `hermes config` | View current configuration |
| `hermes config set KEY value` | Set a config value |
| `hermes config check` | Validate config |
| `hermes update` | Update Hermes to latest version |
| `hermes skills` | List available skills |

All commands work via the launcher:

```bash
./launch-linux.sh <command>
# or
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 <command>
```

---

## Interactive TUI

When you run `hermes` with no arguments, the full TUI opens:

- **Multiline input** -- Shift+Enter for newline, Enter to send
- **Slash commands** -- type `/` to see autocomplete options
- **Interrupt** -- Ctrl+C to interrupt a running response
- **History** -- Up/Down arrows for previous messages
- **Stream output** -- tool calls and responses stream in real time

### Useful Slash Commands in TUI

| Command | Action |
|---------|--------|
| `/clear` | Clear current conversation |
| `/sessions` | List past sessions |
| `/search <query>` | Search past conversation history |
| `/skills` | List loaded skills |
| `/model` | Switch model mid-session |
| `/tools` | Show active tools |
| `/exit` | Exit Hermes |

---

## Memory and Sessions

Hermes maintains two types of persistence:

**Sessions** (`data/sessions/`) -- Full conversation logs, searchable via FTS5.

```bash
# Search past sessions from inside TUI
/search "DEF CON Singapore"

# Or from CLI
./launch-linux.sh search "threat hunt"
```

**Memory** (`data/memory/`) -- Agent-curated long-term facts. Hermes periodically summarizes sessions into structured memories. You can nudge it:

```
> Please remember that I'm operating as part of the Bad Systems Syndicate NOC team
> Remember my OpenRouter key is for the CRL account
```

---

## Running the Gateway (Bot Mode)

The gateway runs Hermes as a persistent background process that receives messages from Telegram, Discord, Slack, etc.

```bash
# Start gateway (runs in background)
./launch-linux.sh gateway start

# Check status
./launch-linux.sh gateway status

# Stop gateway
./launch-linux.sh gateway stop

# View gateway logs
tail -f hermes-portable/logs/gateway.log
```

**Field use pattern:** Start the gateway on a machine at your ops table. Send tasks to Hermes from your phone via Telegram while you're on the floor.

---

## Switching Models Mid-Session

You can switch the underlying LLM without restarting:

```bash
./launch-linux.sh model
```

Or from inside the TUI: `/model`

**Common model switches:**

| Use Case | Recommended Model |
|----------|-----------------|
| General chat / tasks | `anthropic/claude-sonnet-4-5` (via OpenRouter) |
| Fast/cheap tasks | `anthropic/claude-haiku-4-5` |
| Heavy reasoning | `anthropic/claude-opus-4-5` |
| Local / air-gap | `llama3` or `qwen2.5` via Ollama |
| Coding | `deepseek-coder` or `claude-sonnet-4-5` |

---

## Skills

Hermes can create, save, and reuse skills -- reusable automated workflows.

```bash
# List available skills
./launch-linux.sh skills

# Skills live in data/skills/ -- portable with the USB
ls hermes-portable/data/skills/
```

Skills created during a session on Machine A are available when you plug into Machine B -- they're on the drive.

Community skills: https://agentskills.io

---

## MCP Server Integration

Hermes supports MCP (Model Context Protocol) servers for external tool integration.

```bash
# Add an MCP server
./launch-linux.sh config set mcp.servers.myserver.url "http://localhost:3000"

# Or edit config directly
./launch-linux.sh config
```

---

## Cron / Scheduled Tasks

Hermes includes a built-in cron scheduler for recurring tasks:

```bash
# View scheduled jobs
./launch-linux.sh jobs list

# Add a job (example: daily briefing at 0800)
./launch-linux.sh jobs add --cron "0 8 * * *" "Give me a morning briefing on threat intel news"
```

---

## Running Multiple Instances

You can run two instances with different `HERMES_HOME` paths (e.g. one for personal, one for ops). The launcher sets `HERMES_HOME` to the USB path, so any local Hermes install with a different `HERMES_HOME` runs independently.

---

## Proxy Support

If running behind a corporate proxy or event NOC:

```bash
# Add to data/.env
HTTP_PROXY=http://proxy.example.com:8080
HTTPS_PROXY=http://proxy.example.com:8080
NO_PROXY=localhost,127.0.0.1
```
