#!/bin/bash

# Anonymity Tool for Kali Linux

# Function to display usage
usage() {
    echo -e "\nUsage: $0 [options]"
    echo -e "Options:"
    echo -e "  --enable   : Enable anonymity features (MAC change, Tor, Proxychains, etc.)"
    echo -e "  --disable  : Disable anonymity features (restore default settings)"
    echo -e "  --help     : Show this help menu\n"
    exit 1
}

# Function to enable anonymity features
enable_anonymity() {
    echo -e "\n[+] Enabling anonymity features..."

    # Install required tools
    sudo apt update
    sudo apt install -y macchanger tor proxychains

    # Change MAC address
    echo -e "\n[+] Changing MAC address..."
    sudo macchanger -r eth0

    # Configure MAC address change on boot
    echo -e "\n[+] Configuring MAC address change on boot..."
    sudo sed -i '/^exit 0/i pre-up macchanger -r eth0' /etc/network/interfaces

    # Start and enable Tor service
    echo -e "\n[+] Starting and enabling Tor service..."
    sudo systemctl start tor
    sudo systemctl enable tor

    # Configure Proxychains to use Tor
    echo -e "\n[+] Configuring Proxychains to use Tor..."
    sudo sed -i 's/^socks4.*/socks5 127.0.0.1 9050/' /etc/proxychains.conf

    # Disable IPv6
    echo -e "\n[+] Disabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
    echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    # Clear command history and logs
    echo -e "\n[+] Clearing command history and logs..."
    history -c
    sudo rm -rf /var/log/*

    echo -e "\n[+] Anonymity features enabled!"
    echo -e "Use 'proxychains <command>' to route traffic through Tor."
}

# Function to disable anonymity features
disable_anonymity() {
    echo -e "\n[+] Disabling anonymity features..."

    # Restore default MAC address
    echo -e "\n[+] Restoring default MAC address..."
    sudo macchanger -p eth0

    # Remove MAC address change on boot
    echo -e "\n[+] Removing MAC address change on boot..."
    sudo sed -i '/pre-up macchanger -r eth0/d' /etc/network/interfaces

    # Stop and disable Tor service
    echo -e "\n[+] Stopping and disabling Tor service..."
    sudo systemctl stop tor
    sudo systemctl disable tor

    # Restore default Proxychains configuration
    echo -e "\n[+] Restoring default Proxychains configuration..."
    sudo sed -i 's/^socks5.*/socks4 127.0.0.1 9050/' /etc/proxychains.conf

    # Enable IPv6
    echo -e "\n[+] Enabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
    sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    sudo sysctl -p

    echo -e "\n[+] Anonymity features disabled!"
}

# Main script logic
if [[ $# -eq 0 ]]; then
    usage
fi

case $1 in
    --enable)
        enable_anonymity
        ;;
    --disable)
        disable_anonymity
        ;;
    --help)
        usage
        ;;
    *)
        echo -e "\n[-] Invalid option: $1"
        usage
        ;;
esac
