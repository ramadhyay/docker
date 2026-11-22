# README

## Setup
AIDOCKER_PUBKEY=~/.ssh/ramadhyay.pub fish aidocker-setup.fish

## Commands
*aidocker* opens a shell in this folder's container, creating it if needed.
*aidocker stop* stops this folder's container. Use it when you're done, to free RAM.
*aidocker rm* deletes this folder's container. Your project files and the volume are untouched, and the next aidocker makes a fresh one.
*aidocker ls* lists all your aidocker containers, with their status and project folder.
*aidocker update* updates the agents inside the volume.

## Output
```
npm warn using --force Recommended protections disabled.
Step 4: Authorizing your SSH public key for the container (for herdr)...
  Using /home/ram/.ssh/ramadhyay.pub
Step 5: Defining and saving the aidocker function...
funcsave: wrote /home/ram/.config/fish/functions/aidocker.fish
Step 6: Verifying versions...
  node    v24.22.3
  npm     11.19.1
  uv      uv 0.13.9 (x86_64-unknown-linux-musl)
  python
  claude  2.1.330 (Claude Code)
  codex   codex-cli 0.171.0
  gemini  0.70.0
  kiro    kiro-cli 3.5.0
  sshd    OpenSSH_10.0p2 Debian-7+deb13u4, OpenSSL 3.5.9 29 Sep 2026

Done! From any project folder run: aidocker
Inside the container, log in once per agent: claude, codex, gemini, kiro-cli login
Update agents later with: aidocker update

herdr: install the herdr desktop app on your host, then from a project folder:
  aidocker            (starts the container; sshd runs inside it)
  aidocker ssh-info   (shows the ~/.ssh/config block and 'hc machine add' command)
```

