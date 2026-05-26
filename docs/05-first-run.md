# 05 - First Run and Provider Configuration

## The .env File

All credentials and configuration live in `hermes-portable/data/.env`. The builder creates a scaffold with commented examples. You must edit this file before Hermes can connect to an LLM.

**Windows:**
```powershell
notepad E:\hermes-portable\data\.env
```

**Linux:**
```bash
nano /media/$USER/HERMESUSB/hermes-portable/data/.env
# File is chmod 600 -- only readable by your user
```

---

## Choosing a Provider

### Option A -- OpenRouter (Recommended for Ops)

Best for: field use, event ops, multi-model fallback, not locked in to one vendor.

1. Create account at https://openrouter.ai
2. Add a small prepaid balance (e.g. $10-20 for event use)
3. Generate an API key
4. Add to `.env`:

```
OPENROUTER_API_KEY=sk-or-v1-your-key-here
```

5. Run: `./launch-linux.sh model` (or `launch-windows.ps1 model`)
6. Select **OpenRouter** and choose a default model (e.g. `anthropic/claude-sonnet-4-5`)

**Why OpenRouter for events:** One key covers 200+ models. If one provider has an outage, switch model with `hermes model` -- no key change required.

---

### Option B -- Anthropic API Key

Best for: Claude-native workflows, CRL OSINT reporting, full Claude toolset.

1. Get API key from https://console.anthropic.com
2. Add to `.env`:

```
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

3. Run: `./launch-linux.sh model`
4. Select **Anthropic** and choose model (e.g. `claude-sonnet-4-6`)

**Field OPSEC note:** Use a dedicated low-balance API key for the USB. Do not put your primary production API key on a portable drive.

---

### Option C -- DeepSeek

Best for: cost-effective reasoning tasks, coding assistance.

```
DEEPSEEK_API_KEY=sk-your-key-here
```

---

### Option D -- Local Ollama (Air-Gap / No Internet)

Best for: air-gapped networks, private data, no API costs.

1. Install Ollama on the host machine: https://ollama.ai
2. Pull a model: `ollama pull llama3` or `ollama pull qwen2.5`
3. Add to `.env`:

```
HERMES_ENDPOINT=http://localhost:11434/v1
HERMES_MODEL=llama3
```

4. Run: `./launch-linux.sh model`
5. Select **Custom endpoint**

**Note:** Ollama must be running on the host machine. The USB provides Hermes; the host provides the model.

---

## Interactive Model Selector

After editing `.env`, run the model selector:

```bash
./launch-linux.sh model
# or Windows:
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 model
```

This opens an interactive prompt to:
- Select provider
- Authenticate (OAuth login or API key entry)
- Choose default model
- Set context window size

---

## Running hermes doctor

Always run after first setup and after any update:

```bash
./launch-linux.sh doctor
```

Expected healthy output:

```
[OK] Python 3.11.x
[OK] Node.js 22.x
[OK] Git x.x.x
[OK] ripgrep x.x.x
[OK] hermes config valid
[OK] LLM provider: openrouter (claude-sonnet-4-5)
[OK] HERMES_HOME: /media/user/HERMESUSB/hermes-portable
```

Common issues and fixes are in [08-troubleshooting.md](08-troubleshooting.md).

---

## Initial Configuration Wizard

For a full guided setup (provider + tools + gateway):

```bash
./launch-linux.sh setup
```

This runs the official Hermes setup wizard covering:
- LLM provider selection
- Tool enablement (web search, file access, browser, code execution)
- Messaging gateway setup (optional)
- Memory and skill configuration

---

## Configuring Tools

After provider setup, configure which tools Hermes can use:

```bash
./launch-linux.sh tools
```

Recommended tool set for general use:

| Tool | Enable? | Notes |
|------|---------|-------|
| web_search | Yes | Requires internet |
| file_access | Yes | Scoped to HERMES_HOME by default |
| code_execute | Yes | Sandboxed Python execution |
| browser | Optional | Requires Node.js + Chromium (~300 MB) |
| computer_use | Optional | Screen control -- use only on trusted hosts |

---

## Setting Up a Messaging Gateway (Optional)

Hermes can receive and send messages via Telegram, Discord, Slack, WhatsApp, or Signal.

```bash
./launch-linux.sh gateway setup
```

**Telegram setup (most common for ops):**

1. Message @BotFather on Telegram: `/newbot`
2. Copy the bot token
3. Add to `.env`: `TELEGRAM_BOT_TOKEN=your-token`
4. Get your Telegram user ID via @userinfobot
5. Run gateway setup and follow prompts

Once configured, you can send tasks to Hermes from your phone while it runs on the USB-connected machine.

---

## First Chat

```bash
./launch-linux.sh
```

Hermes opens in TUI mode. Try:

```
> What tools do you have available?
> Search the web for the latest NousResearch news
> Remember that I'm running this from a USB drive at a security conference
```

Verify Hermes responds, uses tools, and that session history is being saved to `data/sessions/`.

---

## Saving Your Configuration

All configuration is already on the USB (`data/.env`, `hermes-agent/.hermes/config`). Nothing needs to be "saved" -- it persists automatically between sessions and between machines.

To back up your configuration before an event:

```bash
cp -r /media/$USER/HERMESUSB/hermes-portable/data/ ~/hermes-data-backup/
```
