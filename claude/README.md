# Claude Code in Container

You can run the cldocker-setup.fish file, but this readme provides a list of commands. The container is based on `nodejs` version `24` which is an `LTS` version.

## Running the Setup Script

Run the following script which creates a container and sets up the `cldocker` function.

```shell
fish cldocker-setup.fish
```

## Manual Setup

### Creating the Container

The command will create a container, change permission of the volume as docker volumes are created as root-owned. The permission is changed and is handed over.

```shell
docker run --rm \
    -v "claude-npm-global:/home/node/.npm-global" \
    node:24-trixie-slim \
    chown -R 1000:1000 /home/node/.npm-global
```

### Create a Fish Function

This will create a function in `fish`. Type the following commands in fish shell

```shell
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
```

You should see a message something like

`funcsave: wrote /home/ram/.config/fish/functions/cldocker.fish`

### Running the Container

Just run below command from fish shell from the workspace

```shell
cldocker
```
