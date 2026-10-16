#!/usr/bin/env bash
set -e

echo "=== Starting OpenClaw Container Initialization ==="

# Limit V8 heap to 256MB to fit comfortably within memory limits
export NODE_OPTIONS="${NODE_OPTIONS:-} --max-old-space-size=256"

# 1. Start Edge Gateway Proxy immediately (guarantees port 10000 and /health open in <1s)
PORT="${PORT:-10000}"
export PORT="$PORT"
export OPENCLAW_INTERNAL_PORT="18789"

echo "Starting Edge Gateway Proxy on port $PORT..."
(
  while true; do
    node /app/proxy.js || true
    sleep 1
  done
) &
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
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "loopback",
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
        "http://127.0.0.1:18789",
        "*"
      ]
    }
  },
  "plugins": {
    "load": {
      "paths": [
        "/opt/kimi-claw"
      ]
    },
    "entries": {
      "kimi-claw": {
        "enabled": true,
        "config": {
          "bridge": {
            "url": "wss://www.kimi.com/api-claw/bots/agent-ws",
            "token": "$KIMI_TOKEN",
            "kimiapiHost": "https://www.kimi.com/api-claw",
            "promptTimeoutMs": 1800000
          }
        }
      }
    }
  }
}
EOF

echo "=== Launching OpenClaw Gateway on internal port 18789 ==="
openclaw gateway run --bind loopback --port 18789 --token "$OPENCLAW_GATEWAY_TOKEN" --allow-unconfigured &
GATEWAY_PID=$!

wait "$GATEWAY_PID"
