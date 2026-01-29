#!/bin/bash
#
# Errordon Interactive Installer v1.2.0
# Guided installation wizard for Errordon
#
# Usage: curl -sSL https://raw.githubusercontent.com/error-wtf/errordon/master/deploy/interactive-install.sh -o install.sh && chmod +x install.sh && ./install.sh
#
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
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
echo "║          ERRORDON - Interactive Installer v1.2.0        ║"
echo "║      A Safe Fediverse: No Porn, No Hate, No Fascism     ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Features:                                               ║"
echo "║  • Matrix Terminal landing page (4 color themes)       ║"
echo "║  • Full-text search (OpenSearch)                        ║"
echo "║  • AI content moderation (Ollama)                       ║"
echo "║  • 250MB upload support                                 ║"
echo "║  • Privacy-first defaults                               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${CYAN}Documentation: https://github.com/error-wtf/errordon/blob/master/deploy/TUTORIALS.md${NC}"
echo ""

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
echo -e "\n${BLUE}━━━ STEP 4/6: Features ━━━${NC}"
echo -e "${GREEN}Matrix Terminal:${NC} Cyberpunk-style landing page with terminal interface"
read -p "Enable Matrix Terminal? (Y/n): " yn
[[ "$yn" =~ ^[Nn]$ ]] && INSTALL_MATRIX=false || INSTALL_MATRIX=true

# Matrix Color Selection (only if Matrix enabled)
if [ "$INSTALL_MATRIX" = true ]; then
    echo ""
    echo -e "${GREEN}Matrix Color Theme:${NC} Choose the color scheme for your Matrix UI"
    echo "  1) Green  - Classic Matrix (default)"
    echo "  2) Red    - Aggressive/Error theme"
    echo "  3) Blue   - Cyber/Tech theme"
    echo "  4) Purple - Cyberpunk theme"
    read -p "Select color [1-4, default=1]: " color_choice
    case "$color_choice" in
        2) MATRIX_COLOR="red" ;;
        3) MATRIX_COLOR="blue" ;;
        4) MATRIX_COLOR="purple" ;;
        *) MATRIX_COLOR="green" ;;
    esac
    log "Matrix color: $MATRIX_COLOR"
else
    MATRIX_COLOR="green"
fi

echo -e "${GREEN}Ollama AI:${NC} NSFW-Protect AI moderation (requires 8GB+ RAM)"
read -p "Install Ollama for AI content moderation? (y/N): " yn
[[ "$yn" =~ ^[Yy]$ ]] && INSTALL_OLLAMA=true || INSTALL_OLLAMA=false

# STEP 5: Confirm
echo -e "\n${BLUE}━━━ STEP 6/6: Confirm ━━━${NC}"
echo "Domain:       $DOMAIN"
echo "Admin:        $ADMIN_USER <$ADMIN_EMAIL>"
echo "SMTP:         ${SMTP_SERVER:-not configured}"
echo "Matrix:       $INSTALL_MATRIX"
[ "$INSTALL_MATRIX" = true ] && echo "Matrix Color: $MATRIX_COLOR"
echo "Ollama/AI:    $INSTALL_OLLAMA"
echo ""
read -p "Start installation? (Y/n): " yn
[[ "$yn" =~ ^[Nn]$ ]] && { echo "Cancelled."; exit 0; }

# Run quick-install with collected params
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARGS="--domain $DOMAIN --email $ADMIN_EMAIL"
[ "$INSTALL_MATRIX" = true ] && ARGS="$ARGS --with-matrix --matrix-color $MATRIX_COLOR"
[ "$INSTALL_OLLAMA" = true ] && ARGS="$ARGS --with-ollama"

export ADMIN_USER ADMIN_EMAIL SMTP_SERVER SMTP_PORT SMTP_LOGIN SMTP_PASSWORD SMTP_FROM MATRIX_COLOR

# Always download fresh quick-install.sh to avoid cache issues
echo ""
log "Downloading latest installer..."
if ! curl -sSL "https://raw.githubusercontent.com/error-wtf/errordon/master/deploy/quick-install.sh?v=$(date +%s)" -o /tmp/quick-install.sh; then
    error "Failed to download installer. Check your internet connection."
fi
chmod +x /tmp/quick-install.sh

echo ""
echo -e "${GREEN}━━━ Starting Installation ━━━${NC}"
echo "This will take 20-40 minutes. You can watch the progress below."
echo ""

bash /tmp/quick-install.sh $ARGS

# Cleanup
rm -f /tmp/quick-install.sh
