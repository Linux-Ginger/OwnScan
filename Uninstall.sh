#!/bin/bash

# OwnScan - Uninstaller
# https://github.com/Linux-Ginger/ownscan

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Check whiptail
if ! command -v whiptail &> /dev/null; then
    apt-get install -y whiptail > /dev/null 2>&1
fi

# Confirm
if ! whiptail --title "OwnScan Uninstaller" --yesno "\
Are you sure you want to uninstall OwnScan?\n\
\n\
This will:\n\
  - Remove all OwnScan users\n\
  - Remove all FTP scan folders\n\
  - Remove all upload scripts\n\
  - Remove all systemd services\n\
  - Remove vsftpd and inotify-tools\n\
\n\
Your OwnCloud files will NOT be deleted.\n\
\n\
This cannot be undone." 18 60; then
    exit 0
fi

# Stop and remove all ownscan services
{
    echo 10
    for SERVICE in /etc/systemd/system/ownscan-*.service; do
        [ -f "$SERVICE" ] || continue
        NAME=$(basename "$SERVICE" .service)
        systemctl stop "$NAME" > /dev/null 2>&1 || true
        systemctl disable "$NAME" > /dev/null 2>&1 || true
        rm -f "$SERVICE"
    done
    echo 30
    systemctl daemon-reload > /dev/null 2>&1

    # Remove FTP users
    for ENV in /home/ownscan/*.env; do
        [ -f "$ENV" ] || continue
        FTP_USER=$(basename "$ENV" .env)
        userdel "$FTP_USER" 2>/dev/null || true
        rm -rf "/home/ftpscans/$FTP_USER"
    done
    echo 50

    # Remove ownscan files
    rm -rf /home/ownscan
    rm -rf /home/ftpscans
    echo 70

    # Remove vsftpd and inotify-tools
    apt-get remove -y vsftpd inotify-tools > /dev/null 2>&1
    apt-get autoremove -y > /dev/null 2>&1
    echo 90

    # Remove /bin/false from shells if we added it
    sed -i '/^\/bin\/false$/d' /etc/shells 2>/dev/null || true
    echo 100
} | whiptail --title "OwnScan Uninstaller" --gauge "Uninstalling OwnScan..." 8 60 0

whiptail --title "OwnScan Uninstaller" --msgbox "\
OwnScan has been uninstalled successfully.\n\
\n\
Your OwnCloud files have not been touched." 10 60
