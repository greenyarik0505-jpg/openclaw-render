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
    export OPENCLAW_GATEWAY_TOKEN="oc_gw_7e8b91a24fd3c6e59012a4b8"
    echo "Using default/configured OPENCLAW_GATEWAY_TOKEN: $OPENCLAW_GATEWAY_TOKEN"
else
    echo "Using provided OPENCLAW_GATEWAY_TOKEN."
fi

# 3. Copy Kimi skills to workspace
if [ -d "/opt/kimiim/skills" ]; then
    mkdir -p "$OPENCLAW_WORKSPACE_DIR/skills"
    cp -rn /opt/kimiim/skills/* "$OPENCLAW_WORKSPACE_DIR/skills/" 2>/dev/null || true
    echo "Kimi skills linked to workspace."
fi

# 4. Configure initial openclaw.json
KIMI_TOKEN="${KIMI_BOT_TOKEN:-km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1}"

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
  },
  "plugins": {
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
else
    echo "Updating existing config at $OPENCLAW_CONFIG_PATH..."
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
        
        cfg.plugins = cfg.plugins || {};
        cfg.plugins.entries = cfg.plugins.entries || {};
        cfg.plugins.entries["kimi-claw"] = cfg.plugins.entries["kimi-claw"] || {};
        cfg.plugins.entries["kimi-claw"].enabled = true;
        cfg.plugins.entries["kimi-claw"].config = cfg.plugins.entries["kimi-claw"].config || {};
        cfg.plugins.entries["kimi-claw"].config.bridge = cfg.plugins.entries["kimi-claw"].config.bridge || {};
        cfg.plugins.entries["kimi-claw"].config.bridge.url = "wss://www.kimi.com/api-claw/bots/agent-ws";
        cfg.plugins.entries["kimi-claw"].config.bridge.token = process.env.KIMI_BOT_TOKEN || "km_b_prod_rEMqfnmmRPv1kp4lDcEgQ7voT58I3ti1";
        cfg.plugins.entries["kimi-claw"].config.bridge.kimiapiHost = "https://www.kimi.com/api-claw";
        cfg.plugins.entries["kimi-claw"].config.bridge.promptTimeoutMs = 1800000;
        
        fs.writeFileSync(path, JSON.stringify(cfg, null, 2));
      } catch (err) {
        console.error("Config update error:", err);
      }
    '
fi

# 5. Link pre-built plugin
if [ -d "/opt/kimi-claw" ]; then
    openclaw plugins install /opt/kimi-claw --link --force 2>/dev/null || true
    openclaw plugins enable kimi-claw 2>/dev/null || true
    echo "Kimi Claw plugin registered."
fi

echo "=== Launching OpenClaw Gateway on port $PORT ==="
exec openclaw gateway run --bind lan --port "$PORT" --token "$OPENCLAW_GATEWAY_TOKEN" --allow-unconfigured
