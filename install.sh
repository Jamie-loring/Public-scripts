#!/bin/bash
# ============================================
# PROJECT SHELLSHOCK v1.01
# Automated Pentesting Environment Bootstrap
# Debian/Ubuntu/Parrot Compatible
# Author: Jamie Loring
# ============================================
# DISCLAIMER: This tool is for authorized testing only.
# Request permission before use. Stay legal.
# Last updated: 2025-11-13
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

# Logging functions
log_info() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1" >&2; }
log_progress() { echo -e "${BLUE}[*]${NC} $1"; }
log_skip() { echo -e "${MAGENTA}[SKIP]${NC} $1"; }

# Capture original user (before sudo)
ORIGINAL_USER="${SUDO_USER:-$USER}"
[[ "$ORIGINAL_USER" == "root" ]] && ORIGINAL_USER=""

# Username validation function
validate_username() {
    local username="$1"

    # Check format: lowercase alphanumeric, underscore, hyphen; 1-32 chars
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        log_error "Invalid username format. Must start with lowercase letter or underscore, and be alphanumeric (max 32 chars)."
        return 1
    fi

    # Reserved system usernames
    local reserved=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail"
                    "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "nobody")

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
    dpkg-query -W --showformat='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Safe download with retry and verification
safe_download() {
    local url="$1"
    local output="$2"
    local name=$(basename "$output")

    if [[ -f "$output" ]]; then
        log_skip "$name already exists"
        return 0
    fi

    if curl -fsSLk --retry 3 --max-time 30 "$url" -o "$output" 2>&1 | tee -a /var/log/shellshock-install.log; then
        log_info "Downloaded: $name"
        return 0
    else
        log_warn "Failed to download: $name (non-critical)"
        return 1
    fi
}

# Safe git clone with depth limit
safe_clone() {
    local url="$1"
    local dest="$2"
    local name=$(basename "$dest")

    # Set temporary Git config for SSL bypass during clone/pull
    git config --global http.sslVerify false

    if [[ -d "$dest/.git" ]]; then
        log_skip "$name already cloned. Attempting update..."
        if git -C "$dest" pull --depth 1 2>&1 | tee -a /var/log/shellshock-install.log; then
            log_info "Updated: $name"
        else
            log_warn "Failed to update: $name"
        fi
        return 0
    fi

    if git clone --depth 1 --single-branch "$url" "$dest" 2>&1 | tee -a /var/log/shellshock-install.log; then
        log_info "Cloned: $name (Shallow, SSL ignored)"
        return 0
    else
        log_warn "Failed to clone: $name"
        return 1
    fi
}

# Welcome banner
clear
echo -e "${CYAN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║     ██████╗████████╗███████╗    ██████╗  ██████╗ ██╗  ██╗     ║
║    ██╔════╝╚══██╔══╝██╔════╝    ██╔══██╗██╔═══██╗╚██╗██╔╝     ║
║    ██║      ██║  █████╗      ██████╔╝██║  ██║ ╚███╔╝      ║
║    ██║      ██║  ██╔══╝      ██╔══██╗██║  ██║ ██╔██╗      ║
║    ╚██████╗  ██║  ██║        ██████╔╝╚██████╔╝██╔╝ ██╗     ║
║     ╚═════╝  ╚═╝  ╚═╝        ╚═════╝  ╚═════╝ ╚═╝  ╚═╝     ║
║                                                             ║
║              Project ShellShock 1.01                        ║
║              A love letter to Pentesting by Jamie Loring    ║
║                                                             ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Username prompt
DEFAULT_USERNAME="$ORIGINAL_USER"
[[ -z "$DEFAULT_USERNAME" ]] && DEFAULT_USERNAME="pentester"

USERNAME=""
while true; do
    read -rp "Enter pentesting username [default: $DEFAULT_USERNAME]: " INPUT_USERNAME
    USERNAME="${INPUT_USERNAME:-$DEFAULT_USERNAME}"
    validate_username "$USERNAME" && break
    echo ""
done

export USERNAME
export USER_HOME="/home/$USERNAME"

# Check if running as root before proceeding
if [[ "$(id -u)" -ne 0 ]]; then
    log_error "This script must be run as root or via sudo."
    exit 1
fi
mkdir -p "$USER_HOME"

log_info "Target username: ${GREEN}$USERNAME${NC}"
log_info "Home directory: ${GREEN}$USER_HOME${NC}"
echo ""
log_warn "This will install pentesting tools and configure the system."
log_warn "Smart detection enabled - existing installations will be skipped."
log_warn "ATTENTION: HTTPS certificate verification is TEMPORARILY DISABLED for apt and git."
echo ""
read -rp "Continue? (y/n): " confirm
[[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]] && exit 0

# Initialize log file
touch /var/log/shellshock-install.log
chmod 644 /var/log/shellshock-install.log

# ============================================
# TIME SYNCHRONIZATION (CRITICAL - BEFORE APT)
# ============================================
log_progress "Forcing immediate time synchronization (Google NTP)..."
log_warn "Clock skew can cause APT repository signature failures"

# Display current time before sync
log_info "Current system time: $(date)"

# Function to attempt time sync
attempt_sync() {
    local server="$1"
    log_info "Attempting ntpdate sync with: $server..."
    # The '|| true' ensures the script doesn't exit on sync failure (set -e)
    if ntpdate -u "$server" 2>&1 | tee -a /var/log/shellshock-install.log; then
        log_info "Time synced successfully via $server"
        return 0
    else
        log_warn "ntpdate sync failed using $server."
        return 1
    fi # <-- FIX: Correctly closing the inner if block
} # <-- Correctly closing the function block

# 1. Check if ntpdate is already installed and try to sync
if command_exists ntpdate; then
    attempt_sync "time.google.com" || attempt_sync "pool.ntp.org" || log_warn "All ntpdate sync attempts failed."
else
    # 2. ntpdate not found, attempt to install it quickly
    log_warn "ntpdate not found, attempting to install it now..."
    # Install without updating repos (to avoid skew-related apt failures)
    if apt install -y ntpdate 2>&1 | tee -a /var/log/shellshock-install.log; then
        log_info "Installed ntpdate."
        # Now that it's installed, try to sync
        attempt_sync "time.google.com" || attempt_sync "pool.ntp.org" || log_warn "Sync failed even after ntpdate installation."
    else
        log_warn "Could not install ntpdate without updating - will rely on chrony later."
    fi
fi

# Show updated time
log_info "Updated system time: $(date)"
echo ""

# ============================================
# SSL BYPASS CONFIGURATION
# ============================================
log_progress "Configuring APT and Git to bypass SSL verification..."

# APT SSL Bypass
echo 'Acquire { https::Verify-Peer "false"; }' | sudo tee /etc/apt/apt.conf.d/99no-verify-ssl 2>&1 | tee -a /var/log/shellshock-install.log
log_info "APT SSL verification disabled via 99no-verify-ssl"

# Git SSL Bypass
git config --global http.sslVerify false
log_info "Git SSL verification disabled globally"

# ============================================
# PHASE 1: SYSTEM SETUP
# ============================================
log_progress "Phase 1: System Updates & Base Packages"

# Configure non-interactive mode
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Configure needrestart to avoid interactive prompts
mkdir -p /etc/needrestart/conf.d
cat > /etc/needrestart/conf.d/no-prompt.conf << 'EOF'
$nrconf{restart} = 'a';
$nrconf{kernelhints} = 0;
EOF

# Update package lists
log_info "Updating package lists..."
apt update -qq 2>&1 | tee -a /var/log/shellshock-install.log

# Upgrade system only if packages are available
if apt list --upgradable 2>/dev/null | grep -q "upgradable"; then
    log_info "Upgrading system packages..."
    DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq 2>&1 | tee -a /var/log/shellshock-install.log
else
    log_skip "System already up to date"
fi

# Install robust NTP daemon (chrony)
if ! package_installed "chrony"; then
    log_info "Installing robust NTP client (chrony) for reliable time sync..."
    DEBIAN_FRONTEND=noninteractive apt install -y -qq chrony 2>&1 | tee -a /var/log/shellshock-install.log || log_warn "Failed to install chrony."

    if command_exists chronyc; then
        log_info "Forcing initial time sync (chronyc makestep)..."
        chronyc makestep 2>&1 | tee -a /var/log/shellshock-install.log || true
        log_info "Time synchronization service (chronyd) started."
    fi
else
    log_skip "chrony already installed"
fi

# Install base packages
log_info "Installing base packages..."
PACKAGES=(
    build-essential git curl wget vim neovim tmux zsh
    python3-pip python3-venv python3-dev golang-go rustc cargo
    docker.io docker-compose jq ripgrep fd-find bat
    htop ncdu tree fonts-powerline silversearcher-ag
    john john-data hashcat sqlmap exploitdb
    mingw-w64 mingw-w64-tools
    p7zip-full unzip zip
    net-tools dnsutils iproute2
)

PACKAGES_TO_INSTALL=()
for pkg in "${PACKAGES[@]}"; do
    if ! package_installed "$pkg"; then
        PACKAGES_TO_INSTALL+=("$pkg")
    fi
done

if [[ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]]; then
    log_info "Installing ${#PACKAGES_TO_INSTALL[@]} new packages..."
    DEBIAN_FRONTEND=noninteractive apt install -y -qq "${PACKAGES_TO_INSTALL[@]}" 2>&1 | tee -a /var/log/shellshock-install.log || true
else
    log_skip "All base packages already installed"
fi

# Update searchsploit database
if command_exists searchsploit; then
    log_info "Updating searchsploit database..."
    searchsploit -u -v 2>&1 | tee -a /var/log/shellshock-install.log || log_warn "searchsploit update failed (non-critical)"
else
    log_skip "searchsploit not available"
fi

# ============================================
# PHASE 1.5: VIRTUALBOX DETECTION
# ============================================
log_progress "Phase 1.5: VirtualBox Detection"

if systemd-detect-virt 2>/dev/null | grep -qi "oracle"; then
    log_info "VirtualBox environment detected"
    log_warn "VirtualBox Guest Additions installer will be created on Desktop"
    log_warn "Run ~/Desktop/INSTALL_VBOX_ADDITIONS.sh after setup for:"
    log_warn "  - Bidirectional clipboard"
    log_warn "  - Drag & drop functionality"
    log_warn "  - Auto-resize display"
    log_warn "  - Shared folders support"
else
    log_skip "Not running in VirtualBox - Guest Additions not needed"
fi

# ============================================
# PHASE 2: USER CONFIGURATION
# ============================================
log_progress "Phase 2: User Account Configuration"

# Create or verify user account
if ! id "$USERNAME" &>/dev/null; then
    log_info "Creating user: $USERNAME"
    useradd -m -s /bin/zsh -G sudo,docker --disabled-password "$USERNAME"
    log_info "User '$USERNAME' created (no password required)"

    # Apply Parrot OS defaults from /etc/skel
    log_info "Applying default configuration from /etc/skel..."
    if [[ -d "/etc/skel" ]]; then
        rsync -a /etc/skel/. "$USER_HOME/" 2>/dev/null || true
        log_info "Copied base configurations"
    fi

    # Copy Parrot OS defaults from 'user' account if present
    if [[ -d "/home/user" ]] && [[ "$USERNAME" != "user" ]]; then
        log_info "Copying Parrot OS defaults from 'user' account..."
        rsync -a /home/user/.config/mate "$USER_HOME/.config/" 2>/dev/null || true
        rsync -a /home/user/.config/dconf "$USER_HOME/.config/" 2>/dev/null || true
        cp /home/user/.gtkrc-2.0 "$USER_HOME/" 2>/dev/null || true
        rsync -a /home/user/.themes "$USER_HOME/" 2>/dev/null || true
        log_info "Parrot defaults applied"
    fi

    chown -R "$USERNAME":"$USERNAME" "$USER_HOME" 2>/dev/null || true

    # Configure Parrot theme via gsettings
    log_info "Configuring Parrot theme (Requires running Display/DBUS session)..."
    sudo -u "$USERNAME" bash << 'THEME_EOF'
# Attempt to find the user's running DBUS session if it exists
DBUS_ADDRESS=$(sudo -u "$USERNAME" grep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u "$USERNAME" mate-session|head -n1)/environ 2>/dev/null | tr -d '\0' | cut -d= -f2- || true)
export DBUS_SESSION_BUS_ADDRESS="${DBUS_ADDRESS}"
export DISPLAY=:0

if command -v gsettings &>/dev/null; then
    gsettings set org.mate.interface gtk-theme 'Parrot' 2>/dev/null || gsettings set org.mate.interface gtk-theme 'Arc-Darker' 2>/dev/null || true
    gsettings set org.mate.interface icon-theme 'Papirus-Dark' 2>/dev/null || gsettings set org.mate.interface icon-theme 'Papirus' 2>/dev/null || true
    gsettings set org.mate.Marco.general theme 'Parrot' 2>/dev/null || gsettings set org.mate.Marco.general theme 'Arc-Darker' 2>/dev/null || true
    
    if [[ -f "/usr/share/backgrounds/parrot/default.jpg" ]]; then
        gsettings set org.mate.background picture-filename '/usr/share/backgrounds/parrot/default.jpg' 2>/dev/null || true
    elif [[ -f "/usr/share/backgrounds/parrot/parrot.jpg" ]]; then
        gsettings set org.mate.background picture-filename '/usr/share/backgrounds/parrot/parrot.jpg' 2>/dev/null || true
    fi
    
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/default/ use-theme-colors false 2>/dev/null || true
fi
THEME_EOF

else
    log_skip "User '$USERNAME' already exists"

    # Apply Parrot defaults if not already configured
    if [[ ! -f "$USER_HOME/.config/shellshock-configured" ]]; then
        log_info "Applying Parrot defaults to existing user (if theme is available)..."

        if [[ -d "/home/user" ]] && [[ "$USERNAME" != "user" ]]; then
            rsync -a /home/user/.config/mate "$USER_HOME/.config/" 2>/dev/null || true
            rsync -a /home/user/.config/dconf "$USER_HOME/.config/" 2>/dev/null || true
        fi

        sudo -u "$USERNAME" bash << 'THEME2_EOF'
DBUS_ADDRESS=$(sudo -u "$USERNAME" grep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u "$USERNAME" mate-session|head -n1)/environ 2>/dev/null | tr -d '\0' | cut -d= -f2- || true)
export DBUS_SESSION_BUS_ADDRESS="${DBUS_ADDRESS}"
export DISPLAY=:0

if command -v gsettings &>/dev/null; then
    gsettings set org.mate.interface gtk-theme 'Parrot' 2>/dev/null || gsettings set org.mate.interface gtk-theme 'Arc-Darker' 2>/dev/null || true
    gsettings set org.mate.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
fi
THEME2_EOF

        mkdir -p "$USER_HOME/.config"
        touch "$USER_HOME/.config/shellshock-configured"
        chown -R "$USERNAME":"$USERNAME" "$USER_HOME/.config"
    else
        log_skip "Parrot defaults already configured"
    fi
fi

# Configure sudoers
if [[ ! -f "/etc/sudoers.d/$USERNAME" ]]; then
    if echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | visudo -cf - > /dev/null 2>&1; then
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USERNAME"
        chmod 440 /etc/sudoers.d/"$USERNAME"
        log_info "Sudoers configured for $USERNAME (NOPASSWD)"
    else
        log_error "Failed to validate sudoers entry. Skipping NOPASSWD setup."
    fi
else
    log_skip "Sudoers already configured"
fi

# Ensure ownership
chown -R "$USERNAME":"$USERNAME" "$USER_HOME" 2>/dev/null || true

# Set default shell to zsh
ZSH_PATH="$(which zsh 2>/dev/null || echo '')"
if [[ -n "$ZSH_PATH" ]]; then
    if [[ "$(getent passwd "$USERNAME" | cut -d: -f7)" != "$ZSH_PATH" ]]; then
        chsh -s "$ZSH_PATH" "$USERNAME" 2>/dev/null || true
        log_info "Default shell set to zsh"
    else
        log_skip "Shell already set to zsh"
    fi
else
    log_warn "Zsh executable not found, skipping default shell change"
fi

# Disable old 'user' auto-login if exists
if [[ "$USERNAME" != "user" ]]; then
    log_progress "Checking for existing 'user' auto-login configuration..."
    sed -i '/autologin-user=user/d' /etc/lightdm/lightdm.conf* 2>/dev/null || true
    sed -i '/AutomaticLogin = user/d' /etc/gdm3/custom.conf 2>/dev/null || true
    sed -i '/AutomaticLoginEnable = true/d' /etc/gdm3/custom.conf 2>/dev/null || true
    log_info "Cleaned up obsolete 'user' auto-login settings"
fi

# Configure auto-login
AUTOLOGIN_CONFIGURED=false

if [[ -f "/etc/lightdm/lightdm.conf.d/50-autologin.conf" ]]; then
    if grep -q "autologin-user=$USERNAME" /etc/lightdm/lightdm.conf.d/50-autologin.conf 2>/dev/null; then
        AUTOLOGIN_CONFIGURED=true
    fi
elif [[ -f "/etc/gdm3/custom.conf" ]]; then
    if grep -q "AutomaticLogin = $USERNAME" /etc/gdm3/custom.conf 2>/dev/null; then
        AUTOLOGIN_CONFIGURED=true
    fi
fi

if [[ "$AUTOLOGIN_CONFIGURED" == "false" ]]; then
    echo ""
    read -rp "Enable auto-login for $USERNAME (recommended for CTF VM)? (y/n): " auto_login
    if [[ "$auto_login" =~ ^[Yy]$ ]]; then
        log_progress "Configuring auto-login..."

        # LightDM
        if command_exists lightdm || [[ -d "/etc/lightdm" ]]; then
            mkdir -p /etc/lightdm/lightdm.conf.d
            cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << EOF
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
allow-guest=false
EOF
            log_info "LightDM auto-login configured"
        fi

        # GDM3
        if command_exists gdm3 || [[ -f "/etc/gdm3/custom.conf" ]]; then
            sed -i '/AutomaticLoginEnable/d' /etc/gdm3/custom.conf 2>/dev/null || true
            sed -i '/AutomaticLogin =/d' /etc/gdm3/custom.conf 2>/dev/null || true

            if grep -q '^\[daemon\]' /etc/gdm3/custom.conf; then
                sed -i "/^\[daemon\]/a AutomaticLoginEnable = true" /etc/gdm3/custom.conf
                sed -i "/^\[daemon\]/a AutomaticLogin = $USERNAME" /etc/gdm3/custom.conf
            else
                echo -e "\n[daemon]\nAutomaticLoginEnable = true\nAutomaticLogin = $USERNAME" >> /etc/gdm3/custom.conf
            fi
            log_info "GDM3 auto-login configured"
        fi

        log_info "Auto-login enabled for $USERNAME"
    else
        log_info "Auto-login skipped - manual login required"
    fi
else
    log_skip "Auto-login already configured"
fi

# Configure passwordless login group
if ! grep -q '^nopasswdlogin:' /etc/group; then
    groupadd nopasswdlogin || true
    log_info "Created nopasswdlogin group"
fi

if ! id -nG "$USERNAME" | grep -q 'nopasswdlogin'; then
    usermod -aG nopasswdlogin "$USERNAME" || true
    log_info "Added $USERNAME to nopasswdlogin group"
fi

# Configure PAM
PAM_ENTRY='auth [success=1 default=ignore] pam_succeed_if.so user ingroup nopasswdlogin'
PAM_FILE='/etc/pam.d/common-auth'

if ! grep -qF "$PAM_ENTRY" "$PAM_FILE"; then
    if sed -i "1i$PAM_ENTRY" "$PAM_FILE"; then
        log_info "PAM configured for passwordless login via nopasswdlogin group"
    else
        log_error "Failed to configure PAM for passwordless login (sed failed)"
    fi
else
    log_skip "PAM already configured for nopasswdlogin group"
fi

# ============================================
# PHASE 3: SHELL ENVIRONMENT
# ============================================
log_progress "Phase 3: Shell Environment (Zsh + Oh-My-Zsh + Powerlevel10k)"

if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    log_info "Installing Oh-My-Zsh..."

    TEMP_HOME=$(mktemp -d)

    # Install Oh-My-Zsh to temp location in a subshell
    (
        export HOME="$TEMP_HOME"
        sh -c "RUNZSH=no $(curl -fsSLk https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1 | tee -a /var/log/shellshock-install.log || true
    )

    if [[ -d "$TEMP_HOME/.oh-my-zsh" ]]; then
        # Install plugins using safe_clone
        safe_clone "https://github.com/zsh-users/zsh-autosuggestions" "${TEMP_HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
        safe_clone "https://github.com/zsh-users/zsh-syntax-highlighting.git" "${TEMP_HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
        safe_clone "https://github.com/romkatv/powerlevel10k.git" "${TEMP_HOME}/.oh-my-zsh/custom/themes/powerlevel10k"

        # Download Powerlevel10k config
        safe_download "https://raw.githubusercontent.com/Jamie-loring/Public-scripts/main/p10k-jamie-config.zsh" "${TEMP_HOME}/.p10k.zsh"

        # Copy to user home using rsync
        rsync -a "$TEMP_HOME"/.oh-my-zsh "$USER_HOME/" 2>/dev/null || true
        cp "$TEMP_HOME"/.p10k.zsh "$USER_HOME/" 2>/dev/null || true

        log_info "Oh-My-Zsh installed with plugins and theme"
    else
        log_error "Oh-My-Zsh installation failed in temporary directory."
    fi

    # Cleanup
    rm -rf "$TEMP_HOME"

else
    log_skip "Oh-My-Zsh already installed"
fi

# ============================================
# PHASE 3.5: FIREFOX EXTENSIONS & CONFIGURATION
# ============================================
log_progress "Phase 3.5: Firefox Extensions & Configuration"

if command_exists firefox || command_exists firefox-esr; then
    log_info "Configuring Firefox for pentesting..."

    FIREFOX_CMD=$(command -v firefox || command -v firefox-esr)

    # Step 1: Create Firefox profile structure
    PROFILE_DIR="$USER_HOME/.mozilla/firefox/shellshock.default"
    mkdir -p "$PROFILE_DIR"

    if [[ ! -f "$USER_HOME/.mozilla/firefox/profiles.ini" ]]; then
        cat > "$USER_HOME/.mozilla/firefox/profiles.ini" << 'PROFILES_INI_EOF'
[General]
StartWithLastProfile=1

[Profile0]
Name=default
IsRelative=1
Path=shellshock.default
Default=1
PROFILES_INI_EOF
        log_info "Created Firefox profile: shellshock.default"
    fi

    chown -R "$USERNAME":"$USERNAME" "$USER_HOME/.mozilla" 2>/dev/null || true

    # Step 2: Download Firefox extensions
    mkdir -p "$USER_HOME/.firefox-extensions"
    log_info "Downloading Firefox extensions..."

    declare -A EXTENSIONS=(
        ["darkreader"]="https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi"
        ["cookie-editor"]="https://addons.mozilla.org/firefox/downloads/latest/cookie-editor/latest.xpi"
        ["foxyproxy"]="https://addons.mozilla.org/firefox/downloads/latest/foxyproxy-standard/latest.xpi"
        ["wappalyzer"]="https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/latest.xpi"
        ["user-agent-switcher"]="https://addons.mozilla.org/firefox/downloads/latest/user-agent-string-switcher/latest.xpi"
        ["hacktools"]="https://addons.mozilla.org/firefox/downloads/latest/hacktools/latest.xpi"
    )

    for ext_name in "${!EXTENSIONS[@]}"; do
        ext_url="${EXTENSIONS[$ext_name]}"
        safe_download "$ext_url" "$USER_HOME/.firefox-extensions/${ext_name}.xpi"
    done

    # Step 3: Install extensions directly to profile
    if [[ -d "$PROFILE_DIR" ]]; then
        log_info "Installing extensions to Firefox profile..."
        mkdir -p "$PROFILE_DIR/extensions"

        declare -A EXT_IDS=(
            ["darkreader"]="addon@darkreader.org"
            ["cookie-editor"]="{c36177c0-224a-4e27-b20d-b91c8b6f3ae4}"
            ["foxyproxy"]="foxyproxy@eric.h.jung"
            ["wappalyzer"]="wappalyzer@crunchlabz.com"
            ["user-agent-switcher"]="{3579f63b-d8ee-424f-bbb6-6d0ce3285e6a}"
            ["hacktools"]="hacktools@hacktools.com"
        )

        for ext_name in "${!EXTENSIONS[@]}"; do
            xpi_file="$USER_HOME/.firefox-extensions/${ext_name}.xpi"
            if [[ -f "$xpi_file" ]]; then
                ext_id="${EXT_IDS[$ext_name]}"
                cp "$xpi_file" "$PROFILE_DIR/extensions/${ext_id}.xpi" 2>/dev/null && \
                    log_info "Installed: $ext_name" || \
                    log_warn "Failed to install: $ext_name (copy failed)"
            fi
        done

        # Step 4: Create user.js preferences file
        log_info "Configuring Firefox preferences..."
        cat > "$PROFILE_DIR/user.js" << USERJS_EOF
// ShellShock v1.01 - Firefox Configuration for Pentesting

// Disable automatic updates
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("extensions.update.enabled", false);

// Developer tools
user_pref("devtools.theme", "dark");
user_pref("devtools.debugger.remote-enabled", true);
user_pref("devtools.chrome.enabled", true);

// Security relaxation for pentesting
user_pref("security.fileuri.strict_origin_policy", false);
user_pref("network.http.referer.XOriginPolicy", 0);

// Disable DNS over HTTPS (important for pentesting)
user_pref("network.trr.mode", 5);

// Cache configuration (memory only, no disk writes)
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", 524288);

// Privacy settings (disabled for pentesting)
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.trackingprotection.enabled", false);
user_pref("privacy.donottrackheader.enabled", false);

// Download configuration
user_pref("browser.download.dir", "$USER_HOME/Downloads");
user_pref("browser.download.folderList", 1);
user_pref("browser.download.useDownloadDir", true);

// UI configuration
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.warnOnQuit", false);

// Extension installation (allow unsigned extensions for testing)
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 15);
USERJS_EOF

        chown "$USERNAME":"$USERNAME" "$PROFILE_DIR/user.js" 2>/dev/null || true
        log_info "Firefox preferences configured"
    fi

    # Step 5: Configure enterprise policies
    FIREFOX_PATH=$(find /usr/lib -maxdepth 1 -type d \( -name 'firefox' -o -name 'firefox-esr' \) 2>/dev/null | head -n1)
    if [[ -n "$FIREFOX_PATH" ]]; then
        mkdir -p "$FIREFOX_PATH/distribution"

        cat > "$FIREFOX_PATH/distribution/policies.json" << 'POLICIES_EOF'
{
  "policies": {
    "DisableAppUpdate": true,
    "ExtensionUpdate": false,
    "Preferences": {
      "extensions.autoDisableScopes": {
        "Value": 0,
        "Status": "locked"
      },
      "xpinstall.signatures.required": {
        "Value": false,
        "Status": "locked"
      }
    }
  }
}
POLICIES_EOF
        log_info "Firefox enterprise policies configured"
    fi

    chown -R "$USERNAME":"$USERNAME" "$USER_HOME/.firefox-extensions" "$PROFILE_DIR" 2>/dev/null || true

    log_info "Firefox configured successfully"
    log_warn "Extensions will be active on next Firefox launch"
else
    log_warn "Firefox not detected - skipping extension installation"
fi

# ============================================
# PHASE 4: PENTESTING TOOLS INSTALLATION
# ============================================
log_progress "Phase 4: Installing Pentesting Tools"

mkdir -p "$USER_HOME"/tools/{wordlists,scripts,exploits,repos,windows}

# Python tools via pip
log_progress "Installing Python tools..."

# Ensure pipx is installed
if ! command_exists pipx; then
    log_info "Installing pipx..."
    DEBIAN_FRONTEND=noninteractive apt install -y python3-pip pipx 2>&1 | tee -a /var/log/shellshock-install.log || true
    pipx ensurepath || true
    sudo -u "$USERNAME" pipx ensurepath || true
    export PATH="$PATH:/root/.local/bin:$USER_HOME/.local/bin"
fi

# Python packages via pip3
PIP_TOOLS=(
    "impacket" "hashid" "bloodhound" "bloodyAD" "mitm6" "responder" "certipy-ad"
    "coercer" "pypykatz" "lsassy" "enum4linux-ng" "dnsrecon" "git-dumper"
    "roadrecon" "manspider" "mitmproxy" "pwntools" "ROPgadget" "truffleHog"
)

for tool in "${PIP_TOOLS[@]}"; do
    if ! pip3 list 2>/dev/null | grep -qi "^${tool} "; then
        pip3 install --break-system-packages "$tool" 2>&1 | tee -a /var/log/shellshock-install.log || log_warn "Failed to install $tool"
    else
        log_skip "$tool already installed"
    fi
done

# Pipx tools
log_progress "Installing pipx-isolated tools as $USERNAME..."

PIPX_TOOLS=(
    "git+https://github.com/Pennyw0rth/NetExec"
    "ldapdomaindump"
    "sprayhound"
    "RsaCtfTool"
)

for tool in "${PIPX_TOOLS[@]}"; do
    tool_name=$(basename "$tool" | cut -d'@' -f1 | sed 's/git+https:\/\/github.com\///' | cut -d'/' -f2 | awk '{print tolower($0)}')
    if ! sudo -u "$USERNAME" pipx list 2>/dev/null | grep -qi "$tool_name"; then
        log_info "Installing $tool_name..."
        sudo -u "$USERNAME" bash -c "export PATH=\$PATH:\$HOME/.local/bin; pipx install '$tool'" 2>&1 | tee -a /var/log/shellshock-install.log || log_warn "Failed to install $tool_name via pipx"
    else
        log_skip "$tool_name already installed"
    fi
done

# Go tools
if command_exists go; then
    log_progress "Installing Go-based tools as $USERNAME..."

    GO_TOOLS=(
        "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest" "github.com/projectdiscovery/httpx/cmd/httpx@latest"
        "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        "github.com/projectdiscovery/katana/cmd/katana@latest" "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
        "github.com/ffuf/ffuf/v2@latest" "github.com/OJ/gobuster/v3@latest" "github.com/ropnop/kerbrute@latest"
        "github.com/jpillora/chisel@latest" "github.com/bp0lr/gauplus@latest" "github.com/ropnop/windapsearch@latest"
        "github.com/garrettfoster13/pre2k@latest" "github.com/nicocha30/ligolo-ng/cmd/proxy@latest"
        "github.com/nicocha30/ligolo-ng/cmd/agent@latest"
    )

    export GOPATH="$USER_HOME/go"
    mkdir -p "$GOPATH"/{bin,pkg,src}
    chown -R "$USERNAME":"$USERNAME" "$GOPATH"

    for tool_path in "${GO_TOOLS[@]}"; do
        tool_name=$(basename "$tool_path" | cut -d'@' -f1)
        if [[ ! -f "$GOPATH/bin/$tool_name" ]]; then
            log_info "Installing $tool_name..."
            sudo -u "$USERNAME" bash -c "export GOPATH='$GOPATH'; export PATH=\$PATH:\$GOPATH/bin; go install -v '$tool_path'" 2>&1 | tee -a /var/log/shellshock-install.log || log_warn "Failed to install $tool_name"
        else
            log_skip "$tool_name already installed"
        fi
    done

    chown -R "$USERNAME":"$USERNAME" "$GOPATH" 2>/dev/null || true
else
    log_warn "Go not available - skipping Go-based tools"
fi

# Ruby tools
if command_exists gem; then
    log_progress "Installing Ruby-based tools..."

    RUBY_TOOLS=("one_gadget" "haiti-hash" "evil-winrm")

    for tool in "${RUBY_TOOLS[@]}"; do
        if ! gem list -i "^${tool}$" &>/dev/null; then
            gem install "$tool" 2>&1 | tee -a /var/log/shellshock-install.log || log_warn "Failed to install $tool"
        else
            log_skip "$tool already installed"
        fi
    done
else
    log_warn "Ruby not available - skipping Ruby-based tools"
fi

# Ysoserial
if command_exists java; then
    if [[ ! -f "$USER_HOME/tools/ysoserial.jar" ]]; then
        log_info "Downloading ysoserial.jar..."
        safe_download "https://github.com/frohoff/ysoserial/releases/latest/download/ysoserial-all.jar" "$USER_HOME/tools/ysoserial.jar"
    else
        log_skip "ysoserial.jar already exists"
    fi
else
    log_warn "Java not detected - skipping ysoserial download"
fi

# ============================================
# PHASE 4.5: WINDOWS BINARIES
# ============================================
log_progress "Phase 4.5: Compiling & Downloading Windows Binaries"

mkdir -p "$USER_HOME/tools/windows"

# Compile RunasCs
if command_exists x86_64-w64-mingw32-gcc; then
    RUNASCS_PATH="$USER_HOME/tools/windows/runasCs.exe"
    if [[ ! -f "$RUNASCS_PATH" ]]; then
        log_info "Compiling RunasCs.exe..."
        if safe_download "https://raw.githubusercontent.com/antonioCoco/RunasCs/master/RunasCs.c" "/tmp/RunasCs.c"; then
            if x86_64-w64-mingw32-gcc /tmp/RunasCs.c -o "$RUNASCS_PATH" -lwininet -lws2_32 -static -s -O2 2>&1 | tee -a /var/log/shellshock-install.log; then
                log_info "RunasCs.exe compiled successfully"
            else
                log_warn "RunasCs compilation failed (non-critical)"
            fi
            rm -f /tmp/RunasCs.c
        else
            log_warn "Failed to download RunasCs.c source"
        fi
    else
        log_skip "runasCs.exe already exists"
    fi
else
    log_warn "MinGW not available - skipping RunasCs compilation"
fi

# Download pre-compiled Windows tools
log_progress "Downloading pre-compiled Windows binaries..."
safe_download "https://github.com/PowerShellMafia/PowerSploit/raw/master/Recon/PowerView.ps1" "$USER_HOME/tools/windows/PowerView.ps1"
safe_download "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Rubeus.exe" "$USER_HOME/tools/windows/Rubeus.exe"
safe_download "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/SharpHound.exe" "$USER_HOME/tools/windows/SharpHound.exe"
safe_download "https://github.com/Flangvik/SharpCollection/raw/master/NetFramework_4.8_Any/Seatbelt.exe" "$USER_HOME/tools/windows/Seatbelt.exe"

chown -R "$USERNAME":"$USERNAME" "$USER_HOME/tools/windows" 2>/dev/null || true

# ============================================
# PHASE 5: WORDLISTS
# ============================================
log_progress "Phase 5: Downloading Wordlists"

# Clone SecLists
if [[ ! -d "$USER_HOME/tools/wordlists/SecLists/.git" ]]; then
    log_info "Cloning SecLists (Shallow clone, SSL ignored)..."
    safe_clone "https://github.com/danielmiessler/SecLists.git" "$USER_HOME/tools/wordlists/SecLists"
else
    safe_clone "https://github.com/danielmiessler/SecLists.git" "$USER_HOME/tools/wordlists/SecLists"
fi

# Decompress rockyou.txt
ROCKYOU_GZ="/usr/share/wordlists/rockyou.txt.gz"
ROCKYOU_TXT="/usr/share/wordlists/rockyou.txt"

if [[ -f "$ROCKYOU_GZ" ]] && [[ ! -f "$ROCKYOU_TXT" ]]; then
    log_info "Decompressing rockyou.txt..."
    gunzip "$ROCKYOU_GZ" || true
elif [[ -f "$ROCKYOU_TXT" ]]; then
    log_skip "rockyou.txt already decompressed"
else
    log_warn "rockyou.txt.gz not found in /usr/share/wordlists"
fi

# Create convenience symlinks
if [[ ! -L "$USER_HOME/SecLists" ]] && [[ -d "$USER_HOME/tools/wordlists/SecLists" ]]; then
    ln -sf "$USER_HOME/tools/wordlists/SecLists" "$USER_HOME/SecLists" 2>/dev/null || true
fi
if [[ ! -L "$USER_HOME/tools/wordlists/rockyou.txt" ]] && [[ -f "$ROCKYOU_TXT" ]]; then
    ln -sf "$ROCKYOU_TXT" "$USER_HOME/tools/wordlists/rockyou.txt" 2>/dev/null || true
fi

chown -R "$USERNAME":"$USERNAME" "$USER_HOME/tools/wordlists" 2>/dev/null || true

# ============================================
# PHASE 6: REPOSITORY CLONING
# ============================================
log_progress "Phase 6: Cloning Essential Repositories (Shallow clone, SSL ignored)"

REPOS=(
    "https://github.com/swisskyrepo/PayloadsAllTheThings.git"
    "https://github.com/peass-ng/PEASS-ng.git"
    "https://github.com/HackTricks-wiki/HackTricks.git"
    "https://github.com/Tib3rius/AutoRecon.git"
    "https://github.com/fortra/impacket.git"
    "https://github.com/projectdiscovery/nuclei-templates.git"
    "https://github.com/internetwache/GitTools.git"
    "https://github.com/AonCyberLabs/Windows-Exploit-Suggester.git"
    "https://github.com/PowerShellMafia/PowerSploit.git"
    "https://github.com/GTFOBins/GTFOBins.github.io.git"
    "https://github.com/LOLBAS-Project/LOLBAS.git"
    "https://github.com/RsaCtfTool/RsaCtfTool.git"
    "https://github.com/brightio/penelope.git"
)

for repo in "${REPOS[@]}"; do
    name=$(basename "$repo" .git)
    safe_clone "$repo" "$USER_HOME/tools/repos/$name"
done

# Create convenience symlinks
if [[ -f "$USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh" ]] && [[ ! -L "$USER_HOME/linpeas.sh" ]]; then
    ln -sf "$USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh" "$USER_HOME/linpeas.sh" 2>/dev/null || true
fi

WINPEAS_PATH=""
if [[ -f "$USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEAS.exe" ]]; then
    WINPEAS_PATH="$USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEAS.exe"
elif [[ -f "$USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe" ]]; then
    WINPEAS_PATH="$USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe"
fi

if [[ -n "$WINPEAS_PATH" ]] && [[ ! -L "$USER_HOME/winpeas.exe" ]]; then
    ln -sf "$WINPEAS_PATH" "$USER_HOME/winpeas.exe" 2>/dev/null || true
fi

if [[ -f "$USER_HOME/tools/repos/penelope/penelope.py" ]] && [[ ! -L "$USER_HOME/penelope.py" ]]; then
    ln -sf "$USER_HOME/tools/repos/penelope/penelope.py" "$USER_HOME/penelope.py" 2>/dev/null || true
fi

chown -R "$USERNAME":"$USERNAME" "$USER_HOME/tools/repos" 2>/dev/null || true

# ============================================
# PHASE 7: DOTFILES & CONFIGURATION
# ============================================
log_progress "Phase 7: Creating Shell Configuration & Scripts"

mkdir -p "$USER_HOME/scripts" "$USER_HOME/Desktop" "$USER_HOME/engagements"

# Create .zshrc
if [[ ! -f "$USER_HOME/.zshrc" ]] || ! grep -q "ShellShock v1.01" "$USER_HOME/.zshrc"; then
    log_info "Creating .zshrc configuration..."
    cat > "$USER_HOME/.zshrc" << 'ZSHRC_EOF'
# ============================================
# ShellShock v1.01 - Zsh Configuration (NTP/SSL Fixed)
# ============================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Zsh plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    docker
    sudo
    history
    command-not-found
)

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source $ZSH/oh-my-zsh.sh
fi

# Load Powerlevel10k configuration
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Environment variables
export PATH=$PATH:$HOME/go/bin:$HOME/.local/bin
export EDITOR=vim
export GOPATH=$HOME/go

# Auto-update nuclei templates in background (silent)
(nuclei -update-templates -silent &>/dev/null &)

# Welcome banner (interactive shells only, not in tmux)
if [[ -o interactive ]] && [[ -z "$TMUX" ]]; then
    echo -e "\033[1;36m"
    cat << 'BANNER'
    ╔════════════════════════════════════════════════════════╗
    ║           SHELLSHOCK v1.01 - LOCKED & LOADED           ║
    ║                                                        ║
    ║ Quick:     tools | repos | win | update | timesync     ║
    ║ Engage:    newengagement <name>                        ║
    ║ Scan:      quickscan <target>                          ║
    ║ Reset:     ~/Desktop/RESET_SHELLSHOCK.sh               ║
    ╚════════════════════════════════════════════════════════╝
BANNER
    echo -e "\033[0m"
fi

# ============================================
# SYSTEM ALIASES
# ============================================
alias ll='ls -lah --color=auto'
alias ...='cd ../..'
alias ..='cd ..'
alias c='clear'
alias h='history'
alias please='sudo'
alias rl='rlwrap nc'
alias python='python3'
alias timesync='sudo chronyc makestep; timedatectl'

# ============================================
# PENTESTING ALIASES
# ============================================
alias nmap-quick='nmap -sV -sC -O'
alias nmap-full='nmap -sV -sC -O -p- --min-rate 1000'
alias nmap-udp='nmap -sU -sV'
alias serve='python3 -m http.server'
alias serve80='sudo python3 -m http.server 80'
alias myip='curl -s ifconfig.me && echo'
alias ports='netstat -tulanp'
alias listening='lsof -i -P -n | grep LISTEN'
alias hash='hashid'
alias shell='python3 ~/penelope.py'

# ============================================
# CRACKING TOOLS
# ============================================
alias john='john --wordlist=~/tools/wordlists/rockyou.txt'
alias hashcat='hashcat'
alias sqlmap='sqlmap'

# ============================================
# EXPLOIT DATABASE
# ============================================
alias searchsploit='searchsploit'
alias ss='searchsploit'
alias ssx='searchsploit -x'
alias ssm='searchsploit -m'
alias ssu='searchsploit -u'

# ============================================
# TOOL SHORTCUTS
# ============================================
alias nxc='netexec'
alias cme='netexec'
alias smb='netexec smb'
alias winrm='netexec winrm'
alias bloodhound='bloodhound-python'
alias peas='linpeas.sh'
alias ysoserial='java -jar ~/tools/ysoserial.jar'
alias evil='evil-winrm'
alias ldump='ldapdomaindump'
alias runas='wine ~/tools/windows/runasCs.exe'

# ============================================
# WINDOWS TOOLS
# ============================================
alias rubeus='wine ~/tools/windows/Rubeus.exe'
alias sharphound='wine ~/tools/windows/SharpHound.exe'
alias seatbelt='wine ~/tools/windows/Seatbelt.exe'

# ============================================
# IMPACKET SHORTCUTS
# ============================================
alias secretsdump='secretsdump.py'
alias getnpusers='GetNPUsers.py'
alias getuserspns='GetUserSPNs.py'
alias psexec='psexec.py'
alias smbexec='smbexec.py'
alias wmiexec='wmiexec.py'
alias ntlmrelayx='ntlmrelayx.py'

# ============================================
# WORDLIST SHORTCUTS
# ============================================
alias wl-common='~/tools/wordlists/SecLists/Discovery/Web-Content/common.txt'
alias wl-dir='~/tools/wordlists/SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt'
alias wl-users='~/tools/wordlists/SecLists/Usernames/Names/names.txt'
alias wl-pass='~/tools/wordlists/rockyou.txt'
alias wl-params='~/tools/wordlists/SecLists/Discovery/Web-Content/burp-parameter-names.txt'

# ============================================
# CHISEL TUNNELING
# ============================================
alias chisel-server='chisel server --reverse --port 8000'
alias chisel-client='chisel client'

# ============================================
# COMBO ATTACKS
# ============================================
alias mitm-relay='sudo mitm6 -d DOMAIN & ntlmrelayx.py -t ldaps://DC-IP -wh attacker-ip --delegate-access'

# ============================================
# NAVIGATION SHORTCUTS
# ============================================
alias tools='cd ~/tools'
alias repos='cd ~/tools/repos'
alias wordlists='cd ~/tools/wordlists'
alias scripts='cd ~/tools/scripts'
alias engagements='cd ~/engagements'
alias win='cd ~/tools/windows'

# VirtualBox shared folder (if present)
[[ -d "/media/sf_ctf-tools" ]] && alias host='cd /media/sf_ctf-tools'
[[ -d "/media/ctf-tools" ]] && alias host='cd /media/ctf-tools'

# ============================================
# CUSTOM FUNCTIONS
# ============================================

# Create new engagement directory structure
newengagement() {
    if [[ -z "$1" ]]; then
        echo "Usage: newengagement <name>"
        return 1
    fi
    
    local name=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]_-' '-')
    local path="$HOME/engagements/$name"

    mkdir -p "$path"/{recon,scans,exploits,loot,notes,screenshots}
    cd "$path" || return 1
    echo "# $1 Engagement" > notes/README.md
    echo "Created: $(date)" >> notes/README.md
    echo "[+] Created engagement: $1"
    ls -la
}

# Quick nmap scan with timestamped output
quickscan() {
    if [[ -z "$1" ]]; then
        echo "Usage: quickscan <target>"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="quickscan_${timestamp}_$1"
    nmap -sV -sC -O -oA "$output_file" "$1"
}

# Universal archive extractor
extract() {
    if [[ ! -f $1 ]]; then
        echo "'$1' is not a valid file" >&2
        return 1
    fi
    
    local file="$1"

    case "$file" in
        *.tar.bz2) tar xjf "$file" ;;
        *.tar.gz) tar xzf "$file" ;;
        *.bz2) bunzip2 "$file" ;;
        *.rar) unrar e "$file" ;;
        *.gz) gunzip "$file" ;;
        *.tar) tar xf "$file" ;;
        *.tbz2) tar xjf "$file" ;;
        *.tgz) tar xzf "$file" ;;
        *.zip) unzip "$file" ;;
        *.Z) uncompress "$file" ;;
        *.7z) 7z x "$file" ;;
        *) echo "'$file' cannot be extracted via extract()" >&2; return 1 ;;
    esac
}
ZSHRC_EOF

    chown "$USERNAME":"$USERNAME" "$USER_HOME/.zshrc"
    log_info ".zshrc created with comprehensive configuration"
else
    log_skip ".zshrc already configured"
fi

# Create update-tools.sh script
if [[ ! -f "$USER_HOME/scripts/update-tools.sh" ]]; then
    log_info "Creating update-tools.sh..."
    cat > "$USER_HOME/scripts/update-tools.sh" << 'UPDATE_SCRIPT_EOF'
#!/bin/bash
set -euo pipefail
# ShellShock v1.01 - Tool Update Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}    SHELLSHOCK TOOL & SYSTEM UPDATE      ${NC}"
echo -e "${GREEN}========================================${NC}"

# Set Git to temporarily ignore SSL errors for updates
git config --global http.sslVerify false

log_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y || log_warn "System update partially failed"

log_info "Updating Python tools (pip3 system-wide)..."
pip3 install -U --break-system-packages \
    impacket bloodhound bloodyAD certipy-ad \
    pypykatz lsassy pwntools ROPgadget truffleHog || log_warn "pip3 update partially failed"

log_info "Updating pipx tools..."
pipx upgrade-all || log_warn "pipx update failed"

log_info "Updating Go tools (Requires GOPATH set)..."
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

GO_TOOLS=(
    "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "github.com/ffuf/ffuf/v2@latest"
    "github.com/OJ/gobuster/v3@latest"
    "github.com/jpillora/chisel@latest"
    "github.com/ropnop/windapsearch@latest"
    "github.com/garrettfoster13/pre2k@latest"
    "github.com/nicocha30/ligolo-ng/cmd/proxy@latest"
    "github.com/nicocha30/ligolo-ng/cmd/agent@latest"
    "github.com/projectdiscovery/katana/cmd/katana@latest"
    "github.com/ropnop/kerbrute@latest"
    "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
)

for tool_path in "${GO_TOOLS[@]}"; do
    tool_name=$(basename "$tool_path" | cut -d'@' -f1)
    echo "  > Updating $tool_name..."
    go install -v "$tool_path" || log_warn "Failed to update $tool_name"
done

log_info "Updating nuclei templates..."
nuclei -update-templates || log_warn "Nuclei template update failed"

log_info "Updating Ruby tools..."
gem update one_gadget haiti-hash evil-winrm || log_warn "Ruby tools update failed"

log_info "Updating searchsploit database..."
searchsploit -u -v || log_warn "searchsploit update failed"

log_info "Updating git repositories (Shallow pull, SSL ignored)..."
cd ~/tools/repos || log_warn "Could not find ~/tools/repos" && exit 1

find . -maxdepth 1 -type d -name ".*" -prune -o -type d ! -name . | while read -r dir; do
    if [[ -d "$dir/.git" ]]; then
        echo -e "[*] Updating $(basename "$dir")"
        ( cd "$dir" && git pull --depth 1 ) || log_warn "Failed to update $(basename "$dir")"
    fi
done

log_info "Forcing immediate system time synchronization..."
sudo chronyc makestep || log_warn "chronyc makestep failed. Check network connection."

log_info "Restoring Git SSL verification setting..."
git config --global --unset http.sslVerify || true

echo -e "\n${GREEN}Update complete! Please check log for warnings.${NC}"
UPDATE_SCRIPT_EOF

    chmod +x "$USER_HOME/scripts/update-tools.sh"
    chown "$USERNAME":"$USERNAME" "$USER_HOME/scripts/update-tools.sh"
    log_info "update-tools.sh created"
else
    log_skip "update-tools.sh already exists"
fi

# ============================================
# PHASE 8: RESET SCRIPT
# ============================================
log_progress "Phase 8: Creating System Reset Script"

if [[ ! -f "$USER_HOME/Desktop/RESET_SHELLSHOCK.sh" ]]; then
    log_info "Creating RESET_SHELLSHOCK.sh..."
    cat > "$USER_HOME/Desktop/RESET_SHELLSHOCK.sh" << 'RESET_SCRIPT_EOF'
#!/bin/bash
set -euo pipefail
# ShellShock v1.01 - System Reset Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}SHELLSHOCK v1.01 — SYSTEM RESET${NC}\n"
echo -e "${YELLOW}This will:${NC}"
echo "  • Archive Zsh history and live terminal buffers"
echo "  • Backup and clear engagement directories"
echo "  • Reset /etc/hosts to defaults"
echo "  • Clear Kerberos tickets"
echo "  • Wipe cached credentials (Responder, NetExec)"
echo "  • Clear SSH known_hosts"
echo "  • Restore APT and Git SSL verification"
echo ""
read -rp "Continue? (type 'yes' to confirm): " confirm
[[ "$confirm" != "yes" ]] && exit 0

ARCHIVE_DIR="$HOME/archives/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$ARCHIVE_DIR/history"

log() { echo -e "${GREEN}[+]${NC} $1"; }

# Capture Zsh history
log "Archiving Zsh command history..."
if [[ -f "$HOME/.zsh_history" ]]; then
    cp "$HOME/.zsh_history" "$ARCHIVE_DIR/history/zsh_history.txt"
    perl -pe 's/^: \d+:\d+;//' "$HOME/.zsh_history" > "$ARCHIVE_DIR/history/zsh_clean.txt" 2>/dev/null || true
    log "Zsh history archived and decoded"
fi

# Capture all live PTY buffers
log "Capturing live terminal buffers..."
pty_count=0
for pty in /dev/pts/[0-9]*; do
    [[ ! -e "$pty" ]] && continue
    owner=$(stat -c %U "$pty" 2>/dev/null || echo "")
    [[ "$owner" != "$USER" ]] && continue
    pty_name=$(basename "$pty")
    timeout 2 sudo script -q -c "cat $pty" /dev/null > "$ARCHIVE_DIR/history/pty_${pty_name}.txt" 2>/dev/null || true
    ((pty_count++))
done
[[ $pty_count -gt 0 ]] && log "Captured $pty_count live terminal buffers"

# Archive engagements
if [[ -d "$HOME/engagements" ]] && ls -A "$HOME/engagements" &>/dev/null; then
    log "Archiving engagement directories..."
    tar -czf "$ARCHIVE_DIR/engagements_backup.tar.gz" -C "$HOME" engagements
    rm -rf "$HOME/engagements"/*
    log "Engagements archived and cleared"
fi

# Reset /etc/hosts
log "Resetting /etc/hosts..."
sudo cp /etc/hosts "$ARCHIVE_DIR/hosts.backup" 2>/dev/null || true
sudo bash -c "cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1 localhost
127.0.1.1 $(hostname)
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HOSTS_EOF"
log "/etc/hosts reset to defaults"

# Clear Kerberos tickets
log "Clearing Kerberos tickets..."
kdestroy -A 2>/dev/null || true
sudo rm -f /tmp/krb5cc_* 2>/dev/null || true
log "Kerberos tickets cleared"

# Clear Zsh history
log "Clearing Zsh history..."
: > "$HOME/.zsh_history" 2>/dev/null
history -c 2>/dev/null || true
log "Zsh history cleared"

# Clear cached credentials
log "Wiping cached credentials..."
rm -rf "$HOME/.responder"/* "$HOME/.nxc"/* "$HOME/.cme"/* "$HOME/.netexec"/* 2>/dev/null || true
log "Cached credentials cleared"

# Clear SSH known_hosts
log "Clearing SSH known_hosts..."
: > "$HOME/.ssh/known_hosts" 2>/dev/null || true
log "SSH known_hosts cleared"

# RESTORE SSL VERIFICATION
log "Restoring APT and Git SSL verification..."
sudo rm -f /etc/apt/apt.conf.d/99no-verify-ssl || true
git config --global --unset http.sslVerify || true
log "SSL verification restored (Reboot recommended for full effect)"

echo -e "\n${GREEN}RESET COMPLETE${NC}"
echo -e "Archive location: ${CYAN}$ARCHIVE_DIR${NC}"
echo -e "History backup: ${CYAN}$ARCHIVE_DIR/history/${NC}\n"

if [[ $pty_count -gt 0 ]]; then
    echo -e "${YELLOW}Preview of captured terminals (last 10 lines):${NC}"
    tail -n 10 "$ARCHIVE_DIR/history"/pty_*.txt 2>/dev/null | tail -n 10 || echo "(empty)"
    echo
fi

read -rp "Reboot system now? (y/n): " reboot_choice
[[ "$reboot_choice" =~ ^[Yy]$ ]] && sudo reboot
RESET_SCRIPT_EOF

    chmod +x "$USER_HOME/Desktop/RESET_SHELLSHOCK.sh"
    chown "$USERNAME":"$USERNAME" "$USER_HOME/Desktop/RESET_SHELLSHOCK.sh"
    log_info "RESET_SHELLSHOCK.sh created"
else
    log_skip "RESET_SHELLSHOCK.sh already exists"
fi

# ============================================
# PHASE 9: VIRTUALBOX GUEST ADDITIONS INSTALLER
# ============================================
log_progress "Phase 9: Creating VirtualBox Guest Additions Installer"

if [[ ! -f "$USER_HOME/Desktop/INSTALL_VBOX_ADDITIONS.sh" ]]; then
    log_info "Creating INSTALL_VBOX_ADDITIONS.sh..."
    cat > "$USER_HOME/Desktop/INSTALL_VBOX_ADDITIONS.sh" << 'VBOX_INSTALLER_EOF'
#!/bin/bash
set -euo pipefail
# ShellShock v1.01 - VirtualBox Guest Additions Installer

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1" >&2; }
log_progress() { echo -e "${BLUE}[*]${NC} $1"; }

clear
echo -e "${CYAN}"
cat << 'BANNER'
╔══════════════════════════════════════════════════════════╗
║     VIRTUALBOX GUEST ADDITIONS INSTALLER                  ║
║     Official ISO Method - Direct from Oracle              ║
║     ShellShock v1.01                                      ║
╚══════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}\n"

# Verify VirtualBox environment
if ! systemd-detect-virt 2>/dev/null | grep -qi "oracle"; then
    log_error "Not running in VirtualBox environment!"
    log_error "This installer is only for VirtualBox VMs."
    exit 1
fi

# Check if already installed
if command -v VBoxClient &>/dev/null && VBoxClient --version &>/dev/null 2>&1; then
    log_info "Guest Additions already installed: $(VBoxClient --version 2>&1 | head -n1)"
    echo ""
    read -rp "Reinstall anyway? (y/n): " reinstall
    [[ "$reinstall" != "y" ]] && [[ "$reinstall" != "Y" ]] && exit 0
fi

# Install required dependencies
log_progress "Installing build dependencies..."
sudo apt update -qq
sudo apt install -y build-essential dkms linux-headers-"$(uname -r)" wget

# Detect VirtualBox version
VBOX_VERSION=""

# Fallback to latest from Oracle
if [[ -z "$VBOX_VERSION" ]]; then
    log_warn "Could not reliably detect VirtualBox version, fetching latest..."
    VBOX_VERSION=$(wget -qO- https://download.virtualbox.org/virtualbox/LATEST.TXT 2>/dev/null || echo "7.0.12")
fi

log_info "Target VirtualBox version: ${GREEN}$VBOX_VERSION${NC}"

ISO_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso"
ISO_FILE="/tmp/VBoxGuestAdditions_${VBOX_VERSION}.iso"
MOUNT_POINT="/mnt/vbox-additions"

# Download ISO
log_progress "Downloading Guest Additions ISO from Oracle..."
echo "URL: $ISO_URL"
if ! wget --progress=bar:force --timeout=60 --tries=3 "$ISO_URL" -O "$ISO_FILE"; then
    log_error "Failed to download ISO! Check version or network."
    log_warn "Manual download: https://download.virtualbox.org/virtualbox/"
    exit 1
fi

log_info "Downloaded: $(du -h "$ISO_FILE" | cut -f1)"

# Prepare mount point
sudo mkdir -p "$MOUNT_POINT"
sudo umount "$MOUNT_POINT" 2>/dev/null || true

# Mount ISO
log_progress "Mounting ISO..."
sudo mount -o loop "$ISO_FILE" "$MOUNT_POINT"

# Verify installer exists
if [[ ! -f "$MOUNT_POINT/VBoxLinuxAdditions.run" ]]; then
    log_error "Installer script not found in ISO! Unmounting and cleaning up."
    sudo umount "$MOUNT_POINT" 2>/dev/null || true
    rm -f "$ISO_FILE"
    exit 1
fi

# Run installer
log_progress "Running Guest Additions installer..."
log_warn "This may take 2-3 minutes and produce warnings (normal)"
echo ""

sudo "$MOUNT_POINT/VBoxLinuxAdditions.run" || {
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 2 ]]; then
        log_warn "Installer returned exit code 2 (this is often normal on success)"
    else
        log_error "Installer failed with exit code: $EXIT_CODE"
        log_warn "Check /var/log/vboxadd-install.log for details"
    fi
}

# Cleanup
log_progress "Cleaning up temporary files..."
sudo umount "$MOUNT_POINT" 2>/dev/null || true
sudo rmdir "$MOUNT_POINT" 2>/dev/null || true
rm -f "$ISO_FILE"

# Verify installation
if command -v VBoxClient &>/dev/null; then
    echo ""
    log_info "${GREEN}Installation successful!${NC}"
    VBoxClient --version 2>&1 | head -n1
    
    # Start VBoxClient services
    log_progress "Starting VBoxClient services..."
    
    pkill -9 -u "$(id -u)" -f VBoxClient 2>/dev/null || true
    sleep 1
    
    VBoxClient --clipboard &>/dev/null &
    VBoxClient --draganddrop &>/dev/null &
    VBoxClient --seamless &>/dev/null &
    VBoxClient --display &>/dev/null &
    
    # Configure autostart
    mkdir -p "$HOME/.config/autostart"
    
    cat > "$HOME/.config/autostart/vboxclient-clipboard.desktop" << 'AUTOSTART_CLIPBOARD'
[Desktop Entry]
Type=Application
Exec=/usr/bin/VBoxClient --clipboard
Hidden=false
X-GNOME-Autostart-enabled=true
Name=VBoxClient Clipboard
Comment=Enable bidirectional clipboard
AUTOSTART_CLIPBOARD

    cat > "$HOME/.config/autostart/vboxclient-dnd.desktop" << 'AUTOSTART_DND'
[Desktop Entry]
Type=Application
Exec=/usr/bin/VBoxClient --draganddrop
Hidden=false
X-GNOME-Autostart-enabled=true
Name=VBoxClient Drag and Drop
Comment=Enable drag and drop
AUTOSTART_DND

    log_info "Autostart configured"
    
    echo ""
    log_info "${GREEN}✓ Bidirectional clipboard${NC}"
    log_info "${GREEN}✓ Drag & drop${NC}"
    log_info "${GREEN}✓ Auto-resize display${NC}"
    log_info "${GREEN}✓ Seamless mode${NC}"
    
    echo ""
    log_warn "${YELLOW}Reboot recommended for full functionality${NC}"
    echo ""
    read -rp "Reboot now? (y/n): " reboot_choice
    [[ "$reboot_choice" =~ ^[Yy]$ ]] && sudo reboot
    
else
    echo ""
    log_error "Installation verification failed!"
    log_warn "VBoxClient command not found"
    log_warn "Check /var/log/vboxadd-install.log for details"
    exit 1
fi

echo ""
log_info "Installation complete!"
log_info "Test clipboard by copying text between host and VM"
VBOX_INSTALLER_EOF

    chmod +x "$USER_HOME/Desktop/INSTALL_VBOX_ADDITIONS.sh"
    chown "$USERNAME":"$USERNAME" "$USER_HOME/Desktop/INSTALL_VBOX_ADDITIONS.sh"
    log_info "VirtualBox installer script created"
else
    log_skip "INSTALL_VBOX_ADDITIONS.sh already exists"
fi

# ============================================
# PHASE 10: DOCUMENTATION
# ============================================
log_progress "Phase 10: Creating Desktop Documentation"

# Create comprehensive command reference
if [[ ! -f "$USER_HOME/Desktop/COMMANDS.txt" ]]; then
    cat > "$USER_HOME/Desktop/COMMANDS.txt" << 'COMMANDS_DOC_EOF'
╔═══════════════════════════════════════════════════════════════╗
║             SHELLSHOCK v1.01 — COMMAND REFERENCE              ║
╚═══════════════════════════════════════════════════════════════╝

══════════════════════════════════════════════════════════════
  CUSTOM FUNCTIONS
══════════════════════════════════════════════════════════════
newengagement <name>       Create engagement directory structure
                           → ~/engagements/<name>/{recon,scans,exploits,loot,notes,screenshots}

quickscan <target>         Fast nmap scan with timestamped output
                           → nmap -sV -sC -O -oA quickscan_TIMESTAMP <target>

extract <file>             Universal archive extractor
                           → Supports: .tar.gz, .zip, .7z, .rar, .bz2, etc.

══════════════════════════════════════════════════════════════
  NAVIGATION SHORTCUTS
══════════════════════════════════════════════════════════════
tools                      cd ~/tools
repos                      cd ~/tools/repos
wordlists                  cd ~/tools/wordlists
scripts                    cd ~/tools/scripts
engagements                cd ~/engagements
win                        cd ~/tools/windows
host                       cd /media/sf_ctf-tools (VirtualBox shared folder)

══════════════════════════════════════════════════════════════
  SYSTEM ALIASES
══════════════════════════════════════════════════════════════
ll                         ls -lah --color=auto (detailed listing)
...                        cd ../.. (up two directories)
..                         cd .. (up one directory)
c                          clear
h                          history
please                     sudo
rl                         rlwrap nc (netcat with readline)
python                     python3 (explicit)
timesync                   sudo chronyc makestep; timedatectl (Instant clock sync)

══════════════════════════════════════════════════════════════
  PENTESTING TOOLS
══════════════════════════════════════════════════════════════
nmap-quick <target>        nmap -sV -sC -O
nmap-full <target>         nmap -sV -sC -O -p- --min-rate 1000
nmap-udp <target>          nmap -sU -sV

serve                      python3 -m http.server 8000
serve80                    sudo python3 -m http.server 80

myip                       Display external IP
ports                      netstat -tulanp
listening                  Show listening ports

hash <hash>                Identify hash type
shell                      Launch penelope reverse shell handler

══════════════════════════════════════════════════════════════
  EXPLOIT DATABASE (SEARCHSPLOIT)
══════════════════════════════════════════════════════════════
searchsploit <term>        Search exploit database
ss <term>                  Searchsploit shortcut
ssx <id>                   Examine exploit code
ssm <id>                   Mirror exploit to current directory
ssu                        Update exploit database

══════════════════════════════════════════════════════════════
  CRACKING TOOLS
══════════════════════════════════════════════════════════════
john <hashfile>            John with rockyou.txt
hashcat <hash>             Hashcat
sqlmap                     SQL injection tool

══════════════════════════════════════════════════════════════
  NETWORK TOOLS
══════════════════════════════════════════════════════════════
nxc / cme                  NetExec (CrackMapExec fork)
smb <target>               NetExec SMB enumeration
winrm <target>             NetExec WinRM

bloodhound                 BloodHound Python ingestor
ldump                      ldapdomaindump
evil                       evil-winrm
ysoserial                  java -jar ~/tools/ysoserial.jar
runas                      wine ~/tools/windows/runasCs.exe

══════════════════════════════════════════════════════════════
  WINDOWS TOOLS
══════════════════════════════════════════════════════════════
rubeus                     wine ~/tools/windows/Rubeus.exe (Kerberos attacks)
sharphound                 wine ~/tools/windows/SharpHound.exe (BloodHound collector)
seatbelt                   wine ~/tools/windows/Seatbelt.exe (host enumeration)

══════════════════════════════════════════════════════════════
  IMPACKET SUITE
══════════════════════════════════════════════════════════════
secretsdump                secretsdump.py
getnpusers                 GetNPUsers.py (ASREPRoast)
getuserspns                GetUserSPNs.py (Kerberoast)
psexec                     psexec.py
smbexec                    smbexec.py
wmiexec                    wmiexec.py
ntlmrelayx                 ntlmrelayx.py

══════════════════════════════════════════════════════════════
  WORDLIST SHORTCUTS
══════════════════════════════════════════════════════════════
wl-common                  common.txt
wl-dir                     directory-list-2.3-medium.txt
wl-users                   names.txt
wl-pass                    rockyou.txt
wl-params                  burp-parameter-names.txt

══════════════════════════════════════════════════════════════
  CHISEL TUNNELING
══════════════════════════════════════════════════════════════
alias chisel-server='chisel server --reverse --port 8000'
alias chisel-client='chisel client'

══════════════════════════════════════════════════════════════
  COMBO ATTACKS
══════════════════════════════════════════════════════════════
alias mitm-relay='sudo mitm6 -d DOMAIN & ntlmrelayx.py -t ldaps://DC-IP -wh attacker-ip --delegate-access'

══════════════════════════════════════════════════════════════
  SYSTEM SCRIPTS
══════════════════════════════════════════════════════════════
~/Desktop/RESET_SHELLSHOCK.sh
    Archive history, wipe credentials, reset system, and restore SSL verification.

~/Desktop/INSTALL_VBOX_ADDITIONS.sh
    Install VirtualBox Guest Additions (clipboard, drag-drop).

~/scripts/update-tools.sh
    Update all pentesting tools and repositories. Includes time sync.

══════════════════════════════════════════════════════════════
COMMANDS_DOC_EOF
    log_info "Created COMMANDS.txt"
fi

# Ensure all desktop files are owned by target user
chown -R "$USERNAME":"$USERNAME" "$USER_HOME/Desktop" 2>/dev/null || true

# ============================================
# PHASE 11: FINAL CLEANUP
# ============================================
log_progress "Phase 11: Final Cleanup & Verification"

# Ensure all files are owned by target user
chown -R "$USERNAME":"$USERNAME" "$USER_HOME" 2>/dev/null || true

# Remove unnecessary packages
apt autoremove -y -qq 2>/dev/null || true
apt clean -qq 2>/dev/null || true

# Restore SSL verification
log_progress "Restoring original SSL configuration..."
sudo rm -f /etc/apt/apt.conf.d/99no-verify-ssl || true
git config --global --unset http.sslVerify || true
log_info "APT and Git SSL verification restored."

# Verify critical installations
log_info "Verifying critical installations..."
VERIFY_OK=true

if ! command_exists zsh; then
    log_warn "Zsh not found!"
    VERIFY_OK=false
fi

if ! command_exists docker; then
    log_warn "Docker not found!"
    VERIFY_OK=false
fi

if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    log_warn "Oh-My-Zsh not found!"
    VERIFY_OK=false
fi

if [[ "$VERIFY_OK" == "true" ]]; then
    log_info "All critical components verified"
else
    log_warn "Some components may have installation issues"
    log_warn "Check /var/log/shellshock-install.log for details"
fi

# ============================================
# COMPLETION
# ============================================
clear
echo -e "${GREEN}"
cat << 'COMPLETION_BANNER'
╔═══════════════════════════════════════════════════════════════╗
║             SHELLSHOCK v1.01 — INSTALLATION COMPLETE          ║
╚═══════════════════════════════════════════════════════════════╝
COMPLETION_BANNER
echo -e "${NC}\n"

echo -e "${YELLOW}Target User:${NC} ${GREEN}$USERNAME${NC}"
echo -e "${YELLOW}Home Directory:${NC} ${GREEN}$USER_HOME${NC}"
echo ""
echo -e "${CYAN}Installed Features:${NC}"
echo -e "  ✓ Smart installation (skips existing)"
echo -e "  ✓ Zsh + Oh-My-Zsh + Powerlevel10k"
echo "  ✓ Robust time sync (chrony) installed"
echo "  ✓ HTTPS certificate issues resolved"
echo -e "  ✓ Firefox with pentesting extensions"
echo -e "  ✓ Comprehensive tool suite (Python, Go, Ruby)"
echo -e "  ✓ Windows binaries (Rubeus, SharpHound, runasCs)"
echo -e "  ✓ Wordlists (SecLists + rockyou.txt)"
echo -e "  ✓ Essential repositories (PEASS, HackTricks, PayloadsAllTheThings)"
echo -e "  ✓ Exploit database (searchsploit)"
echo ""
echo -e "${CYAN}Desktop Scripts:${NC}"
echo -e "  • ${GREEN}RESET_SHELLSHOCK.sh${NC} - Archive & reset system, restores SSL verification"
echo -e "  • ${GREEN}INSTALL_VBOX_ADDITIONS.sh${NC} - VirtualBox integration"
echo -e "  • ${GREEN}COMMANDS.txt${NC} - Complete command reference"
echo ""
echo -e "${CYAN}Maintenance:${NC}"
echo -e "  • ${GREEN}~/scripts/update-tools.sh${NC} - Update all tools and syncs clock"
echo -e "  • ${GREEN}timesync${NC} - New alias for instant clock correction"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} ${RED}Reboot required${NC}"
echo -e "${YELLOW}After reboot:${NC} Log in as ${GREEN}$USERNAME${NC}"
echo ""
echo -e "${CYAN}Installation log:${NC} /var/log/shellshock-install.log"
echo ""

read -rp "Reboot now? (y/n): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Rebooting in 5 seconds...${NC}"
    sleep 5
    reboot
else
    echo -e "\n${YELLOW}Remember to reboot before using:${NC} ${GREEN}sudo reboot${NC}"
    echo -e "${CYAN}Happy hunting!${NC}\n"
fi
