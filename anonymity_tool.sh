#!/bin/bash

# Function to handle errors
handle_error() {
    local error_msg="$1"
    echo "[-] Error: $error_msg"
    return 1
}

# Function to check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        handle_error "This script must be run as root"
        exit 1
    fi
}

# Function to display a header
display_header() {
    clear
    echo "========================="
    echo "  Anonymity Tool - Kali"
    echo "========================="
}

# Function to validate and select network interface
get_interface() {
    echo "Available interfaces:"
    local interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
    
    for i in "${!interfaces[@]}"; do
        echo "$((i+1)). ${interfaces[$i]}"
    done
    
    while true; do
        read -p "Select interface number: " num
        if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#interfaces[@]} )); then
            selected_interface="${interfaces[$((num-1))]}"  # Store correct selection
            echo "[+] Selected: $selected_interface"
            break
        else
            echo "[-] Invalid selection. Try again."
        fi
    done
}

# Function to check and install missing dependencies
check_dependencies() {
    echo "Checking for required tools..."
    local packages=("macchanger" "tor" "proxychains")
    local missing=0

    if ! apt-get update &>/dev/null; then
        handle_error "Failed to update package lists. Check your internet connection."
        return 1
    fi

    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            echo "[-] $pkg is not installed. Installing..."
            if ! apt-get install -y "$pkg"; then
                handle_error "Failed to install $pkg"
                missing=1
            fi
        else
            echo "[+] $pkg is already installed"
        fi
    done

    if [[ $missing -eq 1 ]]; then
        handle_error "Some dependencies could not be installed"
        return 1
    fi
    
    echo "[+] All dependencies are installed"
    return 0
}

# Function to backup configuration files
backup_config() {
    local file="$1"
    local backup_file="${file}.backup_$(date +%Y%m%d_%H%M%S)"
    if [[ -f "$file" ]]; then
        cp "$file" "$backup_file" || handle_error "Failed to create backup of $file"
    fi
}

# Function to enable anonymity
enable_anonymity() {
    get_interface
    echo "[+] Enabling anonymity on interface $selected_interface..."

    # Backup configurations
    backup_config "/etc/proxychains.conf"
    backup_config "/etc/sysctl.conf"

    # Change MAC Address
    echo "[+] Spoofing MAC Address..."
    ifconfig "$selected_interface" down
    if ! macchanger -r "$selected_interface"; then
        handle_error "Failed to spoof MAC address"
        ifconfig "$selected_interface" up
        return 1
    fi
    ifconfig "$selected_interface" up

    # Start Tor Service
    echo "[+] Starting Tor..."
    systemctl start tor || handle_error "Failed to start Tor"

    # Configure Proxychains
    echo "[+] Configuring Proxychains..."
    if ! grep -q "socks5 127.0.0.1 9050" /etc/proxychains.conf; then
        echo -e "strict_chain\nproxy_dns\nremote_dns_subnet 224\n[ProxyList]\nsocks5 127.0.0.1 9050" > /etc/proxychains.conf || handle_error "Failed to configure Proxychains"
    else
        echo "[+] Proxychains is already configured"
    fi

    # Disable IPv6 (Ensure file exists first)
    echo "[+] Disabling IPv6..."
    touch /etc/sysctl.conf
    {
        echo "net.ipv6.conf.all.disable_ipv6 = 1"
        echo "net.ipv6.conf.default.disable_ipv6 = 1"
    } >> /etc/sysctl.conf
    sysctl -p || handle_error "Failed to apply sysctl changes"

    echo "[+] Anonymity Enabled!"
}

# Function to disable anonymity
disable_anonymity() {
    get_interface
    echo "[-] Disabling anonymity on interface $selected_interface..."

    # Restore MAC Address
    echo "[-] Restoring MAC Address..."
    ifconfig "$selected_interface" down
    if ! macchanger -p "$selected_interface"; then
        handle_error "Failed to restore MAC address"
    fi
    ifconfig "$selected_interface" up

    # Stop Tor Service
    echo "[-] Stopping Tor..."
    systemctl stop tor || handle_error "Failed to stop Tor"

    # Enable IPv6
    echo "[-] Enabling IPv6..."
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sysctl -w net.ipv6.conf.default.disable_ipv6=0
    sysctl -p || handle_error "Failed to apply sysctl changes"

    echo "[-] Anonymity Disabled!"
}

# Function to clear logs
clear_logs() {
    echo "[+] Clearing system logs..."
    local log_files=("/var/log/auth.log" "/var/log/syslog" "/var/log/tor")

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            backup_config "$log_file"
            cat /dev/null > "$log_file" || handle_error "Failed to clear $log_file"
        fi
    done

    echo "[+] Logs cleared!"
}

# Main execution
check_root

# Main menu
while true; do
    display_header
    echo "1. Enable Anonymity"
    echo "2. Disable Anonymity"
    echo "3. Check Dependencies"
    echo "4. Clear Logs"
    echo "5. Exit"
    read -p "Choose an option: " choice

    case $choice in
        1) enable_anonymity ;;
        2) disable_anonymity ;;
        3) check_dependencies ;;
        4) clear_logs ;;
        5) exit 0 ;;
        *) echo "[-] Invalid option! Try again." ;;
    esac
    read -p "Press Enter to continue..."
done
