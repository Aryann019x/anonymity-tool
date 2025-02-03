#!/bin/bash

# Function to list network interfaces (excluding lo)
list_interfaces() {
    echo -e "\n\033[1;36mAvailable interfaces:\033[0m"
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo'))
    for i in "${!interfaces[@]}"; do
        echo -e "\033[1;34m$((i+1)). ${interfaces[$i]}\033[0m"
    done
}

# Function to check if a service is running
check_service_status() {
    service_name=$1
    if systemctl is-active --quiet $service_name; then
        echo -e "\033[1;32m[+] $service_name is running.\033[0m"
    else
        echo -e "\033[1;31m[-] $service_name is not running.\033[0m"
    fi
}

# Function to enable anonymity
enable_anonymity() {
    list_interfaces
    read -p "Select interface number: " iface_num
    selected_iface=${interfaces[$((iface_num-1))]}

    if [ -z "$selected_iface" ]; then
        echo -e "\033[1;31m[-] Invalid selection!\033[0m"
        return
    fi

    echo -e "\033[1;36m[+] Selected: $selected_iface\033[0m"
    echo -e "\033[1;36m[+] Enabling anonymity on interface $selected_iface...\033[0m"
    
    # Spoofing MAC address
    echo -e "\033[1;36m[+] Spoofing MAC Address...\033[0m"
    sudo ip link set "$selected_iface" down
    sudo macchanger -r "$selected_iface"
    sudo ip link set "$selected_iface" up

    # Starting Tor service
    echo -e "\033[1;36m[+] Starting Tor...\033[0m"
    sudo systemctl start tor

    # Check if Tor is running
    check_service_status tor

    # Configuring Proxychains
    echo -e "\033[1;36m[+] Configuring Proxychains...\033[0m"
    sudo cp /etc/proxychains.conf /etc/proxychains.conf.backup
    echo "socks5 127.0.0.1 9050" | sudo tee -a /etc/proxychains.conf > /dev/null

    # Check if Proxychains is configured
    if grep -q "socks5 127.0.0.1 9050" /etc/proxychains.conf; then
        echo -e "\033[1;32m[+] Proxychains is configured correctly.\033[0m"
    else
        echo -e "\033[1;31m[-] Proxychains is not configured correctly. Please check the configuration.\033[0m"
    fi

    # Disabling IPv6
    echo -e "\033[1;36m[+] Disabling IPv6...\033[0m"
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

    # Final confirmation
    echo -e "\033[1;32m[+] Anonymity Enabled!\033[0m"
}

# Function to disable anonymity
disable_anonymity() {
    list_interfaces
    read -p "Select interface number: " iface_num
    selected_iface=${interfaces[$((iface_num-1))]}

    if [ -z "$selected_iface" ]; then
        echo -e "\033[1;31m[-] Invalid selection!\033[0m"
        return
    fi

    echo -e "\033[1;36m[+] Selected: $selected_iface\033[0m"
    echo -e "\033[1;31m[-] Disabling anonymity on interface $selected_iface...\033[0m"
    
    # Restoring MAC address
    echo -e "\033[1;31m[-] Restoring MAC Address...\033[0m"
    sudo ip link set "$selected_iface" down
    sudo macchanger -p "$selected_iface"
    sudo ip link set "$selected_iface" up

    # Stopping Tor service
    echo -e "\033[1;31m[-] Stopping Tor...\033[0m"
    sudo systemctl stop tor

    # Check if Tor is stopped
    check_service_status tor

    # Enabling IPv6
    echo -e "\033[1;31m[-] Enabling IPv6...\033[0m"
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0

    echo -e "\033[1;31m[-] Anonymity Disabled!\033[0m"
}

# Function to check dependencies
check_dependencies() {
    echo -e "\033[1;36m[+] Checking dependencies...\033[0m"
    deps=("macchanger" "tor" "proxychains")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "\033[1;31m[-] $dep is missing. Installing...\033[0m"
            sudo apt install -y "$dep"
        else
            echo -e "\033[1;32m[+] $dep is installed!\033[0m"
        fi
    done
}

# Function to clear logs
clear_logs() {
    echo -e "\033[1;36m[+] Clearing logs...\033[0m"
    sudo journalctl --vacuum-time=1s
    sudo rm -rf ~/.bash_history
    sudo rm -rf /var/log/*
    echo -e "\033[1;32m[+] Logs cleared!\033[0m"
}

# Menu system
while true; do
    clear
    echo -e "\033[1;36m=========================\033[0m"
    echo -e "\033[1;36m  Anonymity Tool - Kali  \033[0m"
    echo -e "\033[1;36m=========================\033[0m"
    echo -e "\033[1;34m1. Enable Anonymity\033[0m"
    echo -e "\033[1;34m2. Disable Anonymity\033[0m"
    echo -e "\033[1;34m3. Check Dependencies\033[0m"
    echo -e "\033[1;34m4. Clear Logs\033[0m"
    echo -e "\033[1;34m5. Exit\033[0m"
    echo -e "\033[1;35mCreated by: Aryann019x\033[0m"
    echo -n -e "\033[1;37mChoose an option: \033[0m"
    read choice

    case $choice in
        1) enable_anonymity ;;
        2) disable_anonymity ;;
        3) check_dependencies ;;
        4) clear_logs ;;
        5) echo -e "\033[1;37mExiting...\033[0m"; exit ;;
        *) echo -e "\033[1;31mInvalid option!\033[0m"; sleep 1 ;;
    esac
    echo -e "\033[1;37mPress Enter to continue...\033[0m"
    read
done
