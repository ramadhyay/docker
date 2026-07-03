#!/usr/bin/env fish
# One-time setup script for cldocker (Claude Code in a Docker sandbox)
# Run this once with: fish cldocker-setup.fish

echo "Step 1: Fixing ownership of claude-npm-global volume..."
docker run --rm \
    -v "claude-npm-global:/home/node/.npm-global" \
    node:24-trixie-slim \
    chown -R 1000:1000 /home/node/.npm-global

echo "Step 2: Cleaning up any root-owned files in ~/.claude from earlier attempts..."
sudo chown -R (id -u):(id -g) ~/.claude 2>/dev/null; or echo "  (skipped — ~/.claude may not exist yet, that's fine)"

echo "Step 3: Ensuring ~/.claude.json exists (holds theme, onboarding, and session state)..."
touch ~/.claude.json
sudo chown (id -u):(id -g) ~/.claude.json 2>/dev/null

echo "Step 4: Defining and saving the cldocker function..."
function cldocker
    docker run -it --rm \
        --user node \
        -e HOME=/home/node \
        -e NPM_CONFIG_PREFIX=/home/node/.npm-global \
        -v "$HOME/.claude:/home/node/.claude" \
        -v "$HOME/.claude.json:/home/node/.claude.json" \
        -v "claude-npm-global:/home/node/.npm-global" \
        -v "$PWD:/workspace" \
        -w /workspace \
        node:24-trixie-slim \
        bash -c "export PATH=/home/node/.npm-global/bin:\$PATH && npm install -g @anthropic-ai/claude-code && claude"
end
funcsave cldocker

echo ""
echo "Done! Run 'cldocker' from any project folder to start Claude Code."
