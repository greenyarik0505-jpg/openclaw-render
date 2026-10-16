# OpenClaw Deployment Progress on Render

## Status: Deploying Direct LAN Gateway (160MB Heap + optimize-for-size)
- **Date**: 2026-10-16
- **Workspace**: Ярослав's workspace (`tea-d7te7mosfn5c73akpfjg`)
- **Render Service Name**: `openclaw` (`srv-db8se049v7es73dndh90`)
- **Public URL**: https://openclaw-tlzq.onrender.com
- **GitHub Repo**: https://github.com/greenyarik0505-jpg/openclaw-render
- **Target Version**: OpenClaw v2026.10.4
- **Gateway Port**: 10000 (HTTPS terminated by Render edge)
- **Gateway Mode**: `remote`, bind: `lan`
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
- [x] Replaced interactive `openclaw plugins install` with declarative `plugins.load.paths` and auto-discovery.
- [x] Optimized Node.js memory footprint (`--max-old-space-size=160 --optimize-for-size`) to fit strictly within 512MB RAM.
- [x] Configured direct OpenClaw LAN gateway (`mode: remote`, `bind: lan`, `port: 10000`) without proxy overhead.
- [~] Deploying optimized container.
- [ ] Verify HTTP `/health` and Gateway handshake.
- [ ] Verify Kimi Claw Bridge connection.
- [ ] Provide user with live URL and AI model configuration guide.
