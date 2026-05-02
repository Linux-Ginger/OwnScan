#!/bin/bash

# OwnScan - Main command + update checker
# https://github.com/Linux-Ginger/OwnScan

CONFIG_DIR="/etc/ownscan"
OWNSCAN_VERSION_FILE="$CONFIG_DIR/version"
OWNSCAN_CONFIG="$CONFIG_DIR/config"
INSTALL_DIR="/usr/local/lib/ownscan"
GITHUB_API="https://api.github.com/repos/Linux-Ginger/OwnScan/releases/latest"
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
    curl -fsSL --connect-timeout 5 "$GITHUB_API" 2>/dev/null \
        | grep '"tag_name"' \
        | sed 's/.*"tag_name": *"v\?\([^"]*\)".*/\1/' \
        | tr -d '[:space:]'
}

get_release_zip_url() {
    local tag="$1"
    echo "https://github.com/Linux-Ginger/OwnScan/archive/refs/tags/v${tag}.zip"
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

    TMP_DIR=$(mktemp -d)
    ZIP_URL=$(get_release_zip_url "$REMOTE")

    curl -fsSL "$ZIP_URL" -o "$TMP_DIR/ownscan.zip"
    apt-get install -y unzip > /dev/null 2>&1
    unzip -q "$TMP_DIR/ownscan.zip" -d "$TMP_DIR"

    EXTRACTED=$(find "$TMP_DIR" -maxdepth 1 -mindepth 1 -type d | head -1)
    for SCRIPT in "$EXTRACTED"/*.sh; do
        BASENAME=$(basename "$SCRIPT")
        [ "$BASENAME" = "install.sh" ] && continue
        cp "$SCRIPT" "$INSTALL_DIR/$BASENAME"
        chmod +x "$INSTALL_DIR/$BASENAME"
    done

    cp "$INSTALL_DIR/ownscan.sh" /usr/local/bin/ownscan
    chmod +x /usr/local/bin/ownscan
    rm -rf "$TMP_DIR"

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
