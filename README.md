# LiteCP

> LiteCP is a Caddy-based control panel adapted for AlmaLinux 8/9 and Rocky Linux 8/9.

![Version](https://img.shields.io/badge/version-1.0-blue)
![Platform](https://img.shields.io/badge/platform-AlmaLinux%209%20%7C%20Rocky%209%20%7C%20RHEL%209-red)
![License](https://img.shields.io/badge/license-MIT-green)

<p align="left">
  <img src="assets/logo-litecp.png" alt="LiteCP" width="200">
</p>

## Requirements

| Resource | Minimum |
|----------|---------|
| OS       | AlmaLinux 8/9 / Rocky Linux 8/9 / RHEL 8/9 |
| RAM      | 512 MB  |
| Disk     | 5 GB free on `/` |
| Access   | root or sudo |

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

## Quick Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zbigniew73/litecp/main/scripts/install.sh)
```
Or download first and inspect before running:

```bash
curl -fsSL https://raw.githubusercontent.com/zbigniew73/litecp/main/scripts/install.sh -o install.sh
bash install.sh
```

## AlmaLinux 8 / Rocky Linux 8 – Required Restic Installation

On Enterprise Linux 8-based systems (AlmaLinux 8, Rocky Linux 8), the restic package is not available in the EPEL 8 repository. Before running the LiteCP installer, Restic must be installed manually from official binaries.

### Restic Installation

```bash
RESTIC_VERSION=0.18.1
curl -LO https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2
bunzip2 restic_${RESTIC_VERSION}_linux_amd64.bz2
chmod +x restic_${RESTIC_VERSION}_linux_amd64
mv restic_${RESTIC_VERSION}_linux_amd64 /usr/local/bin/restic
```

### Verify Installation

restic version

Example output: restic 0.18.1 compiled with go1.x on linux/amd64

### Download LiteCP Installer

Download the latest installation script:
```bash
curl -fsSL https://raw.githubusercontent.com/zbigniew73/litecp/main/scripts/install.sh -o install.sh
```

### Modify the Installer Script

On AlmaLinux 8 / Rocky Linux 8 systems, you must remove the restic package from the installation list inside the installer script.

Open install.sh in a text editor.

Locate line approximately 206, which contains restic.

Remove restic from the package list.

Save the file.

Run the Installer

After completing the above steps, you can proceed with LiteCP installation:
```bash
bash install.sh
```

> Note: This step is required only for AlmaLinux 8 and Rocky Linux 8. On AlmaLinux 9 and Rocky Linux 9, restic is available in the default repositories and does not require manual installation.

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
