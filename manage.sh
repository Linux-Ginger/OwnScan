#!/bin/bash

# OwnScan - User management
# https://github.com/Linux-Ginger/ownscan

CONFIG_DIR="/etc/ownscan"
OWNSCAN_CONFIG="$CONFIG_DIR/config"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

if [ ! -d "$CONFIG_DIR" ]; then
    echo -e "${RED}OwnScan is not installed. Run install.sh first.${NC}"
    exit 1
fi

source "$OWNSCAN_CONFIG" 2>/dev/null || true

# ─────────────────────────────────────────
# List users
# ─────────────────────────────────────────
list_users() {
    ENVFILES=($(ls /home/ownscan/*.env 2>/dev/null))
    if [ ${#ENVFILES[@]} -eq 0 ]; then
        whiptail --title "Users" --msgbox "No users found." 8 50
        return
    fi

    MSG=""
    I=1
    for ENV in "${ENVFILES[@]}"; do
        USER=$(basename "$ENV" .env)
        MSG="$MSG  $I. $USER\n"
        I=$((I+1))
    done

    whiptail --title "OwnScan users" --msgbox "Current users:\n\n$MSG" 16 50
}

# ─────────────────────────────────────────
# Add user
# ─────────────────────────────────────────
add_user() {
    # Username with back/retry loop
    while true; do
        FTP_USER=$(whiptail --title "Add user" --inputbox \
"Choose a name for this user.
This is the login name the printer will use.

Use only letters and numbers, no spaces.
Example: john or printer1" \
12 58 3>&1 1>&2 2>&3)
        EXIT=$?
        [ $EXIT -ne 0 ] && return

        if [ -z "$FTP_USER" ]; then
            whiptail --title "Error" --msgbox "Username cannot be empty." 8 40
            continue
        fi

        if [ -f "/home/ownscan/$FTP_USER.env" ]; then
            whiptail --title "Error" --msgbox "User '$FTP_USER' already exists." 8 50
            continue
        fi

        if whiptail --title "Confirm username" --yesno \
"The username will be: $FTP_USER

Is this correct?" 8 40; then
            break
        fi
    done

    # Printer password
    while true; do
        FTP_PASS=$(whiptail --title "Add user" --passwordbox \
"Choose a password for the printer login.

This is NOT your OwnCloud password.
This is a new password you choose yourself,
which the printer will use to connect to OwnScan." \
12 58 3>&1 1>&2 2>&3)
        EXIT=$?
        [ $EXIT -ne 0 ] && return
        if [ -z "$FTP_PASS" ]; then
            whiptail --title "Error" --msgbox "Password cannot be empty." 8 40
            continue
        fi
        break
    done

    # OwnCloud URL
    while true; do
        OC_URL=$(whiptail --title "Add user" --inputbox \
"Enter your OwnCloud server address.
Example: 192.168.1.10" \
10 58 3>&1 1>&2 2>&3)
        EXIT=$?
        [ $EXIT -ne 0 ] && return
        if [ -z "$OC_URL" ]; then
            whiptail --title "Error" --msgbox "OwnCloud URL cannot be empty." 8 45
            continue
        fi
        # Strip http:// or https:// if user added it anyway
        OC_URL=$(echo "$OC_URL" | sed 's|^https\?://||')
        OC_URL="http://$OC_URL"
        break
    done

    # OwnCloud username
    while true; do
        OC_USER=$(whiptail --title "Add user" --inputbox \
"Enter your OwnCloud username.
This is the username you use to log in to OwnCloud.

Note: case-sensitive." \
12 58 3>&1 1>&2 2>&3)
        EXIT=$?
        [ $EXIT -ne 0 ] && return
        if [ -z "$OC_USER" ]; then
            whiptail --title "Error" --msgbox "OwnCloud username cannot be empty." 8 45
            continue
        fi
        break
    done

    # OwnCloud password
    while true; do
        OC_PASS=$(whiptail --title "Add user" --passwordbox \
"Enter your OwnCloud password.
This is the password you use to log in to OwnCloud.

Note: case-sensitive." \
12 58 3>&1 1>&2 2>&3)
        EXIT=$?
        [ $EXIT -ne 0 ] && return
        if [ -z "$OC_PASS" ]; then
            whiptail --title "Error" --msgbox "OwnCloud password cannot be empty." 8 45
            continue
        fi
        break
    done

    # OwnCloud folder
    while true; do
        OC_FOLDER=$(whiptail --title "Add user" --inputbox \
"Enter the OwnCloud folder where scans will be saved.

If this folder does not exist, it will be created." \
12 58 "Scans" 3>&1 1>&2 2>&3)
        EXIT=$?
        [ $EXIT -ne 0 ] && return
        if [ -z "$OC_FOLDER" ]; then
            whiptail --title "Error" --msgbox "Folder name cannot be empty." 8 40
            continue
        fi
        break
    done

    # Create FTP user
    SCAN_DIR="/home/ftpscans/$FTP_USER"
    mkdir -p "$SCAN_DIR"
    useradd -m -s /bin/false -d "$SCAN_DIR" "$FTP_USER" 2>/dev/null || true
    echo "$FTP_USER:$FTP_PASS" | chpasswd
    chown "$FTP_USER":"$FTP_USER" "$SCAN_DIR"
    chmod 755 "$SCAN_DIR"

    # Create OwnCloud folder
    curl -s -u "$OC_USER:$OC_PASS" -X MKCOL \
        "$OC_URL/remote.php/dav/files/$OC_USER/$OC_FOLDER/" > /dev/null 2>&1 || true

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
    curl -s -u "\$OWNCLOUD_USER:\$OWNCLOUD_PASS" \
        -T "\$SCAN_DIR/\$file" "\$OWNCLOUD_URL/\$file"
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

Scans will appear in OwnCloud folder: $OC_FOLDER" 20 58
}

# ─────────────────────────────────────────
# Edit user
# ─────────────────────────────────────────
edit_user() {
    USERS=($(ls /home/ownscan/*.env 2>/dev/null | xargs -I{} basename {} .env))
    if [ ${#USERS[@]} -eq 0 ]; then
        whiptail --title "Error" --msgbox "No users found." 8 50
        return
    fi

    MENU_ITEMS=()
    I=1
    for U in "${USERS[@]}"; do
        MENU_ITEMS+=("$U" "$I.")
        I=$((I+1))
    done

    FTP_USER=$(whiptail --title "Edit user" --nocancel --menu \
        "Select user to edit:" 16 50 8 \
        "${MENU_ITEMS[@]}" \
        "< Back" "" \
        3>&1 1>&2 2>&3) || return
    [ "$FTP_USER" = "< Back" ] && return

    ACTION=$(whiptail --title "Edit $FTP_USER" --menu \
        "What do you want to change?" 14 60 4 \
        "1" "Change printer password" \
        "2" "Change OwnCloud password" \
        "3" "Change OwnCloud folder" \
        3>&1 1>&2 2>&3) || return

    case $ACTION in
        1)
            while true; do
                NEW_PASS=$(whiptail --title "Change printer password" --passwordbox \
                    "Enter new printer password for $FTP_USER:" 8 58 3>&1 1>&2 2>&3) || return
                if [ -z "$NEW_PASS" ]; then
                    whiptail --title "Error" --msgbox "Password cannot be empty." 8 40
                    continue
                fi
                break
            done
            echo "$FTP_USER:$NEW_PASS" | chpasswd
            whiptail --title "Done" --msgbox "Printer password updated for $FTP_USER." 8 50
            ;;
        2)
            while true; do
                NEW_OC_PASS=$(whiptail --title "Change OwnCloud password" --passwordbox \
                    "Enter new OwnCloud password for $FTP_USER:" 8 58 3>&1 1>&2 2>&3) || return
                if [ -z "$NEW_OC_PASS" ]; then
                    whiptail --title "Error" --msgbox "Password cannot be empty." 8 40
                    continue
                fi
                break
            done
            sed -i "s/^OWNCLOUD_PASS=.*/OWNCLOUD_PASS=$NEW_OC_PASS/" \
                "/home/ownscan/$FTP_USER.env"
            systemctl restart "ownscan-$FTP_USER" > /dev/null 2>&1
            whiptail --title "Done" --msgbox "OwnCloud password updated for $FTP_USER." 8 50
            ;;
        3)
            while true; do
                NEW_FOLDER=$(whiptail --title "Change OwnCloud folder" --inputbox \
"Enter new OwnCloud folder for $FTP_USER.

If this folder does not exist, it will be created." \
12 58 3>&1 1>&2 2>&3) || return
                if [ -z "$NEW_FOLDER" ]; then
                    whiptail --title "Error" --msgbox "Folder name cannot be empty." 8 40
                    continue
                fi
                break
            done
            source "/home/ownscan/$FTP_USER.env"
            BASE_URL=$(echo "$OWNCLOUD_URL" | sed 's|/[^/]*$||')
            NEW_URL="$BASE_URL/$NEW_FOLDER"
            sed -i "s|^OWNCLOUD_URL=.*|OWNCLOUD_URL=$NEW_URL|" \
                "/home/ownscan/$FTP_USER.env"
            systemctl restart "ownscan-$FTP_USER" > /dev/null 2>&1
            whiptail --title "Done" --msgbox "OwnCloud folder updated for $FTP_USER." 8 50
            ;;
    esac
}

# ─────────────────────────────────────────
# Delete user
# ─────────────────────────────────────────
delete_user() {
    USERS=($(ls /home/ownscan/*.env 2>/dev/null | xargs -I{} basename {} .env))
    if [ ${#USERS[@]} -eq 0 ]; then
        whiptail --title "Error" --msgbox "No users found." 8 50
        return
    fi

    MENU_ITEMS=()
    I=1
    for U in "${USERS[@]}"; do
        MENU_ITEMS+=("$U" "$I.")
        I=$((I+1))
    done

    FTP_USER=$(whiptail --title "Delete user" --nocancel --menu \
        "Select user to delete:" 16 50 8 \
        "${MENU_ITEMS[@]}" \
        "< Back" "" \
        3>&1 1>&2 2>&3) || return
    [ "$FTP_USER" = "< Back" ] && return

    if ! whiptail --title "Confirm" --yesno \
        "Are you sure you want to delete '$FTP_USER'?\nThis cannot be undone." 10 50; then
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
# Auto-update settings
# ─────────────────────────────────────────
toggle_autoupdate() {
    if [ "$OWNSCAN_AUTO_UPDATE" = "true" ]; then
        CURRENT="enabled"
    else
        CURRENT="disabled"
    fi

    if whiptail --title "Auto-update" --yesno \
"Auto-update is currently $CURRENT.

Enable auto-update?

Yes: OwnScan updates automatically when a new
     version is available.

No:  You will need to update manually by running:
     ownscan --update" 16 58; then
        sed -i "s/^OWNSCAN_AUTO_UPDATE=.*/OWNSCAN_AUTO_UPDATE=true/" "$OWNSCAN_CONFIG"
        OWNSCAN_AUTO_UPDATE="true"
        whiptail --title "Done" --msgbox "Auto-update enabled." 8 50
    else
        sed -i "s/^OWNSCAN_AUTO_UPDATE=.*/OWNSCAN_AUTO_UPDATE=false/" "$OWNSCAN_CONFIG"
        OWNSCAN_AUTO_UPDATE="false"
        rm -f /etc/update-motd.d/99-ownscan-update
        whiptail --title "Done" --msgbox "Auto-update disabled." 8 50
    fi
}

# ─────────────────────────────────────────
# Main menu
# ─────────────────────────────────────────
CHANGES=""

while true; do
    ACTION=$(whiptail --title "OwnScan - Management" --menu \
        "What do you want to do?" 18 60 6 \
        "1" "List users" \
        "2" "Add user" \
        "3" "Edit user" \
        "4" "Delete user" \
        "5" "Auto-update settings" \
        "6" "Exit" \
        3>&1 1>&2 2>&3) || break

    case $ACTION in
        1) list_users ;;
        2)
            add_user
            CHANGES="$CHANGES\n- User added or modified"
            ;;
        3)
            edit_user
            CHANGES="$CHANGES\n- User settings changed"
            ;;
        4)
            delete_user
            CHANGES="$CHANGES\n- User deleted"
            ;;
        5)
            toggle_autoupdate
            CHANGES="$CHANGES\n- Auto-update changed to: $OWNSCAN_AUTO_UPDATE"
            ;;
        6) break ;;
    esac
done

# Show summary on exit
if [ -n "$CHANGES" ]; then
    whiptail --title "OwnScan - Summary" --msgbox \
"Changes made this session:
$CHANGES" 14 58
else
    whiptail --title "OwnScan - Summary" --msgbox \
"No changes were made." 8 40
fi

reset
