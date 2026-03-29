#!/usr/bin/env bash
# =============================================================================
# OpenClaw VPS — Update Script
# =============================================================================
# Pulls the latest OpenClaw image, rebuilds, and restarts with zero downtime.
#
# Usage:  ./scripts/update.sh
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[info]${RESET} $*"; }
success() { echo -e "${GREEN}[ok]${RESET}   $*"; }

# Must be run from the repo root
cd "$(dirname "$0")/.."

info "Pulling latest OpenClaw base image..."
docker pull ghcr.io/openclaw/openclaw:latest

info "Rebuilding local image..."
docker compose build --no-cache

info "Restarting services..."
docker compose up -d --force-recreate

success "Update complete"
echo ""
docker compose ps
