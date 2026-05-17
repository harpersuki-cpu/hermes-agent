#!/bin/bash
# Casa Phani — first-boot brain setup
# Runs automatically on every boot via casa-phani-entrypoint.sh
# Idempotent — flag file prevents re-running expensive steps.

set -e

FLAG="/opt/data/.brain-initialized"
BRAIN_DIR="/opt/data/brain"
GBRAIN_DIR="/opt/data/gbrain"
export HOME="/opt/data/home"
mkdir -p "$HOME"

# Skip if already done
if [ -f "$FLAG" ]; then
    echo "[casa-phani] Brain already initialized, skipping."
    exit 0
fi

echo "[casa-phani] First boot — setting up brain..."

# ── Install bun ──
if [ ! -f "$HOME/.bun/bin/bun" ]; then
    echo "[casa-phani] Installing bun..."
    curl -fsSL https://bun.sh/install | bash 2>&1 || {
        echo "[casa-phani] Bun install failed, trying npm fallback..."
    }
fi
export PATH="$HOME/.bun/bin:$HOME/.npm-global/bin:/usr/local/bin:$PATH"

# ── Clone & install gbrain ──
if [ ! -d "$GBRAIN_DIR" ]; then
    echo "[casa-phani] Cloning gbrain..."
    git clone --depth 1 https://github.com/garrytan/gbrain.git "$GBRAIN_DIR"
fi

cd "$GBRAIN_DIR"
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"

if ! command -v gbrain &>/dev/null; then
    echo "[casa-phani] Installing gbrain..."
    npm install --silent 2>&1
    npm link 2>&1
fi
export PATH="$HOME/.npm-global/bin:$PATH"

# ── Initialize gbrain database ──
if command -v gbrain &>/dev/null; then
    echo "[casa-phani] Initializing gbrain database..."
    gbrain init 2>&1 || true
fi

# ── Clone brain repo ──
if [ ! -d "$BRAIN_DIR" ]; then
    echo "[casa-phani] Cloning brain repo..."
    git clone --depth 1 https://github.com/harpersuki-cpu/casa-phani-brain.git "$BRAIN_DIR"
fi

# ── Import + embed ──
if command -v gbrain &>/dev/null && [ -d "$BRAIN_DIR" ]; then
    echo "[casa-phani] Importing brain pages..."
    gbrain import "$BRAIN_DIR" --no-embed 2>&1 || true

    if [ -n "$OPENAI_API_KEY" ]; then
        echo "[casa-phani] Generating embeddings..."
        gbrain embed --stale 2>&1 || true
    else
        echo "[casa-phani] Skipping embeddings (no OPENAI_API_KEY)."
    fi
fi

# ── Make everything owned by hermes user ──
chown -R 10000:10000 "$HOME" "$BRAIN_DIR" "$GBRAIN_DIR" /opt/data/.gbrain 2>/dev/null || true

touch "$FLAG"
echo "[casa-phani] ✅ Brain setup complete!"
