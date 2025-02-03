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
            echo "${interfaces[$((num-1))]}"
            return
        else
            echo "[-] Invalid selection. Try again."
        fi
    done
}

# Function to check and install dependencies
check_dependencies() {
    echo "[+] Checking for required tools..."
    local packages=("macchanger" "tor" "proxychains")
    
    if ! apt-get update &>/dev/null; then
        handle_error "Failed to update package lists. Check your internet connection."
        return 1
    fi

    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            echo "[-] Installing $pkg..."
            if ! apt-get install -y "$pkg"; then
                handle_error "Failed to install $pkg"
                return 1
            fi
        else
            echo "[+] $pkg is already installed"
        fi
    done
    
    echo "[+] All dependencies are installed"
    return 0
}

# Function to enable anonymity
enable_anonymity() {
    local interface
    interface=$(get_interface)
    echo "[+] Selected: $interface"
    echo "[+] Enabling anonymity for $interface..."
    
    # Change MAC Address
    echo "[+] Changing MAC address..."
    ifconfig "$interface" down
    macchanger -r "$interface"
    ifconfig "$interface" up

    # Start Tor Service
    echo "[+] Starting Tor service..."
    systemctl start tor || handle_error "Failed to start Tor"

    # Configure Proxychains
    echo "[+] Configuring Proxychains..."
    echo -e "strict_chain\nproxy_dns\nremote_dns_subnet 224\n[ProxyList]\nsocks5 127.0.0.1 9050" > /etc/proxychains.conf

    # Disable IPv6
    echo "[+] Disabling IPv6..."
    [[ ! -f /etc/sysctl.conf ]] && touch /etc/sysctl.conf
    echo -e "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
    sysctl -p

    echo "[+] Anonymity enabled!"
}

# Function to disable anonymity
disable_anonymity() {
    local interface
    interface=$(get_interface)
    echo "[-] Disabling anonymity for $interface..."

    # Restore MAC Address
    echo "[-] Restoring MAC Address..."
    ifconfig "$interface" down
    macchanger -p "$interface"
    ifconfig "$interface" up

    # Stop Tor Service
    echo "[-] Stopping Tor..."
    systemctl stop tor

    # Enable IPv6
    echo "[-] Enabling IPv6..."
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    sysctl -p

    echo "[-] Anonymity Disabled!"
}

# Function to clear logs
clear_logs() {
    echo "[+] Clearing system logs..."
    local log_files=("/var/log/auth.log" "/var/log/syslog" "/var/log/tor")

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            > "$log_file" || handle_error "Failed to clear $log_file"
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
