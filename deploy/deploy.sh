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

# Start all services
log "Starting all services..."
docker compose up -d

# Setup systemd services (alternative to docker)
log "Installing systemd services..."
sudo cp dist/mastodon-*.service /etc/systemd/system/
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
log "Errordon ENV variables for privacy:"
echo "  Add to .env.production:"
echo "    ERRORDON_PRIVACY_PRESET=strict"
echo "    ERRORDON_DEFAULT_VISIBILITY=unlisted"
echo ""
