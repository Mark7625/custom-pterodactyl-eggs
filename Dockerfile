FROM debian:bookworm-slim

LABEL author="Mark7625" maintainer="custom-pterodactyl-eggs" description="Pterodactyl Next.js Egg"

ARG NODE_VERSION=22

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        git \
        apt-transport-https \
        lsb-release \
        ca-certificates \
        wget \
        curl \
        gnupg2 \
        debian-archive-keyring \
        unzip \
        certbot \
    && curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/debian bookworm nginx" > /etc/apt/sources.list.d/nginx.list \
    && printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx \
    && apt-get update \
    && apt-get install -y nginx \
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then \
        wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi \
    && dpkg -i /tmp/cloudflared.deb \
    && rm /tmp/cloudflared.deb \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && command -v node >/dev/null 2>&1 || { echo "ERROR: Node.js installation failed."; exit 1; } \
    && echo "Node.js installed successfully: $(node -v)" \
    && rm -rf /var/lib/apt/lists/*

# Create user and set environment variables
RUN useradd -m -d /home/container/ -s /bin/bash container \
    && echo "USER=container" >> /etc/environment \
    && echo "HOME=/home/container" >> /etc/environment

WORKDIR /home/container

STOPSIGNAL SIGINT

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
