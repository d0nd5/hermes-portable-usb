# 04 - Linux Installation Guide

## Prerequisites Checklist

- [ ] USB drive plugged in and mounted (check: `lsblk` or `df -h`)
- [ ] USB formatted as exFAT
- [ ] `curl` installed (`curl --version`)
- [ ] `bash` 4.0+ (`bash --version`)
- [ ] Internet connection (~600 MB download)
- [ ] `sudo` available (for optional browser deps)
- [ ] At least one LLM API key ready (or Ollama running locally)

---

## Step 1 -- Mount the USB

Most desktop Linux environments automount USB drives. If not:

```bash
# Check what device your USB appeared as
lsblk

# Install exFAT support if needed
sudo apt install exfatprogs          # Debian / Ubuntu / Kali
sudo pacman -S exfatprogs            # Arch / Manjaro
sudo dnf install exfatprogs          # Fedora / RHEL

# Manual mount (replace sdX1 with your device)
sudo mkdir -p /media/$USER/HERMESUSB
sudo mount -t exfat /dev/sdX1 /media/$USER/HERMESUSB

# Confirm mount
df -h | grep HERMES
```

**Tip for Kali / DEF CON ops:** If the USB was previously used on Windows, Linux may mount it read-only due to a dirty bit. Fix:

```bash
sudo fsck.exfat /dev/sdX1     # clear dirty bit
sudo mount -t exfat /dev/sdX1 /media/$USER/HERMESUSB
```

---

## Step 2 -- Copy the Builder Script

Copy `scripts/hermes-usb-build.sh` from this repo to the root of the USB mount.

```bash
# Example
cp hermes-usb-build.sh /media/$USER/HERMESUSB/
```

---

## Step 3 -- Run the Builder

```bash
cd /media/$USER/HERMESUSB    # adjust to your actual mount point
chmod +x hermes-usb-build.sh
./hermes-usb-build.sh
```

**What happens next (automated):**

1. Banner and confirmation prompt
2. Directory structure created under `./hermes-portable/`
3. Prerequisites checked (curl, bash, git)
4. `HERMES_HOME` and `HERMES_DATA` exported pointing at the USB
5. Official NousResearch installer pulled and executed:
   - Downloads `uv` (Python package manager)
   - Downloads Python 3.11 via uv
   - Downloads Node.js 22
   - Downloads ripgrep and ffmpeg
   - Clones hermes-agent repo into `$HERMES_HOME`
   - Creates Python virtualenv
   - Adds `hermes` to `~/.local/bin` and sources shell profile
6. `data/.env` scaffold written (chmod 600)
7. `launch-linux.sh` written to USB root (executable)
8. `launch-windows.ps1` written to USB root (for cross-platform use)
9. `README.txt` written to USB root
10. Post-install health check (`hermes --version`)

**Expected duration:** 5-20 minutes depending on internet speed and USB write speed.

**Note on sudo:** The installer uses sudo for Playwright (browser automation) system dependencies. If you want to skip browser support entirely:

```bash
# The official installer supports --skip-browser
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-browser
```

The builder script calls the standard installer. If you want `--skip-browser`, edit `hermes-usb-build.sh` before running it (line near the `curl | bash` call).

---

## Step 4 -- Verify the Build

After the builder completes:

```
/media/$USER/HERMESUSB/
|-- hermes-usb-build.sh
|-- launch-linux.sh
|-- launch-windows.ps1
|-- README.txt
|-- hermes-portable/
    |-- hermes-agent/
    |-- data/
    |   |-- .env              (chmod 600)
    |   |-- sessions/
    |   |-- memory/
    |   `-- skills/
    `-- logs/
```

Run the doctor:

```bash
./launch-linux.sh doctor
```

Expected: green checks for Python, Node.js, Git, ripgrep.

---

## Step 5 -- Configure Your LLM Provider

Edit the `.env` file:

```bash
nano /media/$USER/HERMESUSB/hermes-portable/data/.env
# or
vim /media/$USER/HERMESUSB/hermes-portable/data/.env
```

Uncomment and fill in your provider. Example:

```bash
# OpenRouter (recommended for ops)
OPENROUTER_API_KEY=sk-or-v1-your-key-here

# Or Anthropic
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

Then run the interactive model selector:

```bash
./launch-linux.sh model
```

---

## Step 6 -- First Chat

```bash
./launch-linux.sh
```

The Hermes TUI will open. Verify you get a response.

---

## Daily Use (After Initial Build)

On any subsequent Linux machine:

```bash
# Find mount point
lsblk
cd /media/$USER/HERMESUSB    # adjust as needed
./launch-linux.sh
```

---

## Persistent Mount Point (Optional)

If you use the same machine regularly, add a udev rule for a consistent mount point:

```bash
# Get USB identifiers
udevadm info --query=all --name=/dev/sdX | grep -E "ID_SERIAL|ID_FS_LABEL"

# Create udev rule
sudo nano /etc/udev/rules.d/99-hermes-usb.rules
# Add:
# SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="HERMESUSB", ACTION=="add", \
#   RUN+="/bin/mkdir -p /media/hermes", \
#   RUN+="/bin/mount -t exfat %N /media/hermes"
```

Then your launcher path is always `/media/hermes/launch-linux.sh`.

---

## Kali Linux Specific Notes

Kali is fully supported (Debian base). A few field notes:

- If running on patchdeep or similar dual-NIC setups, ensure the USB mount does not conflict with NFS or network shares
- If `/tmp` is tmpfs and small, uv may fail to extract during install -- set `TMPDIR=/media/$USER/HERMESUSB/tmp` before running the builder
- Hermes gateway (Telegram bot) works natively on Kali -- useful for remote agent control during THV/WoS ops

```bash
# Set TMPDIR if /tmp is small
export TMPDIR=/media/$USER/HERMESUSB/tmp
mkdir -p $TMPDIR
./hermes-usb-build.sh
```

---

## Uninstalling / Cleaning Up

The build leaves one trace on the Linux host:

- `~/.local/bin/hermes` symlink (created by official installer)

To clean up:

```bash
rm -f ~/.local/bin/hermes
# Remove HERMES_HOME/HERMES_DATA from ~/.bashrc or ~/.zshrc if they were added
```

USB: `rm -rf /media/$USER/HERMESUSB/hermes-portable/` or format the drive.
