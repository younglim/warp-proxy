#!/bin/bash
# Removed set -e to prevent instant crashes on minor warnings

echo "Starting D-Bus system daemon..."
mkdir -p /run/dbus
dbus-daemon --system --fork || true

echo "Starting Cloudflare WARP service..."
if [ -f /usr/bin/warp-svc ]; then
    WARP_SVC=/usr/bin/warp-svc
elif [ -f /usr/sbin/warp-svc ]; then
    WARP_SVC=/usr/sbin/warp-svc
else
    echo "FATAL: warp-svc binary not found!"
    exit 1
fi

# Start daemon
$WARP_SVC &
sleep 5

echo "Registering WARP client..."
warp-cli --accept-tos registration new || echo "Registration failed, but continuing script..."

# 2. Configure proxy and protocol
warp-cli --accept-tos tunnel protocol set MASQUE || true
warp-cli --accept-tos mode proxy || true
warp-cli --accept-tos proxy port 1080 || true

echo "Connecting to WARP..."
warp-cli --accept-tos connect

# 3. THE BOMB DEFUSAL: Give yourself 120 seconds to debug instead of 30
TIMEOUT=120
while [ "$(warp-cli --accept-tos status | grep -c 'Connected')" -eq 0 ] && [ "$TIMEOUT" -gt 0 ]; do
    echo "Waiting for WARP connection... ($TIMEOUT seconds left)"
    sleep 1
    TIMEOUT=$((TIMEOUT-1))
done

if [ "$(warp-cli --accept-tos status | grep -c 'Connected')" -eq 0 ]; then
    echo "ERROR: Cloudflare WARP failed to connect."
    warp-cli --accept-tos status
    
    # Temporarily changed 'exit 1' to 'sleep 300' so the container stays alive 
    # for 5 minutes, giving you time to jump in and read the logs.
    echo "Container will stay alive for 5 minutes for debugging..."
    sleep 300 
    exit 1
fi

echo "WARP is successfully connected!"

# Expose the local SOCKS5 proxy (127.0.0.1:1080) to all interfaces (0.0.0.0:40000)
PORT=${PROXY_PORT:-40000}
echo "Starting SOCKS5 proxy forwarder on port $PORT..."
exec socat TCP-LISTEN:${PORT},fork,reuseaddr TCP:127.0.0.1:1080