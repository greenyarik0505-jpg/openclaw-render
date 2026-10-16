FROM node:24-bookworm-slim

# Install system dependencies required for OpenClaw and native addons
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    bash \
    tar \
    git \
    python3 \
    make \
    g++ \
    tini \
    ca-certificates \
    procps \
    libjemalloc2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1. Install OpenClaw globally, disable spawn-broker, and patch worker heap limits to prevent unbounded memory on Free Tier
RUN npm install -g openclaw@2026.10.4 --prefer-online && npm cache clean --force \
    && SP=$(find /usr/local/lib/node_modules/openclaw -name "worker.js" | grep "spawn-broker" || true) \
    && if [ -n "$SP" ]; then echo 'process.exit(1);' > "$SP"; echo "Disabled spawn-broker at $SP"; fi \
    && WH=$(find /usr/local/lib/node_modules/openclaw -name "worker-heap-flag.mjs" || true) \
    && if [ -n "$WH" ]; then echo '// disabled' > "$WH"; echo "Neutralized worker-heap-flag at $WH"; fi

# 2. Pre-download and install kimiim-cli binary and skills at build time
RUN mkdir -p /usr/local/bin /opt/kimiim/skills/kimiim /opt/kimiim/skills/worker-safety /opt/kimiim/skills/time-awareness \
    && curl -fsSL "https://kimi-img.moonshot.cn/pub/claw/skills/kimiim/releases/latest/kimiim-cli_linux_amd64.tar.gz" | tar -xz -C /tmp \
    && mv /tmp/kimiim-cli_linux_amd64/kimiim-cli /usr/local/bin/kimiim-cli \
    && chmod +x /usr/local/bin/kimiim-cli \
    && rm -rf /tmp/kimiim-cli_linux_amd64 \
    && curl -fsSL "https://kimi-img.moonshot.cn/pub/claw/skills/kimiim/SKILL.md" -o /opt/kimiim/skills/kimiim/SKILL.md \
    && curl -fsSL "https://kimi-img.moonshot.cn/pub/claw/skills/worker-safety/SKILL.md" -o /opt/kimiim/skills/worker-safety/SKILL.md \
    && curl -fsSL "https://kimi-img.moonshot.cn/pub/claw/skills/time-awareness/SKILL.md" -o /opt/kimiim/skills/time-awareness/SKILL.md

# 3. Pre-install kimi-claw plugin and dependencies at build time (fast build servers, 0s overhead at runtime)
RUN mkdir -p /opt/kimi-claw \
    && curl -fsSL "https://cdn.kimi.com/kimi-claw/kimi-claw-latest.tgz" | tar -xz -C /opt/kimi-claw --strip-components=1 \
    && cd /opt/kimi-claw && npm install --omit=dev --prefer-online && npm cache clean --force

# Copy startup entrypoint, worker limits, and edge proxy
COPY proxy.js /app/proxy.js
COPY limit-workers.cjs /app/limit-workers.cjs
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Environment defaults
ENV PORT=10000
ENV OPENCLAW_GATEWAY_PORT=10000
ENV OPENCLAW_GATEWAY_BIND=lan
ENV OPENCLAW_SKIP_CRON=1
ENV OPENCLAW_SKIP_GMAIL_WATCHER=1
ENV OPENCLAW_DISABLE_BONJOUR=1
ENV NODE_DISABLE_COMPILE_CACHE=1
ENV MALLOC_ARENA_MAX=1
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
ENV MALLOC_CONF="narenas:1,tcache:false,dirty_decay_ms:0,muzzy_decay_ms:0"
ENV NODE_ENV=production
ENV NODE_OPTIONS="-r /app/limit-workers.cjs --expose-gc --max-old-space-size=210 --max-semi-space-size=4"

EXPOSE 10000 18789

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
