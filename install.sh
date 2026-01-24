#!/bin/bash
#
# Errordon Installation Script
# Installs all dependencies for Ubuntu/Debian Linux
#
# Usage: curl -sSL https://raw.githubusercontent.com/error-wtf/errordon/main/install.sh | bash
#    or: ./install.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Please don't run as root. Script will use sudo when needed."
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     Errordon Installation Script       ║"
echo "║     Phase 1: Dependencies Setup        ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    error "Cannot detect OS. This script supports Ubuntu/Debian."
fi

log "Detected: $OS $VERSION"

# Update system
log "Updating package lists..."
sudo apt-get update -qq

# Install basic dependencies
log "Installing basic dependencies..."
sudo apt-get install -y -qq \
    curl \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    git \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libicu-dev \
    libidn11-dev \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    imagemagick \
    ffmpeg \
    libvips-dev \
    redis-server \
    redis-tools \
    certbot \
    python3-certbot-nginx \
    nginx

# Install Node.js 20.x
if ! command -v node &> /dev/null; then
    log "Installing Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
else
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        warn "Node.js version too old. Upgrading..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y -qq nodejs
    else
        log "Node.js $(node -v) already installed"
    fi
fi

# Install Yarn
if ! command -v yarn &> /dev/null; then
    log "Installing Yarn..."
    sudo npm install -g yarn
else
    log "Yarn $(yarn -v) already installed"
fi

# Install rbenv and Ruby
if [ ! -d "$HOME/.rbenv" ]; then
    log "Installing rbenv..."
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
else
    log "rbenv already installed"
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
fi

# Install Ruby 3.3.0
RUBY_VERSION="3.3.0"
if ! rbenv versions | grep -q $RUBY_VERSION; then
    log "Installing Ruby $RUBY_VERSION (this takes a while)..."
    rbenv install $RUBY_VERSION
    rbenv global $RUBY_VERSION
else
    log "Ruby $RUBY_VERSION already installed"
fi

# Install Bundler
log "Installing Bundler..."
gem install bundler

# PostgreSQL
if ! command -v psql &> /dev/null; then
    log "Installing PostgreSQL..."
    sudo apt-get install -y -qq postgresql postgresql-contrib
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
else
    log "PostgreSQL already installed"
fi

# Create mastodon user in PostgreSQL
log "Setting up PostgreSQL user..."
sudo -u postgres psql -c "CREATE USER mastodon CREATEDB;" 2>/dev/null || warn "User mastodon may already exist"

# Start Redis
log "Starting Redis..."
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Clone Errordon (if not already in repo)
if [ ! -f "Gemfile" ]; then
    log "Cloning Errordon..."
    git clone https://github.com/error-wtf/errordon.git
    cd errordon
fi

# Install Ruby dependencies
log "Installing Ruby gems..."
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install -j$(nproc)

# Install Node dependencies
log "Installing Node packages..."
yarn install --production --frozen-lockfile

# Setup environment
if [ ! -f ".env.production" ]; then
    log "Creating .env.production from template..."
    cp .env.production.sample .env.production
    
    # Generate secrets
    SECRET_KEY=$(bundle exec rake secret)
    OTP_SECRET=$(bundle exec rake secret)
    
    sed -i "s/SECRET_KEY_BASE=/SECRET_KEY_BASE=$SECRET_KEY/" .env.production
    sed -i "s/OTP_SECRET=/OTP_SECRET=$OTP_SECRET/" .env.production
    
    # Generate VAPID keys
    bundle exec rake mastodon:webpush:generate_vapid_key >> .env.production
    
    warn "Edit .env.production with your domain and database settings!"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     Installation Complete! ✓           ║"
echo "╚════════════════════════════════════════╝"
echo ""
log "Next steps:"
echo "  1. Edit .env.production with your settings"
echo "  2. Run: RAILS_ENV=production bundle exec rails db:setup"
echo "  3. Run: RAILS_ENV=production bundle exec rails assets:precompile"
echo "  4. Configure nginx (see deploy/nginx.conf)"
echo "  5. Setup systemd services (see docs/DEV_SETUP.md)"
echo ""
log "Errordon Privacy ENV variables (optional):"
echo "  ERRORDON_PRIVACY_PRESET=strict"
echo "  ERRORDON_DEFAULT_VISIBILITY=unlisted"
echo "  ERRORDON_DEFAULT_DISCOVERABLE=false"
echo ""
warn "Reload shell: source ~/.bashrc"
echo ""
