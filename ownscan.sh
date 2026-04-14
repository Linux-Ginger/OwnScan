#!/bin/bash

# OwnScan - Main command + update checker
# https://github.com/Linux-Ginger/OwnScan

CONFIG_DIR="/etc/ownscan"
OWNSCAN_VERSION_FILE="$CONFIG_DIR/version"
OWNSCAN_CONFIG="$CONFIG_DIR/config"
INSTALL_DIR="/usr/local/lib/ownscan"
GITHUB_VERSION_URL="https://raw.githubusercontent.com/Linux-Ginger/OwnScan/main/version.txt"
GITHUB_BASE_URL="https://raw.githubusercontent.com/Linux-Ginger/OwnScan/main"
MOTD_FILE="/etc/update-motd.d/99-ownscan-update"

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m'

source "$OWNSCAN_CONFIG" 2>/dev/null || true

get_local_version() {
    cat "$OWNSCAN_VERSION_FILE" 2>/dev/null || echo "unknown"
}

get_remote_version() {
    curl -fsSL --connect-timeout 5 "$GITHUB_VERSION_URL" 2>/dev/null | tr -d '[:space:]'
}

do_update() {
    LOCAL=$(get_local_version)
    REMOTE=$(get_remote_version)

    if [ -z "$REMOTE" ]; then
        echo -e "${RED}Could not reach GitHub. Check your internet connection.${NC}"
        exit 1
    fi

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo -e "${GREEN}OwnScan is already up to date (${LOCAL}).${NC}"
        exit 0
    fi

    echo -e "${ORANGE}Updating OwnScan from ${LOCAL} to ${REMOTE}...${NC}"

    curl -fsSL "$GITHUB_BASE_URL/ownscan.sh" -o "$INSTALL_DIR/ownscan.sh"
    curl -fsSL "$GITHUB_BASE_URL/manage.sh" -o "$INSTALL_DIR/manage.sh"
    curl -fsSL "$GITHUB_BASE_URL/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"

    chmod +x "$INSTALL_DIR/"*.sh
    cp "$INSTALL_DIR/ownscan.sh" /usr/local/bin/ownscan

    echo "$REMOTE" > "$OWNSCAN_VERSION_FILE"

    for SERVICE in /etc/systemd/system/ownscan-*.service; do
        [ -f "$SERVICE" ] || continue
        NAME=$(basename "$SERVICE" .service)
        systemctl restart "$NAME" > /dev/null 2>&1 || true
    done

    rm -f "$MOTD_FILE"
    echo -e "${GREEN}OwnScan updated to ${REMOTE} successfully.${NC}"
}

do_check_timer() {
    LOCAL=$(get_local_version)
    REMOTE=$(get_remote_version)

    [ -z "$REMOTE" ] && exit 0

    if [ "$LOCAL" = "$REMOTE" ]; then
        rm -f "$MOTD_FILE"
        exit 0
    fi

    if [ "$OWNSCAN_AUTO_UPDATE" = "true" ]; then
        do_update
    else
        cat > "$MOTD_FILE" << MOTDEOF
#!/bin/bash
echo ""
echo "  * OwnScan update available: $LOCAL -> $REMOTE"
echo "    Run 'sudo ownscan --update' to install."
echo ""
MOTDEOF
        chmod +x "$MOTD_FILE"
    fi
}

case "$1" in
    --version|-v)
        echo "OwnScan $(get_local_version)"
        ;;
    --manage|-m)
        if [ "$EUID" -ne 0 ]; then echo -e "${RED}Please run as root${NC}"; exit 1; fi
        bash "$INSTALL_DIR/manage.sh"
        reset
        ;;
    --uninstall)
        if [ "$EUID" -ne 0 ]; then echo -e "${RED}Please run as root${NC}"; exit 1; fi
        bash "$INSTALL_DIR/uninstall.sh"
        reset
        ;;
    --update|-u)
        if [ "$EUID" -ne 0 ]; then echo -e "${RED}Please run as root${NC}"; exit 1; fi
        do_update
        ;;
    --timer)
        do_check_timer
        ;;
    --help|-h|*)
        echo "OwnScan $(get_local_version)"
        echo ""
        echo "Usage:"
        echo "  ownscan --version     Show the currently installed version"
        echo "  ownscan --manage      Add, edit or remove users"
        echo "  ownscan --update      Update OwnScan to the latest version"
        echo "  ownscan --uninstall   Uninstall OwnScan from this server"
        echo "  ownscan --help        Show this help message"
        ;;
esac
