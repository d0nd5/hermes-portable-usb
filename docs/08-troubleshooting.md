# 08 - Troubleshooting

## Diagnostic First Step

Always run `hermes doctor` first:

```bash
./launch-linux.sh doctor
# or
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 doctor
```

This checks Python, Node.js, Git, ripgrep, config validity, and provider connection.

---

## Windows Issues

### "hermes-usb-build.ps1 cannot be loaded because running scripts is disabled"

```powershell
# Run with explicit bypass
powershell -ExecutionPolicy Bypass -File .\hermes-usb-build.ps1

# Or set for current user permanently
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### "The term 'hermes' is not recognized"

The PATH change from the installer requires a new shell:

```powershell
# Close current PowerShell window
# Open a new PowerShell window
# Use the launcher (it sets PATH explicitly)
powershell -ExecutionPolicy Bypass -File E:\launch-windows.ps1
```

### Installer fails with "Git not found" and PortableGit download fails

```powershell
# Check internet access
Test-NetConnection raw.githubusercontent.com -Port 443

# If behind proxy, set proxy env vars
$env:HTTP_PROXY = "http://proxy:port"
$env:HTTPS_PROXY = "http://proxy:port"

# Re-run builder
powershell -ExecutionPolicy Bypass -File E:\hermes-usb-build.ps1
```

### hermes.exe found but crashes immediately on launch

```powershell
# Run with verbose output
$env:HERMES_HOME = "E:\hermes-portable"
$env:HERMES_DATA = "E:\hermes-portable\data"
$env:PATH = "E:\hermes-portable\hermes-agent\venv\Scripts;$env:PATH"
hermes doctor
```

If `ModuleNotFoundError: No module named 'dotenv'` appears, the wrong Python is being used:

```powershell
# Use the venv Python directly
& "E:\hermes-portable\hermes-agent\venv\Scripts\hermes.exe" doctor
```

### Write errors / "Access Denied" on USB

exFAT write protection or dirty bit:

```powershell
# Run as administrator
# Right-click PowerShell > Run as Administrator
chkdsk E: /f
```

Or in Disk Management: right-click USB > Properties > uncheck "Read-only".

### "HERMES_HOME does not appear to be set correctly"

The launcher is not being called with the correct drive letter. Check:

```powershell
# Verify current drive letter in Disk Management or File Explorer
# Update and re-run:
cd E:\   # replace E with actual letter
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1
```

### Dashboard chat terminal pane not working

This is by design on native Windows. The embedded PTY terminal in the web dashboard requires WSL2. All other dashboard features work natively. Install WSL2 if the terminal pane is needed:

```powershell
wsl --install
# Restart, then run the Linux launcher inside WSL2
```

---

## Linux Issues

### USB not mounting / "unknown filesystem type 'exfat'"

```bash
# Install exFAT support
sudo apt install exfatprogs          # Debian/Ubuntu/Kali
sudo pacman -S exfatprogs            # Arch
sudo dnf install exfatprogs          # Fedora

# Manual mount
sudo mount -t exfat /dev/sdX1 /media/$USER/HERMESUSB
```

### USB mounts read-only

Dirty bit from improper Windows ejection:

```bash
sudo fsck.exfat /dev/sdX1
# Then remount
sudo umount /media/$USER/HERMESUSB
sudo mount -t exfat /dev/sdX1 /media/$USER/HERMESUSB
```

### "curl: command not found"

```bash
sudo apt install curl    # Debian/Ubuntu/Kali
sudo pacman -S curl      # Arch
sudo dnf install curl    # Fedora
```

### Installer fails with "No space left on device" in /tmp

```bash
export TMPDIR=/media/$USER/HERMESUSB/tmp
mkdir -p $TMPDIR
./hermes-usb-build.sh
```

### "hermes: command not found" after build

```bash
# Source shell profile
source ~/.bashrc
# or
source ~/.zshrc

# Or use the launcher directly (sets PATH explicitly)
./launch-linux.sh
```

### Playwright / browser install fails

If you don't need browser features:

```bash
# Re-run official installer with skip-browser
export HERMES_HOME="/media/$USER/HERMESUSB/hermes-portable"
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-browser
```

### "Permission denied" running launch-linux.sh

```bash
chmod +x launch-linux.sh
./launch-linux.sh
```

### ModuleNotFoundError after updating

The virtualenv may need rebuilding:

```bash
cd hermes-portable/hermes-agent
source venv/bin/activate
pip install -e .
```

Or do a clean update via the official method:

```bash
./launch-linux.sh update
```

---

## Provider / API Issues

### "API key not set" despite key in .env

Verify the launcher is setting `HERMES_DATA` correctly:

```bash
# Check HERMES_DATA is pointing to the USB
./launch-linux.sh config | grep DATA

# Manually verify .env is being read
cat hermes-portable/data/.env | grep -v "^#" | grep -v "^$"
```

### "Connection refused" or timeout to API

```bash
# Test provider connectivity
curl -s https://api.anthropic.com/v1/models \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01"

# For OpenRouter
curl https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer $OPENROUTER_API_KEY"
```

### Provider returns 401 Unauthorized

Key is invalid or expired. Generate a new key at your provider dashboard and update `.env`.

### Provider returns 429 Too Many Requests / Rate Limited

You've hit rate limits. Either:
- Wait and retry
- Switch to a different model: `./launch-linux.sh model`
- Use OpenRouter for automatic fallback across providers

---

## Hermes doctor Output Reference

| Output | Meaning | Fix |
|--------|---------|-----|
| `[OK] Python 3.11.x` | Python installed correctly | None |
| `[WARN] Python 3.10.x` | Older Python | Reinstall via `uv python install 3.11` |
| `[FAIL] hermes config invalid` | Missing or corrupt config | Run `hermes setup` |
| `[FAIL] LLM provider not configured` | No API key set | Edit `.env`, run `hermes model` |
| `[WARN] ripgrep not found` | File search disabled | `hermes postinstall` |
| `[WARN] ffmpeg not found` | Audio/TTS disabled | `hermes postinstall` |
| `[FAIL] HERMES_HOME not set` | Launcher not used | Use `launch-linux.sh` or `launch-windows.ps1` |

---

## Getting More Help

- Official docs: https://hermes-agent.nousresearch.com/docs
- GitHub issues: https://github.com/NousResearch/hermes-agent/issues
- Discord: https://discord.gg/NousResearch

When filing an issue, include the output of `hermes doctor` and your OS/version. Do not include API keys or session content.
