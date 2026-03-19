const { startWarpProxy } = require('./index.js');

async function main() {
    console.log('Initializing proxy...');
    
    // Start proxy without blocking the Node event loop
    const proxyProcess = await startWarpProxy({
        port: 40000,
        workDir: './app_data'
    });

    console.log('Proxy is running! You can now execute other non-blocking tasks using this proxy.');

    // Simulated task: Gracefully shutdown the proxy after 10 seconds
    setTimeout(() => {
        console.log('Shutting down proxy gracefully...');
        proxyProcess.kill('SIGTERM');
    }, 10000);
}

main().catch(console.error);
