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
    echo "  Anonymity Tool for Kali Linux"
    echo "========================="
}

# Function to validate network interface
validate_interface() {
    local interface="$1"
    if [[ ! "$interface" =~ ^[a-zA-Z0-9]+[a-zA-Z0-9_]*$ ]]; then
        handle_error "Invalid interface name format"
        return 1
    fi
    if ! ip link show "$interface" &>/dev/null; then
        handle_error "Interface does not exist"
        return 1
    fi
    return 0
}

# Function to check and install missing dependencies
check_dependencies() {
    echo "Checking for required tools..."
    local missing=0
    local packages=("macchanger" "tor" "proxychains")
    
    # Update package lists first
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

# Function to get network interface
get_interface() {
    echo "Available network interfaces:"
    ip -o link show | awk -F': ' '{print $2}'
    while true; do
        read -p "Enter the network interface (e.g., eth0, wlan0): " interface
        if validate_interface "$interface"; then
            if ip link show "$interface" | grep -q "state UP"; then
                break
            else
                echo "[-] Interface is not up. Please try again."
            fi
        fi
    done
    echo "$interface"
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
    local interface
    interface=$(get_interface)
    echo "[+] Enabling anonymity on interface $interface..."
    
    # Backup configurations
    backup_config "/etc/proxychains.conf"
    backup_config "/etc/sysctl.conf"
    
    # Change MAC Address
    echo "[+] Spoofing MAC Address..."
    if ! ifconfig "$interface" down; then
        handle_error "Failed to bring interface down"
        return 1
    fi
    
    if ! macchanger -r "$interface"; then
        handle_error "Failed to spoof MAC address"
        ifconfig "$interface" up
        return 1
    fi
    
    if ! ifconfig "$interface" up; then
        handle_error "Failed to bring interface up"
        return 1
    fi
    
    # Start Tor Service
    echo "[+] Starting Tor..."
    if ! systemctl start tor; then
        handle_error "Failed to start Tor"
        return 1
    fi
    
    # Configure Proxychains
    echo "[+] Configuring Proxychains..."
    if ! grep -q "socks5 127.0.0.1 9050" /etc/proxychains.conf; then
        {
            echo "strict_chain"
            echo "proxy_dns"
            echo "remote_dns_subnet 224"
            echo "[ProxyList]"
            echo "socks5 127.0.0.1 9050"
        } | tee /etc/proxychains.conf >/dev/null || handle_error "Failed to configure Proxychains"
    else
        echo "[+] Proxychains is already configured"
    fi
    
    # Disable IPv6
    echo "[+] Disabling IPv6..."
    {
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1
        echo "net.ipv6.conf.all.disable_ipv6 = 1" 
        echo "net.ipv6.conf.default.disable_ipv6 = 1"
    } | tee -a /etc/sysctl.conf >/dev/null
    
    sysctl -p || handle_error "Failed to apply sysctl changes"
    
    echo "[+] Anonymity Enabled!"
}

# Function to disable anonymity
disable_anonymity() {
    local interface
    interface=$(get_interface)
    echo "[-] Disabling anonymity on interface $interface..."

    # Restore MAC Address
    echo "[-] Restoring MAC Address..."
    if ! ifconfig "$interface" down; then
        handle_error "Failed to bring interface down"
        return 1
    fi
    
    if ! macchanger -p "$interface"; then
        handle_error "Failed to restore MAC address"
        ifconfig "$interface" up
        return 1
    fi
    
    if ! ifconfig "$interface" up; then
        handle_error "Failed to bring interface up"
        return 1
    fi

    # Stop Tor Service
    echo "[-] Stopping Tor..."
    if ! systemctl stop tor; then
        handle_error "Failed to stop Tor"
        return 1
    fi

    # Enable IPv6
    echo "[-] Enabling IPv6..."
    if ! sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf; then
        handle_error "Failed to modify sysctl.conf"
        return 1
    fi
    if ! sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf; then
        handle_error "Failed to modify sysctl.conf"
        return 1
    fi
    
    sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sysctl -w net.ipv6.conf.default.disable_ipv6=0
    sysctl -p || handle_error "Failed to apply sysctl changes"

    echo "[-] Anonymity Disabled!"
}

# Function to clear logs
clear_logs() {
    echo "[+] Clearing system logs..."
    local log_files=(
        "/var/log/auth.log"
        "/var/log/syslog"
        "/var/log/tor"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            backup_config "$log_file"
            if ! cat /dev/null > "$log_file"; then
                handle_error "Failed to clear $log_file"
                return 1
            fi
        fi
    done
    
    echo "[+] Logs cleared!"
}

# Function to display help
display_help() {
    display_header
    cat << EOF
Usage: ./anonymity_tool.sh

Options:
  1. Enable Anonymity
     - Spoofs MAC address
     - Starts Tor service
     - Configures Proxychains
     - Disables IPv6

  2. Disable Anonymity
     - Restores original MAC address
     - Stops Tor service
     - Enables IPv6

  3. Check & Install Dependencies
     - Verifies and installs required packages

  4. Clear System Logs
     - Safely clears specific system logs
     - Creates backups before clearing

  5. Help
     - Displays this help message

  6. Exit
     - Exits the program
EOF
}

# Main execution
check_root

# Main menu
while true; do
    display_header
    echo "1. Enable Anonymity"
    echo "2. Disable Anonymity"
    echo "3. Check & Install Dependencies"
    echo "4. Clear System Logs"
    echo "5. Help"
    echo "6. Exit"
    read -p "Choose an option: " choice

    case $choice in
        1) enable_anonymity ;;
        2) disable_anonymity ;;
        3) check_dependencies ;;
        4) clear_logs ;;
        5) display_help ;;
        6) exit 0 ;;
        *) echo "[-] Invalid option! Try again." ;;
    esac
    read -p "Press Enter to continue..."
done
