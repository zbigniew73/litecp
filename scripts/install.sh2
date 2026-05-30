#!/usr/bin/env bash
# LiteCP installer for AlmaLinux 8/9 and Rocky Linux 8/9.

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_LOG=""

log() { echo -e "${GREEN}[LiteCP]${NC} $*"; }
warn() { echo -e "${YELLOW}[Warning]${NC} $*"; }
error() {
    echo -e "${RED}[Error]${NC} $*"
    [[ -n "${INSTALL_LOG}" ]] && echo "Install log: ${INSTALL_LOG}"
    exit 1
}

setup_logging() {
    mkdir -p /var/log/litecp
    chmod 0755 /var/log/litecp
    INSTALL_LOG="${LITECP_INSTALL_LOG:-/var/log/litecp/install-$(date +%Y%m%d-%H%M%S).log}"
    touch "${INSTALL_LOG}"
    chmod 0644 "${INSTALL_LOG}"
    exec > >(tee -a "${INSTALL_LOG}") 2>&1
    trap 'rc=$?; if [[ $rc -ne 0 ]]; then echo -e "${RED}[Error]${NC} Installer failed with exit code ${rc}"; echo "Install log: ${INSTALL_LOG}"; fi' EXIT
    log "Installer log: ${INSTALL_LOG}"
}

is_litecp_source_dir() {
    [[ -f "$1/go.mod" && -d "$1/cmd/litecp" && -d "$1/cmd/litecp-agent" ]]
}

cd_repo_root() {
    local script_dir candidate
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P 2>/dev/null || pwd -P)"

    for candidate in "${script_dir}/.." "${script_dir}" "${PWD}"; do
        if is_litecp_source_dir "${candidate}"; then
            cd "${candidate}"
            log "Using LiteCP source directory: $(pwd -P)"
            return 0
        fi
    done

    warn "LiteCP source tree was not found relative to install.sh or current directory. It will be cloned after base dependencies are installed."
}

ensure_source_tree() {
    if is_litecp_source_dir "$(pwd -P)"; then
        return 0
    fi

    local repo_url source_dir branch
    repo_url="${LITECP_REPO_URL:-https://github.com/zbigniew73/litecp.git}"
    source_dir="${LITECP_SOURCE_DIR:-/usr/local/src/litecp}"
    branch="${LITECP_BRANCH:-main}"

    command -v git >/dev/null 2>&1 || error "git is required to clone LiteCP source."

    if [[ -d "${source_dir}/.git" ]]; then
        log "Updating LiteCP source repository in ${source_dir}..."
        git -C "${source_dir}" fetch --all --tags
        git -C "${source_dir}" checkout "${branch}"
        git -C "${source_dir}" pull --ff-only
    elif [[ -e "${source_dir}" ]]; then
        if is_litecp_source_dir "${source_dir}"; then
            log "Using existing LiteCP source directory: ${source_dir}"
        else
            error "${source_dir} exists but is not a LiteCP source tree. Set LITECP_SOURCE_DIR to another path or move the existing directory."
        fi
    else
        log "Cloning LiteCP source from ${repo_url} to ${source_dir}..."
        mkdir -p "$(dirname -- "${source_dir}")"
        git clone --branch "${branch}" "${repo_url}" "${source_dir}"
    fi

    is_litecp_source_dir "${source_dir}" || error "LiteCP source tree is incomplete after clone/update: ${source_dir}"
    cd "${source_dir}"
    log "Using LiteCP source directory: $(pwd -P)"
}

has_systemd() {
    command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]
}

run_dnf() {
    log "Running: dnf -y $*"
    dnf -y "$@"
}

pkg_exists() {
    rpm -q "$1" >/dev/null 2>&1 || dnf -q list --available "$1" >/dev/null 2>&1
}

install_if_available() {
    local packages=()
    local pkg
    for pkg in "$@"; do
        if pkg_exists "$pkg"; then
            packages+=("$pkg")
        else
            warn "Package not available, skipping: $pkg"
        fi
    done
    if [[ ${#packages[@]} -gt 0 ]]; then
        run_dnf install "${packages[@]}"
    fi
}

print_banner() {
    echo ""
    if [[ -f ./assets/logowkonsolissh.sh ]]; then
        bash ./assets/logowkonsolissh.sh
    else
        echo -e "${BLUE}${BOLD}LiteCP - Caddy Lite Control Panel${NC}"
    fi
    echo "Target: AlmaLinux/Rocky Linux 8/9"
    echo "Install path: /opt/litecp"
    echo ""
}

require_root() {
    [[ ${EUID} -eq 0 ]] || error "This installer must be run as root."
}

detect_os() {
    [[ -r /etc/os-release ]] || error "Cannot read /etc/os-release."
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${ID}" in
        almalinux|rocky) ;;
        *) error "Unsupported OS: ${PRETTY_NAME:-$ID}. LiteCP supports AlmaLinux 8/9 and Rocky Linux 8/9." ;;
    esac
    OS_MAJOR="${VERSION_ID%%.*}"
    case "${OS_MAJOR}" in
        8|9) ;;
        *) error "Unsupported major version: ${VERSION_ID}. LiteCP supports only 8.x and 9.x." ;;
    esac
    log "Detected ${PRETTY_NAME}"
}

detect_arch() {
    case "$(uname -m)" in
        x86_64) ARCH="amd64"; CADDY_ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64"; CADDY_ARCH="arm64" ;;
        *) error "Unsupported architecture: $(uname -m)" ;;
    esac
    log "Architecture: ${ARCH}"
}

disable_selinux() {
    if command -v getenforce >/dev/null 2>&1; then
        local state
        state="$(getenforce 2>/dev/null || true)"
        if [[ "$state" != "Disabled" ]]; then
            warn "SELinux is ${state}; switching runtime mode to permissive and config to disabled. Reboot is required for full disable."
            setenforce 0 >/dev/null 2>&1 || true
        fi
    fi
    if [[ -f /etc/selinux/config ]]; then
        sed -ri 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    fi
}

install_repositories() {
    log "Installing EPEL and Remi repositories..."
    run_dnf install dnf-plugins-core ca-certificates curl wget firewalld sudo nano
    if ! rpm -q epel-release >/dev/null 2>&1; then
        run_dnf install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_MAJOR}.noarch.rpm"
    fi
    if ! rpm -q remi-release >/dev/null 2>&1; then
        run_dnf install "https://rpms.remirepo.net/enterprise/remi-release-${OS_MAJOR}.rpm"
    fi
    dnf config-manager --set-enabled epel >/dev/null 2>&1 || true
    dnf config-manager --set-enabled remi-safe >/dev/null 2>&1 || true
    dnf makecache -y
}

install_base_dependencies() {
    log "Installing base dependencies..."
    local deps=(
        acl bash-completion ca-certificates cronie curl findutils firewalld gawk gcc gzip bash-completion glibc-langpack-pl
        libcap make mariadb mariadb-server openssl pam pam-devel policycoreutils procps-ng zstd zip unzip bzip2 git brotli socat
        restic rsync golang sed shadow-utils sqlite sqlite-devel sudo tar unzip wget which mc htop rsyslog which cronie bind-utils net-tools
    )
    run_dnf install "${deps[@]}"
}

ensure_swap() {
    local total_kb swap_kb
    total_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
    swap_kb="$(awk '/SwapTotal/ {print $2}' /proc/meminfo)"
    if [[ "$total_kb" -le 2097152 && "$swap_kb" -lt 524288 ]]; then
        log "Creating 1GB swapfile for low-memory server..."
        if [[ ! -f /swapfile ]]; then
            fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
            chmod 600 /swapfile
            mkswap /swapfile >/dev/null
        fi
        swapon /swapfile 2>/dev/null || true
        grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
}

create_layout() {
    log "Creating LiteCP directories..."
    mkdir -p /opt/litecp/{bin,data,config,ssl,run,phpmyadmin}
    mkdir -p /opt/litecp/config/{users,php}
    mkdir -p /var/log/litecp
    chmod 0755 /opt/litecp/run
    chmod 0755 /opt/litecp/config
    chmod 0700 /opt/litecp/data
    chmod 1777 /var/log/litecp
    rm -f /etc/tmpfiles.d/litecp.conf
    rm -rf /var/run/litecp

    if [[ ! -f /opt/litecp/data/.secret ]]; then
        openssl rand -base64 32 > /opt/litecp/data/.secret
        chmod 0600 /opt/litecp/data/.secret
    fi
}

ensure_caddy_user() {
    if ! getent group caddy >/dev/null; then
        groupadd --system caddy
    fi
    if ! id -u caddy >/dev/null 2>&1; then
        useradd --system --gid caddy --home-dir /var/lib/caddy --shell /sbin/nologin caddy
    fi
    mkdir -p /var/lib/caddy
    chown -R caddy:caddy /var/lib/caddy
}

install_php() {
    log "Installing PHP 8.4 from Remi..."
    local stream="php84"
    local required=(
        ${stream}-php-fpm ${stream}-php-cli ${stream}-php-common ${stream}-php-mysqlnd ${stream}-php-pdo
    )
    local optional=(
        ${stream}-php-bcmath ${stream}-php-gd ${stream}-php-xml ${stream}-php-pear
        ${stream}-php-gmp ${stream}-php-intl ${stream}-php-mbstring
        ${stream}-php-opcache ${stream}-php-process ${stream}-php-soap
        ${stream}-php-sodium ${stream}-php-xml ${stream}-php-pecl-igbinary ${stream}-php-pecl-imagick-im7 
        ${stream}-php-pecl-apcu ${stream}-php-json ${stream}-php-devel ${stream}-php-zstd
    )
    run_dnf install "${required[@]}"
    install_if_available "${optional[@]}"
    mkdir -p /etc/opt/remi/php84/php-fpm.d
    cat > /opt/litecp/config/php-defaults.json << 'EOF'
{
  "default_php_version": "8.4"
}
EOF
    if has_systemd; then
        systemctl enable --now php84-php-fpm
    fi
}

install_caddy() {
    log "Installing Caddy from COPR repository..."

    if command -v caddy >/dev/null 2>&1; then
        local existing_caddy
        existing_caddy="$(command -v caddy)"
        log "Caddy already installed: ${existing_caddy} ($(caddy version 2>/dev/null || echo unknown))"
        if [[ "${existing_caddy}" != "/usr/local/bin/caddy" && ! -e /usr/local/bin/caddy ]]; then
            ln -s "${existing_caddy}" /usr/local/bin/caddy
        fi
        setcap cap_net_bind_service=+ep "${existing_caddy}" 2>/dev/null || true
        return 0
    fi

    if ! command -v dnf >/dev/null 2>&1; then
        error "dnf is required to install Caddy on AlmaLinux/Rocky Linux."
    fi

    log "Installing dnf COPR plugin..."
    if ! dnf -y install 'dnf-command(copr)'; then
        run_dnf install dnf-plugins-core
    fi

    log "Enabling Caddy COPR repository @caddy/caddy..."
    dnf copr enable -y @caddy/caddy || error "Failed to enable @caddy/caddy COPR repository."

    log "Installing Caddy package..."
    run_dnf install caddy

    local caddy_bin
    caddy_bin="$(command -v caddy || true)"
    [[ -n "${caddy_bin}" ]] || error "Caddy package installed but caddy binary was not found in PATH."
    log "Caddy installed: ${caddy_bin} ($(${caddy_bin} version 2>/dev/null || echo unknown))"

    # LiteCP uses litecp-caddy.service, but migrations and fallback code expect /usr/local/bin/caddy.
    if [[ "${caddy_bin}" != "/usr/local/bin/caddy" && ! -e /usr/local/bin/caddy ]]; then
        ln -s "${caddy_bin}" /usr/local/bin/caddy
    fi
    setcap cap_net_bind_service=+ep "${caddy_bin}" 2>/dev/null || true

    if has_systemd; then
        systemctl disable --now caddy >/dev/null 2>&1 || true
    fi
}

download_release_binary() {
    local url="$1"
    local dest="$2"
    log "Downloading ${url}"
    if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 -o "${dest}" "${url}"; then
        rm -f "${dest}"
        return 1
    fi
    [[ -s "${dest}" ]]
}

install_binaries() {
    log "Installing LiteCP binaries..."
    local version release_url
    version="${LITECP_VERSION:-latest}"
    if [[ -f ./go.mod && -d ./cmd/litecp && -d ./cmd/litecp-agent ]]; then
        command -v go >/dev/null 2>&1 || error "Go was not found after dependency installation; cannot build LiteCP from source."
        log "Building local source with CGO/PAM support from $(pwd -P)..."
        CGO_ENABLED=1 go build -o /opt/litecp/bin/litecp ./cmd/litecp
        CGO_ENABLED=1 go build -o /opt/litecp/bin/litecp-agent ./cmd/litecp-agent
    elif [[ -f ./litecp && -f ./litecp-agent ]]; then
        log "Installing bundled LiteCP binaries from current directory..."
        cp ./litecp /opt/litecp/bin/litecp
        cp ./litecp-agent /opt/litecp/bin/litecp-agent
    else
        if [[ "$version" == "latest" ]]; then
            release_url="https://github.com/zbigniew73/litecp/releases/latest/download"
        else
            release_url="https://github.com/zbigniew73/litecp/releases/download/${version}"
        fi
        if ! download_release_binary "${release_url}/litecp-linux-${ARCH}" /opt/litecp/bin/litecp || \
           ! download_release_binary "${release_url}/litecp-agent-linux-${ARCH}" /opt/litecp/bin/litecp-agent; then
            error "LiteCP release binaries are not available at ${release_url}. Run this installer from the litecp source directory with Go installed, place ./litecp and ./litecp-agent next to install.sh, or publish a GitHub release first."
        fi
    fi
    chmod 0755 /opt/litecp/bin/litecp /opt/litecp/bin/litecp-agent
}

write_pam_config() {
    log "Writing PAM service /etc/pam.d/litecp..."
    cat > /etc/pam.d/litecp << 'EOF'
#%PAM-1.0
auth       required     pam_env.so
auth       sufficient   pam_unix.so try_first_pass
auth       required     pam_deny.so
account    required     pam_unix.so
password   required     pam_unix.so sha512 shadow try_first_pass use_authtok
session    required     pam_limits.so
session    required     pam_unix.so
EOF
    chmod 0644 /etc/pam.d/litecp
}

write_base_config() {
    log "Writing initial LiteCP configuration..."
    cat > /opt/litecp/config/Caddyfile << 'EOF'
{
    admin localhost:2019
}

:80 {
    respond "LiteCP - No sites configured" 404
}
EOF
    cat > /opt/litecp/config/caddy-settings.json << 'EOF'
{
  "profile": "low_ram",
  "access_logs": false,
  "expert_mode": false,
  "read_header": "8s",
  "read_body": "20s",
  "write_timeout": "45s",
  "idle_timeout": "45s",
  "grace_period": "5s",
  "max_header_size": 16384
}
EOF
    cat > /opt/litecp/config/php/99-litecp.ini << 'EOF'
display_errors = Off
expose_php = Off
error_reporting = 22527
EOF
    mkdir -p /opt/litecp/ui/dist/assets
    if [[ -d ./cmd/litecp/ui/dist/assets ]]; then
        cp -a ./cmd/litecp/ui/dist/assets/. /opt/litecp/ui/dist/assets/
    fi
    if [[ -f ./assets/logowkonsolissh.sh ]]; then
        install -m 0755 ./assets/logowkonsolissh.sh /opt/litecp/config/logowkonsolissh.sh
    fi
    rm -f /etc/motd.d/99-litecp /etc/update-motd.d/99-litecp
    cat > /etc/profile.d/litecp-motd.sh << 'EOF'
#!/bin/sh
# Show LiteCP MOTD for interactive SSH/login shells on RHEL-family systems.
case "$-" in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

if [ -n "${LITECP_MOTD_SHOWN:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
export LITECP_MOTD_SHOWN=1

if [ -x /opt/litecp/config/litecp-motd.sh ]; then
  /opt/litecp/config/litecp-motd.sh
fi
EOF
    chmod 0644 /etc/profile.d/litecp-motd.sh
}

generate_panel_cert() {
    log "Generating self-signed panel certificate..."
    local host cert_ip ips
    host="$(hostname -f 2>/dev/null || hostname)"
    ips="$(hostname -I 2>/dev/null || true)"
    cert_ip="$(echo "$ips" | tr ' ' '\n' | awk '/^([0-9]{1,3}\.){3}[0-9]{1,3}$/ {print; exit}')"
    [[ -n "$cert_ip" ]] || cert_ip="127.0.0.1"
    if [[ ! -f /opt/litecp/ssl/server.crt || ! -f /opt/litecp/ssl/server.key ]]; then
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout /opt/litecp/ssl/server.key \
            -out /opt/litecp/ssl/server.crt \
            -subj "/C=US/O=LiteCP/CN=${host}" \
            -addext "subjectAltName=DNS:${host},DNS:localhost,IP:127.0.0.1,IP:${cert_ip}" \
            >/dev/null 2>&1
        chmod 0600 /opt/litecp/ssl/server.key
        chmod 0644 /opt/litecp/ssl/server.crt
    fi
}

configure_mariadb() {
    log "Configuring MariaDB..."
    mkdir -p /etc/my.cnf.d
    cat > /etc/my.cnf.d/litecp.cnf << 'EOF'
[mysqld]
# LiteCP conservative defaults for small VPS instances.
innodb_buffer_pool_size = 128M
innodb_log_file_size = 16M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
key_buffer_size = 4M
max_connections = 30
table_open_cache = 200
thread_cache_size = 8
performance_schema = OFF
skip-name-resolve
EOF
    if has_systemd; then
        systemctl enable --now mariadb
        systemctl restart mariadb
    fi
}

install_phpmyadmin() {
    log "Installing phpMyAdmin..."
    local version secret
    version="5.2.2"
    rm -rf /opt/litecp/phpmyadmin/*
    curl -fsSL "https://files.phpmyadmin.net/phpMyAdmin/${version}/phpMyAdmin-${version}-all-languages.tar.gz" \
        | tar xz --strip-components=1 -C /opt/litecp/phpmyadmin
    secret="$(openssl rand -hex 16)"
    cat > /opt/litecp/phpmyadmin/config.inc.php << EOF
<?php
error_reporting(E_ALL & ~E_DEPRECATED & ~E_STRICT);
\$cfg['blowfish_secret'] = '${secret}';
\$cfg['TempDir'] = '/opt/litecp/run/phpmyadmin-tmp';
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['host'] = '127.0.0.1';
\$cfg['Servers'][\$i]['auth_type'] = 'config';
\$cfg['Servers'][\$i]['user'] = \$_SERVER['PHP_AUTH_USER'] ?? '';
\$cfg['Servers'][\$i]['password'] = \$_SERVER['PHP_AUTH_PW'] ?? '';
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['Servers'][\$i]['hide_db'] = '^(information_schema|performance_schema|mysql|sys)$';
\$cfg['ShowCreateDb'] = false;
\$cfg['LoginCookieValidity'] = 3600;
\$cfg['LoginCookieStore'] = 0;
\$cfg['LoginCookieDeleteAll'] = true;
EOF
    rm -f /opt/litecp/phpmyadmin/signon.php /opt/litecp/phpmyadmin/.user.ini
    mkdir -p /opt/litecp/run/phpmyadmin-tmp
    chown -R caddy:caddy /opt/litecp/run/phpmyadmin-tmp /opt/litecp/phpmyadmin
}

create_admin_user() {
    log "Creating LiteCP admin user..."
    LITECP_PASSWORD="$(openssl rand -hex 9)"
    if ! id -u litecp >/dev/null 2>&1; then
        useradd -m -s /bin/bash litecp
    fi
    echo "litecp:${LITECP_PASSWORD}" | chpasswd
    local home_dir
    home_dir="$(eval echo ~litecp)"
    mkdir -p "${home_dir}/apps" "${home_dir}/.litecp/run" "${home_dir}/.tmp"/{sessions,uploads,cache,phpmyadmin,wsdl}
    mkdir -p /opt/litecp/config/users/litecp
    chown -R litecp:litecp "${home_dir}/apps" "${home_dir}/.litecp" "${home_dir}/.tmp"
    touch /var/log/litecp/php-litecp-error.log
    chown litecp:litecp /var/log/litecp/php-litecp-error.log
    echo "litecp" > /opt/litecp/data/default_admin
    chmod 0600 /opt/litecp/data/default_admin
}

write_systemd_units() {
    log "Writing systemd units..."
    cat > /etc/systemd/system/litecp-agent.service << 'EOF'
[Unit]
Description=LiteCP privileged agent
After=network-online.target mariadb.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/litecp/bin/litecp-agent --socket /opt/litecp/run/agent.sock
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/litecp.service << 'EOF'
[Unit]
Description=LiteCP control panel
After=network-online.target litecp-agent.service
Requires=litecp-agent.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/litecp/bin/litecp --listen :3050 --data-dir /opt/litecp/data --agent-socket /opt/litecp/run/agent.sock --tls-cert /opt/litecp/ssl/server.crt --tls-key /opt/litecp/ssl/server.key
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/litecp-caddy.service << 'EOF'
[Unit]
Description=LiteCP Caddy reverse proxy
After=network-online.target litecp-agent.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/caddy run --config /opt/litecp/config/Caddyfile --adapter caddyfile
ExecReload=/usr/local/bin/caddy reload --config /opt/litecp/config/Caddyfile --adapter caddyfile
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

configure_firewalld() {
    log "Configuring firewalld..."
    if has_systemd; then
        systemctl enable --now firewalld
    fi
    firewall-cmd --permanent --add-service=http >/dev/null
    firewall-cmd --permanent --add-service=https >/dev/null
    firewall-cmd --permanent --add-port=3050/tcp >/dev/null
    firewall-cmd --reload >/dev/null
}

start_services() {
    if ! has_systemd; then
        warn "systemd not detected; services were installed but not started."
        return
    fi
    log "Starting LiteCP services..."
    systemctl daemon-reload
    systemctl enable litecp-agent litecp litecp-caddy
    systemctl restart php84-php-fpm
    systemctl restart litecp-agent
    sleep 2
    systemctl restart litecp
    systemctl restart litecp-caddy
}

wait_for_panel() {
    log "Waiting for LiteCP panel..."
    local i
    for i in {1..30}; do
        if curl -sk https://127.0.0.1:3050/ >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    warn "LiteCP did not respond within 30 seconds. Check: journalctl -u litecp -u litecp-agent -f"
}

print_summary() {
    local display_host ips ipv4 ipv6
    ips="$(hostname -I 2>/dev/null || true)"
    ipv4="$(echo "$ips" | tr ' ' '\n' | awk '/^([0-9]{1,3}\.){3}[0-9]{1,3}$/ {print; exit}')"
    ipv6="$(echo "$ips" | tr ' ' '\n' | awk 'index($0, ":") > 0 {gsub(/%.*/, "", $0); print; exit}')"
    if [[ -n "$ipv4" ]]; then
        display_host="$ipv4"
    elif [[ -n "$ipv6" ]]; then
        display_host="[$ipv6]"
    else
        display_host="127.0.0.1"
    fi
    echo ""
    echo -e "${GREEN}${BOLD}LiteCP installation complete.${NC}"
    echo "Panel URL: https://${display_host}:3050"
    echo "Username: litecp"
    echo "Password: ${LITECP_PASSWORD}"
    echo "phpMyAdmin: https://${display_host}:3050/phpmyadmin/"
    [[ -n "${INSTALL_LOG}" ]] && echo "Install log: ${INSTALL_LOG}"
    echo ""
    echo "Useful commands:"
    echo "  systemctl status litecp litecp-agent litecp-caddy"
    echo "  journalctl -u litecp -u litecp-agent -f"
    echo "  passwd litecp"
    echo ""
    if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce 2>/dev/null || true)" != "Disabled" ]]; then
        warn "SELinux config was set to disabled. Reboot the server to complete SELinux disablement."
    fi
}

main() {
    require_root
    setup_logging
    cd_repo_root
    print_banner
    detect_os
    detect_arch
    disable_selinux
    install_repositories
    install_base_dependencies
    ensure_source_tree
    ensure_swap
    create_layout
    ensure_caddy_user
    install_php
    install_caddy
    install_binaries
    write_pam_config
    write_base_config
    generate_panel_cert
    configure_mariadb
    install_phpmyadmin
    create_admin_user
    write_systemd_units
    configure_firewalld
    start_services
    wait_for_panel
    print_summary
}

main "$@"
