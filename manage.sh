#!/bin/bash

# OwnScan - User management
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

# Check if OwnScan is installed
if [ ! -d "/home/ownscan" ]; then
    echo -e "${RED}OwnScan is not installed. Run install.sh first.${NC}"
    exit 1
fi

# ─────────────────────────────────────────
# List users
# ─────────────────────────────────────────
list_users() {
    USERS=$(ls /home/ownscan/*.env 2>/dev/null | xargs -I{} basename {} .env | tr '\n' ' ')
    if [ -z "$USERS" ]; then
        whiptail --title "Users" --msgbox "No users found." 8 50
    else
        whiptail --title "OwnScan users" --msgbox "Current users:\n\n$USERS" 12 50
    fi
}

# ─────────────────────────────────────────
# Add user
# ─────────────────────────────────────────
add_user() {
    FTP_USER=$(whiptail --title "Add user" --inputbox "Enter a username for this user (used for FTP login):" 8 60 3>&1 1>&2 2>&3)
    [ -z "$FTP_USER" ] && return

    # Check if user already exists
    if [ -f "/home/ownscan/$FTP_USER.env" ]; then
        whiptail --title "Error" --msgbox "User '$FTP_USER' already exists." 8 50
        return
    fi

    FTP_PASS=$(whiptail --title "Add user" --passwordbox "Enter FTP password for $FTP_USER:" 8 60 3>&1 1>&2 2>&3)
    [ -z "$FTP_PASS" ] && return

    OC_URL=$(whiptail --title "Add user" --inputbox "Enter OwnCloud URL (e.g. http://192.168.1.10):" 8 60 3>&1 1>&2 2>&3)
    [ -z "$OC_URL" ] && return

    OC_USER=$(whiptail --title "Add user" --inputbox "Enter OwnCloud username:" 8 60 3>&1 1>&2 2>&3)
    [ -z "$OC_USER" ] && return

    OC_PASS=$(whiptail --title "Add user" --passwordbox "Enter OwnCloud password for $OC_USER:" 8 60 3>&1 1>&2 2>&3)
    [ -z "$OC_PASS" ] && return

    OC_FOLDER=$(whiptail --title "Add user" --inputbox "Enter OwnCloud folder to save scans in:" 8 60 "Scans" 3>&1 1>&2 2>&3)
    [ -z "$OC_FOLDER" ] && OC_FOLDER="Scans"

    SCAN_DIR="/home/ftpscans/$FTP_USER"
    mkdir -p "$SCAN_DIR"
    useradd -m -s /bin/false -d "$SCAN_DIR" "$FTP_USER" 2>/dev/null || true
    echo "$FTP_USER:$FTP_PASS" | chpasswd
    chown "$FTP_USER":"$FTP_USER" "$SCAN_DIR"
    chmod 755 "$SCAN_DIR"

    curl -s -u "$OC_USER:$OC_PASS" -X MKCOL "$OC_URL/remote.php/dav/files/$OC_USER/$OC_FOLDER/" > /dev/null 2>&1 || true

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
    curl -s -u "\$OWNCLOUD_USER:\$OWNCLOUD_PASS" -T "\$SCAN_DIR/\$file" "\$OWNCLOUD_URL/\$file"
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

# ─────────────────────────────────────────
# Edit user
# ─────────────────────────────────────────
edit_user() {
    USERS=$(ls /home/ownscan/*.env 2>/dev/null | xargs -I{} basename {} .env)
    if [ -z "$USERS" ]; then
        whiptail --title "Error" --msgbox "No users found." 8 50
        return
    fi

    MENU_ITEMS=()
    while IFS= read -r u; do
        MENU_ITEMS+=("$u" "")
    done <<< "$USERS"

    FTP_USER=$(whiptail --title "Edit user" --menu "Select user to edit:" 16 50 8 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [ -z "$FTP_USER" ] && return

    ACTION=$(whiptail --title "Edit $FTP_USER" --menu "What do you want to change?" 14 60 4 \
        "1" "Change FTP password" \
        "2" "Change OwnCloud password" \
        "3" "Change OwnCloud folder" \
        3>&1 1>&2 2>&3)

    case $ACTION in
        1)
            NEW_PASS=$(whiptail --title "Change FTP password" --passwordbox "Enter new FTP password for $FTP_USER:" 8 60 3>&1 1>&2 2>&3)
            [ -z "$NEW_PASS" ] && return
            echo "$FTP_USER:$NEW_PASS" | chpasswd
            whiptail --title "Done" --msgbox "FTP password updated for $FTP_USER." 8 50
            ;;
        2)
            NEW_OC_PASS=$(whiptail --title "Change OwnCloud password" --passwordbox "Enter new OwnCloud password:" 8 60 3>&1 1>&2 2>&3)
            [ -z "$NEW_OC_PASS" ] && return
            sed -i "s/^OWNCLOUD_PASS=.*/OWNCLOUD_PASS=$NEW_OC_PASS/" "/home/ownscan/$FTP_USER.env"
            systemctl restart "ownscan-$FTP_USER" > /dev/null 2>&1
            whiptail --title "Done" --msgbox "OwnCloud password updated for $FTP_USER." 8 50
            ;;
        3)
            NEW_FOLDER=$(whiptail --title "Change OwnCloud folder" --inputbox "Enter new OwnCloud folder:" 8 60 3>&1 1>&2 2>&3)
            [ -z "$NEW_FOLDER" ] && return
            source "/home/ownscan/$FTP_USER.env"
            BASE_URL=$(echo "$OWNCLOUD_URL" | sed 's|/[^/]*$||')
            NEW_URL="$BASE_URL/$NEW_FOLDER"
            sed -i "s|^OWNCLOUD_URL=.*|OWNCLOUD_URL=$NEW_URL|" "/home/ownscan/$FTP_USER.env"
            systemctl restart "ownscan-$FTP_USER" > /dev/null 2>&1
            whiptail --title "Done" --msgbox "OwnCloud folder updated for $FTP_USER." 8 50
            ;;
    esac
}

# ─────────────────────────────────────────
# Delete user
# ─────────────────────────────────────────
delete_user() {
    USERS=$(ls /home/ownscan/*.env 2>/dev/null | xargs -I{} basename {} .env)
    if [ -z "$USERS" ]; then
        whiptail --title "Error" --msgbox "No users found." 8 50
        return
    fi

    MENU_ITEMS=()
    while IFS= read -r u; do
        MENU_ITEMS+=("$u" "")
    done <<< "$USERS"

    FTP_USER=$(whiptail --title "Delete user" --menu "Select user to delete:" 16 50 8 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
    [ -z "$FTP_USER" ] && return

    if ! whiptail --title "Confirm" --yesno "Are you sure you want to delete user '$FTP_USER'?\nThis cannot be undone." 10 50; then
        return
    fi

    systemctl stop "ownscan-$FTP_USER" > /dev/null 2>&1 || true
    systemctl disable "ownscan-$FTP_USER" > /dev/null 2>&1 || true
    rm -f "/etc/systemd/system/ownscan-$FTP_USER.service"
    systemctl daemon-reload > /dev/null 2>&1

    userdel "$FTP_USER" 2>/dev/null || true
    rm -rf "/home/ftpscans/$FTP_USER"
    rm -f "/home/ownscan/$FTP_USER.env"
    rm -f "/home/ownscan/$FTP_USER-upload.sh"

    whiptail --title "Done" --msgbox "User '$FTP_USER' has been deleted." 8 50
}

# ─────────────────────────────────────────
# Main menu
# ─────────────────────────────────────────
while true; do
    ACTION=$(whiptail --title "OwnScan - User management" --menu "What do you want to do?" 16 60 5 \
        "1" "List users" \
        "2" "Add user" \
        "3" "Edit user" \
        "4" "Delete user" \
        "5" "Exit" \
        3>&1 1>&2 2>&3)

    case $ACTION in
        1) list_users ;;
        2) add_user ;;
        3) edit_user ;;
        4) delete_user ;;
        5) exit 0 ;;
        *) exit 0 ;;
    esac
done
