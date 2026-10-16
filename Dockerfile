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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install OpenClaw latest stable release globally (requires Node 24+)
RUN npm install -g openclaw@2026.10.4 --prefer-online && npm cache clean --force

# Copy startup entrypoint
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Environment defaults
ENV PORT=10000
ENV OPENCLAW_GATEWAY_PORT=10000
ENV OPENCLAW_GATEWAY_BIND=lan
ENV NODE_ENV=production

EXPOSE 10000 18789

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
