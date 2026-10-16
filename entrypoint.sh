#!/usr/bin/env bash
set -e

echo "=== Starting OpenClaw Container Initialization ==="

# Set thread stack and threadpool limit to save OS memory on 512MB Free Tier
ulimit -s 1024 2>/dev/null || true
export UV_THREADPOOL_SIZE=2
export MALLOC_ARENA_MAX=2
export OPENCLAW_SKIP_CHANNELS=1
export OPENCLAW_SKIP_CRON=1
export OPENCLAW_SKIP_GMAIL_WATCHER=1
export OPENCLAW_DISABLE_BONJOUR=1

# 1. Start Edge Gateway Proxy immediately (guarantees port 10000 and /health open in <1s)
PORT="${PORT:-10000}"
export PORT="$PORT"
export OPENCLAW_INTERNAL_PORT="18789"

echo "Starting Edge Gateway Proxy on port $PORT..."
NODE_OPTIONS="--max-old-space-size=12" node --optimize-for-size /app/proxy.js &
PROXY_PID=$!
echo "Edge Gateway Proxy started with PID: $PROXY_PID."

cleanup() {
    echo "Signal received. Terminating processes..."
    kill -TERM "$PROXY_PID" 2>/dev/null || true
    kill -TERM "$GATEWAY_PID" 2>/dev/null || true
    wait "$GATEWAY_PID" 2>/dev/null || true
    wait "$PROXY_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# 2. Setup Persistent Storage & Directories
if [ -d "/data" ]; then
    echo "Persistent volume /data detected. Configuring persistent directories..."
    export OPENCLAW_STATE_DIR="/data/.openclaw"
    export OPENCLAW_CONFIG_DIR="/data/.openclaw"
    export OPENCLAW_CONFIG_PATH="/data/.openclaw/openclaw.json"
    export OPENCLAW_WORKSPACE_DIR="/data/workspace"
    mkdir -p /data/.openclaw /data/workspace /data/.openclaw/extensions
else
    echo "No /data mount found. Using home directory for state..."
    export OPENCLAW_STATE_DIR="$HOME/.openclaw"
    export OPENCLAW_CONFIG_DIR="$HOME/.openclaw"
    export OPENCLAW_CONFIG_PATH="$HOME/.openclaw/openclaw.json"
    export OPENCLAW_WORKSPACE_DIR="$HOME/.openclaw/workspace"
    mkdir -p "$HOME/.openclaw" "$HOME/.openclaw/workspace" "$HOME/.openclaw/extensions"
fi

export PATH="$HOME/.local/bin:$PATH"

# Enforce worker heap limit patch (guarantees workers never exceed 8MB heap)
WH=$(find /usr/local/lib/node_modules/openclaw -name "worker-heap-flag.mjs" 2>/dev/null || true)
if [ -n "$WH" ]; then
    sed -i 's/--max-old-space-size=0 --max-heap-size=0/--max-old-space-size=8 --max-heap-size=8/g' "$WH" 2>/dev/null || true
    echo "Enforced worker-heap-flag at $WH"
fi

# 3. Setup Gateway Token
if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
    export OPENCLAW_GATEWAY_TOKEN="oc_gw_7e8b91a24fd3c6e59012a4b8"
    echo "Using default/configured OPENCLAW_GATEWAY_TOKEN: $OPENCLAW_GATEWAY_TOKEN"
else
    echo "Using provided OPENCLAW_GATEWAY_TOKEN."
fi

# 4. Setup Kimi skills and extensions (symlinks for zero overhead)
if [ -d "/opt/kimiim/skills" ]; then
    mkdir -p "$OPENCLAW_WORKSPACE_DIR/skills"
    cp -rn /opt/kimiim/skills/* "$OPENCLAW_WORKSPACE_DIR/skills/" 2>/dev/null || true
    echo "Kimi skills linked to workspace."
fi

if [ -d "/opt/kimi-claw" ]; then
    mkdir -p "$OPENCLAW_STATE_DIR/extensions"
    ln -sfn /opt/kimi-claw "$OPENCLAW_STATE_DIR/extensions/kimi-claw"
    echo "Kimi Claw extension linked."
fi

# 5. Configure openclaw.json with Gateway and Kimi Bridge
KIMI_TOKEN="${KIMI_BOT_TOKEN:-km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1}"

echo "Writing configuration to $OPENCLAW_CONFIG_PATH..."
cat <<EOF > "$OPENCLAW_CONFIG_PATH"
{
  "browser": {
    "enabled": false
  },
  "telemetry": {
    "enabled": false
  },
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "loopback",
    "publicOrigin": "https://openclaw-tlzq.onrender.com",
    "trustedProxies": [
      "127.0.0.1",
      "::1",
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16"
    ],
    "allowRealIpFallback": true,
    "auth": {
      "mode": "token",
      "token": "$OPENCLAW_GATEWAY_TOKEN"
    },
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true,
      "allowedOrigins": [
        "https://openclaw-tlzq.onrender.com",
        "http://localhost:10000",
        "http://127.0.0.1:10000",
        "http://localhost:18789",
        "http://127.0.0.1:18789"
      ]
    }
  }
}
EOF

# Set balanced memory limits to prevent JS heap OOM while staying within 512MB Free Tier
export NODE_OPTIONS="--max-old-space-size=192 --max-semi-space-size=4"

OPENCLAW_BIN="$(command -v openclaw || echo /usr/local/bin/openclaw)"
echo "Resolved openclaw binary: $OPENCLAW_BIN"

set +e
echo "=== Launching OpenClaw Gateway on internal port 18789 ==="
while true; do
    node --optimize-for-size --max-old-space-size=192 --max-semi-space-size=4 "$OPENCLAW_BIN" gateway run --bind loopback --port 18789 --token "$OPENCLAW_GATEWAY_TOKEN" --allow-unconfigured --compact &
    GATEWAY_PID=$!
    wait "$GATEWAY_PID"
    EXIT_CODE=$?
    echo "OpenClaw Gateway exited (code $EXIT_CODE). Restarting in 2s..."
    sleep 2
done
