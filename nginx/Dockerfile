# =============================================================================
# Nginx — Reverse Proxy with Self-Signed TLS
# =============================================================================
# Generates a 10-year self-signed certificate at BUILD TIME.
# Your browser will show an "untrusted" warning — that's expected for self-signed.
# Click through it (or add a permanent exception).
#
# When you add a domain, replace this with Certbot + Let's Encrypt:
#   https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal
# =============================================================================

FROM nginx:alpine

RUN apk add --no-cache openssl && \
    mkdir -p /etc/nginx/certs && \
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout /etc/nginx/certs/self.key \
      -out    /etc/nginx/certs/self.crt \
      -subj   "/CN=openclaw-vps/O=OpenClaw/C=US"

EXPOSE 80 443
