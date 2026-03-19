const fs = require('fs');
const { execSync, spawn } = require('child_process');

const PORT = process.env.PROXY_PORT || 40000;
const WORKDIR = '/app';

// Ensure working directory exists and move into it
if (!fs.existsSync(WORKDIR)) {
    fs.mkdirSync(WORKDIR, { recursive: true });
}
process.chdir(WORKDIR);

console.log('Registering WARP account using wgcf...');
execSync('wgcf register --accept-tos', { stdio: 'inherit' });
execSync('wgcf generate', { stdio: 'inherit' });

console.log('Extracting WireGuard configuration...');
const profileStr = fs.readFileSync('wgcf-profile.conf', 'utf8');

// Parse the required fields
const privateKeyMatch = profileStr.match(/PrivateKey\s*=\s*(.+)/);
const publicKeyMatch = profileStr.match(/PublicKey\s*=\s*(.+)/);
const endpointMatch = profileStr.match(/Endpoint\s*=\s*(.+)/);

if (!privateKeyMatch || !publicKeyMatch || !endpointMatch) {
    console.error('Failed to parse keys or endpoint from wgcf-profile.conf');
    process.exit(1);
}

const wireproxyConf = `[Interface]
Address = 172.16.0.2/32
MTU = 1280
PrivateKey = ${privateKeyMatch[1].trim()}

[Peer]
PublicKey = ${publicKeyMatch[1].trim()}
Endpoint = ${endpointMatch[1].trim()}

[Socks5]
BindAddress = 0.0.0.0:${PORT}
`;

fs.writeFileSync('wireproxy.conf', wireproxyConf);

console.log(`Starting wireproxy in user-space on port ${PORT}...`);
const child = spawn('wireproxy', ['-c', 'wireproxy.conf'], { stdio: 'inherit' });

child.on('close', (code) => {
    process.exit(code);
});

// Pass termination signals to the child process for graceful shutdown
process.on('SIGINT', () => child.kill('SIGINT'));
process.on('SIGTERM', () => child.kill('SIGTERM'));
