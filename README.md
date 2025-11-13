# ShellShock v1.0 — Your CTF/Pentest Box

**Repository:** [Jamie-loring/Public-scripts](https://github.com/Jamie-loring/Public-scripts/blob/ShellShock/README.md)

---

## Overview

ShellShock is an automated setup script designed for Debian-based systems like **Parrot OS** and **Kali Linux**. It configures your environment into a complete, ready-to-go CTF and penetration testing box — all with a single command.

```bash
curl -fsSL https://raw.githubusercontent.com/Jamie-loring/Public-scripts/ShellShock/install.sh | sudo bash
```

**The structure is:**
```
https://raw.githubusercontent.com/
  Jamie-loring/           (user)
  Public-scripts/         (repo)
  ShellShock/             (branch)
  ShellShock              (filename - no extension!)
```

After installation, reboot when prompted to enter your new environment.

---

## What You Get

### Shell Environment

* **Zsh**, **Oh-My-Zsh**, **Powerlevel10k**
* Autosuggestions, syntax highlighting, and user-friendly defaults

### Tools

Installed automatically:

```
impacket, netexec, nuclei, ffuf, chisel, bloodhound, evil-winrm, ysoserial, Rubeus, SharpHound, Seatbelt, runasCs.exe, linpeas, winpeas, penelope.py
```

### Wordlists

* **SecLists**, **rockyou.txt**, and smart symbolic links

### Repositories

* **PEASS-ng**, **HackTricks**, **PayloadsAllTheThings**, **impacket**, **nuclei-templates**, **GTFOBins**, **LOLBAS**

### Firefox Setup

* Preconfigured to auto-install the following extensions on first launch:

  * Dark Reader
  * Cookie Editor
  * FoxyProxy
  * Wappalyzer
  * HackTools
  * User-Agent Switcher

> **Note:** Firefox addon installation is currently **known to be broken**. Run `~/install-firefox-extensions.sh` manually if needed.

### VirtualBox Integration

* Auto-detects Oracle VirtualBox guests
* Installs **Guest Additions**, **clipboard**, **drag & drop**, and **shared folder** support

### OpSec Features

* **RESET_CTF_BOX.sh** archives live PTY buffers, clears credentials, Kerberos tickets, and SSH keys

### Update Management

* `update-tools.sh` refreshes tools, repos, and configurations

### Documentation

After install, the following files are placed on your Desktop:

```
COMMANDS.txt            → Alias/function reference
TOOL_LOCATIONS.txt      → Environment + tool paths
FIREFOX_EXTENSIONS.txt  → Extension guide
RESET_CTF_BOX.sh        → Full system reset
RESTORE_PARROT_DEFAULTS.sh → Restore Parrot theme defaults
```

---

## Core Commands

| Command         | Function                                       |
| --------------- | ---------------------------------------------- |
| `newengagement` | Create new engagement workspace                |
| `quickscan`     | Run timestamped nmap scan                      |
| `extract`       | Universal extractor                            |
| `update`        | Run update-tools.sh                            |
| `reset`         | Execute system wipe/reset                      |
| `host`          | Shortcut to mounted shared folder (VirtualBox) |

---

## Directory Structure

```
~/tools/
├── repos/        ← PEASS-ng, HackTricks, etc.
├── wordlists/    ← SecLists, rockyou.txt
├── windows/      ← Rubeus.exe, runasCs.exe, etc.
└── go/bin/       ← naabu, httpx, nuclei, ffuf, chisel

~/engagements/<project>/
├── recon/
├── scans/
├── exploits/
├── loot/
├── notes/
└── screenshots/
```

---

## Pro Tips

* Nuclei templates auto-update on shell start
* Aliases can be used inside scripts
* Use **RESET_CTF_BOX.sh** between engagements
* If Firefox extensions fail, rerun `~/install-firefox-extensions.sh`

---

## Supported OS

ShellShock is tested and optimized for:

* **Parrot OS** (Debian-based, preferred)
* **Kali Linux**
* Other Debian-based distros may work but are not officially supported

---

## Legal & Ethics

> *“Just because you can, doesn’t mean you should.”*

* Always get explicit permission before testing.
* Stay within scope.
* Be ethical, responsible, and lawful.

This script is **100% free** to modify and distribute — but you **cannot charge** for it.
