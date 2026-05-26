# 01 - Overview and Architecture

## What Is Hermes Agent?

[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) is an autonomous AI agent framework built by Nous Research. Current version: **v0.14.x (May 2026)**. MIT License.

Key capabilities:
- Persistent memory across sessions (FTS5 search + LLM summarization)
- Skill creation -- agent builds and improves its own tools from experience
- Messaging gateways -- Telegram, Discord, Slack, WhatsApp, Signal, CLI
- Tool use -- web search, file access, code execution, browser automation
- Multi-provider -- Anthropic Claude, OpenRouter, DeepSeek, Ollama, and 20+ others
- MCP support -- Model Context Protocol stdio and HTTP transports

---

## The exFAT Symlink Problem

The standard Hermes installer creates a Python virtualenv using `uv`. On Linux and
Windows, `uv` creates symlinks inside the venv (e.g. `venv/bin/python -> /path/to/python3.11`).

exFAT -- the only filesystem that is natively read/write on Windows, Linux, AND macOS --
does not support symlinks. Attempting to install directly onto the USB produces:

```
error: Failed to create virtual environment
  Caused by: failed to symlink file from .../venv/bin/python to ...: Operation not permitted (os error 1)
```

---

## Architecture: Split Install

The solution is to split the install into two locations:

```
HOST MACHINE (native FS -- ext4 / NTFS)
  ~/.hermes-usb/           (Linux)
  %LOCALAPPDATA%\hermes-usb\  (Windows)
  |-- hermes-agent/        <- git clone + Python venv (symlinks work here)
  |-- git/                 <- PortableGit (Windows only)
  `-- data/                <- JUNCTION/SYMLINK pointing to USB data dir

USB DRIVE (exFAT -- no symlinks)
  hermes-portable/
  `-- data/                <- The real data dir (flat files only)
      |-- .env             <- API keys
      |-- sessions/        <- Conversation history (SQLite)
      |-- memory/          <- Agent memory
      `-- skills/          <- Custom skills
```

The launcher runs on every invocation and:
1. Sets `HERMES_HOME` to the host runtime directory
2. Sets `HERMES_DATA` to the USB data directory
3. Re-creates the symlink/junction if it has drifted (USB replugged, path changed)
4. Calls `hermes`

**Result:** Hermes sees a unified home directory. Runtimes run from fast native FS.
All persistent data (keys, sessions, memory) lives on the USB and travels with it.

---

## What This Means in Practice

| Item | Where it lives | Travels with USB? |
|------|---------------|-------------------|
| Python 3.11 venv | Host machine | No -- reinstall per machine |
| Node.js 22 | Host machine | No -- reinstall per machine |
| PortableGit (Windows) | Host machine | No -- reinstall per machine |
| API keys (.env) | USB | YES |
| Conversation history | USB | YES |
| Agent memory | USB | YES |
| Custom skills | USB | YES |
| Hermes config | USB (via data link) | YES |

**On a new machine:** run the builder once (~600MB, ~10 min). Your sessions, keys, and
memory are already there from the USB. Pick up exactly where you left off.

---

## Directory Layout (Post-Build)

```
USB_ROOT/
|-- hermes-usb-build.ps1           Windows builder (run once per new machine)
|-- hermes-usb-build.sh            Linux builder (run once per new machine)
|-- launch-windows.ps1             Daily Windows launcher
|-- launch-linux.sh                Daily Linux launcher
|-- BOOTSTRAP-NEW-MACHINE.txt      Quick new-machine instructions
|-- README.txt                     Quick reference
|
`-- hermes-portable/
    |-- data/
    |   |-- .env                   API keys (ENCRYPT THE DRIVE)
    |   |-- sessions/              Conversation history (SQLite)
    |   |-- memory/                Agent long-term memory
    |   `-- skills/                Custom skill definitions
    `-- logs/                      Launcher logs

HOST (Linux: ~/.hermes-usb/ | Windows: %LOCALAPPDATA%\hermes-usb\)
|-- hermes-agent/                  Git clone + Python venv
|-- git/                           PortableGit (Windows only)
`-- data -> <USB>/hermes-portable/data   (symlink / junction)
```

---

## Design Decisions

| Decision | Reason |
|----------|--------|
| exFAT format | Native R/W on Windows, Linux, macOS without drivers |
| Runtimes on host, data on USB | exFAT has no symlink support; venv requires them |
| Symlink/junction auto-repair in launcher | USB path changes on every machine; launcher heals it |
| Official installer (not vendored binaries) | Stays current; no supply-chain risk |
| ASCII-only scripts | Eliminates encoding corruption across Windows code pages |
| .env scaffold with no keys pre-filled | Forces intentional credential configuration |
| VeraCrypt recommended | Cross-platform encryption for field/event use |
