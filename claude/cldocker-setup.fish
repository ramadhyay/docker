#!/usr/bin/env fish
# One-time setup script for cldocker (Claude Code in a Docker sandbox)
# Includes: Node 24 + npm, Python 3.12 (system default), uv
# Run this once with: fish cldocker-setup.fish
# Re-run it any time to rebuild the image (e.g. to pick up a newer uv).

set -l IMAGE cldocker:latest

# The container runs as user 'node' (UID 1000). Bind-mounted folders
# (~/.claude, your project) must be writable by that UID.
if test (id -u) -ne 1000
    echo "WARNING: your UID is "(id -u)", not 1000. The container's 'node' user"
    echo "         may not be able to write to ~/.claude or your project folder."
    echo ""
end

# Base is the official Python 3.12 image (Debian trixie), so python/python3 are 3.12.
# Node 24 is copied in from the official Node image; uv from Astral's image.
set -l DOCKERFILE '
FROM node:24-trixie-slim AS node
FROM ghcr.io/astral-sh/uv:latest AS uv
FROM python:3.12-slim-trixie

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl libstdc++6 wl-clipboard \
 && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

COPY --from=uv /uv /uvx /usr/local/bin/

RUN useradd -m -u 1000 -s /bin/bash node \
 && mkdir -p /home/node/.npm-global /home/node/.cache/uv /workspace \
 && chown -R node:node /home/node /workspace

ENV HOME=/home/node \
    NPM_CONFIG_PREFIX=/home/node/.npm-global \
    PATH=/home/node/.npm-global/bin:$PATH \
    UV_PYTHON=3.12 \
    UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy

USER node
WORKDIR /workspace
'

echo "Step 1: Building $IMAGE (Node 24, Python 3.12, uv)..."
printf '%s\n' $DOCKERFILE | docker build --pull -t $IMAGE -; or begin
    echo "  Build failed. Is Docker running?"
    exit 1
end

echo "Step 2: Creating volumes and fixing their ownership..."
docker volume create claude-npm-global >/dev/null
docker volume create claude-uv-cache >/dev/null
docker run --rm --user root \
    -v "claude-npm-global:/home/node/.npm-global" \
    -v "claude-uv-cache:/home/node/.cache/uv" \
    $IMAGE \
    chown -R 1000:1000 /home/node/.npm-global /home/node/.cache/uv

echo "Step 3: Ensuring ~/.claude exists and is owned by you..."
mkdir -p ~/.claude
sudo chown -R (id -u):(id -g) ~/.claude

echo "Step 4: Ensuring ~/.claude.json exists (theme, onboarding, session state)..."
touch ~/.claude.json
sudo chown (id -u):(id -g) ~/.claude.json

echo "Step 5: Defining and saving the cldocker function..."
function cldocker
    # Self-heal: make sure the volumes are writable by 'node' (no-op if already fine)
    docker run --rm --user root \
        -v "claude-npm-global:/home/node/.npm-global" \
        -v "claude-uv-cache:/home/node/.cache/uv" \
        cldocker:latest \
        sh -c 'for d in /home/node/.npm-global /home/node/.cache/uv; do [ "$(stat -c %u $d)" = 1000 ] || chown -R 1000:1000 $d; done'

    docker run -it --rm \
    	-e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    	-e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    	-e NPM_CONFIG_PREFIX=/home/node/.npm-global \
    	-v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:ro" \
    	--user "$(id -u):$(id -g)" \
        -v "$HOME/.claude:/home/node/.claude" \
        -v "$HOME/.claude.json:/home/node/.claude.json" \
        -v "claude-npm-global:/home/node/.npm-global" \
        -v "claude-uv-cache:/home/node/.cache/uv" \
        -v "$PWD:/workspace" \
        cldocker:latest \
        bash -c 'command -v claude >/dev/null || npm install -g @anthropic-ai/claude-code; exec bash'
end
funcsave cldocker

echo "Step 6: Verifying versions..."
docker run --rm $IMAGE bash -c 'echo "  node   $(node --version)"; echo "  npm    $(npm --version)"; echo "  python $(python --version)"; echo "  uv     $(uv --version)"'

echo ""
echo "Done! Run 'cldocker' from any project folder, then type 'claude' inside."
echo "To update Claude Code later, run inside the container:"
echo "  npm install -g @anthropic-ai/claude-code"
