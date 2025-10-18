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
# PHASE 1: System Updates & Base Packages
# ============================================
phase1_system_setup() {
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
}

# ============================================
# PHASE 2: User Setup
# ============================================
phase2_user_setup() {
    log_info "Phase 2: Setting up user account"
    
    if ! id "jamie" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo jamie
        passwd -d jamie
        echo "jamie ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jamie
        chmod 440 /etc/sudoers.d/jamie
        log_info "User 'jamie' created with no password"
    else
        log_warn "User 'jamie' already exists, skipping creation"
    fi
    
    usermod -aG docker jamie || true
    export USER_HOME=/home/jamie
    log_info "Phase 2 complete"
}

# ============================================
# PHASE 3: Shell Environment
# ============================================
phase3_shell_setup() {
    log_info "Phase 3: Setting up Zsh and Oh-My-Zsh for jamie"
    
    export HOME=$USER_HOME
    cd $USER_HOME
    
    if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
        sudo -u jamie sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    sudo -u jamie git clone https://github.com/zsh-users/zsh-autosuggestions ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true
    sudo -u jamie git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true
    sudo -u jamie git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${USER_HOME}/.oh-my-zsh/custom/themes/powerlevel10k 2>/dev/null || true
    
    chsh -s $(which zsh) jamie || true
    log_info "Phase 3 complete"
}

# ============================================
# PHASE 4: Tool Installation & Optimization
# ============================================
phase4_tools_setup() {
    log_info "Phase 4: Installing and configuring pentesting tools"
    
    sudo -u jamie mkdir -p $USER_HOME/tools/{wordlists,scripts,exploits,repos}
    
    log_info "Installing Impacket"
    pip3 install impacket --break-system-packages || pip3 install impacket
    
    log_info "Installing Python pentesting tools"
    pip3 install --break-system-packages \
        netexec bloodhound bloodyAD bloodhound-python mitm6 responder \
        certipy-ad coercer pypykatz lsassy enum4linux-ng dnsrecon \
        git-dumper penelope-shell kerbrute || true
    
    log_info "Installing Rust-based tools"
    cargo install rustscan feroxbuster || true
    
    log_info "Installing Go-based tools"
    go install github.com/nicocha30/ligolo-ng/cmd/proxy@latest || true
    go install github.com/nicocha30/ligolo-ng/cmd/agent@latest || true
    go install github.com/jpillora/chisel@latest || true
    
    cp ~/go/bin/* /usr/local/bin/ 2>/dev/null || true
    
    log_info "Cloning useful repositories"
    cd $USER_HOME/tools/repos
    declare -a repos=(
        "https://github.com/swisskyrepo/PayloadsAllTheThings.git"
        "https://github.com/carlospolop/PEASS-ng.git"
        "https://github.com/AonCyberLabs/Windows-Exploit-Suggester.git"
        "https://github.com/PowerShellMafia/PowerSploit.git"
    )
    for repo in "${repos[@]}"; do
        folder=$(basename "$repo" .git)
        if [ ! -d "$folder" ]; then
            sudo -u jamie git clone "$repo" || true
        fi
    done
    
    log_info "Setting up PEAS scripts quick access"
    sudo -u jamie mkdir -p $USER_HOME/peas
    if [ -d "$USER_HOME/tools/repos/PEASS-ng" ]; then
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh $USER_HOME/peas/linpeas.sh
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe $USER_HOME/peas/winpeas64.exe
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx86.exe $USER_HOME/peas/winpeas86.exe
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASany.exe $USER_HOME/peas/winpeas.exe
        sudo -u jamie ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEAS.bat $USER_HOME/peas/winpeas.bat
    fi
    
    log_info "Setting up wordlists"
    cd $USER_HOME/tools/wordlists
    if [ ! -d "SecLists" ]; then
        sudo -u jamie git clone https://github.com/danielmiessler/SecLists.git
    fi
    if [ -f "/usr/share/wordlists/rockyou.txt.gz" ] && [ ! -f "/usr/share/wordlists/rockyou.txt" ]; then
        gunzip /usr/share/wordlists/rockyou.txt.gz
    fi
    if [ -f "/usr/share/wordlists/rockyou.txt" ]; then
        sudo -u jamie ln -sf /usr/share/wordlists/rockyou.txt $USER_HOME/tools/wordlists/rockyou.txt || true
    fi
    
    log_info "Creating tool reference guide"
    cat > $USER_HOME/Desktop/CTF_TOOLS_REFERENCE.txt << 'TOOLS_EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                        CTF TOOLS QUICK REFERENCE                          ║
╚═══════════════════════════════════════════════════════════════════════════╝
...
(leave full text from your previous reference guide here)
...
TOOLS_EOF
    
    chown jamie:jamie $USER_HOME/Desktop/CTF_TOOLS_REFERENCE.txt
    log_info "Phase 4 complete"
}

# ============================================
# PHASE 5-8: Dotfiles, Automation, VirtualBox, Cleanup
# (Leave as-is from your previous script)
# ============================================

# For brevity, phases 5-8 can remain exactly as you already wrote, including .zshrc, .vimrc, tmux, update-tools.sh, backup script, VirtualBox additions, and cleanup.
# The main fix here is the repo cloning in Phase 4.

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
    
    phase1_system_setup
    phase2_user_setup
    phase3_shell_setup
    phase4_tools_setup
    phase5_dotfiles_setup
    phase6_automation_setup
    phase7_virtualbox_setup
    phase8_cleanup
    
    cat << EOF

╔═══════════════════════════════════════════════════╗
║              Installation Complete!               ║
╚═══════════════════════════════════════════════════╝

User 'jamie' created with full sudo privileges (no password required)

EOF
}

main "$@"
