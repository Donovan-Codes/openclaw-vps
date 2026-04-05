# =============================================================================
# Nginx — Reverse Proxy
# =============================================================================
# Supports two modes controlled by the DOMAIN env var in .env:
#
#   DOMAIN=         (empty) → generates a self-signed cert at build time
#   DOMAIN=your.domain.com → uses Let's Encrypt cert from /etc/letsencrypt
#
# The nginx.conf.template uses ${DOMAIN} placeholders which are substituted
# at container startup by the official nginx envsubst entrypoint.
# =============================================================================

FROM nginx:alpine

RUN apk add --no-cache openssl && \
    mkdir -p /etc/nginx/certs && \
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout /etc/nginx/certs/self.key \
      -out    /etc/nginx/certs/self.crt \
      -subj   "/CN=openclaw-vps/O=OpenClaw/C=US"

# Copy template — nginx entrypoint will run envsubst on startup
COPY nginx.conf.template /etc/nginx/templates/openclaw.conf.template

EXPOSE 80 443
