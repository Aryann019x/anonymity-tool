#!/bin/bash

# Function to check and install missing dependencies
check_dependencies() {
    echo "Checking for required tools..."
    for pkg in macchanger tor proxychains; do
        if ! command -v $pkg &> /dev/null; then
            echo "$pkg is not installed. Installing..."
            sudo apt-get install -y $pkg
        else
            echo "$pkg is already installed."
        fi
    done
}

# Function to enable anonymity
enable_anonymity() {
    echo "[+] Enabling anonymity..."
    
    # Change MAC Address
    echo "[+] Spoofing MAC Address..."
    sudo ifconfig eth0 down
    sudo macchanger -r eth0
    sudo ifconfig eth0 up
    
    # Start Tor Service
    echo "[+] Starting Tor..."
    sudo systemctl start tor
    
    # Configure Proxychains
    echo "[+] Configuring Proxychains..."
    echo "socks5 127.0.0.1 9050" | sudo tee -a /etc/proxychains.conf > /dev/null
    
    echo "[+] Anonymity Enabled!"
}

# Function to disable anonymity
disable_anonymity() {
    echo "[-] Disabling anonymity..."

    # Restore MAC Address
    echo "[-] Restoring MAC Address..."
    sudo ifconfig eth0 down
    sudo macchanger -p eth0
    sudo ifconfig eth0 up

    # Stop Tor Service
    echo "[-] Stopping Tor..."
    sudo systemctl stop tor

    echo "[-] Anonymity Disabled!"
}

# Main menu
while true; do
    clear
    echo "========================="
    echo "  Anonymity Tool for Kali Linux"
    echo "========================="
    echo "1. Enable Anonymity"
    echo "2. Disable Anonymity"
    echo "3. Check & Install Dependencies"
    echo "4. Exit"
    read -p "Choose an option: " choice

    case $choice in
        1) enable_anonymity ;;
        2) disable_anonymity ;;
        3) check_dependencies ;;
        4) exit ;;
        *) echo "Invalid option! Try again." ;;
    esac
    read -p "Press Enter to continue..."
done
