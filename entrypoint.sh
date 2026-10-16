#!/usr/bin/env bash
set -e

echo "=== Starting OpenClaw Container Initialization ==="

# 1. Setup Persistent Storage & Directories
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

# 2. Setup Gateway Token & Port
PORT="${PORT:-10000}"
export OPENCLAW_GATEWAY_PORT="$PORT"
export OPENCLAW_GATEWAY_BIND="lan"

if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
    export OPENCLAW_GATEWAY_TOKEN="oc_gw_7e8b91a24fd3c6e59012a4b8"
    echo "Using default/configured OPENCLAW_GATEWAY_TOKEN: $OPENCLAW_GATEWAY_TOKEN"
else
    echo "Using provided OPENCLAW_GATEWAY_TOKEN."
fi

# 3. Setup Kimi skills and extensions (zero runtime compile/install overhead)
if [ -d "/opt/kimiim/skills" ]; then
    mkdir -p "$OPENCLAW_WORKSPACE_DIR/skills"
    cp -rn /opt/kimiim/skills/* "$OPENCLAW_WORKSPACE_DIR/skills/" 2>/dev/null || true
    echo "Kimi skills linked to workspace."
fi

if [ -d "/opt/kimi-claw" ]; then
    mkdir -p "$OPENCLAW_STATE_DIR/extensions"
    cp -rn /opt/kimi-claw "$OPENCLAW_STATE_DIR/extensions/kimi-claw" 2>/dev/null || true
    echo "Kimi Claw extension deployed."
fi

# 4. Configure openclaw.json with Gateway and Kimi Bridge
KIMI_TOKEN="${KIMI_BOT_TOKEN:-km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1}"

echo "Writing configuration to $OPENCLAW_CONFIG_PATH..."
cat <<EOF > "$OPENCLAW_CONFIG_PATH"
{
  "gateway": {
    "mode": "local",
    "port": $PORT,
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "$OPENCLAW_GATEWAY_TOKEN"
    },
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true,
      "allowedOrigins": ["*"]
    }
  },
  "plugins": {
    "load": {
      "paths": [
        "$OPENCLAW_STATE_DIR/extensions/kimi-claw"
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

echo "=== Launching OpenClaw Gateway on port $PORT ==="
exec openclaw gateway run --bind lan --port "$PORT" --token "$OPENCLAW_GATEWAY_TOKEN" --allow-unconfigured
