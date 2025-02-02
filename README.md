# Anonymity Tool for Kali Linux

This script provides an easy way to enable and disable anonymity on a Kali Linux machine by changing the MAC address, starting the Tor service, configuring Proxychains, and disabling IPv6. It also includes features for checking and installing missing dependencies, and clearing system logs.

## Features

- **Enable Anonymity:**
  - Spoofs the MAC address.
  - Starts the Tor service.
  - Configures Proxychains to use Tor for routing traffic.
  - Disables IPv6 for increased anonymity.

- **Disable Anonymity:**
  - Restores the original MAC address.
  - Stops the Tor service.
  - Enables IPv6.

- **Check & Install Dependencies:**
  - Ensures `macchanger`, `tor`, and `proxychains` are installed on the system.

- **Clear System Logs:**
  - Clears system logs to remove traces of activities.

- **Help:**
  - Displays usage instructions and options.

## Requirements

- Kali Linux
- `macchanger`
- `tor`
- `proxychains`

## Usage

1. Clone or download the script to your system.
2. Give the script execute permissions:
    ```bash
    chmod +x anonymity_tool.sh
    ```

3. Run the script:
    ```bash
    ./anonymity_tool.sh
    ```

4. Follow the on-screen menu to:
    - **Enable Anonymity**: Spoof MAC, start Tor, configure Proxychains, and disable IPv6.
    - **Disable Anonymity**: Restore MAC, stop Tor, and enable IPv6.
    - **Check & Install Dependencies**: Ensure all required tools are installed.
    - **Clear System Logs**: Clear logs to erase traces of activities.
    - **Help**: Get information on using the tool.
    - **Exit**: Exit the script.

## Dependencies Installation

If the required tools (`macchanger`, `tor`, `proxychains`) are not installed, the script will attempt to install them automatically.

To manually install dependencies, use the following command:
```bash
sudo apt-get install -y macchanger tor proxychains
