# 01 - Overview and Architecture

## What Is Hermes Agent?

[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) is an autonomous AI agent framework built by Nous Research. Current version: **v0.14.x (May 2026)**. MIT License.

It is not a chatbot wrapper. Key capabilities:

- **Persistent memory** across sessions (FTS5 search + LLM summarization)
- **Skill creation** -- agent builds and improves its own tools from experience
- **Messaging gateways** -- Telegram, Discord, Slack, WhatsApp, Signal, CLI
- **Tool use** -- web search, file access, code execution, browser automation
- **Multi-provider** -- Anthropic Claude, OpenRouter, DeepSeek, Ollama, and 20+ others
- **MCP support** -- Model Context Protocol stdio and HTTP transports

---

## What This Toolkit Does

The standard Hermes installer places everything in `~/.hermes/` (Linux/macOS) or `%LOCALAPPDATA%\hermes\` (Windows). Those paths are tied to the host machine. Move to a different machine and you start over.

This toolkit overrides `HERMES_HOME` to point at the USB drive **before** the official installer runs. Result: every file Hermes needs -- runtimes, virtualenv, config, keys, sessions, memory -- lives inside a single portable folder on the drive.

```
Host machine provides:  CPU, RAM, OS, internet
USB drive provides:     Everything Hermes needs to run
```

No registry entries. No host-side `~/.hermes`. No cleanup required after use.

---

## Directory Layout (Post-Build)

```
E:\  (or /media/user/HERMESUSB/)
|
|-- hermes-usb-build.ps1        <- Builder (Windows, run once)
|-- hermes-usb-build.sh         <- Builder (Linux, run once)
|-- launch-windows.ps1          <- Daily launcher (Windows)
|-- launch-linux.sh             <- Daily launcher (Linux)
|-- README.txt                  <- Quick reference
|
|-- hermes-portable/
    |-- hermes-agent/           <- Git clone of NousResearch/hermes-agent
    |   |-- venv/               <- Python virtualenv (all deps here)
    |   |-- scripts/            <- Official install/update scripts
    |   `-- ...                 <- Full Hermes source
    |
    |-- git/                    <- PortableGit (Windows only, if no system Git)
    |
    |-- data/
    |   |-- .env                <- API keys and config (KEEP ENCRYPTED)
    |   |-- sessions/           <- Conversation history (KEEP ENCRYPTED)
    |   |-- memory/             <- Agent memory store
    |   `-- skills/             <- Custom skill definitions
    |
    `-- logs/                   <- Launcher and install logs
```

---

## How HERMES_HOME Works

Hermes respects the `HERMES_HOME` environment variable to override its data directory. The launchers set this to the USB path on every invocation:

```powershell
# launch-windows.ps1 sets this before calling hermes
$env:HERMES_HOME = "$DRIVE\hermes-portable"
$env:HERMES_DATA = "$DRIVE\hermes-portable\data"
```

```bash
# launch-linux.sh sets this before calling hermes
export HERMES_HOME="$SCRIPT_DIR/hermes-portable"
export HERMES_DATA="$HERMES_HOME/data"
```

This means you can safely run the launchers on machines that also have a local Hermes install -- the two installations do not conflict.

---

## Design Decisions

| Decision | Reason |
|----------|--------|
| exFAT format | Read/write on Windows, Linux, and macOS without drivers |
| Official installer (not vendored binaries) | Stays current; no supply-chain risk from third-party wrappers |
| HERMES_HOME override | Cleanest isolation; no host pollution |
| ASCII-only launcher scripts | Eliminates encoding corruption across different Windows code pages |
| `.env` scaffold with no keys pre-filled | Forces intentional credential configuration |
| VeraCrypt recommended | Cross-platform encryption for field/event use |

---

## What This Toolkit Does NOT Do

- Does not vendor or redistribute Hermes Agent binaries
- Does not modify the host system beyond the current user's PATH (and only during install)
- Does not store credentials anywhere except `data/.env` on the USB
- Does not auto-configure a provider -- you choose your own API key/provider
