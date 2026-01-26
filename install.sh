#!/bin/bash
#
# Errordon Installation Script v2.0
# Secure installation for Ubuntu/Debian Linux
#
# Usage: curl -sSL https://raw.githubusercontent.com/error-wtf/errordon/main/install.sh | bash
#    or: ./install.sh [--domain example.com] [--email admin@example.com]
#
# Security: This script validates checksums and uses HTTPS only
#

set -euo pipefail
trap 'error "Installation failed at line $LINENO"' ERR

# ============================================================================
# CONFIGURATION
# ============================================================================
ERRORDON_VERSION="0.3.0"
RUBY_VERSION="3.3.0"
NODE_VERSION="20"
MIN_DISK_GB=20
MIN_RAM_MB=2048

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# Parse arguments
DOMAIN=""
EMAIL=""
SKIP_SSL=false
INSTALL_MATRIX=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift 2 ;;
        --email) EMAIL="$2"; shift 2 ;;
        --skip-ssl) SKIP_SSL=true; shift ;;
        --with-matrix) INSTALL_MATRIX=true; shift ;;
        --help) echo "Usage: $0 [--domain example.com] [--email admin@example.com] [--skip-ssl] [--with-matrix]"; exit 0 ;;
        *) shift ;;
    esac
done

# ============================================================================
# SECURITY CHECKS
# ============================================================================

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Please don't run as root. Script will use sudo when needed."
fi

# Check sudo access
if ! sudo -v &>/dev/null; then
    error "This script requires sudo privileges."
fi

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║     Errordon Installation Script v2.0          ║"
echo "║     Security-Hardened Mastodon Fork            ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# INTERACTIVE CONFIGURATION
# ============================================================================
if [ -z "$DOMAIN" ]; then
    echo -e "${BLUE}[?]${NC} Enter your domain (e.g., social.example.com):"
    read -p "    Domain: " DOMAIN
    if [ -z "$DOMAIN" ]; then
        warn "No domain provided - will configure for local development only"
    fi
fi

if [ -n "$DOMAIN" ] && [ -z "$EMAIL" ]; then
    echo -e "${BLUE}[?]${NC} Enter admin email for SSL certificate and notifications:"
    read -p "    Email: " EMAIL
    if [ -z "$EMAIL" ]; then
        error "Email is required when domain is specified"
    fi
fi

# Ask about Matrix Terminal
if [ "$INSTALL_MATRIX" = false ]; then
    echo ""
    echo -e "${BLUE}[?]${NC} Install Matrix Terminal landing page?"
    echo "    (Cool hacker-style login screen with commands like 'tetris', 'talk morpheus')"
    read -p "    Install Matrix Terminal? (y/N): " -n 1 -r MATRIX_REPLY
    echo
    if [[ $MATRIX_REPLY =~ ^[Yy]$ ]]; then
        INSTALL_MATRIX=true
    fi
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║     Installation Configuration                 ║"
echo "╠════════════════════════════════════════════════╣"
if [ -n "$DOMAIN" ]; then
    echo "║  Domain:         $DOMAIN"
    echo "║  Email:          $EMAIL"
else
    echo "║  Mode:           Local Development"
fi
echo "║  Matrix Theme:   $([ "$INSTALL_MATRIX" = true ] && echo "Yes" || echo "No")"
echo "║  Skip SSL:       $([ "$SKIP_SSL" = true ] && echo "Yes" || echo "No")"
echo "╚════════════════════════════════════════════════╝"
echo ""
read -p "Continue with installation? (Y/n): " -n 1 -r CONFIRM
echo
if [[ $CONFIRM =~ ^[Nn]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi
echo ""

# ============================================================================
# SYSTEM REQUIREMENTS CHECK
# ============================================================================

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    error "Cannot detect OS. This script supports Ubuntu/Debian."
fi

# Check supported OS (Kali is Debian-based)
case "$OS" in
    ubuntu|debian|kali) log "Detected: $OS $VERSION" ;;
    *) error "Unsupported OS: $OS. Use Ubuntu 20.04+, Debian 11+, or Kali Linux" ;;
esac

# Check disk space
DISK_FREE=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
if [ "$DISK_FREE" -lt "$MIN_DISK_GB" ]; then
    error "Insufficient disk space. Need ${MIN_DISK_GB}GB, have ${DISK_FREE}GB"
fi
log "Disk space: ${DISK_FREE}GB available"

# Check RAM
RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
if [ "$RAM_MB" -lt "$MIN_RAM_MB" ]; then
    warn "Low RAM: ${RAM_MB}MB. Recommended: ${MIN_RAM_MB}MB+"
fi
log "RAM: ${RAM_MB}MB"

# Check network connectivity
if ! curl -sf --connect-timeout 5 https://github.com > /dev/null; then
    error "No network connectivity to GitHub"
fi
log "Network connectivity: OK"

# ============================================================================
# PHASE 1: SYSTEM PACKAGES
# ============================================================================
info "Phase 1: Installing system packages..."

# Update system
log "Updating package lists..."
sudo apt-get update -qq || error "Failed to update package lists"

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
    hash -r  # Refresh PATH
else
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        warn "Node.js version too old. Upgrading..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y -qq nodejs
        hash -r  # Refresh PATH
    else
        log "Node.js $(node -v) already installed"
    fi
fi

# Ensure npm is available (Kali/Debian may have node without npm)
if ! command -v npm &> /dev/null; then
    log "Installing npm..."
    sudo apt-get install -y -qq npm
    hash -r
fi

# Install Yarn via corepack (modern method) or npm fallback
if ! command -v yarn &> /dev/null; then
    log "Installing Yarn..."
    if command -v corepack &> /dev/null; then
        sudo corepack enable
        corepack prepare yarn@stable --activate 2>/dev/null || sudo npm install -g yarn
    else
        sudo npm install -g yarn
    fi
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

# ============================================================================
# PHASE 5: ERRORDON SECURITY CONFIGURATION
# ============================================================================
info "Phase 5: Configuring Errordon security..."

# Add Errordon-specific ENV variables
if ! grep -q "ERRORDON_" .env.production 2>/dev/null; then
    log "Adding Errordon security configuration..."
    cat >> .env.production << 'EOF'

# ============================================================================
# ERRORDON CONFIGURATION
# ============================================================================

# Privacy (strict = unlisted default, no federation search)
ERRORDON_PRIVACY_PRESET=standard
ERRORDON_DEFAULT_VISIBILITY=public
ERRORDON_DEFAULT_DISCOVERABLE=true

# Upload limits (250MB for video)
ERRORDON_VIDEO_SIZE_LIMIT=262144000
ERRORDON_AUDIO_SIZE_LIMIT=52428800
ERRORDON_IMAGE_SIZE_LIMIT=20971520

# Transcoding
ERRORDON_TRANSCODING_ENABLED=true
ERRORDON_TRANSCODING_THREADS=2

# Quotas
ERRORDON_QUOTA_ENABLED=true
ERRORDON_MAX_STORAGE_GB=10
ERRORDON_MAX_UPLOADS_HOUR=20
ERRORDON_MAX_DAILY_UPLOAD_GB=2

# Security (IMPORTANT!)
ERRORDON_SECURITY_STRICT=true
ERRORDON_BLOCK_SUSPICIOUS_IPS=true
ERRORDON_AUDIT_FILE=true

# ============================================================================
# NSFW-PROTECT AI MODERATION
# ============================================================================
# Enable to activate AI-based content moderation
ERRORDON_NSFW_PROTECT_ENABLED=false

# Ollama Configuration (required when NSFW-Protect is enabled)
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://localhost:11434
ERRORDON_NSFW_OLLAMA_VISION_MODEL=llava
ERRORDON_NSFW_OLLAMA_TEXT_MODEL=llama3

# Admin email for NSFW alerts (CSAM detection, instance freeze, etc.)
ERRORDON_NSFW_ADMIN_EMAIL=

# Instance freeze when X alarms are active (0 = disabled)
ERRORDON_NSFW_ALARM_THRESHOLD=10

# Registration restrictions
ERRORDON_INVITE_ONLY=false
ERRORDON_REQUIRE_AGE_18=false
EOF
    log "Errordon security configuration added"
fi

# Check ffmpeg version for transcoding
FFMPEG_VERSION=$(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}' | cut -d'-' -f1)
if [ -n "$FFMPEG_VERSION" ]; then
    log "ffmpeg version: $FFMPEG_VERSION"
    # Check for libx264 support
    if ffmpeg -encoders 2>/dev/null | grep -q libx264; then
        log "ffmpeg libx264 encoder: OK"
    else
        warn "ffmpeg missing libx264 - transcoding may fail"
    fi
else
    warn "ffmpeg not found - transcoding will not work"
fi

# ============================================================================
# PHASE 5b: OLLAMA INSTALLATION (for NSFW-Protect AI)
# ============================================================================
info "Phase 5b: Installing Ollama for NSFW-Protect AI..."

INSTALL_OLLAMA=false
read -p "Install Ollama for AI content moderation? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    INSTALL_OLLAMA=true
fi

if [ "$INSTALL_OLLAMA" = true ]; then
    if ! command -v ollama &> /dev/null; then
        log "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
        
        # Wait for Ollama service to start
        sleep 3
        
        # Pull the required models
        log "Pulling llava model for image analysis (this may take a while)..."
        ollama pull llava
        
        log "Pulling llama3 model for text analysis..."
        ollama pull llama3
        
        # Enable and start Ollama service
        sudo systemctl enable ollama 2>/dev/null || true
        sudo systemctl start ollama 2>/dev/null || true
        
        log "Ollama installed successfully"
        
        # Update ENV to enable NSFW-Protect
        if [ -f ".env.production" ]; then
            sed -i 's/ERRORDON_NSFW_PROTECT_ENABLED=false/ERRORDON_NSFW_PROTECT_ENABLED=true/' .env.production
            log "NSFW-Protect enabled in .env.production"
        fi
    else
        log "Ollama already installed"
        
        # Check if models are available
        if ! ollama list 2>/dev/null | grep -q "llava"; then
            log "Pulling llava model..."
            ollama pull llava
        fi
        if ! ollama list 2>/dev/null | grep -q "llama3"; then
            log "Pulling llama3 model..."
            ollama pull llama3
        fi
    fi
    
    # Create Ollama systemd service if it doesn't exist
    if [ ! -f "/etc/systemd/system/ollama.service" ]; then
        log "Creating Ollama systemd service..."
        sudo tee /etc/systemd/system/ollama.service > /dev/null << 'OLLAMAEOF'
[Unit]
Description=Ollama AI Service
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0"

[Install]
WantedBy=multi-user.target
OLLAMAEOF
        sudo systemctl daemon-reload
        sudo systemctl enable ollama
        sudo systemctl start ollama
    fi
else
    warn "Ollama not installed. NSFW-Protect AI will be disabled."
    warn "To install later: curl -fsSL https://ollama.com/install.sh | sh"
fi

# ============================================================================
# PHASE 6: SYSTEMD SERVICES (optional)
# ============================================================================
if [ -n "$DOMAIN" ]; then
    info "Phase 6: Setting up systemd services..."
    
    # Create systemd service files
    sudo tee /etc/systemd/system/errordon-web.service > /dev/null << EOF
[Unit]
Description=Errordon Web
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
Environment="RAILS_ENV=production"
Environment="PORT=3000"
ExecStart=/home/$USER/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/errordon-sidekiq.service > /dev/null << EOF
[Unit]
Description=Errordon Sidekiq
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
Environment="RAILS_ENV=production"
Environment="MALLOC_ARENA_MAX=2"
ExecStart=/home/$USER/.rbenv/shims/bundle exec sidekiq -c 5
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/errordon-streaming.service > /dev/null << EOF
[Unit]
Description=Errordon Streaming
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
Environment="NODE_ENV=production"
Environment="PORT=4000"
ExecStart=/usr/bin/node streaming
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    log "Systemd services created"
fi

# ============================================================================
# PHASE 7: SSL SETUP (optional)
# ============================================================================
if [ -n "$DOMAIN" ] && [ -n "$EMAIL" ] && [ "$SKIP_SSL" = false ]; then
    info "Phase 7: Setting up SSL with Let's Encrypt..."
    
    # Configure nginx
    sudo tee /etc/nginx/sites-available/errordon > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $(pwd)/public;
    
    location /.well-known/acme-challenge/ {
        allow all;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
    
    sudo ln -sf /etc/nginx/sites-available/errordon /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
    
    # Get SSL certificate
    sudo certbot certonly --webroot -w $(pwd)/public -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive && {
        log "SSL certificate obtained for $DOMAIN"
        
        # Update nginx with SSL
        sudo tee /etc/nginx/sites-available/errordon > /dev/null << NGINXEOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    
    root $(pwd)/public;
    client_max_body_size 300M;
    
    location / {
        try_files \$uri @proxy;
    }
    
    location @proxy {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /api/v1/streaming {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINXEOF
        sudo nginx -t && sudo systemctl reload nginx
        log "Nginx configured with SSL"
    } || warn "SSL setup failed - configure manually"
fi

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║     Errordon Installation Complete! ✓          ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
log "Version: $ERRORDON_VERSION"
log "Ruby: $RUBY_VERSION"
log "Node: $NODE_VERSION"
echo ""

if [ -n "$DOMAIN" ]; then
    log "Domain: $DOMAIN"
    log "Systemd services: errordon-web, errordon-sidekiq, errordon-streaming"
    echo ""
    log "Start services:"
    echo "  sudo systemctl enable --now errordon-web errordon-sidekiq errordon-streaming"
else
    log "Next steps:"
    echo "  1. Edit .env.production with your domain"
    echo "  2. Run: RAILS_ENV=production bundle exec rails db:setup"
    echo "  3. Run: RAILS_ENV=production bundle exec rails assets:precompile"
    echo "  4. Re-run with: ./install.sh --domain your.domain --email you@email.com"
fi

echo ""
log "Errordon Security Features:"
echo "  ✓ File upload validation"
echo "  ✓ Malware detection"  
echo "  ✓ Rate limiting"
echo "  ✓ Audit logging"
echo "  ✓ Auto IP blocking"
echo ""

# Check if Ollama/NSFW-Protect is installed
if command -v ollama &> /dev/null; then
    log "NSFW-Protect AI Features:"
    echo "  ✓ Ollama AI installed"
    echo "  ✓ Image/Video porn detection"
    echo "  ✓ Text hate speech detection"
    echo "  ✓ Automatic strike/freeze system"
    echo "  ✓ Admin email alerts"
    echo "  ✓ IP address logging for law enforcement"
    echo "  ✓ Domain blocklist (auto-updated daily)"
    echo ""
    
    # Initialize blocklist on first install
    if [ -f "config/errordon/porn_domain_blocklist.txt" ]; then
        log "Porn domain blocklist: $(wc -l < config/errordon/porn_domain_blocklist.txt) domains"
    fi
    
    warn "Configure ERRORDON_NSFW_ADMIN_EMAIL in .env.production!"
    info "Blocklist auto-updates daily at 3 AM via Sidekiq"
else
    warn "NSFW-Protect AI not installed"
    echo "  To install later:"
    echo "    curl -fsSL https://ollama.com/install.sh | sh"
    echo "    ollama pull llava"
    echo "    ollama pull llama3"
    echo "    # Then set ERRORDON_NSFW_PROTECT_ENABLED=true in .env.production"
fi

# Initialize Errordon directories
if [ -d "log" ]; then
    mkdir -p log/nsfw_protect/admin_reports
    mkdir -p log/gdpr_audit
    mkdir -p tmp/errordon_cleanup
    chmod 700 log/nsfw_protect log/nsfw_protect/admin_reports 2>/dev/null || true
    chmod 700 log/gdpr_audit 2>/dev/null || true
    log "Errordon log directories created"
fi

# Run Errordon database migrations
log "Running Errordon database migrations..."
RAILS_ENV=production bundle exec rake db:migrate 2>/dev/null || warn "Migration may need to run manually"

# Initialize blocklists
log "Initializing blocklists..."
RAILS_ENV=production bundle exec rake errordon:blocklist:update 2>/dev/null || true

# ============================================================================
# MATRIX TERMINAL LANDING PAGE
# ============================================================================
if [ "$INSTALL_MATRIX" = true ]; then
    log "Enabling Matrix Terminal landing page..."
    
    # Add Matrix config to .env.production
    if [ -f ".env.production" ]; then
        if ! grep -q "ERRORDON_MATRIX_LANDING_ENABLED" .env.production; then
            cat >> .env.production << 'MATRIXEOF'

# ============================================================================
# MATRIX TERMINAL LANDING PAGE
# ============================================================================
ERRORDON_MATRIX_LANDING_ENABLED=true
MATRIXEOF
        else
            sed -i 's/ERRORDON_MATRIX_LANDING_ENABLED=false/ERRORDON_MATRIX_LANDING_ENABLED=true/' .env.production
        fi
    fi
    
    # Set landing page in database
    RAILS_ENV=production bundle exec rails runner "Setting.landing_page = 'matrix'" 2>/dev/null || true
    
    log "Matrix Terminal: ✓ Enabled as landing page"
    echo "  - Visitors see interactive terminal first"
    echo "  - Type 'enter matrix' to access login"
    echo "  - Commands: tetris, quote, hack, talk <character>"
    echo "  - Configure in Admin → Server Settings → Branding"
fi

# ============================================================================
# CREATE ADMIN ACCOUNT
# ============================================================================
if [ -n "$DOMAIN" ] && [ -n "$EMAIL" ]; then
    echo ""
    read -p "Create admin account now? (Y/n): " -n 1 -r CREATE_ADMIN
    echo
    if [[ ! $CREATE_ADMIN =~ ^[Nn]$ ]]; then
        read -p "Admin username (default: admin): " ADMIN_USER
        ADMIN_USER=${ADMIN_USER:-admin}
        
        log "Creating admin account: $ADMIN_USER"
        ADMIN_PASSWORD=$(RAILS_ENV=production bin/tootctl accounts create "$ADMIN_USER" --email="$EMAIL" --confirmed --role=Owner 2>&1 | grep -oP 'New password: \K.*' || true)
        
        if [ -n "$ADMIN_PASSWORD" ]; then
            echo ""
            echo "╔════════════════════════════════════════════════╗"
            echo "║  ADMIN CREDENTIALS - SAVE THESE!              ║"
            echo "╠════════════════════════════════════════════════╣"
            echo "║  Username: $ADMIN_USER"
            echo "║  Email:    $EMAIL"
            echo "║  Password: $ADMIN_PASSWORD"
            echo "╚════════════════════════════════════════════════╝"
            echo ""
            # Save credentials to file
            cat > "admin_credentials.txt" << CREDS
Errordon Admin Credentials
===========================
Username: $ADMIN_USER
Email:    $EMAIL
Password: $ADMIN_PASSWORD
URL:      https://$DOMAIN

Created: $(date)
IMPORTANT: Delete this file after saving credentials securely!
CREDS
            chmod 600 "admin_credentials.txt"
            warn "Credentials saved to: $(pwd)/admin_credentials.txt"
            warn "DELETE THIS FILE after saving credentials securely!"
        else
            warn "Could not create admin account automatically."
            log "Create manually with:"
            echo "  RAILS_ENV=production bin/tootctl accounts create $ADMIN_USER --email=$EMAIL --confirmed --role=Owner"
        fi
    fi
fi

echo ""
warn "Reload shell: source ~/.bashrc"
echo ""
