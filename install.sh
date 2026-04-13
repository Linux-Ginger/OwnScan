#!/bin/bash

# OwnScan - Your scans, straight to OwnCloud - self-hosted
# https://github.com/Linux-Ginger/ownscan
# Only for use on a local network, NOT for internet-facing servers.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
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

# ─────────────────────────────────────────
# Welcome screen
# ─────────────────────────────────────────
whiptail --title "OwnScan Installer" --msgbox "\
Welcome to the OwnScan installer!\n\
\n\
OwnScan bridges your Brother printer and OwnCloud.\n\
Scans are sent via FTP and uploaded to OwnCloud.\n\
\n\
⚠  Only use this on a LOCAL network.\n\
   Do NOT expose this to the internet.\n\
\n\
Press OK to continue." 18 60

# ─────────────────────────────────────────
# Check OS
# ─────────────────────────────────────────
if ! grep -qEi "debian|ubuntu" /etc/os-release; then
    whiptail --title "Error" --msgbox "OwnScan only supports Debian/Ubuntu." 8 50
    exit 1
fi

# ─────────────────────────────────────────
# Install dependencies
# ─────────────────────────────────────────
{
    echo 10
    sleep 0.5
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

# Fix PAM
sed -i '/pam_shells.so/d' /etc/pam.d/vsftpd 2>/dev/null || true

systemctl enable vsftpd > /dev/null 2>&1
systemctl restart vsftpd > /dev/null 2>&1

# ─────────────────────────────────────────
# Add first user
# ─────────────────────────────────────────
whiptail --title "OwnScan Installer" --msgbox "Now you will add your first OwnCloud user." 8 50

add_user() {
    # Username
    FTP_USER=$(whiptail --title "Add user" --inputbox "Enter a username for this user (used for FTP login):" 8 60 3>&1 1>&2 2>&3)
    [ -z "$FTP_USER" ] && return

    # FTP password
    FTP_PASS=$(whiptail --title "Add user" --passwordbox "Enter FTP password for $FTP_USER:" 8 60 3>&1 1>&2 2>&3)
    [ -z "$FTP_PASS" ] && return

    # OwnCloud URL
    OC_URL=$(whiptail --title "Add user" --inputbox "Enter OwnCloud URL (e.g. http://192.168.1.10):" 8 60 3>&1 1>&2 2>&3)
    [ -z "$OC_URL" ] && return

    # OwnCloud username
    OC_USER=$(whiptail --title "Add user" --inputbox "Enter OwnCloud username:" 8 60 3>&1 1>&2 2>&3)
    [ -z "$OC_USER" ] && return

    # OwnCloud password
    OC_PASS=$(whiptail --title "Add user" --passwordbox "Enter OwnCloud password for $OC_USER:" 8 60 3>&1 1>&2 2>&3)
    [ -z "$OC_PASS" ] && return

    # OwnCloud scan folder
    OC_FOLDER=$(whiptail --title "Add user" --inputbox "Enter OwnCloud folder to save scans in (e.g. Scans):" 8 60 "Scans" 3>&1 1>&2 2>&3)
    [ -z "$OC_FOLDER" ] && OC_FOLDER="Scans"

    # Create FTP user
    SCAN_DIR="/home/ftpscans/$FTP_USER"
    mkdir -p "$SCAN_DIR"
    useradd -m -s /bin/false -d "$SCAN_DIR" "$FTP_USER" 2>/dev/null || true
    echo "$FTP_USER:$FTP_PASS" | chpasswd
    chown "$FTP_USER":"$FTP_USER" "$SCAN_DIR"
    chmod 755 "$SCAN_DIR"

    # Create OwnCloud folder via WebDAV
    curl -s -u "$OC_USER:$OC_PASS" -X MKCOL "$OC_URL/remote.php/dav/files/$OC_USER/$OC_FOLDER/" > /dev/null 2>&1 || true

    # Save .env
    ENV_FILE="/home/ownscan/$FTP_USER.env"
    cat > "$ENV_FILE" << ENVEOF
OWNCLOUD_URL=$OC_URL/remote.php/dav/files/$OC_USER/$OC_FOLDER
OWNCLOUD_USER=$OC_USER
OWNCLOUD_PASS=$OC_PASS
SCAN_DIR=$SCAN_DIR
ENVEOF
    chmod 600 "$ENV_FILE"

    # Create upload script
    SCRIPT="/home/ownscan/$FTP_USER-upload.sh"
    cat > "$SCRIPT" << SCRIPTEOF
#!/bin/bash
source /home/ownscan/$FTP_USER.env

inotifywait -m -e close_write "\$SCAN_DIR" |
while read dir event file; do
    curl -s -u "\$OWNCLOUD_USER:\$OWNCLOUD_PASS" -T "\$SCAN_DIR/\$file" "\$OWNCLOUD_URL/\$file"
    rm "\$SCAN_DIR/\$file"
done
SCRIPTEOF
    chmod 700 "$SCRIPT"

    # Create systemd service
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

    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    whiptail --title "User added!" --msgbox "\
User '$FTP_USER' has been added.\n\
\n\
Brother printer FTP settings:\n\
  Host:     $SERVER_IP\n\
  Username: $FTP_USER\n\
  Password: (what you entered)\n\
  Directory: /\n\
  Port:     21\n\
  Passive:  ON\n\
\n\
Scans will appear in OwnCloud folder: $OC_FOLDER" 18 60
}

add_user

# ─────────────────────────────────────────
# Add more users?
# ─────────────────────────────────────────
while whiptail --title "OwnScan Installer" --yesno "Do you want to add another user?" 8 50; do
    add_user
done

# ─────────────────────────────────────────
# Done
# ─────────────────────────────────────────
whiptail --title "OwnScan Installer" --msgbox "\
OwnScan has been installed successfully!\n\
\n\
To manage users later, run:\n\
  bash manage.sh\n\
\n\
To uninstall, run:\n\
  bash uninstall.sh" 14 60
