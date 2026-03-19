# Use a stable Ubuntu LTS base image
FROM ubuntu:jammy

# Set environment variables for the WARP client installation
ENV DEBIAN_FRONTEND=noninteractive

# --- 1. Install Dependencies and WARP Client ---
RUN apt update && \
    apt install -y --no-install-recommends \
        curl \
        wget \
        gnupg \
        iproute2 \
        net-tools \
        dumb-init \
        ca-certificates \
        dbus \
        systemd \
        systemd-sysv \
        socat && \
    \
    # Detect architecture
    ARCH=$(dpkg --print-architecture) && \
    \
    # Add Cloudflare GPG key
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    \
    # Add Cloudflare WARP repository (using detected architecture)
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | tee /etc/apt/sources.list.d/cloudflare-warp.list && \
    \
    # Install WARP client
    apt update && \
    apt install -y --no-install-recommends cloudflare-warp && \
    \
    # Clean up
    apt autoremove -y && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

ENV PROXY_PORT=40000

EXPOSE ${PROXY_PORT}

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]