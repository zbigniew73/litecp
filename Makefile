# LiteCP Makefile

VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS := -ldflags "-s -w -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"
RHEL_BUILD_IMAGE ?= rockylinux:9

.PHONY: all build build-linux build-linux-arm64 release clean install

all: build

build:
	CGO_ENABLED=1 go build $(LDFLAGS) -o bin/litecp ./cmd/litecp
	CGO_ENABLED=1 go build $(LDFLAGS) -o bin/litecp-agent ./cmd/litecp-agent

build-linux:
	mkdir -p dist
	docker run --rm -v $(PWD):/app -w /app $(RHEL_BUILD_IMAGE) bash -lc '\
		dnf -y install golang gcc make pam-devel sqlite-devel git >/dev/null && \
		CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o dist/litecp-linux-amd64 ./cmd/litecp && \
		CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o dist/litecp-agent-linux-amd64 ./cmd/litecp-agent'

build-linux-arm64:
	mkdir -p dist
	docker run --rm --platform linux/arm64 -v $(PWD):/app -w /app $(RHEL_BUILD_IMAGE) bash -lc '\
		dnf -y install golang gcc make pam-devel sqlite-devel git >/dev/null && \
		CGO_ENABLED=1 GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o dist/litecp-linux-arm64 ./cmd/litecp && \
		CGO_ENABLED=1 GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o dist/litecp-agent-linux-arm64 ./cmd/litecp-agent'

release: build-linux
	mkdir -p dist/litecp-$(VERSION)
	cp dist/litecp-linux-amd64 dist/litecp-$(VERSION)/litecp
	cp dist/litecp-agent-linux-amd64 dist/litecp-$(VERSION)/litecp-agent
	cp scripts/install.sh scripts/uninstall.sh dist/litecp-$(VERSION)/
	tar -czf dist/litecp-$(VERSION)-linux-amd64.tar.gz -C dist litecp-$(VERSION)

clean:
	rm -rf bin dist

install: build
	sudo install -m 0755 bin/litecp /usr/local/bin/litecp
	sudo install -m 0755 bin/litecp-agent /usr/local/bin/litecp-agent