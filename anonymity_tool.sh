#!/bin/bash
# ───────────────────────────────────────────────────────────────────────────
# Secure Kali Linux Anonymity Tool v6.0
# Created by: Aryan
# ───────────────────────────────────────────────────────────────────────────

# === Color Definitions ===
BLUE="\e[34m"
LAVENDER="\e[35m"
WHITE="\e[97m"
RESET="\e[0m"
BOLD="\e[1m"

# === File Paths ===
LOG_FILE="anonymity_log.txt"
PROXYCHAINS_CONF="/etc/proxychains.conf"
RESOLV_FILE="/etc/resolv.conf"
RESOLV_BAK="/etc/resolv.conf.bak"

# === Get Active Network Interface ===
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

# === Check if script is run as root ===
if [[ $EUID -ne 0 ]]; then
    echo -e "${LAVENDER}${BOLD}❄ Please run as root (sudo).${RESET}"
    exit 1
fi

# === Check Internet Connectivity ===
check_internet() {
    echo -e "${WHITE}🔹 Testing connection (this may take a moment)...${RESET}"
    
    # Try multiple DNS servers with longer timeout
    for dns in "8.8.8.8" "1.1.1.1" "208.67.222.222"; do
        for i in {1..3}; do
            if ping -c 1 -W 10 $dns &>/dev/null; then
                return 0
            fi
            sleep 2
        done
    done
    return 1
}

# === Verify Tor Connection ===
verify_tor() {
    echo -e "${WHITE}🔹 Verifying Tor connection (please wait)...${RESET}"
    sleep 5  # Increased wait time for mobile connections
    
    for i in {1..3}; do
        if curl --socks5 localhost:9050 -s --max-time 30 https://check.torproject.org/ | grep -q "Congratulations"; then
            return 0
        fi
        sleep 3
    done
    return 1
}

# === Install Required Packages ===
install_dependencies() {
    echo -e "${WHITE}🔹 Checking required packages...${RESET}"
    
    # First verify internet connection
    if ! check_internet; then
        echo -e "${LAVENDER}⚠ Please check your hotspot connection and try again${RESET}"
        echo -e "${WHITE}Tips for mobile hotspot:${RESET}"
        echo -e "1. Ensure mobile data is enabled"
        echo -e "2. Check hotspot signal strength"
        echo -e "3. Try repositioning your phone"
        echo -e "4. Verify hotspot password is correct"
        return 1
    fi
    
    for pkg in tor proxychains curl; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            echo -e "${WHITE}📦 Installing $pkg (may take longer on mobile connection)...${RESET}"
            apt-get update &>/dev/null
            apt-get install -y "$pkg" || {
                echo -e "${LAVENDER}⚠ Failed to install $pkg!${RESET}"
                return 1
            }
        fi
    done
}

# === Enable Anonymity Mode ===
enable_anonymity() {
    echo -e "${BLUE}${BOLD}🔹 Enabling anonymity...${RESET}" | tee -a "$LOG_FILE"

    # Check active network
    if [[ -z "$INTERFACE" ]]; then
        echo -e "${LAVENDER}⚠ No active network interface detected!${RESET}"
        echo -e "${WHITE}🔹 Trying to detect hotspot connection...${RESET}"
        INTERFACE=$(ip link | grep -E '^[0-9]+: w' | cut -d: -f2 | tr -d ' ' | head -n1)
        if [[ -z "$INTERFACE" ]]; then
            echo -e "${LAVENDER}⚠ Could not detect network interface. Please ensure hotspot is connected.${RESET}"
            return 1
        fi
    fi

    # Install dependencies with more verbose output
    echo -e "${WHITE}🔹 Checking and installing required packages...${RESET}"
    install_dependencies
    if [ $? -ne 0 ]; then
        echo -e "${LAVENDER}⚠ Package installation failed. Please check your connection.${RESET}"
        return 1
    fi

    # Backup resolv.conf if not already backed up
    [[ ! -f "$RESOLV_BAK" ]] && cp "$RESOLV_FILE" "$RESOLV_BAK"

    # Update DNS for anonymity
    echo -e "${WHITE}🔹 Updating DNS settings...${RESET}"
    echo "nameserver 1.1.1.1" > "$RESOLV_FILE"
    echo "nameserver 9.9.9.9" >> "$RESOLV_FILE"

    # Start Tor Service
    echo -e "${WHITE}🔹 Starting Tor...${RESET}"
    systemctl stop tor 2>/dev/null
    sleep 2
    systemctl start tor
    sleep 3

    # Ensure Tor is running
    if ! systemctl is-active --quiet tor; then
        echo -e "${LAVENDER}⚠ Tor failed to start!${RESET}"
        disable_anonymity
        return 1
    fi

    # Configure Proxychains
    echo -e "${WHITE}🔹 Configuring Proxychains...${RESET}"
    sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"
    sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
    sed -i 's/^#proxy_dns/proxy_dns/' "$PROXYCHAINS_CONF"

    # Setup Firewall (Less Restrictive)
    echo -e "${WHITE}🔹 Securing firewall...${RESET}"
    ufw --force reset >/dev/null 2>&1
    ufw default deny outgoing
    ufw default deny incoming
    
    # Allow essential services
    ufw allow out on "$INTERFACE" to any port 9050  # Tor
    ufw allow out on "$INTERFACE" to any port 53    # DNS
    ufw allow out on "$INTERFACE" to any port 80    # HTTP
    ufw allow out on "$INTERFACE" to any port 443   # HTTPS
    
    ufw --force enable >/dev/null 2>&1
    ufw reload >/dev/null 2>&1

    # Verify Tor Connection
    if verify_tor; then
        echo -e "${WHITE}✨ Anonymity mode enabled successfully.${RESET}"
    else
        echo -e "${LAVENDER}⚠ Network issue detected! Rolling back changes...${RESET}"
        disable_anonymity
        return 1
    fi
}

# === Disable Anonymity Mode ===
disable_anonymity() {
    echo -e "${BLUE}${BOLD}🔹 Disabling anonymity...${RESET}" | tee -a "$LOG_FILE"

    # Restore original DNS settings
    echo -e "${WHITE}🔹 Restoring original DNS settings...${RESET}"
    if [[ -f "$RESOLV_BAK" ]]; then
        mv "$RESOLV_BAK" "$RESOLV_FILE"
    else
        echo "nameserver 8.8.8.8" > "$RESOLV_FILE"
        echo "nameserver 8.8.4.4" >> "$RESOLV_FILE"
    fi

    # Stop Tor
    echo -e "${WHITE}🔹 Stopping Tor...${RESET}"
    systemctl stop tor

    # Reset Firewall
    echo -e "${WHITE}🔹 Resetting firewall rules...${RESET}"
    ufw --force reset >/dev/null 2>&1
    ufw default allow outgoing
    ufw default deny incoming
    ufw --force disable >/dev/null 2>&1

    if check_internet; then
        echo -e "${WHITE}✨ Anonymity disabled, network restored.${RESET}"
    else
        echo -e "${LAVENDER}⚠ Please check your network connection manually.${RESET}"
    fi
}

# === Show Status ===
show_status() {
    echo -e "${BLUE}════════════════════════════════════"
    echo -e "${BLUE}  🔹 Current Anonymity Status"
    echo -e "${BLUE}════════════════════════════════════${RESET}"
    echo -e "${WHITE}🔹 Active Interface: ${INTERFACE:-None}${RESET}"
    echo -n "🔹 Tor Service: "
    if systemctl is-active --quiet tor; then
        echo -e "${WHITE}✅ Running${RESET}"
    else
        echo -e "${LAVENDER}❌ Stopped${RESET}"
    fi
    echo -e "${WHITE}🔹 Firewall: $(ufw status | grep 'Status' | awk '{print $2}')${RESET}"
    echo -e "${WHITE}🔹 Current DNS: $(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')${RESET}"
    echo -e "${BLUE}════════════════════════════════════${RESET}"
}

# === Main Menu (Persistent) ===
while true; do
    clear
    echo -e "${BLUE}════════════════════════════════════"
    echo -e "${BLUE}  Secure Kali Anonymity Tool v6.0"
    echo -e "${LAVENDER}  Created by: Aryann019x"
    echo -e "${BLUE}════════════════════════════════════"
    echo -e "${WHITE}[1] Enable Anonymity"
    echo -e "${WHITE}[2] Disable Anonymity"
    echo -e "${WHITE}[3] Show Status"
    echo -e "${WHITE}[4] Exit"
    echo -e "${BLUE}════════════════════════════════════${RESET}"
    read -p "🔹 Select an option: " choice

    case "$choice" in
        1) enable_anonymity ;;
        2) disable_anonymity ;;
        3) show_status ;;
        4) echo -e "${WHITE}Exiting...${RESET}" && exit 0 ;;
        *) echo -e "${LAVENDER}⚠ Invalid option, try again.${RESET}" ;;
    esac

    echo -e "\n${WHITE}Press Enter to return to the menu...${RESET}"
    read
done
