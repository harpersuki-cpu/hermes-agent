#!/bin/bash
# Casa Phani — first-boot brain setup
# Runs once, creates a flag file to skip on subsequent boots.
# Called from entrypoint or manually.

set -e

FLAG="/opt/data/.brain-initialized"
BRAIN_DIR="/opt/data/brain"
GBRAIN_DIR="/opt/data/gbrain"

# Skip if already done
if [ -f "$FLAG" ]; then
    echo "[casa-phani] Brain already initialized, skipping."
    exit 0
fi

echo "[casa-phani] First boot — setting up brain..."

# Install bun if not present
if ! command -v bun &>/dev/null && [ ! -f "$HOME/.bun/bin/bun" ]; then
    echo "[casa-phani] Installing bun..."
    curl -fsSL https://bun.sh/install | bash
fi
export PATH="$HOME/.bun/bin:$HOME/.npm-global/bin:$PATH"

# Clone gbrain if not present
if [ ! -d "$GBRAIN_DIR" ]; then
    echo "[casa-phani] Cloning gbrain..."
    git clone https://github.com/garrytan/gbrain.git "$GBRAIN_DIR"
    cd "$GBRAIN_DIR"
    npm config set prefix "$HOME/.npm-global"
    npm install && npm link
else
    echo "[casa-phani] gbrain already cloned."
fi

export PATH="$HOME/.npm-global/bin:$HOME/.bun/bin:$PATH"

# Initialize gbrain database
if command -v gbrain &>/dev/null; then
    echo "[casa-phani] Initializing gbrain..."
    gbrain init || true
    gbrain doctor --json || true
else
    echo "[casa-phani] WARNING: gbrain not on PATH after install"
fi

# Clone brain repo if not present
if [ ! -d "$BRAIN_DIR" ]; then
    echo "[casa-phani] Cloning brain repo..."
    git clone https://github.com/harpersuki-cpu/casa-phani-brain.git "$BRAIN_DIR"
else
    echo "[casa-phani] Brain repo already present."
fi

# Import brain into gbrain
if command -v gbrain &>/dev/null && [ -d "$BRAIN_DIR" ]; then
    echo "[casa-phani] Importing brain pages..."
    gbrain import "$BRAIN_DIR" --no-embed || true
    
    # Embed if OpenAI key is available
    if [ -n "$OPENAI_API_KEY" ]; then
        echo "[casa-phani] Generating embeddings..."
        gbrain embed --stale || true
    else
        echo "[casa-phani] OPENAI_API_KEY not set, skipping embeddings."
    fi
fi

# Copy personality file if present
SOUL_SRC="/opt/hermes/docker/SOUL.md"
SOUL_DST="/opt/data/personality.md"
if [ -f "$SOUL_SRC" ] && [ ! -f "$SOUL_DST" ]; then
    cp "$SOUL_SRC" "$SOUL_DST"
    echo "[casa-phani] Personality deployed."
fi

touch "$FLAG"
echo "[casa-phani] ✅ Brain setup complete!"
