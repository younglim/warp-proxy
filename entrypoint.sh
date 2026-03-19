#!/bin/bash
set -e

PORT=${PROXY_PORT:-40000}
WORKDIR="/app"
mkdir -p $WORKDIR
cd $WORKDIR

echo "Registering WARP account using wgcf..."
wgcf register --accept-tos
wgcf generate

echo "Extracting WireGuard configuration..."
PRIVATE_KEY=$(grep 'PrivateKey' wgcf-profile.conf | awk '{print $3}')
PEER_PUBLIC_KEY=$(grep 'PublicKey' wgcf-profile.conf | awk '{print $3}')
ENDPOINT=$(grep 'Endpoint' wgcf-profile.conf | awk '{print $3}')

# Write wireproxy configuration
cat <<EOF > wireproxy.conf
[Interface]
Address = 172.16.0.2/32
MTU = 1280
PrivateKey = $PRIVATE_KEY

[Peer]
PublicKey = $PEER_PUBLIC_KEY
Endpoint = $ENDPOINT

[Socks5]
BindAddress = 0.0.0.0:$PORT
EOF

echo "Starting wireproxy successfully in user-space on port $PORT..."
exec wireproxy -c wireproxy.conf