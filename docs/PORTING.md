# LiteCP Porting Notes: FastCP Ubuntu to AlmaLinux/Rocky Linux

This project keeps the useful FastCP architecture: a Go web panel, a privileged Go agent over a Unix socket, Caddy as the public reverse proxy, PHP-FPM pools per site/user, PAM authentication and SQLite metadata.

The Ubuntu-specific system layer was replaced for AlmaLinux/Rocky Linux 8/9:

- `apt`, `apt-cache`, Ondrej PPA and `libpam0g-dev` were replaced with `dnf`, EPEL/Remi and `pam-devel`.
- UFW management was replaced with firewalld and `firewall-cmd`.
- PHP-FPM paths now use Remi SCL layout:
  - pool configs: `/etc/opt/remi/php84/php-fpm.d/`
  - runtime dir: `/var/opt/remi/php84/run/php-fpm/`
  - service: `php84-php-fpm`
  - PHP binary: `/opt/remi/php84/root/usr/bin/php`
- Default PHP runtime is PHP 8.4.
- MariaDB tuning is written to `/etc/my.cnf.d/litecp.cnf`.
- PAM authentication uses the dedicated service `/etc/pam.d/litecp` instead of Ubuntu's generic `login` service.
- The installer disables SELinux in `/etc/selinux/config` and calls `setenforce 0` for the current boot when possible.
- Runtime names and paths changed from FastCP to LiteCP:
  - binaries: `litecp`, `litecp-agent`
  - base directory: `/opt/litecp`
  - panel port: `3050`
  - database: `/opt/litecp/data/litecp.db`

Primary changed files:

- `internal/agent/handlers.go`: RHEL system operations, Remi PHP-FPM, firewalld, MariaDB paths.
- `internal/api/auth.go`: PAM service name changed to `litecp`.
- `scripts/install.sh`: complete Alma/Rocky installer.
- `scripts/uninstall.sh`: RHEL-oriented cleanup.
- `Makefile` and `.github/workflows/release.yml`: CGO/PAM builds in Rocky Linux containers.