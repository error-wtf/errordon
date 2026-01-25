#!/bin/bash
# Errordon Interactive Installer
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Docker Compose detection - check exit code AND version pattern
dc() {
    if docker compose version &> /dev/null && docker compose version 2>&1 | grep -qE "v[0-9]+\.[0-9]+"; then
        docker compose "$@"
    elif command -v docker-compose &> /dev/null && docker-compose version &> /dev/null; then
        docker-compose "$@"
    else
        error "Docker Compose not found!"
    fi
}

clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          ERRORDON - Interactive Installer                ║"
echo "║      A Safe Fediverse: No Porn, No Hate, No Fascism      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check not root
[ "$EUID" -eq 0 ] && error "Don't run as root. Use a normal user with sudo."

# STEP 1: Domain
echo -e "${BLUE}━━━ STEP 1/5: Domain ━━━${NC}"
read -p "Enter your domain (e.g. social.example.com): " DOMAIN
[ -z "$DOMAIN" ] && error "Domain required!"
log "Domain: $DOMAIN"

# STEP 2: Admin
echo -e "\n${BLUE}━━━ STEP 2/5: Admin Account ━━━${NC}"
read -p "Admin username [admin]: " ADMIN_USER; ADMIN_USER=${ADMIN_USER:-admin}
read -p "Admin email [admin@$DOMAIN]: " ADMIN_EMAIL; ADMIN_EMAIL=${ADMIN_EMAIL:-admin@$DOMAIN}
log "Admin: $ADMIN_USER <$ADMIN_EMAIL>"

# STEP 3: SMTP
echo -e "\n${BLUE}━━━ STEP 3/5: Email (SMTP) ━━━${NC}"
echo "Errordon needs SMTP to send emails. Leave blank to skip."
read -p "SMTP Server (e.g. smtp.mailgun.org): " SMTP_SERVER
if [ -n "$SMTP_SERVER" ]; then
    read -p "SMTP Port [587]: " SMTP_PORT; SMTP_PORT=${SMTP_PORT:-587}
    read -p "SMTP Username: " SMTP_LOGIN
    read -sp "SMTP Password: " SMTP_PASSWORD; echo ""
    read -p "From Address [noreply@$DOMAIN]: " SMTP_FROM; SMTP_FROM=${SMTP_FROM:-noreply@$DOMAIN}
    log "SMTP configured: $SMTP_SERVER:$SMTP_PORT"
else
    warn "SMTP skipped - configure later in .env.production"
fi

# STEP 4: Features
echo -e "\n${BLUE}━━━ STEP 4/5: Features ━━━${NC}"
read -p "Enable Matrix Terminal landing page? (Y/n): " yn
[[ "$yn" =~ ^[Nn]$ ]] && INSTALL_MATRIX=false || INSTALL_MATRIX=true

read -p "Install Ollama for AI content moderation? (y/N): " yn
[[ "$yn" =~ ^[Yy]$ ]] && INSTALL_OLLAMA=true || INSTALL_OLLAMA=false

# STEP 5: Confirm
echo -e "\n${BLUE}━━━ STEP 5/5: Confirm ━━━${NC}"
echo "Domain:       $DOMAIN"
echo "Admin:        $ADMIN_USER <$ADMIN_EMAIL>"
echo "SMTP:         ${SMTP_SERVER:-not configured}"
echo "Matrix:       $INSTALL_MATRIX"
echo "Ollama/AI:    $INSTALL_OLLAMA"
echo ""
read -p "Start installation? (Y/n): " yn
[[ "$yn" =~ ^[Nn]$ ]] && { echo "Cancelled."; exit 0; }

# Run quick-install with collected params
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARGS="--domain $DOMAIN --email $ADMIN_EMAIL"
[ "$INSTALL_MATRIX" = true ] && ARGS="$ARGS --with-matrix"
[ "$INSTALL_OLLAMA" = true ] && ARGS="$ARGS --with-ollama"

export ADMIN_USER ADMIN_EMAIL SMTP_SERVER SMTP_PORT SMTP_LOGIN SMTP_PASSWORD SMTP_FROM

# Always download fresh quick-install.sh to avoid cache issues
curl -sSL "https://raw.githubusercontent.com/error-wtf/errordon/master/deploy/quick-install.sh?nocache=$(date +%s)" -o /tmp/quick-install.sh
bash /tmp/quick-install.sh $ARGS
