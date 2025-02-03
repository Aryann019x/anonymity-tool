#!/bin/bash

# Function to list network interfaces (excluding lo)
list_interfaces() {
    echo "Available interfaces:"
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo'))
    for i in "${!interfaces[@]}"; do
        echo "$((i+1)). ${interfaces[$i]}"
    done
}

# Function to enable anonymity
enable_anonymity() {
    list_interfaces
    read -p "Select interface number: " iface_num
    selected_iface=${interfaces[$((iface_num-1))]}

    if [ -z "$selected_iface" ]; then
        echo "[-] Invalid selection!"
        return
    fi

    echo "[+] Selected: $selected_iface"
    echo "[+] Enabling anonymity on interface $selected_iface..."
    
    echo "[+] Spoofing MAC Address..."
    sudo ip link set "$selected_iface" down
    sudo macchanger -r "$selected_iface"
    sudo ip link set "$selected_iface" up

    echo "[+] Starting Tor..."
    sudo systemctl start tor

    echo "[+] Configuring Proxychains..."
    sudo cp /etc/proxychains.conf /etc/proxychains.conf.backup
    echo "socks5 127.0.0.1 9050" | sudo tee -a /etc/proxychains.conf > /dev/null

    echo "[+] Disabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

    echo "[+] Anonymity Enabled!"
}

# Function to disable anonymity
disable_anonymity() {
    list_interfaces
    read -p "Select interface number: " iface_num
    selected_iface=${interfaces[$((iface_num-1))]}

    if [ -z "$selected_iface" ]; then
        echo "[-] Invalid selection!"
        return
    fi

    echo "[+] Selected: $selected_iface"
    echo "[-] Disabling anonymity on interface $selected_iface..."

    echo "[-] Restoring MAC Address..."
    sudo ip link set "$selected_iface" down
    sudo macchanger -p "$selected_iface"
    sudo ip link set "$selected_iface" up

    echo "[-] Stopping Tor..."
    sudo systemctl stop tor

    echo "[-] Enabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0

    echo "[-] Anonymity Disabled!"
}

# Function to check dependencies
check_dependencies() {
    echo "[+] Checking dependencies..."
    deps=("macchanger" "tor" "proxychains")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "[-] $dep is missing. Installing..."
            sudo apt install -y "$dep"
        else
            echo "[+] $dep is installed!"
        fi
    done
}

# Function to clear logs
clear_logs() {
    echo "[+] Clearing logs..."
    sudo journalctl --vacuum-time=1s
    sudo rm -rf ~/.bash_history
    sudo rm -rf /var/log/*
    echo "[+] Logs cleared!"
}

# Menu system
while true; do
    clear
    echo "========================="
    echo "  Anonymity Tool - Kali  "
    echo "========================="
    echo "1. Enable Anonymity"
    echo "2. Disable Anonymity"
    echo "3. Check Dependencies"
    echo "4. Clear Logs"
    echo "5. Exit"
    echo -n "Choose an option: "
    read choice

    case $choice in
        1) enable_anonymity ;;
        2) disable_anonymity ;;
        3) check_dependencies ;;
        4) clear_logs ;;
        5) echo "Exiting..."; exit ;;
        *) echo "Invalid option!"; sleep 1 ;;
    esac
    echo "Press Enter to continue..."
    read
done
