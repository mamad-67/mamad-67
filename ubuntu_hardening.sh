#!/bin/bash

# Ubuntu Hardening Script
# Run this script with sudo or as root
# Color codes for output messages
GREEN="\033[0;32m"
NC="\033[0m" # No Color
echo -e "${GREEN}Starting Ubuntu hardening...${NC}"
# Step 1: Update and Upgrade System
echo -e "${GREEN}Updating and upgrading system...${NC}"
apt update && apt upgrade -y
# Step 2: Enable Automatic Security Updates
echo -e "${GREEN}Configuring automatic security updates...${NC}"
apt install -y unattended-upgrades apt-listchanges
dpkg-reconfigure --priority=low unattended-upgrades
# Step 3: Set up the firewall with UFW
echo -e "${GREEN}Configuring UFW firewall...${NC}"
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh  # Allow SSH
ufw allow 80/tcp  # Allow HTTP
ufw allow 443/tcp  # Allow HTTPS
ufw enable

# Step 4: SSH Hardening
echo -e "${GREEN}Hardening SSH configuration...${NC}"
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# Change SSH Port (Optional)
# Uncomment and change the port if you wish to change the default SSH port (avoid using reserved ports below 1024)
# sed -i 's/#Port 22/Port 2200/' /etc/ssh/sshd_config

systemctl restart sshd

# Step 5: Disable Unnecessary Services (disable cups service for printing)
echo -e "${GREEN}Disabling unnecessary services...${NC}"
systemctl disable cups
systemctl stop cups

# Step 6: Secure Shared Memory
# echo -e "${GREEN}Securing shared memory...${NC}"
# if ! grep -q "tmpfs /run/shm" /etc/fstab; then
#  echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
# fi
# mount -o remount /run/shm

# Step 7: Remove Unnecessary Packages
# echo -e "${GREEN}Removing unnecessary packages...${NC}"
# apt purge -y telnet ftp rsh-server rsh-client
# apt autoremove -y

# Step 8: Set Up Audit Logs
echo -e "${GREEN}Configuring auditd...${NC}"
apt install -y auditd audispd-plugins
systemctl enable auditd
systemctl start auditd

# Add basic audit rules
cat <<EOF >> /etc/audit/audit.rules
# Record all commands executed by users
-a always,exit -F arch=b64 -S execve -k command_logging

# Log modifications to critical system files
-w /etc/passwd -p wa -k usergroup_modifications
-w /etc/group -p wa -k usergroup_modifications
-w /etc/shadow -p wa -k usergroup_modifications

# Ensure auditd configuration cannot be modified
-w /etc/audit/ -p wa -k auditconfig
EOF

# Restart auditd to apply changes
systemctl restart auditd

# Step 9: Enable ASLR (Address Space Layout Randomization)
echo -e "${GREEN}Enabling ASLR...${NC}"
echo 2 > /proc/sys/kernel/randomize_va_space
if ! grep -q "kernel.randomize_va_space" /etc/sysctl.conf; then
  echo "kernel.randomize_va_space = 2" >> /etc/sysctl.conf
fi
sysctl -p

# Step 10: Configure Fail2Ban for SSH protection
echo -e "${GREEN}Installing and configuring Fail2Ban...${NC}"
apt install -y fail2ban
cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF
systemctl enable fail2ban
systemctl restart fail2ban

# Step 11: Disable IPv6 (optional based on your requirements)
# Uncomment the following lines if you want to disable IPv6:
# echo -e "${GREEN}Disabling IPv6...${NC}"
# echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
# echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
# sysctl -p

# Step 12: Check for open ports
echo -e "${GREEN}Checking for open ports...${NC}"
ss -tuln

# Step 13: Install ClamAV for antivirus scanning (optional)
echo -e "${GREEN}Installing ClamAV...${NC}"
apt install -y clamav clamav-daemon
systemctl enable clamav-daemon
systemctl start clamav-daemon

# Step 14: Reboot (optional based on changes made)
# echo -e "${GREEN}Rebooting the system...${NC}"
# reboot

echo -e "${GREEN}Hardening complete! Please review the script for custom changes and reboot the system if necessary.${NC}"
