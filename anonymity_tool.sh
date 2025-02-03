#!/bin/bash

# Function to check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "[-] Error: This script must be run as root."
        exit 1
    fi
}

# Function to check and install dependencies
check_dependencies() {
    echo "[+] Checking dependencies..."
    local packages=("macchanger" "tor" "proxychains")
    
    apt-get update -qq
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            echo "[-] $pkg not found. Installing..."
            apt-get install -y "$pkg"
        else
            echo "[+] $pkg is installed."
        fi
    done
}

# Function to get network interface
get_interface() {
    local interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
    echo "Available interfaces:"
    for i in "${!interfaces[@]}"; do
        echo "$((i+1)). ${interfaces[$i]}"
    done

    while true; do
        read -p "Select interface number: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            selected_interface="${interfaces[$((choice-1))]}"
            echo "[+] Selected: $selected_interface"
            break
        else
            echo "[-] Invalid input. Try again."
        fi
    done
}

# Function to backup configuration files
backup_config() {
    local file="$1"
    local backup="${file}.backup_$(date +%Y%m%d_%H%M%S)"
    [[ -f "$file" ]] && cp "$file" "$backup"
}

# Function to enable anonymity
enable_anonymity() {
    get_interface
    echo "[+] Enabling anonymity for $selected_interface..."

    # Backup configs
    backup_config "/etc/proxychains.conf"
    backup_config "/etc/sysctl.conf"

    # Spoof MAC
    echo "[+] Changing MAC address..."
    ifconfig "$selected_interface" down
    macchanger -r "$selected_interface"
    ifconfig "$selected_interface" up

    # Start Tor
    echo "[+] Starting Tor service..."
    systemctl start tor

    # Configure Proxychains
    echo "[+] Configuring Proxychains..."
    cat << EOF > /etc/proxychains.conf
strict_chain
proxy_dns
remote_dns_subnet 224
[ProxyList]
socks5 127.0.0.1 9050
EOF

    # Disable IPv6
    echo "[+] Disabling IPv6..."
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1
    sysctl -p

    echo "[+] Anonymity enabled!"
}

# Function to disable anonymity
disable_anonymity() {
    get_interface
    echo "[-] Disabling anonymity for $selected_interface..."

    # Restore MAC
    echo "[-] Restoring MAC..."
    ifconfig "$selected_interface" down
    macchanger -p "$selected_interface"
    ifconfig "$selected_interface" up

    # Stop Tor
    echo "[-] Stopping Tor..."
    systemctl stop tor

    # Enable IPv6
    echo "[-] Enabling IPv6..."
    sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sysctl -w net.ipv6.conf.default.disable_ipv6=0
    sysctl -p

    echo "[-] Anonymity disabled!"
}

# Function to clear logs
clear_logs() {
    echo "[+] Clearing logs..."
    log_files=(
        "/var/log/auth.log"
        "/var/log/syslog"
        "/var/log/tor/log"
    )

    for file in "${log_files[@]}"; do
        [[ -f "$file" ]] && cat /dev/null > "$file"
    done

    echo "[+] Logs cleared!"
}

# Display menu
while true; do
    clear
    echo "=========================="
    echo "  Anonymity Tool - Kali"
    echo "=========================="
    echo "1. Enable Anonymity"
    echo "2. Disable Anonymity"
    echo "3. Check Dependencies"
    echo "4. Clear Logs"
    echo "5. Exit"
    read -p "Choose an option: " opt

    case $opt in
        1) enable_anonymity ;;
        2) disable_anonymity ;;
        3) check_dependencies ;;
        4) clear_logs ;;
        5) exit 0 ;;
        *) echo "[-] Invalid choice. Try again." ;;
    esac
    read -p "Press Enter to continue..."
done
