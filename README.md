# ShellShock v3.6 — Your CTF / Pentest Box

> **One command install. Ready for Capture-the-Flag (CTF) and pentest labs.**

[![Release](https://img.shields.io/badge/release-v3.6-blue)]() [![License](https://img.shields.io/badge/license-Non--Commercial--See--LICENSE-yellow)]() <!-- Replace links with tags if you publish -->

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Install](#quick-install)
3. [What You Get](#what-you-get)
4. [Quickstart / After Reboot](#quickstart--after-reboot)
5. [Core Commands & Aliases](#core-commands--aliases)
6. [Directory Layout](#directory-layout)
7. [Desktop Documentation](#desktop-documentation)
8. [Pro Tips](#pro-tips)
9. [Troubleshooting](#troubleshooting)
10. [Security, OpSec & Ethics](#security-opsec--ethics)
11. [Contributing](#contributing)
12. [Changelog](#changelog)
13. [License](#license)
14. [Credits & Acknowledgements](#credits--acknowledgements)

---

## Overview

ShellShock is a one-command installer that builds a focused, ready-to-use environment for CTFs and pentest labs. It configures a modern shell, installs common tooling, prepares wordlists and repo checkouts, configures VirtualBox convenience features, and drops documentation on the desktop so you can get started fast.

This repository contains the installer script and supporting resources. Use responsibly.

---

## Quick Install

> **Run as root / via sudo**

```bash
curl -fsSL https://raw.githubusercontent.com/Jamie-loring/Public-scripts/main/ShellShock/install.sh | sudo bash
```

The script will prompt:

```
Reboot now? (y/n)
```

Say `y` to reboot into the created user. After the reboot you will be logged into the prepared environment.

---

## What You Get

* **Shell & UI**

  * Zsh + Oh-My-Zsh + Powerlevel10k
  * Autosuggestions, Syntax Highlighting
* **CLI tooling** (common pentest/CTF tools)

  * `impacket`, `netexec`, `nuclei`, `ffuf`, `chisel`, `bloodhound`, `evil-winrm`, `ysoserial`, `Rubeus`, `SharpHound`, `Seatbelt`, `runasCs.exe`, `linpeas`, `winpeas`, `penelope.py`, and more
* **Wordlists**

  * `SecLists`, `rockyou.txt`, curated wordlists and smart symlinks
* **Repos cloned** (smart symlinks in `~/tools/repos`)

  * PEASS-ng, HackTricks, PayloadsAllTheThings, impacket, nuclei-templates, GTFOBins, LOLBAS
* **Firefox**

  * Auto-installs extensions (Dark Reader, Cookie Editor, FoxyProxy, Wappalyzer, HackTools, User-Agent Switcher) — see `FIREFOX_EXTENSIONS.txt` for details
* **VirtualBox**

  * Clipboard, Drag&Drop, Shared Folder helpers (host folder mounted at `/media/sf_ctf-tools` by default)
* **OpSec helpers**

  * `RESET_CTF_BOX.sh` — archive live PTY buffers, wipe obvious credentials, clear Kerberos tickets, rotate SSH keys (read script before use)
* **Updates**

  * `update-tools.sh` — helper used to refresh installed tools and Go binaries
* **Desktop docs**

  * `COMMANDS.txt`, `TOOL_LOCATIONS.txt`, `FIREFOX_EXTENSIONS.txt`, `RESET_CTF_BOX.sh`, `RESTORE_PARROT_DEFAULTS.sh`

---

## Quickstart — After Reboot

1. Log into the supplied user account (the installer will create a local user for daily use).
2. Open a terminal — your shell prompt is pre-configured.
3. Run a quick scan or create an engagement:

```bash
# create new engagement directory
newengagement my-target

# run a quick scan wrapper
quickscan my-target

# update toolset
update-tools.sh

# if you want to nuke credentials & reset state (read before running)
~/Desktop/RESET_CTF_BOX.sh
```

---

## Core Commands & Aliases

The following commands are provided as convenient wrappers and aliases. They are defined in the install and/or the user dotfiles — inspect them in `~/.zshrc` and `~/scripts`.

| Command                      | Purpose                                                                        |
| ---------------------------- | ------------------------------------------------------------------------------ |
| `newengagement <name>`       | Create `~/engagements/<name>` with skeleton dirs                               |
| `quickscan <name>`           | Run timestamped nmap + basic enum, store output in engagement                  |
| `extractor`                  | Universal extractor for archives and dumped files                              |
| `update-tools.sh`            | Pull updates for repos, rebuild go tools, refresh atomized bins                |
| `~/Desktop/RESET_CTF_BOX.sh` | Wipe local creds, archive PTY buffers, clear Kerberos/SSH state (OpSec helper) |
| `host`                       | `cd /media/sf_ctf-tools` (host-shared folder mount)                            |

> Tip: All aliases are safe to use in scripts — they are exported functions where appropriate.

---

## Directory Layout

```
~
├── tools/
│   ├── repos/        # cloned repos (PEASS-ng, HackTricks, etc.)
│   ├── wordlists/    # SecLists, rockyou.txt
│   ├── windows/      # Windows tools & EXEs (Rubeus.exe, runasCs.exe, etc.)
│   └── go/bin/       # compiled Go tools (naabu, httpx, nuclei, ffuf, chisel)

├── scripts/          # helper scripts (update-tools.sh, installer helpers)
└── engagements/      # <name>/ recon, scans, exploits, loot, notes, screenshots
    └── <name>/
        ├── recon/
        ├── scans/
        ├── exploits/
        ├── loot/
        ├── notes/
        └── screenshots/
```

---

## Desktop Documentation (Delivered to Desktop)

* `COMMANDS.txt` — Full alias/function reference and examples
* `TOOL_LOCATIONS.txt` — Environment & tool paths
* `FIREFOX_EXTENSIONS.txt` — Extension list and usage notes
* `RESET_CTF_BOX.sh` — Full system reset helper (read before running)
* `RESTORE_PARROT_DEFAULTS.sh` — Quick theme & visual restore script

---

## Pro Tips

* **Nuclei** templates auto-update on shell start (configurable) — check `~/.config/nuclei`.
* Use `update-tools.sh` often after network-heavy sessions to refresh templates and go binaries.
* If Firefox extension auto-install fails on first launch, run:

```bash
~/install-firefox-extensions.sh
```

* Run `~/Desktop/RESET_CTF_BOX.sh` between CTF runs to reduce the chance of credential leakage.

---

## Troubleshooting

**Firefox extensions didn’t install**

* Run `~/install-firefox-extensions.sh` and restart Firefox.

**Go binaries missing from `~/tools/go/bin`**

* Ensure `GOBIN`/`GOPATH` are set and run `update-tools.sh`.

**Shared folder not mounted**

* Verify VirtualBox Guest Additions are present and the host folder is shared. Check `/media/` for mount points.

**I don’t want some repos/tools installed**

* Remove the symlink from `~/tools/repos` and delete the directory. Re-run `update-tools.sh` to refresh any dependent bins.

---

## Security, OpSec & Ethics

* **Read the scripts before running them.** Do not run on devices you do not control or on production systems.
* `RESET_CTF_BOX.sh` performs destructive cleaning actions — read it carefully before use.
* **Do not use these tools without permission.** Unauthorized access is illegal.

> *"Just because you can, doesn't mean you should."*

---

## Contributing

Contributions, issues, and feature requests are welcome. Please follow these guidelines:

* Open an issue describing the bug or feature request.
* Send a pull request with a clear description and tests where appropriate.
* Keep changes scoped and documented.

---

## Changelog (high level)

* **v3.6** — Polished install flow, added more repo symlinks, updated OpSec helpers.
* **v3.5** — Firefox extension auto-install improvements.
* **v3.0** — Major refactor: moved tools into `~/tools` and added `update-tools.sh`.

---

## License

This project is intended for free modification and distribution **for non-commercial use only**. See `LICENSE` for exact terms.

```text
Copyright (c) 2025 Jamie Loring

Permission is granted to use, copy, modify, and distribute this software for
**non-commercial** purposes only, provided that this copyright notice and
permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
```

> If you want a different license (MIT, Apache 2.0, or CC BY-NC) I can add a
> standard LICENSE file instead — tell me which you prefer.

---

## Credits & Acknowledgements

* This README and installer were created and maintained by Jamie Loring.
* Downstream tooling and repository content are maintained by their original authors — please see each subrepo for their licenses and attribution.
