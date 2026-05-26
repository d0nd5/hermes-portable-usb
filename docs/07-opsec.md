# 07 - OPSEC and Security

## Threat Model

You are carrying a USB drive that contains:

- LLM API credentials (`.env`)
- Full conversation history including any sensitive context you've shared (`sessions/`)
- Agent memory including personal and operational details (`memory/`)
- Custom skill definitions that may reveal TTPs or workflows (`skills/`)

Anyone who physically obtains the drive and knows what Hermes is can access all of the above immediately. The drive requires no password to mount on any machine.

**Treat this drive with the same care as a hardware token or a laptop.**

---

## Encryption -- VeraCrypt (Required for Event Use)

VeraCrypt creates an encrypted container file on the USB. The container mounts as a virtual drive. All Hermes data lives inside the container.

### Setup

1. Download VeraCrypt: https://www.veracrypt.fr/en/Downloads.html
2. Install on your daily machine (Windows or Linux)
3. Open VeraCrypt > **Create Volume**
4. Select **Create an encrypted file container**
5. Choose **Standard VeraCrypt volume**
6. Save the container file to the USB root: `E:\hermes.vc` (or USB mount path)
7. Choose encryption: **AES** + **SHA-512** (defaults are fine)
8. Set container size: **4 GB minimum**, more if needed for sessions
9. Set a strong passphrase (20+ chars or passphrase of 5+ random words)
10. Format inside VeraCrypt as **exFAT**
11. Mount the container and copy `hermes-portable/` inside it

### Daily Use with VeraCrypt

**Windows:**
```
1. Plug in USB
2. Open VeraCrypt
3. Select a drive letter (e.g. Z:)
4. Click "Select File" > navigate to E:\hermes.vc
5. Click "Mount" > enter passphrase
6. Hermes data is now at Z:\hermes-portable\
7. Update launch-windows.ps1 $DRIVE to use Z:\ when VeraCrypt is mounted
8. When done: VeraCrypt > Dismount
```

**Linux:**
```bash
# Mount
veracrypt /media/$USER/HERMESUSB/hermes.vc /media/hermes-vc

# Use
cd /media/$USER/HERMESUSB
./launch-linux.sh  # launcher resolves HERMES_HOME to vc mount

# Dismount
veracrypt -d /media/$USER/HERMESUSB/hermes.vc
```

### Alternative: Full Drive Encryption

If your OS supports it, encrypt the entire USB:
- **Windows:** BitLocker To Go (right-click drive > Turn on BitLocker)
- **Linux:** LUKS (`cryptsetup luksFormat /dev/sdX`)

BitLocker is simpler on Windows but does not decrypt natively on Linux without third-party tools. VeraCrypt is the cross-platform option.

---

## API Key Hygiene

**Use dedicated event/field keys.**

Do not put primary production API keys on a portable drive. Instead:

1. Create a dedicated API key specifically for the USB / field use
2. Set a hard usage limit (e.g. $20/month on Anthropic, $10 balance on OpenRouter)
3. Label the key clearly in your API provider dashboard: `hermes-usb-field`
4. Rotate after each major event

**OpenRouter** makes this easy -- fund a specific key with a fixed balance. When balance hits zero, the key stops working.

---

## `.env` File Permissions

On Linux, the builder sets `chmod 600` on `data/.env` automatically. Verify:

```bash
ls -la hermes-portable/data/.env
# Should show: -rw------- (600)
```

On Windows, exFAT does not support Unix permissions. The file is readable by anyone who mounts the drive. This reinforces the VeraCrypt requirement for Windows event use.

---

## Session and Memory Data

`data/sessions/` contains SQLite databases with full conversation history.  
`data/memory/` contains structured agent memory.

Before any event, consider:

```bash
# Back up current sessions
cp -r hermes-portable/data/sessions/ ~/hermes-sessions-backup/

# Clear sessions for a clean start
rm -rf hermes-portable/data/sessions/*
rm -rf hermes-portable/data/memory/*
```

Hermes will start with no history at the next launch. This is useful before high-sensitivity ops.

---

## Physical Security

- **Lanyard/clip:** Attach the USB to your badge lanyard or person -- don't leave it on the ops table
- **Label:** Do NOT label the drive "Hermes" or anything descriptive. Plain label or no label
- **Backup:** Keep a second USB with a clean build stored separately. If the primary drive is lost/seized, you don't lose your setup
- **Dead man:** At DEF CON and similar events, assume anything plugged into a shared machine is potentially logged. Use VeraCrypt

---

## Network Security

Hermes makes outbound HTTPS connections to:
- Your LLM provider API endpoint
- `github.com` (only during `hermes update`)
- Web search APIs (if web_search tool is enabled)

It does not make any inbound connections unless the gateway is running (which opens a webhook listener for Telegram/Discord/etc).

**On event networks (DEF CON, etc.):**
- Use a dedicated hotspot, not the event WiFi, for Hermes API calls
- Disable the gateway if you don't need it: `./launch-linux.sh gateway stop`
- Consider a VPN between Hermes and your API provider

---

## Incident Response -- Drive Lost or Stolen

1. **Immediately rotate all API keys** listed in the lost `.env`
2. Revoke the specific keys in your provider dashboards
3. Check provider usage logs for unexpected API calls
4. If VeraCrypt was in use and passphrase is strong, data is protected -- but keys are still at risk
5. Create new keys and update your backup drive

---

## What Hermes Logs

Hermes logs to `hermes-portable/logs/`. These logs may contain:
- Command invocations
- Tool call inputs and outputs
- Error messages referencing file paths or API responses

Review logs before sharing or uploading them anywhere.

```bash
# View recent launcher log
tail -50 hermes-portable/logs/launcher.log

# Clear logs
rm hermes-portable/logs/*.log
```
