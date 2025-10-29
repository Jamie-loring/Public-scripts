#!/bin/bash

set -e

# ============================================
# CONFIGURATION
# ============================================
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

# ============================================
# LOGGING FUNCTIONS
# ============================================
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

# ============================================
# PROGRESS INDICATOR
# ============================================
show_progress() {
  local current=$1
  local total=$2
  local phase_name=$3
  local percent=$(( current * 100 / total ))
  
  local filled=$(( percent / 2 ))
  local empty=$(( 50 - filled ))
  
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  
  local remaining=$(( (total - current) * 2 ))
  local time_est=""
  if [ $remaining -eq 0 ]; then
    time_est="Complete!"
  elif [ $remaining -lt 5 ]; then
    time_est="~${remaining} min remaining"
  else
    time_est="~${remaining} min remaining"
  fi
  
  echo ""
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC} ${YELLOW}Phase ${current}/${total}:${NC} ${phase_name}"
  echo -e "${CYAN}║${NC}"
  echo -e "${CYAN}║${NC} [${GREEN}${bar}${NC}] ${GREEN}${percent}%${NC}"
  echo -e "${CYAN}║${NC}"
  echo -e "${CYAN}║${NC} ${BLUE}${time_est}${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# ============================================
# WELCOME SCREEN
# ============================================
welcome_screen() {
  clear
  
  echo -e "${CYAN}"
  cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║     ██████╗████████╗███████╗    ██████╗  ██████╗ ██╗  ██╗     ║
║    ██╔════╝╚══██╔══╝██╔════╝    ██╔══██╗██╔═══██╗╚██╗██╔╝     ║
║    ██║         ██║  █████╗      ██████╔╝██║   ██║ ╚███╔╝      ║
║    ██║         ██║  ██╔══╝      ██╔══██╗██║   ██║ ██╔██╗      ║
║    ╚██████╗    ██║  ██║         ██████╔╝╚██████╔╝██╔╝ ██╗     ║
║     ╚═════╝    ╚═╝  ╚═╝         ╚═════╝  ╚═════╝ ╚═╝  ╚═╝     ║
║                                                               ║
║            PENTESTING TOOLKIT INSTALLER                       ║
║           Clean User Creation Model                           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  
  echo ""
  echo -e "${YELLOW}[*]${NC} Welcome to the CTF Pentesting Toolkit Installer!"
  echo ""
  echo "This script will set up a complete offensive security environment with:"
  echo "  * A dedicated, non-root pentesting user profile (making it the default)"
  echo "  * Modern shell environment (Zsh + Powerlevel10k)"
  echo "  * 40+ specialized pentesting tools"
  echo ""
  
  configure_username
}

# ============================================
# USERNAME CONFIGURATION
# ============================================
validate_username() {
  local username=$1
  
  if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    log_error "Invalid username format!"
    echo "Username must:"
    echo "  - Start with lowercase letter or underscore"
    echo "  - Contain only lowercase letters, numbers, underscore, or dash"
    echo "  - Be 1-32 characters long"
    return 1
  fi
  
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
  
  while true; do
    read -p "Enter desired pentesting username [default: $DEFAULT_USERNAME]: " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USERNAME}
    
    if validate_username "$USERNAME"; then
      break
    fi
    echo ""
  done
  
  export USERNAME
  export USER_HOME="/home/$USERNAME"
  
  echo ""
  log_info "Pentesting username set to: ${GREEN}$USERNAME${NC}"
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

display_status() {
  local var_name=$1
  local var_value="${!var_name}"
  
  if [ "$var_value" = "true" ]; then
    echo -e "[${GREEN}Y${NC}]"
  else
    echo -e "[${RED}N${NC}]"
  fi
}

# ============================================
# DOCUMENTATION MENU
# ============================================
show_documentation() {
  clear
  echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║                    PENTEST BOX DOCUMENTATION                  ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo -e "${NC}"
  
  echo -e "${YELLOW}A. CUSTOM ENVIRONMENT VARIABLES & PATHS${NC}"
  echo "-------------------------------------------------------------"
  echo -e " ${GREEN}* USERNAME:${NC} ${USERNAME} (Configured pentesting user)"
  echo -e " ${GREEN}* USER_HOME:${NC} ${USER_HOME} (Home directory for \$USERNAME)"
  echo -e " ${GREEN}* GOPATH:${NC} \$HOME/go (Go tools installation directory)"
  echo -e " ${GREEN}* PATH EXTENSIONS:${NC} Go bins, Pipx bins, Impacket scripts are added to your PATH."
  
  echo ""
  echo -e "${YELLOW}B. CORE ALIASES (CLI Shorteners)${NC}"
  echo "-------------------------------------------------------------"
  echo -e " ${GREEN}* General Utilities:${NC}"
  echo "   ${CYAN}ll${NC} (ls -lah), ${CYAN}...${NC} (cd ../..), ${CYAN}c${NC} (clear), ${CYAN}h${NC} (history), ${CYAN}please${NC} (sudo), ${CYAN}rl${NC} (rlwrap nc)"
  
  echo -e " ${GREEN}* Pentesting Aliases (Network/Web):${NC}"
  echo "   ${CYAN}nmap-quick${NC} / ${CYAN}nmap-full${NC} / ${CYAN}nmap-udp${NC} (Pre-defined nmap scans)"
  echo "   ${CYAN}serve${NC} / ${CYAN}serve80${NC} (Python HTTP server on 8000/80)"
  echo "   ${CYAN}myip${NC} (curl ifconfig.me), ${CYAN}ports${NC}, ${CYAN}listening${NC}"
  echo "   ${CYAN}hash${NC} (hashid), ${CYAN}shell${NC} (python3 ~/penelope.py)"

  echo -e " ${GREEN}* Windows/AD Tool Aliases:${NC}"
  echo "   ${CYAN}nxc${NC} (netexec), ${CYAN}smb${NC} / ${CYAN}winrm${NC} (NetExec modes)"
  echo "   ${CYAN}bloodhound${NC} (bloodhound-python), ${CYAN}peas${NC} (linpeas.sh shortcut)"
  echo "   ${CYAN}secretsdump${NC}, ${CYAN}getnpusers${NC}, etc. (Impacket script shortcuts)"
  
  echo ""
  echo -e "${YELLOW}C. TOOL LOCATIONS & DIRECTORY STRUCTURE${NC}"
  echo "-------------------------------------------------------------"
  echo " ${GREEN}* Root Directory:${NC} ${CYAN}~/tools/${NC}"
  echo "   - ${CYAN}~/tools/repos/${NC}: Git clones (PayloadsAllTheThings, PEASS, HackTricks, etc.)"
  echo "   - ${CYAN}~/tools/wordlists/${NC}: SecLists, rockyou.txt"
  echo "   - ${CYAN}~/tools/scripts/${NC}: Automation scripts, including ${CYAN}update-tools.sh${NC}"
  echo "   - ${CYAN}~/tools/ysoserial.jar${NC}: Java deserialization tool"
  
  echo -e " ${GREEN}* Tool Binaries:${NC}"
  echo "   - **Python Tools:** Installed globally via pip3/pipx (e.g., NetExec, Impacket)."
  echo "   - **Go Tools:** Installed to ${CYAN}\$HOME/go/bin${NC} (e.g., nuclei, ffuf, httpx)."
  
  echo ""
  echo -e "${YELLOW}D. CUSTOM FUNCTIONS${NC}"
  echo "-------------------------------------------------------------"
  echo -e " ${GREEN}* ${CYAN}newengagement <name>${NC}:${NC} Creates a full engagement directory structure under ${CYAN}~/engagements/<name>${NC} (recon, scans, loot, notes, etc.) and CDs into it."
  echo -e " ${GREEN}* ${CYAN}quickscan <target>${NC}:${NC} Runs ${CYAN}nmap -sV -sC -O${NC} and saves output to a file with a timestamp."
  echo -e " ${GREEN}* ${CYAN}extract <file>${NC}:${NC} A universal file extraction function (handles .tar.gz, .zip, .7z, etc.)."
  
  echo ""
  read -p "Press Enter to return to the Main Menu..."
}

# ============================================
# MAIN MENU
# ============================================
show_main_menu() {
  while true; do
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║             CTF BOX INSTALLER                                 ║
║             Main Menu                                         ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}Current Target User:${NC} $USERNAME"
    echo ""
    echo "1) Install All (Everything - No Questions Asked)"
    echo "2) Full Installation (All Components - With Confirmation)"
    echo "3) Custom Installation (Choose Components)"
    echo "4) Quick Presets (Web/Windows/CTF/Minimal)"
    echo "5) Change Target Username (Current: $USERNAME)"
    echo "6) Update Existing Installation"
    echo "7) Documentation & Quick Reference"
    echo "0) Exit"
    echo ""
    read -p "Select option [0-7]: " choice
    
    case $choice in
      1) install_all_immediate ;;
      2) install_full ;;
      3) show_component_menu ;;
      4) show_presets_menu ;;
      5) configure_username ;;
      6) update_installation ;;
      7) show_documentation ;;
      0) 
        echo ""
        log_info "Exiting installer. Stay safe out there!"
        exit 0
        ;;
      *)
        log_error "Invalid option. Please select 0-7."
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
  cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                    INSTALLATION PRESETS                       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  echo ""
  echo "1) Web Pentesting (Recon, enumeration, fuzzing)"
  echo "2) Windows/AD Focus (NetExec, Impacket, Bloodhound)"
  echo "3) CTF Player (Crypto, stego, forensics, binary)"
  echo "4) Minimal Setup (Core tools only, no extras)"
  echo "5) Back to Main Menu"
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
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                    COMPONENT SELECTION                        ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo "Toggle components (Y=enabled, N=disabled):"
    echo ""
    echo "━━━━ SYSTEM SETUP ━━━━"
    
    echo -e " 1) System Updates & Base Packages         $(display_status SYSTEM_UPDATES)"
    echo -e " 2) Pentesting User Setup ($USERNAME)      $(display_status USER_SETUP)"
    echo -e " 3) Shell Environment (Zsh + p10k)         $(display_status SHELL_ENVIRONMENT)"
    
    echo ""
    echo "━━━━ TOOL CATEGORIES ━━━━"
    
    echo -e " 4) Core Tools (Python/Go/Ruby base)     $(display_status CORE_TOOLS)"
    echo -e " 5) Web Enumeration (ffuf, nuclei, etc)  $(display_status WEB_ENUMERATION)"
    echo -e " 6) Windows/AD Tools (NetExec, Impacket) $(display_status WINDOWS_AD)"
    echo -e " 7) Wireless Tools (aircrack-ng, etc)    $(display_status WIRELESS)"
    echo -e " 8) Post-Exploitation (Penelope, etc)    $(display_status POSTEXPLOIT)"
    echo -e " 9) Forensics & Stego                    $(display_status FORENSICS_STEGO)"
    echo -e "10) Binary Exploitation                  $(display_status BINARY_EXPLOITATION)"
    echo -e "11) Wordlists (SecLists, rockyou)         $(display_status WORDLISTS)"
    
    echo ""
    echo "━━━━ REPOSITORIES ━━━━"
    
    echo -e "12) Essential Repos (PayloadsAllTheThings, PEASS, HackTricks) $(display_status REPOS_ESSENTIAL)"
    echo -e "13) Privilege Escalation Repos (GTFOBins, LOLBAS)             $(display_status REPOS_PRIVILEGE)"
    
    echo ""
    echo "━━━━ EXTRAS ━━━━"
    
    echo -e "14) Firefox Extensions                   $(display_status FIREFOX_EXTENSIONS)"
    echo -e "15) Automation Scripts                   $(display_status AUTOMATION_SCRIPTS)"
    
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
  cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                    INSTALLATION SUMMARY                       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  echo ""
  echo -e "${GREEN}Target Username:${NC} $USERNAME"
  echo ""
  echo "Selected Components:"
  
  [ "$SYSTEM_UPDATES" = "true" ] && echo -e "  ${GREEN}[+]${NC} System Updates & Base Packages"
  [ "$USER_SETUP" = "true" ] && echo -e "  ${GREEN}[+]${NC} User Setup (Creation/Configuration)"
  [ "$SHELL_ENVIRONMENT" = "true" ] && echo -e "  ${GREEN}[+]${NC} Shell Environment"
  [ "$CORE_TOOLS" = "true" ] && echo -e "  ${GREEN}[+]${NC} Core Tools"
  [ "$WEB_ENUMERATION" = "true" ] && echo -e "  ${GREEN}[+]${NC} Web Enumeration"
  [ "$WINDOWS_AD" = "true" ] && echo -e "  ${GREEN}[+]${NC} Windows/AD Tools"
  [ "$WIRELESS" = "true" ] && echo -e "  ${GREEN}[+]${NC} Wireless Tools"
  [ "$POSTEXPLOIT" = "true" ] && echo -e "  ${GREEN}[+]${NC} Post-Exploitation"
  [ "$FORENSICS_STEGO" = "true" ] && echo -e "  ${GREEN}[+]${NC} Forensics & Stego"
  [ "$BINARY_EXPLOITATION" = "true" ] && echo -e "  ${GREEN}[+]${NC} Binary Exploitation"
  [ "$WORDLISTS" = "true" ] && echo -e "  ${GREEN}[+]${NC} Wordlists"
  [ "$REPOS_ESSENTIAL" = "true" ] && echo -e "  ${GREEN}[+]${NC} Essential Repositories"
  [ "$REPOS_PRIVILEGE" = "true" ] && echo -e "  ${GREEN}[+]${NC} Privilege Escalation Repos"
  [ "$FIREFOX_EXTENSIONS" = "true" ] && echo -e "  ${GREEN}[+]${NC} Firefox Extensions"
  [ "$AUTOMATION_SCRIPTS" = "true" ] && echo -e "  ${GREEN}[+]${NC} Automation Scripts"
  
  echo ""
  echo -e "${YELLOW}WARNING:${NC} This installation will take 10-30 minutes depending on your connection."
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
  
  clear
  echo -e "${CYAN}"
  cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                   ⚡ INSTALL ALL MODE ⚡                       ║
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
  cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                    UPDATE INSTALLATION                        ║
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
  echo ""
  
  # Calculate total phases
  TOTAL_PHASES=0
  [ "$SYSTEM_UPDATES" = "true" ] && TOTAL_PHASES=$(( TOTAL_PHASES + 1 ))
  [ "$USER_SETUP" = "true" ] && TOTAL_PHASES=$(( TOTAL_PHASES + 2 )) # User Creation + PAM config
  [ "$SHELL_ENVIRONMENT" = "true" ] && TOTAL_PHASES=$(( TOTAL_PHASES + 1 ))
  
  if [ "$CORE_TOOLS" = "true" ] || [ "$WEB_ENUMERATION" = "true" ] || [ "$WINDOWS_AD" = "true" ] || \
      [ "$WIRELESS" = "true" ] || [ "$POSTEXPLOIT" = "true" ] || [ "$FORENSICS_STEGO" = "true" ] || \
      [ "$BINARY_EXPLOITATION" = "true" ]; then
    TOTAL_PHASES=$(( TOTAL_PHASES + 1 ))
  fi
  
  [ "$WORDLISTS" = "true" ] && TOTAL_PHASES=$(( TOTAL_PHASES + 1 ))
  
  if [ "$REPOS_ESSENTIAL" = "true" ] || [ "$REPOS_PRIVILEGE" = "true" ]; then
    TOTAL_PHASES=$(( TOTAL_PHASES + 1 ))
  fi
  
  [ "$FIREFOX_EXTENSIONS" = "true" ] && TOTAL_PHASES=$(( TOTAL_PHASES + 1 ))
  [ "$AUTOMATION_SCRIPTS" = "true" ] && TOTAL_PHASES=$(( TOTAL_PHASES + 1 ))
  
  TOTAL_PHASES=$(( TOTAL_PHASES + 1 )) # Documentation
  
  [ "$USER_SETUP" = "true" ] && TOTAL_PHASES=$(( TOTAL_PHASES + 1 )) # Disable old user
  TOTAL_PHASES=$(( TOTAL_PHASES + 1 )) # Final cleanup
  
  # Show installation roadmap
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║              ${YELLOW}INSTALLATION ROADMAP${NC}                           ${CYAN}║${NC}"
  echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║ Total Phases: ${GREEN}${TOTAL_PHASES}${NC}                                       ${CYAN}║${NC}"
  echo -e "${CYAN}║ Estimated Time: ${GREEN}~$(( TOTAL_PHASES * 2 )) minutes${NC}                         ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Starting installation in 5 seconds...${NC}"
  sleep 5
  
  CURRENT_PHASE=0
  
  if [ "$SYSTEM_UPDATES" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "System Updates & Base Packages"
    phase1_system_setup
  fi
  
  if [ "$USER_SETUP" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "User Account Creation & Configuration"
    phase2_user_setup
    
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "Passwordless Login Configuration"
    phase3_pam_config
  fi
  
  if [ "$SHELL_ENVIRONMENT" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "Shell Environment (Zsh + Powerlevel10k)"
    phase4_shell_setup
  fi
  
  if [ "$CORE_TOOLS" = "true" ] || [ "$WEB_ENUMERATION" = "true" ] || [ "$WINDOWS_AD" = "true" ] || \
      [ "$WIRELESS" = "true" ] || [ "$POSTEXPLOIT" = "true" ] || [ "$FORENSICS_STEGO" = "true" ] || \
      [ "$BINARY_EXPLOITATION" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "Installing Pentesting Tools"
    phase5_tools_setup
  fi
  
  if [ "$WORDLISTS" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "Downloading Wordlists (SecLists ~700MB)"
    phase6_wordlists_setup
  fi
  
  if [ "$REPOS_ESSENTIAL" = "true" ] || [ "$REPOS_PRIVILEGE" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "Cloning Essential Repositories"
    phase7_repos_setup
  fi
  
  if [ "$FIREFOX_EXTENSIONS" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "Installing Firefox Extensions"
    phase8_firefox_extensions
  fi
  
  if [ "$AUTOMATION_SCRIPTS" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "Creating Automation Scripts & Dotfiles"
    phase9_automation_setup
  fi

  CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
  show_progress $CURRENT_PHASE $TOTAL_PHASES "Creating Desktop Documentation Files"
  phase10_create_documentation
  
  if [ "$USER_SETUP" = "true" ]; then
    CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
    show_progress $CURRENT_PHASE $TOTAL_PHASES "Disabling Original User Account"
    phase11_disable_old_user
  fi
  
  CURRENT_PHASE=$(( CURRENT_PHASE + 1 ))
  show_progress $CURRENT_PHASE $TOTAL_PHASES "Final Cleanup & Optimization"
  phase12_final_cleanup
  
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
  
  log_info "System setup complete"
}

# ============================================
# PHASE 2: USER SETUP
# ============================================
phase2_user_setup() {
  log_progress "Phase: User Account Creation & Configuration"

  export USER_HOME="/home/$USERNAME"
  local ORIGINAL_USER="${SUDO_USER}"

  # Check/Create New User
  if id "$USERNAME" &>/dev/null; then
    log_info "User '$USERNAME' already exists. Skipping creation."
  else
    log_warn "User '$USERNAME' does not exist. Creating new user..."
    
    log_progress "Adding user and setting home directory..."
    useradd -m -s /bin/zsh -G sudo,docker "$USERNAME" 2>&1 | tee -a /var/log/ctfbox-install.log

    log_progress "Setting user to passwordless access (via chpasswd)..."
    echo "$USERNAME:''" | chpasswd -e 2>&1 | tee -a /var/log/ctfbox-install.log
    
    log_info "User '$USERNAME' created successfully with no password set."
  fi

  # Configure Permissions and Access
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USERNAME"
  chmod 440 /etc/sudoers.d/"$USERNAME"
  log_info "Sudo NOPASSWD configured for $USERNAME."

  usermod -aG docker "$USERNAME" 2>/dev/null || true

  # Removed the shell configuration moving block from here.

  log_progress "Setting proper ownership for $USER_HOME..."
  chown -R "$USERNAME":"$USERNAME" "$USER_HOME" 2>/dev/null || true
  
  chsh -s $(which zsh) "$USERNAME" 2>/dev/null || true

  # Configure Auto-Login
  echo ""
  read -p "Set $USERNAME as automatic login user and disable login screen? (y/n): " auto_login
  
  if [[ "$auto_login" == "y" || "$auto_login" == "Y" ]]; then
      log_progress "Configuring automatic login for $USERNAME, bypassing login screen..."
      
      # LightDM configuration
      if [ -d "/etc/lightdm" ]; then
          mkdir -p /etc/lightdm/lightdm.conf.d
          cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << LIGHTDM_EOF
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
user-session=default
allow-guest=false
autologin-guest=false
LIGHTDM_EOF
          log_info "LightDM auto-login configured for $USERNAME."
      fi
      
      # GDM configuration
      if [ -f "/etc/gdm3/custom.conf" ]; then
          if ! grep -q '^\[daemon\]' /etc/gdm3/custom.conf; then
              echo -e "\n[daemon]" | sudo tee -a /etc/gdm3/custom.conf >/dev/null
          fi
          sed -i '/AutomaticLoginEnable/d' /etc/gdm3/custom.conf
          sed -i '/AutomaticLogin/d' /etc/gdm3/custom.conf
          sed -i '/^\[daemon\]/a AutomaticLoginEnable = true' /etc/gdm3/custom.conf 2>/dev/null || true
          sed -i "/^AutomaticLoginEnable/a AutomaticLogin = $USERNAME" /etc/gdm3/custom.conf 2>/dev/null || true
          sed -i '/^\[daemon\]/a TimedLoginEnable = true' /etc/gdm3/custom.conf 2>/dev/null || true
          sed -i "/^TimedLoginEnable/a TimedLogin = $USERNAME" /etc/gdm3/custom.conf 2>/dev/null || true
          sed -i "/^TimedLogin/a TimedLoginDelay = 0" /etc/gdm3/custom.conf 2>/dev/null || true
          log_info "GDM3 auto-login configured for $USERNAME."
      fi
      
      # SDDM configuration
      if [ -f "/etc/sddm.conf" ]; then
          if ! grep -q "\[Autologin\]" /etc/sddm.conf; then
              echo -e "\n[Autologin]" >> /etc/sddm.conf
          fi
          sed -i "/^\[Autologin\]/a User=$USERNAME" /etc/sddm.conf 2>/dev/null || true
          sed -i "/^\[Autologin\]/a Session=plasma" /etc/sddm.conf 2>/dev/null || true
          log_info "SDDM auto-login configured for $USERNAME."
      fi
      
      # Clear old user's session cache
      if [ -d "/home/$ORIGINAL_USER/.cache" ]; then
          log_progress "Clearing original user's session cache to prevent automatic session resume."
          rm -rf /home/"$ORIGINAL_USER"/.cache/sessions/* 2>/dev/null || true
          chown -R "$ORIGINAL_USER":"$ORIGINAL_USER" /home/"$ORIGINAL_USER"/.cache 2>/dev/null || true
      fi
      
      log_info "Auto-login configured for $USERNAME"
  fi
  
  log_info "User creation and setup complete"
}

# ============================================
# PHASE 3: PAM CONFIGURATION FOR PW-LESS LOGIN
# ============================================
phase3_pam_config() {
    log_progress "Phase: Configuring PAM for Passwordless Login"

    # Create the 'nopasswdlogin' group
    if ! grep -q '^nopasswdlogin:' /etc/group; then
        groupadd nopasswdlogin
        log_info "Created 'nopasswdlogin' group."
    fi

    # Add the new user to this group
    usermod -aG nopasswdlogin "$USERNAME" 2>&1 | tee -a /var/log/ctfbox-install.log
    log_info "Added '$USERNAME' to 'nopasswdlogin' group."

    # Modify common-auth to allow members of 'nopasswdlogin' to skip authentication
    if ! grep -q 'pam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/common-auth; then
        log_progress "Modifying /etc/pam.d/common-auth..."
        
        sed -i '/^auth.*pam_deny.so/i auth\t[success=1 default=ignore]\tpam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/common-auth
        
        log_info "PAM configuration updated for passwordless login."
    else
        log_info "PAM configuration already contains passwordless bypass."
    fi
}

# ============================================
# PHASE 4: SHELL ENVIRONMENT (FIXED)
# ============================================
phase4_shell_setup() {
  log_progress "Phase: Shell Environment (Zsh + Oh-My-Zsh + p10k)"
  log_info "Pre-configuring Zsh and Oh-My-Zsh for $USERNAME"
  
  export USER_HOME="/home/$USERNAME" # Ensure USER_HOME is set
  local TEMP_HOME="/tmp/user-setup-$USERNAME"
  rm -rf "$TEMP_HOME" 2>/dev/null || true
  mkdir -p "$TEMP_HOME"
  
  if [ ! -d "$TEMP_HOME/.oh-my-zsh" ]; then
    log_progress "Installing Oh-My-Zsh to temporary location..."
    export HOME="$TEMP_HOME"
    sh -c "RUNZSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1 | tee -a /var/log/ctfbox-install.log
    export HOME="/root" 
  fi
  
  log_progress "Installing zsh plugins..."
  git clone https://github.com/zsh-users/zsh-autosuggestions ${TEMP_HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${TEMP_HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true
  
  log_progress "Installing Powerlevel10k theme..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${TEMP_HOME}/.oh-my-zsh/custom/themes/powerlevel10k 2>/dev/null || true
  
  log_info "Downloading pre-configured Powerlevel10k config..."
  wget -q https://raw.githubusercontent.com/Jamie-loring/Public-scripts/main/p10k-jamie-config.zsh -O ${TEMP_HOME}/.p10k.zsh 2>/dev/null || log_warn "Failed to download p10k config"
  
  # FIX: Move the shell config files immediately after installation
  if [ -d "$TEMP_HOME/.oh-my-zsh" ]; then
    log_progress "Moving shell configuration to user home: $USER_HOME..."
    
    # Copy the .oh-my-zsh folder and .p10k.zsh file
    cp -r "$TEMP_HOME"/.oh-my-zsh "$USER_HOME/" 2>/dev/null || true
    cp "$TEMP_HOME"/.p10k.zsh "$USER_HOME/" 2>/dev/null || true
    
    # Set ownership for the copied files
    chown -R "$USERNAME":"$USERNAME" "$USER_HOME/.oh-my-zsh" 2>/dev/null || true
    chown "$USERNAME":"$USERNAME" "$USER_HOME/.p10k.zsh" 2>/dev/null || true

    # Clean up the temporary directory
    rm -rf "$TEMP_HOME"
    rm /tmp/shell-setup-temp-home 2>/dev/null || true
    log_info "Shell configuration successfully moved and ownership set for $USERNAME"
  else
    log_error "Failed to create temporary Oh-My-Zsh directory during installation."
  fi
  
  log_info "Shell environment setup complete."
}

# ============================================
# PHASE 5: TOOLS INSTALLATION
# ============================================
phase5_tools_setup() {
  log_progress "Phase: Tool Installation"
  
  export USER_HOME="/home/$USERNAME"
  
  log_progress "Creating tool directory structure..."
  mkdir -p $USER_HOME/tools/{wordlists,scripts,exploits,repos}
  
  if [ "$CORE_TOOLS" = "true" ]; then
    install_core_tools
  fi
  
  if [ "$WEB_ENUMERATION" = "true" ]; then
    install_web_tools
  fi
  
  if [ "$WINDOWS_AD" = "true" ]; then
    install_windows_tools
  fi
  
  if [ "$WIRELESS" = "true" ]; then
    install_wireless_tools
  fi
  
  if [ "$POSTEXPLOIT" = "true" ]; then
    install_postexploit_tools
  fi
  
  if [ "$FORENSICS_STEGO" = "true" ]; then
    install_forensics_tools
  fi
  
  if [ "$BINARY_EXPLOITATION" = "true" ]; then
    install_binary_tools
  fi
  
  log_info "Tool installation complete"
}

# Core tools module
install_core_tools() {
  log_progress "Installing core tools (Python, Go, Ruby base)..."
  
  log_progress "Installing Impacket..."
  pip3 install impacket --break-system-packages 2>&1 | tee -a /var/log/ctfbox-install.log || pip3 install impacket 2>&1 | tee -a /var/log/ctfbox-install.log
  
  log_progress "Installing pipx..."
  if ! command -v pipx &> /dev/null; then
    apt update -qq > /dev/null 2>&1 && apt install -y pipx 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "Failed to install pipx"
  fi
  
  if command -v pipx &> /dev/null; then
    pipx ensurepath
    log_progress "Installing NetExec..."
    pipx install git+https://github.com/Pennyw0rth/NetExec 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "NetExec failed to install"
  fi
  
  log_progress "Installing essential Python tools..."
  pip3 install --break-system-packages \
    hashid featherduster \
    bloodhound bloodyAD mitm6 responder certipy-ad coercer \
    pypykatz lsassy enum4linux-ng dnsrecon git-dumper \
    roadrecon manspider mitmproxy pwntools \
    ROPgadget truffleHog \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
  
  if [ ! -d "$USER_HOME/tools/repos/RsaCtfTool" ]; then
    log_progress "Installing RsaCtfTool..."
    git clone https://github.com/RsaCtfTool/RsaCtfTool.git $USER_HOME/tools/repos/RsaCtfTool 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "RsaCtfTool clone failed"
  fi
  
  log_progress "Installing ysoserial..."
  if [ ! -f "$USER_HOME/tools/ysoserial.jar" ]; then
    if command -v java &> /dev/null; then
      wget -q https://github.com/frohoff/ysoserial/releases/latest/download/ysoserial-all.jar -O $USER_HOME/tools/ysoserial.jar 2>/dev/null || log_warn "Failed to download ysoserial"
      
      if [ -f "$USER_HOME/tools/ysoserial.jar" ]; then
        cat > /usr/local/bin/ysoserial << 'YSOSERIAL_EOF'
#!/bin/bash
java -jar /home/$SUDO_USER/tools/ysoserial.jar "$@" 
YSOSERIAL_EOF
        chmod +x /usr/local/bin/ysoserial
      fi
    fi
  fi
  
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
  
  export GOPATH=$USER_HOME/go
  mkdir -p $GOPATH/bin
  
  log_progress "Installing ProjectDiscovery suite..."
  bash -c "go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest && \
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest && \
    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest" \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
  
  log_progress "Installing other web tools..."
  bash -c "go install -v github.com/ffuf/ffuf@latest && \
    go install -v github.com/OJ/gobuster/v3@latest" \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
}

# Windows/AD tools module
install_windows_tools() {
  log_progress "Installing Windows/AD tools..."
  
  log_info "Windows/AD tools (NetExec, Impacket, etc.) installed in core tools"
  
  if command -v go &> /dev/null; then
    log_progress "Installing kerbrute..."
    bash -c "export GOPATH=$USER_HOME/go && go install -v github.com/ropnop/kerbrute@latest" 2>&1 | tee -a /var/log/ctfbox-install.log || true
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
  
  DEBIAN_FRONTEND=noninteractive apt install -y \
    socat rlwrap proxychains4 sshuttle \
    2>&1 | tee -a /var/log/ctfbox-install.log || true
  
  if command -v go &> /dev/null; then
    log_progress "Installing chisel..."
    bash -c "export GOPATH=$USER_HOME/go && go install -v github.com/jpillora/chisel@latest" 2>&1 | tee -a /var/log/ctfbox-install.log || true
  fi
  
  if [ ! -d "$USER_HOME/tools/repos/penelope" ]; then
    log_progress "Installing Penelope reverse shell handler..."
    git clone https://github.com/brightio/penelope.git $USER_HOME/tools/repos/penelope 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "Penelope clone failed"
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
}

# ============================================
# PHASE 6: WORDLISTS
# ============================================
phase6_wordlists_setup() {
  log_progress "Phase: Wordlists"
  
  log_progress "Downloading SecLists (~700MB, this will take a while)..."
  if [ ! -d "$USER_HOME/tools/wordlists/SecLists" ]; then
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git $USER_HOME/tools/wordlists/SecLists 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "SecLists clone failed"
  fi
  
  if [ -f "/usr/share/wordlists/rockyou.txt.gz" ] && [ ! -f "/usr/share/wordlists/rockyou.txt" ]; then
    log_progress "Extracting rockyou.txt..."
    gunzip /usr/share/wordlists/rockyou.txt.gz
  fi
  
  log_progress "Creating wordlist symlinks..."
  ln -sf $USER_HOME/tools/wordlists/SecLists $USER_HOME/SecLists 2>/dev/null || true
  ln -sf /usr/share/wordlists/rockyou.txt $USER_HOME/tools/wordlists/rockyou.txt 2>/dev/null || true
  
  log_info "Wordlists setup complete"
}

# ============================================
# PHASE 7: REPOSITORIES
# ============================================
phase7_repos_setup() {
  log_progress "Phase: Repositories"
  
  clone_repo() {
    local url=$1
    local name=$(basename $url .git)
    if [ ! -d "$USER_HOME/tools/repos/$name" ]; then
      log_progress "Cloning $name..."
      git clone $url $USER_HOME/tools/repos/$name 2>&1 | tee -a /var/log/ctfbox-install.log || log_warn "Failed to clone $name"
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
  
  if [ -d "$USER_HOME/tools/repos/PEASS-ng" ]; then
    ln -sf $USER_HOME/tools/repos/PEASS-ng/linPEAS/linpeas.sh $USER_HOME/linpeas.sh 2>/dev/null || true
    ln -sf $USER_HOME/tools/repos/PEASS-ng/winPEAS/winPEASx64.exe $USER_HOME/winpeas.exe 2>/dev/null || true
  fi
  
  if [ -d "$USER_HOME/tools/repos/penelope" ]; then
    ln -sf $USER_HOME/tools/repos/penelope/penelope.py $USER_HOME/penelope.py 2>/dev/null || true
  fi
  
  log_info "Repositories setup complete"
}

# ============================================
# PHASE 8: FIREFOX EXTENSIONS
# ============================================
phase8_firefox_extensions() {
  log_progress "Phase: Firefox Extensions"
  
  FIREFOX_PROFILE=$(find $USER_HOME/.mozilla/firefox -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
  
  if [ -z "$FIREFOX_PROFILE" ]; then
    log_warn "Firefox profile not found. Attempting to create profile for $USERNAME..."
    su - "$USERNAME" -c "timeout 5 firefox --headless" 2>/dev/null || true
    sleep 2
    FIREFOX_PROFILE=$(find $USER_HOME/.mozilla/firefox -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
  fi
  
  if [ -n "$FIREFOX_PROFILE" ]; then
    log_info "Firefox profile found: $FIREFOX_PROFILE"
    mkdir -p "$FIREFOX_PROFILE/extensions"
    
    log_progress "Installing Firefox extensions..."
    wget -q "https://addons.mozilla.org/firefox/downloads/latest/foxyproxy-standard/latest.xpi" \
      -O "$FIREFOX_PROFILE/extensions/foxyproxy@eric.h.jung.xpi" 2>/dev/null || log_warn "Failed to download FoxyProxy"
    
    wget -q "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi" \
      -O "$FIREFOX_PROFILE/extensions/addon@darkreader.org.xpi" 2>/dev/null || log_warn "Failed to download Dark Reader"
    
    wget -q "https://addons.mozilla.org/firefox/downloads/latest/cookie-editor/latest.xpi" \
      -O "$FIREFOX_PROFILE/extensions/{c5f15d22-8421-4a2f-9bed-e4e2c0b560e0}.xpi" 2>/dev/null || log_warn "Failed to download Cookie-Editor"
    
    wget -q "https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/latest.xpi" \
      -O "$FIREFOX_PROFILE/extensions/wappalyzer@crunchlabs.com.xpi" 2>/dev/null || log_warn "Failed to download Wappalyzer"
    
    log_info "Firefox extensions installed"
  else
    log_warn "Could not find or create Firefox profile"
  fi
  
  log_info "Firefox extensions setup complete"
}

# ============================================
# PHASE 9: AUTOMATION & DOTFILES
# ============================================
phase9_automation_setup() {
  log_progress "Phase: Automation Scripts & Dotfiles"
  
  mkdir -p $USER_HOME/scripts
  
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

# Initialize zoxide (if installed)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# Environment variables
export EDITOR=vim
export VISUAL=vim
export GOPATH=$HOME/go

# Aliases - System
alias ls='ls -h --color=auto'
alias ll='ls -lah'
alias la='ls -a'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias h='history'
alias please='sudo'
alias rl='rlwrap nc'

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
      *.tar.gz)  tar xzf $1 ;;
      *.bz2)     bunzip2 $1 ;;
      *.rar)     unrar e $1 ;;
      *.gz)      gunzip $1 ;;
      *.tar)     tar xf $1 ;;
      *.tbz2)    tar xjf $1 ;;
      *.tgz)     tar xzf $1 ;;
      *.zip)     unzip $1 ;;
      *.Z)       uncompress $1 ;;
      *.7z)      7z x $1 ;;
      *)         echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}
ZSH_EOF
  
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
  
  log_progress "Creating system reset script for Desktop..."
  mkdir -p $USER_HOME/Desktop
  
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
║                                                               ║
║                    CTF BOX RESET SCRIPT                       ║
║              Restore System to Clean State                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${YELLOW}WARNING: This script will:${NC}"
echo ""
echo "  * Archive all engagement folders"
echo "  * Reset /etc/hosts to defaults"
echo "  * Clear Kerberos tickets and config"
echo "  * Clear and archive bash/zsh history"
echo "  * Clear browser data (optional)"
echo "  * Clear cached credentials"
echo "  * Clear temporary files"
echo "  * Reset proxychains configuration"
echo "  * Clear SSH known hosts"
echo ""
echo -e "${RED}Archived data will be saved to: ~/archives/<timestamp>${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo -e "${GREEN}Reset cancelled.${NC}"
  exit 0
fi

echo ""
echo -e "${CYAN}[*] Starting system reset...${NC}"
echo ""

ARCHIVE_DIR="$HOME/archives/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$ARCHIVE_DIR"
echo -e "${GREEN}[+]${NC} Created archive directory: $ARCHIVE_DIR"

echo ""
echo -e "${CYAN}[1/10] Archiving engagement data...${NC}"

if [ -d "$HOME/engagements" ] && [ "$(ls -A $HOME/engagements 2>/dev/null)" ]; then
  echo -e "${YELLOW}[*]${NC} Found engagement data, creating archive..."
  tar -czf "$ARCHIVE_DIR/engagements_backup.tar.gz" -C "$HOME" engagements 2>/dev/null
  
  if [ -f "$ARCHIVE_DIR/engagements_backup.tar.gz" ]; then
    echo -e "${GREEN}[+]${NC} Engagements archived"
    rm -rf "$HOME/engagements"/*
    echo -e "${GREEN}[+]${NC} Engagement folders cleared"
  fi
else
  echo -e "${YELLOW}[*]${NC} No engagement data found"
fi

echo ""
echo -e "${CYAN}[2/10] Resetting /etc/hosts...${NC}"
sudo cp /etc/hosts "$ARCHIVE_DIR/hosts.backup" 2>/dev/null
sudo bash -c "cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1       localhost
127.0.1.1       \$(hostname)

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HOSTS_EOF"
echo -e "${GREEN}[+]${NC} /etc/hosts reset to defaults"

echo ""
echo -e "${CYAN}[3/10] Clearing Kerberos tickets...${NC}"
kdestroy -A 2>/dev/null || true
sudo kdestroy -A 2>/dev/null || true
rm -f /tmp/krb5cc_* 2>/dev/null || true
echo -e "${GREEN}[+]${NC} Kerberos tickets cleared"

echo ""
echo -e "${CYAN}[4/10] Clearing command history...${NC}"
mkdir -p "$ARCHIVE_DIR/command_history"

if [ -f "$HOME/.bash_history" ]; then
  cp "$HOME/.bash_history" "$ARCHIVE_DIR/command_history/bash_history.txt" 2>/dev/null
  cat /dev/null > "$HOME/.bash_history"
fi

if [ -f "$HOME/.zsh_history" ]; then
  cp "$HOME/.zsh_history" "$ARCHIVE_DIR/command_history/zsh_history.txt" 2>/dev/null
  cat /dev/null > "$HOME/.zsh_history"
fi

history -c 2>/dev/null || true
echo -e "${GREEN}[+]${NC} Command histories cleared"

echo ""
echo -e "${CYAN}[5/10] Clearing cached credentials...${NC}"
rm -rf "$HOME/.responder"/* 2>/dev/null || true
rm -rf "$HOME/.nxc"/* 2>/dev/null || true
rm -rf "$HOME/.cme"/* 2>/dev/null || true
echo -e "${GREEN}[+]${NC} Cached credentials cleared"

echo ""
echo -e "${CYAN}[6/10] Clearing SSH known hosts...${NC}"
if [ -f "$HOME/.ssh/known_hosts" ]; then
  cp "$HOME/.ssh/known_hosts" "$ARCHIVE_DIR/ssh_known_hosts.backup" 2>/dev/null
  cat /dev/null > "$HOME/.ssh/known_hosts"
  echo -e "${GREEN}[+]${NC} SSH known hosts cleared"
fi

echo ""
echo -e "${CYAN}[7/10] Resetting proxychains...${NC}"
if [ -f /etc/proxychains4.conf ]; then
  sudo cp /etc/proxychains4.conf "$ARCHIVE_DIR/proxychains4.conf.backup" 2>/dev/null
  echo -e "${GREEN}[+]${NC} Proxychains config backed up"
fi

echo ""
echo -e "${CYAN}[8/10] Clearing temporary files...${NC}"
rm -rf /tmp/nmap* 2>/dev/null || true
rm -rf "$HOME/.cache/nuclei" 2>/dev/null || true
rm -rf "$HOME/.local/share/Trash"/* 2>/dev/null || true
echo -e "${GREEN}[+]${NC} Temporary files cleared"

echo ""
echo -e "${CYAN}[9/10] Browser data cleanup...${NC}"
read -p "Clear Firefox history and cookies? (y/n): " clear_browser

if [[ "$clear_browser" == "y" || "$clear_browser" == "Y" ]]; then
  FIREFOX_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
  if [ -n "$FIREFOX_PROFILE" ]; then
    rm -f "$FIREFOX_PROFILE/places.sqlite" 2>/dev/null || true
    rm -f "$FIREFOX_PROFILE/cookies.sqlite" 2>/dev/null || true
    echo -e "${GREEN}[+]${NC} Firefox data cleared"
  fi
fi

echo ""
echo -e "${CYAN}[10/10] Final cleanup...${NC}"
sync
echo -e "${GREEN}[+]${NC} Cleanup complete"

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                 [+] SYSTEM RESET COMPLETE!                    ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${YELLOW}Archive Location:${NC} $ARCHIVE_DIR"
echo ""
echo -e "${CYAN}Your system is now reset to a clean state!${NC}"
echo -e "${CYAN}Ready for the next engagement!${NC}"
echo ""

read -p "Reboot system now? (y/n): " reboot_choice
if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
  echo ""
  echo -e "${YELLOW}Rebooting in 5 seconds...${NC}"
  sleep 5
  sudo reboot
fi
RESET_EOF
  
  chmod +x $USER_HOME/Desktop/RESET_CTF_BOX.sh
  
  log_info "Automation & dotfiles setup complete"
}

# ============================================
# PHASE 10: CREATE DOCUMENTATION FILES
# ============================================
phase10_create_documentation() {
  log_progress "Phase: Creating Documentation and Quick Reference Files"
  
  mkdir -p "$USER_HOME/Desktop"
  
  cat > "$USER_HOME/Desktop/COMMANDS.txt" << 'DOC_COMMANDS_EOF'
CTF Box Quick Command Reference
-----------------------------------------

This is a list of custom aliases and functions configured in your ~/.zshrc file.

I. CUSTOM FUNCTIONS
-------------------
newengagement <name>    Creates a standardized engagement folder structure:
                        ~/engagements/<name>/{recon,scans,exploits,loot,notes,screenshots}
quickscan <target>      Runs a quick Nmap scan (-sV -sC -O) and saves output with a timestamp.
extract <file>          Universal extraction tool for archives (.zip, .tar.gz, .7z, etc.).

II. GENERAL ALIASES
-------------------
ll                      ls -lah (Detailed listing)
la                      ls -a (List all files)
...                     cd ../..
please                  sudo (Use 'please apt update')
rl                      rlwrap nc (Netcat with history/arrow keys)
c                       clear

III. PENTESTING ALIASES
-----------------------
nmap-quick              nmap -sV -sC -O
nmap-full               nmap -sV -sC -O -p-
nmap-udp                nmap -sU -sV
serve                   python3 -m http.server (Starts HTTP server on 8000)
serve80                 sudo python3 -m http.server 80
myip                    curl -s ifconfig.me (Get external IP)
ports                   netstat -tulanp
listening               lsof -i -P -n | grep LISTEN
hash                    hashid
shell                   python3 ~/penelope.py (Penelope handler shortcut)

IV. WINDOWS / AD ALIASES
--------------------------
nxc                     netexec
smb                     netexec smb
winrm                   netexec winrm
bloodhound              bloodhound-python
secretsdump             secretsdump.py
getnpusers              GetNPUsers.py
getuserspns             GetUserSPNs.py
psexec                  psexec.py
peas                    linpeas.sh (Shortcut to ~/linpeas.sh symlink)
DOC_COMMANDS_EOF

  cat > "$USER_HOME/Desktop/TOOL_LOCATIONS.txt" << TOOL_LOCATIONS_EOF
CTF Box Tool Location & Environment Reference
------------------------------------------------------------

I. USER ENVIRONMENT
-------------------
USER:       $USERNAME
HOME:       $USER_HOME
GOPATH:     $USER_HOME/go
SUDO:       NOPASSWD is configured via /etc/sudoers.d/$USERNAME.

II. TOOL DIRECTORY STRUCTURE
----------------------------
All manually installed tools, wordlists, and repos reside here:

~/tools/
|-- repos/              (GitHub clones: PayloadsAllTheThings, PEASS, HackTricks, etc.)
|-- wordlists/          (SecLists, rockyou.txt)
|-- scripts/            (Automation scripts: update-tools.sh)
|-- ysoserial.jar       (Java deserialization payload generator)

III. TOOL ACCESS METHODS
------------------------
* Go Tools (nuclei, ffuf, httpx, naabu, chisel): 
  Installed to \$HOME/go/bin/. Accessible directly from PATH.

* Python Tools (impacket scripts, NetExec, Bloodhound-Python): 
  Installed globally or via pipx. Accessible directly via tool name (e.g., netexec, secretsdump.py).

IV. KEY CONFIGURATION FILES
---------------------------
Shell Config:       ~/.zshrc and ~/.p10k.zsh
Installer Config:   ~/.ctfbox.conf
Update Script:      ~/scripts/update-tools.sh 
System Reset:       ~/Desktop/RESET_CTF_BOX.sh (Use to clean up after an engagement)

TOOL_LOCATIONS_EOF

  chown "$USERNAME":"$USERNAME" "$USER_HOME/Desktop/COMMANDS.txt" 2>/dev/null || true
  chown "$USERNAME":"$USERNAME" "$USER_HOME/Desktop/TOOL_LOCATIONS.txt" 2>/dev/null || true
  
  log_info "Documentation files created on the Desktop."
}

# ============================================
# PHASE 11: DISABLE ORIGINAL USER ACCOUNT
# ============================================
phase11_disable_old_user() {
  log_progress "Phase: Disabling Original User Account"
  
  local ORIGINAL_USER="${SUDO_USER}"
  
  if [ -z "$ORIGINAL_USER" ] || [ "$ORIGINAL_USER" = "root" ]; then
    log_warn "Could not reliably determine original user or running as root. Skipping."
    return 
  fi
  
  if [ "$ORIGINAL_USER" = "$USERNAME" ]; then
    log_info "Original user is the same as new user ('$USERNAME'). No disabling action needed."
    return
  fi
  
  log_warn "Disabling original user '$ORIGINAL_USER' to enforce new default profile..."

  log_progress "Locking password for $ORIGINAL_USER."
  usermod -L "$ORIGINAL_USER" 2>&1 | tee -a /var/log/ctfbox-install.log
  
  log_progress "Setting shell to /sbin/nologin to disable terminal login."
  usermod -s /sbin/nologin "$ORIGINAL_USER" 2>&1 | tee -a /var/log/ctfbox-install.log

  log_info "Original user '$ORIGINAL_USER' is now fully disabled and cannot log in."
}

# ============================================
# PHASE 12: FINAL CLEANUP
# ============================================
phase12_final_cleanup() {
  log_progress "Phase: Final Cleanup & Optimization"
  
  log_progress "Setting final ownership for all user files..."
  chown -R "$USERNAME":"$USERNAME" "$USER_HOME" 2>/dev/null || true
  
  log_progress "Cleaning up temporary files..."
  rm -f /tmp/shell-setup-temp-home 2>/dev/null || true
  
  log_progress "Cleaning apt cache..."
  apt autoremove -y -qq 2>/dev/null || true
  apt clean -qq 2>/dev/null || true
  
  log_info "Final cleanup complete"
}

# ============================================
# COMPLETION MESSAGE
# ============================================
show_completion_message() {
  clear
  
  echo -e "${GREEN}"
  cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          🎉 CTF BOX INSTALLATION COMPLETE! 🎉                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}Installation Summary${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${YELLOW}Pentesting User:${NC} ${GREEN}$USERNAME${NC}"
  echo -e "${YELLOW}Home Directory:${NC} ${GREEN}$USER_HOME${NC}"
  echo -e "${YELLOW}Configuration:${NC} ${GREEN}$CONFIG_FILE${NC}"
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}Quick Start Guide${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${YELLOW}1. Documentation:${NC}"
  echo "   - Desktop files: COMMANDS.txt, TOOL_LOCATIONS.txt"
  echo "   - In-terminal: Run installer and select option 7"
  echo ""
  echo -e "${YELLOW}2. Update Tools:${NC}"
  echo "   - Run: ${CYAN}~/scripts/update-tools.sh${NC}"
  echo "   - Or: Installer menu option 6"
  echo ""
  echo -e "${YELLOW}3. Reset System:${NC}"
  echo "   - Run: ${CYAN}~/Desktop/RESET_CTF_BOX.sh${NC}"
  echo "   - Archives data and cleans artifacts"
  echo ""
  echo -e "${YELLOW}4. Key Aliases:${NC}"
  echo "   - ${CYAN}newengagement <name>${NC} - Create engagement structure"
  echo "   - ${CYAN}quickscan <target>${NC} - Quick nmap scan"
  echo "   - ${CYAN}nxc smb <target>${NC} - NetExec SMB enumeration"
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${GREEN}[+]${NC} Installation log: ${CYAN}/var/log/ctfbox-install.log${NC}"
  echo -e "${GREEN}[+]${NC} Config file: ${CYAN}$CONFIG_FILE${NC}"
  echo ""
  
  if [ "$USER_SETUP" = "true" ]; then
    echo -e "${YELLOW}⚠  IMPORTANT:${NC} Please ${GREEN}reboot${NC} your system to apply all changes!"
    echo ""
    read -p "Reboot now? (y/n): " reboot_choice
    if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
      echo ""
      echo -e "${YELLOW}Rebooting in 5 seconds...${NC}"
      sleep 5
      reboot
    fi
  fi
  
  echo ""
  echo -e "${GREEN}Happy Hacking! 🚀${NC}"
  echo ""
}

# ============================================
# SCRIPT ENTRY POINT
# ============================================
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root or with sudo${NC}"
  exit 1
fi

welcome_screen
show_main_menu
