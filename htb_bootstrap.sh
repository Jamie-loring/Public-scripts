#!/bin/bash

# Parrot Security VM Enhancement Bootstrap Script
# For fresh Parrot installs running as VM guest on Windows host

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { 
    echo -e "${GREEN}[+]${NC} $1"
}
log_warn() { 
    echo -e "${YELLOW}[!]${NC} $1"
}
log_error() { 
    echo -e "${RED}[-]${NC} $1"
}
log_progress() {
    echo -e "${BLUE}[*]${NC} $1"
}

show_progress() {
    local phase=$1
    local total=8
    local percent=$((phase * 100 / total))
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} Overall Progress: ${GREEN}${percent}%${NC} (Phase ${phase}/${total})                ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
}

# ============================================
# PHASE 1: System Updates & Base Packages
# ============================================
phase1_system_setup() {
    show_progress 1
    log_progress "Phase 1/8: System Updates & Base Packages..."
    log_info "Phase 1: Updating system and installing base packages"
    
    log_progress "Updating package lists..."
    DEBIAN_FRONTEND=noninteractive apt update
    
    log_progress "Upgrading installed packages (this may take a while)..."
    DEBIAN_FRONTEND=noninteractive apt upgrade -y
    
    log_progress "Installing base packages..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
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
    show_progress 2
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
    show_progress 3
    log_progress "Phase 3/8: Shell Environment (Zsh + Oh-My-Zsh + p10k)..."
    log_info "Phase 3: Setting up Zsh and Oh-My-Zsh for jamie"
    
    # Switch to jamie's home for installations
    export HOME=$USER_HOME
    cd $USER_HOME
    
    # Install Oh-My-Zsh
    if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
        log_progress "Installing Oh-My-Zsh..."
        sudo -u jamie sh -c "RUNZSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Install zsh-autosuggestions
    log_progress "Installing zsh-autosuggestions..."
    sudo -u jamie git clone https://github.com/zsh-users/zsh-autosuggestions ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true
    
    # Install zsh-syntax-highlighting
    log_progress "Installing zsh-syntax-highlighting..."
    sudo -u jamie git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true
    
    # Install Powerlevel10k theme
    log_progress "Installing Powerlevel10k theme..."
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
    show_progress 4
    log_progress "Phase 4/8: Tool Installation (repos, wordlists, scripts)..."
    log_info "Phase 4: Installing and configuring pentesting tools"
    
    # Create tool directory structure as jamie
    sudo -u jamie mkdir -p $USER_HOME/tools/{wordlists,scripts,exploits,repos}
    
    # Impacket - properly installed
    log_progress "Installing Impacket..."
    pip3 install impacket --break-system-packages || pip3 install impacket
    
    # Install pipx for isolated Python tool installations
    log_progress "Installing pipx for isolated Python environments..."
    DEBIAN_FRONTEND=noninteractive apt install -y pipx
    pipx ensurepath
    
    # Modern Python pentesting tools with pipx
    log_progress "Installing modern Python pentesting tools (this may take several minutes)..."
    
    # NetExec (modern CrackMapExec replacement)
    sudo -u jamie pipx install git+https://github.com/Pennyw0rth/NetExec || log_warn "NetExec failed to install"
    
    # Other essential Python tools with pip
    pip3 install --break-system-packages \
        bloodhound \
        bloodyAD \
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
        roadrecon \
        manspider \
        mitmproxy || true
    
    # Modern Go-based tools (ProjectDiscovery suite + essentials)
    log_progress "Installing modern Go-based tools (ProjectDiscovery suite)..."
    
    log_progress "Installing naabu (fast port scanner)..."
    go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest || true
    
    log_progress "Installing httpx (HTTP toolkit)..."
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest || true
    
    log_progress "Installing nuclei (vulnerability scanner)..."
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest || true
    
    log_progress "Installing subfinder (subdomain enumeration)..."
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest || true
    
    log_progress "Installing katana (web crawler)..."
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest || true
    
    log_progress "Installing dnsx (DNS toolkit)..."
    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest || true
    
    # Other essential Go tools
    log_progress "Installing ffuf (fast web fuzzer)..."
    go install -v github.com/ffuf/ffuf@latest || true
    
    log_progress "Installing gobuster (directory/DNS brute-forcer)..."
    go install -v github.com/OJ/gobuster/v3@latest || true
    
    # Kerbrute for Kerberos user enumeration (ADDED)
    log_progress "Installing kerbrute (Kerberos user enumeration)..."
    go install -v github.com/ropnop/kerbrute@latest || true
    
    # Add Go binaries to PATH
    echo 'export PATH=$PATH:/root/go/bin:$HOME/go/bin' >> /root/.bashrc
    echo 'export PATH=$PATH:$HOME/go/bin' >> $USER_HOME/.zshrc
    
    # Pivoting tools
    log_progress "Installing chisel (fast TCP/UDP tunnel)..."
    go install -v github.com/jpillora/chisel@latest || true
    
    # Try to install ligolo-ng (may fail, that's okay)
    log_progress "Attempting to install ligolo-ng (advanced pivoting)..."
    go install -v github.com/nicocha30/ligolo-ng/cmd/proxy@latest 2>/dev/null || log_warn "ligolo-ng failed (this is normal, continuing...)"
    go install -v github.com/nicocha30/ligolo-ng/cmd/agent@latest 2>/dev/null || log_warn "ligolo-ng agent failed (this is normal, continuing...)"
    
    # Fallback pivoting tool
    log_progress "Installing sshuttle (VPN over SSH)..."
    DEBIAN_FRONTEND=noninteractive apt install -y sshuttle || true
    
    # Install proxychains-ng (modern proxychains alternative) - ADDED
    log_progress "Installing proxychains-ng..."
    DEBIAN_FRONTEND=noninteractive apt install -y proxychains4 || true
    
    # Clone essential repos
    log_progress "Cloning essential pentesting repositories..."
    
    # PayloadsAllTheThings
    if [ ! -d "$USER_HOME/tools/repos/PayloadsAllTheThings" ]; then
        sudo -u jamie git clone https://github.com/swisskyrepo/PayloadsAllTheThings.git $USER_HOME/tools/repos/PayloadsAllTheThings
    fi
    
    # PEASS-ng (Linux/Windows privilege escalation)
    if [ ! -d "$USER_HOME/tools/repos/PEASS-ng" ]; then
        sudo -u jamie git clone https://github.com/peass-ng/PEASS-ng.git $USER_HOME/tools/repos/PEASS-ng
    fi
    
    # Windows-Exploit-Suggester
    if [ ! -d "$USER_HOME/tools/repos/Windows-Exploit-Suggester" ]; then
        sudo -u jamie git clone https://github.com/AonCyberLabs/Windows-Exploit-Suggester.git $USER_HOME/tools/repos/Windows-Exploit-Suggester
    fi
    
    # PowerSploit
    if [ ! -d "$USER_HOME/tools/repos/PowerSploit" ]; then
        sudo -u jamie git clone https://github.com/PowerShellMafia/PowerSploit.git $USER_HOME/tools/repos/PowerSploit
    fi
    
    # HackTricks (Carlos Polop's methodology)
    if [ ! -d "$USER_HOME/tools/repos/HackTricks" ]; then
        sudo -u jamie git clone https://github.com/HackTricks-wiki/HackTricks.git $USER_HOME/tools/repos/HackTricks
    fi
    
    # AutoRecon
    if [ ! -d "$USER_HOME/tools/repos/AutoRecon" ]; then
        sudo -u jamie git clone https://github.com/Tib3rius/AutoRecon.git $USER_HOME/tools/repos/AutoRecon
    fi
    
    # Impacket from source (for latest examples)
    if [ ! -d "$USER_HOME/tools/repos/impacket" ]; then
        sudo -u jamie git clone https://github.com/fortra/impacket.git $USER_HOME/tools/repos/impacket
    fi
    
    # GTFOBins (Unix privilege escalation)
    if [ ! -d "$USER_HOME/tools/repos/GTFOBins" ]; then
        sudo -u jamie git clone https://github.com/GTFOBins/GTFOBins.github.io.git $USER_HOME/tools/repos/GTFOBins
    fi
    
    # LOLBAS (Windows Living Off The Land)
    if [ ! -d "$USER_HOME/tools/repos/LOLBAS" ]; then
        sudo -u jamie git clone https://github.com/LOLBAS-Project/LOLBAS.git $USER_HOME/tools/repos/LOLBAS
    fi
    
    # Nuclei templates
    if [ ! -d "$USER_HOME/tools/repos/nuclei-templates" ]; then
        sudo -u jamie git clone https://github.com/projectdiscovery/nuclei-templates.git $USER_HOME/tools/repos/nuclei-templates
    fi
    
    # SecLists wordlists
    log_progress "Downloading SecLists (this is large, ~700MB)..."
    if [ ! -d "$USER_HOME/tools/wordlists/SecLists" ]; then
        sudo -u jamie git clone --depth 1 https://github.com/danielmiessler/SecLists.git $USER_HOME/tools/wordlists/SecLists
    fi
    
    # Extract rockyou.txt if compressed
    if [ -f "/usr/share/wordlists/rockyou.txt.gz" ] && [ ! -f "/usr/share/wordlists/rockyou.txt" ]; then
        log_progress "Extracting rockyou.txt..."
        gunzip /usr/share/wordlists/rockyou.txt.gz
    fi
    
    # Create symlinks for easy access
    log_progress "Creating convenient symlinks..."
    sudo -u jamie ln -sf $USER_HOME/tools/wordlists/SecLists $USER_HOME/SecLists 2>/dev/null || true
    sudo -u jamie ln -sf /usr/share/wordlists/rockyou.txt $USER_HOME/tools/wordlists/rockyou.txt 2>/dev/null || true
    sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh $USER_HOME/linpeas.sh 2>/dev/null || true
    sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe $USER_HOME/winpeas.exe 2>/dev/null || true
    
    log_info "Phase 4 complete"
    log_progress "Phase 4/8: ✓ Complete"
}

# ============================================
# PHASE 5: Dotfiles & Shell Configuration
# ============================================
phase5_dotfiles_setup() {
    show_progress 5
    log_progress "Phase 5/8: Dotfiles & Shell Configuration..."
    log_info "Phase 5: Configuring shell environment and dotfiles"
    
    # Configure .zshrc
    log_progress "Configuring .zshrc with custom aliases and functions..."
    cat > $USER_HOME/.zshrc << 'ZSH_EOF'
# Path to oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

# Powerlevel10k theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    docker
    sudo
    history
    command-not-found
)

source $ZSH/oh-my-zsh.sh

# Load p10k configuration
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Custom PATH
export PATH=$PATH:$HOME/go/bin:$HOME/.local/bin:/root/go/bin

# Environment variables
export EDITOR=vim
export VISUAL=vim
export GOPATH=$HOME/go

# Aliases - System
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias c='clear'
alias h='history'
alias please='sudo'

# Aliases - Pentesting
alias nmap-quick='nmap -sV -sC -O'
alias nmap-full='nmap -sV -sC -O -p-'
alias nmap-udp='nmap -sU -sV'
alias serve='python3 -m http.server'
alias serve80='sudo python3 -m http.server 80'
alias myip='curl -s ifconfig.me && echo'
alias ports='netstat -tulanp'
alias listening='lsof -i -P -n | grep LISTEN'

# Aliases - Tool shortcuts
alias nxc='netexec'  # Short form for NetExec
alias smb='netexec smb'
alias winrm='netexec winrm'
alias bloodhound='bloodhound-python'
alias peas='linpeas.sh'

# Aliases - Navigation
alias tools='cd ~/tools'
alias repos='cd ~/tools/repos'
alias wordlists='cd ~/tools/wordlists'
alias scripts='cd ~/tools/scripts'
alias engagements='cd ~/engagements'

# Functions
newengagement() {
    if [ -z "$1" ]; then
        echo "Usage: newengagement <name>"
        return 1
    fi
    mkdir -p ~/engagements/$1/{recon,scans,exploits,loot,notes,screenshots}
    cd ~/engagements/$1
    echo "# $1 Engagement" > notes/README.md
    echo "Created engagement: $1"
    ls -la
}

quickscan() {
    if [ -z "$1" ]; then
        echo "Usage: quickscan <target>"
        return 1
    fi
    nmap -sV -sC -oA quickscan_$(date +%Y%m%d_%H%M%S) $1
}

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

# reconchain: Quick recon workflow with ProjectDiscovery tools
reconchain() {
    if [ -z "$1" ]; then
        echo "Usage: reconchain <domain>"
        return 1
    fi
    echo "[+] Starting reconnaissance chain for: $1"
    echo "[*] Subfinder → DNSx → HTTPx → Nuclei"
    subfinder -d $1 -silent | dnsx -a -silent | httpx -tech-detect -silent | nuclei -severity critical,high
}
ZSH_EOF

    # Configure tmux
    log_progress "Configuring tmux..."
    cat > $USER_HOME/.tmux.conf << 'TMUX_EOF'
# Set prefix to Ctrl-a
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Enable mouse mode
set -g mouse on

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Status bar
set -g status-style 'bg=colour235 fg=colour137 dim'
set -g status-left ''
set -g status-right '#[fg=colour233,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S '
set -g status-right-length 50
set -g status-left-length 20

# Pane borders
set -g pane-border-style 'fg=colour238'
set -g pane-active-border-style 'fg=colour51'

# Messages
set -g message-style 'fg=colour232 bg=colour166 bold'
TMUX_EOF

    # Configure vim
    log_progress "Configuring vim..."
    cat > $USER_HOME/.vimrc << 'VIM_EOF'
" Basic settings
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch
set wildmenu
set wildmode=longest:full,full
set clipboard=unnamedplus

" Syntax highlighting
syntax on
filetype plugin indent on

" Color scheme
colorscheme desert
set background=dark

" Status line
set laststatus=2
set statusline=%F%m%r%h%w\ [%l,%c]\ [%L\ lines]

" Enable mouse
set mouse=a

" Leader key
let mapleader = ","

" Quick save
nnoremap <leader>w :w<CR>

" Quick quit
nnoremap <leader>q :q<CR>
VIM_EOF

    # Create CTF Tools Reference on Desktop
    log_info "Creating comprehensive tool reference guide"
    CREATION_DATE=$(date '+%Y-%m-%d %H:%M:%S %Z')
    
    cat > $USER_HOME/Desktop/CTF_TOOLS_REFERENCE.txt << TOOLS_EOF
═══════════════════════════════════════════════════════════════════════════
                    PARROT PENTESTING TOOLKIT REFERENCE
                          Modern 2025 Edition
═══════════════════════════════════════════════════════════════════════════

RECONNAISSANCE & ENUMERATION
═══════════════════════════════════════════════════════════════════════════

PORT SCANNING
nmap
  Network exploration and security auditing
  Quick: nmap -sV -sC <target>
  Full: nmap -sV -sC -O -p- <target>
  UDP: nmap -sU -sV <target>

naabu
  Fast port scanner (ProjectDiscovery)
  Usage: naabu -host <target> -p - -silent | nmap -sV -iL -
  Note: Much faster than nmap for initial discovery

SUBDOMAIN ENUMERATION
subfinder
  Fast passive subdomain discovery (ProjectDiscovery)
  Usage: subfinder -d <domain> -silent | tee subdomains.txt

dnsx
  DNS toolkit with bruteforcing (ProjectDiscovery)
  Usage: dnsx -l subdomains.txt -a -resp -silent

WEB ENUMERATION
httpx
  HTTP toolkit with tech detection (ProjectDiscovery)
  Usage: httpx -l targets.txt -tech-detect -status-code -title

katana
  Next-generation web crawler (ProjectDiscovery)
  Usage: katana -u <url> -d 3 -jc -kf all

nuclei
  Vulnerability scanner with templates (ProjectDiscovery)
  Usage: nuclei -l targets.txt -severity critical,high
  Update templates: nuclei -update-templates

ffuf
  Fast web fuzzer
  Usage: ffuf -u http://target/FUZZ -w wordlist.txt
  Dir: ffuf -u http://target/FUZZ -w /opt/SecLists/Discovery/Web-Content/raft-large-directories.txt

gobuster
  Directory/DNS/vhost brute-forcer
  Dir: gobuster dir -u <url> -w <wordlist>
  DNS: gobuster dns -d <domain> -w <wordlist>
  Vhost: gobuster vhost -u <url> -w <wordlist>

═══════════════════════════════════════════════════════════════════════════
WINDOWS / ACTIVE DIRECTORY
═══════════════════════════════════════════════════════════════════════════

CREDENTIAL ATTACKS
netexec (nxc)
  Modern CrackMapExec replacement - Swiss Army knife for AD
  SMB: nxc smb <target> -u <user> -p <pass>
  WinRM: nxc winrm <target> -u <user> -p <pass>
  Spray: nxc smb <targets> -u users.txt -p passwords.txt --continue-on-success
  Shares: nxc smb <target> -u <user> -p <pass> --shares
  SAM: nxc smb <target> -u <user> -p <pass> --sam
  LSA: nxc smb <target> -u <user> -p <pass> --lsa

kerbrute
  Kerberos user enumeration and password spraying
  User enum: kerbrute userenum -d <domain> --dc <dc-ip> users.txt
  Password spray: kerbrute passwordspray -d <domain> --dc <dc-ip> users.txt <password>

Impacket Suite
  All tools work WITHOUT 'impacket-' prefix!
  
  GetNPUsers.py
    AS-REP roasting - find users without Kerberos pre-auth
    Usage: GetNPUsers.py <domain>/ -dc-ip <dc-ip> -usersfile users.txt -format hashcat
  
  GetUserSPNs.py
    Kerberoasting - extract service ticket hashes
    Usage: GetUserSPNs.py <domain>/<user>:<pass> -dc-ip <dc-ip> -request
  
  secretsdump.py
    Dump credentials from various sources
    Usage: secretsdump.py <domain>/<user>:<pass>@<target>
    Local: secretsdump.py -sam SAM -system SYSTEM -security SECURITY LOCAL
  
  psexec.py / wmiexec.py / smbexec.py / dcomexec.py
    Remote command execution
    Usage: psexec.py <domain>/<user>:<pass>@<target>
  
  getTGT.py / getST.py
    Kerberos ticket manipulation
    Usage: getTGT.py <domain>/<user>:<pass>
  
  ticketer.py
    Forge Kerberos tickets (Golden/Silver ticket attacks)
    Usage: ticketer.py -nthash <hash> -domain-sid <sid> -domain <domain> <user>

ENUMERATION
bloodhound-python
  Active Directory relationship mapper
  Usage: bloodhound-python -u <user> -p <pass> -ns <dc-ip> -d <domain> -c all

bloodyAD
  Active Directory privilege escalation framework
  Usage: bloodyAD -u <user> -p <pass> -d <domain> --host <dc-ip> get object <object>

enum4linux-ng
  Modern SMB/AD enumeration
  Usage: enum4linux-ng <target> -A

ADDITIONAL TOOLS
certipy-ad
  Active Directory Certificate Services abuse
  Usage: certipy find -u <user>@<domain> -p <pass> -dc-ip <dc-ip>

coercer
  Force authentication from remote machines
  Usage: coercer -u <user> -p <pass> -d <domain> -t <target> -l <listener-ip>

pypykatz
  Mimikatz in Python - parse LSASS dumps
  Usage: pypykatz lsa minidump lsass.dmp

lsassy
  Remote LSASS credential dumper
  Usage: lsassy -u <user> -p <pass> -d <domain> <target>

responder
  LLMNR/NBT-NS/mDNS poisoner
  Usage: responder -I eth0 -wv

mitm6
  IPv6 man-in-the-middle for credential relay
  Usage: mitm6 -d <domain>

mitmproxy / mitmweb
  Interactive HTTPS proxy for web app testing
  Usage: mitmproxy (TUI) or mitmweb (Web UI on :8081)
  Note: More powerful than Burp for scripting/automation

═══════════════════════════════════════════════════════════════════════════
PIVOTING & TUNNELING
═══════════════════════════════════════════════════════════════════════════

chisel
  Fast TCP/UDP tunnel over HTTP
  Server: chisel server -p 8000 --reverse
  Client: chisel client <server>:8000 R:socks

ligolo-ng
  Advanced pivoting (may not be installed if build failed)
  Proxy: proxy -selfcert
  Agent: agent -connect <proxy-ip>:11601 -ignore-cert

sshuttle
  VPN over SSH - no hassle, works everywhere
  Usage: sshuttle -r user@<target> 10.0.0.0/8

ssh
  SSH tunneling for port forwarding
  Local forward: ssh -L 8080:localhost:80 user@<target>
  SOCKS proxy: ssh -D 1080 user@<target>
  Remote forward: ssh -R 8080:localhost:80 user@<target>

proxychains4
  Route traffic through SOCKS/HTTP proxies
  Usage: proxychains4 nmap <target>
  Config: /etc/proxychains4.conf
  MSF: set Proxies socks5:127.0.0.1:1080 (native, no proxychains needed)

═══════════════════════════════════════════════════════════════════════════
WEB APPLICATION TESTING
═══════════════════════════════════════════════════════════════════════════

git-dumper
  Dump exposed .git repositories
  Usage: git-dumper http://target/.git/ output_dir/

SQL INJECTION
sqlmap
  Automated SQL injection exploitation
  Usage: sqlmap -u <url> --batch --dump

REVERSE SHELLS
penelope
  Feature-rich reverse shell handler
  Usage: penelope 4444
  Note: Auto-upgrades shells, handles PTY, session management

═══════════════════════════════════════════════════════════════════════════
PRIVILEGE ESCALATION
═══════════════════════════════════════════════════════════════════════════

LINUX
linpeas.sh
  Automated Linux privilege escalation scanner
  Location: ~/linpeas.sh (symlink to ~/tools/repos/PEASS-ng/linPEAS/linpeas.sh)
  Usage: ./linpeas.sh | tee linpeas_output.txt
  With colors: ./linpeas.sh -a | tee linpeas_output.txt

WINDOWS
winpeas.exe
  Automated Windows privilege escalation scanner
  Location: ~/winpeas.exe (symlink to ~/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe)
  Transfer to target and run: winpeas.exe

Windows-Exploit-Suggester
  Finds missing patches on Windows systems
  Location: ~/tools/repos/Windows-Exploit-Suggester/
  Usage: python windows-exploit-suggester.py --update
         python windows-exploit-suggester.py --database <db> --systeminfo <file>

═══════════════════════════════════════════════════════════════════════════
REPOSITORIES & RESOURCES
═══════════════════════════════════════════════════════════════════════════

PayloadsAllTheThings/
  Swiss Army knife for pentesting
  Browse locally: ~/tools/repos/PayloadsAllTheThings/

PowerSploit/
  PowerShell post-exploitation framework
  Location: ~/tools/repos/PowerSploit/

HackTricks/
  Carlos Polop's methodology and technique documentation
  Browse locally or at: https://book.hacktricks.xyz

AutoRecon/
  Automated reconnaissance tool by Tib3rius
  Usage: python3 ~/tools/repos/AutoRecon/src/autorecon.py <target>

Impacket-Examples/
  Latest Impacket examples and tools from source
  Location: ~/tools/repos/impacket/examples/

GTFOBins/
  Unix binaries that can be used for privilege escalation
  Browse: ~/tools/repos/GTFOBins/_gtfobins/ directory

LOLBAS/
  Living Off The Land Binaries and Scripts for Windows
  Browse: ~/tools/repos/LOLBAS/yml/ directory for techniques

nuclei-templates/
  Official Nuclei vulnerability templates (auto-updated)
  Used automatically by nuclei command

═══════════════════════════════════════════════════════════════════════════
WORDLISTS
═══════════════════════════════════════════════════════════════════════════

SecLists/
  Comprehensive collection of security wordlists
  Location: ~/SecLists (symlink to ~/tools/wordlists/SecLists/)
  Popular lists:
    - Passwords: SecLists/Passwords/
    - Web Content: SecLists/Discovery/Web-Content/
    - Usernames: SecLists/Usernames/
    - Fuzzing: SecLists/Fuzzing/

rockyou.txt
  Classic password list (14M+ passwords)
  Location: ~/tools/wordlists/rockyou.txt (symlink to /usr/share/wordlists/rockyou.txt)

═══════════════════════════════════════════════════════════════════════════
MODERN WORKFLOW TIPS
═══════════════════════════════════════════════════════════════════════════

Initial Recon Chain:
  subfinder -d target.com -silent | dnsx -a -silent | httpx -tech-detect -silent | nuclei -severity critical,high

Port Scanning:
  naabu -host target.com -p - -silent | nmap -sV -iL -

Web Enumeration:
  httpx + katana + ffuf + nuclei combo is fastest

AD Enumeration:
  netexec for everything, then bloodhound for visualization

Pivoting Preference:
  1. ligolo-ng (if it compiled)
  2. chisel (reliable, fast)
  3. sshuttle (works everywhere, no hassle)

Password Attacks:
  netexec for spraying, then dump with secretsdump/lsassy

═══════════════════════════════════════════════════════════════════════════
TIPS & TRICKS
═══════════════════════════════════════════════════════════════════════════

• All Impacket tools work WITHOUT the 'impacket-' prefix
• Use 'nxc' as shorthand for 'netexec'
• Docker commands don't require sudo (jamie is in docker group)
• Tmux prefix is Ctrl-a (split with | and -)
• Alt+arrows to switch tmux panes without prefix
• Tab completion works for most commands and arguments
• Up arrow searches command history based on what you've typed
• Use 'extract' function for any compressed file
• Nuclei templates auto-update, or run: nuclei -update-templates
• ProjectDiscovery tools have built-in JSON output: add -j flag

═══════════════════════════════════════════════════════════════════════════
ENGAGEMENT WORKFLOW
═══════════════════════════════════════════════════════════════════════════

1. newengagement <target-name>
2. cd ~/engagements/<target-name>
3. Initial recon:
   - subfinder -d target.com -silent | tee recon/subdomains.txt
   - naabu -l recon/subdomains.txt -silent | tee recon/ports.txt
4. Web enumeration:
   - httpx -l recon/subdomains.txt -tech-detect | tee recon/web.txt
   - nuclei -l recon/web.txt -severity critical,high
5. Document findings in notes/
6. Store loot in loot/
7. Keep all output files in recon/scans/ for reference

═══════════════════════════════════════════════════════════════════════════

Tool Stack Version: 2.0 (Modern 2025 Edition)
Last updated: ${CREATION_DATE}

TOOLS_EOF

    # Fix ownership of all dotfiles
    chown -R jamie:jamie $USER_HOME
    
    log_info "Phase 5 complete"
    log_progress "Phase 5/8: ✓ Complete"
}

# ============================================
# PHASE 6: Automation & Maintenance Scripts
# ============================================
phase6_automation_setup() {
    show_progress 6
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
pip3 install --upgrade --break-system-packages impacket bloodhound bloodyAD mitm6 certipy-ad

echo "[+] Updating Go tools..."
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/ffuf/ffuf@latest
go install -v github.com/OJ/gobuster/v3@latest
go install -v github.com/jpillora/chisel@latest

echo "[+] Updating Nuclei templates..."
nuclei -update-templates

echo "[+] Updating repositories..."
cd ~/tools/repos
for dir in */; do
    echo "[+] Updating $dir"
    cd "$dir"
    git pull || true
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
# PHASE 7: Firefox Extensions for Web Enumeration
# ============================================
phase7_firefox_extensions() {
    show_progress 7
    log_progress "Phase 7/8: Firefox Extensions for CTF/Web Enumeration..."
    log_info "Phase 7: Installing Firefox extensions"
    
    # Find Firefox profile directory for jamie
    FIREFOX_PROFILE=$(find $USER_HOME/.mozilla/firefox -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
    
    if [ -z "$FIREFOX_PROFILE" ]; then
        log_warn "Firefox profile not found. Starting Firefox once to create profile..."
        # Start Firefox as jamie briefly to create profile
        sudo -u jamie timeout 5 firefox --headless 2>/dev/null || true
        sleep 2
        FIREFOX_PROFILE=$(find $USER_HOME/.mozilla/firefox -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
    fi
    
    if [ -n "$FIREFOX_PROFILE" ]; then
        log_info "Firefox profile found: $FIREFOX_PROFILE"
        
        # Create extensions directory
        sudo -u jamie mkdir -p "$FIREFOX_PROFILE/extensions"
        
        # Download and install extensions
        log_progress "Installing FoxyProxy Standard (proxy management)..."
        sudo -u jamie wget -q "https://addons.mozilla.org/firefox/downloads/latest/foxyproxy-standard/latest.xpi" \
            -O "$FIREFOX_PROFILE/extensions/foxyproxy@eric.h.jung.xpi" 2>/dev/null || log_warn "Failed to download FoxyProxy"
        
        log_progress "Installing Dark Reader (dark mode for all sites)..."
        sudo -u jamie wget -q "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi" \
            -O "$FIREFOX_PROFILE/extensions/addon@darkreader.org.xpi" 2>/dev/null || log_warn "Failed to download Dark Reader"
        
        log_progress "Installing Cookie-Editor (cookie management)..."
        sudo -u jamie wget -q "https://addons.mozilla.org/firefox/downloads/latest/cookie-editor/latest.xpi" \
            -O "$FIREFOX_PROFILE/extensions/{c5f15d22-8421-4a2f-9bed-e4e2c0b560e0}.xpi" 2>/dev/null || log_warn "Failed to download Cookie-Editor"
        
        log_progress "Installing Wappalyzer (technology detection)..."
        sudo -u jamie wget -q "https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/latest.xpi" \
            -O "$FIREFOX_PROFILE/extensions/wappalyzer@crunchlabs.com.xpi" 2>/dev/null || log_warn "Failed to download Wappalyzer"
        
        log_progress "Installing Hack-Tools (web pentest toolkit)..."
        sudo -u jamie wget -q "https://addons.mozilla.org/firefox/downloads/latest/hacktools/latest.xpi" \
            -O "$FIREFOX_PROFILE/extensions/{c5f15d22-8421-4a2f-9bed-hacktools}.xpi" 2>/dev/null || log_warn "Failed to download Hack-Tools"
        
        log_progress "Installing User-Agent Switcher (modify user agent)..."
        sudo -u jamie wget -q "https://addons.mozilla.org/firefox/downloads/latest/user-agent-string-switcher/latest.xpi" \
            -O "$FIREFOX_PROFILE/extensions/user-agent-switcher@ninetailed.ninja.xpi" 2>/dev/null || log_warn "Failed to download User-Agent Switcher"
        
        log_info "Firefox extensions installed. They will be available after Firefox restart."
        log_info "Installed extensions:"
        log_info "  - FoxyProxy Standard: Proxy management for Burp"
        log_info "  - Dark Reader: Dark mode for web enumeration"
        log_info "  - Cookie-Editor: Easy cookie editing"
        log_info "  - Wappalyzer: Detect technologies on websites"
        log_info "  - Hack-Tools: Reverse shells, payloads, etc."
        log_info "  - User-Agent Switcher: Change browser UA"
    else
        log_warn "Could not find or create Firefox profile. Extensions will need to be installed manually."
    fi
    
    log_info "Phase 7 complete"
    log_progress "Phase 7/8: ✓ Complete"
}

# ============================================
# PHASE 8: Post-Install Cleanup
# ============================================
phase8_cleanup() {
    show_progress 8
    log_progress "Phase 8/8: Post-Install Cleanup..."
    log_info "Phase 8: Cleaning up and finalizing"
    
    # Clean apt cache
    log_progress "Removing unnecessary packages..."
    DEBIAN_FRONTEND=noninteractive apt autoremove -y
    
    log_progress "Cleaning package cache..."
    DEBIAN_FRONTEND=noninteractive apt autoclean -y
    
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
║   Modern 2025 Edition                             ║
╚═══════════════════════════════════════════════════╝
EOF
    
    log_info "Starting installation..."
    log_info "This will take 10-20 minutes depending on your connection"
    sleep 2
    
    phase1_system_setup
    phase2_user_setup
    phase3_shell_setup
    phase4_tools_setup
    phase5_dotfiles_setup
    phase6_automation_setup
    phase7_firefox_extensions
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
  - reconchain <domain>   : Quick recon with ProjectDiscovery tools

Tool reference guide on Desktop: CTF_TOOLS_REFERENCE.txt

Happy hacking!
EOF
    
    log_warn "System will reboot in 10 seconds..."
    sleep 10
    reboot
}

# Run it
main
