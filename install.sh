#!/bin/bash

# OwnScan - Your scans, straight to OwnCloud - self-hosted
# https://github.com/Linux-Ginger/ownscan
# Only for use on a local network, NOT for internet-facing servers.

set -e

GITHUB_API="https://api.github.com/repos/Linux-Ginger/ownscan/releases"
GITHUB_BASE_URL="https://raw.githubusercontent.com/Linux-Ginger/ownscan"
INSTALL_DIR="/usr/local/lib/ownscan"
CONFIG_DIR="/etc/ownscan"

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
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

# Check curl
if ! command -v curl &> /dev/null; then
    apt-get install -y curl > /dev/null 2>&1
fi

# ─────────────────────────────────────────
# Welcome screen
# ─────────────────────────────────────────
whiptail --title "OwnScan Installer" --msgbox \
"Welcome to the OwnScan installer!

OwnScan bridges your Brother printer and OwnCloud.
Scans are sent via FTP and uploaded to OwnCloud.

WARNING: Only use this on a LOCAL network.
         Do NOT expose this to the internet.

Press OK to continue." 16 58

# ─────────────────────────────────────────
# Check OS
# ─────────────────────────────────────────
if ! grep -qEi "ubuntu" /etc/os-release; then
    whiptail --title "Error" --msgbox \
        "OwnScan only supports Ubuntu 24.04 LTS or higher." 8 55
    exit 1
fi

# ─────────────────────────────────────────
# Version selection
# ─────────────────────────────────────────
SELECTED_VERSION="main"

RELEASES_JSON=$(curl -fsSL "$GITHUB_API" 2>/dev/null || echo "")

if [ -n "$RELEASES_JSON" ] && echo "$RELEASES_JSON" | grep -q '"tag_name"'; then
    MENU_ITEMS=()
    while IFS= read -r line; do
        TAG=$(echo "$line" | grep '"tag_name"' | sed 's/.*"tag_name": *"\(.*\)".*/\1/')
        DATE=$(echo "$line" | grep '"published_at"' | sed 's/.*"published_at": *"\([0-9-]*\).*/\1/')
        [ -z "$TAG" ] && continue
        MENU_ITEMS+=("$TAG" "$DATE")
    done <<< "$(echo "$RELEASES_JSON" | grep -E '"tag_name"|"published_at"' | paste - -)"

    if [ ${#MENU_ITEMS[@]} -gt 0 ]; then
        SELECTED_VERSION=$(whiptail --title "Select version" --menu \
            "Choose which version to install:" 18 60 8 \
            "${MENU_ITEMS[@]}" \
            3>&1 1>&2 2>&3) || SELECTED_VERSION="${MENU_ITEMS[0]}"
    fi
else
    whiptail --title "Version" --msgbox \
        "No releases found on GitHub.\nInstalling latest version from main branch." 8 58
fi

# ─────────────────────────────────────────
# Auto-update
# ─────────────────────────────────────────
if whiptail --title "Auto-update" --yesno \
"Do you want to enable auto-updates?

Yes: OwnScan will automatically update itself
     when a new version is available.

No:  You will need to update manually by running:
     ownscan --update" 14 58; then
    AUTO_UPDATE="true"
else
    AUTO_UPDATE="false"
fi

# ─────────────────────────────────────────
# Install dependencies
# ─────────────────────────────────────────
{
    echo 10
    apt-get update -y > /dev/null 2>&1
    echo 30
    apt-get install -y vsftpd inotify-tools curl > /dev/null 2>&1
    echo 60
    echo "/bin/false" >> /etc/shells
    echo 80
    sleep 0.3
    echo 100
} | whiptail --title "OwnScan Installer" --gauge "Installing dependencies..." 8 60 0

# ─────────────────────────────────────────
# Create directories
# ─────────────────────────────────────────
mkdir -p /home/ftpscans
mkdir -p /home/ownscan
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

# ─────────────────────────────────────────
# Download scripts from GitHub
# ─────────────────────────────────────────
{
    echo 20
    BRANCH="$SELECTED_VERSION"
    curl -fsSL "$GITHUB_BASE_URL/$BRANCH/ownscan.sh" -o "$INSTALL_DIR/ownscan.sh"
    echo 50
    curl -fsSL "$GITHUB_BASE_URL/$BRANCH/manage.sh" -o "$INSTALL_DIR/manage.sh"
    echo 70
    curl -fsSL "$GITHUB_BASE_URL/$BRANCH/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"
    echo 90
    chmod +x "$INSTALL_DIR/"*.sh
    cp "$INSTALL_DIR/ownscan.sh" /usr/local/bin/ownscan
    chmod +x /usr/local/bin/ownscan
    echo 100
} | whiptail --title "OwnScan Installer" --gauge "Downloading OwnScan scripts..." 8 60 0

# ─────────────────────────────────────────
# Save version and config
# ─────────────────────────────────────────
if [ "$SELECTED_VERSION" = "main" ]; then
    OWNSCAN_VERSION=$(curl -fsSL "$GITHUB_BASE_URL/main/version.txt" 2>/dev/null \
        | tr -d '[:space:]' || echo "dev")
else
    OWNSCAN_VERSION="$SELECTED_VERSION"
fi

echo "$OWNSCAN_VERSION" > "$CONFIG_DIR/version"
cat > "$CONFIG_DIR/config" << EOF
OWNSCAN_AUTO_UPDATE=$AUTO_UPDATE
EOF
chmod 600 "$CONFIG_DIR/config"

# ─────────────────────────────────────────
# Configure vsftpd
# ─────────────────────────────────────────
cat > /etc/vsftpd.conf << 'EOF'
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=login
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
EOF

sed -i '/pam_shells.so/d' /etc/pam.d/vsftpd 2>/dev/null || true
systemctl enable vsftpd > /dev/null 2>&1
systemctl restart vsftpd > /dev/null 2>&1

# ─────────────────────────────────────────
# Setup update checker systemd timer
# ─────────────────────────────────────────
cat > /etc/systemd/system/ownscan-update-check.service << 'EOF'
[Unit]
Description=OwnScan update checker

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ownscan --timer
EOF

cat > /etc/systemd/system/ownscan-update-check.timer << 'EOF'
[Unit]
Description=OwnScan update check every 24 hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=24h

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload > /dev/null 2>&1
systemctl enable ownscan-update-check.timer > /dev/null 2>&1
systemctl start ownscan-update-check.timer > /dev/null 2>&1

# ─────────────────────────────────────────
# Add first user
# ─────────────────────────────────────────
whiptail --title "OwnScan Installer" --msgbox \
"You will now enter your OwnCloud login credentials
and set up a user for your Brother printer.

Each user gets their own FTP login on this server.
When scanning, the printer uses that login to send
the file to OwnScan, which then uploads it to the
correct OwnCloud account.

Note: all names and passwords are case-sensitive.
      One wrong character and it will not work." 16 58

add_user() {
    # Loop for username with back option
    while true; do
        FTP_USER=$(whiptail --title "Add user" --inputbox \
"Choose a name for this user.
This is the login name the printer will use.

Use only letters and numbers, no spaces.
Example: john or printer1

Note: this name is case-sensitive." \
14 58 3>&1 1>&2 2>&3) || return
        [ -z "$FTP_USER" ] && continue

        # Confirm username
        if whiptail --title "Confirm username" --yesno \
"The username will be: $FTP_USER

Is this correct?" 8 40; then
            break
        fi
    done

    FTP_PASS=$(whiptail --title "Add user" --passwordbox \
"Choose a password for the printer login.

This is NOT your OwnCloud password.
This is a new password you choose yourself,
which the printer will use to connect to OwnScan." \
12 58 3>&1 1>&2 2>&3) || return
    [ -z "$FTP_PASS" ] && return

    OC_URL=$(whiptail --title "Add user" --inputbox \
"Enter your OwnCloud server address.
Example: http://192.168.1.10" \
10 58 3>&1 1>&2 2>&3) || return
    [ -z "$OC_URL" ] && return

    OC_USER=$(whiptail --title "Add user" --inputbox \
"Enter your OwnCloud username.
This is the username you use to log in to OwnCloud.

Note: case-sensitive." \
12 58 3>&1 1>&2 2>&3) || return
    [ -z "$OC_USER" ] && return

    OC_PASS=$(whiptail --title "Add user" --passwordbox \
"Enter your OwnCloud password.
This is the password you use to log in to OwnCloud." \
10 58 3>&1 1>&2 2>&3) || return
    [ -z "$OC_PASS" ] && return

    OC_FOLDER=$(whiptail --title "Add user" --inputbox \
"Enter the OwnCloud folder where scans will be saved.

If this folder does not exist, it will be created." \
12 58 "Scans" 3>&1 1>&2 2>&3) || return
    [ -z "$OC_FOLDER" ] && OC_FOLDER="Scans"

    SCAN_DIR="/home/ftpscans/$FTP_USER"
    mkdir -p "$SCAN_DIR"
    useradd -m -s /bin/false -d "$SCAN_DIR" "$FTP_USER" 2>/dev/null || true
    echo "$FTP_USER:$FTP_PASS" | chpasswd
    chown "$FTP_USER":"$FTP_USER" "$SCAN_DIR"
    chmod 755 "$SCAN_DIR"

    curl -s -u "$OC_USER:$OC_PASS" -X MKCOL \
        "$OC_URL/remote.php/dav/files/$OC_USER/$OC_FOLDER/" > /dev/null 2>&1 || true

    ENV_FILE="/home/ownscan/$FTP_USER.env"
    cat > "$ENV_FILE" << ENVEOF
OWNCLOUD_URL=$OC_URL/remote.php/dav/files/$OC_USER/$OC_FOLDER
OWNCLOUD_USER=$OC_USER
OWNCLOUD_PASS=$OC_PASS
SCAN_DIR=$SCAN_DIR
ENVEOF
    chmod 600 "$ENV_FILE"

    SCRIPT="/home/ownscan/$FTP_USER-upload.sh"
    cat > "$SCRIPT" << SCRIPTEOF
#!/bin/bash
source /home/ownscan/$FTP_USER.env

inotifywait -m -e close_write "\$SCAN_DIR" |
while read dir event file; do
    curl -s -u "\$OWNCLOUD_USER:\$OWNCLOUD_PASS" \
        -T "\$SCAN_DIR/\$file" "\$OWNCLOUD_URL/\$file"
    rm "\$SCAN_DIR/\$file"
done
SCRIPTEOF
    chmod 700 "$SCRIPT"

    SERVICE="/etc/systemd/system/ownscan-$FTP_USER.service"
    cat > "$SERVICE" << SVCEOF
[Unit]
Description=OwnScan upload service for $FTP_USER
After=network.target

[Service]
ExecStart=/home/ownscan/$FTP_USER-upload.sh
Restart=always

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload > /dev/null 2>&1
    systemctl enable "ownscan-$FTP_USER" > /dev/null 2>&1
    systemctl start "ownscan-$FTP_USER" > /dev/null 2>&1

    SERVER_IP=$(hostname -I | awk '{print $1}')

    whiptail --title "User added!" --msgbox \
"User '$FTP_USER' has been added successfully.

Configure your Brother printer with these settings:

  Host:          $SERVER_IP
  Username:      $FTP_USER
  Password:      (the printer password you just set)
  Directory:     /
  Port:          21
  Passive mode:  ON

Scans will appear in OwnCloud folder: $OC_FOLDER" 18 58
}

add_user

while whiptail --title "OwnScan Installer" --yesno \
    "Do you want to add another user?" 8 50; do
    add_user
done

# ─────────────────────────────────────────
# Done
# ─────────────────────────────────────────
whiptail --title "OwnScan Installer" --msgbox \
"OwnScan $OWNSCAN_VERSION installed successfully!

Available commands:
  ownscan --version     Show current version
  ownscan --manage      Manage users
  ownscan --update      Update OwnScan
  ownscan --uninstall   Uninstall OwnScan

Auto-update: $AUTO_UPDATE" 16 58
