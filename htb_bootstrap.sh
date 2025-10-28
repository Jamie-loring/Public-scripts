# Parrot Security VM Enhancement Bootstrap Script
# For fresh Parrot installs running as VM guest on Windows host
# --- SCRIPT CLEANUP NOTE ---
# If you encounter 'command not found' errors related to unexpected tokens or newline issues, try running the
# following commands to clean the line endings:
# tr -cd '[:print:]\n\t' < /your/file/ >/your/file/
# Modular installation system with component selection

#!/bin/bash

# CTF Box Installer - Pentesting Toolkit Bootstrap v3.0
# Modular installation system with component selection
# Modern CTF Edition - 2025

set -e

# ============================================
# CONFIGURATION
# ============================================
SCRIPT_VERSION="3.0"
CONFIG_FILE="$HOME/.ctfbox.conf"
DEFAULT_USERNAME="$USER"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging functions
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

# Progress indicator
show_progress() {
  local current=$1
  local total=$2
  local percent=$((current * 100 / total))
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC} Progress: ${GREEN}${percent}%${NC} (${current}/${total})${BLUE}                    ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
  echo ""
}

# ============================================
# WELCOME SCREEN
# ============================================
welcome_screen() {
  clear
  
  echo -e "${CYAN}"
  cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    ██████╗████████╗███████╗    ██████╗  ██████╗ ██╗  ██╗    ║
║   ██╔════╝╚══██╔══╝██╔════╝    ██╔══██╗██╔═══██╗╚██╗██╔╝    ║
║   ██║        ██║   █████╗      ██████╔╝██║   ██║ ╚███╔╝     ║
║   ██║        ██║   ██╔══╝      ██╔══██╗██║   ██║ ██╔██╗     ║
║   ╚██████╗   ██║   ██║         ██████╔╝╚██████╔╝██╔╝ ██╗    ║
║    ╚═════╝   ╚═╝   ╚═╝         ╚═════╝  ╚═════╝ ╚═╝  ╚═╝    ║
EOF
  echo -e "${GREEN}"
  cat << "EOF"
║                                                               ║
║           PENTESTING TOOLKIT INSTALLER v3.0                  ║
║              Modern CTF Edition - 2025                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  
  echo ""
  echo -e "${YELLOW}[*]${NC} Welcome to the CTF Pentesting Toolkit Installer!"
  echo ""
  echo "This script will set up a complete offensive security environment with:"
  echo -e "  ${GREEN}•${NC} 40+ pentesting tools (Python, Go, Ruby)"
  echo -e "  ${GREEN}•${NC} 12 essential exploit/payload repositories"
  echo -e "  ${GREEN}•${NC} Modern shell environment (Zsh + Powerlevel10k)"
  echo -e "  ${GREEN}•${NC} Automated workflows and scripts"
  echo ""
  
  # Username configuration
  configure_username
}

# ============================================
# USERNAME CONFIGURATION
# ============================================
validate_username() {
  local username=$1
  
  # Check format
  if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    log_error "Invalid username format!"
    echo "Username must:"
    echo "  - Start with lowercase letter or underscore"
    echo "  - Contain only lowercase letters, numbers, underscore, or dash"
    echo "  - Be 1-32 characters long"
    return 1
  fi
  
  # Check if reserved
  local reserved=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "nobody")
  for reserved_name in "${reserved[@]}"; do
    if [[ "$username" == "$reserved_name" ]]; then
      log_error "Cannot use reserved username: $username"
      return 1
    fi
  done
  
  return 0
}

configure_username() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${CYAN}USER CONFIGURATION${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Check for existing config
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log_info "Found existing config: Username=${USERNAME}"
    read -p "Use this username? (y/n): " use_existing
    if [[ "$use_existing" == "y" || "$use_existing" == "Y" ]]; then
      export USERNAME
      export USER_HOME="/home/$USERNAME"
      log_info "Using username: $USERNAME"
      echo ""
      read -p "Press Enter to continue..."
      return
    fi
  fi
  
  # Get username from user
  while true; do
    read -p "Enter username for pentesting user [default: $DEFAULT_USERNAME]: " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USERNAME}
    
    if validate_username "$USERNAME"; then
      break
    fi
    echo ""
  done
  
  export USERNAME
  export USER_HOME="/home/$USERNAME"
  
  echo ""
  log_info "✓ Username set to: ${GREEN}$USERNAME${NC}"
  log_info "✓ Home directory: ${GREEN}$USER_HOME${NC}"
  echo ""
  
  read -p "Press Enter to continue to main menu..."
}

# ============================================
# CONFIGURATION MANAGEMENT
# ============================================
save_config() {
  cat > "$CONFIG_FILE" << CONF_EOF
# CTF Box Installer Configuration
# Generated: $(date)

USERNAME="$USERNAME"
USER_HOME="$USER_HOME"

# Component Selection
SYSTEM_UPDATES=${SYSTEM_UPDATES:-true}
USER_SETUP=${USER_SETUP:-true}
SHELL_ENVIRONMENT=${SHELL_ENVIRONMENT:-true}
CORE_TOOLS=${CORE_TOOLS:-true}
WEB_ENUMERATION=${WEB_ENUMERATION:-true}
WINDOWS_AD=${WINDOWS_AD:-true}
WIRELESS=${WIRELESS:-false}
POSTEXPLOIT=${POSTEXPLOIT:-true}
FORENSICS_STEGO=${FORENSICS_STEGO:-false}
BINARY_EXPLOITATION=${BINARY_EXPLOITATION:-false}
WORDLISTS=${WORDLISTS:-true}
REPOS_ESSENTIAL=${REPOS_ESSENTIAL:-true}
REPOS_PRIVILEGE=${REPOS_PRIVILEGE:-true}
FIREFOX_EXTENSIONS=${FIREFOX_EXTENSIONS:-true}
AUTOMATION_SCRIPTS=${AUTOMATION_SCRIPTS:-true}
CONF_EOF

  log_info "Configuration saved to $CONFIG_FILE"
}

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log_info "Loaded configuration from $CONFIG_FILE"
  fi
}

# ============================================
# MAIN MENU
# ============================================
show_main_menu() {
  while true; do
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                      CTF BOX INSTALLER                        ║
║                    Main Menu - v3.0                           ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}Current User:${NC} $USERNAME"
    echo ""
    echo "1) ⚡ Install All (Everything - No Questions Asked)"
    echo "2) 🚀 Full Installation (All Components - With Confirmation)"
    echo "3) ⚙️  Custom Installation (Choose Components)"
    echo "4) 📦 Quick Presets (Web/Windows/CTF/Minimal)"
    echo "5) 👤 Change Username (Current: $USERNAME)"
    echo "6) 🔧 Update Existing Installation"
    echo "0) ❌ Exit"
    echo ""
    read -p "Select option [0-6]: " choice
    
    case $choice in
      1) install_all_immediate ;;
      2) install_full ;;
      3) show_component_menu ;;
      4) show_presets_menu ;;
      5) configure_username ;;
      6) update_installation ;;
      0) 
        echo ""
        log_info "Exiting installer. Stay safe out there! 🏴‍☠️"
        exit 0
        ;;
      *)
        log_error "Invalid option. Please select 0-6."
        sleep 2
        ;;
    esac
  done
}

# ============================================
# INSTALLATION PRESETS
# ============================================
show_presets_menu() {
  clear
  echo -e "${CYAN}"
  cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                    INSTALLATION PRESETS                       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  echo ""
  echo "1) 🌐 Web Pentesting (Recon, enumeration, fuzzing)"
  echo "2) 🪟  Windows/AD Focus (NetExec, Impacket, Bloodhound)"
  echo "3) 🏆 CTF Player (Crypto, stego, forensics, binary)"
  echo "4) ⚡ Minimal Setup (Core tools only, no extras)"
  echo "5) 🔙 Back to Main Menu"
  echo ""
  read -p "Select preset [1-5]: " preset
  
  case $preset in
    1) preset_web ;;
    2) preset_windows ;;
    3) preset_ctf ;;
    4) preset_minimal ;;
    5) return ;;
    *)
      log_error "Invalid option"
      sleep 2
      show_presets_menu
      ;;
  esac
}

preset_web() {
  SYSTEM_UPDATES=true
  USER_SETUP=true
  SHELL_ENVIRONMENT=true
  CORE_TOOLS=true
  WEB_ENUMERATION=true
  WINDOWS_AD=false
  WIRELESS=false
  POSTEXPLOIT=true
  FORENSICS_STEGO=false
  BINARY_EXPLOITATION=false
  WORDLISTS=true
  REPOS_ESSENTIAL=true
  REPOS_PRIVILEGE=false
  FIREFOX_EXTENSIONS=true
  AUTOMATION_SCRIPTS=true
  
  log_info "Web Pentesting preset selected"
  save_config
  confirm_and_install
}

preset_windows() {
  SYSTEM_UPDATES=true
  USER_SETUP=true
  SHELL_ENVIRONMENT=true
  CORE_TOOLS=true
  WEB_ENUMERATION=false
  WINDOWS_AD=true
  WIRELESS=false
  POSTEXPLOIT=true
  FORENSICS_STEGO=false
  BINARY_EXPLOITATION=false
  WORDLISTS=true
  REPOS_ESSENTIAL=true
  REPOS_PRIVILEGE=true
  FIREFOX_EXTENSIONS=false
  AUTOMATION_SCRIPTS=true
  
  log_info "Windows/AD preset selected"
  save_config
  confirm_and_install
}

preset_ctf() {
  SYSTEM_UPDATES=true
  USER_SETUP=true
  SHELL_ENVIRONMENT=true
  CORE_TOOLS=true
  WEB_ENUMERATION=true
  WINDOWS_AD=true
  WIRELESS=false
  POSTEXPLOIT=true
  FORENSICS_STEGO=true
  BINARY_EXPLOITATION=true
  WORDLISTS=true
  REPOS_ESSENTIAL=true
  REPOS_PRIVILEGE=true
  FIREFOX_EXTENSIONS=true
  AUTOMATION_SCRIPTS=true
  
  log_info "CTF Player preset selected (Full install)"
  save_config
  confirm_and_install
}

preset_minimal() {
  SYSTEM_UPDATES=false
  USER_SETUP=true
  SHELL_ENVIRONMENT=true
  CORE_TOOLS=true
  WEB_ENUMERATION=false
  WINDOWS_AD=false
  WIRELESS=false
  POSTEXPLOIT=false
  FORENSICS_STEGO=false
  BINARY_EXPLOITATION=false
  WORDLISTS=false
  REPOS_ESSENTIAL=false
  REPOS_PRIVILEGE=false
  FIREFOX_EXTENSIONS=false
  AUTOMATION_SCRIPTS=false
  
  log_info "Minimal preset selected"
  save_config
  confirm_and_install
}

# ============================================
# COMPONENT SELECTION MENU
# ============================================
show_component_menu() {
  load_config
  
  while true; do
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                   COMPONENT SELECTION                         ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo "Toggle components (Y=enabled, N=disabled):"
    echo ""
    echo "━━━━ SYSTEM SETUP ━━━━"
    echo " 1) System Updates & Base Packages        [$([ "$SYSTEM_UPDATES" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo " 2) User Setup ($USERNAME)                 [$([ "$USER_SETUP" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo " 3) Shell Environment (Zsh + p10k)        [$([ "$SHELL_ENVIRONMENT" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo ""
    echo "━━━━ TOOL CATEGORIES ━━━━"
    echo " 4) Core Tools (Python/Go/Ruby base)     [$([ "$CORE_TOOLS" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo " 5) Web Enumeration (ffuf, nuclei, etc)  [$([ "$WEB_ENUMERATION" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo " 6) Windows/AD Tools (NetExec, Impacket) [$([ "$WINDOWS_AD" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo " 7) Wireless Tools (aircrack-ng, etc)    [$([ "$WIRELESS" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo " 8) Post-Exploitation (Penelope, etc)    [$([ "$POSTEXPLOIT" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo " 9) Forensics & Stego                    [$([ "$FORENSICS_STEGO" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo "10) Binary Exploitation                  [$([ "$BINARY_EXPLOITATION" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo "11) Wordlists (SecLists, rockyou)        [$([ "$WORDLISTS" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo ""
    echo "━━━━ REPOSITORIES ━━━━"
    echo "12) Essential Repos (PayloadsAllTheThings, PEASS, HackTricks) [$([ "$REPOS_ESSENTIAL" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo "13) Privilege Escalation Repos (GTFOBins, LOLBAS)             [$([ "$REPOS_PRIVILEGE" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo ""
    echo "━━━━ EXTRAS ━━━━"
    echo "14) Firefox Extensions                   [$([ "$FIREFOX_EXTENSIONS" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo "15) Automation Scripts                   [$([ "$AUTOMATION_SCRIPTS" = "true" ] && echo -e "${GREEN}Y${NC}" || echo -e "${RED}N${NC}")]"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo " A) Select All"
    echo " N) Select None"
    echo " C) Continue with Installation"
    echo " S) Save Configuration & Exit"
    echo " Q) Back to Main Menu"
    echo ""
    read -p "Select option: " comp_choice
    
    case $comp_choice in
      1) SYSTEM_UPDATES=$([ "$SYSTEM_UPDATES" = "true" ] && echo "false" || echo "true") ;;
      2) USER_SETUP=$([ "$USER_SETUP" = "true" ] && echo "false" || echo "true") ;;
      3) SHELL_ENVIRONMENT=$([ "$SHELL_ENVIRONMENT" = "true" ] && echo "false" || echo "true") ;;
      4) CORE_TOOLS=$([ "$CORE_TOOLS" = "true" ] && echo "false" || echo "true") ;;
      5) WEB_ENUMERATION=$([ "$WEB_ENUMERATION" = "true" ] && echo "false" || echo "true") ;;
      6) WINDOWS_AD=$([ "$WINDOWS_AD" = "true" ] && echo "false" || echo "true") ;;
      7) WIRELESS=$([ "$WIRELESS" = "true" ] && echo "false" || echo "true") ;;
      8) POSTEXPLOIT=$([ "$POSTEXPLOIT" = "true" ] && echo "false" || echo "true") ;;
      9) FORENSICS_STEGO=$([ "$FORENSICS_STEGO" = "true" ] && echo "false" || echo "true") ;;
      10) BINARY_EXPLOITATION=$([ "$BINARY_EXPLOITATION" = "true" ] && echo "false" || echo "true") ;;
      11) WORDLISTS=$([ "$WORDLISTS" = "true" ] && echo "false" || echo "true") ;;
      12) REPOS_ESSENTIAL=$([ "$REPOS_ESSENTIAL" = "true" ] && echo "false" || echo "true") ;;
      13) REPOS_PRIVILEGE=$([ "$REPOS_PRIVILEGE" = "true" ] && echo "false" || echo "true") ;;
      14) FIREFOX_EXTENSIONS=$([ "$FIREFOX_EXTENSIONS" = "true" ] && echo "false" || echo "true") ;;
      15) AUTOMATION_SCRIPTS=$([ "$AUTOMATION_SCRIPTS" = "true" ] && echo "false" || echo "true") ;;
      [Aa])
        SYSTEM_UPDATES=true USER_SETUP=true SHELL_ENVIRONMENT=true CORE_TOOLS=true
        WEB_ENUMERATION=true WINDOWS_AD=true WIRELESS=true POSTEXPLOIT=true
        FORENSICS_STEGO=true BINARY_EXPLOITATION=true WORDLISTS=true
        REPOS_ESSENTIAL=true REPOS_PRIVILEGE=true FIREFOX_EXTENSIONS=true AUTOMATION_SCRIPTS=true
        log_info "All components selected"
        sleep 1
        ;;
      [Nn])
        SYSTEM_UPDATES=false USER_SETUP=false SHELL_ENVIRONMENT=false CORE_TOOLS=false
        WEB_ENUMERATION=false WINDOWS_AD=false WIRELESS=false POSTEXPLOIT=false
        FORENSICS_STEGO=false BINARY_EXPLOITATION=false WORDLISTS=false
        REPOS_ESSENTIAL=false REPOS_PRIVILEGE=false FIREFOX_EXTENSIONS=false AUTOMATION_SCRIPTS=false
        log_info "All components deselected"
        sleep 1
        ;;
      [Cc])
        save_config
        confirm_and_install
        return
        ;;
      [Ss])
        save_config
        log_info "Configuration saved!"
        sleep 2
        return
        ;;
      [Qq])
        return
        ;;
      *)
        log_error "Invalid option"
        sleep 1
        ;;
    esac
  done
}

# ============================================
# INSTALLATION CONFIRMATION
# ============================================
confirm_and_install() {
  clear
  echo -e "${CYAN}"
  cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                 INSTALLATION SUMMARY                          ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  echo ""
  echo -e "${GREEN}Username:${NC} $USERNAME"
  echo -e "${GREEN}Home Directory:${NC} $USER_HOME"
  echo ""
  echo "Selected Components:"
  
  [ "$SYSTEM_UPDATES" = "true" ] && echo -e "  ${GREEN}✓${NC} System Updates & Base Packages"
  [ "$USER_SETUP" = "true" ] && echo -e "  ${GREEN}✓${NC} User Setup"
  [ "$SHELL_ENVIRONMENT" = "true" ] && echo -e "  ${GREEN}✓${NC} Shell Environment"
  [ "$CORE_TOOLS" = "true" ] && echo -e "  ${GREEN}✓${NC} Core Tools"
  [ "$WEB_ENUMERATION" = "true" ] && echo -e "  ${GREEN}✓${NC} Web Enumeration"
  [ "$WINDOWS_AD" = "true" ] && echo -e "  ${GREEN}✓${NC} Windows/AD Tools"
  [ "$WIRELESS" = "true" ] && echo -e "  ${GREEN}✓${NC} Wireless Tools"
  [ "$POSTEXPLOIT" = "true" ] && echo -e "  ${GREEN}✓${NC} Post-Exploitation"
  [ "$FORENSICS_STEGO" = "true" ] && echo -e "  ${GREEN}✓${NC} Forensics & Stego"
  [ "$BINARY_EXPLOITATION" = "true" ] && echo -e "  ${GREEN}✓${NC} Binary Exploitation"
  [ "$WORDLISTS" = "true" ] && echo -e "  ${GREEN}✓${NC} Wordlists"
  [ "$REPOS_ESSENTIAL" = "true" ] && echo -e "  ${GREEN}✓${NC} Essential Repositories"
  [ "$REPOS_PRIVILEGE" = "true" ] && echo -e "  ${GREEN}✓${NC} Privilege Escalation Repos"
  [ "$FIREFOX_EXTENSIONS" = "true" ] && echo -e "  ${GREEN}✓${NC} Firefox Extensions"
  [ "$AUTOMATION_SCRIPTS" = "true" ] && echo -e "  ${GREEN}✓${NC} Automation Scripts"
  
  echo ""
  echo -e "${YELLOW}⚠️  This installation will take 10-30 minutes depending on your connection.${NC}"
  echo ""
  read -p "Proceed with installation? (yes/no): " confirm
  
  if [[ "$confirm" == "yes" || "$confirm" == "y" || "$confirm" == "Y" ]]; then
    run_installation
  else
    log_info "Installation cancelled"
    sleep 2
  fi
}

# ============================================
# FULL INSTALLATION
# ============================================
install_all_immediate() {
  # Enable all components
  SYSTEM_UPDATES=true
  USER_SETUP=true
  SHELL_ENVIRONMENT=true
  CORE_TOOLS=true
  WEB_ENUMERATION=true
  WINDOWS_AD=true
  WIRELESS=true
  POSTEXPLOIT=true
  FORENSICS_STEGO=true
  BINARY_EXPLOITATION=true
  WORDLISTS=true
  REPOS_ESSENTIAL=true
  REPOS_PRIVILEGE=true
  FIREFOX_EXTENSIONS=true
  AUTOMATION_SCRIPTS=true
  
  save_config
  
  # Skip confirmation and go straight to install
  clear
  echo -e "${CYAN}"
  cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                  ⚡ INSTALL ALL MODE ⚡                        ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  echo ""
  log_info "Installing EVERYTHING - No questions asked!"
  log_info "This will take 10-30 minutes depending on your connection"
  echo ""
  echo -e "${YELLOW}Starting in 5 seconds... (Ctrl+C to cancel)${NC}"
  sleep 5
  
  run_installation
}

install_full() {
  # Enable all components
  SYSTEM_UPDATES=true
  USER_SETUP=true
  SHELL_ENVIRONMENT=true
  CORE_TOOLS=true
  WEB_ENUMERATION=true
  WINDOWS_AD=true
  WIRELESS=true
  POSTEXPLOIT=true
  FORENSICS_STEGO=true
  BINARY_EXPLOITATION=true
  WORDLISTS=true
  REPOS_ESSENTIAL=true
  REPOS_PRIVILEGE=true
  FIREFOX_EXTENSIONS=true
  AUTOMATION_SCRIPTS=true
  
  save_config
  confirm_and_install
}

# ============================================
# UPDATE EXISTING INSTALLATION
# ============================================
update_installation() {
  clear
  echo -e "${CYAN}"
  cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                  UPDATE INSTALLATION                          ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  echo ""
  log_info "This will update all installed tools and repositories"
  echo ""
  read -p "Continue? (y/n): " update_confirm
  
  if [[ "$update_confirm" == "y" || "$update_confirm" == "Y" ]]; then
    log_progress "Running update script..."
    if [ -f "$USER_HOME/scripts/update-tools.sh" ]; then
      bash "$USER_HOME/scripts/update-tools.sh"
    else
      log_error "Update script not found. Run full installation first."
    fi
  fi
  
  read -p "Press Enter to continue..."
}

# ============================================
# MAIN INSTALLATION RUNNER
# ============================================
run_installation() {
  clear
  log_info "Starting CTF Box Installation..."
  log_info "Installation log: /var/log/ctfbox-install.log"
  sleep 2
  
  # Calculate total phases
  TOTAL_PHASES=0
  [ "$SYSTEM_UPDATES" = "true" ] && ((TOTAL_PHASES++))
  [ "$USER_SETUP" = "true" ] && ((TOTAL_PHASES++))
  [ "$SHELL_ENVIRONMENT" = "true" ] && ((TOTAL_PHASES++))
  # Core tools phase always runs if any tool category is selected
  if [ "$CORE_TOOLS" = "true" ] || [ "$WEB_ENUMERATION" = "true" ] || [ "$WINDOWS_AD" = "true" ] || \
     [ "$WIRELESS" = "true" ] || [ "$POSTEXPLOIT" = "true" ] || [ "$FORENSICS_STEGO" = "true" ] || \
     [ "$BINARY_EXPLOITATION" = "true" ]; then
    ((TOTAL_PHASES++))
  fi
  [ "$WORDLISTS" = "true" ] && ((TOTAL_PHASES++))
  [ "$REPOS_ESSENTIAL" = "true" ] || [ "$REPOS_PRIVILEGE" = "true" ] && ((TOTAL_PHASES++))
  [ "$FIREFOX_EXTENSIONS" = "true" ] && ((TOTAL_PHASES++))
  [ "$AUTOMATION_SCRIPTS" = "true" ] && ((TOTAL_PHASES++))
  ((TOTAL_PHASES++)) # Cleanup phase
  
  CURRENT_PHASE=0
  
  # Run selected phases
  [ "$SYSTEM_UPDATES" = "true" ] && {
    ((CURRENT_PHASE++))
    show_progress $CURRENT_PHASE $TOTAL_PHASES
    phase1_system_setup
  }
  
  [ "$USER_SETUP" = "true" ] && {
    ((CURRENT_PHASE++))
    show_progress $CURRENT_PHASE $TOTAL_PHASES
    phase2_user_setup
  }
  
  [ "$SHELL_ENVIRONMENT" = "true" ] && {
    ((CURRENT_PHASE++))
    show_progress $CURRENT_PHASE $TOTAL_PHASES
    phase3_shell_setup
  }
  
  # Tool installation phase (modular)
  if [ "$CORE_TOOLS" = "true" ] || [ "$WEB_ENUMERATION" = "true" ] || [ "$WINDOWS_AD" = "true" ] || \
     [ "$WIRELESS" = "true" ] || [ "$POSTEXPLOIT" = "true" ] || [ "$FORENSICS_STEGO" = "true" ] || \
     [ "$BINARY_EXPLOITATION" = "true" ]; then
    ((CURRENT_PHASE++))
    show_progress $CURRENT_PHASE $TOTAL_PHASES
    phase4_tools_setup
  fi
  
  [ "$WORDLISTS" = "true" ] && {
    ((CURRENT_PHASE++))
    show_progress $CURRENT_PHASE $TOTAL_PHASES
    phase5_wordlists_setup
  }
  
  if [ "$REPOS_ESSENTIAL" = "true" ] || [ "$REPOS_PRIVILEGE" = "true" ]; then
    ((CURRENT_PHASE++))
    show_progress $CURRENT_PHASE $TOTAL_PHASES
    phase6_repos_setup
  fi
  
  [ "$FIREFOX_EXTENSIONS" = "true" ] && {
    ((CURRENT_PHASE++))
    show_progress $CURRENT_PHASE $TOTAL_PHASES
    phase7_firefox_extensions
  }
  
  [ "$AUTOMATION_SCRIPTS" = "true" ] && {
    ((CURRENT_PHASE++))
    show_progress $CURRENT_PHASE $TOTAL_PHASES
    phase8_automation_setup
  }
  
  # Final cleanup always runs
  ((CURRENT_PHASE++))
  show_progress $CURRENT_PHASE $TOTAL_PHASES
  phase_final_cleanup
  
  show_completion_message
}

# ============================================
# PHASE 1: SYSTEM UPDATES & BASE PACKAGES
# ============================================
phase1_system_setup() {
  log_progress "Phase: System Updates & Base Packages"
  log_info "Updating system and installing base packages..."
  
  log_progress "Updating package lists..."
  DEBIAN_FRONTEND=noninteractive apt update -qq
  
  log_progress "Upgrading installed packages (this may take a while)..."
  DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq
  
  log_progress "Installing base packages..."
  DEBIAN_FRONTEND=noninteractive apt install -y -qq \
    build-essential git curl wget \
    vim neovim tmux zsh \
    python3-pip python3-venv \
    golang-go rustc cargo \
    docker.io docker-compose \
    jq ripgrep fd-find bat \
    htop ncdu tree \
    fonts-powerline \
    silversearcher-ag \
    2>&1 | tee -a /var/log/ctfbox-install.log
  
  log_info "✓ System setup complete"
}

# ============================================
# PHASE 2: USER SETUP
# ============================================
phase2_user_setup() {
  log_progress "Phase: User Account Setup"
  log_info "Setting up user account: $USERNAME"
  
  # Create user if doesn't exist
  if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo "$USERNAME"
    passwd -d "$USERNAME"
    chage -d 0 "$USERNAME"
    
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USERNAME"
    chmod 440 /etc/sudoers.d/"$USERNAME"
    
    log_info "User '$USERNAME' created with sudo privileges"
  else
    log_warn "User '$USERNAME' already exists, updating configuration"
  fi
  
  usermod -aG docker "$USERNAME" 2>/dev/null || true
  export USER_HOME="/home/$USERNAME"
  
  log_info "✓ User setup complete"
}

# ============================================
# PHASE 3: SHELL ENVIRONMENT
# ============================================
phase3_shell_setup() {
  log_progress "Phase: Shell Environment (Zsh + Oh-My-Zsh + p10k)"
  log_info "Setting up Zsh and Oh-My-Zsh for $USERNAME"
  
  # Switch to user's home
  export HOME=$USER_HOME
  cd $USER_HOME
  
  # Install Oh-My-Zsh
  if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    log_progress "Installing Oh-My-Zsh..."
    sudo -u "$USERNAME" sh -c "RUNZSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1 | tee -a /var/log/ctfbox-install.log
  fi
  
  # Install zsh plugins
  log_progress "Installing zsh plugins..."
  sudo -u "$USERNAME" git clone https://github.com/zsh-users/zsh-autosuggestions ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true
  sudo -u "$USERNAME" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true
  
  # Install Powerlevel10k theme
  log_progress "Installing Powerlevel10k theme..."
  sudo -u "$USERNAME" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${USER_HOME}/.oh-my-zsh/custom/themes/powerlevel10k 2>/dev/null || true
  
  # Download pre-configured p10k config
  log_info "Downloading pre-configured Powerlevel10k config..."
  sudo -u "$USERNAME" wget -q https://raw.githubusercontent.com/Jamie-loring/Public-scripts/main/p10k-jamie-config.zsh -O ${USER_HOME}/.p10k.zsh 2>/dev/null || log_warn "Failed to download p10k config"
  
  # Set Zsh as default shell
  chsh -s $(which zsh) "$USERNAME" 2>/dev/null || true
  
  # Configure .zshrc (will be created in phase8 with dotfiles)
  
  log_info "✓ Shell environment setup complete"
}

# ============================================
# PHASE 4: TOOLS INSTALLATION (MODULAR)
# ============================================
phase4_tools_setup() {
  log_progress "Phase: Tool Installation"
  
  # Create tool directory structure
  log_progress "Creating tool directory structure..."
  sudo -u "$USERNAME" mkdir -p $USER_HOME/tools/{wordlists,scripts,exploits,repos}
  
  # Core tools (always if any tool category is selected)
  if [ "$CORE_TOOLS" = "true" ]; then
    install_core_tools
  fi
  
  # Web enumeration tools
  if [ "$WEB_ENUMERATION" = "true" ]; then
    install_web_tools
  fi
  
  # Windows/AD tools
  if [ "$WINDOWS_AD" = "true" ]; then
    install_windows_tools
  fi
  
  # Wireless tools
  if [ "$WIRELESS" = "true" ]; then
    install_wireless_tools
  fi
  
  # Post-exploitation tools
  if [ "$POSTEXPLOIT" = "true" ]; then
    install_postexploit_tools
  fi
  
  # Forensics & Stego tools
  if [ "$FORENSICS_STEGO" = "true" ]; then
    install_forensics_tools
  fi
  
  # Binary exploitation tools
  if [ "$BINARY_EXPLOITATION" = "true" ]; then
    install_binary_tools
  fi
  
  log_info "✓ Tool installation complete"
}

# Core tools module
install_core_tools() {
  log_progress "Installing core tools (Python, Go, Ruby base)..."
  
  # Impacket
  log_progress "Installing Impacket..."
  pip3 install impacket --break-system-packages 2>&1 | tee -a /var/log/ctfbox-install.log || pip3 install impacket 2>&1 | tee -a /var/log/ctfbox-install.log
  
  # Install pipx
  log_progress "Installing pipx..."
  if ! command -v pipx &> /dev/null; then
    apt update -qq > /dev/null 2>&1 && apt install -y pipx 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "Failed to install pipx"
  fi
  
  if command -v pipx &> /dev/null; then
    pipx ensurepath
    log_progress "Installing NetExec..."
    sudo -u "$USERNAME" pipx install git+https://github.com/Pennyw0rth/NetExec 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "NetExec failed to install"
  fi
  
  # Essential Python tools
  log_progress "Installing essential Python tools..."
  pip3 install --break-system-packages \
    hashid featherduster \
    bloodhound bloodyAD mitm6 responder certipy-ad coercer \
    pypykatz lsassy enum4linux-ng dnsrecon git-dumper \
    roadrecon manspider mitmproxy pwntools \
    ROPgadget truffleHog \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
  
  # RsaCtfTool from GitHub
  if [ ! -d "$USER_HOME/tools/repos/RsaCtfTool" ]; then
    log_progress "Installing RsaCtfTool..."
    sudo -u "$USERNAME" git clone https://github.com/RsaCtfTool/RsaCtfTool.git $USER_HOME/tools/repos/RsaCtfTool 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "RsaCtfTool clone failed"
  fi
  
  # ysoserial
  log_progress "Installing ysoserial..."
  if [ ! -f "$USER_HOME/tools/ysoserial.jar" ]; then
    if command -v java &> /dev/null; then
      sudo -u "$USERNAME" wget -q https://github.com/frohoff/ysoserial/releases/latest/download/ysoserial-all.jar -O $USER_HOME/tools/ysoserial.jar 2>/dev/null || log_warn "Failed to download ysoserial"
      
      if [ -f "$USER_HOME/tools/ysoserial.jar" ]; then
        cat > /usr/local/bin/ysoserial << 'YSOSERIAL_EOF'
#!/bin/bash
java -jar ~/tools/ysoserial.jar "$@"
YSOSERIAL_EOF
        chmod +x /usr/local/bin/ysoserial
      fi
    fi
  fi
  
  # Ruby gems
  log_progress "Installing Ruby gems (one_gadget, haiti)..."
  if command -v gem &> /dev/null; then
    gem install one_gadget haiti-hash 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "Ruby gem installation failed"
  fi
}

# Web enumeration tools module
install_web_tools() {
  log_progress "Installing web enumeration tools..."
  
  if ! command -v go &> /dev/null; then
    log_warn "Go not found - skipping Go tools"
    return
  fi
  
  log_progress "Installing ProjectDiscovery suite..."
  sudo -u "$USERNAME" bash -c 'export GOPATH=$HOME/go && \
    go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest && \
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest && \
    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest' \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
  
  log_progress "Installing other web tools..."
  sudo -u "$USERNAME" bash -c 'export GOPATH=$HOME/go && \
    go install -v github.com/ffuf/ffuf@latest && \
    go install -v github.com/OJ/gobuster/v3@latest' \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
}

# Windows/AD tools module
install_windows_tools() {
  log_progress "Installing Windows/AD tools..."
  
  # Already installed in core: NetExec, Impacket, bloodhound, bloodyAD, certipy-ad, pypykatz, lsassy
  log_info "Windows/AD tools (NetExec, Impacket, etc.) installed in core tools"
  
  # Kerberos tools
  if command -v go &> /dev/null; then
    log_progress "Installing kerbrute..."
    sudo -u "$USERNAME" bash -c 'export GOPATH=$HOME/go && go install -v github.com/ropnop/kerbrute@latest' 2>&1 | tee -a /var/log/ctfbox-install.log || true
  fi
}

# Wireless tools module
install_wireless_tools() {
  log_progress "Installing wireless tools..."
  
  DEBIAN_FRONTEND=noninteractive apt install -y \
    aircrack-ng bluez bluelog hcitool \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
}

# Post-exploitation tools module
install_postexploit_tools() {
  log_progress "Installing post-exploitation tools..."
  
  # Pivoting tools
  DEBIAN_FRONTEND=noninteractive apt install -y \
    socat rlwrap proxychains4 sshuttle \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
  
  # Chisel
  if command -v go &> /dev/null; then
    log_progress "Installing chisel..."
    sudo -u "$USERNAME" bash -c 'export GOPATH=$HOME/go && go install -v github.com/jpillora/chisel@latest' 2>&1 | tee -a /var/log/ctfbox-install.log || true
  fi
  
  # Penelope
  if [ ! -d "$USER_HOME/tools/repos/penelope" ]; then
    log_progress "Installing Penelope reverse shell handler..."
    sudo -u "$USERNAME" git clone https://github.com/brightio/penelope.git $USER_HOME/tools/repos/penelope 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "Penelope clone failed"
  fi
}

# Forensics & Stego tools module
install_forensics_tools() {
  log_progress "Installing forensics & stego tools..."
  
  DEBIAN_FRONTEND=noninteractive apt install -y \
    steghide zsteg binwalk foremost exiftool p7zip-full \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
}

# Binary exploitation tools module
install_binary_tools() {
  log_progress "Installing binary exploitation tools..."
  
  DEBIAN_FRONTEND=noninteractive apt install -y \
    gdb radare2 \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
  
  # pwntools already installed in core Python tools
  # one_gadget already installed in core Ruby gems
}

# ============================================
# PHASE 5: WORDLISTS
# ============================================
phase5_wordlists_setup() {
  log_progress "Phase: Wordlists"
  
  # SecLists
  log_progress "Downloading SecLists (~700MB, this will take a while)..."
  if [ ! -d "$USER_HOME/tools/wordlists/SecLists" ]; then
    sudo -u "$USERNAME" git clone --depth 1 https://github.com/danielmiessler/SecLists.git $USER_HOME/tools/wordlists/SecLists 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "SecLists clone failed"
  fi
  
  # Extract rockyou.txt
  if [ -f "/usr/share/wordlists/rockyou.txt.gz" ] && [ ! -f "/usr/share/wordlists/rockyou.txt" ]; then
    log_progress "Extracting rockyou.txt..."
    gunzip /usr/share/wordlists/rockyou.txt.gz
  fi
  
  # Create symlinks
  log_progress "Creating wordlist symlinks..."
  sudo -u "$USERNAME" ln -sf $USER_HOME/tools/wordlists/SecLists $USER_HOME/SecLists 2>/dev/null || true
  sudo -u "$USERNAME" ln -sf /usr/share/wordlists/rockyou.txt $USER_HOME/tools/wordlists/rockyou.txt 2>/dev/null || true
  
  log_info "✓ Wordlists setup complete"
}

# ============================================
# PHASE 6: REPOSITORIES
# ============================================
phase6_repos_setup() {
  log_progress "Phase: Repositories"
  
  clone_repo() {
    local url=$1
    local name=$(basename $url .git)
    if [ ! -d "$USER_HOME/tools/repos/$name" ]; then
      log_progress "Cloning $name..."
      sudo -u "$USERNAME" git clone $url $USER_HOME/tools/repos/$name 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "Failed to clone $name"
    fi
  }
  
  if [ "$REPOS_ESSENTIAL" = "true" ]; then
    log_progress "Cloning essential repositories..."
    clone_repo "https://github.com/swisskyrepo/PayloadsAllTheThings.git"
    clone_repo "https://github.com/peass-ng/PEASS-ng.git"
    clone_repo "https://github.com/HackTricks-wiki/HackTricks.git"
    clone_repo "https://github.com/Tib3rius/AutoRecon.git"
    clone_repo "https://github.com/fortra/impacket.git"
    clone_repo "https://github.com/projectdiscovery/nuclei-templates.git"
    clone_repo "https://github.com/internetwache/GitTools.git"
    clone_repo "https://github.com/AonCyberLabs/Windows-Exploit-Suggester.git"
    clone_repo "https://github.com/PowerShellMafia/PowerSploit.git"
  fi
  
  if [ "$REPOS_PRIVILEGE" = "true" ]; then
    log_progress "Cloning privilege escalation repositories..."
    clone_repo "https://github.com/GTFOBins/GTFOBins.github.io.git"
    clone_repo "https://github.com/LOLBAS-Project/LOLBAS.git"
  fi
  
  # Create PEASS symlinks
  if [ -d "$USER_HOME/tools/repos/PEASS-ng" ]; then
    sudo -u "$USERNAME" ln -sf $USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh $USER_HOME/linpeas.sh 2>/dev/null || true
    sudo -u "$USERNAME" ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe $USER_HOME/winpeas.exe 2>/dev/null || true
  fi
  
  # Create Penelope symlink
  if [ -d "$USER_HOME/tools/repos/penelope" ]; then
    sudo -u "$USERNAME" ln -sf $USER_HOME/tools/repos/penelope/penelope.py $USER_HOME/penelope.py 2>/dev/null || true
  fi
  
  log_info "✓ Repositories setup complete"
}

# ============================================
# PHASE 7: FIREFOX EXTENSIONS
# ============================================
phase7_firefox_extensions() {
  log_progress "Phase: Firefox Extensions"
  
  # Find Firefox profile
  FIREFOX_PROFILE=$(find $USER_HOME/.mozilla/firefox -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
  
  if [ -z "$FIREFOX_PROFILE" ]; then
    log_warn "Firefox profile not found. Starting Firefox once to create profile..."
    sudo -u "$USERNAME" timeout 5 firefox --headless 2>/dev/null || true
    sleep 2
    FIREFOX_PROFILE=$(find $USER_HOME/.mozilla/firefox -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
  fi
  
  if [ -n "$FIREFOX_PROFILE" ]; then
    log_info "Firefox profile found: $FIREFOX_PROFILE"
    sudo -u "$USERNAME" mkdir -p "$FIREFOX_PROFILE/extensions"
    
    # Download extensions
    log_progress "Installing Firefox extensions..."
    sudo -u "$USERNAME" wget -q "https://addons.mozilla.org/firefox/downloads/latest/foxyproxy-standard/latest.xpi" \
      -O "$FIREFOX_PROFILE/extensions/foxyproxy@eric.h.jung.xpi" 2>/dev/null || log_warn "Failed to download FoxyProxy"
    
    sudo -u "$USERNAME" wget -q "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi" \
      -O "$FIREFOX_PROFILE/extensions/addon@darkreader.org.xpi" 2>/dev/null || log_warn "Failed to download Dark Reader"
    
    sudo -u "$USERNAME" wget -q "https://addons.mozilla.org/firefox/downloads/latest/cookie-editor/latest.xpi" \
      -O "$FIREFOX_PROFILE/extensions/{c5f15d22-8421-4a2f-9bed-e4e2c0b560e0}.xpi" 2>/dev/null || log_warn "Failed to download Cookie-Editor"
    
    sudo -u "$USERNAME" wget -q "https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/latest.xpi" \
      -O "$FIREFOX_PROFILE/extensions/wappalyzer@crunchlabs.com.xpi" 2>/dev/null || log_warn "Failed to download Wappalyzer"
    
    log_info "Firefox extensions installed"
  else
    log_warn "Could not find or create Firefox profile"
  fi
  
  log_info "✓ Firefox extensions setup complete"
}

# ============================================
# PHASE 8: AUTOMATION & DOTFILES
# ============================================
phase8_automation_setup() {
  log_progress "Phase: Automation Scripts & Dotfiles"
  
  sudo -u "$USERNAME" mkdir -p $USER_HOME/scripts
  
  # Create .zshrc with aliases
  log_progress "Configuring .zshrc..."
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
export PATH=$PATH:$HOME/go/bin:$HOME/.local/bin

# Initialize zoxide
eval "$(zoxide init zsh)"

# Environment variables
export EDITOR=vim
export VISUAL=vim
export GOPATH=$HOME/go

# Aliases - System
alias ls='eza -h --icons'
alias ll='eza -lag --icons'
alias la='eza -a --icons'
alias l='eza -F --icons'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias h='history'
alias please='sudo'
alias rl='rlwrap nc'
alias top='btop'

# Aliases - Pentesting
alias nmap-quick='nmap -sV -sC -O'
alias nmap-full='nmap -sV -sC -O -p-'
alias nmap-udp='nmap -sU -sV'
alias serve='python3 -m http.server'
alias serve80='sudo python3 -m http.server 80'
alias myip='curl -s ifconfig.me && echo'
alias ports='netstat -tulanp'
alias listening='lsof -i -P -n | grep LISTEN'
alias hash='hashid'
alias http='httpie'
alias shell='python3 ~/penelope.py'

# Aliases - Tool shortcuts
alias nxc='netexec'
alias smb='netexec smb'
alias winrm='netexec winrm'
alias bloodhound='bloodhound-python'
alias peas='linpeas.sh'
alias secrets='gitleaks detect --source'
alias ysoserial='java -jar ~/tools/ysoserial.jar'

# Aliases - Impacket Shortcuts
alias secretsdump='secretsdump.py'
alias getnpusers='GetNPUsers.py'
alias getuserspns='GetUserSPNs.py'
alias psexec='psexec.py'
alias smbexec='smbexec.py'
alias wmiexec='wmiexec.py'

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

extract() {
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2) tar xjf $1 ;;
      *.tar.gz)  tar xzf $1 ;;
      *.bz2)     bunzip2 $1 ;;
      *.rar)     unrar e $1 ;;
      *.gz)      gunzip $1 ;;
      *.tar)     tar xf $1 ;;
      *.tbz2)    tar xjf $1 ;;
      *.tgz)     tar xzf $1 ;;
      *.zip)     unzip $1 ;;
      *.Z)       uncompress $1 ;;
      *.7z)      7z x $1 ;;
      *)         echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}
ZSH_EOF
  
  chown "$USERNAME":"$USERNAME" $USER_HOME/.zshrc
  
  # Create update script
  log_progress "Creating update-tools script..."
  cat > $USER_HOME/scripts/update-tools.sh << 'UPDATE_EOF'
#!/bin/bash
# Update all pentesting tools

echo "[+] Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "[+] Updating Python tools..."
pip3 install --upgrade --break-system-packages \
  impacket bloodhound bloodyAD certipy-ad pypykatz lsassy pwntools ROPgadget truffleHog || true

echo "[+] Updating Go tools..."
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/ffuf/ffuf@latest
go install -v github.com/OJ/gobuster/v3@latest
go install -v github.com/jpillora/chisel@latest
go install -v github.com/zricethezav/gitleaks/v8@latest

echo "[+] Updating Ruby tools..."
gem update one_gadget haiti-hash || true

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
UPDATE_EOF
  
  chmod +x $USER_HOME/scripts/update-tools.sh
  chown -R "$USERNAME":"$USERNAME" $USER_HOME/scripts
  
  # Create reset/cleanup script
  log_progress "Creating system reset script for Desktop..."
  cat > $USER_HOME/Desktop/RESET_CTF_BOX.sh << 'RESET_EOF'
#!/bin/bash

# CTF Box Reset Script
# Restores the system to post-installation state
# Archives engagement data and clears pentesting artifacts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                    CTF BOX RESET SCRIPT                       ║
║              Restore System to Clean State                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${YELLOW}⚠️  WARNING: This script will:${NC}"
echo ""
echo "  • Archive all engagement folders"
echo "  • Reset /etc/hosts to defaults"
echo "  • Clear Kerberos tickets and config"
echo "  • Clear bash/zsh history"
echo "  • Clear browser data (optional)"
echo "  • Clear cached credentials"
echo "  • Clear temporary files"
echo "  • Reset proxychains configuration"
echo "  • Clear SSH known hosts"
echo ""
echo -e "${RED}Archived data will be saved to: ~/archives/<timestamp>${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo -e "${GREEN}Reset cancelled.${NC}"
  exit 0
fi

# Check for active terminal sessions
ACTIVE_BASH=$(pgrep -u $USER bash 2>/dev/null | wc -l)
ACTIVE_ZSH=$(pgrep -u $USER zsh 2>/dev/null | wc -l)
TOTAL_TERMINALS=$((ACTIVE_BASH + ACTIVE_ZSH))

if [ $TOTAL_TERMINALS -gt 1 ]; then
  echo ""
  echo -e "${YELLOW}⚠️  WARNING: Detected $TOTAL_TERMINALS active terminal sessions!${NC}"
  echo ""
  echo "For best results:"
  echo "  1. Close all other terminal windows/tabs"
  echo "  2. Run this script from a single terminal"
  echo "  3. This ensures all command history is properly captured"
  echo ""
  read -p "Continue anyway? (y/n): " continue_multi
  if [[ "$continue_multi" != "y" && "$continue_multi" != "Y" ]]; then
    echo -e "${GREEN}Reset cancelled. Please close other terminals and try again.${NC}"
    exit 0
  fi
fi

echo ""
echo -e "${CYAN}[*] Starting system reset...${NC}"
echo ""

# Create archive directory
ARCHIVE_DIR="$HOME/archives/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$ARCHIVE_DIR"
echo -e "${GREEN}[+]${NC} Created archive directory: $ARCHIVE_DIR"

# ============================================
# 1. ARCHIVE ENGAGEMENTS
# ============================================
echo ""
echo -e "${CYAN}[1/10] Archiving engagement data...${NC}"

if [ -d "$HOME/engagements" ] && [ "$(ls -A $HOME/engagements 2>/dev/null)" ]; then
  echo -e "${YELLOW}[*]${NC} Found engagement data, creating archive..."
  tar -czf "$ARCHIVE_DIR/engagements_backup.tar.gz" -C "$HOME" engagements 2>/dev/null
  
  if [ -f "$ARCHIVE_DIR/engagements_backup.tar.gz" ]; then
    echo -e "${GREEN}[+]${NC} Engagements archived to: $ARCHIVE_DIR/engagements_backup.tar.gz"
    
    # Create index of what was archived
    echo "# Engagement Backup - $(date)" > "$ARCHIVE_DIR/ARCHIVE_INDEX.txt"
    echo "" >> "$ARCHIVE_DIR/ARCHIVE_INDEX.txt"
    echo "Archived Engagements:" >> "$ARCHIVE_DIR/ARCHIVE_INDEX.txt"
    ls -1 "$HOME/engagements" >> "$ARCHIVE_DIR/ARCHIVE_INDEX.txt" 2>/dev/null
    
    # Remove engagement folders
    rm -rf "$HOME/engagements"/*
    echo -e "${GREEN}[+]${NC} Engagement folders cleared"
  else
    echo -e "${RED}[-]${NC} Failed to create engagement archive"
  fi
else
  echo -e "${YELLOW}[*]${NC} No engagement data found, skipping..."
fi

# ============================================
# 2. RESET /etc/hosts
# ============================================
echo ""
echo -e "${CYAN}[2/10] Resetting /etc/hosts...${NC}"

# Backup current hosts file
sudo cp /etc/hosts "$ARCHIVE_DIR/hosts.backup" 2>/dev/null
echo -e "${GREEN}[+]${NC} Current /etc/hosts backed up"

# Create clean hosts file
sudo bash -c "cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1       localhost
127.0.1.1       $(hostname)

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HOSTS_EOF"

echo -e "${GREEN}[+]${NC} /etc/hosts reset to defaults"

# ============================================
# 3. CLEAR KERBEROS
# ============================================
echo ""
echo -e "${CYAN}[3/10] Clearing Kerberos tickets and config...${NC}"

# Backup krb5.conf if exists
if [ -f /etc/krb5.conf ]; then
  sudo cp /etc/krb5.conf "$ARCHIVE_DIR/krb5.conf.backup" 2>/dev/null
  echo -e "${GREEN}[+]${NC} Kerberos config backed up"
fi

# Destroy Kerberos tickets
kdestroy -A 2>/dev/null || true
sudo kdestroy -A 2>/dev/null || true
echo -e "${GREEN}[+]${NC} Kerberos tickets destroyed"

# Reset krb5.conf to minimal default
sudo bash -c 'cat > /etc/krb5.conf << "KRB_EOF"
[libdefaults]
    default_realm = EXAMPLE.COM
    dns_lookup_realm = false
    dns_lookup_kdc = false

[realms]
    EXAMPLE.COM = {
        kdc = kerberos.example.com
        admin_server = kerberos.example.com
    }

[domain_realm]
    .example.com = EXAMPLE.COM
    example.com = EXAMPLE.COM
KRB_EOF'

echo -e "${GREEN}[+]${NC} Kerberos config reset to defaults"

# Clear cached Kerberos tickets
rm -f /tmp/krb5cc_* 2>/dev/null || true
rm -f /var/tmp/krb5cc_* 2>/dev/null || true
rm -f "$HOME/.krb5/krb5cc_*" 2>/dev/null || true
echo -e "${GREEN}[+]${NC} Cached Kerberos tickets cleared"

# ============================================
# 4. CLEAR HISTORY
# ============================================
echo ""
echo -e "${CYAN}[4/10] Clearing command history (all sessions)...${NC}"

# First, force all running shells to write their history to disk
echo -e "${YELLOW}[*]${NC} Flushing history from active terminal sessions..."

# Get all bash PIDs and force them to write history
BASH_PIDS=$(pgrep -u $USER bash 2>/dev/null || true)
if [ -n "$BASH_PIDS" ]; then
  for pid in $BASH_PIDS; do
    # Send signal to flush history (doesn't close terminal)
    kill -SIGUSR1 $pid 2>/dev/null || true
  done
  echo -e "${GREEN}[+]${NC} Flushed history from $(echo $BASH_PIDS | wc -w) bash sessions"
fi

# Get all zsh PIDs and force them to write history
ZSH_PIDS=$(pgrep -u $USER zsh 2>/dev/null || true)
if [ -n "$ZSH_PIDS" ]; then
  for pid in $ZSH_PIDS; do
    kill -SIGUSR1 $pid 2>/dev/null || true
  done
  echo -e "${GREEN}[+]${NC} Flushed history from $(echo $ZSH_PIDS | wc -w) zsh sessions"
fi

# Give shells time to write history
sleep 1

# Backup all history files (including numbered backups)
echo -e "${YELLOW}[*]${NC} Backing up all history files to readable .txt format..."

# Create history archive subdirectory
mkdir -p "$ARCHIVE_DIR/command_history"

# Bash histories - combine into single txt file
if [ -f "$HOME/.bash_history" ]; then
  echo "# Bash Command History - Archived $(date)" > "$ARCHIVE_DIR/command_history/bash_history.txt"
  echo "# Main history file" >> "$ARCHIVE_DIR/command_history/bash_history.txt"
  echo "============================================" >> "$ARCHIVE_DIR/command_history/bash_history.txt"
  cat "$HOME/.bash_history" >> "$ARCHIVE_DIR/command_history/bash_history.txt" 2>/dev/null
  
  # Add numbered bash history backups
  for hist in "$HOME"/.bash_history.*; do
    if [ -f "$hist" ]; then
      echo "" >> "$ARCHIVE_DIR/command_history/bash_history.txt"
      echo "============================================" >> "$ARCHIVE_DIR/command_history/bash_history.txt"
      echo "# From: $(basename $hist)" >> "$ARCHIVE_DIR/command_history/bash_history.txt"
      echo "============================================" >> "$ARCHIVE_DIR/command_history/bash_history.txt"
      cat "$hist" >> "$ARCHIVE_DIR/command_history/bash_history.txt" 2>/dev/null
    fi
  done
  echo -e "${GREEN}[+]${NC} Bash history archived to bash_history.txt"
fi

# Zsh histories - combine into single txt file
if [ -f "$HOME/.zsh_history" ]; then
  echo "# Zsh Command History - Archived $(date)" > "$ARCHIVE_DIR/command_history/zsh_history.txt"
  echo "# Main history file" >> "$ARCHIVE_DIR/command_history/zsh_history.txt"
  echo "============================================" >> "$ARCHIVE_DIR/command_history/zsh_history.txt"
  cat "$HOME/.zsh_history" >> "$ARCHIVE_DIR/command_history/zsh_history.txt" 2>/dev/null
  
  # Add numbered zsh history backups
  for hist in "$HOME"/.zsh_history.*; do
    if [ -f "$hist" ]; then
      echo "" >> "$ARCHIVE_DIR/command_history/zsh_history.txt"
      echo "============================================" >> "$ARCHIVE_DIR/command_history/zsh_history.txt"
      echo "# From: $(basename $hist)" >> "$ARCHIVE_DIR/command_history/zsh_history.txt"
      echo "============================================" >> "$ARCHIVE_DIR/command_history/zsh_history.txt"
      cat "$hist" >> "$ARCHIVE_DIR/command_history/zsh_history.txt" 2>/dev/null
    fi
  done
  echo -e "${GREEN}[+]${NC} Zsh history archived to zsh_history.txt"
fi

# PowerShell history
if [ -f "$HOME/.local/share/powershell/PSReadLine/ConsoleHost_history.txt" ]; then
  echo "# PowerShell Command History - Archived $(date)" > "$ARCHIVE_DIR/command_history/powershell_history.txt"
  echo "============================================" >> "$ARCHIVE_DIR/command_history/powershell_history.txt"
  cat "$HOME/.local/share/powershell/PSReadLine/ConsoleHost_history.txt" >> "$ARCHIVE_DIR/command_history/powershell_history.txt" 2>/dev/null
  echo -e "${GREEN}[+]${NC} PowerShell history archived to powershell_history.txt"
fi

# Python REPL history
if [ -f "$HOME/.python_history" ]; then
  echo "# Python REPL History - Archived $(date)" > "$ARCHIVE_DIR/command_history/python_history.txt"
  echo "============================================" >> "$ARCHIVE_DIR/command_history/python_history.txt"
  cat "$HOME/.python_history" >> "$ARCHIVE_DIR/command_history/python_history.txt" 2>/dev/null
  echo -e "${GREEN}[+]${NC} Python history archived to python_history.txt"
fi

# MySQL history
if [ -f "$HOME/.mysql_history" ]; then
  echo "# MySQL CLI History - Archived $(date)" > "$ARCHIVE_DIR/command_history/mysql_history.txt"
  echo "============================================" >> "$ARCHIVE_DIR/command_history/mysql_history.txt"
  cat "$HOME/.mysql_history" >> "$ARCHIVE_DIR/command_history/mysql_history.txt" 2>/dev/null
  echo -e "${GREEN}[+]${NC} MySQL history archived to mysql_history.txt"
fi

# PostgreSQL history
if [ -f "$HOME/.psql_history" ]; then
  echo "# PostgreSQL History - Archived $(date)" > "$ARCHIVE_DIR/command_history/psql_history.txt"
  echo "============================================" >> "$ARCHIVE_DIR/command_history/psql_history.txt"
  cat "$HOME/.psql_history" >> "$ARCHIVE_DIR/command_history/psql_history.txt" 2>/dev/null
  echo -e "${GREEN}[+]${NC} PostgreSQL history archived to psql_history.txt"
fi

# Redis CLI history
if [ -f "$HOME/.rediscli_history" ]; then
  echo "# Redis CLI History - Archived $(date)" > "$ARCHIVE_DIR/command_history/redis_history.txt"
  echo "============================================" >> "$ARCHIVE_DIR/command_history/redis_history.txt"
  cat "$HOME/.rediscli_history" >> "$ARCHIVE_DIR/command_history/redis_history.txt" 2>/dev/null
  echo -e "${GREEN}[+]${NC} Redis history archived to redis_history.txt"
fi

# Less history (contains search patterns)
if [ -f "$HOME/.lesshst" ]; then
  echo "# Less Search History - Archived $(date)" > "$ARCHIVE_DIR/command_history/less_history.txt"
  echo "============================================" >> "$ARCHIVE_DIR/command_history/less_history.txt"
  cat "$HOME/.lesshst" >> "$ARCHIVE_DIR/command_history/less_history.txt" 2>/dev/null
  echo -e "${GREEN}[+]${NC} Less history archived to less_history.txt"
fi

# Create combined "all commands" file
echo "# ALL COMMAND HISTORY - Complete Archive" > "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
echo "# Archived: $(date)" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
echo "# User: $USER" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
echo "# Host: $(hostname)" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
echo "========================================" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
echo "" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"

# Append all history files to combined file
for histfile in "$ARCHIVE_DIR"/command_history/*_history.txt; do
  if [ -f "$histfile" ] && [ "$(basename $histfile)" != "ALL_COMMANDS.txt" ]; then
    echo "" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
    echo "###############################################" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
    echo "# Source: $(basename $histfile)" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
    echo "###############################################" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
    cat "$histfile" >> "$ARCHIVE_DIR/command_history/ALL_COMMANDS.txt"
  fi
done

echo -e "${GREEN}[+]${NC} Combined history created: ALL_COMMANDS.txt"
echo -e "${GREEN}[+]${NC} All command histories backed up to: $ARCHIVE_DIR/command_history/"

# Clear all history files
echo -e "${YELLOW}[*]${NC} Clearing all history files..."

# Bash
cat /dev/null > "$HOME/.bash_history" 2>/dev/null || true
for hist in "$HOME"/.bash_history.*; do
  [ -f "$hist" ] && cat /dev/null > "$hist" 2>/dev/null || true
done

# Zsh
cat /dev/null > "$HOME/.zsh_history" 2>/dev/null || true
for hist in "$HOME"/.zsh_history.*; do
  [ -f "$hist" ] && cat /dev/null > "$hist" 2>/dev/null || true
done

# PowerShell
if [ -f "$HOME/.local/share/powershell/PSReadLine/ConsoleHost_history.txt" ]; then
  cat /dev/null > "$HOME/.local/share/powershell/PSReadLine/ConsoleHost_history.txt" 2>/dev/null || true
fi

# Other tool histories
cat /dev/null > "$HOME/.python_history" 2>/dev/null || true
cat /dev/null > "$HOME/.mysql_history" 2>/dev/null || true
cat /dev/null > "$HOME/.psql_history" 2>/dev/null || true
cat /dev/null > "$HOME/.rediscli_history" 2>/dev/null || true
cat /dev/null > "$HOME/.lesshst" 2>/dev/null || true

# Clear in-memory history for current shell
history -c 2>/dev/null || true
export HISTSIZE=0
export HISTFILE=/dev/null

echo -e "${GREEN}[+]${NC} All command histories cleared"

# Clear systemd journal logs (contains command execution)
echo -e "${YELLOW}[*]${NC} Clearing systemd journal (user session logs)..."
journalctl --user --vacuum-time=1s 2>/dev/null || true

echo -e "${GREEN}[+]${NC} Command history clearing complete"

# ============================================
# 5. CLEAR CACHED CREDENTIALS
# ============================================
echo ""
echo -e "${CYAN}[5/10] Clearing cached credentials...${NC}"

# Clear responder logs and hashes
if [ -d "$HOME/.responder" ]; then
  tar -czf "$ARCHIVE_DIR/responder_logs.tar.gz" -C "$HOME" .responder 2>/dev/null
  rm -rf "$HOME/.responder"/*
  echo -e "${GREEN}[+]${NC} Responder logs cleared"
fi

# Clear NetExec/CrackMapExec databases
if [ -d "$HOME/.nxc" ]; then
  tar -czf "$ARCHIVE_DIR/nxc_databases.tar.gz" -C "$HOME" .nxc 2>/dev/null
  rm -rf "$HOME/.nxc"/*
  echo -e "${GREEN}[+]${NC} NetExec databases cleared"
fi

if [ -d "$HOME/.cme" ]; then
  tar -czf "$ARCHIVE_DIR/cme_databases.tar.gz" -C "$HOME" .cme 2>/dev/null
  rm -rf "$HOME/.cme"/*
  echo -e "${GREEN}[+]${NC} CrackMapExec databases cleared"
fi

# Clear bloodhound data
if [ -d "$HOME/.config/bloodhound" ]; then
  tar -czf "$ARCHIVE_DIR/bloodhound_data.tar.gz" -C "$HOME/.config" bloodhound 2>/dev/null
  rm -rf "$HOME/.config/bloodhound"/*
  echo -e "${GREEN}[+]${NC} BloodHound data cleared"
fi

# ============================================
# 6. CLEAR SSH KNOWN HOSTS
# ============================================
echo ""
echo -e "${CYAN}[6/10] Clearing SSH known hosts...${NC}"

if [ -f "$HOME/.ssh/known_hosts" ]; then
  cp "$HOME/.ssh/known_hosts" "$ARCHIVE_DIR/ssh_known_hosts.backup" 2>/dev/null
  cat /dev/null > "$HOME/.ssh/known_hosts"
  echo -e "${GREEN}[+]${NC} SSH known hosts cleared"
else
  echo -e "${YELLOW}[*]${NC} No SSH known hosts file found"
fi

# ============================================
# 7. RESET PROXYCHAINS
# ============================================
echo ""
echo -e "${CYAN}[7/10] Resetting proxychains configuration...${NC}"

if [ -f /etc/proxychains4.conf ]; then
  sudo cp /etc/proxychains4.conf "$ARCHIVE_DIR/proxychains4.conf.backup" 2>/dev/null
  
  sudo bash -c 'cat > /etc/proxychains4.conf << "PROXY_EOF"
# proxychains.conf - Default configuration

strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
# Add proxy here
# Examples:
# socks5  127.0.0.1 1080
# socks4  127.0.0.1 1080
# http    127.0.0.1 8080
PROXY_EOF'
  
  echo -e "${GREEN}[+]${NC} Proxychains config reset to defaults"
fi

# ============================================
# 8. CLEAR TEMPORARY FILES
# ============================================
echo ""
echo -e "${CYAN}[8/10] Clearing temporary files...${NC}"

# Clear downloads
if [ -d "$HOME/Downloads" ] && [ "$(ls -A $HOME/Downloads 2>/dev/null)" ]; then
  mkdir -p "$ARCHIVE_DIR/downloads"
  mv "$HOME/Downloads"/* "$ARCHIVE_DIR/downloads/" 2>/dev/null || true
  echo -e "${GREEN}[+]${NC} Downloads archived and cleared"
fi

# Clear desktop files (except reset script and reference guides)
if [ -d "$HOME/Desktop" ]; then
  find "$HOME/Desktop" -type f ! -name "RESET_CTF_BOX.sh" ! -name "*REFERENCE*.txt" ! -name "*GUIDE*.txt" -exec mv {} "$ARCHIVE_DIR/" \; 2>/dev/null || true
  echo -e "${GREEN}[+]${NC} Desktop files archived"
fi

# Clear temporary directories
rm -rf /tmp/nmap* 2>/dev/null || true
rm -rf /tmp/*.log 2>/dev/null || true
rm -rf "$HOME/.cache/nuclei" 2>/dev/null || true
rm -rf "$HOME/.local/share/Trash"/* 2>/dev/null || true
echo -e "${GREEN}[+]${NC} Temporary files cleared"

# ============================================
# 9. CLEAR BROWSER DATA (OPTIONAL)
# ============================================
echo ""
echo -e "${CYAN}[9/10] Browser data cleanup...${NC}"
read -p "Clear Firefox browsing history and cookies? (y/n): " clear_browser

if [[ "$clear_browser" == "y" || "$clear_browser" == "Y" ]]; then
  # Find Firefox profile
  FIREFOX_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
  
  if [ -n "$FIREFOX_PROFILE" ]; then
    # Backup Firefox profile
    tar -czf "$ARCHIVE_DIR/firefox_profile.tar.gz" -C "$HOME/.mozilla" firefox 2>/dev/null
    
    # Clear history and cookies
    rm -f "$FIREFOX_PROFILE/places.sqlite" 2>/dev/null || true
    rm -f "$FIREFOX_PROFILE/cookies.sqlite" 2>/dev/null || true
    rm -f "$FIREFOX_PROFILE/formhistory.sqlite" 2>/dev/null || true
    rm -rf "$FIREFOX_PROFILE/cache2"/* 2>/dev/null || true
    
    echo -e "${GREEN}[+]${NC} Firefox browsing data cleared"
  else
    echo -e "${YELLOW}[*]${NC} Firefox profile not found"
  fi
else
  echo -e "${YELLOW}[*]${NC} Skipping browser data cleanup"
fi

# ============================================
# 10. FINAL CLEANUP
# ============================================
echo ""
echo -e "${CYAN}[10/10] Final cleanup...${NC}"

# Clear logs that might contain sensitive info
sudo truncate -s 0 /var/log/auth.log 2>/dev/null || true
sudo truncate -s 0 /var/log/syslog 2>/dev/null || true

# Clear user-specific logs
rm -rf "$HOME/.local/share/recently-used.xbel" 2>/dev/null || true

# Sync filesystem
sync

echo -e "${GREEN}[+]${NC} Final cleanup complete"

# ============================================
# SUMMARY
# ============================================
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                  ✓ SYSTEM RESET COMPLETE!                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}SUMMARY:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Engagement data archived"
echo -e "  ${GREEN}✓${NC} /etc/hosts reset"
echo -e "  ${GREEN}✓${NC} Kerberos tickets cleared"
echo -e "  ${GREEN}✓${NC} Command history cleared"
echo -e "  ${GREEN}✓${NC} Cached credentials cleared"
echo -e "  ${GREEN}✓${NC} SSH known hosts cleared"
echo -e "  ${GREEN}✓${NC} Proxychains reset"
echo -e "  ${GREEN}✓${NC} Temporary files cleared"
echo ""
echo -e "${YELLOW}Archive Location:${NC} $ARCHIVE_DIR"
echo ""
echo -e "${CYAN}Your system is now reset to a clean state!${NC}"
echo -e "${CYAN}Ready for the next engagement! 🎯${NC}"
echo ""

# Offer to reboot
read -p "Reboot system now for a completely fresh start? (y/n): " reboot_choice
if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
  echo ""
  echo -e "${YELLOW}Rebooting in 5 seconds... (Ctrl+C to cancel)${NC}"
  sleep 5
  sudo reboot
else
  echo ""
  echo -e "${GREEN}Reset complete! No reboot requested.${NC}"
fi
RESET_EOF
  
  chmod +x $USER_HOME/Desktop/RESET_CTF_BOX.sh
  chown "$USERNAME":"$USERNAME" $USER_HOME/Desktop/RESET_CTF_BOX.sh
  
  log_info "✓ Automation & dotfiles setup complete"
}

# ============================================
# FINAL CLEANUP
# ============================================
phase_final_cleanup() {
  log_progress "Phase: Final Cleanup"
  
  log_progress "Removing unnecessary packages..."
  DEBIAN_FRONTEND=noninteractive apt autoremove -y -qq 2>&1 | tee -a /var/log/ctfbox-install.log
  
  log_progress "Cleaning package cache..."
  DEBIAN_FRONTEND=noninteractive apt autoclean -y -qq 2>&1 | tee -a /var/log/ctfbox-install.log
  
  # Fix ownership
  chown -R "$USERNAME":"$USERNAME" $USER_HOME
  
  log_info "✓ Cleanup complete"
}

# ============================================
# COMPLETION MESSAGE
# ============================================
show_completion_message() {
  clear
  echo -e "${GREEN}"
  cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              ✓ INSTALLATION COMPLETE!                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  
  echo ""
  echo -e "${GREEN}User '${USERNAME}' created with full sudo privileges${NC}"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${CYAN}NEXT STEPS:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "1. REBOOT the VM: ${YELLOW}sudo reboot${NC}"
  echo "2. Log in as '${USERNAME}'"
  echo "3. Run: ${YELLOW}~/scripts/update-tools.sh${NC} (to update everything)"
  echo "4. Create an engagement: ${YELLOW}newengagement <name>${NC}"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${CYAN}USEFUL COMMANDS:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo " ${GREEN}•${NC} newengagement <name>  : Create new engagement folder"
  echo " ${GREEN}•${NC} quickscan <target>    : Quick nmap scan"
  echo " ${GREEN}•${NC} shell <port>          : Start Penelope reverse shell handler"
  echo " ${GREEN}•${NC} z <keyword>           : Jump to directory (zoxide)"
  echo " ${GREEN}•${NC} ll                    : Modern file listing (eza)"
  echo " ${GREEN}•${NC} top                   : System monitor (btop)"
  echo " ${GREEN}•${NC} http                  : Modern cURL (httpie)"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${CYAN}IMPORTANT FILES ON DESKTOP:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo " ${GREEN}•${NC} ${YELLOW}RESET_CTF_BOX.sh${NC}     : Reset system to clean state"
  echo "                          Archives engagements, clears history,"
  echo "                          resets /etc/hosts, clears Kerberos, etc."
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo -e "${YELLOW}Installation log saved to: /var/log/ctfbox-install.log${NC}"
  echo ""
  echo -e "${GREEN}Happy Hacking! 🏴‍☠️${NC}"
  echo ""
  
  log_warn "System will reboot in 10 seconds (Ctrl+C to cancel)..."
  sleep 10
  reboot
}

# ============================================
# MAIN EXECUTION
# ============================================
main() {
  # Check if running as root
  if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
  
  # Parse command-line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --user=*)
        CLI_USERNAME="${1#*=}"
        shift
        ;;
      -u)
        CLI_USERNAME="$2"
        shift 2
        ;;
      --full)
        install_full
        exit 0
        ;;
      --install-all)
        install_all_immediate
        exit 0
        ;;
      --help|-h)
        echo "CTF Box Installer v${SCRIPT_VERSION}"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --user=<username>, -u <username>  Set username"
        echo "  --full                            Run full installation (with confirmation)"
        echo "  --install-all                     Install everything immediately (no prompts)"
        echo "  --help, -h                        Show this help"
        echo ""
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
  
  # Set username from CLI if provided
  if [[ -n "$CLI_USERNAME" ]]; then
    if validate_username "$CLI_USERNAME"; then
      USERNAME="$CLI_USERNAME"
      USER_HOME="/home/$USERNAME"
      export USERNAME USER_HOME
    else
      log_error "Invalid username provided via command line"
      exit 1
    fi
  fi
  
  # Show welcome screen and start menu
  welcome_screen
  show_main_menu
}

# Run the installer
main "$@"
