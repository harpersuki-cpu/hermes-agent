#!/bin/bash
# Casa Phani wrapper entrypoint
# Runs brain init (idempotent) then launches the real Hermes entrypoint

# Deploy config from image to volume (overwrites stale config on every boot)
CONFIG_SRC="/opt/hermes/cli-config.yaml.example"
CONFIG_DST="/opt/data/config.yaml"
if [ -f "$CONFIG_SRC" ]; then
    cp "$CONFIG_SRC" "$CONFIG_DST"
    echo "[casa-phani] Config deployed to $CONFIG_DST"
fi

# Copy personality on every boot (in case it was updated)
if [ -f /opt/hermes/docker/SOUL.md ]; then
    cp /opt/hermes/docker/SOUL.md /opt/data/personality.md
    echo "[casa-phani] Personality file deployed."
fi

# Run brain setup (skips automatically if already done via flag file)
if [ -f /opt/hermes/docker/casa-phani-init.sh ]; then
    echo "[casa-phani] Running brain init..."
    bash /opt/hermes/docker/casa-phani-init.sh || echo "[casa-phani] Init had errors (non-fatal, continuing)"
fi

# Hand off to the real entrypoint
exec /opt/hermes/docker/entrypoint.sh "$@"
