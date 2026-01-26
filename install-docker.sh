#!/bin/bash
# Errordon Docker Install v3.0 - Complete
set -euo pipefail
trap 'echo "[✗] Failed at line $LINENO"; exit 1' ERR

log(){ echo -e "\033[0;32m[✓]\033[0m $1"; }
warn(){ echo -e "\033[1;33m[⚠]\033[0m $1"; }
error(){ echo -e "\033[0;31m[✗]\033[0m $1"; exit 1; }

# Avoid `set -u` crashes if `read` fails (e.g., `curl | bash` without a TTY)
MATRIX_R=""
OLLAMA_R=""
CONFIRM=""

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║     Errordon Docker Installation v3.0         ║"
echo "║     Complete Setup with All Features          ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

[ "$EUID" -eq 0 ] && error "Don't run as root. Use: bash install-docker.sh"
if [ -r /dev/tty ] && [ -w /dev/tty ]; then
  exec </dev/tty >/dev/tty
fi

if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    exec 3</dev/tty
    exec 4>/dev/tty
else
    error "Interactive terminal required. Run: curl -fsSL https://raw.githubusercontent.com/error-wtf/errordon/main/install-docker.sh -o install-docker.sh && bash install-docker.sh"
fi

# When executed via `curl | bash`, stdin is not a TTY and `read` will fail.
# If /dev/tty is available, use it for interactive prompts.
if [ ! -t 0 ] && [ -r /dev/tty ]; then
    exec < /dev/tty || true
fi

# ══════════════════════════════════════════════════════════
# INTERACTIVE CONFIGURATION
# ══════════════════════════════════════════════════════════
echo "── Configuration ──────────────────────────────────────"
echo ""

read -p "[?] Domain (e.g., social.example.com): " DOMAIN
[ -z "$DOMAIN" ] && error "Domain is required"

read -p "[?] Admin Email: " EMAIL
[ -z "$EMAIL" ] && error "Email is required"

read -p "[?] Admin Username (default: admin): " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

echo ""
echo "── SMTP Configuration (for sending emails) ───────────"
read -p "[?] SMTP Server (empty to skip): " SMTP_SERVER
SMTP_PORT=""; SMTP_USER=""; SMTP_PASS=""
if [ -n "$SMTP_SERVER" ]; then
    read -p "    SMTP Port (default: 587): " SMTP_PORT
    SMTP_PORT=${SMTP_PORT:-587}
    read -p "    SMTP Username: " SMTP_USER
    read -s -p "    SMTP Password: " SMTP_PASS
    echo ""
fi

echo ""
MATRIX_R=""
read -p "[?] Install Matrix Terminal theme? (y/N): " -n1 MATRIX_R
echo ""
MATRIX_ENABLED=$([[ $MATRIX_R =~ ^[Yy]$ ]] && echo "true" || echo "false")

OLLAMA_R=""
read -p "[?] Install Ollama AI for NSFW moderation? (Y/n): " -n1 OLLAMA_R
echo ""
OLLAMA_ENABLED=$([[ ! $OLLAMA_R =~ ^[Nn]$ ]] && echo "true" || echo "false")

# Generate secrets
SECRET_KEY=$(openssl rand -hex 64)
OTP_SECRET=$(openssl rand -hex 64)
DB_PASS=$(openssl rand -hex 16)
# Active Record Encryption (required since Mastodon 4.x)
AR_ENCRYPTION_PRIMARY=$(openssl rand -base64 32)
AR_ENCRYPTION_DETERMINISTIC=$(openssl rand -base64 32)
AR_ENCRYPTION_SALT=$(openssl rand -base64 32)

echo ""
echo "── Summary ────────────────────────────────────────────"
echo "   Domain:       $DOMAIN"
echo "   Admin:        $ADMIN_USER ($EMAIL)"
echo "   SMTP:         ${SMTP_SERVER:-not configured}"
echo "   Matrix:       $MATRIX_ENABLED"
echo "   Ollama AI:    $OLLAMA_ENABLED"
echo ""
read -p "Continue? (Y/n): " -n1 CONFIRM
echo ""
[[ $CONFIRM =~ ^[Nn]$ ]] && { echo "Cancelled."; exit 0; }

# ══════════════════════════════════════════════════════════
# PHASE 1: INSTALL DOCKER
# ══════════════════════════════════════════════════════════
echo ""
log "Phase 1: Docker Setup"

if ! command -v docker &>/dev/null; then
    log "Installing Docker..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker.io docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"
    log "Docker installed - you may need to re-login for group changes"
else
    log "Docker already installed"
fi

# ══════════════════════════════════════════════════════════
# PHASE 2: CLONE REPOSITORY
# ══════════════════════════════════════════════════════════
log "Phase 2: Repository Setup"

INSTALL_DIR="$HOME/errordon"
if [ ! -d "$INSTALL_DIR" ]; then
    log "Cloning Errordon..."
    git clone https://github.com/error-wtf/errordon.git "$INSTALL_DIR"
else
    log "Repository exists, updating..."
    cd "$INSTALL_DIR" && git pull origin master || true
fi
cd "$INSTALL_DIR"

# ══════════════════════════════════════════════════════════
# PHASE 3: CREATE .env.production
# ══════════════════════════════════════════════════════════
log "Phase 3: Environment Configuration"

cat > .env.production << ENVFILE
# Errordon Configuration - Generated $(date)
LOCAL_DOMAIN=$DOMAIN
SINGLE_USER_MODE=false

# Security Keys
SECRET_KEY_BASE=$SECRET_KEY
OTP_SECRET=$OTP_SECRET

# Active Record Encryption (required since Mastodon 4.x)
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$AR_ENCRYPTION_PRIMARY
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$AR_ENCRYPTION_DETERMINISTIC
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$AR_ENCRYPTION_SALT

# Database
DB_HOST=db
DB_USER=mastodon
DB_NAME=mastodon_production
DB_PASS=$DB_PASS
DB_PORT=5432

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# SMTP
SMTP_SERVER=$SMTP_SERVER
SMTP_PORT=${SMTP_PORT:-587}
SMTP_LOGIN=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASS
SMTP_FROM_ADDRESS=${EMAIL}
SMTP_AUTH_METHOD=plain
SMTP_ENABLE_STARTTLS=auto

# Errordon Features
ERRORDON_PRIVACY_PRESET=standard
ERRORDON_SECURITY_STRICT=true
ERRORDON_NSFW_PROTECT_ENABLED=$OLLAMA_ENABLED
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://host.docker.internal:11434
ERRORDON_MATRIX_LANDING_ENABLED=$MATRIX_ENABLED
ERRORDON_INVITE_ONLY=false
ERRORDON_MAX_UPLOAD_SIZE_MB=100
ENVFILE

log ".env.production created"

# ══════════════════════════════════════════════════════════
# PHASE 4: INSTALL OLLAMA (if selected)
# ══════════════════════════════════════════════════════════
if [ "$OLLAMA_ENABLED" = "true" ]; then
    log "Phase 4: Ollama AI Setup"
    
    if ! command -v ollama &>/dev/null; then
        log "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    
    log "Pulling llava model (image analysis, ~4GB)..."
    ollama pull llava
    
    log "Pulling llama3 model (text analysis, ~4GB)..."
    ollama pull llama3
    
    sudo systemctl enable ollama 2>/dev/null || true
    sudo systemctl start ollama 2>/dev/null || true
    log "Ollama ready with AI models"
else
    warn "Skipping Ollama - NSFW-Protect disabled"
fi

# ══════════════════════════════════════════════════════════
# PHASE 5: START DOCKER CONTAINERS
# ══════════════════════════════════════════════════════════
log "Phase 5: Starting Services"

log "Starting database and redis..."
sudo docker compose up -d db redis
sleep 10

log "Ensuring PostgreSQL role/database exist..."
# Create role/database expected by Mastodon (.env.production uses DB_USER=mastodon)
sudo docker compose exec -T db sh -lc "psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'mastodon') THEN
    CREATE ROLE mastodon LOGIN PASSWORD '${DB_PASS}';
  END IF;
END
\$\$;

DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mastodon_production') THEN
    CREATE DATABASE mastodon_production OWNER mastodon;
  END IF;
END
\$\$;
SQL"

log "Setting up database..."
sudo docker compose run --rm web bundle exec rails db:setup RAILS_ENV=production 2>/dev/null || \
sudo docker compose run --rm web bundle exec rails db:migrate RAILS_ENV=production

log "Precompiling assets (this takes a while)..."
sudo docker compose run --rm web bundle exec rails assets:precompile RAILS_ENV=production

log "Starting all services..."
sudo docker compose up -d

# ══════════════════════════════════════════════════════════
# PHASE 6: CREATE ADMIN ACCOUNT
# ══════════════════════════════════════════════════════════
log "Phase 6: Creating Admin Account"

ADMIN_PASS=$(sudo docker compose run --rm web bin/tootctl accounts create "$ADMIN_USER" --email="$EMAIL" --confirmed --role=Owner 2>&1 | grep -oP 'New password: \K.*' || echo "")

# Save credentials
cat > admin_credentials.txt << CREDS
Errordon Admin Credentials
==========================
URL:      https://$DOMAIN
Username: $ADMIN_USER
Email:    $EMAIL
Password: $ADMIN_PASS

Created: $(date)
DELETE THIS FILE AFTER SAVING!
CREDS
chmod 600 admin_credentials.txt

# ══════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════
echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║     Installation Complete!                    ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
log "URL: https://$DOMAIN"
log "Admin: $ADMIN_USER"
log "Email: $EMAIL"
[ -n "$ADMIN_PASS" ] && log "Password: $ADMIN_PASS"
echo ""
warn "Credentials saved to: $INSTALL_DIR/admin_credentials.txt"
warn "DELETE after saving securely!"
echo ""
log "Next: Configure DNS to point $DOMAIN to this server"
log "Then: sudo docker compose exec web rails assets:precompile"
echo ""
