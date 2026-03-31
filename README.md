# OpenClaw VPS

Self-hosted [OpenClaw](https://docs.openclaw.ai) AI gateway on a Hetzner VPS, running in Docker behind an Nginx reverse proxy with HTTPS.

**Dashboard**: `https://openclaw.yourdomain.com` (replace with your subdomain)

---

## What's included

| File | Purpose |
|---|---|
| `Dockerfile` | Extends the official OpenClaw image; installs extras at build time |
| `docker-compose.yml` | Orchestrates `openclaw-gateway` + `nginx` |
| `setup.sh` | Interactive guided setup — prompts for all API keys and channel tokens |
| `config/gateway.yml.template` | Gateway config with `${ENV_VAR}` substitution; channels toggled here |
| `nginx/` | Reverse proxy — self-signed TLS by default, swap for Let's Encrypt (see below) |
| `scripts/install-vps.sh` | One-time Hetzner bootstrap: Docker, ufw firewall, compile cache |
| `scripts/update.sh` | Pull latest OpenClaw image and restart |

---

## DNS Setup

Point `openclaw.yourdomain.com` at your VPS before going public:

1. Log in to your domain registrar / DNS provider
2. Add a new **A record**:
   - **Host / Name**: `openclaw`
   - **Value / Data**: `<YOUR_VPS_IP>`
   - **TTL**: 3600
3. DNS propagation typically takes 5–30 minutes.

Verify:
```bash
dig openclaw.yourdomain.com +short
# Should return your VPS IP
```

---

## First-time VPS setup

SSH into the server and run the bootstrap script:

```bash
ssh root@<YOUR_VPS_IP>
curl -fsSL https://raw.githubusercontent.com/Donovan-Codes/openclaw-vps/main/scripts/install-vps.sh | bash
```

This installs Docker Engine + Compose v2, configures the ufw firewall (SSH + port 443 open; port 18789 blocked from the internet), and sets up the Node compile cache for faster gateway startup.

---

## Deploying OpenClaw

```bash
# 1. Clone the repo onto the VPS
git clone https://github.com/Donovan-Codes/openclaw-vps
cd openclaw-vps

# 2. Run interactive setup — enter API keys + Telegram bot token
./setup.sh

# 3. Build the Docker images
#    NOTE: requires at least 2 GB RAM. If the build dies with exit code 137,
#    the VPS is out of memory — upgrade temporarily for the first build.
docker compose build

# 4. One-time onboarding (first time only)
docker compose run --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js onboard --mode local --no-install-daemon

# 5. Set gateway bind so Nginx can reach it over the Docker network
docker compose run --rm --entrypoint node openclaw-gateway \
  dist/index.js config set gateway.bind lan

# 6. Allow your VPS IP as a trusted origin for the Control UI
docker compose run --rm --entrypoint node openclaw-gateway \
  dist/index.js config set gateway.controlUi.allowedOrigins '["https://<YOUR_VPS_IP>"]'

# 7. Start everything
docker compose up -d
```

---

## Accessing the dashboard

Open `https://openclaw.yourdomain.com` in your browser.

If DNS is not yet live, you can access via IP directly — your browser will show a self-signed cert warning. Click **Advanced → Proceed** to continue.

Enter your gateway token when prompted. To retrieve it later:
```bash
docker compose run --rm --entrypoint node openclaw-gateway dist/index.js dashboard --no-open
```

Health check:
```bash
curl -fsSk https://openclaw.yourdomain.com/healthz
```

---

## Switching to Let's Encrypt (real HTTPS)

Once your subdomain's DNS is pointed at your VPS:

```bash
# On the VPS host (not inside a container)
apt-get install -y certbot python3-certbot-nginx

# Stop nginx container so certbot can bind port 80
docker compose stop nginx

# Obtain the certificate
certbot certonly --standalone -d openclaw.yourdomain.com
# Cert stored at: /etc/letsencrypt/live/openclaw.yourdomain.com/
```

Update `nginx/nginx.conf` — replace the self-signed cert lines:
```nginx
# Replace:
ssl_certificate     /etc/nginx/certs/self.crt;
ssl_certificate_key /etc/nginx/certs/self.key;

# With:
ssl_certificate     /etc/letsencrypt/live/openclaw.yourdomain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/openclaw.yourdomain.com/privkey.pem;
```

Also update `server_name _` → `server_name openclaw.yourdomain.com` in `nginx/nginx.conf`.

Mount the Let's Encrypt directory into the Nginx container in `docker-compose.yml`:
```yaml
nginx:
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/conf.d/openclaw.conf:ro
    - /etc/letsencrypt:/etc/letsencrypt:ro
```

Restart Nginx and enable auto-renewal:
```bash
docker compose up -d nginx
systemctl enable --now certbot.timer
```

---

## Adding or changing API keys

Re-run `setup.sh` at any time — it skips keys you leave blank and preserves existing values:

```bash
./setup.sh
docker compose up -d   # restart to pick up changes
```

---

## LLM providers supported

| Provider | Env var | Get key |
|---|---|---|
| Anthropic (Claude) | `ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com) |
| Groq | `GROQ_API_KEY` | [console.groq.com](https://console.groq.com) |
| Google Gemini | `GOOGLE_API_KEY` | [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| OpenAI | `OPENAI_API_KEY` | [platform.openai.com](https://platform.openai.com/api-keys) |
| OpenRouter | `OPENROUTER_API_KEY` | [openrouter.ai](https://openrouter.ai/keys) |
| Mistral AI | `MISTRAL_API_KEY` | [console.mistral.ai](https://console.mistral.ai) |
| Cohere | `COHERE_API_KEY` | [dashboard.cohere.com](https://dashboard.cohere.com/api-keys) |
| Together AI | `TOGETHER_API_KEY` | [api.together.xyz](https://api.together.xyz/settings/api-keys) |
| Ollama (local) | `OLLAMA_BASE_URL` | No key — URL to your running Ollama instance |

---

## Messaging channels

Telegram is **enabled by default**. All others are opt-in — uncomment the relevant block in `config/gateway.yml.template` and add credentials via `setup.sh`.

### Telegram
1. Open Telegram → message `@BotFather`
2. Send `/newbot` and follow the prompts
3. Copy the token → run `./setup.sh` and paste it when prompted

### Discord
1. Create a bot at [discord.com/developers/applications](https://discord.com/developers/applications)
2. Enable the **MESSAGE CONTENT** intent
3. Set `DISCORD_BOT_TOKEN` in `.env`
4. Uncomment the `discord` block in `config/gateway.yml.template`

### Slack
1. Create an app with Socket Mode at [api.slack.com/apps](https://api.slack.com/apps)
2. Subscribe to the required bot events (listed in `config/gateway.yml.template`)
3. Set `SLACK_APP_TOKEN` and `SLACK_BOT_TOKEN` in `.env`
4. Uncomment the `slack` block in `config/gateway.yml.template`

### WhatsApp
No token needed — uses QR code login:
```bash
docker compose run --rm --entrypoint node openclaw-gateway dist/index.js channels login --channel whatsapp
```
Sessions are stored in the `openclaw-data` Docker volume and survive container restarts.

---

## Enabling Ollama (local model inference)

1. Uncomment the `ollama` service block in `docker-compose.yml`
2. Set `OLLAMA_BASE_URL=http://ollama:11434` in `.env`
3. Uncomment the `ollama` provider block in `config/gateway.yml.template`
4. Rebuild and restart: `docker compose up -d --build`

Pull a model:
```bash
docker compose exec ollama ollama pull llama3
```

---

## Updates

```bash
./scripts/update.sh
```

---

## Troubleshooting

**Build killed / exit code 137** — VPS ran out of memory. Requires 2 GB RAM minimum for the build step. Upgrade the Hetzner server temporarily, run the build, then downsize.

**Gateway not starting**
```bash
docker compose logs openclaw-gateway
```

**Dashboard unreachable**
```bash
docker compose ps        # are containers running?
docker compose logs nginx
ufw status               # is port 443 open?
```

**Re-run onboarding**
```bash
docker compose run --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js onboard --mode local --no-install-daemon
```

**Permission denied on `/home/node/.openclaw`** — the volume was created with root ownership. Fix with:
```bash
docker compose run --rm --user root openclaw-gateway chown -R node:node /home/node/.openclaw
```
Then re-run onboarding.
