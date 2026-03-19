const fs = require('fs');
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);
const { spawn } = require('child_process');

/**
 * Starts the WARP SOCKS5 proxy asynchronously.
 * @param {Object} options - Configuration options.
 * @param {number} options.port - The port to expose the SOCKS5 proxy (default: 40000).
 * @param {string} options.workDir - The working directory to store configurations (default: '/app').
 * @returns {Promise<import('child_process').ChildProcess>} The wireproxy child process.
 */
async function startWarpProxy(options = {}) {
    const port = options.port || process.env.PROXY_PORT || 40000;
    const workDir = options.workDir || '/app';

    if (!fs.existsSync(workDir)) {
        fs.mkdirSync(workDir, { recursive: true });
    }

    const originalDir = process.cwd();
    process.chdir(workDir);

    try {
        // Skip registration if configuration already exists
        if (!fs.existsSync('wgcf-profile.conf')) {
            console.log('Registering WARP account using wgcf...');
            await exec('wgcf register --accept-tos');
            await exec('wgcf generate');
        } else {
            console.log('Using existing WARP configuration...');
        }

        console.log('Extracting WireGuard configuration...');
        const profileStr = fs.readFileSync('wgcf-profile.conf', 'utf8');

        const privateKeyMatch = profileStr.match(/PrivateKey\s*=\s*(.+)/);
        const publicKeyMatch = profileStr.match(/PublicKey\s*=\s*(.+)/);
        const endpointMatch = profileStr.match(/Endpoint\s*=\s*(.+)/);

        if (!privateKeyMatch || !publicKeyMatch || !endpointMatch) {
            throw new Error('Failed to parse keys or endpoint from wgcf-profile.conf');
        }

        const wireproxyConf = `[Interface]
Address = 172.16.0.2/32
MTU = 1280
PrivateKey = ${privateKeyMatch[1].trim()}

[Peer]
PublicKey = ${publicKeyMatch[1].trim()}
Endpoint = ${endpointMatch[1].trim()}

[Socks5]
BindAddress = 0.0.0.0:${port}
`;

        fs.writeFileSync('wireproxy.conf', wireproxyConf);

        console.log(`Starting wireproxy in user-space on port ${port}...`);
        const child = spawn('wireproxy', ['-c', 'wireproxy.conf'], { stdio: 'inherit' });

        // Wait slightly to ensure process doesn't instantly crash before resolving
        await new Promise(resolve => setTimeout(resolve, 1000));

        return child;
    } finally {
        process.chdir(originalDir);
    }
}

// If executed directly via CLI (e.g., node index.js)
if (require.main === module) {
    startWarpProxy().then(child => {
        child.on('close', (code) => {
            process.exit(code || 0);
        });
        
        // Pass termination signals to the child process for graceful shutdown
        process.on('SIGINT', () => child.kill('SIGINT'));
        process.on('SIGTERM', () => child.kill('SIGTERM'));
    }).catch(err => {
        console.error('Fatal Error:', err);
        process.exit(1);
    });
}

module.exports = { startWarpProxy };
