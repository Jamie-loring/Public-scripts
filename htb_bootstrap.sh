#!/bin/bash

# Parrot Security VM Enhancement Bootstrap Script
# For fresh Parrot installs running as VM guest on Windows host
# Version 2.2 (Final - HTB/CTF Focused with Archive & Revert)

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
    echo -e "${BLUE}║${NC} Overall Progress: ${GREEN}${percent}%${NC} (Phase ${phase}/${total})                ${BLUE}║${NC}"
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
    
    # Create jamie user as essentially root
    if ! id "jamie" &>/dev/null; then
        # Use bash for initial setup compatibility, switch to zsh later
        useradd -m -s /bin/bash -G sudo jamie
        passwd -d jamie  # Remove password for auto-login
        chage -d 0 jamie # Force user to set a password on first shell login (mitigation)
        
        # Give jamie full root privileges without password (for convenience/autologin)
        echo "jamie ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jamie
        chmod 440 /etc/sudoers.d/jamie
        
        log_info "User 'jamie' created. Password disabled for auto-login, but password change required on first login."
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
    
    # Configure LightDM to auto-login as jamie
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
    log_progress "Installing NetExec (modern CrackMapExec replacement)..."
    sudo -u jamie pipx install git+https://github.com/Pennyw0rth/NetExec || log_warn "NetExec failed to install"
    
    # Core HTB/CTF tools (APT)
    log_progress "Installing core CTF/HTB utilities (nc, socat, forensics, stego)..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        netcat-openbsd socat rlwrap xfreerdp upx \
        aircrack-ng bluez bluelog hcitool \
        wpscan \
        steghide zsteg binwalk foremost exiftool p7zip-full || true
    
    # Other essential Python tools with pip
    log_progress "Installing essential Python pentesting tools..."
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
        mitmproxy \
        pwntools || true
    
    # High-priority gap tools (APT)
    log_progress "Installing high-priority APT tools..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        sqlmap hashcat john theharvester cewl proxychains4 gdb || true
    
    # Java deserialization (ysoserial)
    log_progress "Installing ysoserial (Java deserialization)..."
    if [ ! -f "$USER_HOME/tools/ysoserial.jar" ]; then
        DEBIAN_FRONTEND=noninteractive apt install -y default-jre || true
        sudo -u jamie wget -q https://github.com/frohoff/ysoserial/releases/latest/download/ysoserial-all.jar -O $USER_HOME/tools/ysoserial.jar 2>/dev/null || log_warn "Failed to download ysoserial"
        
        # Create wrapper script
        if [ -f "$USER_HOME/tools/ysoserial.jar" ]; then
            cat > /usr/local/bin/ysoserial << 'YSOSERIAL_EOF'
#!/bin/bash
java -jar ~/tools/ysoserial.jar "$@"
YSOSERIAL_EOF
            chmod +x /usr/local/bin/ysoserial
        fi
    fi
    
    # Install pwndbg (better GDB)
    if [ ! -d "$USER_HOME/tools/repos/pwndbg" ]; then
        log_progress "Installing pwndbg (enhanced GDB)..."
        sudo -u jamie git clone https://github.com/pwndbg/pwndbg $USER_HOME/tools/repos/pwndbg || true
        if [ -d "$USER_HOME/tools/repos/pwndbg" ]; then
            cd $USER_HOME/tools/repos/pwndbg
            sudo -u jamie ./setup.sh || log_warn "pwndbg setup failed (this is optional)"
            cd - > /dev/null
        fi
    fi
    
    # ROPgadget for binary exploitation
    log_progress "Installing ROPgadget..."
    pip3 install --break-system-packages ROPgadget || true
    
    # one_gadget for Pwn
    log_progress "Installing one_gadget (Ruby utility)..."
    DEBIAN_FRONTEND=noninteractive apt install -y ruby ruby-dev || true
    gem install one_gadget || log_warn "one_gadget installation via gem failed. You may need to run 'gem install one_gadget' as jamie later."
    
    # Modern Go-based tools (ProjectDiscovery suite + essentials)
    log_progress "Installing modern Go-based tools (ProjectDiscovery suite, ffuf, etc.)..."
    
    go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest || true
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest || true
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest || true
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest || true
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest || true
    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest || true
    go install -v github.com/ffuf/ffuf@latest || true
    go install -v github.com/OJ/gobuster/v3@latest || true
    go install -v github.com/ropnop/kerbrute@latest || true
    go install -v github.com/jpillora/chisel@latest || true
    
    # Ligolo/Git tools
    log_progress "Installing advanced tools (ligolo-ng, gitleaks, gitrob)..."
    go install -v github.com/nicocha30/ligolo-ng/cmd/proxy@latest 2>/dev/null || log_warn "ligolo-ng proxy failed (continuing...)"
    go install -v github.com/nicocha30/ligolo-ng/cmd/agent@latest 2>/dev/null || log_warn "ligolo-ng agent failed (continuing...)"
    go install -v github.com/gitleaks/gitleaks/v8@latest || true
    go install -v github.com/michenriksen/gitrob@latest || true
    pip3 install --break-system-packages truffleHog || true
    
    # Fallback pivoting tool
    log_progress "Installing sshuttle (VPN over SSH)..."
    DEBIAN_FRONTEND=noninteractive apt install -y sshuttle || true
    
    # Clone essential repos
    log_progress "Cloning essential pentesting repositories..."
    
    if [ ! -d "$USER_HOME/tools/repos/PayloadsAllTheThings" ]; then
        sudo -u jamie git clone https://github.com/swisskyrepo/PayloadsAllTheThings.git $USER_HOME/tools/repos/PayloadsAllTheThings
    fi
    if [ ! -d "$USER_HOME/tools/repos/PEASS-ng" ]; then
        sudo -u jamie git clone https://github.com/peass-ng/PEASS-ng.git $USER_HOME/tools/repos/PEASS-ng
    fi
    if [ ! -d "$USER_HOME/tools/repos/Windows-Exploit-Suggester" ]; then
        sudo -u jamie git clone https://github.com/AonCyberLabs/Windows-Exploit-Suggester.git $USER_HOME/tools/repos/Windows-Exploit-Suggester
    fi
    if [ ! -d "$USER_HOME/tools/repos/PowerSploit" ]; then
        sudo -u jamie git clone https://github.com/PowerShellMafia/PowerSploit.git $USER_HOME/tools/repos/PowerSploit
    fi
    if [ ! -d "$USER_HOME/tools/repos/HackTricks" ]; then
        sudo -u jamie git clone https://github.com/HackTricks-wiki/HackTricks.git $USER_HOME/tools/repos/HackTricks
    fi
    if [ ! -d "$USER_HOME/tools/repos/AutoRecon" ]; then
        sudo -u jamie git clone https://github.com/Tib3rius/AutoRecon.git $USER_HOME/tools/repos/AutoRecon
    fi
    if [ ! -d "$USER_HOME/tools/repos/impacket" ]; then
        sudo -u jamie git clone https://github.com/fortra/impacket.git $USER_HOME/tools/repos/impacket
    fi
    if [ ! -d "$USER_HOME/tools/repos/GTFOBins" ]; then
        sudo -u jamie git clone https://github.com/GTFOBins/GTFOBins.github.io.git $USER_HOME/tools/repos/GTFOBins
    fi
    if [ ! -d "$USER_HOME/tools/repos/LOLBAS" ]; then
        sudo -u jamie git clone https://github.com/LOLBAS-Project/LOLBAS.git $USER_HOME/tools/repos/LOLBAS
    fi
    if [ ! -d "$USER_HOME/tools/repos/nuclei-templates" ]; then
        sudo -u jamie git clone https://github.com/projectdiscovery/nuclei-templates.git $USER_HOME/tools/repos/nuclei-templates
    fi
    if [ ! -d "$USER_HOME/tools/repos/GitTools" ]; then
        sudo -u jamie git clone https://github.com/internetwache/GitTools.git $USER_HOME/tools/repos/GitTools
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

# Custom PATH - Includes Go and Ruby gem binaries
export PATH=$PATH:$HOME/go/bin:$HOME/.local/bin:$HOME/.gem/ruby/$(ls $HOME/.gem/ruby/)/bin

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
alias rl='rlwrap nc'  # netcat with history/line-editing

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
alias nxc='netexec'  # Short form for NetExec
alias smb='netexec smb'
alias winrm='netexec winrm'
alias bloodhound='bloodhound-python'
alias peas='linpeas.sh'
alias secrets='gitleaks detect --source'  # Quick secret scan
alias ysoserial='java -jar ~/tools/ysoserial.jar'  # Java deserialization
alias pwn='gdb -q'  # Quick GDB with pwndbg

# Aliases - Impacket Shortcuts (Installed via pip3 in Phase 4)
# Allows running tools without the .py extension.
alias secretsdump='secretsdump.py'
alias getnpusers='GetNPUsers.py'
alias getuserspns='GetUserSPNs.py'
alias psexec='psexec.py'
alias smbexec='smbexec.py'
alias wmiexec='wmiexec.py'
alias dcomexec='dcomexec.py'
alias ticketer='ticketer.py'
alias lookupsid='lookupsid.py'
alias atexec='atexec.py'

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
    nmap -sV -sC -O -oA quickscan_$(date +%Y%m%d_%H%M%S) $1
}

# Enhanced extract function to handle more compression types
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1         ;;
            *.tar.gz)    tar xzf $1         ;;
            *.bz2)       bunzip2 $1         ;;
            *.rar)       unrar e $1         ;;
            *.gz)        gunzip $1          ;;
            *.tar)       tar xf $1          ;;
            *.tbz2)      tar xjf $1         ;;
            *.tgz)       tar xzf $1         ;;
            *.zip)       unzip $1           ;;
            *.Z)         uncompress $1      ;;
            *.7z)        7z x $1            ;; # 7zip support
            *.deb)      dpkg-deb -x $1 $(mktemp -d) ;; # Debian package
            *.iso)      echo "Use: sudo mount -o loop $1 /mnt" ;; # ISO advice
            *)           echo "'$1' cannot be extracted via extract()" ;;
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

# gitanalyze: Complete Git repository disclosure workflow
gitanalyze() {
    if [ -z "$1" ]; then
        echo "Usage: gitanalyze <git-url>"
        echo "Example: gitanalyze http://target.com/.git/"
        return 1
    fi
    
    local url="$1"
    local output_dir="git-dump-$(date +%Y%m%d_%H%M%S)"
    
    echo "[+] Git Repository Analysis Workflow"
    echo "[*] Target: $url"
    echo ""
    
    # Step 1: Dump the repository
    echo "[1/4] Dumping .git repository..."
    git-dumper "$url" "$output_dir" || {
        echo "[-] git-dumper failed, trying GitTools..."
        bash ~/tools/repos/GitTools/Dumper/gitdumper.sh "$url" "$output_dir"
    }
    
    # Step 2: Extract all commits
    echo "[2/4] Extracting commits..."
    bash ~/tools/repos/GitTools/Extractor/extractor.sh "$output_dir" "${output_dir}-extracted"
    
    # Step 3: Scan for secrets with gitleaks
    echo "[3/4] Scanning for secrets with gitleaks..."
    gitleaks detect --source "$output_dir" --report-path "${output_dir}-gitleaks.json" --report-format json || true
    
    # Step 4: Scan with truffleHog
    echo "[4/4] Scanning with truffleHog..."
    trufflehog filesystem "$output_dir" --json > "${output_dir}-trufflehog.json" || true
    
    echo ""
    echo "[+] Analysis complete!"
    echo "    Repository: $output_dir"
    echo "    Extracted commits: ${output_dir}-extracted"
    echo "    Gitleaks report: ${output_dir}-gitleaks.json"
    echo "    TruffleHog report: ${output_dir}-trufflehog.json"
    echo ""
    echo "[!] Don't forget to check:"
    echo "    - docker-compose.yml"
    echo "    - .env files"
    echo "    - config/ directories"
    echo "    - Database connection strings"
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

Impacket Suite (Aliases installed: 'secretsdump', 'psexec', 'getnpusers', etc.)
  All tools work WITHOUT the 'impacket-' OR the '.py' suffix!
   
  getnpusers
    AS-REP roasting - find users without Kerberos pre-auth
    Usage: getnpusers <domain>/ -dc-ip <dc-ip> -usersfile users.txt -format hashcat
   
  getuserspns
    Kerberoasting - extract service ticket hashes
    Usage: getuserspns <domain>/<user>:<pass> -dc-ip <dc-ip> -request
   
  secretsdump
    Dump credentials from various sources
    Usage: secretsdump <domain>/<user>:<pass>@<target>
    Local: secretsdump -sam SAM -system SYSTEM -security SECURITY LOCAL
   
  psexec / wmiexec / smbexec / dcomexec
    Remote command execution
    Usage: psexec <domain>/<user>:<pass>@<target>
   
  ticketer
    Forge Kerberos tickets (Golden/Silver ticket attacks)
    Usage: ticketer -nthash <hash> -domain-sid <sid> -domain <domain> <user>

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

xfreerdp
  RDP client for connecting to Windows systems
  Usage: xfreerdp /v:<target-ip> /u:<user> /p:<pass>

═══════════════════════════════════════════════════════════════════════════
WEB APPLICATION TESTING
═══════════════════════════════════════════════════════════════════════════

git-dumper
  Dump exposed .git repositories
  Usage: git-dumper http://target/.git/ output_dir/

truffleHog
  Find secrets and credentials in git history
  Usage: trufflehog git file:///path/to/repo
  Remote: trufflehog git https://github.com/user/repo

gitleaks
  Fast secret detector for git repositories
  Usage: gitleaks detect --source /path/to/repo

wpscan
  WordPress vulnerability scanner
  Usage: wpscan --url http://target.com/ -e vp,vt,u --api-token <token>

SQL INJECTION
sqlmap
  Automated SQL injection exploitation
  Usage: sqlmap -u <url> --batch --dump

DESERIALIZATION ATTACKS
ysoserial
  Java deserialization payload generator
  Location: ~/tools/ysoserial.jar
  Usage: ysoserial <payload> <command>

REVERSE SHELLS
penelope
  Feature-rich reverse shell handler
  Usage: penelope 4444

rlwrap / socat / nc-openbsd
  Manual shell handling and connection tools
  rlwrap nc -lvnp 4444   # Netcat listener with history
  socat file:`tty`,raw,echo=0 tcp-listen:4445   # Powerful TTY listener

═══════════════════════════════════════════════════════════════════════════
PASSWORD CRACKING
═══════════════════════════════════════════════════════════════════════════

hashcat
  GPU-accelerated password cracking
  Usage: hashcat -m 1000 hashes.txt rockyou.txt

john
  CPU password cracking (John the Ripper)
  Usage: john --wordlist=rockyou.txt hashes.txt

CeWL
  Generate custom wordlists from websites
  Usage: cewl -d 2 -m 5 -w wordlist.txt <url>

═══════════════════════════════════════════════════════════════════════════
BINARY EXPLOITATION
═══════════════════════════════════════════════════════════════════════════

pwntools
  Python exploit development library
  Usage: from pwn import *

pwndbg
  Enhanced GDB with pwntools integration
  Usage: gdb ./binary

ROPgadget
  ROP chain builder
  Usage: ROPgadget --binary ./binary

one_gadget
  Find the "one gadget" RCE offsets in libc
  Usage: one_gadget /lib/x86_64-linux-gnu/libc.so.6

═══════════════════════════════════════════════════════════════════════════
CTF / FORENSICS / STEGANOGRAPHY
═══════════════════════════════════════════════════════════════════════════

binwalk
  Firmware/File analysis and extraction tool
  Usage: binwalk -e <file>   # Extract embedded files

exiftool
  Read and write meta information in files
  Usage: exiftool <file>

steghide
  Hide/extract data in JPEG/BMP/WAV/AU files
  Usage: steghide extract -sf <file>

zsteg
  Detect hidden data in PNG/BMP files
  Usage: zsteg -E <file>

foremost
  File carving tool (recover files from raw data)
  Usage: foremost -i <disk-image>

7z
  Universal archiver for less common formats
  Usage: 7z x archive.7z

═══════════════════════════════════════════════════════════════════════════
PRIVILEGE ESCALATION
═══════════════════════════════════════════════════════════════════════════

LINUX
linpeas.sh
  Automated Linux privilege escalation scanner
  Usage: ./linpeas.sh | tee linpeas_output.txt

WINDOWS
winpeas.exe
  Automated Windows privilege escalation scanner
  Transfer to target and run: winpeas.exe

═══════════════════════════════════════════════════════════════════════════
TIPS & TRICKS
═══════════════════════════════════════════════════════════════════════════

• All Impacket tools now work WITHOUT the '.py' suffix! (e.g., 'secretsdump')
• Use 'nxc' as shorthand for 'netexec'
• Use **'extract'** function for any compressed file (including 7z)
• Use **'rl'** for a reliable netcat listener with history (rlwrap nc)
• **REVERT_CTF_CHANGES.sh** on the Desktop archives engagements and resets the environment.

═══════════════════════════════════════════════════════════════════════════

Tool Stack Version: 2.2 (Final - HTB/CTF Focused with Archive & Revert)
Last updated: ${CREATION_DATE}

TOOLS_EOF

    # Create VirtualBox Guest Additions installation guide
    log_info "Creating VirtualBox Guest Additions installation guide"
    cat > $USER_HOME/Desktop/VIRTUALBOX_GUEST_ADDITIONS_INSTALL.txt << 'VBOX_EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║          Installing VirtualBox Guest Additions on Parrot OS               ║
║                    (Debian 12 "Bookworm"-based)                           ║
╚═══════════════════════════════════════════════════════════════════════════╝

This guide will help you install VirtualBox Guest Additions to enable:
  • Shared clipboard (copy/paste between host and VM)
  • Drag and drop files
  • Shared folders
  • Better screen resolution and scaling
  • Improved mouse integration

═══════════════════════════════════════════════════════════════════════════
STEP 1: Insert the Guest Additions ISO
═══════════════════════════════════════════════════════════════════════════

On your Windows host:
  1. Open VirtualBox Manager
  2. Select your Parrot VM → Settings → Storage
  3. Under the CD drive (IDE or SATA), click the disc icon
  4. Choose "Insert Guest Additions CD image..."
     OR manually select:
     C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso

═══════════════════════════════════════════════════════════════════════════
STEP 2: Mount the ISO in the Parrot guest
═══════════════════════════════════════════════════════════════════════════

Run these commands in your Parrot VM terminal:

sudo mkdir -p /mnt/cdrom
sudo mount /dev/cdrom /mnt/cdrom

Expected output:
  mount: /mnt/cdrom: WARNING: source write-protected, mounted read-only.

⚠️  This warning is NORMAL and OK to ignore — CD-ROMs are read-only by nature.

═══════════════════════════════════════════════════════════════════════════
STEP 3: Verify the ISO contents
═══════════════════════════════════════════════════════════════════════════

ls /mnt/cdrom

You should see files like:
  • VBoxLinuxAdditions.run
  • VBoxWindowsAdditions.exe
  • autorun.sh
  • AUTORUN.INF

═══════════════════════════════════════════════════════════════════════════
STEP 4: Install required build tools
═══════════════════════════════════════════════════════════════════════════

sudo apt update
sudo apt install -y build-essential dkms linux-headers-$(uname -r)

This installs:
  • build-essential: Compilers and build tools
  • dkms: Dynamic Kernel Module Support
  • linux-headers: Kernel headers for your current kernel

═══════════════════════════════════════════════════════════════════════════
STEP 5: Run the Guest Additions installer
═══════════════════════════════════════════════════════════════════════════

cd /mnt/cdrom
sudo sh ./VBoxLinuxAdditions.run

Expected output:
  Verifying archive integrity...  100%   MD5 checksums are OK. All good.
  Uncompressing VirtualBox X.X.X Guest Additions for Linux...
  VirtualBox Guest Additions: Starting.
  VirtualBox Guest Additions: Building the VirtualBox Guest Additions kernel
  modules.  This may take a while.
  VirtualBox Guest Additions: To build modules for other installed kernels, run
  VirtualBox Guest Additions:   /sbin/rcvboxadd quicksetup <version>
  VirtualBox Guest Additions: or
  VirtualBox Guest Additions:   /sbin/rcvboxadd quicksetup all
  VirtualBox Guest Additions: Building the modules for kernel X.X.X-X-amd64.
  VirtualBox Guest Additions: Running kernel modules will not be replaced until
  the system is restarted
  VirtualBox Guest Additions: kernel modules and services X.X.X loaded

⚠️  You may see repeated errors like:
  libkmod: ERROR ../libkmod/libkmod-config.c:772 conf_files_filter_out: 
  Directories inside directories are not supported: /etc/modprobe.d/virtualbox-dkms.conf

These errors are OK to ignore unless they interfere with system behavior.
They occur when there's a directory where a config file is expected.

═══════════════════════════════════════════════════════════════════════════
STEP 6: Reboot the VM
═══════════════════════════════════════════════════════════════════════════

sudo reboot

After reboot, Guest Additions should be active and you'll have:
  ✓ Shared clipboard
  ✓ Drag and drop
  ✓ Better resolution scaling
  ✓ Seamless mouse integration

═══════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════

If clipboard sharing doesn't work after reboot:
  1. Verify Guest Additions are running:
     lsmod | grep vbox

     You should see modules like:
       vboxguest
       vboxsf
       vboxvideo

  2. Check VirtualBox settings:
     VM Settings → General → Advanced
     - Shared Clipboard: Bidirectional
     - Drag'n'Drop: Bidirectional

  3. Restart the VBoxClient services:
     killall VBoxClient
     VBoxClient --clipboard &
     VBoxClient --draganddrop &
     VBoxClient --seamless &

If kernel modules fail to build:
  • Ensure you have the correct kernel headers:
    sudo apt install linux-headers-$(uname -r)
  
  • Try rebuilding:
    sudo /sbin/rcvboxadd setup

If screen resolution is wrong:
  • Right-click desktop → Display Settings
  • Or use VirtualBox: View → Auto-resize Guest Display

═══════════════════════════════════════════════════════════════════════════
SETTING UP SHARED FOLDERS (Optional)
═══════════════════════════════════════════════════════════════════════════

1. On Windows host:
   VM Settings → Shared Folders → Add new shared folder
   Folder Path: C:\Users\YourName\Desktop (or wherever)
   Folder Name: shared (or any name you want)
   ☑ Auto-mount
   ☑ Make Permanent

2. In Parrot VM, add your user to vboxsf group:
   sudo usermod -aG vboxsf jamie
   
3. Reboot or log out/in

4. Access shared folder at:
   /media/sf_shared (or whatever name you chose)

═══════════════════════════════════════════════════════════════════════════
QUICK REFERENCE COMMANDS
═══════════════════════════════════════════════════════════════════════════

Mount CD:
  sudo mount /dev/cdrom /mnt/cdrom

Install:
  cd /mnt/cdrom && sudo sh ./VBoxLinuxAdditions.run

Check if running:
  lsmod | grep vbox

Restart services:
  killall VBoxClient && VBoxClient --clipboard &

Rebuild modules:
  sudo /sbin/rcvboxadd setup

═══════════════════════════════════════════════════════════════════════════
VBOX_EOF

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
pip3 install --upgrade --break-system-packages impacket bloodhound bloodyAD mitm6 certipy-ad truffleHog pwntools ROPgadget

echo "[+] Updating system packages (sqlmap, hashcat, john, etc.)..."
sudo apt update
sudo apt upgrade -y sqlmap hashcat john theharvester cewl gdb wpscan steghide zsteg binwalk foremost exiftool p7zip-full

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
go install -v github.com/gitleaks/gitleaks/v8@latest
go install -v github.com/michenriksen/gitrob@latest
go install -v github.com/ropnop/kerbrute@latest

echo "[+] Updating Ruby tools (one_gadget)..."
gem update one_gadget || true

echo "[+] Updating Nuclei templates..."
nuclei -update-templates

echo "[+] Updating ysoserial..."
wget -q https://github.com/frohoff/ysoserial/releases/latest/download/ysoserial-all.jar -O ~/tools/ysoserial.jar 2>/dev/null || echo "[-] Failed to update ysoserial"

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

echo "[+] Updating pwndbg..."
if [ -d ~/tools/repos/pwndbg ]; then
    cd ~/tools/repos/pwndbg
    git pull
    cd -
fi

echo "[+] All tools updated!"
EOF
    
    chmod +x $USER_HOME/scripts/update-tools.sh
    
    # --- NEW REVERT & ARCHIVE SCRIPT ---
    log_progress "Creating CTF environment revert and archive script..."
    cat > $USER_HOME/scripts/revert-ctf-changes.sh << 'REVERT_EOF'
#!/bin/bash
# CTF Environment Revert & Archive Script
# Archives engagement data and cleans up common artifacts left over from HTB/CTF engagements.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_revert_info() { 
    echo -e "${GREEN}[*]${NC} $1"
}
log_revert_warn() { 
    echo -e "${YELLOW}[!]${NC} $1"
}

# 1. Reset Host & DNS Files
reset_network_config() {
    log_revert_info "1. Resetting /etc/hosts, /etc/resolv.conf, and Kerberos config..."
    
    # a) Reset /etc/hosts to default loopback entries
    if [ -w /etc/hosts ]; then
        echo -e "127.0.0.1\tlocalhost\n127.0.1.1\tparrot" | sudo tee /etc/hosts > /dev/null
        log_revert_info " -> /etc/hosts reverted."
    else
        log_revert_warn " -> Cannot write to /etc/hosts. Skipping."
    fi
    
    # b) Reset /etc/resolv.conf to standard Google/Cloudflare DNS
    if [ -w /etc/resolv.conf ]; then
        echo -e "nameserver 127.0.0.1\nnameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee /etc/resolv.conf > /dev/null
        log_revert_info " -> /etc/resolv.conf reset."
    else
        log_revert_warn " -> Cannot write to /etc/resolv.conf. Skipping."
    fi
    
    # c) Clear Kerberos configuration
    if [ -f /etc/krb5.conf.default ]; then
        sudo cp /etc/krb5.conf.default /etc/krb5.conf
        log_revert_info " -> /etc/krb5.conf reverted."
    else
        log_revert_warn " -> Default Kerberos config not found. Skipping /etc/krb5.conf."
    fi
}

# 2. Clear Residual Credentials and Tickets
clear_credentials() {
    log_revert_info "2. Clearing residual session data..."
    
    # a) Clear Kerberos ticket cache
    if klist &>/dev/null; then
        kdestroy -A 2>/dev/null
        log_revert_info " -> Kerberos tickets destroyed."
    fi
    
    # b) Clear user-specific temp folders where tokens might be stored
    find $HOME/ -type f -name "*.token" -delete 2>/dev/null
    log_revert_info " -> Temporary token files deleted from home directory."
    
    # c) Clear ssh-agent identities
    if ssh-add -l &>/dev/null; then
        ssh-add -D 2>/dev/null
        log_revert_info " -> SSH identities cleared from ssh-agent."
    fi
}

# 3. Archive engagement-specific data and clean up workspace
cleanup_workspace() {
    log_revert_info "3. Archiving engagement data and cleaning workspace..."
    
    local ENGAGEMENTS_DIR="$HOME/engagements"
    local BACKUP_DIR="$HOME/backups"
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local ARCHIVE_NAME="engagement_archive_${TIMESTAMP}.tar.gz"

    mkdir -p $BACKUP_DIR
    
    # a) Archive and move engagements directory
    if [ -d "$ENGAGEMENTS_DIR" ] && [ "$(ls -A $ENGAGEMENTS_DIR)" ]; then
        echo ""
        log_revert_warn "!!! WARNING: About to zip and move the contents of $ENGAGEMENTS_DIR"
        read -r -p "Do you want to archive and clear the engagement data? (yes/no): " confirmation
        if [[ "$confirmation" =~ ^(yes|y)$ ]]; then
            # Create archive
            tar -czf $BACKUP_DIR/$ARCHIVE_NAME -C $ENGAGEMENTS_DIR .
            log_revert_info " -> Engagements successfully archived to $BACKUP_DIR/$ARCHIVE_NAME"
            
            # Clear the live engagements directory
            rm -rf $ENGAGEMENTS_DIR/*
            log_revert_info " -> $ENGAGEMENTS_DIR cleared for the next CTF."
        else
            log_revert_warn " -> Engagement data preserved. $ENGAGEMENTS_DIR NOT cleared."
        fi
    else
        log_revert_info " -> $ENGAGEMENTS_DIR is empty or not found. Skipping archive."
    fi
    
    # b) Clear common temporary directories
    log_revert_info " -> Clearing common temporary directories (e.g., /tmp, /dev/shm)..."
    sudo rm -rf /tmp/* /dev/shm/* $HOME/.cache/* 2>/dev/null || true
}

# 4. Final System Polish
final_polish() {
    log_revert_info "4. Final System Polish..."
    
    # Clear Zsh history
    history -c
    history -w
    log_revert_info " -> Shell history cleared for current session."
    
    log_revert_info "Script finished! A reboot is recommended for a clean state."
}

# --- Main Execution ---
echo -e "${RED}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║               CTF ENVIRONMENT REVERT & ARCHIVE        ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════╝${NC}"
log_revert_warn "This script requires 'sudo' privileges for network changes."
read -r -p "Press Enter to begin the revert process (Ctrl+C to cancel)..."

reset_network_config
clear_credentials
cleanup_workspace
final_polish

REVERT_EOF
    
    chmod +x $USER_HOME/scripts/revert-ctf-changes.sh
    sudo -u jamie ln -sf $USER_HOME/scripts/revert-ctf-changes.sh $USER_HOME/Desktop/REVERT_CTF_CHANGES.sh 2>/dev/null || true
    log_info "Revert/Archive script created: ~/scripts/revert-ctf-changes.sh"
    log_info "Desktop symlink created: ~/Desktop/REVERT_CTF_CHANGES.sh"

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
    chown jamie:jamie $USER_HOME/Desktop/REVERT_CTF_CHANGES.sh
    
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
        log_info "  - FoxyProxy Standard: Proxy management for Burp"
        log_info "  - Dark Reader: Dark mode for web enumeration"
        log_info "  - Cookie-Editor: Easy cookie editing"
        log_info "  - Wappalyzer: Detect technologies on websites"
        log_info "  - Hack-Tools: Reverse shells, payloads, etc."
        log_info "  - User-Agent Switcher: Change browser UA"
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
║   Parrot Security VM Enhancement Script           ║
║   Fresh install → Fully loaded pentesting box    ║
║   Modern 2025 Edition (Fixed)                     ║
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
║              Installation Complete!               ║
╚═══════════════════════════════════════════════════╝

User 'jamie' created with full sudo privileges (no password required)

Next steps:
1. REBOOT the VM: sudo reboot
2. Log in as 'jamie' (auto-login configured)
3. Powerlevel10k theme is pre-configured (no wizard needed!)
4. Run '~/scripts/update-tools.sh' to update everything
5. Create an engagement: newengagement <name>

Useful commands:
  - newengagement <name>     : Create new engagement folder
  - quickscan <target>       : Quick nmap scan
  - serve                   : Start HTTP server on port 8000
  - update-tools.sh         : Update all tools
  - reconchain <domain>     : Quick recon with ProjectDiscovery tools
  - gitanalyze <url>        : Complete Git repository analysis
  - extract <file>          : Universal archive extraction (Fixed!)
  - **REVERT_CTF_CHANGES.sh**: Archives engagement data and resets host files.

Tool reference guide on Desktop: CTF_TOOLS_REFERENCE.txt
VirtualBox setup guide on Desktop: VIRTUALBOX_GUEST_ADDITIONS_INSTALL.txt

Happy hacking!
EOF
    
    log_warn "System will reboot in 10 seconds (Hit Ctrl+C to cancel)..."
    sleep 10
    reboot
}

# Run it
main
