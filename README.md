# Cloudflare WARP SOCKS5 Proxy (Fargate Compatible)

A lightweight Docker container that connects to Cloudflare WARP and exposes it locally as a **SOCKS5 proxy**. 

Unlike the official Cloudflare WARP Linux client which requires root-level kernel privileges (`NET_ADMIN` and `/dev/net/tun`), this implementation uses [`wireproxy`](https://github.com/octeep/wireproxy) and [`wgcf`](https://github.com/ViRb3/wgcf) to run entirely in user-space.

This makes it **100% compatible with AWS ECS Fargate** and strictly sandboxed environments.

## Features
- **Zero Privileges Required**: Drops all Linux capabilities (`cap_drop: ALL`). No `NET_ADMIN` needed.
- **Auto-Registration**: Automatically provisions a free Cloudflare WARP account on startup.
- **Alpine Base**: Extremely slim image size.
- **SOCKS5 Proxy**: Binds to `0.0.0.0:40000` by default.

## Quick Start (Local)

1. Start the proxy using Docker Compose:
   ```bash
   docker-compose up --build -d
   ```

2. Test the connection through the proxy:
   ```bash
   curl --socks5 127.0.0.1:40000 https://cloudflare.com/cdn-cgi/trace
   ```
   *Look for `warp=on` in the output to confirm traffic is being routed through Cloudflare.*

3. In your web browser or application, configure your **SOCKS5 proxy** to point to `127.0.0.1:40000`.

## Connecting from other devices
To allow other machines to connect to your proxy, configure their SOCKS5 settings to point to your Docker host's IP address (e.g., `192.168.1.100:40000`).

## Environment Variables
| Variable | Default  | Description |
|----------|----------|-------------|
| `PROXY_PORT` | `40000` | The port where the SOCKS5 proxy will be exposed. |

## AWS ECS Fargate Deployment Guide

Because this container runs entirely in user-space, it is natively compatible with AWS Fargate. 

**Task Definition Requirements:**
1. **No Capabilities**: You do not need to specify `linuxParameters` or capabilities in your task definition.
2. **Security Groups**:
   - **Egress (Outbound)**: You must allow **UDP Port 2408** to `0.0.0.0/0` (Wireguard/WARP traffic) and standard HTTPS (TCP 443) for initial account registration.
   - **Ingress (Inbound)**: Allow **TCP Port 40000** from your internal VPC or trusted clients to access the proxy.
3. **Networking**: Ensure your Fargate task is in a private subnet with a NAT gateway attached, or in a public subnet with a public IP assigned so it can reach Cloudflare's edge network.



