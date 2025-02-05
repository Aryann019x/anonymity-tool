# Secure Kali Linux Anonymity Tool v6.0

⚠️ **IMPORTANT: DEVELOPMENT STATUS** ⚠️

This tool is currently in development and requires thorough testing and modification. It should NOT be used in production environments or for situations requiring guaranteed anonymity without extensive verification and improvements.

## Current Limitations and Needed Improvements

- Code requires security audit and penetration testing
- Firewall rules need comprehensive review
- Tor configuration requires additional hardening
- DNS leak protection needs verification
- Error handling requires enhancement
- Network fallback mechanisms need implementation
- Security against various attack vectors needs testing

A robust command-line tool designed to enhance anonymity on Kali Linux systems by configuring Tor, ProxyChains, and firewall settings. This tool is particularly optimized for systems using mobile hotspot connections.

## Features

- Automated Tor configuration and verification
- Dynamic ProxyChains setup
- Secure DNS configuration
- UFW firewall rules management
- Mobile hotspot optimization
- Real-time status monitoring
- Automatic dependency installation
- Backup and restore functionality

## Prerequisites

- Kali Linux operating system
- Root privileges
- Active internet connection (supports mobile hotspot)
- Basic packages: `tor`, `proxychains`, `curl` (automatically installed if missing)

## Installation

1. Download the script:
```bash
git clone [repository-url]
cd [repository-directory]
```

2. Make the script executable:
```bash
chmod +x anonymity_tool.sh
```

## Usage

Run the script with root privileges:
```bash
sudo ./anonymity_tool.sh
```

### Available Options

1. **Enable Anonymity**
   - Configures Tor service
   - Sets up ProxyChains
   - Implements secure DNS settings
   - Configures firewall rules
   - Verifies anonymous connection

2. **Disable Anonymity**
   - Restores original DNS settings
   - Stops Tor service
   - Resets firewall rules
   - Restores normal network connectivity

3. **Show Status**
   - Displays active network interface
   - Shows Tor service status
   - Reports firewall status
   - Lists current DNS settings

4. **Exit**
   - Safely exits the program

## Files Modified

- `/etc/proxychains.conf` - ProxyChains configuration
- `/etc/resolv.conf` - DNS settings
- `/etc/resolv.conf.bak` - Backup of original DNS settings

## Logging

The script maintains a log file (`anonymity_log.txt`) to track operations and potential issues.

## Troubleshooting

### Common Issues

1. **Connection Problems**
   - Ensure mobile hotspot is properly connected
   - Check signal strength
   - Verify hotspot password
   - Try repositioning your mobile device

2. **Permission Denied**
   - Make sure to run the script with sudo
   - Verify script has executable permissions

3. **Tor Connection Failure**
   - Check internet connectivity
   - Ensure Tor service is not blocked
   - Verify firewall settings

## Security Notes

- The tool implements restricted firewall rules
- Only essential ports (53, 80, 443, 9050) are allowed
- Default deny policy for incoming connections
- Automatic backup of critical configuration files

## Known Security Risks

1. **DNS Leaks**: Current DNS configuration might not fully prevent leaks
2. **Firewall Rules**: Some rules might be too permissive
3. **Tor Configuration**: Default settings might not provide optimal security
4. **Network Fallback**: Failure scenarios might expose real IP
5. **Mobile Hotspot**: Additional risks when using mobile connections

## Contribution Guidelines

Contributions are welcome to improve the security and functionality of this tool. Areas that need particular attention:

1. Security auditing
2. Penetration testing
3. Code review
4. Documentation improvements
5. Error handling enhancement
6. Network security hardening
7. Tor configuration optimization

## Author

Created by: Aryann019x

## Version

Current Version: 1.1 (Development)

## Disclaimer

This tool is intended for legal and ethical use only. Users are responsible for complying with all applicable laws and regulations in their jurisdiction. 

**IMPORTANT**: This is a development version and should not be relied upon for critical anonymity needs without thorough testing and modification. Use at your own risk. The authors and contributors are not responsible for any security breaches or damages resulting from the use of this tool.
