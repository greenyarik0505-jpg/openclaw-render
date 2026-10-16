# OpenClaw Deployment Progress on Render

## Status: Deploying In-Process Single-Daemon Architecture with Zero-OOM Memory Limits
- **Date**: 2026-10-16
- **Workspace**: Ярослав's workspace (`tea-d7te7mosfn5c73akpfjg`)
- **Render Service Name**: `openclaw` (`srv-db8se049v7es73dndh90`)
- **Public URL**: https://openclaw-tlzq.onrender.com
- **GitHub Repo**: https://github.com/greenyarik0505-jpg/openclaw-render
- **Target Version**: OpenClaw v2026.10.4
- **Gateway Port**: 10000 (HTTPS terminated by Render edge)
- **Gateway Mode**: `local`, internal port: `18789`, proxy port: `10000`
- **Public Origin**: `https://openclaw-tlzq.onrender.com`
- **Gateway Token**: `oc_gw_7e8b91a24fd3c6e59012a4b8`
- **Kimi Bot Token**: `km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1`

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
- [x] Configured `--compact` logging and tuned V8 heap to `--max-old-space-size=160 --max-semi-space-size=4`.
- [ ] Push commit and trigger Render deploy.
- [ ] Verify HTTP `/health` and Gateway handshake.
- [ ] Verify Kimi Claw Bridge connection.
- [ ] Provide user with live URL and AI model configuration guide.
