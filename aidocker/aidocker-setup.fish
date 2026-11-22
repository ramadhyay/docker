#!/usr/bin/env fish
# One-time setup for aidocker: a sandbox container for AI coding agents.
#   Agents:  Claude Code, Codex, Gemini CLI (npm) and Kiro CLI (official installer)
#   Runtime: Node 24 + npm, uv (Python is managed by uv and lives in a volume)
#   Remote:  unprivileged sshd inside the container so the herdr desktop app
#            (on the host) can connect over SSH and run herdr-core in it.
#   Storage: ONE named volume (aidocker-home) mounted at /home/node holds agent
#            logins/config, global npm packages, the uv cache, uv-managed Pythons,
#            the SSH host key, authorized_keys and (once installed) herdr itself.
#            Nothing is written to your host except your project folder.
#
# Run once:   fish aidocker-setup.fish
# Re-run any time to rebuild the image and refresh the agents.
#
# Usage after setup (run from a project folder):
#   aidocker           start (or reuse) this project's container and open a shell
#   aidocker ssh-info  print the ~/.ssh/config block + herdr command for this project
#   aidocker stop      stop this project's container
#   aidocker rm        remove this project's container (volume and project untouched)
#   aidocker ls        list aidocker containers (with their SSH ports)
#   aidocker update    update agents/uv Python inside the volume
#
# NOTE: containers created by an older version of this script have no sshd and no
# published port. Run "aidocker rm" in each project once to recreate it.

set -l IMAGE aidocker:latest
set -l VOLUME aidocker-home

# The container user is 'node' (UID 1000). The volume is owned by that UID and the
# Wayland socket is only reachable by your own UID, so these should match.
if test (id -u) -ne 1000
    echo "WARNING: your UID is "(id -u)", not 1000. The volume is owned by UID 1000,"
    echo "         so the container user may not be able to write to it."
    echo ""
end

# Base is plain Debian trixie (no system Python: uv installs Python into the volume).
# Node 24 is copied from the official Node image; uv from Astral's image.
# NOTE: this is a fish single-quoted string, so the Dockerfile must not contain
# single quotes (use \" inside RUN lines instead).
set -l DOCKERFILE '
FROM node:24-trixie-slim AS node
FROM ghcr.io/astral-sh/uv:latest AS uv
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl unzip vim libstdc++6 wl-clipboard procps ripgrep openssh-server openssh-client \
 && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

COPY --from=uv /uv /uvx /usr/local/bin/

# Install/update helper, used by setup and by "aidocker update".
RUN printf "%s\n" "#!/bin/bash" "set -e" \
    "npm install -g --allow-scripts=@anthropic-ai/claude-code,@github/keytar @anthropic-ai/claude-code @openai/codex @google/gemini-cli" \
    "curl -fsSL https://cli.kiro.dev/install | KIRO_CLI_SKIP_SETUP=1 bash -s -- --force" \
    "npm cache clean --force" > /usr/local/bin/aidocker-update \
 && chmod +x /usr/local/bin/aidocker-update

# Unprivileged sshd (runs as node, listens on 2222, key-only, only user node).
# SetEnv gives SSH sessions (and so herdr panes) the same PATH/npm/uv settings as
# docker exec shells, since ENV from this Dockerfile is not passed through sshd.
RUN mkdir -p /run/sshd /etc/aidocker \
 && printf "%s\n" \
    "Port 2222" \
    "ListenAddress 0.0.0.0" \
    "HostKey /home/node/.ssh/host_ed25519" \
    "PidFile /home/node/.ssh/sshd.pid" \
    "AuthorizedKeysFile /home/node/.ssh/authorized_keys" \
    "AllowUsers node" \
    "PubkeyAuthentication yes" \
    "PasswordAuthentication no" \
    "KbdInteractiveAuthentication no" \
    "UsePAM no" \
    "X11Forwarding no" \
    "SetEnv PATH=/home/node/.npm-global/bin:/home/node/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin NPM_CONFIG_PREFIX=/home/node/.npm-global UV_PYTHON_PREFERENCE=only-managed UV_LINK_MODE=copy" \
    > /etc/aidocker/sshd_config

# Container entrypoint: create the SSH host key in the volume if missing, then run
# sshd in the foreground as the main process (replaces the old "sleep infinity").
RUN printf "%s\n" "#!/bin/bash" "set -e" \
    "mkdir -p /home/node/.ssh && chmod 700 /home/node/.ssh" \
    "[ -f /home/node/.ssh/host_ed25519 ] || ssh-keygen -q -t ed25519 -N \"\" -f /home/node/.ssh/host_ed25519" \
    "exec /usr/sbin/sshd -D -e -f /etc/aidocker/sshd_config" > /usr/local/bin/aidocker-init \
 && chmod +x /usr/local/bin/aidocker-init

# Directories are created here, owned by node, so Docker gives a new named volume
# the same ownership on first use (no chown step needed).
RUN useradd -m -u 1000 -s /bin/bash node \
 && mkdir -p /home/node/.npm-global /home/node/.local/bin /home/node/.cache/uv /home/node/.ssh /workspace \
 && chmod 700 /home/node/.ssh \
 && chown -R node:node /home/node /workspace

ENV HOME=/home/node \
    NPM_CONFIG_PREFIX=/home/node/.npm-global \
    PATH=/home/node/.npm-global/bin:/home/node/.local/bin:$PATH \
    UV_PYTHON_PREFERENCE=only-managed \
    UV_LINK_MODE=copy

USER node
WORKDIR /workspace
EXPOSE 2222
'

echo "Step 1: Building $IMAGE (Node 24, uv, sshd)..."
printf '%s\n' $DOCKERFILE | docker build --pull -t $IMAGE -; or begin
    echo "  Build failed. Is Docker running?"
    exit 1
end

echo "Step 2: Creating volume $VOLUME..."
docker volume create $VOLUME >/dev/null; or exit 1

echo "Step 3: Installing agents into the volume (takes a few minutes)..."
docker run --rm --user (id -u):(id -g) -v "$VOLUME:/home/node" $IMAGE aidocker-update; or begin
    echo "  Agent install failed. Re-run this script to retry."
    exit 1
end

echo "Step 4: Authorizing your SSH public key for the container (for herdr)..."
set -l pubkey
for f in ~/.ssh/id_ed25519.pub ~/.ssh/id_ecdsa.pub ~/.ssh/id_rsa.pub
    if test -f $f
        set pubkey $f
        break
    end
end
if test -z "$pubkey"
    echo "  No public key found in ~/.ssh (id_ed25519/id_ecdsa/id_rsa)."
    echo "  Create one with: ssh-keygen -t ed25519"
    echo "  then re-run this script."
    exit 1
end
echo "  Using $pubkey"
docker run --rm --user (id -u):(id -g) -v "$VOLUME:/home/node" \
    -v "$pubkey:/tmp/host.pub:ro" $IMAGE bash -c '
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat /tmp/host.pub >> ~/.ssh/authorized_keys
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
'; or begin
    echo "  Could not write authorized_keys."
    exit 1
end

echo "Step 5: Defining and saving the aidocker function..."
function aidocker
    set -l IMAGE aidocker:latest
    set -l VOLUME aidocker-home
    set -l cmd shell
    set -q argv[1]; and set cmd $argv[1]

    # One container per project folder: name = folder name + short hash of full path
    set -l base (basename $PWD | string replace -ra '[^A-Za-z0-9_.-]' '-')
    set -l hash (printf %s $PWD | md5sum | string sub -l 6)
    set -l name aidocker-$base-$hash
    # Stable per-project SSH port on 127.0.0.1 (2300-3299). Collisions are possible
    # but unlikely; if one happens, "docker run" fails with "port is already allocated".
    set -l port (math "0x$hash % 1000 + 2300")

    switch "$cmd"
        case update
            docker run --rm --user (id -u):(id -g) -v "$VOLUME:/home/node" $IMAGE aidocker-update
        case stop
            docker stop $name
        case rm
            docker rm -f $name
        case ls
            docker ps -a --filter 'name=^aidocker-' --format 'table {{.Names}}\t{{.Status}}\t{{.Label "aidocker.port"}}\t{{.Label "aidocker.workspace"}}'
        case ssh-info
            echo "# Add to ~/.ssh/config on your host:"
            echo "Host $name"
            echo "    HostName 127.0.0.1"
            echo "    Port $port"
            echo "    User node"
            echo ""
            echo "# Then (container must be running, see: aidocker):"
            echo "ssh $name"
            echo "hc machine add $name --label \"$base\""
        case '' shell
            set -l state (docker container inspect -f '{{.State.Running}}' $name 2>/dev/null)
            if test -z "$state"
                # Container does not exist yet: create it. Its main process is sshd
                # (aidocker-init), published on 127.0.0.1 only.
                set -l args run -d --init --name $name --hostname aidocker \
                    --label "aidocker.workspace=$PWD" \
                    --label "aidocker.port=$port" \
                    --user (id -u):(id -g) \
                    -p 127.0.0.1:$port:2222 \
                    -v "$VOLUME:/home/node" \
                    -v "$PWD:/workspace"
                # Wayland clipboard (wl-clipboard) support
                if set -q WAYLAND_DISPLAY; and test -n "$XDG_RUNTIME_DIR"
                    set -a args -e "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" -e "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
                        -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:ro"
                end
                docker $args $IMAGE aidocker-init >/dev/null; or return 1
            else if test "$state" = false
                docker start $name >/dev/null; or return 1
            end
            set -l eargs -it -e "TERM=$TERM"
            if set -q COLORTERM
                set -a eargs -e "COLORTERM=$COLORTERM"
            end
            docker exec $eargs $name bash
        case '*'
            echo "usage: aidocker [shell|ssh-info|stop|rm|ls|update]"
            return 1
    end
end
funcsave aidocker

echo "Step 6: Verifying versions..."
docker run --rm --user (id -u):(id -g) -v "$VOLUME:/home/node" $IMAGE bash -c '
echo "  node    $(node --version)"
echo "  npm     $(npm --version)"
echo "  uv      $(uv --version)"
echo "  python  $(uv python list --only-installed 2>/dev/null | head -n1)"
echo "  claude  $(claude --version 2>&1 | head -n1)"
echo "  codex   $(codex --version 2>&1 | head -n1)"
echo "  gemini  $(gemini --version 2>&1 | head -n1)"
echo "  kiro    $(kiro-cli --version 2>&1 | head -n1)"
echo "  sshd    $(/usr/sbin/sshd -V 2>&1 | head -n1)"
'

echo ""
echo "Done! From any project folder run: aidocker"
echo "Inside the container, log in once per agent: claude, codex, gemini, kiro-cli login"
echo "Update agents later with: aidocker update"
echo ""
echo "herdr: install the herdr desktop app on your host, then from a project folder:"
echo "  aidocker            (starts the container; sshd runs inside it)"
echo "  aidocker ssh-info   (shows the ~/.ssh/config block and 'hc machine add' command)"
