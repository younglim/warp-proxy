#!/bin/bash
set -e

# Start dbus to prevent dbus connection warnings
echo "Starting D-Bus system daemon..."
mkdir -p /run/dbus
dbus-daemon --system --fork 2>/dev/null || true

# Find and start the WARP service daemon in the background
echo "Starting Cloudflare WARP service..."
# The warp-svc binary might be in different locations depending on the package
if [ -f /usr/bin/warp-svc ]; then
    WARP_SVC=/usr/bin/warp-svc
elif [ -f /usr/sbin/warp-svc ]; then
    WARP_SVC=/usr/sbin/warp-svc
else
    echo "ERROR: warp-svc binary not found!"
    find /usr -name "warp-svc" 2>/dev/null || echo "warp-svc not found anywhere"
    exit 1
fi

# Start warp-svc in the background (suppress warnings)
$WARP_SVC 2>/dev/null &
WARP_PID=$!

# Wait for the service to be available
echo "Waiting for WARP daemon to start..."
sleep 5

# Check if warp-svc is still running
if ! kill -0 $WARP_PID 2>/dev/null; then
    echo "ERROR: warp-svc failed to start"
    exit 1
fi

# Set WARP mode to proxy and set the proxy port to 1080 (the default listen port for warp-cli proxy mode)
warp-cli --accept-tos mode proxy 2>/dev/null

# Disable DNS handling to avoid conflicts with host WARP
warp-cli --accept-tos dns families off 2>/dev/null

warp-cli --accept-tos proxy port 1080 2>/dev/null

# If you have a WARP+ license key, set it as an environment variable (WARP_LICENSE_KEY)
if [ -n "$WARP_LICENSE_KEY" ]; then
    echo "Registering WARP+ license..."
    warp-cli --accept-tos registration license "$WARP_LICENSE_KEY"
fi

# Register the client for a new WARP account (if not already registered)
echo "Registering WARP client..."
warp-cli --accept-tos registration new || echo "Already registered or registration failed, continuing..."

# Connect to the WARP network
echo "Connecting to WARP..."
warp-cli --accept-tos connect

# Wait for WARP to connect
TIMEOUT=30
while [ "$(warp-cli --accept-tos status | grep -c 'Connected')" -eq 0 ] && [ "$TIMEOUT" -gt 0 ]; do
    echo "Waiting for WARP connection... ($TIMEOUT seconds left)"
    sleep 1
    TIMEOUT=$((TIMEOUT-1))
done

if [ "$(warp-cli --accept-tos status | grep -c 'Connected')" -eq 0 ]; then
    echo "ERROR: Cloudflare WARP failed to connect."
    warp-cli --accept-tos status
    exit 1
fi

echo "Cloudflare WARP is connected. SOCKS5 is running on 127.0.0.1:1080."
warp-cli --accept-tos status 2>/dev/null

# Check WARP IPv6 connectivity
echo "Checking WARP IPv6 connectivity..."
WARP_IPV6=$(warp-cli --accept-tos status | grep -Eo 'IPv6: [0-9a-fA-F:]+')
echo "WARP IPv6 status: $WARP_IPV6"

# Test outbound IPv6 connectivity through WARP
echo "Testing outbound IPv6 connectivity via WARP..."
curl -6 -s https://[2606:4700:4700::1111]/cdn-cgi/trace || echo "IPv6 outbound test failed"

# Start the gost relay to expose the SOCKS5 proxy to 0.0.0.0
echo "Starting SOCKS5 relay on 0.0.0.0:40000 forwarding to 127.0.0.1:1080..."
# Use PROXY_PORT env var if provided (default 40000)
PORT=${PROXY_PORT:-40000}
HTTP_PORT=${HTTP_PROXY_PORT:-40001}

# If username and password are provided, include them in the listener URL so
# gost enforces authentication. Note: credentials should be URL-safe (avoid
# '@' or ':' characters) or pre-encoded. If not set, the listener is open.
if [ -n "${GOST_USERNAME}" ] && [ -n "${GOST_PASSWORD}" ]; then
    AUTH="${GOST_USERNAME}:${GOST_PASSWORD}@"
else
    AUTH=""
fi

# Detect if WARP SOCKS5 is listening on ::1:1080
if ss -ltn | grep -q 'LISTEN.*[::]:1080'; then
    FORWARD_ADDR="socks5://[::1]:1080"
else
    FORWARD_ADDR="socks5://127.0.0.1:1080"
fi

# Start SOCKS5 proxy (IPv4)
LISTEN_ADDR="socks5://${AUTH}0.0.0.0:${PORT}"
echo "Starting SOCKS5 gost with listener ${LISTEN_ADDR} forwarding to ${FORWARD_ADDR}"
gost -L "${LISTEN_ADDR}" -F "${FORWARD_ADDR}" --prefer-ipv6 2>&1 | grep -vE "WARN|power_notifier" &

# Start HTTP proxy (IPv4) - chain through SOCKS5
HTTP_LISTEN_ADDR="http://${AUTH}0.0.0.0:${HTTP_PORT}"
echo "Starting HTTP proxy on ${HTTP_LISTEN_ADDR} chaining through ${FORWARD_ADDR}"
gost -L "${HTTP_LISTEN_ADDR}" -F "${FORWARD_ADDR}" --prefer-ipv6 2>&1 | grep -vE "WARN|power_notifier" &

# Detect if IPv6 is available in the container
if ip -6 addr show | grep -q 'inet6'; then
    echo "IPv6 detected, starting gost on [::]:${PORT} and [::]:${HTTP_PORT} as well."
    
    # Start SOCKS5 for IPv6
    IPV6_LISTEN_ADDR="socks5://${AUTH}[::]:${PORT}"
    gost -L "${IPV6_LISTEN_ADDR}" -F "${FORWARD_ADDR}" 2>&1 | grep -vE "WARN|power_notifier" &
    
    # Start HTTP for IPv6 - chain through SOCKS5
    HTTP_IPV6_LISTEN_ADDR="http://${AUTH}[::]:${HTTP_PORT}"
    gost -L "${HTTP_IPV6_LISTEN_ADDR}" -F "${FORWARD_ADDR}" 2>&1 | grep -vE "WARN|power_notifier" &
fi

echo "Proxy servers started:"
echo "  - SOCKS5: 0.0.0.0:${PORT}"
echo "  - HTTP: 0.0.0.0:${HTTP_PORT}"

# Keep container running and show logs
wait
