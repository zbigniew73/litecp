# LiteCP

LiteCP is a Caddy-based Linux control panel adapted from FastCP for AlmaLinux 8/9 and Rocky Linux 8/9.

## Target Platform

- AlmaLinux 8.x / 9.x
- Rocky Linux 8.x / 9.x
- SELinux is configured as disabled by the installer
- firewalld is used for host firewall management
- PHP is installed from Remi packages, with PHP 8.4 as the default runtime

## Architecture

- `litecp`: web UI and REST API, HTTPS on port `3050`
- `litecp-agent`: privileged root agent, Unix socket IPC
- Caddy v2: public reverse proxy on ports `80` and `443`
- Remi PHP-FPM pools per site and per Linux user
- PAM authentication via `/etc/pam.d/litecp`
- SQLite database at `/opt/litecp/data/litecp.db`

## Paths

```text
/opt/litecp/
├── bin/
│   ├── litecp
│   └── litecp-agent
├── config/
│   ├── Caddyfile
│   ├── caddy-settings.json
│   └── php-defaults.json
├── data/
│   └── litecp.db
├── run/
└── ssl/
```

Sites are stored under:

```text
/home/{user}/apps/{site}/public
/home/{user}/apps/{site}/logs
/home/{user}/apps/{site}/tmp
```

## Install From Source On Alma/Rocky

```bash
sudo dnf install -y git
cd /usr/local/src
git clone https://github.com/zbigniew73/litecp.git
cd litecp
sudo bash scripts/install.sh
```

The installer configures EPEL, Remi, PHP 8.4, MariaDB, firewalld, PAM, Caddy and systemd units.

## Build

On an Alma/Rocky build host:

```bash
sudo dnf install -y golang gcc make pam-devel sqlite-devel git
CGO_ENABLED=1 go build -o bin/litecp ./cmd/litecp
CGO_ENABLED=1 go build -o bin/litecp-agent ./cmd/litecp-agent
```

Or build Linux release binaries in a Rocky container:

```bash
make build-linux
```

## Services

```bash
systemctl status litecp
systemctl status litecp-agent
systemctl status litecp-caddy
systemctl status php84-php-fpm
systemctl status mariadb
systemctl status firewalld
```

Logs:

```bash
journalctl -u litecp -f
journalctl -u litecp-agent -f
journalctl -u litecp-caddy -f
```

## Uninstall

```bash
sudo bash scripts/uninstall.sh
```