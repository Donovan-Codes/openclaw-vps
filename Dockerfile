# =============================================================================
# OpenClaw Gateway — Docker Image
# =============================================================================
# Base image: official OpenClaw release from GitHub Container Registry.
# All dependencies are installed at BUILD TIME per the Docker VM Runtime docs.
# Nothing is installed at runtime — containers are ephemeral.
#
# Persistent state (config, sessions, auth tokens) lives in a named volume
# mounted at /home/node/.openclaw — see docker-compose.yml.
# =============================================================================

FROM ghcr.io/openclaw/openclaw:latest

# Install extra OS-level tools at build time
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Switch back to the unprivileged node user that OpenClaw expects
USER node

# Control UI + gateway API port
EXPOSE 18789
