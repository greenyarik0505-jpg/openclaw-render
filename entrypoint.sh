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
    mkdir -p /data/.openclaw /data/workspace
else
    echo "No /data mount found. Using home directory for state..."
    export OPENCLAW_STATE_DIR="$HOME/.openclaw"
    export OPENCLAW_CONFIG_DIR="$HOME/.openclaw"
    export OPENCLAW_CONFIG_PATH="$HOME/.openclaw/openclaw.json"
    export OPENCLAW_WORKSPACE_DIR="$HOME/.openclaw/workspace"
    mkdir -p "$HOME/.openclaw" "$HOME/.openclaw/workspace"
fi

export PATH="$HOME/.local/bin:$PATH"

# 2. Setup Gateway Token & Port
PORT="${PORT:-10000}"
export OPENCLAW_GATEWAY_PORT="$PORT"
export OPENCLAW_GATEWAY_BIND="lan"

if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
    export OPENCLAW_GATEWAY_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
    echo "Generated Gateway Token: $OPENCLAW_GATEWAY_TOKEN"
else
    echo "Using provided OPENCLAW_GATEWAY_TOKEN."
fi

# 3. Configure initial openclaw.json if not present or sync settings
if [ ! -f "$OPENCLAW_CONFIG_PATH" ]; then
    echo "Creating initial $OPENCLAW_CONFIG_PATH..."
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
  }
}
EOF
else
    echo "Config file already exists. Updating gateway port and bind..."
    node -e '
      const fs = require("fs");
      const path = process.env.OPENCLAW_CONFIG_PATH;
      try {
        const cfg = JSON.parse(fs.readFileSync(path, "utf8"));
        cfg.gateway = cfg.gateway || {};
        cfg.gateway.port = parseInt(process.env.PORT, 10);
        cfg.gateway.bind = "lan";
        cfg.gateway.auth = cfg.gateway.auth || {};
        cfg.gateway.auth.mode = "token";
        if (process.env.OPENCLAW_GATEWAY_TOKEN) {
          cfg.gateway.auth.token = process.env.OPENCLAW_GATEWAY_TOKEN;
        }
        cfg.gateway.controlUi = cfg.gateway.controlUi || {};
        cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true;
        cfg.gateway.controlUi.allowedOrigins = ["*"];
        fs.writeFileSync(path, JSON.stringify(cfg, null, 2));
      } catch (err) {
        console.error("Config update error:", err);
      }
    '
fi

# 4. Install Kimi Bot Bridge if token provided
KIMI_TOKEN="${KIMI_BOT_TOKEN:-km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1}"
if [ -n "$KIMI_TOKEN" ]; then
    echo "Configuring Kimi Claw Bridge integration with provided bot token..."
    (
      sleep 5
      echo "Running Kimi Claw installation script in background..."
      bash <(curl -fsSL https://cdn.kimi.com/kimi-claw/claw-install.sh) --bot-token "$KIMI_TOKEN" || {
        echo "Kimi Claw background installation warning: script exited with code $?"
      }
    ) &
fi

echo "=== Launching OpenClaw Gateway on port $PORT ==="
exec openclaw gateway --bind lan --port "$PORT" --token "$OPENCLAW_GATEWAY_TOKEN" --allow-unconfigured
