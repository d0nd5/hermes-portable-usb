# 03 - Windows Installation Guide

## Prerequisites Checklist

Before running the builder:

- [ ] USB drive plugged in and showing as drive letter (e.g. `E:\`)
- [ ] USB formatted as exFAT (check: right-click drive in Explorer > Properties > File System)
- [ ] PowerShell 5.1+ available (check: `$PSVersionTable.PSVersion` in any PowerShell window)
- [ ] Internet connection (~600 MB download)
- [ ] Local admin account (or Run As Administrator)
- [ ] At least one LLM API key ready (or Ollama running locally)

---

## Step 1 -- Format the USB (if needed)

If the USB is FAT32 or NTFS and you want a fresh start:

1. Open File Explorer
2. Right-click the USB drive > **Format**
3. File system: **exFAT**
4. Allocation unit size: **Default**
5. Quick Format: **checked**
6. Click **Start**

> Warning: This erases all existing data on the drive.

---

## Step 2 -- Copy the Builder Script

Copy `scripts/hermes-usb-build.ps1` from this repo to the **root** of the USB drive.

Example: `E:\hermes-usb-build.ps1`

---

## Step 3 -- Run the Builder

Open PowerShell. Navigate to the USB root and run:

```powershell
cd E:\
powershell -ExecutionPolicy Bypass -File .\hermes-usb-build.ps1
```

Or right-click the file in Explorer and choose **Run with PowerShell** (may require confirming the execution policy prompt).

**What happens next (automated):**

1. Banner and confirmation prompt
2. Directory structure created under `E:\hermes-portable\`
3. Prerequisites checked (PowerShell version, internet, Git)
4. `HERMES_HOME=E:\hermes-portable` set for current session and User environment
5. Official NousResearch installer pulled and executed
   - Downloads `uv` (Python package manager)
   - Downloads Python 3.11 via uv
   - Downloads Node.js 22
   - Downloads PortableGit (if no system Git found, ~50 MB)
   - Downloads ripgrep and ffmpeg
   - Clones hermes-agent repo into `HERMES_HOME`
   - Creates Python virtualenv
   - Adds `hermes` to User PATH
6. `data\.env` scaffold written
7. `launch-windows.ps1` written to USB root
8. `launch-linux.sh` written to USB root (LF line endings)
9. `README.txt` written to USB root
10. Post-install health check (`hermes --version`)

**Expected duration:** 5-20 minutes depending on internet speed and USB write speed.

---

## Step 4 -- Verify the Build

After the builder completes, check the USB root looks like this:

```
E:\
|-- hermes-usb-build.ps1       (the builder you ran)
|-- launch-windows.ps1         (daily launcher -- Windows)
|-- launch-linux.sh            (daily launcher -- Linux)
|-- README.txt                 (quick reference)
|-- hermes-portable\
    |-- hermes-agent\          (full Hermes source + venv)
    |-- data\
    |   |-- .env               (API key config -- empty scaffold)
    |   |-- sessions\
    |   |-- memory\
    |   `-- skills\
    `-- logs\
```

Run a quick verification:

```powershell
# Open a NEW PowerShell window (to pick up PATH changes), then:
cd E:\
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 doctor
```

Expected output: green checks for Python, Node.js, Git, ripgrep.

---

## Step 5 -- Configure Your LLM Provider

Edit the `.env` file to add your API key:

```powershell
notepad E:\hermes-portable\data\.env
```

Uncomment and fill in your chosen provider. Example for OpenRouter:

```
OPENROUTER_API_KEY=sk-or-v1-your-key-here
```

Example for Anthropic:

```
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

Save and close Notepad.

Then run the model selector:

```powershell
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 model
```

Follow the interactive prompts to select provider and model.

---

## Step 6 -- First Chat

```powershell
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1
```

The Hermes TUI will open. Type a message and verify you get a response.

---

## Daily Use (After Initial Build)

On any subsequent Windows machine:

1. Plug in USB
2. Open PowerShell
3. `cd E:\` (adjust drive letter)
4. `powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1`

No installation. No configuration. Everything is on the drive.

---

## Rebuilding on a New Machine

The builder does not need to run again on each new machine. The launcher handles PATH and environment on every invocation.

The builder only needs to re-run if:
- You want to update Hermes to a new version (use `hermes update` instead -- see [09-updating.md](09-updating.md))
- The virtualenv gets corrupted
- You are setting up a brand new USB from scratch

---

## Windows-Specific Feature Notes

| Feature | Status | Notes |
|---------|--------|-------|
| CLI (`hermes`, `hermes chat`) | Native | Full support |
| Gateway (Telegram, Discord, Slack) | Native | Runs as background PowerShell process |
| Cron scheduler | Native | Supported |
| Browser tool (Chromium) | Native | Via Node.js |
| MCP servers | Native | stdio and HTTP both supported |
| Dashboard web UI | Native (partial) | All tabs except embedded terminal pane |
| Dashboard chat terminal pane | WSL2 only | Requires POSIX PTY -- not available natively |

---

## Uninstalling / Cleaning Up

The build leaves two traces on the host beyond the USB:

1. **User PATH entry** -- `%LOCALAPPDATA%\hermes\...` added during install
2. **User environment variables** -- `HERMES_HOME` and `HERMES_DATA`

To clean these up on a host machine:

```powershell
# Remove env vars
[System.Environment]::SetEnvironmentVariable("HERMES_HOME", $null, "User")
[System.Environment]::SetEnvironmentVariable("HERMES_DATA", $null, "User")

# Remove from PATH (System > Advanced System Settings > Environment Variables > User PATH)
# Remove any entry containing "hermes"
```

The USB itself: just delete the `hermes-portable\` folder or format the drive.
