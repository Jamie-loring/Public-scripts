# ShellShock v3.6 — Your CTF/Pentest Box. One Command.

``bash
curl -fsSL https://raw.githubusercontent.com/Jamie-loring/Public-scripts/main/ShellShock/install.sh | sudo bash

What You Get - 

Shell,Zsh + Oh-My-Zsh + Powerlevel10k + Autosuggestions + Syntax Highlighting
Tools,"impacket, netexec, nuclei, ffuf, chisel, bloodhound, evil-winrm, ysoserial, Rubeus, SharpHound, Seatbelt, runasCs.exe, linpeas, winpeas, penelope.py"
Wordlists,SecLists + rockyou.txt + smart symlinks
Repos,"PEASS-ng, HackTricks, PayloadsAllTheThings, impacket, nuclei-templates, GTFOBins, LOLBAS"
Firefox,"Auto-installed: Dark Reader, Cookie Editor, FoxyProxy, Wappalyzer, HackTools, User-Agent Switcher"
VirtualBox,Clipboard + Drag & Drop + Shared Folder (host alias)
OpSec,"RESET_CTF_BOX.sh → archives live PTY buffers, wipes creds, Kerberos, SSH"
Updates,update-tools.sh → refreshes everything
Docs,"COMMANDS.txt, TOOL_LOCATIONS.txt, FIREFOX_EXTENSIONS.txt on Desktop"

One-Command Install
curl -fsSL https://raw.githubusercontent.com/Jamie-loring/Public-scripts/main/ShellShock/install.sh | sudo bash
The script will ask: "Reboot now? (y/n)"
→ Say yes to reboot into your new user.
# After reboot → you're in

Core Commands 
newengagement <name>     # → ~/engagements/<name>/
quickscan <ip>           # → timestamped nmap
extract <file>           # → universal extractor
update                   # → ~/scripts/update-tools.sh
reset                    # → ~/Desktop/RESET_CTF_BOX.sh
host                     # → cd /media/sf_ctf-tools

Directory Structure
~/tools/
  ├── repos/           ← PEASS-ng, HackTricks, etc.
  ├── wordlists/       ← SecLists, rockyou.txt
  ├── windows/         ← Rubeus.exe, runasCs.exe, etc.
  └── go/bin/          ← naabu, httpx, nuclei, ffuf, chisel

~/engagements/<name>/
  ├── recon/ scans/ exploits/ loot/ notes/ screenshots/

Pro Tips

Nuclei templates auto-update on shell start
All aliases work in scripts
Firefox extensions auto-install on first launch (currenty broken)
Run ~/install-firefox-extensions.sh if needed
Use RESET_CTF_BOX.sh between CTFs  

Desktop Documentation 
After install, this will be on the users desktop for the supplied user name.

COMMANDS.txt,Full alias/function reference
TOOL_LOCATIONS.txt,Environment + tool paths
FIREFOX_EXTENSIONS.txt,Extension guide
RESET_CTF_BOX.sh,Full system reset
RESTORE_PARROT_DEFAULTS.sh,Restore theme

Legal & Ethics
"Just because you can, doesn't mean you should."
Ask permission. Stay out of jail. Be responsible.
This script is 100% free to modify and distribute — but you cannot charge for it.
