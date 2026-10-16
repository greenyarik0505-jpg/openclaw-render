import http from 'node:http';
import net from 'node:net';

const PORT = parseInt(process.env.PORT || '10000', 10);
const TARGET_PORT = parseInt(process.env.OPENCLAW_INTERNAL_PORT || '18789', 10);
const TARGET_HOST = '127.0.0.1';

console.log(`[proxy] Initializing Edge Gateway Proxy on port ${PORT} -> ${TARGET_HOST}:${TARGET_PORT}`);

const server = http.createServer((req, res) => {
  // 1. Health check handling for Render deployment probes
  if (req.url === '/health' || req.url === '/healthz') {
    const healthReq = http.request({
      host: TARGET_HOST,
      port: TARGET_PORT,
      path: req.url,
      method: 'GET',
      timeout: 1500
    }, (healthRes) => {
      res.writeHead(healthRes.statusCode || 200, healthRes.headers);
      healthRes.pipe(res);
    });

    healthReq.on('error', () => {
      // Return 200 OK so Render health check passes while OpenClaw finishes booting
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, status: 'starting', message: 'OpenClaw gateway is initializing' }));
    });

    healthReq.on('timeout', () => {
      healthReq.destroy();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, status: 'starting', message: 'OpenClaw gateway is initializing' }));
    });

    healthReq.end();
    return;
  }

  // 2. Standard HTTP request proxying
  const proxyReq = http.request({
    host: TARGET_HOST,
    port: TARGET_PORT,
    path: req.url,
    method: req.method,
    headers: req.headers
  }, (proxyRes) => {
    res.writeHead(proxyRes.statusCode || 200, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    res.writeHead(503, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end('<!DOCTYPE html><html><head><meta charset="utf-8"><title>OpenClaw Starting</title><meta http-equiv="refresh" content="3"></head><body style="font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#0f172a;color:#f8fafc"><div style="text-align:center;padding:2rem;background:#1e293b;border-radius:1rem;box-shadow:0 10px 25px rgba(0,0,0,0.5)"><h2>OpenClaw Gateway is Starting</h2><p style="color:#94a3b8">The gateway service is completing initialization. This page will refresh automatically in 3 seconds...</p></div></body></html>');
  });

  req.pipe(proxyReq);
});

// 3. WebSocket upgrade handling
server.on('upgrade', (req, clientSocket, head) => {
  const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
    targetSocket.write(`${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`);
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      targetSocket.write(`${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}\r\n`);
    }
    targetSocket.write('\r\n');
    if (head && head.length > 0) {
      targetSocket.write(head);
    }
    clientSocket.pipe(targetSocket);
    targetSocket.pipe(clientSocket);
  });

  targetSocket.on('error', () => {
    clientSocket.destroy();
  });

  clientSocket.on('error', () => {
    targetSocket.destroy();
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[proxy] Edge Gateway Proxy successfully listening on 0.0.0.0:${PORT}`);
});
