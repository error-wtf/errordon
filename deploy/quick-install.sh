#!/bin/bash
#
# Errordon Quick Install Script
# One-line VPS installer for Ubuntu 22.04
#
# Usage: curl -sSL https://raw.githubusercontent.com/error-wtf/errordon/main/deploy/quick-install.sh | bash -s -- --domain your.domain.com
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# Docker Compose wrapper - uses plugin or standalone
dc() {
    if docker compose version &> /dev/null; then
        docker compose "$@"
    elif command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        error "Docker Compose not found!"
    fi
}

# Parse arguments
DOMAIN=""
EMAIL=""
INSTALL_OLLAMA=false
INSTALL_MATRIX=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift 2 ;;
        --email) EMAIL="$2"; shift 2 ;;
        --with-ollama) INSTALL_OLLAMA=true; shift ;;
        --with-matrix) INSTALL_MATRIX=true; shift ;;
        --help) 
            echo "Errordon Quick Installer"
            echo ""
            echo "Usage: $0 --domain your.domain.com [options]"
            echo ""
            echo "Options:"
            echo "  --domain DOMAIN    Your domain (required)"
            echo "  --email EMAIL      Admin email for SSL and alerts"
            echo "  --with-ollama      Install Ollama for NSFW-Protect AI"
            echo "  --with-matrix      Enable Matrix theme"
            echo ""
            exit 0
            ;;
        *) shift ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo ""
    read -p "Enter your domain (e.g., social.example.com): " DOMAIN
fi

if [ -z "$DOMAIN" ]; then
    error "Domain is required. Use: $0 --domain your.domain.com"
fi

if [ -z "$EMAIL" ]; then
    EMAIL="admin@$DOMAIN"
fi

# Admin account setup (use env vars if set, otherwise ask)
if [ -z "$ADMIN_USER" ]; then
    echo ""
    read -p "Admin username (default: admin): " ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-admin}
fi

if [ -z "$ADMIN_EMAIL" ]; then
    read -p "Admin email (default: $EMAIL): " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-$EMAIL}
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Errordon Quick Installer                         ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  Domain: $DOMAIN"
echo "║  Admin:  $ADMIN_USER <$ADMIN_EMAIL>"
[ -n "$SMTP_SERVER" ] && echo "║  SMTP:   $SMTP_SERVER"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Don't run as root. Script will use sudo when needed."
fi

# Check OS
if [ ! -f /etc/os-release ]; then
    error "Unsupported OS. Use Ubuntu 22.04 LTS."
fi
. /etc/os-release
if [ "$ID" != "ubuntu" ] && [ "$ID" != "debian" ] && [ "$ID" != "kali" ]; then
    error "Unsupported OS: $ID. Use Ubuntu 22.04, Debian 12, or Kali."
fi
log "Detected: $ID $VERSION_ID"

# ============================================================================
# PHASE 1: SYSTEM PACKAGES
# ============================================================================
info "Phase 1: Installing system packages..."

sudo apt-get update -qq
sudo apt-get install -y -qq \
    curl \
    git \
    nginx \
    certbot \
    python3-certbot-nginx

# Install Docker
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    warn "Added to docker group. May need to logout/login."
else
    log "Docker already installed"
fi

# Install Docker Compose - ALWAYS check and install standalone for Kali
log "Checking Docker Compose..."
if docker compose version &> /dev/null; then
    log "Docker Compose plugin available"
elif command -v docker-compose &> /dev/null; then
    log "Docker Compose standalone available"
else
    log "Installing Docker Compose standalone..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K[^"]+' 2>/dev/null || echo "v2.27.0")
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    # Also create as docker plugin
    mkdir -p ~/.docker/cli-plugins
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo ln -sf /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
    log "Docker Compose installed: $(docker-compose --version)"
fi

# ============================================================================
# PHASE 2: CLONE ERRORDON
# ============================================================================
info "Phase 2: Cloning Errordon..."

INSTALL_DIR="$HOME/errordon"
if [ ! -d "$INSTALL_DIR" ]; then
    git clone https://github.com/error-wtf/errordon.git "$INSTALL_DIR"
else
    log "Errordon directory exists, updating..."
    cd "$INSTALL_DIR"
    git pull origin main || git pull origin master
fi

cd "$INSTALL_DIR"

# ============================================================================
# PHASE 3: CONFIGURATION
# ============================================================================
info "Phase 3: Configuring environment..."

if [ ! -f ".env.production" ]; then
    cp deploy/.env.example .env.production
    
    # Set domain
    sed -i "s/LOCAL_DOMAIN=.*/LOCAL_DOMAIN=$DOMAIN/" .env.production
    
    # Generate secrets using docker
    log "Generating secrets..."
    SECRET_KEY=$(docker run --rm ghcr.io/mastodon/mastodon:v4.3.0 bundle exec rake secret 2>/dev/null || openssl rand -hex 64)
    OTP_SECRET=$(docker run --rm ghcr.io/mastodon/mastodon:v4.3.0 bundle exec rake secret 2>/dev/null || openssl rand -hex 64)
    
    sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$SECRET_KEY/" .env.production
    sed -i "s/OTP_SECRET=.*/OTP_SECRET=$OTP_SECRET/" .env.production
    
    # Generate VAPID keys
    VAPID_OUTPUT=$(docker run --rm ghcr.io/mastodon/mastodon:v4.3.0 bundle exec rake mastodon:webpush:generate_vapid_key 2>/dev/null || echo "")
    if [ -n "$VAPID_OUTPUT" ]; then
        echo "$VAPID_OUTPUT" >> .env.production
    fi
    
    # Set admin email
    sed -i "s/ERRORDON_NSFW_ADMIN_EMAIL=.*/ERRORDON_NSFW_ADMIN_EMAIL=$EMAIL/" .env.production
    
    # Configure SMTP if provided via environment
    if [ -n "$SMTP_SERVER" ]; then
        log "Configuring SMTP..."
        sed -i "s/SMTP_SERVER=.*/SMTP_SERVER=$SMTP_SERVER/" .env.production
        sed -i "s/SMTP_PORT=.*/SMTP_PORT=${SMTP_PORT:-587}/" .env.production
        sed -i "s/SMTP_LOGIN=.*/SMTP_LOGIN=$SMTP_LOGIN/" .env.production
        sed -i "s/SMTP_PASSWORD=.*/SMTP_PASSWORD=$SMTP_PASSWORD/" .env.production
        sed -i "s/SMTP_FROM_ADDRESS=.*/SMTP_FROM_ADDRESS=${SMTP_FROM:-noreply@$DOMAIN}/" .env.production
    fi
    
    # Enable Matrix theme if requested
    if [ "$INSTALL_MATRIX" = true ]; then
        sed -i "s/ERRORDON_MATRIX_THEME_ENABLED=false/ERRORDON_MATRIX_THEME_ENABLED=true/" .env.production
    fi
    
    log ".env.production created"
else
    log ".env.production already exists"
fi

# ============================================================================
# PHASE 4: NGINX & SSL
# ============================================================================
info "Phase 4: Configuring nginx and SSL..."

# CRITICAL: Remove ALL existing nginx configs first
sudo rm -f /etc/nginx/sites-enabled/*
sudo rm -f /etc/nginx/sites-available/errordon*

# Step 1: Create temporary HTTP-only config for certbot
cat << TEMPNGINX | sudo tee /etc/nginx/sites-available/errordon-temp > /dev/null
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 200 'Errordon Setup in Progress';
        add_header Content-Type text/plain;
    }
}
TEMPNGINX

sudo ln -sf /etc/nginx/sites-available/errordon-temp /etc/nginx/sites-enabled/
sudo mkdir -p /var/www/html

# Ensure nginx is running
sudo nginx -t
if ! systemctl is-active --quiet nginx; then
    sudo systemctl start nginx
else
    sudo systemctl reload nginx
fi

# Step 2: Get SSL certificate
log "Getting SSL certificate..."
SSL_SUCCESS=false
if [ -n "$EMAIL" ]; then
    if sudo certbot certonly --webroot -w /var/www/html -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"; then
        SSL_SUCCESS=true
    fi
else
    if sudo certbot certonly --webroot -w /var/www/html -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email; then
        SSL_SUCCESS=true
    fi
fi

if [ "$SSL_SUCCESS" = false ]; then
    warn "Certbot failed. Trying standalone method..."
    sudo systemctl stop nginx 2>/dev/null || true
    if sudo certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "${EMAIL:-admin@$DOMAIN}"; then
        SSL_SUCCESS=true
    else
        error "SSL certificate failed. Run manually: sudo certbot certonly --standalone -d $DOMAIN"
    fi
fi
log "SSL certificate obtained"

# Step 3: Now install the full HTTPS config
sudo rm -f /etc/nginx/sites-enabled/errordon-temp
sudo cp deploy/nginx.conf /etc/nginx/sites-available/errordon
sudo sed -i "s/example.com/$DOMAIN/g" /etc/nginx/sites-available/errordon

# Fix deprecated http2 directive for newer nginx
sudo sed -i 's/listen 443 ssl http2;/listen 443 ssl;\n    http2 on;/' /etc/nginx/sites-available/errordon
sudo sed -i 's/listen \[::\]:443 ssl http2;/listen [::]:443 ssl;/' /etc/nginx/sites-available/errordon

sudo ln -sf /etc/nginx/sites-available/errordon /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
log "Nginx configured with SSL"

# ============================================================================
# PHASE 5: DATABASE & SERVICES
# ============================================================================
info "Phase 5: Starting services..."

# Start db and redis first
dc up -d db redis
sleep 10

# Setup database
log "Initializing database..."
dc run --rm web bundle exec rake db:setup 2>/dev/null || \
dc run --rm web bundle exec rake db:migrate

# Precompile assets
log "Precompiling assets (this takes a while)..."
dc run --rm web bundle exec rake assets:precompile

# Start all services
dc up -d

# ============================================================================
# PHASE 6: OLLAMA (optional)
# ============================================================================
if [ "$INSTALL_OLLAMA" = true ]; then
    info "Phase 6: Installing Ollama for NSFW-Protect AI..."
    
    if ! command -v ollama &> /dev/null; then
        log "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
        sleep 3
        sudo systemctl enable ollama
        sudo systemctl start ollama
        sleep 5
    fi
    
    log "Downloading AI models (this may take a while)..."
    echo ""
    echo "  📦 Model 1/3: llava:7b (Image analysis, ~4.7GB)"
    ollama pull llava:7b || warn "llava:7b pull failed"
    
    echo "  📦 Model 2/3: llama3.2:3b (Fast text moderation, ~2GB)"
    ollama pull llama3.2:3b || warn "llama3.2:3b pull failed"
    
    echo "  📦 Model 3/3: llama3:8b (Advanced text analysis, ~4.7GB)"
    ollama pull llama3:8b || warn "llama3:8b pull failed"
    
    log "AI models downloaded"
    
    # Enable NSFW-Protect
    sed -i "s/ERRORDON_NSFW_PROTECT_ENABLED=false/ERRORDON_NSFW_PROTECT_ENABLED=true/" .env.production
    sed -i "s|ERRORDON_NSFW_OLLAMA_ENDPOINT=.*|ERRORDON_NSFW_OLLAMA_ENDPOINT=http://host.docker.internal:11434|" .env.production
    
    # Restart to apply
    dc restart web sidekiq
    
    log "NSFW-Protect enabled"
fi

# ============================================================================
# PHASE 6B: MATRIX TERMINAL (optional)
# ============================================================================
if [ "$INSTALL_MATRIX" = true ]; then
    info "Enabling Matrix Terminal landing page..."
    
    # Add Matrix config to .env.production
    if ! grep -q "ERRORDON_MATRIX_LANDING_ENABLED" .env.production 2>/dev/null; then
        cat >> .env.production << 'MATRIXEOF'

# ============================================================================
# MATRIX TERMINAL LANDING PAGE
# ============================================================================
ERRORDON_MATRIX_LANDING_ENABLED=true
MATRIXEOF
    else
        sed -i 's/ERRORDON_MATRIX_LANDING_ENABLED=false/ERRORDON_MATRIX_LANDING_ENABLED=true/' .env.production
    fi
    
    # Set landing page via Rails console
    dc run --rm web bundle exec rails runner "Setting.landing_page = 'matrix'" 2>/dev/null || true
    
    log "Matrix Terminal enabled as landing page"
fi

# ============================================================================
# PHASE 7: POST-INSTALL SETUP
# ============================================================================
info "Phase 7: Post-install setup..."

# Create Errordon directories
log "Creating Errordon directories..."
dc exec -T web mkdir -p log/nsfw_protect/admin_reports 2>/dev/null || true
dc exec -T web mkdir -p log/gdpr_audit 2>/dev/null || true
dc exec -T web mkdir -p tmp/errordon_cleanup 2>/dev/null || true

# Run any pending migrations (for Errordon tables)
log "Running database migrations..."
dc run --rm web bundle exec rake db:migrate 2>/dev/null || true

# Initialize NSFW-Protect
dc exec -T web bundle exec rake errordon:nsfw_protect:setup 2>/dev/null || true

# Initialize blocklists
dc exec -T web bundle exec rake errordon:blocklist:update 2>/dev/null || true

# ============================================================================
# CREATE ADMIN ACCOUNT
# ============================================================================
info "Creating admin account..."
ADMIN_PASSWORD=$(dc exec -T web bin/tootctl accounts create "$ADMIN_USER" --email="$ADMIN_EMAIL" --confirmed --role=Owner 2>&1 | grep -oP 'New password: \K.*' || true)

if [ -n "$ADMIN_PASSWORD" ]; then
    log "Admin account created successfully!"
    echo ""
    echo "╔════════════════════════════════════════════════╗"
    echo "║  ADMIN CREDENTIALS - SAVE THESE!              ║"
    echo "╠════════════════════════════════════════════════╣"
    echo "║  Username: $ADMIN_USER"
    echo "║  Email:    $ADMIN_EMAIL"
    echo "║  Password: $ADMIN_PASSWORD"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    # Save credentials to file
    cat > "$INSTALL_DIR/admin_credentials.txt" << CREDS
Errordon Admin Credentials
===========================
Username: $ADMIN_USER
Email:    $ADMIN_EMAIL
Password: $ADMIN_PASSWORD
URL:      https://$DOMAIN

Created: $(date)
IMPORTANT: Delete this file after saving credentials securely!
CREDS
    chmod 600 "$INSTALL_DIR/admin_credentials.txt"
    warn "Credentials saved to: $INSTALL_DIR/admin_credentials.txt"
    warn "DELETE THIS FILE after saving credentials securely!"
else
    warn "Could not create admin account automatically."
    log "Create manually with:"
    echo "  dc exec web bin/tootctl accounts create $ADMIN_USER --email=$ADMIN_EMAIL --confirmed --role=Owner"
fi
echo ""

# ============================================================================
# DONE
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║     Installation Complete! ✓                   ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
log "Errordon is running at: https://$DOMAIN"
echo ""

# Status
log "Service status:"
dc ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || dc ps

echo ""
log "Useful commands:"
echo "  cd $INSTALL_DIR"
echo "  dc logs -f        # View logs"
echo "  dc restart        # Restart services"
echo "  dc down           # Stop services"
echo ""

if [ "$INSTALL_OLLAMA" = true ]; then
    log "NSFW-Protect: ✓ Enabled"
    echo "  - Ollama: $(ollama --version 2>/dev/null || echo 'installed')"
    echo "  - Models: llava, llama3"
    echo "  - Admin alerts: $EMAIL"
fi

if [ "$INSTALL_MATRIX" = true ]; then
    log "Matrix Terminal: ✓ Enabled as landing page"
    echo "  - Visitors see interactive terminal first"
    echo "  - Type 'enter matrix' to access login"
    echo "  - Commands: tetris, quote, hack, talk"
    echo "  - Configure in Admin → Server Settings → Branding"
fi

echo ""
warn "Edit .env.production to configure SMTP for emails!"
echo ""
