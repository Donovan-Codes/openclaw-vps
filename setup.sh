#!/usr/bin/env bash
# =============================================================================
# OpenClaw VPS — Interactive Setup
# =============================================================================
# Usage:
#   ./setup.sh          First-time setup or update existing .env
#   ./setup.sh --reset  Wipe .env and start fresh
#
# This script prompts for API keys and channel credentials, then writes them
# to a .env file with chmod 600 (owner-only). Nothing is printed to stdout
# after you type a secret — input is masked.
# =============================================================================

set -euo pipefail

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

# -- Colors -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[info]${RESET} $*"; }
success() { echo -e "${GREEN}[ok]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET} $*"; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }

# -- Helpers ------------------------------------------------------------------

# Prompt for a secret (masked input). Writes to $REPLY.
prompt_secret() {
    local prompt="$1"
    local current="$2"
    if [[ -n "$current" ]]; then
        echo -e "  ${prompt} ${YELLOW}[already set — press Enter to keep, or type new value]${RESET}"
    else
        echo -e "  ${prompt}"
    fi
    read -rs reply
    echo ""
    REPLY="$reply"
}

# Prompt for a plain (visible) value. Writes to $REPLY.
prompt_plain() {
    local prompt="$1"
    local current="$2"
    if [[ -n "$current" ]]; then
        echo -e "  ${prompt} ${YELLOW}[current: ${current}]${RESET}"
    else
        echo -e "  ${prompt}"
    fi
    read -r reply
    REPLY="$reply"
}

# Read current value of a key from .env (returns empty string if not set)
get_current() {
    local key="$1"
    if [[ -f "$ENV_FILE" ]]; then
        grep -E "^${key}=" "$ENV_FILE" | cut -d'=' -f2- || true
    fi
}

# Set a key=value in .env (creates or replaces the line)
set_env() {
    local key="$1"
    local value="$2"
    if [[ -f "$ENV_FILE" ]] && grep -qE "^${key}=" "$ENV_FILE"; then
        # Replace existing line (portable sed)
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

# Ask a yes/no question. Returns 0 for yes, 1 for no.
ask_yn() {
    local prompt="$1"
    local default="${2:-n}"
    local yn_hint
    if [[ "$default" == "y" ]]; then yn_hint="[Y/n]"; else yn_hint="[y/N]"; fi
    echo -e "  ${prompt} ${yn_hint}"
    read -r yn
    yn="${yn:-$default}"
    [[ "$yn" =~ ^[Yy] ]]
}

# =============================================================================
# Main
# =============================================================================

echo ""
echo -e "${BOLD}====================================================${RESET}"
echo -e "${BOLD}   OpenClaw VPS — Setup${RESET}"
echo -e "${BOLD}====================================================${RESET}"
echo ""

# -- Reset flag ---------------------------------------------------------------
if [[ "${1:-}" == "--reset" ]]; then
    warn "--reset flag detected. Removing existing .env..."
    rm -f "$ENV_FILE"
fi

# -- Bootstrap .env from example if it doesn't exist -------------------------
if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f "$ENV_EXAMPLE" ]]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        info "Created .env from .env.example"
    else
        touch "$ENV_FILE"
        info "Created empty .env"
    fi
fi
chmod 600 "$ENV_FILE"

# =============================================================================
# SECTION 1: Gateway Token
# =============================================================================
header "1/4  Gateway Token"
echo "  This token protects your OpenClaw dashboard."
echo "  Set a strong passphrase. If left empty, one will be auto-generated on first start."
echo ""

current_token=$(get_current "OPENCLAW_GATEWAY_TOKEN")
prompt_secret "Gateway token (passphrase):" "$current_token"
if [[ -n "$REPLY" ]]; then
    set_env "OPENCLAW_GATEWAY_TOKEN" "$REPLY"
    success "Gateway token set."
elif [[ -z "$current_token" ]]; then
    warn "No token set — OpenClaw will auto-generate one and print it to the logs."
fi

# =============================================================================
# SECTION 2: LLM Provider API Keys
# =============================================================================
header "2/4  LLM Provider API Keys"
echo "  Press Enter to skip any provider you don't use."
echo "  Input is masked — your keys will not be displayed."
echo ""

# -- Anthropic (Claude) -------------------------------------------------------
info "Anthropic (Claude) — https://console.anthropic.com/"
current=$(get_current "ANTHROPIC_API_KEY")
prompt_secret "  ANTHROPIC_API_KEY:" "$current"
[[ -n "$REPLY" ]] && set_env "ANTHROPIC_API_KEY" "$REPLY" && success "Anthropic key set."
[[ -z "$REPLY" && -n "$current" ]] && success "Anthropic key unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "Anthropic key skipped."

# -- Groq ---------------------------------------------------------------------
info "Groq — https://console.groq.com/"
current=$(get_current "GROQ_API_KEY")
prompt_secret "  GROQ_API_KEY:" "$current"
[[ -n "$REPLY" ]] && set_env "GROQ_API_KEY" "$REPLY" && success "Groq key set."
[[ -z "$REPLY" && -n "$current" ]] && success "Groq key unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "Groq key skipped."

# -- Google Gemini ------------------------------------------------------------
info "Google Gemini — https://aistudio.google.com/app/apikey"
current=$(get_current "GOOGLE_API_KEY")
prompt_secret "  GOOGLE_API_KEY:" "$current"
[[ -n "$REPLY" ]] && set_env "GOOGLE_API_KEY" "$REPLY" && success "Gemini key set."
[[ -z "$REPLY" && -n "$current" ]] && success "Gemini key unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "Gemini key skipped."

# -- OpenAI -------------------------------------------------------------------
info "OpenAI (GPT-4o, o1, etc.) — https://platform.openai.com/api-keys"
current=$(get_current "OPENAI_API_KEY")
prompt_secret "  OPENAI_API_KEY:" "$current"
[[ -n "$REPLY" ]] && set_env "OPENAI_API_KEY" "$REPLY" && success "OpenAI key set."
[[ -z "$REPLY" && -n "$current" ]] && success "OpenAI key unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "OpenAI key skipped."

# -- OpenRouter ---------------------------------------------------------------
info "OpenRouter (100+ models via one key) — https://openrouter.ai/keys"
current=$(get_current "OPENROUTER_API_KEY")
prompt_secret "  OPENROUTER_API_KEY:" "$current"
[[ -n "$REPLY" ]] && set_env "OPENROUTER_API_KEY" "$REPLY" && success "OpenRouter key set."
[[ -z "$REPLY" && -n "$current" ]] && success "OpenRouter key unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "OpenRouter key skipped."

# -- Mistral ------------------------------------------------------------------
info "Mistral AI — https://console.mistral.ai/"
current=$(get_current "MISTRAL_API_KEY")
prompt_secret "  MISTRAL_API_KEY:" "$current"
[[ -n "$REPLY" ]] && set_env "MISTRAL_API_KEY" "$REPLY" && success "Mistral key set."
[[ -z "$REPLY" && -n "$current" ]] && success "Mistral key unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "Mistral key skipped."

# -- Cohere -------------------------------------------------------------------
info "Cohere — https://dashboard.cohere.com/api-keys"
current=$(get_current "COHERE_API_KEY")
prompt_secret "  COHERE_API_KEY:" "$current"
[[ -n "$REPLY" ]] && set_env "COHERE_API_KEY" "$REPLY" && success "Cohere key set."
[[ -z "$REPLY" && -n "$current" ]] && success "Cohere key unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "Cohere key skipped."

# -- Together AI --------------------------------------------------------------
info "Together AI — https://api.together.xyz/settings/api-keys"
current=$(get_current "TOGETHER_API_KEY")
prompt_secret "  TOGETHER_API_KEY:" "$current"
[[ -n "$REPLY" ]] && set_env "TOGETHER_API_KEY" "$REPLY" && success "Together AI key set."
[[ -z "$REPLY" && -n "$current" ]] && success "Together AI key unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "Together AI key skipped."

# -- Ollama -------------------------------------------------------------------
info "Ollama (local models — no API key, just a URL)"
echo "  Leave empty to skip. Example: http://host.docker.internal:11434"
current=$(get_current "OLLAMA_BASE_URL")
prompt_plain "  OLLAMA_BASE_URL:" "$current"
[[ -n "$REPLY" ]] && set_env "OLLAMA_BASE_URL" "$REPLY" && success "Ollama URL set."
[[ -z "$REPLY" && -n "$current" ]] && success "Ollama URL unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "Ollama skipped."

# =============================================================================
# SECTION 3: Messaging Channels
# =============================================================================
header "3/4  Messaging Channels"
echo "  Telegram is enabled by default. Other channels are opt-in."
echo ""

# -- Telegram -----------------------------------------------------------------
info "Telegram (enabled by default)"
echo "  To create a bot: open Telegram → message @BotFather → /newbot"
echo "  Token format: 123456789:ABCdef..."
current=$(get_current "TELEGRAM_BOT_TOKEN")
prompt_secret "  TELEGRAM_BOT_TOKEN:" "$current"
[[ -n "$REPLY" ]] && set_env "TELEGRAM_BOT_TOKEN" "$REPLY" && success "Telegram token set."
[[ -z "$REPLY" && -n "$current" ]] && success "Telegram token unchanged."
[[ -z "$REPLY" && -z "$current" ]] && warn "Telegram token skipped. The Telegram channel will be disabled until you add one."

# -- Optional channels --------------------------------------------------------
echo ""
if ask_yn "Do you want to configure additional channels (Discord, Slack, WhatsApp)?"; then

    # Discord
    echo ""
    if ask_yn "  Enable Discord?"; then
        info "Discord — create a bot at https://discord.com/developers/applications"
        current=$(get_current "DISCORD_BOT_TOKEN")
        prompt_secret "    DISCORD_BOT_TOKEN:" "$current"
        [[ -n "$REPLY" ]] && set_env "DISCORD_BOT_TOKEN" "$REPLY" && success "Discord token set."
        [[ -z "$REPLY" && -n "$current" ]] && success "Discord token unchanged."
        warn "Remember to uncomment the Discord block in config/gateway.yml.template"
    fi

    # Slack
    echo ""
    if ask_yn "  Enable Slack?"; then
        info "Slack — create an app with Socket Mode at https://api.slack.com/apps"
        current=$(get_current "SLACK_APP_TOKEN")
        prompt_secret "    SLACK_APP_TOKEN (xapp-...):" "$current"
        [[ -n "$REPLY" ]] && set_env "SLACK_APP_TOKEN" "$REPLY" && success "Slack app token set."
        [[ -z "$REPLY" && -n "$current" ]] && success "Slack app token unchanged."

        current=$(get_current "SLACK_BOT_TOKEN")
        prompt_secret "    SLACK_BOT_TOKEN (xoxb-...):" "$current"
        [[ -n "$REPLY" ]] && set_env "SLACK_BOT_TOKEN" "$REPLY" && success "Slack bot token set."
        [[ -z "$REPLY" && -n "$current" ]] && success "Slack bot token unchanged."
        warn "Remember to uncomment the Slack block in config/gateway.yml.template"
    fi

    # WhatsApp
    echo ""
    if ask_yn "  Enable WhatsApp?"; then
        info "WhatsApp uses QR code login — no token needed here."
        echo "  After the gateway starts, run:"
        echo "    docker compose run --rm openclaw-cli channels login --channel whatsapp"
        warn "Remember to uncomment the WhatsApp block in config/gateway.yml.template"
    fi
fi

# =============================================================================
# SECTION 4: Summary
# =============================================================================
header "4/4  Summary"
echo ""

print_status() {
    local key="$1"
    local label="$2"
    local val
    val=$(get_current "$key")
    if [[ -n "$val" ]]; then
        echo -e "  ${GREEN}✓${RESET} ${label}"
    else
        echo -e "  ${YELLOW}-${RESET} ${label} (not set)"
    fi
}

echo "  Gateway:"
print_status "OPENCLAW_GATEWAY_TOKEN" "Gateway token"

echo ""
echo "  LLM Providers:"
print_status "ANTHROPIC_API_KEY"  "Anthropic (Claude)"
print_status "GROQ_API_KEY"       "Groq"
print_status "GOOGLE_API_KEY"     "Google Gemini"
print_status "OPENAI_API_KEY"     "OpenAI"
print_status "OPENROUTER_API_KEY" "OpenRouter"
print_status "MISTRAL_API_KEY"    "Mistral AI"
print_status "COHERE_API_KEY"     "Cohere"
print_status "TOGETHER_API_KEY"   "Together AI"
print_status "OLLAMA_BASE_URL"    "Ollama"

echo ""
echo "  Channels:"
print_status "TELEGRAM_BOT_TOKEN" "Telegram"
print_status "DISCORD_BOT_TOKEN"  "Discord"
print_status "SLACK_APP_TOKEN"    "Slack"

echo ""
echo -e "  .env written to ${BOLD}${ENV_FILE}${RESET} (chmod 600)"
echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo "  docker compose build"
echo "  docker compose run --rm --no-deps --entrypoint node openclaw-gateway \\"
echo "    dist/index.js onboard --mode local --no-install-daemon"
echo "  docker compose up -d"
echo ""
echo "  Dashboard: https://5.78.129.29"
echo "  Health:    curl -fsSk https://5.78.129.29/healthz"
echo ""
