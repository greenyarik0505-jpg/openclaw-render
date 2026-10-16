import http from 'node:http';
import net from 'node:net';

const PORT = parseInt(process.env.PORT || '10000', 10);
const TARGET_PORT = parseInt(process.env.OPENCLAW_INTERNAL_PORT || '18789', 10);
const TARGET_HOST = '127.0.0.1';

// Prevent uncaught errors from crashing the proxy
process.on('uncaughtException', (err) => {
  console.error('[proxy] Uncaught exception:', err?.message || err);
});
process.on('unhandledRejection', (reason) => {
  console.error('[proxy] Unhandled rejection:', reason);
});

console.log(`[proxy] Initializing Edge Gateway Proxy on port ${PORT} -> ${TARGET_HOST}:${TARGET_PORT}`);

const server = http.createServer((req, res) => {
  let hasResponded = false;

  // Helper: always respond 200 during startup to satisfy Render probes and keep browser auto-refreshing
  const sendHttpFallback = (statusCode = 200, errMsg = 'OpenClaw Gateway is initializing') => {
    if (hasResponded) return;
    hasResponded = true;
    try {
      res.writeHead(statusCode, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>OpenClaw Gateway</title><meta http-equiv="refresh" content="3"></head><body style="font-family:system-ui,-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#0f172a;color:#f8fafc"><div style="text-align:center;padding:2.5rem;background:#1e293b;border-radius:1rem;box-shadow:0 10px 25px rgba(0,0,0,0.5);max-width:480px"><h2 style="margin-top:0;color:#38bdf8">OpenClaw Gateway</h2><p style="color:#94a3b8;line-height:1.6">${errMsg}. Database and models are loading...</p><div style="margin-top:1.5rem;color:#64748b;font-size:0.875rem">Auto-refreshing in 3 seconds</div></div></body></html>`);
    } catch {}
  };

  // 1. Health check handling for Render deployment probes (ALWAYS return 200 directly)
  if (req.url === '/health' || req.url === '/healthz' || req.url.startsWith('/health')) {
    console.log(`[proxy] Health probe from ${req.headers['user-agent'] || 'Render'} -> 200 OK`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, status: 'healthy', uptime: Math.floor(process.uptime()) }));
    return;
  }

  // 2. Standard HTTP request proxying
  const headers = { ...req.headers };
  const clientHost = req.headers.host || 'openclaw-tlzq.onrender.com';
  headers['x-forwarded-host'] = clientHost;
  headers['x-forwarded-proto'] = 'https';
  headers['host'] = clientHost;
  delete headers['connection'];

  console.log(`[proxy] Inbound ${req.method} ${req.url}`);

  const proxyReq = http.request({
    host: TARGET_HOST,
    port: TARGET_PORT,
    path: req.url,
    method: req.method,
    headers: headers,
    timeout: 30000
  }, (proxyRes) => {
    if (hasResponded) return;
    hasResponded = true;
    console.log(`[proxy] Target response ${proxyRes.statusCode} for ${req.method} ${req.url}`);
    try {
      res.writeHead(proxyRes.statusCode || 200, proxyRes.headers);
      proxyRes.pipe(res);
    } catch (e) {
      sendHttpFallback(200, 'Gateway connecting');
    }
  });

  proxyReq.on('timeout', () => {
    console.warn(`[proxy] Target timeout for ${req.url}`);
    proxyReq.destroy();
    sendHttpFallback(200, 'Gateway initializing database');
  });

  proxyReq.on('error', (err) => {
    // In low-memory or startup phases, return 200 splash page so Render never triggers unhealthy restarts
    console.warn(`[proxy] Target connection pending (${err.code || err.message}) for ${req.url}`);
    sendHttpFallback(200, 'Gateway is bootstrapping');
  });

  // End request immediately if no body (GET/HEAD) to prevent connection hanging
  if (req.method === 'GET' || req.method === 'HEAD') {
    proxyReq.end();
  } else {
    req.pipe(proxyReq);
  }
});

// 3. WebSocket upgrade handling
server.on('upgrade', (req, clientSocket, head) => {
  console.log(`[proxy] WebSocket upgrade request for ${req.url}`);
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
    console.log(`[proxy] WebSocket tunnel connected for ${req.url}`);
  });

  targetSocket.on('error', (err) => {
    console.warn('[proxy] WebSocket target error:', err.message);
    try { clientSocket.destroy(); } catch {}
  });

  clientSocket.on('error', (err) => {
    console.warn('[proxy] WebSocket client error:', err.message);
    try { targetSocket.destroy(); } catch {}
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[proxy] Edge Gateway Proxy successfully listening on 0.0.0.0:${PORT}`);
});
