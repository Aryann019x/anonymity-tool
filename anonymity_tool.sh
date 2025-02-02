#!/bin/bash

# Function to display a header
display_header() {
    clear
    echo "========================="
    echo "  Anonymity Tool for Kali Linux"
    echo "========================="
}

# Function to check and install missing dependencies
check_dependencies() {
    echo "Checking for required tools..."
    local missing=0
    for pkg in macchanger tor proxychains; do
        if ! command -v $pkg &> /dev/null; then
            echo "[-] $pkg is not installed. Installing..."
            sudo apt-get install -y $pkg || {
                echo "[-] Failed to install $pkg. Please check your internet connection or permissions."
                missing=1
            }
        else
            echo "[+] $pkg is already installed."
        fi
    done
    if [[ $missing -eq 1 ]]; then
        echo "[-] Some dependencies could not be installed. Exiting."
        exit 1
    fi
}

# Function to get network interface
get_interface() {
    echo "Available network interfaces:"
    ip -o link show | awk -F': ' '{print $2}'
    while true; do
        read -p "Enter the network interface (e.g., eth0, wlan0): " interface
        if ip link show $interface &> /dev/null; then
            break
        else
            echo "[-] Invalid interface. Please try again."
        fi
    done
    echo $interface
}

# Function to enable anonymity
enable_anonymity() {
    interface=$(get_interface)
    echo "[+] Enabling anonymity on interface $interface..."
    
    # Change MAC Address
    echo "[+] Spoofing MAC Address..."
    sudo ifconfig $interface down
    sudo macchanger -r $interface || {
        echo "[-] Failed to spoof MAC address. Exiting."
        sudo ifconfig $interface up
        exit 1
    }
    sudo ifconfig $interface up
    
    # Start Tor Service
    echo "[+] Starting Tor..."
    sudo systemctl start tor || {
        echo "[-] Failed to start Tor. Exiting."
        exit 1
    }
    
    # Configure Proxychains
    echo "[+] Configuring Proxychains..."
    if ! grep -q "socks5 127.0.0.1 9050" /etc/proxychains.conf; then
        echo "socks5 127.0.0.1 9050" | sudo tee -a /etc/proxychains.conf > /dev/null
    else
        echo "[+] Proxychains is already configured."
    fi
    
    # Disable IPv6
    echo "[+] Disabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
    echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -p
    
    echo "[+] Anonymity Enabled!"
}

# Function to disable anonymity
disable_anonymity() {
    interface=$(get_interface)
    echo "[-] Disabling anonymity on interface $interface..."

    # Restore MAC Address
    echo "[-] Restoring MAC Address..."
    sudo ifconfig $interface down
    sudo macchanger -p $interface || {
        echo "[-] Failed to restore MAC address. Exiting."
        sudo ifconfig $interface up
        exit 1
    }
    sudo ifconfig $interface up

    # Stop Tor Service
    echo "[-] Stopping Tor..."
    sudo systemctl stop tor || {
        echo "[-] Failed to stop Tor. Exiting."
        exit 1
    }

    # Enable IPv6
    echo "[-] Enabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
    sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    sudo sysctl -p

    echo "[-] Anonymity Disabled!"
}

# Function to clear logs
clear_logs() {
    echo "[+] Clearing system logs..."
    sudo rm -rf /var/log/* || {
        echo "[-] Failed to clear logs. Exiting."
        exit 1
    }
    echo "[+] Logs cleared!"
}

# Function to display help
display_help() {
    display_header
    echo "Usage: ./anonymity_tool.sh"
    echo "Options:"
    echo "  1. Enable Anonymity"
    echo "  2. Disable Anonymity"
    echo "  3. Check & Install Dependencies"
    echo "  4. Clear System Logs"
    echo "  5. Help"
    echo "  6. Exit"
}

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
        6) exit ;;
        *) echo "[-] Invalid option! Try again." ;;
    esac
    read -p "Press Enter to continue..."
done
