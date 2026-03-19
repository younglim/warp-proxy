FROM node:24-bullseye-slim

# Install dependencies (Node slim images use apt-get)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl wget bash jq ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install wgcf (WARP config generator)
RUN curl -fsSL "https://github.com/ViRb3/wgcf/releases/download/v2.2.30/wgcf_2.2.30_linux_amd64" -o /usr/local/bin/wgcf && \
    chmod +x /usr/local/bin/wgcf

# Install wireproxy (User-space Wireguard SOCKS5 proxy)
RUN curl -fsSL "https://github.com/octeep/wireproxy/releases/download/v1.1.2/wireproxy_linux_amd64.tar.gz" -o /tmp/wireproxy.tar.gz && \
    tar -xzf /tmp/wireproxy.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/wireproxy && \
    rm /tmp/wireproxy.tar.gz

ENV PROXY_PORT=40000

EXPOSE ${PROXY_PORT}

WORKDIR /app
COPY index.js /app/index.js

ENTRYPOINT ["node", "/app/index.js"]