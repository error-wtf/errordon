# Errordon Deployment Guide

Complete guide to deploying Errordon in production.

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Quick Start (Docker)](#quick-start-docker)
3. [Manual Installation](#manual-installation)
4. [Configuration](#configuration)
5. [SSL/TLS Setup](#ssltls-setup)
6. [Nginx Configuration](#nginx-configuration)
7. [Systemd Services](#systemd-services)
8. [Database Setup](#database-setup)
9. [Elasticsearch/OpenSearch](#elasticsearchopensearch)
10. [Ollama AI Setup](#ollama-ai-setup)
11. [Email Configuration](#email-configuration)
12. [Backup & Restore](#backup--restore)
13. [Updating](#updating)
14. [Scaling](#scaling)

---

## System Requirements

### Minimum Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Storage | 50 GB SSD | 200+ GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |

### Additional for NSFW-Protect AI

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | +4 GB | +8 GB |
| GPU | Optional | NVIDIA with CUDA |
| Storage | +10 GB | +20 GB (models) |

---

## Quick Start (Docker)

### One-Line Installation

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/error-wtf/errordon/main/install-docker.sh -o install-docker.sh
bash install-docker.sh
```

The interactive installer will prompt for:
- Domain name
- Admin email
- Admin username
- SMTP configuration
- Matrix theme (yes/no)
- Ollama AI (yes/no)

### What Gets Installed

```
Docker containers:
├── web          # Rails application (port 3000)
├── streaming    # WebSocket server (port 4000)
├── sidekiq      # Background job processor
├── db           # PostgreSQL 14
├── redis        # Redis 7
└── es           # OpenSearch 2.11
```

---

## Manual Installation

### 1. Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
  git curl wget \
  build-essential \
  libssl-dev libreadline-dev zlib1g-dev \
  libpq-dev libicu-dev libidn11-dev \
  imagemagick ffmpeg libvips-dev \
  redis-server postgresql postgresql-contrib \
  nginx certbot python3-certbot-nginx
```

### 2. Install Ruby (via rbenv)

```bash
# Install rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install ruby-build
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Install Ruby 3.3.x
rbenv install 3.3.6
rbenv global 3.3.6
```

### 3. Install Node.js (via nvm)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
source ~/.bashrc
nvm install 22
nvm use 22
```

### 4. Clone Repository

```bash
git clone https://github.com/error-wtf/errordon.git /home/mastodon/live
cd /home/mastodon/live
```

### 5. Install Dependencies

```bash
bundle config deployment 'true'
bundle config without 'development test'
bundle install -j$(nproc)

yarn install --frozen-lockfile
```

### 6. Setup Database

```bash
# Create PostgreSQL user
sudo -u postgres createuser --createdb mastodon

# Create database
RAILS_ENV=production bundle exec rails db:setup
```

### 7. Precompile Assets

```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

---

## Configuration

### Environment Variables (.env.production)

```bash
# === BASIC CONFIGURATION ===
LOCAL_DOMAIN=your-domain.com
SINGLE_USER_MODE=false
SECRET_KEY_BASE=<generate with: bundle exec rails secret>
OTP_SECRET=<generate with: bundle exec rails secret>

# === DATABASE ===
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mastodon_production
DB_USER=mastodon
DB_PASS=your_secure_password

# === REDIS ===
REDIS_URL=redis://localhost:6379/0

# === ELASTICSEARCH ===
ES_ENABLED=true
ES_HOST=localhost
ES_PORT=9200

# === EMAIL ===
SMTP_SERVER=smtp.example.com
SMTP_PORT=587
SMTP_LOGIN=your@email.com
SMTP_PASSWORD=your_smtp_password
SMTP_FROM_ADDRESS=notifications@your-domain.com

# === ERRORDON FEATURES ===
ERRORDON_THEME=matrix
ERRORDON_THEME_COLOR=green

# === NSFW-PROTECT AI ===
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://localhost:11434
ERRORDON_NSFW_ADMIN_EMAIL=admin@your-domain.com
ERRORDON_NSFW_AUTO_DELETE=true
ERRORDON_NSFW_AUTO_FREEZE=true

# === STORAGE QUOTAS ===
ERRORDON_STORAGE_ENABLED=true
ERRORDON_STORAGE_BASE_QUOTA=1073741824
ERRORDON_STORAGE_MAX_QUOTA=10737418240
ERRORDON_STORAGE_FAIR_SHARE_PERCENT=60

# === REGISTRATION ===
ERRORDON_INVITE_ONLY=true
ERRORDON_REQUIRE_AGE_18=true

# === PRIVACY (chaos.social inspired) ===
ERRORDON_PRIVACY_PRESET=STANDARD
```

### Generate Secrets

```bash
# Generate SECRET_KEY_BASE
bundle exec rails secret

# Generate OTP_SECRET
bundle exec rails secret

# Generate VAPID keys (for push notifications)
bundle exec rails mastodon:webpush:generate_vapid_key
```

---

## SSL/TLS Setup

### Using Certbot (Let's Encrypt)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal (already set up by certbot)
sudo systemctl enable certbot.timer
```

---

## Nginx Configuration

Create `/etc/nginx/sites-available/errordon`:

```nginx
map $http_upgrade $connection_upgrade {
  default upgrade;
  ''      close;
}

upstream backend {
  server 127.0.0.1:3000 fail_timeout=0;
}

upstream streaming {
  server 127.0.0.1:4000 fail_timeout=0;
}

server {
  listen 80;
  listen [::]:80;
  server_name your-domain.com;
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name your-domain.com;

  ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

  keepalive_timeout 70;
  sendfile on;
  client_max_body_size 250M;

  root /home/mastodon/live/public;

  gzip on;
  gzip_vary on;
  gzip_types text/plain text/css application/json application/javascript;

  location / {
    try_files $uri @proxy;
  }

  location @proxy {
    proxy_pass http://backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffering on;
    proxy_redirect off;
  }

  location /api/v1/streaming {
    proxy_pass http://streaming;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_buffering off;
    proxy_redirect off;
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/errordon /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Systemd Services

### Web Service

Create `/etc/systemd/system/mastodon-web.service`:

```ini
[Unit]
Description=Mastodon Web
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="RAILS_ENV=production"
Environment="PORT=3000"
ExecStart=/home/mastodon/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

### Sidekiq Service

Create `/etc/systemd/system/mastodon-sidekiq.service`:

```ini
[Unit]
Description=Mastodon Sidekiq
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="RAILS_ENV=production"
Environment="MALLOC_ARENA_MAX=2"
ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 25
Restart=always

[Install]
WantedBy=multi-user.target
```

### Streaming Service

Create `/etc/systemd/system/mastodon-streaming.service`:

```ini
[Unit]
Description=Mastodon Streaming
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="NODE_ENV=production"
Environment="PORT=4000"
ExecStart=/usr/bin/node streaming/index.js
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start services:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mastodon-web mastodon-sidekiq mastodon-streaming
sudo systemctl start mastodon-web mastodon-sidekiq mastodon-streaming
```

---

## Ollama AI Setup

### Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Download Models

```bash
# Vision model (required for image/video analysis)
ollama pull llava

# Text model (required for hate speech detection)
ollama pull llama3
```

### Configure as Service

```bash
sudo systemctl enable ollama
sudo systemctl start ollama
```

### Verify Installation

```bash
curl http://localhost:11434/api/tags
```

---

## Email Configuration

### Using Mailgun

```bash
SMTP_SERVER=smtp.mailgun.org
SMTP_PORT=587
SMTP_LOGIN=postmaster@mg.your-domain.com
SMTP_PASSWORD=your_mailgun_key
SMTP_FROM_ADDRESS=notifications@your-domain.com
```

### Using SendGrid

```bash
SMTP_SERVER=smtp.sendgrid.net
SMTP_PORT=587
SMTP_LOGIN=apikey
SMTP_PASSWORD=your_sendgrid_api_key
SMTP_FROM_ADDRESS=notifications@your-domain.com
```

### Test Email

```bash
RAILS_ENV=production bundle exec rails mastodon:email:send_test
```

---

## Backup & Restore

### Automated Backup Script

The `deploy/backup.sh` script handles:
- PostgreSQL database dump
- Media files (optional)
- Configuration files
- Retention policy (default: 7 days)

```bash
# Run backup
./deploy/backup.sh

# Backup location
/home/mastodon/backups/
├── db_YYYYMMDD_HHMMSS.sql.gz
├── media_YYYYMMDD_HHMMSS.tar.gz
└── config_YYYYMMDD_HHMMSS.tar.gz
```

### Restore Database

```bash
# Stop services
sudo systemctl stop mastodon-web mastodon-sidekiq

# Restore
gunzip -c backup.sql.gz | psql -U mastodon mastodon_production

# Restart
sudo systemctl start mastodon-web mastodon-sidekiq
```

### Cron Job for Daily Backups

```bash
# Add to crontab
0 3 * * * /home/mastodon/live/deploy/backup.sh >> /var/log/mastodon-backup.log 2>&1
```

---

## Updating

### Docker Update

```bash
cd /home/errordon/errordon
git pull origin main
docker compose build
docker compose up -d
docker compose exec web bin/rails db:migrate
docker compose exec web bin/rails assets:precompile
```

### Manual Update

```bash
cd /home/mastodon/live

# Stop services
sudo systemctl stop mastodon-*

# Pull updates
git fetch origin
git checkout main
git pull

# Update dependencies
bundle install
yarn install

# Migrate database
RAILS_ENV=production bundle exec rails db:migrate

# Precompile assets
RAILS_ENV=production bundle exec rails assets:precompile

# Restart services
sudo systemctl start mastodon-web mastodon-sidekiq mastodon-streaming
```

---

## Scaling

### Horizontal Scaling

For high-traffic instances:

```yaml
# docker-compose.yml
services:
  web:
    deploy:
      replicas: 3
  
  sidekiq:
    deploy:
      replicas: 2
```

### Database Optimization

```sql
-- Increase shared buffers
ALTER SYSTEM SET shared_buffers = '2GB';

-- Increase work memory
ALTER SYSTEM SET work_mem = '256MB';

-- Enable parallel queries
ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
```

### Redis Optimization

```bash
# /etc/redis/redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

---

## Security Checklist

- [ ] SSL/TLS enabled with A+ rating
- [ ] Firewall configured (only 80, 443, 22)
- [ ] Database not exposed to internet
- [ ] Redis not exposed to internet
- [ ] Regular backups configured
- [ ] Fail2ban installed
- [ ] Automatic security updates enabled

---

## Support

- **GitHub Issues**: [github.com/error-wtf/errordon/issues](https://github.com/error-wtf/errordon/issues)
- **Mastodon Upstream**: [github.com/mastodon/mastodon](https://github.com/mastodon/mastodon)
