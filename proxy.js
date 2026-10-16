import http from 'node:http';
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';

const PORT = parseInt(process.env.PORT || '10000', 10);
const TARGET_PORT = parseInt(process.env.OPENCLAW_INTERNAL_PORT || '18789', 10);
const TARGET_HOST = '127.0.0.1';
const CONTROL_UI_DIR = process.env.OPENCLAW_CONTROL_UI_DIR || '/usr/local/lib/node_modules/openclaw/dist/control-ui';

// Prevent uncaught errors from crashing the proxy
process.on('uncaughtException', (err) => {
  console.error('[proxy] Uncaught exception:', err?.message || err);
});
process.on('unhandledRejection', (reason) => {
  console.error('[proxy] Unhandled rejection:', reason);
});

console.log(`[proxy] Initializing Edge Gateway Proxy on port ${PORT} -> ${TARGET_HOST}:${TARGET_PORT}`);
console.log(`[proxy] Control UI static asset directory: ${CONTROL_UI_DIR}`);

const MIME_TYPES = {
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.cjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.txt': 'text/plain; charset=utf-8'
};

function tryServeStatic(req, res) {
  if (req.method !== 'GET' && req.method !== 'HEAD') return false;

  let reqPath;
  try {
    reqPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch {
    return false;
  }

  const safePath = path.normalize(reqPath).replace(/^(\.\.[\/\\])+/, '');
  const isStaticPrefix = safePath.startsWith('/assets/') ||
                         safePath.startsWith('/themes/') ||
                         safePath.startsWith('/fonts/') ||
                         safePath.startsWith('/cloud-provider-icons/') ||
                         safePath.startsWith('/provider-icons/') ||
                         safePath.startsWith('/file-icons/') ||
                         safePath.startsWith('/app-art/') ||
                         safePath.startsWith('/community-art/');
  const isRootAsset = safePath === '/favicon.ico' ||
                      safePath === '/favicon.svg' ||
                      safePath === '/favicon-32.png' ||
                      safePath === '/apple-touch-icon.png' ||
                      safePath === '/social-card.png' ||
                      safePath === '/sw.js' ||
                      safePath === '/manifest.webmanifest' ||
                      safePath === '/asset-manifest.json';

  if (!isStaticPrefix && !isRootAsset) return false;

  const fullPath = path.join(CONTROL_UI_DIR, safePath);
  if (!fullPath.startsWith(CONTROL_UI_DIR)) return false;

  const ext = path.extname(safePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';
  const acceptEncoding = req.headers['accept-encoding'] || '';

  let serveFile = null;
  let contentEncoding = null;

  if (acceptEncoding.includes('br') && fs.existsSync(fullPath + '.br')) {
    serveFile = fullPath + '.br';
    contentEncoding = 'br';
  } else if (acceptEncoding.includes('gzip') && fs.existsSync(fullPath + '.gz')) {
    serveFile = fullPath + '.gz';
    contentEncoding = 'gzip';
  } else if (fs.existsSync(fullPath)) {
    serveFile = fullPath;
  }

  if (!serveFile) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-cache' });
    res.end('Not Found');
    return true;
  }

  try {
    const stat = fs.statSync(serveFile);
    const headers = {
      'Content-Type': contentType,
      'Content-Length': stat.size,
    };

    if (contentEncoding) {
      headers['Content-Encoding'] = contentEncoding;
    }

    if (safePath.startsWith('/assets/')) {
      headers['Cache-Control'] = 'public, max-age=31536000, immutable';
    } else if (safePath === '/sw.js') {
      headers['Cache-Control'] = 'no-cache';
    } else {
      headers['Cache-Control'] = 'public, max-age=86400';
    }

    res.writeHead(200, headers);
    if (req.method === 'HEAD') {
      res.end();
    } else {
      fs.createReadStream(serveFile).pipe(res);
    }
    return true;
  } catch (err) {
    console.error(`[proxy] Error serving static asset ${safePath}:`, err.message);
    res.writeHead(500, { 'Content-Type': 'text/plain' });
    res.end('Static Read Error');
    return true;
  }
}

const server = http.createServer((req, res) => {
  let hasResponded = false;

  // Helper: always respond 200 during startup to satisfy Render probes and keep browser auto-refreshing
  const sendHttpFallback = (statusCode = 200, errMsg = 'OpenClaw Gateway is initializing') => {
    if (hasResponded) return;
    hasResponded = true;
    try {
      res.writeHead(statusCode, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
        'Pragma': 'no-cache'
      });
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

  // 2. Direct static asset serving (assets, themes, fonts, icons) directly from disk
  // Serves instant responses (<1ms), bypassing OpenClaw event loop and avoiding worker OOM
  if (tryServeStatic(req, res)) {
    return;
  }

  // 3. Dynamic HTTP request proxying to OpenClaw Gateway
  const headers = { ...req.headers };
  const clientHost = req.headers.host || 'openclaw-tlzq.onrender.com';
  headers['x-forwarded-host'] = clientHost;
  headers['x-forwarded-proto'] = 'https';
  headers['x-forwarded-for'] = req.headers['x-forwarded-for'] || req.socket.remoteAddress || '127.0.0.1';
  headers['host'] = clientHost;
  delete headers['connection'];

  console.log(`[proxy] Inbound ${req.method} ${req.url}`);

  const proxyReq = http.request({
    host: TARGET_HOST,
    port: TARGET_PORT,
    path: req.url,
    method: req.method,
    headers: headers,
    timeout: 60000
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

// 4. WebSocket upgrade handling
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
