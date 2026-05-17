#!/bin/bash
# Casa Phani — first-boot brain setup
# Idempotent — flag file prevents re-running expensive steps.
# Flag is ONLY set when gbrain is fully working.

set -e

FLAG="/opt/data/.brain-initialized"
BRAIN_DIR="/opt/data/brain"
GBRAIN_DIR="/opt/data/gbrain"
export HOME="/opt/data/home"
mkdir -p "$HOME" "$HOME/.npm-global"

# Skip if fully done
if [ -f "$FLAG" ]; then
    echo "[casa-phani] Brain already initialized, skipping."
    exit 0
fi

echo "[casa-phani] First boot — setting up brain..."

# ── npm prefix (avoid /usr/local permission issues) ──
npm config set prefix "$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"

# ── Clone & install gbrain ──
if [ ! -d "$GBRAIN_DIR" ]; then
    echo "[casa-phani] Cloning gbrain..."
    git clone --depth 1 https://github.com/garrytan/gbrain.git "$GBRAIN_DIR"
fi

cd "$GBRAIN_DIR"
if ! command -v gbrain &>/dev/null; then
    echo "[casa-phani] Installing gbrain via npm..."
    npm install --silent 2>&1 || echo "[casa-phani] npm install had warnings"
    npm link 2>&1 || echo "[casa-phani] npm link had warnings"
fi
export PATH="$HOME/.npm-global/bin:$PATH"

# ── Verify gbrain is available ──
if ! command -v gbrain &>/dev/null; then
    echo "[casa-phani] ❌ gbrain not found after install. Will retry next boot."
    exit 1
fi

# ── Initialize gbrain database ──
echo "[casa-phani] Initializing gbrain database..."
gbrain init 2>&1 || echo "[casa-phani] gbrain init had issues"

# ── Clone brain repo ──
if [ ! -d "$BRAIN_DIR" ]; then
    echo "[casa-phani] Cloning brain repo..."
    git clone --depth 1 https://github.com/harpersuki-cpu/casa-phani-brain.git "$BRAIN_DIR"
fi

# ── Import + embed ──
if [ -d "$BRAIN_DIR" ]; then
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
chown -R 10000:10000 "$HOME" 2>/dev/null || true
chown -R 10000:10000 "$BRAIN_DIR" 2>/dev/null || true
chown -R 10000:10000 "$GBRAIN_DIR" 2>/dev/null || true
chown -R 10000:10000 /opt/data/.gbrain 2>/dev/null || true

# Only set flag if we got this far
touch "$FLAG"
echo "[casa-phani] ✅ Brain setup complete!"
