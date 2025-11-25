# Use a stable Ubuntu LTS base image
FROM ubuntu:jammy

# Set environment variables for the WARP client installation
ENV DEBIAN_FRONTEND=noninteractive
ENV GOST_VERSION=3.2.6

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
        systemd-sysv && \
    \
    # Detect architecture
    ARCH=$(dpkg --print-architecture) && \
    \
    # Add Cloudflare GPG key
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    \
    # Add Cloudflare WARP repository (using detected architecture)
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ focal main" | tee /etc/apt/sources.list.d/cloudflare-warp.list && \
    \
    # Install WARP client
    apt update && \
    apt install -y --no-install-recommends cloudflare-warp && \
    \
    # --- 2. Install Gost (Proxy Relay Tool) ---
    # Download and install gost v3.x (tarball per architecture)
    case "${ARCH}" in \
        amd64) GOST_ARCH=amd64 ;; \
        arm64|aarch64) GOST_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    GOST_TAR="gost_${GOST_VERSION}_linux_${GOST_ARCH}.tar.gz" && \
    wget -O "/tmp/${GOST_TAR}" "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/${GOST_TAR}" && \
    tar -xzf "/tmp/${GOST_TAR}" -C /tmp gost && \
    mv /tmp/gost /usr/local/bin/ && \
    chmod +x /usr/local/bin/gost && \
    \
    # Clean up
    apt autoremove -y && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# The WARP SOCKS5 proxy runs on localhost:1080 by default.
# We expose port 40000 externally and use gost to forward to WARP's 127.0.0.1:1080
ENV PROXY_PORT=40000
ENV HTTP_PROXY_PORT=40001

# Expose the SOCKS5 and HTTP proxy ports (external ports)
EXPOSE ${PROXY_PORT} ${HTTP_PROXY_PORT}

# Set the entrypoint to run multiple services (WARP daemon + proxy relay)
# The entrypoint script will handle WARP registration and connection.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]