#!/usr/bin/env fish
# One-time setup script for odin-project (Node dev container for The Odin Project)
# Run this once with: fish odin-project-setup.fish
# Re-run it any time to update to the newest Node LTS.

# The container runs as user 'node' (UID 1000). Your project folder must be
# writable by that UID, so warn if your own UID is different.
if test (id -u) -ne 1000
    echo "WARNING: your UID is "(id -u)", not 1000. The container's 'node' user"
    echo "         may not be able to write to your project folder."
    echo ""
end

echo "Step 1: Building the odin-project image (Node LTS, git, ssh, openssl)..."
printf '%s\n' \
    'FROM node:lts-slim' \
    'RUN apt-get update && apt-get install -y --no-install-recommends openssl git ca-certificates openssh-client && rm -rf /var/lib/apt/lists/*' \
    'ENV NPM_CONFIG_PREFIX=/home/node/.npm-global PATH=/home/node/.npm-global/bin:$PATH' \
    'USER node' \
    'WORKDIR /workspace' \
    | docker build --pull -t odin-project -
or exit 1

echo "Step 2: Creating the odin-project-home volume and fixing its ownership..."
docker run --rm --user root \
    -v "odin-project-home:/home/node" \
    odin-project \
    chown -R 1000:1000 /home/node

echo "Step 3: Defining and saving the odin-project function..."
function odindocker
    docker run -it --rm \
        --network host \
        -v "odin-project-home:/home/node" \
        -v "$PWD:/workspace" \
        odin-project \
        bash
end
funcsave odindocker

echo ""
echo "Done! Run 'odin-project' from any project folder."
