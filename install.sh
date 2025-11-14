#!/bin/bash
# ============================================
# PROJECT SHELLSHOCK v2.0
# Automated Pentesting Environment Bootstrap
# Debian/Ubuntu/Parrot Compatible
# Author: Jamie Loring
# Last updated: 2025-11-14 (Fix applied: 2025-11-14)
# ============================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Capture original user before sudo
ORIGINAL_USER="${SUDO_USER:-$USER}"
[[ "$ORIGINAL_USER" == "root" ]] && ORIGINAL_USER=""

# Logging functions
log_info() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1"; }
log_section() { echo -e "\n${CYAN}[*] $1${NC}"; }
log_skip() { echo -e "${BLUE}[~]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Log file
LOG_FILE="/var/log/shellshock-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Username validation
validate_username() {
    local username="$1"
    
    # Format check
    if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        log_error "Invalid username format. Must start with lowercase letter or underscore."
        return 1
    fi
    
    # Reserved system usernames
    local reserved=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" 
                    "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "nobody" "user")
    
    for reserved_name in "${reserved[@]}"; do
        if [[ "$username" == "$reserved_name" ]]; then
            log_error "Cannot use reserved system username: $username"
            return 1
        fi
    done
    
    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if package is installed
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Universal archive extractor
extract_archive() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "'$file' is not a valid file"
        return 1
    fi
    
    case "$file" in
        *.tar.bz2)   tar xjf "$file"     ;;
        *.tar.gz)    tar xzf "$file"     ;;
        *.tar.xz)    tar xJf "$file"     ;;
        *.bz2)       bunzip2 "$file"     ;;
        *.rar)       unrar e "$file"     ;;
        *.gz)        gunzip "$file"      ;;
        *.tar)       tar xf "$file"      ;;
        *.tbz2)      tar xjf "$file"     ;;
        *.tgz)       tar xzf "$file"     ;;
        *.zip)       unzip -q "$file"    ;;
        *.Z)         uncompress "$file"  ;;
        *.7z)        7z x "$file"        ;;
        *)
            log_error "'$file' cannot be extracted via extract_archive()"
            return 1
            ;;
    esac
    
    log_info "Extracted: $(basename $file)"
    return 0
}

# Safe download with retry
safe_download() {
    local url="$1"
    local output="$2"
    local name=$(basename "$output")
    
    if [[ -f "$output" ]]; then
        log_skip "$name already exists"
        return 0
    fi
    
    if wget --timeout=30 --tries=3 --no-verbose "$url" -O "$output" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "Downloaded: $name"
        return 0
    else
        log_warn "Failed to download: $name (non-critical)"
        return 1
    fi
}

# Safe git clone
safe_clone() {
    local url="$1"
    local dest="$2"
    local name=$(basename "$dest")
    
    if [[ -d "$dest/.git" ]]; then
        log_skip "$name already cloned"
        return 0
    fi
    
    if git clone --depth 1 "$url" "$dest" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "Cloned: $name"
        return 0
    else
        log_warn "Failed to clone: $name"
        return 1
    fi
}

# ============================================
# WELCOME BANNER
# ============================================
clear
echo -e "${CYAN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║   ███████╗██╗  ██╗███████╗██╗     ██╗     ███████╗██╗  ██╗   ║
║   ██╔════╝██║  ██║██╔════╝██║     ██║     ██╔════╝██║  ██║   ║
║   ███████╗███████║█████╗  ██║     ██║     ███████╗███████║   ║
║   ╚════██║██╔══██║██╔══╝  ██║     ██║     ╚════██║██╔══██║   ║
║   ███████║██║  ██║███████╗███████╗███████╗███████║██║  ██║   ║
║   ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝   ║
║                                                               ║
║             PROJECT SHELLSHOCK v2.0                           ║
║        Automated Pentesting Environment Bootstrap             ║
║             By Jamie Loring - Use Responsibly                 ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Username prompt
DEFAULT_USERNAME="$ORIGINAL_USER"
[[ -z "$DEFAULT_USERNAME" ]] && DEFAULT_USERNAME="pentester"

while true; do
    read -p "Enter pentesting username [default: $DEFAULT_USERNAME]: " USERNAME
    USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
    validate_username "$USERNAME" && break
    echo ""
done

export USERNAME
export USER_HOME="/home/$USERNAME"
mkdir -p "$USER_HOME"

log_info "Target username: ${GREEN}$USERNAME${NC}"
log_info "Home directory: ${GREEN}$USER_HOME${NC}"
echo ""
log_warn "This will install pentesting tools and configure the system."
log_warn "Smart detection enabled - existing installations will be skipped."
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_error "Installation cancelled"
    exit 1
fi

# ============================================
# PHASE 1: SYSTEM PREPARATION
# ============================================
log_section "Phase 1: System Preparation"

# Time sync with robust NTP (15 attempts)
log_info "Syncing system time..."
NTP_SERVERS=("pool.ntp.org" "time.nist.gov" "time.google.com" "time.cloudflare.com" "time.windows.com")
SYNC_SUCCESS=false

for attempt in {1..3}; do
    for ntp_server in "${NTP_SERVERS[@]}"; do
        if timeout 10 ntpdate -u "$ntp_server" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Time synced successfully via $ntp_server"
            SYNC_SUCCESS=true
            break 2
        fi
    done
done

if [[ "$SYNC_SUCCESS" == "false" ]]; then
    log_warn "All NTP sync attempts failed. Continuing anyway..."
fi

# Update package lists
log_info "Updating package lists..."
apt-get update -qq

# Upgrade system
log_info "Upgrading system packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# ============================================
# PHASE 2: CORE PACKAGES
# ============================================
log_section "Phase 2: Installing Core Packages"

CORE_PACKAGES=(
    # Essential
    "curl" "wget" "git" "vim" "nano" "unzip" "p7zip-full" "software-properties-common"
    "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
    
    # Shells
    "zsh" "tmux"
    
    # Build tools
    "build-essential" "gcc" "g++" "make" "cmake" "pkg-config"
    
    # Python
    "python3" "python3-pip" "python3-venv" "python3-dev" "pipx"
    
    # Ruby
    "ruby" "ruby-dev"
    
    # Network tools
    "nmap" "masscan" "netcat-traditional" "socat" "tcpdump" "wireshark" "tshark"
    "dnsutils" "whois" "host" "ldap-utils" "openssl"
    
    # Web tools
    "curl" "wget" "nikto" "dirb" "wfuzz" "sqlmap"
    
    # Other tools
    "john" "hashcat" "hydra" "nfs-common" "snmp" "ftp"
    "exploitdb" "metasploit-framework"
)

log_info "Installing core packages (this may take a while)..."
for package in "${CORE_PACKAGES[@]}"; do
    if package_installed "$package"; then
        log_skip "$package already installed"
    else
        if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Installed: $package"
        else
            log_warn "Failed to install: $package (non-critical)"
        fi
    fi
done

# Optional packages (may have dependency conflicts)
OPTIONAL_PACKAGES=("smbclient" "cifs-utils")
log_info "Installing optional packages..."
for package in "${OPTIONAL_PACKAGES[@]}"; do
    if package_installed "$package"; then
        log_skip "$package already installed"
    else
        # Try to install, but don't fail if it doesn't work
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package" 2>&1 | tee -a "$LOG_FILE" && \
            log_info "Installed: $package" || \
            log_warn "Could not install: $package (optional, skipping)"
    fi
done

# ============================================
# PHASE 3: USER ACCOUNT CONFIGURATION
# ============================================
log_section "Phase 3: User Account Configuration"

# Create user if doesn't exist
if id "$USERNAME" &>/dev/null; then
    log_skip "User $USERNAME already exists"
else
    log_info "Creating user: $USERNAME"
    
    # Ensure docker group exists
    if ! getent group docker > /dev/null; then
        groupadd docker
        log_info "Created docker group"
    fi
    
    # Create user with bash first (zsh may not be in PATH yet)
    useradd -m -s /bin/bash -G sudo,docker "$USERNAME"
    
    # Set password
    echo "$USERNAME:shellshock" | chpasswd
    log_info "User created with default password: shellshock"
    log_warn "IMPORTANT: Change password after first login!"
fi

# Add to groups if not already member
for group in sudo docker; do
    if ! id -nG "$USERNAME" | grep -qw "$group"; then
        usermod -aG "$group" "$USERNAME"
        log_info "Added $USERNAME to $group group"
    fi
done

# Passwordless sudo
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
if [[ ! -f "$SUDOERS_FILE" ]]; then
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    log_info "Configured passwordless sudo"
fi

# Disable built-in 'user' account if exists
if id "user" &>/dev/null && [[ "$USERNAME" != "user" ]]; then
    usermod -L user
    log_info "Disabled built-in 'user' account"
fi

# Create directory structure
log_info "Creating directory structure..."
mkdir -p "$USER_HOME"/{tools/{repos,scripts,windows},engagements,wordlists,.config}
chown -R "$USERNAME":"$USERNAME" "$USER_HOME"

# ============================================
# PHASE 4: GO INSTALLATION (THREE-LAYER PATH)
# ============================================
log_section "Phase 4: Installing Go with Proper PATH Configuration"

# Remove old Go if present
if [[ -d "/usr/local/go" ]]; then
    log_info "Removing old Go installation..."
    rm -rf /usr/local/go
fi

# Install latest stable Go
log_info "Installing Go 1.23.3..."
cd /tmp
wget -q https://go.dev/dl/go1.23.3.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.23.3.linux-amd64.tar.gz
rm go1.23.3.linux-amd64.tar.gz

# Layer 1: /etc/environment (system-wide)
log_info "Configuring Go PATH (system-wide)..."
if ! grep -q "/usr/local/go/bin" /etc/environment; then
    sed -i 's|PATH="\(.*\)"|PATH="/usr/local/go/bin:\1"|' /etc/environment
fi

# Layer 2: /etc/profile.d/golang.sh (all shells)
cat > /etc/profile.d/golang.sh << 'EOF'
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
EOF
chmod +x /etc/profile.d/golang.sh
log_info "Created /etc/profile.d/golang.sh"

# Layer 3: User shells
for shell_rc in "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"; do
    touch "$shell_rc"
    if ! grep -q "GOROOT" "$shell_rc"; then
        cat >> "$shell_rc" << 'EOF'

# Go configuration
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
EOF
        log_info "Added Go PATH to $(basename $shell_rc)"
    fi
done

# Source for immediate use
source /etc/profile.d/golang.sh
export PATH="/usr/local/go/bin:$USER_HOME/go/bin:$PATH"

# Verify Go installation
if /usr/local/go/bin/go version &>/dev/null; then
    log_info "✓ Go installed: $(/usr/local/go/bin/go version)"
else
    log_error "Go installation failed"
    exit 1
fi

# Create go directory
mkdir -p "$USER_HOME/go/bin"
chown -R "$USERNAME":"$USERNAME" "$USER_HOME/go"

# ============================================
# PHASE 5: OH-MY-ZSH INSTALLATION
# ============================================
log_section "Phase 5: Installing Oh-My-Zsh & Plugins"

# Set zsh as default shell
chsh -s /usr/bin/zsh "$USERNAME"
log_info "Set zsh as default shell for $USERNAME"

# Install Oh-My-Zsh
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    log_info "Installing Oh-My-Zsh..."
    su - "$USERNAME" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' 2>&1 | tee -a "$LOG_FILE"
    log_info "✓ Oh-My-Zsh installed"
else
    log_skip "Oh-My-Zsh already installed"
fi

# Install Powerlevel10k theme
if [[ ! -d "$USER_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
    log_info "Installing Powerlevel10k theme..."
    su - "$USERNAME" -c "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k"
    log_info "✓ Powerlevel10k installed"
fi

# Install zsh-autosuggestions
if [[ ! -d "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
    log_info "Installing zsh-autosuggestions..."
    su - "$USERNAME" -c "git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    log_info "✓ zsh-autosuggestions installed"
fi

# Install zsh-syntax-highlighting
if [[ ! -d "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
    log_info "Installing zsh-syntax-highlighting..."
    su - "$USERNAME" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    log_info "✓ zsh-syntax-highlighting installed"
fi

# Configure .zshrc
if [[ -f "$USER_HOME/.zshrc" ]]; then
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$USER_HOME/.zshrc"
    
    if grep -q "^plugins=" "$USER_HOME/.zshrc"; then
        sed -i 's/^plugins=.*/plugins=(git command-not-found zsh-autosuggestions zsh-syntax-highlighting)/' "$USER_HOME/.zshrc"
    else
        echo 'plugins=(git command-not-found zsh-autosuggestions zsh-syntax-highlighting)' >> "$USER_HOME/.zshrc"
    fi
    
    log_info "✓ Configured .zshrc"
fi

# ============================================
# PHASE 6: PYTHON TOOLS
# ============================================
log_section "Phase 6: Installing Python Tools"

# Ensure pipx in PATH
export PATH="$USER_HOME/.local/bin:$PATH"

# System-wide Python tools
PYTHON_TOOLS=(
    "impacket"
    "bloodhound"
    "bloodyAD"
    "mitm6"
)

log_info "Installing Python tools (system-wide)..."
for tool in "${PYTHON_TOOLS[@]}"; do
    # Check if tool is importable to determine if it's already installed
    if python3 -c "import $tool" 2>/dev/null; then
        log_skip "$tool already installed"
    else
        # Added || true to prevent script exit on non-critical pip install failures
        if pip3 install --break-system-packages "$tool" 2>&1 | tee -a "$LOG_FILE" || true; then
            log_info "Installed: $tool"
        else
            log_warn "Failed to install: $tool"
        endif
    fi
done

# NetExec - special case (git install)
log_info "Installing NetExec..."
if command_exists netexec || command_exists nxc; then
    log_skip "NetExec already installed"
else
    # Added || true to prevent script exit on non-critical pip install failures
    if pip3 install --break-system-packages git+https://github.com/Pennyw0rth/NetExec 2>&1 | tee -a "$LOG_FILE" || true; then
        log_info "✓ NetExec installed"
    else
        log_warn "Failed to install NetExec (non-critical)"
    fi
fi

# pipx-based tools (isolated)
log_info "Installing pipx tools..."
su - "$USERNAME" -c "pipx ensurepath"

PIPX_TOOLS=(
    "ldapdomaindump"
    "sprayhound"
    "certipy-ad"
)

for tool in "${PIPX_TOOLS[@]}"; do
    if su - "$USERNAME" -c "pipx list" | grep -q "$tool"; then
        log_skip "$tool already installed via pipx"
    else
        # Added || true to prevent script exit on non-critical pipx install failures
        if su - "$USERNAME" -c "pipx install $tool" 2>&1 | tee -a "$LOG_FILE" || true; then
            log_info "Installed via pipx: $tool"
        else
            log_warn "Failed to install via pipx: $tool"
        fi
    fi
done

# ============================================
# PHASE 7: RUBY TOOLS
# ============================================
log_section "Phase 7: Installing Ruby Tools"

RUBY_TOOLS=(
    "evil-winrm"
    "one_gadget"
    "haiti-hash"
)

for tool in "${RUBY_TOOLS[@]}"; do
    if gem list -i "$tool" &>/dev/null; then
        log_skip "$tool already installed"
    else
        # Added || true to prevent script exit on non-critical gem install failures
        if gem install "$tool" 2>&1 | tee -a "$LOG_FILE" || true; then
            log_info "Installed: $tool"
        else
            log_warn "Failed to install: $tool"
        fi
    fi
done

# ============================================
# PHASE 8: GO TOOLS (OFFICIAL SOURCES ONLY)
# ============================================
log_section "Phase 8: Installing Go Security Tools"

# Array of Go tools with full package paths
declare -A GO_TOOLS=(
    ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
    ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    ["dnsx"]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    ["nuclei"]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    ["ffuf"]="github.com/ffuf/ffuf/v2@latest"
    ["gobuster"]="github.com/OJ/gobuster/v3@latest"
    ["kerbrute"]="github.com/ropnop/kerbrute@latest"
    ["chisel"]="github.com/jpillora/chisel@latest"
    ["ligolo-ng"]="github.com/nicocha30/ligolo-ng/cmd/proxy@latest"
)

log_info "Installing Go tools (this may take a while)..."
for tool_name in "${!GO_TOOLS[@]}"; do
    tool_path="${GO_TOOLS[$tool_name]}"
    if [[ -f "$USER_HOME/go/bin/$tool_name" ]]; then
        log_skip "$tool_name already installed"
    else
        log_info "Installing $tool_name..."
        # Added || true to prevent script exit on non-critical Go install failures
        if su - "$USERNAME" -c "export PATH=/usr/local/go/bin:\$HOME/go/bin:\$PATH && go install -v $tool_path" 2>&1 | tee -a "$LOG_FILE" || true; then
            log_info "✓ $tool_name installed"
        else
            log_warn "Failed to install $tool_name"
        fi
    fi
done

# ============================================
# PHASE 9: GIT-BASED TOOLS (TOOL SWAPS)
# ============================================
log_section "Phase 9: Installing Git-Based Tools"

# Responder (git clone instead of pipx)
if [[ ! -d "$USER_HOME/tools/repos/Responder" ]]; then
    log_info "Installing Responder..."
    safe_clone "https://github.com/lgandx/Responder.git" "$USER_HOME/tools/repos/Responder"
else
    log_skip "Responder already installed"
fi

# enum4linux-ng (git clone instead of pipx)
if [[ ! -d "$USER_HOME/tools/repos/enum4linux-ng" ]]; then
    log_info "Installing enum4linux-ng..."
    safe_clone "https://github.com/cddmp/enum4linux-ng.git" "$USER_HOME/tools/repos/enum4linux-ng"
    # Added || true to prevent a non-critical pip install error from halting the script
    su - "$USERNAME" -c "cd $USER_HOME/tools/repos/enum4linux-ng && pip3 install -r requirements.txt --break-system-packages" 2>&1 | tee -a "$LOG_FILE" || true
else
    log_skip "enum4linux-ng already installed"
fi

# ============================================
# PHASE 10: ESSENTIAL REPOSITORIES
# ============================================
log_section "Phase 10: Cloning Essential Repositories"

REPOS=(
    "https://github.com/danielmiessler/SecLists.git|SecLists"
    "https://github.com/carlospolop/PEASS-ng.git|PEASS-ng"
    "https://github.com/brightio/penelope.git|penelope"
    "https://github.com/swisskyrepo/PayloadsAllTheThings.git|PayloadsAllTheThings"
)

for repo_entry in "${REPOS[@]}"; do
    IFS='|' read -r url name <<< "$repo_entry"
    safe_clone "$url" "$USER_HOME/tools/repos/$name"
done

# ============================================
# PHASE 11: WINDOWS BINARIES (FIX APPLIED)
# ============================================
log_section "Phase 11: Installing Windows Binaries"

mkdir -p "$USER_HOME/tools/windows"
cd "$USER_HOME/tools/windows"

# SharpHound
if [[ ! -f "SharpHound.exe" ]]; then
    log_info "Downloading SharpHound..."
    # FIX: Added || true to the pipeline to prevent grep failure (no match)
    # or curl failure (rate limit/network) from exiting the script due to pipefail.
    SHARPHOUND_URL=$(curl -s https://api.github.com/repos/BloodHoundAD/SharpHound/releases/latest | grep "browser_download_url.*SharpHound.*zip" | head -n 1 | cut -d '"' -f 4 || true)

    if [[ -n "$SHARPHOUND_URL" ]]; then
        if wget -q "$SHARPHOUND_URL" -O SharpHound.zip 2>&1 | tee -a "$LOG_FILE"; then
            extract_archive "SharpHound.zip" || unzip -q SharpHound.zip
            rm -f SharpHound.zip
            if [[ -f "SharpHound.exe" ]]; then
                log_info "✓ SharpHound.exe downloaded"
            else
                log_warn "SharpHound.exe not found after extraction"
            fi
        else
            log_warn "Failed to download SharpHound"
        fi
    else
        log_warn "Could not fetch SharpHound URL from GitHub API. Skipping SharpHound."
    fi
else
    log_skip "SharpHound.exe already present"
fi

# Seatbelt
if [[ ! -f "Seatbelt.exe" ]]; then
    log_info "Downloading Seatbelt..."
    wget -q https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Seatbelt.exe -O Seatbelt.exe 2>&1 || \
    log_warn "Could not fetch Seatbelt.exe"
    [[ -f "Seatbelt.exe" ]] && log_info "✓ Seatbelt.exe downloaded"
else
    log_skip "Seatbelt.exe already present"
fi

# Rubeus
if [[ ! -f "Rubeus.exe" ]]; then
    log_info "Downloading Rubeus..."
    wget -q https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Rubeus.exe -O Rubeus.exe 2>&1 || \
    log_warn "Could not fetch Rubeus.exe"
    [[ -f "Rubeus.exe" ]] && log_info "✓ Rubeus.exe downloaded"
else
    log_skip "Rubeus.exe already present"
fi

# PowerView
if [[ ! -f "PowerView.ps1" ]]; then
    log_info "Downloading PowerView..."
    wget -q https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Recon/PowerView.ps1 -O PowerView.ps1
    [[ -f "PowerView.ps1" ]] && log_info "✓ PowerView.ps1 downloaded"
else
    log_skip "PowerView.ps1 already present"
fi

# ============================================
# PHASE 12: WORDLISTS
# ============================================
log_section "Phase 12: Setting Up Wordlists"

# Symlink SecLists
if [[ ! -L "$USER_HOME/wordlists/SecLists" ]]; then
    ln -s "$USER_HOME/tools/repos/SecLists" "$USER_HOME/wordlists/SecLists"
    log_info "Symlinked SecLists to wordlists directory"
fi

# Extract rockyou.txt
if [[ -f "/usr/share/wordlists/rockyou.txt.gz" ]] && [[ ! -f "$USER_HOME/wordlists/rockyou.txt" ]]; then
    log_info "Extracting rockyou.txt..."
    gunzip -c /usr/share/wordlists/rockyou.txt.gz > "$USER_HOME/wordlists/rockyou.txt"
    log_info "✓ rockyou.txt extracted"
elif [[ -f "$USER_HOME/wordlists/rockyou.txt" ]]; then
    log_skip "rockyou.txt already present"
fi

# ============================================
# PHASE 13: SYMLINKS FOR QUICK ACCESS
# ============================================
log_section "Phase 13: Creating Symlinks for PEAS Tools"

mkdir -p "$USER_HOME/tools/scripts"

# linPEAS
if [[ -f "$USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh" ]]; then
    ln -sf "$USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh" "$USER_HOME/tools/scripts/linpeas.sh"
    log_info "✓ linpeas.sh symlinked"
else
    log_warn "linpeas.sh not found in PEASS-ng repo"
fi

# winPEAS (check multiple locations)
WINPEAS_FOUND=false
for winpeas_path in \
    "$USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe" \
    "$USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64_ofs.exe"; do
    
    if [[ -f "$winpeas_path" ]]; then
        ln -sf "$winpeas_path" "$USER_HOME/tools/scripts/winpeas.exe"
        log_info "✓ winpeas.exe symlinked"
        WINPEAS_FOUND=true
        break
    fi
done
[[ "$WINPEAS_FOUND" == false ]] && log_warn "winpeas.exe not found in PEASS-ng repo"

# Penelope
if [[ -f "$USER_HOME/tools/repos/penelope/penelope.py" ]]; then
    ln -sf "$USER_HOME/tools/repos/penelope/penelope.py" "$USER_HOME/tools/scripts/penelope.py"
    chmod +x "$USER_HOME/tools/repos/penelope/penelope.py"
    log_info "✓ penelope.py symlinked"
else
    log_warn "penelope.py not found"
fi

# ============================================
# PHASE 14: CUSTOM ENVIRONMENT FILE
# ============================================
log_section "Phase 14: Creating Custom Environment"

cat > "$USER_HOME/.shellshock_env" << 'EOFENV'
# ShellShock Environment Variables
# Automatically sourced by .bashrc and .zshrc

# Go configuration
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

# Tool shortcuts
alias responder='cd ~/tools/repos/Responder && python3 Responder.py'
alias enum4linux-ng='~/tools/repos/enum4linux-ng/enum4linux-ng.py'
alias penelope='~/tools/scripts/penelope.py'
alias linpeas='~/tools/scripts/linpeas.sh'

# Engagement workflow
export HTB_ENGAGEMENTS="$HOME/engagements"
alias htb-new='mkdir -p $HTB_ENGAGEMENTS/$1 && cd $HTB_ENGAGEMENTS/$1'

# Universal archive extractor
extract() {
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi
    
    case "$1" in
        *.tar.bz2)   tar xjf "$1"     ;;
        *.tar.gz)    tar xzf "$1"     ;;
        *.tar.xz)    tar xJf "$1"     ;;
        *.bz2)       bunzip2 "$1"     ;;
        *.rar)       unrar e "$1"     ;;
        *.gz)        gunzip "$1"      ;;
        *.tar)       tar xf "$1"      ;;
        *.tbz2)      tar xjf "$1"     ;;
        *.tgz)       tar xzf "$1"     ;;
        *.zip)       unzip -q "$1"    ;;
        *.Z)         uncompress "$1"  ;;
        *.7z)        7z x "$1"        ;;
        *)
            echo "Error: '$1' cannot be extracted via extract()"
            return 1
            ;;
    esac
    echo "Extracted: $1"
}

# Color aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'

EOFENV

# Add to shell configs
for shell_rc in "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"; do
    if [[ -f "$shell_rc" ]] && ! grep -q ".shellshock_env" "$shell_rc"; then
        cat >> "$shell_rc" << 'EOF'

# ShellShock environment
[[ -f ~/.shellshock_env ]] && source ~/.shellshock_env
EOF
        log_info "Added ShellShock env to $(basename $shell_rc)"
    fi
done

# ============================================
# PHASE 15: DOCUMENTATION
# ============================================
log_section "Phase 15: Generating Documentation"

cat > "$USER_HOME/TOOLS_REFERENCE.md" << 'EOFDOC'
# ShellShock v2.0 - Tools Reference

## Environment Variables
```bash
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
