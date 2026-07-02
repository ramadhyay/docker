# Use a lightweight Node.js base image
FROM node:22-slim

# Install essential tools (Git is highly recommended for Claude Code)
RUN apt-get update && apt-get install -y \
    curl \
    git \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally via npm
RUN npm install -g @anthropic-ai/claude-code

# Switch to the non-root 'node' user
USER node

# Set the working directory
WORKDIR /workspace

# Launch into a standard bash terminal
CMD ["/bin/bash"]
