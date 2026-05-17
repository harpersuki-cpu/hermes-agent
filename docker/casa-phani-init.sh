#!/bin/bash
# Casa Phani — first-boot brain setup
# Requires GITHUB_PAT env var for private brain repo access.

set -e

FLAG="/opt/data/.brain-initialized"
BRAIN_DIR="/opt/data/brain"
GBRAIN_DIR="/opt/data/gbrain"
export HOME="/opt/data/home"
mkdir -p "$HOME" "$HOME/.npm-global"

if [ -f "$FLAG" ]; then
    echo "[casa-phani] Brain already initialized, skipping."
    exit 0
fi

echo "[casa-phani] First boot — setting up brain..."

# ── npm prefix ──
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

if ! command -v gbrain &>/dev/null; then
    echo "[casa-phani] ❌ gbrain not found after install. Will retry next boot."
    exit 1
fi

echo "[casa-phani] Initializing gbrain database..."
gbrain init 2>&1 || echo "[casa-phani] gbrain init had issues"

# ── Clone brain repo (private — needs GITHUB_PAT) ──
if [ ! -d "$BRAIN_DIR" ]; then
    if [ -n "$GITHUB_PAT" ]; then
        echo "[casa-phani] Cloning brain repo (authenticated)..."
        git clone --depth 1 "https://${GITHUB_PAT}@github.com/harpersuki-cpu/casa-phani-brain.git" "$BRAIN_DIR"
    else
        echo "[casa-phani] ⚠️ GITHUB_PAT not set — cannot clone private brain repo."
        echo "[casa-phani] Add GITHUB_PAT env var in Railway and redeploy."
    fi
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

# ── Ownership ──
chown -R 10000:10000 "$HOME" 2>/dev/null || true
chown -R 10000:10000 "$BRAIN_DIR" 2>/dev/null || true
chown -R 10000:10000 "$GBRAIN_DIR" 2>/dev/null || true
chown -R 10000:10000 /opt/data/.gbrain 2>/dev/null || true

touch "$FLAG"
echo "[casa-phani] ✅ Brain setup complete!"
