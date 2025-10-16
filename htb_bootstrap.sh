#!/bin/bash

# HTB Pwnbox Enhancement Bootstrap Script
# Because life's too short for broken tooling

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1"; }

# ============================================
# PHASE 1: User Setup
# ============================================
phase1_user_setup() {
    log_info "Phase 1: Setting up user account"
    
    # Create jamie user as essentially root
    if ! id "jamie" &>/dev/null; then
        useradd -m -s /bin/zsh -u 1000 -G sudo jamie
        passwd -d jamie  # Remove password entirely
        
        # Give jamie full root privileges without password
        echo "jamie ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jamie
        chmod 440 /etc/sudoers.d/jamie
        
        log_info "User 'jamie' created with no password"
    else
        log_warn "User 'jamie' already exists, skipping creation"
    fi
    
    # Set up home directory
    export USER_HOME=/home/jamie
    
    log_info "Phase 1 complete"
}

# ============================================
# PHASE 2: System Updates & Base Packages
# ============================================
phase2_system_setup() {
    log_info "Phase 2: Updating system and installing base packages"
    
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
    
    # Enable docker without sudo
    usermod -aG docker jamie || true
    
    log_info "Phase 2 complete"
}

# ============================================
# PHASE 3: Shell Environment (Zsh + Oh-My-Zsh)
# ============================================
phase3_shell_setup() {
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
    
    # Set Zsh as default shell for jamie
    chsh -s $(which zsh) jamie || true
    
    log_info "Phase 3 complete"
}

# ============================================
# PHASE 4: Tool Installation & Optimization
# ============================================
phase4_tools_setup() {
    log_info "Phase 4: Installing and configuring pentesting tools"
    
    # Create tool directory structure as jamie
    sudo -u jamie mkdir -p $USER_HOME/tools/{wordlists,scripts,exploits,repos}
    
    # Impacket - properly installed
    log_info "Installing Impacket"
    pip3 install impacket --break-system-packages || pip3 install impacket
    
    # Other essential Python tools
    log_info "Installing Python pentesting tools"
    pip3 install --break-system-packages \
        crackmapexec \
        bloodhound \
        mitm6 \
        responder \
        certipy-ad \
        coercer \
        pypykatz \
        lsassy \
        enum4linux-ng \
        dnsrecon \
        git-dumper \
        penelope-shell || true
    
    # Install Rust tools
    log_info "Installing Rust-based tools"
    cargo install rustscan feroxbuster || true
    
    # Clone useful repos
    log_info "Cloning useful repositories"
    cd $USER_HOME/tools/repos
    
    sudo -u jamie bash << 'REPOS_EOF'
[ ! -d "PayloadsAllTheThings" ] && git clone https://github.com/swisskyrepo/PayloadsAllTheThings.git || true
[ ! -d "LinPEAS" ] && git clone https://github.com/carlospolop/PEASS-ng.git || true
[ ! -d "Windows-Exploit-Suggester" ] && git clone https://github.com/AonCyberLabs/Windows-Exploit-Suggester.git || true
[ ! -d "PowerSploit" ] && git clone https://github.com/PowerShellMafia/PowerSploit.git || true
REPOS_EOF
    
    # Download wordlists
    log_info "Setting up wordlists"
    cd $USER_HOME/tools/wordlists
    
    # SecLists if not already present
    if [ ! -d "SecLists" ]; then
        sudo -u jamie git clone https://github.com/danielmiessler/SecLists.git
    fi
    
    log_info "Phase 4 complete"
}

# ============================================
# PHASE 5: Dotfiles & Aliases Configuration
# ============================================
phase5_dotfiles_setup() {
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

# Network enumeration
alias nse='ls /usr/share/nmap/scripts | grep'
alias portscan='nmap -p- -T4 --min-rate=1000'
alias vulnscan='nmap -sV --script=vuln'

# Web enumeration
alias gobust='gobuster dir -w ~/tools/wordlists/SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt -u'
alias ferox='feroxbuster -w ~/tools/wordlists/SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt -u'

# Quick SMB enumeration
alias smbenum='enum4linux-ng -A'

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
}

# ============================================
# PHASE 6: Automation & Maintenance Scripts
# ============================================
phase6_automation_setup() {
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
}

# ============================================
# PHASE 7: Post-Install Cleanup
# ============================================
phase7_cleanup() {
    log_info "Phase 7: Cleaning up and finalizing"
    
    # Clean apt cache
    apt autoremove -y
    apt autoclean -y
    
    log_info "Phase 7 complete"
}

# ============================================
# Main Execution
# ============================================
main() {
    cat << "EOF"
╔═══════════════════════════════════════════════════╗
║   HTB Pwnbox Enhancement Bootstrap Script         ║
║   Because default configs are for cowards         ║
╚═══════════════════════════════════════════════════╝
EOF
    
    log_warn "This script will modify your system configuration"
    log_warn "Press Ctrl+C to cancel, or Enter to continue..."
    read
    
    phase1_user_setup
    phase2_system_setup
    phase3_shell_setup
    phase4_tools_setup
    phase5_dotfiles_setup
    phase6_automation_setup
    phase7_cleanup
    
    cat << EOF

╔═══════════════════════════════════════════════════╗
║              Installation Complete!               ║
╚═══════════════════════════════════════════════════╝

User 'jamie' created with full sudo privileges (no password required)
Default password: jamie (CHANGE THIS!)

Next steps:
1. Switch to jamie: su - jamie
2. Run 'p10k configure' to set up your prompt
3. Run '~/scripts/update-tools.sh' to update everything
4. Create an engagement: newengagement <name>

Useful commands:
  - newengagement <name>  : Create new engagement folder
  - quickscan <target>    : Quick nmap scan
  - serve                 : Start HTTP server on port 8000
  - update-tools.sh       : Update all tools

Have fun!
EOF
}

# Run it
main
