#!/usr/bin/env bash
# =============================================================================
# OpenClaw VPS — Hetzner Bootstrap
# =============================================================================
# Run this ONCE on a fresh Hetzner VPS (Ubuntu 22.04 or 24.04) as root.
#
# Usage:
#   ssh root@5.78.129.29
#   curl -fsSL https://raw.githubusercontent.com/Donovan-Codes/openclaw-vps/main/scripts/install-vps.sh | bash
#
# What this does:
#   1. Updates the system
#   2. Installs Docker Engine + Compose v2
#   3. Configures ufw firewall (SSH + HTTPS only)
#   4. Sets up Node compile cache for OpenClaw startup performance
#   5. Creates a non-root deploy user (optional)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[info]${RESET} $*"; }
success() { echo -e "${GREEN}[ok]${RESET}   $*"; }
die()     { echo -e "${RED}[error]${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}>>> $*${RESET}"; }

# Must run as root
[[ "$EUID" -eq 0 ]] || die "Run this script as root (or with sudo)"

header "1/5  System update"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
success "System up to date"

header "2/5  Install Docker Engine + Compose v2"
# Remove any old versions
apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install dependencies
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker apt repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker

success "Docker $(docker --version) installed"
success "Docker Compose $(docker compose version) installed"

header "3/5  Firewall (ufw)"
apt-get install -y -qq ufw

# Reset to defaults
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (don't lock yourself out)
ufw allow 22/tcp comment "SSH"

# Allow HTTP + HTTPS (Nginx handles these)
ufw allow 80/tcp comment "HTTP (redirect to HTTPS)"
ufw allow 443/tcp comment "HTTPS"

# OpenClaw gateway is on loopback only — block external access
# (This rule is redundant since we bind to 127.0.0.1, but explicit is better)
ufw deny 18789/tcp comment "OpenClaw gateway (loopback only)"

ufw --force enable
success "Firewall enabled"
ufw status verbose

header "4/5  Node compile cache"
# Speeds up OpenClaw gateway startup on repeated runs
CACHE_DIR="/var/tmp/openclaw-compile-cache"
mkdir -p "$CACHE_DIR"
chmod 777 "$CACHE_DIR"

# Persist across reboots via /etc/environment
if ! grep -q "NODE_COMPILE_CACHE" /etc/environment 2>/dev/null; then
    echo "NODE_COMPILE_CACHE=${CACHE_DIR}" >> /etc/environment
fi
success "NODE_COMPILE_CACHE=${CACHE_DIR}"

header "5/5  Done"
echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo "  git clone https://github.com/Donovan-Codes/openclaw-vps"
echo "  cd openclaw-vps"
echo "  ./setup.sh"
echo "  docker compose build"
echo "  docker compose run --rm --no-deps --entrypoint node openclaw-gateway \\"
echo "    dist/index.js onboard --mode local --no-install-daemon"
echo "  docker compose up -d"
echo ""
echo -e "${BOLD}Memory note:${RESET}"
echo "  If the build is killed (exit code 137), your VPS is out of memory."
echo "  Hetzner recommendation: 2–4 GB RAM minimum for the build step."
echo "  After the first build, a 2 GB server runs fine."
echo ""
success "Bootstrap complete"
