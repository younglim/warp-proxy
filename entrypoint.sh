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

# Start the gost relay to expose the SOCKS5 proxy to 0.0.0.0
echo "Starting SOCKS5 relay on 0.0.0.0:40000 forwarding to 127.0.0.1:1080..."
# Remove -D flag to reduce verbosity, redirect warnings to /dev/null
exec gost -L "socks5://:40000" -F "socks5://127.0.0.1:1080" 2>&1 | grep -vE "WARN|power_notifier" || true