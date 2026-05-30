# LiteCP container image for development smoke tests.
# Production installs are handled by scripts/install.sh on AlmaLinux/Rocky Linux 8/9.

FROM rockylinux:9 AS builder
WORKDIR /src
RUN dnf -y install golang gcc make pam-devel sqlite-devel git && dnf clean all
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 go build -o /out/litecp ./cmd/litecp && \
    CGO_ENABLED=1 go build -o /out/litecp-agent ./cmd/litecp-agent

FROM rockylinux:9
RUN dnf -y install ca-certificates curl wget && \
    dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm && \
    dnf -y install acl firewalld mariadb mariadb-server openssl pam procps-ng restic rsync shadow-utils tar which \
        php84-php-fpm php84-php-cli php84-php-common php84-php-mysqlnd php84-php-pdo && \
    dnf clean all
RUN mkdir -p /opt/litecp/bin /opt/litecp/data /opt/litecp/config /opt/litecp/run /var/log/litecp
COPY --from=builder /out/litecp /opt/litecp/bin/litecp
COPY --from=builder /out/litecp-agent /opt/litecp/bin/litecp-agent
COPY scripts/install.sh /opt/litecp/install.sh
EXPOSE 80 443 3050
CMD ["/opt/litecp/bin/litecp", "--listen", ":3050", "--data-dir", "/opt/litecp/data", "--agent-socket", "/opt/litecp/run/agent.sock", "--no-tls"]