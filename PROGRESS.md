# OpenClaw Deployment Progress on Render

## Status: 100% OPERATIONAL & FULLY STABILIZED (Deploy dep-db94esuk1f9s73fi7rhg)
- **Date**: 2026-10-16
- **Workspace**: Ярослав's workspace (`tea-d7te7mosfn5c73akpfjg`)
- **Render Service Name**: `openclaw` (`srv-db8se049v7es73dndh90`)
- **Public URL**: https://openclaw-tlzq.onrender.com
- **Direct Auth URL**: https://openclaw-tlzq.onrender.com/?gatewayUrl=wss%3A%2F%2Fopenclaw-tlzq.onrender.com#token=oc_gw_7e8b91a24fd3c6e59012a4b8
- **GitHub Repo**: https://github.com/greenyarik0505-jpg/openclaw-render
- **Target Version**: OpenClaw v2026.10.4
- **Gateway Port**: 10000 (terminated by Render edge)
- **Gateway Internal Port**: 18789
- **Gateway Token**: `oc_gw_7e8b91a24fd3c6e59012a4b8`
- **Kimi Bot Token**: `km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1`
- **Bridge Subscription Status**: Connected & subscribed (`default_chat_id=1a14119a-ad12-8f62-8000-0920bab2c7bf`)

---

## Action Checklist
- [x] Check Render CLI status & authenticate active workspace (`tea-d7te7mosfn5c73akpfjg`)
- [x] Inspect existing workspace resources (safe-mode: no changes to `parallax-backend`)
- [x] Research latest stable OpenClaw version (`v2026.10.4` on GitHub & npm)
- [x] Analyze Render deployment requirements (Docker, Gateway, HTTPS, persistent disk, health check)
- [x] Analyze Kimi integration script (`https://cdn.kimi.com/kimi-claw/claw-install.sh`)
- [x] Create Dockerfile, entrypoint.sh, .gitignore, and render.yaml blueprint
- [x] Tested payment requirements for Standard plan: Render returns `402 Payment Required` because no card is attached to billing.
- [x] User confirmed to proceed without card attachment ("Делай деплай на кредити какие есть карта не привязана").
- [x] Created GitHub repository `greenyarik0505-jpg/openclaw-render` and pushed code.
- [x] Provisioned `openclaw` Web Service on Render (`srv-db8se049v7es73dndh90`).
- [x] Configured environment variables (`PORT`, `OPENCLAW_GATEWAY_PORT`, `OPENCLAW_GATEWAY_BIND`, `OPENCLAW_GATEWAY_TOKEN`, `KIMI_BOT_TOKEN`, `OPENCLAW_PUBLIC_ORIGIN`).
- [x] Upgraded Dockerfile to `node:24-bookworm-slim` for OpenClaw engine requirement.
- [x] Pre-cached Kimi plugin and skills at build time.
- [x] Implemented edge `proxy.js` answering `/health` in <1s for instant Render readiness.
- [x] Diagnosed cgroup OOM: multi-process `spawn-broker` consumes ~80MB extra RAM alongside SQLite worker threads.
- [x] Patched Dockerfile to neutralize `spawn-broker/worker.js`, triggering OpenClaw's native fallback: `in-process spawning is in effect for the lifetime of this process` (saving 80MB RAM).
- [x] Added `OPENCLAW_SKIP_CHANNELS=1` to disable unused channel poller overhead and channel-health-monitor loops.
- [x] Fixed `proxy.js` GET/HEAD request body termination (`proxyReq.end()`) to eliminate 30-second gateway timeouts.
- [x] Diagnosed cgroup OOM: OpenClaw `worker-heap-flag.mjs` was resetting `--max-old-space-size=0 --max-heap-size=0` for all worker threads, causing workers (SQLite, Control UI asset worker, etc.) to allocate unbounded 4.2GB heaps.
- [x] Patched `worker-heap-flag.mjs` to `--max-old-space-size=16 --max-heap-size=16` in Dockerfile and entrypoint.sh to strictly cap worker memory.
- [x] Added `ulimit -s 1024` to cap thread stack size at 1MB, eliminating virtual memory sprawl.
- [x] Observed mark-compact pressure at 158.4MB during HTTP server initialization.
- [x] Set V8 heap to `--max-old-space-size=192 --max-semi-space-size=4` providing exact headroom for 158MB peak without bloating container RSS.
- [x] Added `MALLOC_ARENA_MAX=2` to eliminate glibc multi-core heap fragmentation on Linux.
- [x] Added `OPENCLAW_SKIP_CRON=1`, `OPENCLAW_SKIP_GMAIL_WATCHER=1`, `OPENCLAW_DISABLE_BONJOUR=1` to eliminate background thread loops.
- [x] Identified Control UI worker thread pool (WorkerTaskPool maxWorkers: 2) causing cgroup OOM when incoming GET / was received.
- [x] Patched `maxWorkers: 2` to `maxWorkers: 1` in OpenClaw distribution files.
- [x] Calibrated V8 heap to 192MB with 4MB semi-space, eliminating both V8 heap OOM and Linux cgroup limits.
- [x] Configured `gateway.trustedProxies` with loopback/private subnets and `allowRealIpFallback: true` in openclaw.json so internal proxying succeeds without unattributable proxy rejections.
- [x] Forwarded `x-forwarded-for` header in `proxy.js`.
- [x] Removed aggressive background bash polling loop (curl in subshell every 2s) from entrypoint.sh.
- [x] Pre-cached Kimi plugin and skills at build time.
- [x] Configured Kimi Claw Bridge in openclaw.json (`plugins.load.paths`, `plugins.entries["kimi-claw"]`, bot token `km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1`).
- [x] Verified Kimi Claw plugin successfully loaded in OpenClaw (`/opt/kimi-claw/dist/index.js`, plugin v0.27.1).
- [x] Verified Kimi Claw outbound live IM sender registered (`agentId=main`, `accountId=main`, `ownerId=2b3902d0-5745-4df9-b52e-d8a99c576c4f`).
- [x] Verified live HTTP 200 OK response from OpenClaw Control UI at `https://openclaw-tlzq.onrender.com`.
- [x] Verified gateway proxy forwarding in <1s.
- [x] OpenClaw + Kimi Claw is 100% LIVE and operational!
