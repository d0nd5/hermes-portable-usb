# hermes-usb-portable

**Portable NousResearch Hermes Agent on a USB Drive**  
Cross-platform (Windows + Linux) | exFAT USB | MIT License  
Built by [Bad Systems Syndicate](https://github.com/BadSystemsSyndicate) / Cyber Recon Labs

---

## What This Is

A one-shot build toolkit that installs [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) directly onto a USB drive with all data, config, sessions, and API keys stored on the drive itself — not on the host machine.

Plug in. Run launcher. Pull out. Zero host pollution.

---

## Quick Start

### Windows (exFAT USB, local admin)

```powershell
# Copy hermes-usb-build.ps1 to USB root, then:
powershell -ExecutionPolicy Bypass -File E:\hermes-usb-build.ps1
```

After build:

```powershell
# Edit E:\hermes-portable\data\.env -- add your API key
powershell -ExecutionPolicy Bypass -File E:\launch-windows.ps1 model
powershell -ExecutionPolicy Bypass -File E:\launch-windows.ps1 doctor
powershell -ExecutionPolicy Bypass -File E:\launch-windows.ps1
```

### Linux (exFAT USB, sudo available)

```bash
# Copy hermes-usb-build.sh to USB mount root, then:
chmod +x hermes-usb-build.sh
./hermes-usb-build.sh
```

After build:

```bash
# Edit hermes-portable/data/.env -- add your API key
./launch-linux.sh model
./launch-linux.sh doctor
./launch-linux.sh
```

---

## Repository Contents

```
hermes-usb-portable/
|-- README.md                       -- This file
|-- scripts/
|   |-- hermes-usb-build.ps1        -- Windows one-shot builder
|   |-- hermes-usb-build.sh         -- Linux one-shot builder
|-- docs/
    |-- 01-overview.md              -- Architecture and design decisions
    |-- 02-requirements.md          -- Hardware and software requirements
    |-- 03-windows-install.md       -- Full Windows installation guide
    |-- 04-linux-install.md         -- Full Linux installation guide
    |-- 05-first-run.md             -- First-run configuration
    |-- 06-usage.md                 -- Daily use and Hermes commands
    |-- 07-opsec.md                 -- Security and encryption guidance
    |-- 08-troubleshooting.md       -- Common issues and fixes
    |-- 09-updating.md              -- Keeping Hermes current
    |-- 10-reference.md             -- USB layout, env vars, full command reference
```

---

## Requirements Summary

| Item | Minimum | Recommended |
|------|---------|-------------|
| USB Drive | 8 GB USB 3.0 | 32 GB USB 3.1 / SSD |
| Format | exFAT | exFAT |
| Windows | 10 64-bit | 11 64-bit |
| Linux kernel | 5.x | 6.x |
| RAM (host) | 4 GB | 8 GB+ |
| Internet (build) | Required (~600 MB) | Fast connection |
| Admin rights | Local admin | Local admin |

---

## Security Warning

`hermes-portable/data/.env` stores API keys in plaintext.  
`hermes-portable/data/sessions/` stores full conversation history.

**Encrypt the drive with VeraCrypt before using at any event or on untrusted systems.**  
See [docs/07-opsec.md](docs/07-opsec.md) for full guidance.

---

## Upstream Project

- GitHub: https://github.com/NousResearch/hermes-agent
- Docs: https://hermes-agent.nousresearch.com/docs
- Discord: https://discord.gg/NousResearch
- License: MIT

This repo contains only launcher and build tooling.  
Hermes Agent itself is pulled directly from NousResearch at build time.

---

## License

MIT -- see upstream [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent/blob/main/LICENSE)  
Build scripts in this repo are also MIT.
