#!/bin/bash

# Parrot Security VM Enhancement Bootstrap Script
# For fresh Parrot installs running as VM guest on Windows host

set -e

# Setup logging
LOGFILE="$HOME/bootstrap-$(date +%Y%m%d_%H%M%S).log"
exec 3>&1 4>&2
exec 1>>"$LOGFILE" 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { 
    echo -e "${GREEN}[+]${NC} $1"
    echo -e "${GREEN}[+]${NC} $1" >&3
}
log_warn() { 
    echo -e "${YELLOW}[!]${NC} $1"
    echo -e "${YELLOW}[!]${NC} $1" >&3
}
log_error() { 
    echo -e "${RED}[-]${NC} $1"
    echo -e "${RED}[-]${NC} $1" >&3
}
log_progress() {
    echo -e "${BLUE}[*]${NC} $1" >&3
}

# Restore stdout/stderr at exit
trap 'exec 1>&3 2>&4' EXIT

# ============================================
# PHASE 1: System Updates & Base Packages
# ============================================
phase1_system_setup() {
    log_progress "Phase 1/8: System Updates & Base Packages..."
    log_info "Phase 1: Updating system and installing base packages"
    
    apt update
    apt upgrade -y
    
    apt install -y \
        build-essential git curl wget \
        vim neovim tmux zsh \
        python3-pip python3-venv \
        golang-go rustc cargo \
        docker.io docker-compose \
        jq ripgrep fd-find bat \
        htop ncdu tree \
        fonts-powerline \
        silversearcher-ag
    
    log_info "Phase 1 complete"
    log_progress "Phase 1/8: ✓ Complete"
}

# ============================================
# PHASE 2: User Setup
# ============================================
phase2_user_setup() {
    log_progress "Phase 2/8: User Account Setup..."
    log_info "Phase 2: Setting up user account"
    
    # Create jamie user as essentially root (let system assign UID, use bash for now)
    if ! id "jamie" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo jamie
        passwd -d jamie  # Remove password entirely
        
        # Give jamie full root privileges without password
        echo "jamie ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jamie
        chmod 440 /etc/sudoers.d/jamie
        
        log_info "User 'jamie' created with no password"
    else
        log_warn "User 'jamie' already exists, skipping creation"
    fi
    
    # Enable docker without sudo
    usermod -aG docker jamie || true
    
    # Set up home directory
    export USER_HOME=/home/jamie
    
    log_info "Phase 2 complete"
    log_progress "Phase 2/8: ✓ Complete"
}

# ============================================
# PHASE 3: Shell Environment (Zsh + Oh-My-Zsh)
# ============================================
phase3_shell_setup() {
    log_progress "Phase 3/8: Shell Environment (Zsh + Oh-My-Zsh + p10k)..."
    log_info "Phase 3: Setting up Zsh and Oh-My-Zsh for jamie"
    
    # Switch to jamie's home for installations
    export HOME=$USER_HOME
    cd $USER_HOME
    
    # Install Oh-My-Zsh
    if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
        sudo -u jamie sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Install zsh-autosuggestions
    sudo -u jamie git clone https://github.com/zsh-users/zsh-autosuggestions ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true
    
    # Install zsh-syntax-highlighting
    sudo -u jamie git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true
    
    # Install Powerlevel10k theme
    sudo -u jamie git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${USER_HOME}/.oh-my-zsh/custom/themes/powerlevel10k 2>/dev/null || true
    
    # Download pre-configured p10k config from GitHub
    log_info "Downloading pre-configured Powerlevel10k config"
    sudo -u jamie wget https://raw.githubusercontent.com/Jamie-loring/Public-scripts/main/p10k-jamie-config.zsh -O ${USER_HOME}/.p10k.zsh 2>/dev/null || log_warn "Failed to download p10k config, will use default"
    
    # Set Zsh as default shell for jamie
    chsh -s $(which zsh) jamie || true
    
    # Configure LightDM to auto-login as jamie instead of user
    log_info "Configuring auto-login for jamie"
    if [ -f /etc/lightdm/lightdm.conf ]; then
        # Backup original config
        cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup 2>/dev/null || true
        
        # Remove any existing autologin-user lines and add jamie
        sed -i '/^autologin-user=/d' /etc/lightdm/lightdm.conf
        sed -i '/^\[Seat:\*\]/a autologin-user=jamie' /etc/lightdm/lightdm.conf
    fi
    
    log_info "Phase 3 complete"
    log_progress "Phase 3/8: ✓ Complete"
}

# ============================================
# PHASE 4: Tool Installation & Optimization
# ============================================
phase4_tools_setup() {
    log_progress "Phase 4/8: Tool Installation (repos, wordlists, scripts)..."
    log_info "Phase 4: Installing and configuring pentesting tools"
    
    # Create tool directory structure as jamie
    sudo -u jamie mkdir -p $USER_HOME/tools/{wordlists,scripts,exploits,repos}
    
    # Impacket - properly installed
    log_info "Installing Impacket"
    pip3 install impacket --break-system-packages || pip3 install impacket
    
    # Other essential Python tools
    log_info "Installing Python pentesting tools"
    pip3 install --break-system-packages \
        bloodhound \
        bloodyAD \
        bloodhound-python \
        mitm6 \
        responder \
        certipy-ad \
        coercer \
        pypykatz \
        lsassy \
        enum4linux-ng \
        dnsrecon \
        git-dumper \
        penelope-shell \
        kerbrute || true
    
    # Install Rust tools
    log_info "Installing Rust-based tools"
    cargo install rustscan feroxbuster || true
    
    # Install Go tools
    log_info "Installing Go-based tools"
    go install github.com/nicocha30/ligolo-ng/cmd/proxy@latest || true
    go install github.com/nicocha30/ligolo-ng/cmd/agent@latest || true
    go install github.com/jpillora/chisel@latest || true
    
    # Copy go binaries to path
    cp ~/go/bin/* /usr/local/bin/ 2>/dev/null || true
    
    # Clone useful repos
    log_info "Cloning useful repositories"
    cd $USER_HOME/tools/repos
    
    sudo -u jamie bash << 'REPOS_EOF'
[ ! -d "PayloadsAllTheThings" ] && git clone https://github.com/swisskyrepo/PayloadsAllTheThings.git || true
[ ! -d "PEASS-ng" ] && git clone https://github.com/carlospolop/PEASS-ng.git || true
[ ! -d "Windows-Exploit-Suggester" ] && git clone https://github.com/AonCyberLabs/Windows-Exploit-Suggester.git || true
[ ! -d "PowerSploit" ] && git clone https://github.com/PowerShellMafia/PowerSploit.git || true
REPOS_EOF
    
    # Create quick access directory for PEAS scripts
    log_info "Setting up PEAS scripts quick access"
    sudo -u jamie mkdir -p $USER_HOME/peas
    
    # Create symlinks to PEAS scripts for easy access
    if [ -d "$USER_HOME/tools/repos/PEASS-ng" ]; then
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh $USER_HOME/peas/linpeas.sh 2>/dev/null || true
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe $USER_HOME/peas/winpeas64.exe 2>/dev/null || true
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx86.exe $USER_HOME/peas/winpeas86.exe 2>/dev/null || true
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASany.exe $USER_HOME/peas/winpeas.exe 2>/dev/null || true
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEAS.bat $USER_HOME/peas/winpeas.bat 2>/dev/null || true
    fi
    
    # Download wordlists
    log_info "Setting up wordlists"
    cd $USER_HOME/tools/wordlists
    
    # SecLists if not already present
    if [ ! -d "SecLists" ]; then
        sudo -u jamie git clone https://github.com/danielmiessler/SecLists.git
    fi
    
    # Unzip rockyou.txt if it exists and isn't already unzipped
    log_info "Unzipping rockyou.txt"
    if [ -f "/usr/share/wordlists/rockyou.txt.gz" ] && [ ! -f "/usr/share/wordlists/rockyou.txt" ]; then
        gunzip /usr/share/wordlists/rockyou.txt.gz
        log_info "rockyou.txt unzipped"
    elif [ -f "/usr/share/wordlists/rockyou.txt" ]; then
        log_info "rockyou.txt already unzipped"
    else
        log_warn "rockyou.txt not found in /usr/share/wordlists/"
    fi
    
    # Create symlink to rockyou in our wordlists folder for convenience
    if [ -f "/usr/share/wordlists/rockyou.txt" ]; then
        sudo -u jamie ln -sf /usr/share/wordlists/rockyou.txt $USER_HOME/tools/wordlists/rockyou.txt 2>/dev/null || true
    fi
    
    # Create tool reference guide
    log_info "Creating tool reference guide"
    cat > $USER_HOME/Desktop/CTF_TOOLS_REFERENCE.txt << 'TOOLS_EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                        CTF TOOLS QUICK REFERENCE                          ║
╚═══════════════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════════════════
RECONNAISSANCE & ENUMERATION
═══════════════════════════════════════════════════════════════════════════

nmap
  Network scanner for host discovery and port enumeration
  Usage: nmap -sC -sV -oA output <target>

rustscan
  Fast port scanner that feeds results to nmap
  Usage: rustscan -a <target> -- -sC -sV

gobuster
  Directory/file brute-forcing tool for web enumeration
  Usage: gobuster dir -u http://target -w wordlist.txt

feroxbuster
  Fast content discovery tool with recursion
  Usage: feroxbuster -u http://target -w wordlist.txt

enum4linux-ng
  SMB enumeration tool for Windows/Samba systems
  Usage: enum4linux-ng -A <target>

kerbrute
  Kerberos username enumeration and password spraying
  Usage: kerbrute userenum --dc <dc-ip> -d <domain> users.txt

bloodhound / bloodhound-python
  Active Directory relationship mapper
  Usage: bloodhound-python -u user -p pass -d domain -dc dc.domain.com -c all

dnsrecon
  DNS enumeration and zone transfer testing
  Usage: dnsrecon -d <domain> -a

═══════════════════════════════════════════════════════════════════════════
EXPLOITATION & LATERAL MOVEMENT
═══════════════════════════════════════════════════════════════════════════

msfconsole
  Metasploit Framework - exploitation and post-exploitation
  Usage: msfconsole -q

searchsploit
  Offline exploit database search
  Usage: searchsploit <software name>

═══════════════════════════════════════════════════════════════════════════
ACTIVE DIRECTORY TOOLS (IMPACKET SUITE)
═══════════════════════════════════════════════════════════════════════════

psexec / smbexec / wmiexec / dcomexec / atexec
  Remote command execution on Windows systems
  Usage: psexec <domain>/<user>:<pass>@<target>

secretsdump
  Extract credentials from Windows systems (SAM, LSA, NTDS.dit)
  Usage: secretsdump <domain>/<user>:<pass>@<target>

GetNPUsers
  Find users with Kerberos pre-authentication disabled (AS-REP roasting)
  Usage: GetNPUsers <domain>/ -dc-ip <dc-ip> -usersfile users.txt

GetUserSPNs
  Find service accounts for Kerberoasting
  Usage: GetUserSPNs <domain>/<user>:<pass> -dc-ip <dc-ip> -request

getTGT / getST
  Request Kerberos tickets for pass-the-ticket attacks
  Usage: getTGT <domain>/<user>:<pass>

ntlmrelayx
  NTLM relay attacks against SMB, HTTP, LDAP
  Usage: ntlmrelayx -tf targets.txt -smb2support

smbserver
  Quick SMB server for file transfers
  Usage: smbserver share . -smb2support

smbclient
  SMB client for file operations
  Usage: smbclient //<target>/share -U <user>

ticketer
  Create silver/golden Kerberos tickets
  Usage: ticketer -nthash <hash> -domain-sid <sid> -domain <domain> <user>

═══════════════════════════════════════════════════════════════════════════
CREDENTIAL ATTACKS
═══════════════════════════════════════════════════════════════════════════

crackmapexec / netexec
  Swiss army knife for pentesting Windows/AD networks
  Usage: crackmapexec smb <target> -u user -p pass
  Note: Use 'crackmapexec' (netexec not available on this distro)

hydra
  Network login brute-forcer
  Usage: hydra -l user -P wordlist.txt <target> ssh

john
  Password hash cracking tool
  Usage: john --wordlist=rockyou.txt hashes.txt

hashcat
  GPU-accelerated password cracking
  Usage: hashcat -m 1000 -a 0 hashes.txt rockyou.txt

responder
  LLMNR/NBT-NS/mDNS poisoner for credential capture
  Usage: responder -I eth0 -wf

mitm6
  IPv6 man-in-the-middle for credential relay
  Usage: mitm6 -d <domain>

certipy-ad
  Active Directory certificate abuse tool
  Usage: certipy find -u user@domain -p pass -dc-ip <dc-ip>

coercer
  Force Windows authentication for relay attacks
  Usage: coercer -u user -p pass -d domain -t <target> -l <listener>

pypykatz
  Mimikatz implementation in Python
  Usage: pypykatz lsa minidump lsass.dmp

lsassy
  Remote LSASS credential dumping
  Usage: lsassy -u user -p pass -d domain <target>

═══════════════════════════════════════════════════════════════════════════
SHELLS & POST-EXPLOITATION
═══════════════════════════════════════════════════════════════════════════

penelope
  Advanced shell handler with auto-upgrade and file transfer
  Usage: penelope 4444

nc (netcat)
  Basic network connections and listeners
  Usage: nc -lvnp 4444

evil-winrm
  WinRM shell with PowerShell capabilities
  Usage: evil-winrm -i <target> -u user -p pass

LinPEAS / WinPEAS
  Privilege escalation enumeration scripts
  Location: ~/peas/ (symlinked for easy access)
  Usage: linpeas (on target) or winpeas (on target)
  Full repo: ~/tools/repos/PEASS-ng/

═══════════════════════════════════════════════════════════════════════════
PIVOTING & TUNNELING
═══════════════════════════════════════════════════════════════════════════

ligolo-ng
  Creates TUN interface for pivoting (NO proxychains needed!)
  Server: proxy -selfcert
  Agent: agent -connect <attacker-ip>:11601 -ignore-cert
  Then: session, ifconfig, start

chisel
  Fast TCP/UDP tunnel over HTTP
  Server: chisel server -p 8080 --reverse
  Client: chisel client <server-ip>:8080 R:socks

ssh
  SSH tunneling for port forwarding
  Usage: ssh -L 8080:localhost:80 user@<target>
  Usage: ssh -D 1080 user@<target>  # SOCKS proxy

═══════════════════════════════════════════════════════════════════════════
WEB APPLICATION TESTING
═══════════════════════════════════════════════════════════════════════════

burpsuite
  Web application security testing platform
  Usage: burpsuite

sqlmap
  Automated SQL injection tool
  Usage: sqlmap -u "http://target/?id=1" --batch

nikto
  Web server vulnerability scanner
  Usage: nikto -h http://target

wpscan
  WordPress vulnerability scanner
  Usage: wpscan --url http://target

ffuf
  Fast web fuzzer
  Usage: ffuf -u http://target/FUZZ -w wordlist.txt

═══════════════════════════════════════════════════════════════════════════
FILE OPERATIONS & UTILITIES
═══════════════════════════════════════════════════════════════════════════

serve / serve80
  Quick Python HTTP server
  Usage: serve (port 8000) or serve80 (port 80)

git-dumper
  Dump exposed .git repositories
  Usage: git-dumper http://target/.git/ output/

base64
  Encode/decode base64
  Aliases: b64e "string" / b64d "encoded"

═══════════════════════════════════════════════════════════════════════════
CUSTOM FUNCTIONS
═══════════════════════════════════════════════════════════════════════════

newengagement <name>
  Creates engagement folder structure in ~/engagements/
  Includes: recon, exploit, loot, screenshots, notes

quickscan <target>
  Runs nmap with default scripts and version detection
  Saves output as scan_<target>

extract <file>
  Universal archive extractor (zip, tar, gz, bz2, etc.)

revshell <ip> <port>
  Generates common reverse shell one-liners

update-tools.sh
  Updates all installed tools and repositories

backup-engagement.sh <name>
  Creates timestamped backup of engagement folder

═══════════════════════════════════════════════════════════════════════════
USEFUL WORDLISTS
═══════════════════════════════════════════════════════════════════════════

Location: ~/tools/wordlists/SecLists/

Common paths:
  - Discovery/Web-Content/directory-list-2.3-medium.txt
  - Passwords/Leaked-Databases/rockyou.txt
  - Usernames/Names/names.txt
  - Fuzzing/command-injection-commix.txt
  - Discovery/DNS/subdomains-top1million-5000.txt

═══════════════════════════════════════════════════════════════════════════
USEFUL REPOSITORIES
═══════════════════════════════════════════════════════════════════════════

Location: ~/tools/repos/

PayloadsAllTheThings/
  Comprehensive payload and technique reference

PEASS-ng/
  LinPEAS and WinPEAS privilege escalation scripts
  Quick access: ~/peas/ directory with symlinks

PowerSploit/
  PowerShell post-exploitation framework

Windows-Exploit-Suggester/
  Finds missing patches on Windows systems

═══════════════════════════════════════════════════════════════════════════
TIPS & TRICKS
═══════════════════════════════════════════════════════════════════════════

• All Impacket tools work WITHOUT the 'impacket-' prefix
• Docker commands don't require sudo (jamie is in docker group)
• Tmux prefix is Ctrl-a (split with | and -)
• Alt+arrows to switch tmux panes without prefix
• Tab completion works for most commands and arguments
• Up arrow searches command history based on what you've typed
• Use 'extract' function for any compressed file
• Ligolo-ng creates a real network interface - no proxychains needed!

═══════════════════════════════════════════════════════════════════════════
ENGAGEMENT WORKFLOW
═══════════════════════════════════════════════════════════════════════════

1. newengagement <target-name>
2. cd ~/engagements/<target-name>
3. quickscan <target-ip>
4. Document findings in notes/
5. Store loot in loot/
6. Take screenshots in screenshots/
7. backup-engagement.sh <target-name> when done

═══════════════════════════════════════════════════════════════════════════

Last updated: $(date)
Script version: 1.0

TOOLS_EOF
    
    chown jamie:jamie $USER_HOME/Desktop/CTF_TOOLS_REFERENCE.txt
    
    log_info "Phase 4 complete"
    log_progress "Phase 4/8: ✓ Complete"
}

# ============================================
# PHASE 5: Dotfiles & Aliases Configuration
# ============================================
phase5_dotfiles_setup() {
    log_progress "Phase 5/8: Dotfiles & Aliases Configuration..."
    log_info "Phase 5: Configuring dotfiles and aliases"
    
    # Backup existing configs
    [ -f $USER_HOME/.zshrc ] && cp $USER_HOME/.zshrc $USER_HOME/.zshrc.backup
    [ -f $USER_HOME/.tmux.conf ] && cp $USER_HOME/.tmux.conf $USER_HOME/.tmux.conf.backup
    
    # Create custom .zshrc
    cat > $USER_HOME/.zshrc << 'EOF'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    docker
    sudo
    zsh-autosuggestions
    zsh-syntax-highlighting
    command-not-found
    colored-man-pages
)

source $ZSH/oh-my-zsh.sh

# ============================================
# Custom Aliases - Impacket
# ============================================
alias psexec='impacket-psexec'
alias smbexec='impacket-smbexec'
alias wmiexec='impacket-wmiexec'
alias dcomexec='impacket-dcomexec'
alias atexec='impacket-atexec'
alias secretsdump='impacket-secretsdump'
alias GetNPUsers='impacket-GetNPUsers'
alias GetUserSPNs='impacket-GetUserSPNs'
alias GetADUsers='impacket-GetADUsers'
alias getTGT='impacket-getTGT'
alias getST='impacket-getST'
alias smbclient='impacket-smbclient'
alias smbserver='impacket-smbserver'
alias ntlmrelayx='impacket-ntlmrelayx'
alias ticketer='impacket-ticketer'
alias raiseChild='impacket-raiseChild'

# ============================================
# Custom Aliases - General
# ============================================
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias cat='batcat --style=plain' 2>/dev/null || alias cat='cat'
alias fd='fdfind' 2>/dev/null || alias fd='fd'

# Docker shortcuts
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
alias dstop='docker stop $(docker ps -aq)'
alias drm='docker rm $(docker ps -aq)'

# Metasploit
alias msfconsole='msfconsole -q'
alias msf='msfconsole -q'

# Reverse shells
alias penelope='penelope'
alias pen='penelope'

# AD Tools shortcuts
alias bh='bloodhound'
alias bhp='bloodhound-python'
alias bloody='bloodyAD'

# Network enumeration
alias nse='ls /usr/share/nmap/scripts | grep'
alias portscan='nmap -p- -T4 --min-rate=1000'
alias vulnscan='nmap -sV --script=vuln'

# Web enumeration
alias gobust='gobuster dir -w ~/tools/wordlists/SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt -u'
alias ferox='feroxbuster -w ~/tools/wordlists/SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt -u'

# Quick SMB enumeration
alias smbenum='enum4linux-ng -A'

# PEAS scripts quick access
alias linpeas='~/peas/linpeas.sh'
alias winpeas='~/peas/winpeas.exe'

# Python HTTP servers
alias serve='python3 -m http.server 8000'
alias serve80='sudo python3 -m http.server 80'

# ============================================
# Custom Functions
# ============================================

# Create new engagement folder with standard structure
newengagement() {
    if [ -z "$1" ]; then
        echo "Usage: newengagement <name>"
        return 1
    fi
    
    mkdir -p ~/engagements/$1/{recon,exploit,loot,screenshots,notes}
    cd ~/engagements/$1
    echo "# Engagement: $1" > notes/README.md
    echo "Created: $(date)" >> notes/README.md
    echo "Engagement folder created: ~/engagements/$1"
}

# Quick nmap scan wrapper
quickscan() {
    if [ -z "$1" ]; then
        echo "Usage: quickscan <target>"
        return 1
    fi
    nmap -sC -sV -oA scan_$1 $1
}

# Extract any archive
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick base64 encode/decode
b64e() { echo -n "$1" | base64; }
b64d() { echo -n "$1" | base64 -d; }

# ============================================
# Environment Variables
# ============================================
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export EDITOR=vim
export VISUAL=vim

# Golang
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY

EOF

    # Create tmux config
    cat > $USER_HOME/.tmux.conf << 'EOF'
# Tmux configuration for pentesting

# Change prefix to Ctrl-a
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Enable mouse mode
set -g mouse on

# Don't rename windows automatically
set-option -g allow-rename off

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Increase scrollback buffer
set-option -g history-limit 10000

# Status bar
set -g status-bg black
set -g status-fg white
set -g status-left '#[fg=green]#H '
set -g status-right '#[fg=yellow]#(uptime | cut -d "," -f 3-)'

EOF

    # Create vim config with useful defaults
    cat > $USER_HOME/.vimrc << 'EOF'
" Basic vim configuration for pentesting
set number
set relativenumber
set autoindent
set tabstop=4
set shiftwidth=4
set expandtab
set smarttab
set mouse=a
syntax on
set hlsearch
set incsearch
set ignorecase
set smartcase
set clipboard=unnamedplus

" Show whitespace
set list
set listchars=tab:→\ ,trail:·

" Better split navigation
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

EOF

    # Fix ownership of all dotfiles
    chown -R jamie:jamie $USER_HOME
    
    log_info "Phase 5 complete"
    log_progress "Phase 5/8: ✓ Complete"
}

# ============================================
# PHASE 6: Automation & Maintenance Scripts
# ============================================
phase6_automation_setup() {
    log_progress "Phase 6/8: Automation & Maintenance Scripts..."
    log_info "Phase 6: Setting up automation scripts"
    
    sudo -u jamie mkdir -p $USER_HOME/scripts
    
    # Tool update script
    cat > $USER_HOME/scripts/update-tools.sh << 'EOF'
#!/bin/bash
# Update all pentesting tools

echo "[+] Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "[+] Updating Python tools..."
pip3 install --upgrade impacket crackmapexec bloodhound

echo "[+] Updating repositories..."
cd ~/tools/repos
for dir in */; do
    echo "[+] Updating $dir"
    cd "$dir"
    git pull
    cd ..
done

echo "[+] Updating SecLists..."
cd ~/tools/wordlists/SecLists
git pull

echo "[+] All tools updated!"
EOF
    
    chmod +x $USER_HOME/scripts/update-tools.sh
    
    # Quick backup script
    cat > $USER_HOME/scripts/backup-engagement.sh << 'EOF'
#!/bin/bash
# Backup engagement folder

if [ -z "$1" ]; then
    echo "Usage: backup-engagement.sh <engagement-name>"
    exit 1
fi

BACKUP_DIR=~/backups
mkdir -p $BACKUP_DIR

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
tar -czf $BACKUP_DIR/$1_$TIMESTAMP.tar.gz ~/engagements/$1/

echo "[+] Backup created: $BACKUP_DIR/$1_$TIMESTAMP.tar.gz"
EOF
    
    chmod +x $USER_HOME/scripts/backup-engagement.sh
    chown -R jamie:jamie $USER_HOME/scripts
    
    log_info "Phase 6 complete"
    log_progress "Phase 6/8: ✓ Complete"
}

# ============================================
# PHASE 7: VM Guest Tools (VirtualBox or VMware)
# ============================================
phase7_vm_guest_tools() {
    log_progress "Phase 7/8: VM Guest Tools (clipboard, display, auto-resize)..."
    log_info "Phase 7: Detecting virtualization environment"
    
    # Detect VirtualBox
    if lspci | grep -i "virtualbox" > /dev/null 2>&1 || dmidecode -s system-product-name 2>/dev/null | grep -i "virtualbox" > /dev/null 2>&1; then
        log_info "VirtualBox detected! Installing Guest Additions for bidirectional clipboard"
        
        # Install required dependencies
        apt install -y \
            build-essential \
            dkms \
            linux-headers-$(uname -r) \
            module-assistant \
            perl
        
        # Prepare module-assistant
        m-a prepare
        
        # Download VirtualBox Guest Additions ISO
        VBOX_VERSION=$(VBoxControl --version 2>/dev/null | cut -d 'r' -f1)
        if [ -z "$VBOX_VERSION" ]; then
            # Fallback to latest stable version
            VBOX_VERSION="7.0.14"
            log_warn "Could not detect VBox version, using default: $VBOX_VERSION"
        fi
        
        log_info "Downloading VirtualBox Guest Additions $VBOX_VERSION"
        wget "https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso" \
            -O /tmp/VBoxGuestAdditions.iso
        
        # Mount and install
        mkdir -p /mnt/vbox
        mount -o loop /tmp/VBoxGuestAdditions.iso /mnt/vbox
        
        log_info "Installing VirtualBox Guest Additions"
        cd /mnt/vbox
        ./VBoxLinuxAdditions.run --nox11 || true  # May fail on some modules, that's OK
        
        # Enable bidirectional clipboard and drag-and-drop
        log_info "Enabling bidirectional clipboard and drag-and-drop"
        VBoxClient --clipboard &
        VBoxClient --draganddrop &
        VBoxClient --seamless &
        
        # Add to jamie's autostart
        sudo -u jamie mkdir -p $USER_HOME/.config/autostart
        
        cat > $USER_HOME/.config/autostart/vboxclient-clipboard.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Clipboard
Exec=VBoxClient --clipboard
X-GNOME-Autostart-enabled=true
EOF

        cat > $USER_HOME/.config/autostart/vboxclient-draganddrop.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Drag and Drop
Exec=VBoxClient --draganddrop
X-GNOME-Autostart-enabled=true
EOF

        cat > $USER_HOME/.config/autostart/vboxclient-seamless.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Seamless
Exec=VBoxClient --seamless
X-GNOME-Autostart-enabled=true
EOF
        
        chown -R jamie:jamie $USER_HOME/.config
        
        # Enable auto-resize and set max resolution
        log_info "Configuring display auto-resize"
        VBoxClient --vmsvga &
        
        # Add to jamie's autostart for display auto-resize
        cat > $USER_HOME/.config/autostart/vboxclient-vmsvga.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VBoxClient Display
Exec=VBoxClient --vmsvga
X-GNOME-Autostart-enabled=true
EOF
        
        # Cleanup
        umount /mnt/vbox
        rm /tmp/VBoxGuestAdditions.iso
        
        log_info "VirtualBox Guest Additions installed successfully"
        log_warn "IMPORTANT: Reboot the VM for full functionality"
        log_warn "IMPORTANT: In VBox settings, set Shared Clipboard to 'Bidirectional'"
        
    # Detect VMware
    elif lspci | grep -i "vmware" > /dev/null 2>&1 || dmidecode -s system-product-name 2>/dev/null | grep -i "vmware" > /dev/null 2>&1; then
        log_info "VMware detected! Installing open-vm-tools for bidirectional clipboard"
        
        apt install -y \
            open-vm-tools \
            open-vm-tools-desktop
        
        # Enable and start vmtoolsd
        systemctl enable open-vm-tools
        systemctl start open-vm-tools
        
        log_info "VMware Tools installed successfully"
        log_warn "IMPORTANT: Enable 'Copy and Paste' in VMware VM settings"
        
    else
        log_info "No virtualization environment detected (VirtualBox/VMware)"
        log_info "Installing xclip for clipboard management anyway"
        apt install -y xclip xsel
    fi
    
    log_info "Phase 7 complete"
    log_progress "Phase 7/8: ✓ Complete"
}

# ============================================
# PHASE 8: Post-Install Cleanup
# ============================================
phase8_cleanup() {
    log_progress "Phase 8/8: Post-Install Cleanup..."
    log_info "Phase 8: Cleaning up and finalizing"
    
    # Clean apt cache
    apt autoremove -y
    apt autoclean -y
    
    log_info "Phase 8 complete"
    log_progress "Phase 8/8: ✓ Complete"
}

# ============================================
# Main Execution
# ============================================
main() {
    cat << "EOF"
╔═══════════════════════════════════════════════════╗
║   Parrot Security VM Enhancement Script           ║
║   Fresh install → Fully loaded pentesting box    ║
╚═══════════════════════════════════════════════════╝
EOF
    
    log_warn "This script will modify your system configuration"
    log_warn "Press Ctrl+C to cancel, or Enter to continue..."
    read
    
    phase1_system_setup
    phase2_user_setup
    phase3_shell_setup
    phase4_tools_setup
    phase5_dotfiles_setup
    phase6_automation_setup
    phase7_vm_guest_tools
    phase8_cleanup
    
    cat << EOF

╔═══════════════════════════════════════════════════╗
║              Installation Complete!               ║
╚═══════════════════════════════════════════════════╝

User 'jamie' created with full sudo privileges (no password required)

Next steps:
1. REBOOT the VM: sudo reboot
2. Log in as 'jamie' (auto-login configured)
3. Powerlevel10k theme is pre-configured (no wizard needed!)
4. Run '~/scripts/update-tools.sh' to update everything
5. Create an engagement: newengagement <name>

Useful commands:
  - newengagement <name>  : Create new engagement folder
  - quickscan <target>    : Quick nmap scan
  - serve                 : Start HTTP server on port 8000
  - update-tools.sh       : Update all tools

Tool reference guide on Desktop: CTF_TOOLS_REFERENCE.txt

Happy hacking!
EOF
}

# Run it
main
