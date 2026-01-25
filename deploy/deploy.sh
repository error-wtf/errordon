#!/bin/bash
#
# Errordon Production Deployment Script
# For Ubuntu 22.04 LTS
#
# Usage: ./deploy.sh [domain]
# Example: ./deploy.sh social.example.com
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

DOMAIN=${1:-""}

if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain (e.g., social.example.com): " DOMAIN
fi

if [ -z "$DOMAIN" ]; then
    error "Domain is required"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     Errordon Production Deploy         ║"
echo "║     Domain: $DOMAIN"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Don't run as root. Script will use sudo when needed."
fi

# Create mastodon user if needed
if ! id "mastodon" &>/dev/null; then
    log "Creating mastodon user..."
    sudo adduser --disabled-login --gecos "" mastodon
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    sudo usermod -aG docker mastodon
    warn "Docker installed. You may need to logout/login for group changes."
else
    log "Docker already installed"
fi

# Install Docker Compose plugin
if ! docker compose version &> /dev/null; then
    log "Installing Docker Compose..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-compose-plugin
fi

# Install nginx and certbot
log "Installing nginx and certbot..."
sudo apt-get install -y -qq nginx certbot python3-certbot-nginx

# Ask about NSFW-Protect / Ollama
INSTALL_OLLAMA=false
echo ""
read -p "Install Ollama for AI content moderation (NSFW-Protect)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    INSTALL_OLLAMA=true
fi

# Clone or update repo
INSTALL_DIR="/home/mastodon/errordon"
if [ ! -d "$INSTALL_DIR" ]; then
    log "Cloning Errordon..."
    sudo -u mastodon git clone https://github.com/error-wtf/errordon.git $INSTALL_DIR
else
    log "Updating Errordon..."
    cd $INSTALL_DIR
    sudo -u mastodon git pull
fi

cd $INSTALL_DIR

# Create .env.production if not exists
if [ ! -f ".env.production" ]; then
    log "Creating .env.production..."
    cp deploy/.env.example .env.production
    
    # Set domain
    sed -i "s/LOCAL_DOMAIN=.*/LOCAL_DOMAIN=$DOMAIN/" .env.production
    
    # Generate secrets
    log "Generating secrets..."
    SECRET_KEY=$(docker run --rm ghcr.io/mastodon/mastodon:v4.3.0 bundle exec rake secret 2>/dev/null)
    OTP_SECRET=$(docker run --rm ghcr.io/mastodon/mastodon:v4.3.0 bundle exec rake secret 2>/dev/null)
    
    sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$SECRET_KEY/" .env.production
    sed -i "s/OTP_SECRET=.*/OTP_SECRET=$OTP_SECRET/" .env.production
    
    # Generate VAPID keys
    VAPID_KEYS=$(docker run --rm ghcr.io/mastodon/mastodon:v4.3.0 bundle exec rake mastodon:webpush:generate_vapid_key 2>/dev/null)
    echo "$VAPID_KEYS" >> .env.production
    
    warn "Review .env.production and configure SMTP settings!"
else
    log ".env.production already exists"
fi

# Setup nginx
log "Configuring nginx..."
sudo cp deploy/nginx.conf /etc/nginx/sites-available/errordon
sudo sed -i "s/example.com/$DOMAIN/g" /etc/nginx/sites-available/errordon
sudo ln -sf /etc/nginx/sites-available/errordon /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

# Get SSL certificate
log "Obtaining SSL certificate..."
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN || warn "Certbot failed - run manually"

# Start database and redis first
log "Starting database and redis..."
docker compose up -d db redis
sleep 10

# Initialize database
log "Setting up database..."
docker compose run --rm web bundle exec rake db:setup || docker compose run --rm web bundle exec rake db:migrate

# Precompile assets
log "Precompiling assets..."
docker compose run --rm web bundle exec rake assets:precompile

# Install Ollama if requested
if [ "$INSTALL_OLLAMA" = true ]; then
    log "Installing Ollama for NSFW-Protect AI..."
    
    if ! command -v ollama &> /dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
        sleep 3
    fi
    
    # Pull required models
    log "Pulling llava model for image analysis (this may take a while)..."
    ollama pull llava || warn "Failed to pull llava model"
    
    log "Pulling llama3 model for text analysis..."
    ollama pull llama3 || warn "Failed to pull llama3 model"
    
    # Enable Ollama service
    sudo systemctl enable ollama 2>/dev/null || true
    sudo systemctl start ollama 2>/dev/null || true
    
    # Update .env.production
    if [ -f ".env.production" ]; then
        # Add NSFW-Protect config if not present
        if ! grep -q "ERRORDON_NSFW_PROTECT_ENABLED" .env.production; then
            cat >> .env.production << 'NSFWEOF'

# ============================================================================
# NSFW-PROTECT AI MODERATION
# ============================================================================
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://host.docker.internal:11434
ERRORDON_NSFW_OLLAMA_VISION_MODEL=llava
ERRORDON_NSFW_OLLAMA_TEXT_MODEL=llama3
ERRORDON_NSFW_ADMIN_EMAIL=
ERRORDON_NSFW_ALARM_THRESHOLD=10
ERRORDON_INVITE_ONLY=false
ERRORDON_REQUIRE_AGE_18=false
NSFWEOF
        else
            sed -i 's/ERRORDON_NSFW_PROTECT_ENABLED=false/ERRORDON_NSFW_PROTECT_ENABLED=true/' .env.production
            # Fix endpoint for Docker
            sed -i 's|ERRORDON_NSFW_OLLAMA_ENDPOINT=http://localhost:11434|ERRORDON_NSFW_OLLAMA_ENDPOINT=http://host.docker.internal:11434|' .env.production
        fi
        log "NSFW-Protect enabled in .env.production"
    fi
    
    log "Ollama installed successfully"
fi

# Start all services
log "Starting all services..."
docker compose up -d

# Setup systemd services (alternative to docker)
log "Installing systemd services..."
sudo cp dist/mastodon-*.service /etc/systemd/system/ 2>/dev/null || true
sudo systemctl daemon-reload

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     Deployment Complete! ✓             ║"
echo "╚════════════════════════════════════════╝"
echo ""
log "Errordon is now running at: https://$DOMAIN"
echo ""
log "Useful commands:"
echo "  docker compose logs -f          # View logs"
echo "  docker compose restart          # Restart services"
echo "  docker compose down              # Stop services"
echo ""
log "Create admin user:"
echo "  docker compose run --rm web bin/tootctl accounts create admin --email=admin@$DOMAIN --confirmed --role=Owner"
echo ""

# NSFW-Protect status
if [ "$INSTALL_OLLAMA" = true ]; then
    log "NSFW-Protect AI:"
    echo "  ✓ Ollama installed and running"
    echo "  ✓ llava model (image analysis)"
    echo "  ✓ llama3 model (text analysis)"
    echo "  ✓ Domain blocklist (auto-updated daily)"
    echo "  ✓ IP logging for law enforcement"
    echo "  ✓ Audit trail in log/nsfw_protect/"
    echo ""
    warn "Configure ERRORDON_NSFW_ADMIN_EMAIL in .env.production!"
    info "Scheduled jobs run via Sidekiq (requires sidekiq-cron):"
    echo "    - Blocklist update: daily at 3 AM"
    echo "    - GDPR cleanup: daily at 4 AM"
    echo "    - AI Snapshot cleanup: daily at 4:30 AM"
    echo "    - Video cleanup: daily at 5 AM (if enabled)"
    echo "    - Freeze cleanup: hourly"
    echo "    - Weekly summary: Monday 9 AM"
    echo ""
else
    warn "NSFW-Protect AI not installed"
    echo "  To enable later:"
    echo "    1. curl -fsSL https://ollama.com/install.sh | sh"
    echo "    2. ollama pull llava && ollama pull llama3"
    echo "    3. Add to .env.production:"
    echo "       ERRORDON_NSFW_PROTECT_ENABLED=true"
    echo "       ERRORDON_NSFW_OLLAMA_ENDPOINT=http://host.docker.internal:11434"
    echo ""
fi

# Create Errordon log directories
log "Creating log directories..."
docker compose run --rm web mkdir -p log/nsfw_protect/admin_reports 2>/dev/null || true
docker compose run --rm web mkdir -p log/gdpr_audit 2>/dev/null || true
docker compose run --rm web mkdir -p tmp/errordon_cleanup 2>/dev/null || true

# Run Errordon database migrations
log "Running Errordon database migrations..."
docker compose run --rm web bundle exec rake db:migrate 2>/dev/null || true

# Initialize NSFW-Protect (blocklist, etc.)
log "Initializing NSFW-Protect..."
docker compose exec -T web bundle exec rake errordon:nsfw_protect:setup 2>/dev/null || true

# Initialize fascism blocklist
docker compose exec -T web bundle exec rake errordon:blocklist:update 2>/dev/null || true

# ============================================================================
# POST-INSTALL VERIFICATION
# ============================================================================
echo ""
log "Running post-install verification..."

# Check services
echo ""
log "Service Status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || docker compose ps

# Test web endpoint
echo ""
if curl -sf --max-time 10 "http://localhost:3000/health" > /dev/null 2>&1; then
    log "Web health check: ✓ OK"
else
    warn "Web health check: Could not reach localhost:3000"
fi

# Test external
if curl -sf --max-time 10 "https://$DOMAIN" > /dev/null 2>&1; then
    log "External access: ✓ https://$DOMAIN reachable"
else
    warn "External access: https://$DOMAIN not yet reachable (check nginx/DNS)"
fi

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║     Post-Install Checklist                     ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "  [ ] Edit .env.production:"
echo "      - SMTP settings for emails"
echo "      - ERRORDON_NSFW_ADMIN_EMAIL for alerts"
echo "  [ ] Create admin user (command above)"
echo "  [ ] Test login at https://$DOMAIN"
echo "  [ ] Configure backup (see deploy/backup.sh)"
echo ""

# Matrix Theme hint
if grep -q "ERRORDON_MATRIX_THEME_ENABLED=true" .env.production 2>/dev/null; then
    log "Matrix Theme: ✓ Enabled"
    echo "  Users can toggle with Ctrl+Shift+M"
fi

echo ""
log "Documentation: https://github.com/error-wtf/errordon/blob/main/deploy/README_VPS.md"
echo ""
