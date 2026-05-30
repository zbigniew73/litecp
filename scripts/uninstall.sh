#!/usr/bin/env bash
# LiteCP uninstaller for AlmaLinux/Rocky Linux.

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[LiteCP]${NC} $*"; }
warn() { echo -e "${YELLOW}[Warning]${NC} $*"; }
error() { echo -e "${RED}[Error]${NC} $*"; exit 1; }
confirm() {
    local prompt="$1" answer
    read -r -p "${prompt} [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

[[ ${EUID} -eq 0 ]] || error "Run as root."

REMOVE_DATA=0
PURGE_PACKAGES=0
confirm "Remove LiteCP-managed users and site files too?" && REMOVE_DATA=1
confirm "Remove LiteCP-related packages installed by the panel?" && PURGE_PACKAGES=1

log "Stopping services..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl stop litecp litecp-agent litecp-caddy 2>/dev/null || true
    systemctl disable litecp litecp-agent litecp-caddy 2>/dev/null || true
fi
pkill -f '/opt/litecp/bin/litecp-agent' 2>/dev/null || true
pkill -f '/opt/litecp/bin/litecp --listen :3050' 2>/dev/null || true
pkill -f '/usr/local/bin/caddy run --config /opt/litecp/config/Caddyfile' 2>/dev/null || true

log "Removing systemd units..."
rm -f /etc/systemd/system/litecp.service
rm -f /etc/systemd/system/litecp-agent.service
rm -f /etc/systemd/system/litecp-caddy.service
rm -f /etc/systemd/system/litecp-php@.service
rm -f /etc/systemd/system/litecp-php@*.service
rm -rf /etc/systemd/system/user-*.slice.d/50-litecp-limits.conf 2>/dev/null || true
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
fi

log "Removing firewalld rules..."
if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --remove-port=3050/tcp >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
fi

log "Removing LiteCP configuration files..."
rm -rf /opt/litecp
rm -rf /var/log/litecp
rm -f /etc/pam.d/litecp
rm -f /etc/update-motd.d/99-litecp
rm -f /etc/profile.d/litecp-motd.sh
rm -f /etc/my.cnf.d/litecp.cnf
rm -f /usr/local/bin/caddy

if [[ $REMOVE_DATA -eq 1 ]]; then
    log "Removing LiteCP-managed users and data..."
    mapfile -t users < <(awk -F: '$6 ~ /^\/home\// {print $1}' /etc/passwd | grep -Ev '^(root|adm|apache|caddy|mysql|mariadb|nobody|dbus|systemd-|polkitd)$' || true)
    for u in "${users[@]}"; do
        if [[ -d "/home/${u}/apps" || -d "/home/${u}/.litecp" ]]; then
            userdel -r "$u" >/dev/null 2>&1 || warn "Could not remove user $u"
        fi
    done
fi

if [[ $PURGE_PACKAGES -eq 1 ]]; then
    log "Removing LiteCP PHP packages and optional tools..."
    dnf -y remove 'php84-php*' restic rclone >/dev/null 2>&1 || true
    dnf -y autoremove >/dev/null 2>&1 || true
else
    warn "System packages were preserved."
fi

log "LiteCP uninstall completed."