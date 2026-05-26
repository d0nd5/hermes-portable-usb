# 09 - Updating Hermes

## How Updates Work

Hermes auto-detects how it was installed (git installer, pip, Homebrew, Nix) and uses the correct update method. Because this USB toolkit uses the git installer path, updates pull the latest commits from `main` and reinstall the package.

All data (`data/sessions/`, `data/memory/`, `data/skills/`, `data/.env`) is preserved during updates.

---

## Standard Update (Recommended)

```bash
# Linux
./launch-linux.sh update

# Windows
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 update
```

This is the official Hermes update command. It detects the install path and runs the appropriate update procedure.

---

## Manual Git Update

If `hermes update` fails or you want to update to a specific commit:

```bash
# Linux
cd hermes-portable/hermes-agent
git pull origin main
source venv/bin/activate
pip install -e .
deactivate

# Verify
./launch-linux.sh doctor
```

```powershell
# Windows
cd E:\hermes-portable\hermes-agent
git pull origin main
.\venv\Scripts\activate
pip install -e .
deactivate

# Verify
powershell -ExecutionPolicy Bypass -File E:\launch-windows.ps1 doctor
```

---

## Checking Current Version

```bash
./launch-linux.sh --version
# or check git log
cd hermes-portable/hermes-agent && git log --oneline -5
```

---

## Config Migration After Update

Major version updates may change config schema. If Hermes behaves strangely after an update:

```bash
./launch-linux.sh config check
./launch-linux.sh config migrate
```

If migration fails, run the setup wizard:

```bash
./launch-linux.sh setup
```

Your `.env` API keys are never touched by migration.

---

## Before Updating at an Event

Do NOT update Hermes the morning of an event. Verify the current version works for your use case, then freeze it until after the event.

Update procedure for pre-event prep:

1. **At home / stable environment:**

```bash
./launch-linux.sh update
./launch-linux.sh doctor
./launch-linux.sh   # verify a working conversation
```

2. Confirm all expected tools and providers still work
3. Lock the version if needed:

```bash
cd hermes-portable/hermes-agent
git log --oneline -1   # note the commit hash
# If the post-event update breaks something:
git checkout <previous-hash>
pip install -e .
```

---

## Updating the Builder Scripts

The builder scripts (`hermes-usb-build.ps1` / `hermes-usb-build.sh`) are separate from Hermes itself. Check this repository for updates to the build scripts.

Builder scripts do not need to re-run after initial setup unless:
- You are setting up a new USB from scratch
- Significant changes to HERMES_HOME handling require rebuilding the virtualenv

---

## Rollback

If an update breaks your setup:

```bash
cd hermes-portable/hermes-agent

# See recent commits
git log --oneline -20

# Roll back to a specific commit
git checkout <commit-hash>
source venv/bin/activate
pip install -e .
deactivate

# Verify
./launch-linux.sh doctor
```

---

## Keeping the Launcher Scripts Current

The launchers (`launch-linux.sh`, `launch-windows.ps1`) at the USB root are static -- they set env vars and call `hermes`. They do not need updating unless Hermes changes where it installs its binary.

If Hermes moves its venv location in a future version, update the path resolution block in the launcher:

```bash
# launch-linux.sh -- path resolution block
for venv in \
    "$HERMES_HOME/hermes-agent/venv/bin" \
    "$HERMES_HOME/venv/bin" \
    "$HOME/.local/bin"; do
    [ -d "$venv" ] && export PATH="$venv:$PATH"
done
```

Add any new candidate paths here if needed.
