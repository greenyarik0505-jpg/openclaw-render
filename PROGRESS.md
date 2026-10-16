# OpenClaw Deployment Progress on Render

## Status: Deploying Native LAN Gateway (mode: local, bind: lan, 180MB Heap)
- **Date**: 2026-10-16
- **Workspace**: Ярослав's workspace (`tea-d7te7mosfn5c73akpfjg`)
- **Render Service Name**: `openclaw` (`srv-db8se049v7es73dndh90`)
- **Public URL**: https://openclaw-tlzq.onrender.com
- **GitHub Repo**: https://github.com/greenyarik0505-jpg/openclaw-render
- **Target Version**: OpenClaw v2026.10.4
- **Gateway Port**: 10000 (HTTPS terminated by Render edge)
- **Gateway Mode**: `local`, bind: `lan` (0.0.0.0:10000)
- **Public Origin**: `https://openclaw-tlzq.onrender.com`
- **Gateway Token**: `oc_gw_7e8b91a24fd3c6e59012a4b8`
- **Kimi Bot Token**: `km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1`
- **Active Deploy**: `dep-db8tj48n74is73cplav0` (commit `544789b`)

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
- [x] Fixed configuration schema: `gateway.mode: "local"` (required to run gateway server locally), `gateway.bind: "lan"` (binds to 0.0.0.0), and `gateway.publicOrigin: "https://openclaw-tlzq.onrender.com"`. Validated against `openclaw config validate`.
- [x] Capped Node.js heap to 180MB (`--max-old-space-size=180`) to ensure both main gateway and broker fit inside 512MB RAM without OOM.
- [~] Deploying commit `544789b` (`dep-db8tj48n74is73cplav0`).
- [ ] Verify HTTP `/health` and Gateway handshake.
- [ ] Verify Kimi Claw Bridge connection.
- [ ] Provide user with live URL and AI model configuration guide.
