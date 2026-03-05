#!/bin/bash
# ========================================================================
# MacUpdateGuard v4.2
# Author: bili_25396444320 (c) 2025
# Purpose: macOS system update management utility
# Updated: March 5, 2026
# ========================================================================

# -------------------------- Global Configuration --------------------------
readonly SCRIPT_VERSION="4.2"
readonly HOSTS_BLOCK_START="# BEGIN MacUpdateGuard update block"
readonly HOSTS_BLOCK_END="# END MacUpdateGuard update block"
readonly DEFAULT_DOMAIN_LIST=(
    "swscan.apple.com"
    "mesu.apple.com"
    "swdist.apple.com"
    "swcdn.apple.com"
    "gdmf.apple.com"
    "xp.apple.com"
)

# Color definitions
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_NC='\033[0m'

# -------------------------- Runtime State ---------------------------------
INSTALLED=false
INSTALL_PATH=""
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# -------------------------- Core Functions --------------------------------
function main() {
    verify_privileges
    check_installation
    display_header

    while true; do
        show_main_menu
        read -r -p "Choose an option (1-5): " choice

        case $choice in
            1) disable_system_updates ;;
            2) restore_system_updates ;;
            3) check_system_status ;;
            4) show_version_info ;;
            5) graceful_exit ;;
            *) handle_invalid_input ;;
        esac

        echo "============================================================"
    done
}

# -------------------------- Privilege Management --------------------------
function verify_privileges() {
    if [[ $(id -u) != "0" ]]; then
        echo -e "${COLOR_RED}Error: Administrator privileges are required${COLOR_NC}" >&2
        echo "Please run: sudo \"$0\"" >&2
        exit 1
    fi
}

# -------------------------- Installation Management -----------------------
function check_installation() {
    local script_dir
    script_dir="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

    if [[ "$script_dir" =~ ^/Users/ ]]; then
        INSTALLED=true
        INSTALL_PATH="$SCRIPT_PATH"
        return
    fi

    echo "Script is not running from a user directory"
    echo "------------------------------------------------------------"
    echo "For best experience, install it under your user home"
    echo "Please choose an action:"
    echo "1. Auto-install to user home and launch (recommended)"
    echo "2. Continue from current location"
    echo "3. Exit"
    echo ""

    read -r -p "Choose an option (1-3): " install_choice

    case $install_choice in
        1) auto_install ;;
        2)
            echo "Continuing from current location..."
            INSTALL_PATH="$SCRIPT_PATH"
            ;;
        3) exit 0 ;;
        *) auto_install ;;
    esac
}

function auto_install() {
    local current_user="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
    local user_home="/Users/$current_user"

    if [[ ! -d "$user_home" ]]; then
        user_home="$HOME"
    fi

    INSTALL_PATH="$user_home/MacUpdateGuard.sh"

    echo "Starting automatic installation..."
    echo "------------------------------------------------------------"

    cp "$SCRIPT_PATH" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"
    chown "$current_user":staff "$INSTALL_PATH" 2>/dev/null || true

    echo "Installation complete! Location: $INSTALL_PATH"
    echo "Launching script..."
    echo "------------------------------------------------------------"

    exec "$INSTALL_PATH"
}

# -------------------------- Update Management -----------------------------
function disable_system_updates() {
    echo "Disabling automatic system updates..."
    echo "------------------------------------------------------------"

    execute_disable_actions

    echo "------------------------------------------------------------"
    echo -e "${COLOR_GREEN}System updates have been disabled successfully${COLOR_NC}"
    echo "Tip: Restart your Mac to ensure all changes fully apply"

    system_action_menu
}

function restore_system_updates() {
    echo "Restoring system update functionality..."
    echo "------------------------------------------------------------"

    execute_restore_actions

    echo "------------------------------------------------------------"
    echo -e "${COLOR_GREEN}System updates have been restored successfully${COLOR_NC}"
    echo "Tip: Restart your Mac to ensure all changes fully apply"

    refresh_system_services

    system_action_menu
}

# -------------------------- Operation Functions ---------------------------
function execute_disable_actions() {
    echo "Turning off update schedule..."
    softwareupdate --schedule off >/dev/null 2>&1

    echo "Disabling all automatic update preferences..."
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled -bool FALSE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticDownload -bool FALSE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall -bool FALSE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall -bool FALSE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates -bool FALSE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticInstallation -bool FALSE

    echo "Cleaning update cache files..."
    rm -rf /Library/Caches/com.apple.SoftwareUpdate/ 2>/dev/null
    find /private/var/folders -name "com.apple.SoftwareUpdate" -exec rm -rf {} + 2>/dev/null

    create_hosts_backup
    configure_hosts_block

    refresh_system_services

    echo "Stopping update services..."
    launchctl disable system/com.apple.softwareupdated >/dev/null 2>&1
    launchctl stop system/com.apple.softwareupdated >/dev/null 2>&1
    launchctl unload -w /System/Library/LaunchDaemons/com.apple.softwareupdated.plist >/dev/null 2>&1

    echo "Disabling power-triggered update checks..."
    pmset -a powernap 0 >/dev/null 2>&1
    pmset -a womp 0 >/dev/null 2>&1
    pmset -a darkwakes 0 >/dev/null 2>&1

    echo "Clearing notification badges..."
    defaults write com.apple.systempreferences AttentionPrefBundleIDs 0
    killall Dock >/dev/null 2>&1
    killall usernoted >/dev/null 2>&1

    echo "Performing deep cache cleanup..."
    rm -rf /Library/Updates/* 2>/dev/null
    rm -f /var/db/softwareupdate/* 2>/dev/null

    echo "Removing software update badge markers..."
    rm -f /var/db/SoftwareUpdate.badge 2>/dev/null
    rm -f /Library/Preferences/com.apple.preferences.softwareupdate.plist 2>/dev/null
    rm -f /var/db/softwareupdate/preferences.plist 2>/dev/null
    rm -f /private/var/db/softwareupdate/preferences.plist 2>/dev/null

    echo "Stopping related update processes..."
    killall softwareupdated 2>/dev/null
    killall softwareupdated_notify_agent 2>/dev/null

    echo "Resetting software update ignore list..."
    softwareupdate --reset-ignored >/dev/null 2>&1
}

function execute_restore_actions() {
    restore_hosts_backup

    echo "Enabling update schedule..."
    softwareupdate --schedule on >/dev/null 2>&1

    echo "Restoring all automatic update preferences..."
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled -bool TRUE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticDownload -bool TRUE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall -bool TRUE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall -bool TRUE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates -bool TRUE
    defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticInstallation -bool TRUE

    echo "Starting update services..."
    launchctl enable system/com.apple.softwareupdated >/dev/null 2>&1
    launchctl start system/com.apple.softwareupdated >/dev/null 2>&1
    launchctl load -w /System/Library/LaunchDaemons/com.apple.softwareupdated.plist >/dev/null 2>&1

    echo "Restoring power-related settings..."
    pmset -a powernap 1 >/dev/null 2>&1
    pmset -a womp 1 >/dev/null 2>&1
    pmset -a darkwakes 1 >/dev/null 2>&1

    echo "Cleaning recovery cache..."
    rm -rf /Library/Caches/com.apple.SoftwareUpdate/ 2>/dev/null

    refresh_system_services

    echo "Resetting update badge marker..."
    touch /var/db/SoftwareUpdate.badge
    chmod 644 /var/db/SoftwareUpdate.badge
}

# -------------------------- Helper Functions ------------------------------
function create_hosts_backup() {
    local timestamp
    local backup_file

    timestamp=$(date +%Y%m%d%H%M%S)
    backup_file="/etc/hosts.bak_$timestamp"

    cp /etc/hosts "$backup_file"
    echo "Created hosts backup: ${backup_file##*/}"
}

function restore_hosts_backup() {
    if ls /etc/hosts.bak_* >/dev/null 2>&1; then
        local latest_bak
        latest_bak=$(ls -t /etc/hosts.bak_* | head -1)
        cp -f "$latest_bak" /etc/hosts
        chmod 644 /etc/hosts
        echo "Restored hosts backup: ${latest_bak##*/}"

        remove_hosts_block
    else
        echo "Notice: No hosts backup found. Attempting direct block removal..."
        remove_hosts_block
    fi
}

function configure_hosts_block() {
    remove_hosts_block

    {
        echo ""
        echo "$HOSTS_BLOCK_START"
        for domain in "${DEFAULT_DOMAIN_LIST[@]}"; do
            echo "127.0.0.1 $domain"
        done
        echo "$HOSTS_BLOCK_END"
    } >> /etc/hosts

    chmod 644 /etc/hosts
    echo "Hosts block rules applied"
}

function remove_hosts_block() {
    if grep -Fq "$HOSTS_BLOCK_START" /etc/hosts; then
        echo "Removing hosts block rules..."
        sed -i '' "/$HOSTS_BLOCK_START/,/$HOSTS_BLOCK_END/d" /etc/hosts
        chmod 644 /etc/hosts
    fi
}

function refresh_system_services() {
    echo "Refreshing system services..."
    dscacheutil -flushcache >/dev/null 2>&1
    killall -HUP mDNSResponder >/dev/null 2>&1

    launchctl stop system/com.apple.softwareupdated >/dev/null 2>&1
    sleep 1
    launchctl start system/com.apple.softwareupdated >/dev/null 2>&1

    killall -9 NotificationCenter >/dev/null 2>&1
}

# -------------------------- Menu System -----------------------------------
function system_action_menu() {
    while true; do
        echo ""
        echo "Choose an action:"
        echo "1. Restart now"
        echo "2. Shut down"
        echo "3. Return to main menu"
        echo ""

        read -r -p "Choose an option (1-3): " action_choice

        case $action_choice in
            1)
                echo "Restarting..."
                shutdown -r now
                ;;
            2)
                echo "Shutting down..."
                shutdown -h now
                ;;
            3)
                echo "Returning to main menu..."
                return
                ;;
            *)
                echo -e "${COLOR_RED}Invalid option. Please try again.${COLOR_NC}"
                ;;
        esac

        echo "------------------------------------------------------------"
    done
}

# -------------------------- Information Display ---------------------------
function display_header() {
    echo ""
    echo "============================================================"
    echo "MacUpdateGuard v${SCRIPT_VERSION} | Author: bili_25396444320"
    [[ -n "$INSTALL_PATH" ]] && echo "Path: $INSTALL_PATH"
    echo "============================================================"
}

function show_main_menu() {
    echo ""
    echo "Choose an action:"
    echo "1. Disable automatic system updates"
    echo "2. Restore automatic system updates"
    echo "3. Check current update status"
    echo "4. Show version information"
    echo "5. Exit"
    echo ""
}

function check_system_status() {
    echo "System update status check:"
    echo "------------------------------------------------------------"

    local schedule_status
    schedule_status=$(softwareupdate --schedule 2>&1)
    if [[ $schedule_status == *"off"* ]]; then
        echo -e "Auto-update schedule: ${COLOR_RED}Disabled${COLOR_NC}"
    else
        echo -e "Auto-update schedule: ${COLOR_GREEN}Enabled${COLOR_NC}"
    fi

    echo -n "Server blocking status: "
    local all_active=true
    for domain in "${DEFAULT_DOMAIN_LIST[@]}"; do
        if ! grep -q "^127\\.0\\.0\\.1[[:space:]]*$domain" /etc/hosts; then
            all_active=false
            break
        fi
    done

    if $all_active; then
        echo -e "${COLOR_RED}Active${COLOR_NC}"
    else
        echo -e "${COLOR_GREEN}Inactive${COLOR_NC}"
    fi

    local service_status
    service_status=$(launchctl list | grep com.apple.softwareupdated)
    if [[ -z "$service_status" ]]; then
        echo -e "softwareupdated service: ${COLOR_RED}Not running${COLOR_NC}"
    else
        echo -e "softwareupdated service: ${COLOR_GREEN}Running${COLOR_NC}"
    fi

    echo "------------------------------------------------------------"
    echo "Tip: Open System Settings > General > Software Update to verify"
}

function show_version_info() {
    echo "------------------------------------------------------------"
    echo "MacUpdateGuard v${SCRIPT_VERSION}"
    echo "Author: bili_25396444320"
    echo "Last updated: March 5, 2026"
    echo "------------------------------------------------------------"
}

# -------------------------- Exit Handling ---------------------------------
function graceful_exit() {
    echo ""
    echo "Thanks for using MacUpdateGuard!"
    [[ -n "$INSTALL_PATH" ]] && echo "Tip: Next run with: sudo \"$INSTALL_PATH\""
    exit 0
}

function handle_invalid_input() {
    echo -e "${COLOR_RED}Invalid option. Please try again.${COLOR_NC}"
}

# ======================== Script Entry Point ==============================
main "$@"
