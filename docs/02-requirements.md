# 02 - Requirements

## Hardware

### USB Drive

| Spec | Minimum | Recommended |
|------|---------|-------------|
| Capacity | 8 GB | 32 GB |
| Interface | USB 2.0 | USB 3.1 Gen 1+ |
| Format | exFAT | exFAT |
| Type | Flash drive | Flash drive or portable SSD |

**Why exFAT?**  
exFAT is natively supported on Windows 10/11, Linux kernel 5.4+ (exfatprogs), and macOS. It handles files over 4 GB (unlike FAT32) and has no journaling overhead.

**Why 32 GB recommended?**  
The Hermes install pulls approximately 600 MB of runtimes (Python via uv, Node.js 22, PortableGit on Windows, ripgrep, ffmpeg). Add ~200 MB for the hermes-agent repo and virtualenv. Budget 1-2 GB for model caches and session history over time. 8 GB is workable but tight.

**Performance note:**  
USB 2.0 flash drives are slow for Python virtualenv operations. On first launch after plugging into a new machine, expect 5-15 seconds for the launcher to resolve PATH and start. A USB 3.1 SSD is noticeably faster.

### Host Machine

| Resource | Minimum | Notes |
|----------|---------|-------|
| RAM | 4 GB | 8 GB+ for comfortable use with browser tools |
| CPU | x64 (64-bit) | ARM64 on Windows has limited PortableGit support |
| Internet (build only) | Required | ~600 MB download on first build |
| Internet (runtime) | Required for cloud providers | Not required for local Ollama |

---

## Software -- Windows

| Requirement | Version | Notes |
|------------|---------|-------|
| Windows | 10 64-bit or 11 | Earlier versions untested |
| PowerShell | 5.1+ | Built into Windows 10/11 |
| Git | Optional | Installer downloads PortableGit (~50 MB) if absent |
| WSL2 | Optional | Required only for dashboard chat terminal pane |
| Admin rights | Local admin | Required for installer; not required for daily use after build |

**Execution policy:**  
The builder sets `ExecutionPolicy RemoteSigned` for the current user only. This does not affect machine-wide policy.

**32-bit Windows:**  
PortableGit ships 64-bit and ARM64 only. On 32-bit Windows, the installer falls back to MinGit, which lacks bash.exe. Terminal tool and agent browser features will not work. 64-bit is strongly recommended.

---

## Software -- Linux

| Requirement | Version | Notes |
|------------|---------|-------|
| Kernel | 5.4+ | For exFAT native support (exfatprogs) |
| bash | 4.0+ | Standard on all modern distributions |
| curl | Any | For pulling the official installer |
| git | Any | Builder will attempt apt/pacman/dnf install if missing |
| sudo | Available | Required for Playwright browser deps (optional feature) |
| exfatprogs | Any | `sudo apt install exfatprogs` if USB not automounting |

**Supported distributions (tested by Nous Research):**  
Debian/Ubuntu, Arch Linux, Fedora/RHEL, openSUSE

**Kali Linux:**  
Fully supported. Same as Debian path.

**exFAT mounting on Linux:**

```bash
# Install exFAT support if USB does not automount
sudo apt install exfatprogs       # Debian/Ubuntu/Kali
sudo pacman -S exfatprogs         # Arch
sudo dnf install exfatprogs       # Fedora

# Manual mount if needed
sudo mount -t exfat /dev/sdX1 /media/usb
```

---

## Network Requirements

| Phase | Requirement |
|-------|------------|
| Build (first time) | Internet required, ~600 MB |
| Daily use (cloud provider) | Internet required for LLM API calls |
| Daily use (local Ollama) | No internet required after model download |
| hermes update | Internet required |

**Firewall notes:**  
The installer downloads from `raw.githubusercontent.com`, `pypi.org`, `nodejs.org`, and `github.com`. Corporate or event network firewalls may block these. Use a hotspot or VPN if needed.

---

## Provider Requirements

You need at least one of the following to use Hermes:

| Provider | What You Need | Cost Model |
|----------|--------------|------------|
| Anthropic Claude | API key from console.anthropic.com | Pay per token |
| OpenRouter | API key from openrouter.ai | Pay per token, 200+ models |
| DeepSeek | API key from platform.deepseek.com | Pay per token |
| Ollama (local) | Ollama running on host or network | Free, local compute |
| Nous Portal | Subscription | Subscription, 300+ models |
| OpenAI | API key | Pay per token |

For field/event use (DEF CON, etc.), OpenRouter with a prepaid balance or a dedicated low-balance Anthropic API key is recommended. Do not put production credentials on a portable drive.
