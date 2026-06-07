FROM debian:bookworm-slim

LABEL author="Mark7625" maintainer="custom-pterodactyl-eggs/ktor" description="Pterodactyl Ktor/JAR Egg"

ARG JAVA_VERSION=22

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        git \
        ca-certificates \
        wget \
        curl \
        python3 \
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then CF_ARCH=amd64; JDK_ARCH=x64; \
    elif [ "$ARCH" = "aarch64" ]; then CF_ARCH=arm64; JDK_ARCH=aarch64; \
    else echo "Unsupported architecture: $ARCH" && exit 1; fi \
    && wget -O /tmp/cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}.deb" \
    && dpkg -i /tmp/cloudflared.deb \
    && rm /tmp/cloudflared.deb \
    && if [ "${JAVA_VERSION}" = "11" ]; then \
        JDK_RELEASE="jdk-11.0.31%2B11"; \
        JDK_PKG_VER="11.0.31_11"; \
        JDK_REPO="temurin11-binaries"; \
    else \
        JDK_RELEASE="jdk-22.0.2%2B9"; \
        JDK_PKG_VER="22.0.2_9"; \
        JDK_REPO="temurin22-binaries"; \
    fi \
    && wget -qO /tmp/jdk.tar.gz "https://github.com/adoptium/${JDK_REPO}/releases/download/${JDK_RELEASE}/OpenJDK${JAVA_VERSION}U-jre_${JDK_ARCH}_linux_hotspot_${JDK_PKG_VER}.tar.gz" \
    && mkdir -p /opt/java \
    && tar -xzf /tmp/jdk.tar.gz -C /opt/java --strip-components=1 \
    && rm /tmp/jdk.tar.gz \
    && ln -sf /opt/java/bin/java /usr/local/bin/java \
    && java -version \
    && echo "Java ${JAVA_VERSION}" > /etc/pterodactyl-ktor-java-version \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home/container/ -s /bin/bash container \
    && echo "USER=container" >> /etc/environment \
    && echo "HOME=/home/container" >> /etc/environment

WORKDIR /home/container

STOPSIGNAL SIGINT

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
