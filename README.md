# WARP Proxy Docker Container

A Dockerized Cloudflare WARP client that exposes a SOCKS5 proxy on port 40000.

## Prerequisites

- macOS with [Colima](https://github.com/abiosoft/colima) installed
- Docker or Docker Compose

## Quick Start

### 1. Start Colima

```bash
# Stop any running instance
colima stop

# Start Colima (let host WARP handle DNS if you have company WARP)
colima start --network-address
```

### 2. Build and Run

```bash
# Using Docker Compose (recommended)
docker-compose up -d

# OR using Docker directly
docker build -t warp-proxy .
docker run -d \
  --name warp-proxy \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  -p 40000:40000 \
  warp-proxy
```

### 3. Test the Proxy

```bash
# Test connection
curl -x socks5://localhost:40000 https://www.cloudflare.com/cdn-cgi/trace

# You should see: warp=on or warp=plus
```

## Usage

### View Logs

```bash
# Docker Compose
docker-compose logs -f

# Docker
docker logs -f warp-proxy
```

### Stop/Start Container

```bash
# Docker Compose
docker-compose down
docker-compose up -d

# Docker
docker stop warp-proxy
docker start warp-proxy
```

### Rebuild After Changes

```bash
# Docker Compose
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Docker
docker stop warp-proxy
docker rm warp-proxy
docker build -t warp-proxy .
docker run -d --name warp-proxy [... flags ...] warp-proxy
```

## ⚠️ Company WARP Conflict

If you have company WARP installed on your macOS host, you **cannot** run both simultaneously due to DNS conflicts.

### Choose One:

**Option A: Use Container WARP (Personal/Testing)**
1. Turn OFF company WARP on macOS
2. Start container: `docker-compose up -d`
3. Use proxy: `socks5://localhost:40000`

**Option B: Use Company WARP (Work)**
1. Stop container: `docker-compose down`
2. Turn ON company WARP on macOS

### Solution: Deploy on Separate Machine

For simultaneous use, deploy this container on:
- A Linux VPS (DigitalOcean, AWS, etc.)
- A Raspberry Pi
- Another Mac without company WARP

## Configuration

### WARP+ License (Optional)

Add your WARP+ license key in `docker-compose.yml`:

```yaml
environment:
  - WARP_LICENSE_KEY=your-license-key-here
```

### Custom Proxy Port

Change the port in `docker-compose.yml`:

```yaml
environment:
  - PROXY_PORT=40000  # Change this
ports:
  - "40000:40000"     # Change this too
```

## Troubleshooting

### Port Already in Use

```bash
# Find what's using port 40000
lsof -i :40000

# Kill the process or change the port
```

### Container Won't Connect to WARP

```bash
# Check logs
docker-compose logs -f

# Restart container
docker-compose restart

# Rebuild from scratch
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# With authentication
docker-compose down
docker-compose build --no-cache
GOST_USERNAME=myusername GOST_PASSWORD=mySecurePassword123 docker-compose up -d
```

### Cannot Connect from macOS Host

```bash
# Get Colima VM IP
colima list

# Test with VM IP instead
curl -x socks5://192.168.5.2:40000 https://www.cloudflare.com/cdn-cgi/trace
```

## Files

- `Dockerfile` - Container image definition
- `docker-compose.yml` - Docker Compose configuration
- `entrypoint.sh` - Startup script that configures WARP
- `README.md` - This file

## License

MIT



