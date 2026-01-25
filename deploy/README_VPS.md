# Errordon VPS Deployment Guide

## Requirements

- **VPS**: 4+ CPU cores, 8GB+ RAM (transcoding needs CPU)
- **OS**: Ubuntu 22.04 LTS recommended
- **Domain**: Point DNS A record to VPS IP
- **Storage**: 100GB+ SSD (or S3 for media)

## Quick Start

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Logout and login again
```

### 2. Clone & Configure

```bash
git clone https://github.com/error-wtf/errordon.git
cd errordon/deploy
cp .env.example .env.production

# Edit configuration
nano .env.production
```

### 3. Generate Secrets

```bash
# Generate SECRET_KEY_BASE and OTP_SECRET
docker run --rm -it ghcr.io/mastodon/mastodon:v4.3.0 bundle exec rake secret

# Generate VAPID keys
docker run --rm -it ghcr.io/mastodon/mastodon:v4.3.0 bundle exec rake mastodon:webpush:generate_vapid_key
```

### 4. Initialize Database

```bash
docker compose up -d db redis
docker compose run --rm web bundle exec rake db:setup
```

### 5. Start Services

```bash
docker compose up -d
```

### 6. Setup nginx & SSL

```bash
# Install nginx
sudo apt install nginx certbot python3-certbot-nginx

# Copy config
sudo cp nginx.conf /etc/nginx/sites-available/errordon
sudo ln -s /etc/nginx/sites-available/errordon /etc/nginx/sites-enabled/

# Get SSL certificate
sudo certbot --nginx -d errordon.example.com

# Test & reload
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Create Admin User

```bash
docker compose exec web tootctl accounts create admin --email=admin@example.com --confirmed --role=Owner
```

## Errordon-Specific Settings

### Upload Limits (250MB)

Already configured in `.env.production`:
- `MAX_VIDEO_SIZE=262144000`
- `MAX_AUDIO_SIZE=262144000`

nginx already set to `client_max_body_size 250m;`

### Privacy Defaults

Pre-configured for privacy-conscious defaults:
- Default visibility: `unlisted`
- Profile indexing: disabled
- Search federation: disabled
- IP retention: 7 days

## Maintenance

### Updates

```bash
cd errordon
git pull origin master
docker compose pull
docker compose up -d
docker compose exec web bundle exec rake db:migrate
docker compose exec web bundle exec rake assets:precompile
docker compose restart
```

### Backups

```bash
# Database
docker compose exec db pg_dump -U postgres mastodon_production > backup.sql

# Media (if local storage)
tar -czf media_backup.tar.gz /var/lib/docker/volumes/deploy_mastodon_public
```

### Logs

```bash
docker compose logs -f web
docker compose logs -f sidekiq
```

## Troubleshooting

### Check Service Health

```bash
docker compose ps
docker compose logs --tail=100 web
```

### Restart Services

```bash
docker compose restart web sidekiq streaming
```

### Clear Cache

```bash
docker compose exec web tootctl cache clear
```

## NSFW-Protect AI Moderation

### Enable NSFW-Protect

1. **Install Ollama** (on host, not in Docker):
```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llava    # Image analysis (3.8GB)
ollama pull llama3   # Text analysis (4.7GB)
```

2. **Configure in `.env.production`**:
```bash
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://host.docker.internal:11434
ERRORDON_NSFW_ADMIN_EMAIL=admin@example.com
```

3. **Initialize NSFW-Protect**:
```bash
docker compose exec web bundle exec rake errordon:nsfw_protect:setup
```

### Features

| Feature | Description |
|---------|-------------|
| AI Image Analysis | Detects porn, CSAM, hate symbols |
| AI Text Analysis | Detects hate speech, threats |
| Domain Blocklist | 150k+ porn domains (auto-updated) |
| Strike System | Escalating bans (warning → freeze → permanent) |
| Admin Alerts | Email on violations, CSAM, instance freeze |
| IP Logging | For law enforcement reports |
| GDPR Compliant | Auto-cleanup of personal data |

### Scheduled Jobs (automatic via Sidekiq)

| Job | Schedule | Purpose |
|-----|----------|---------|
| Blocklist Update | 3:00 AM | Update porn domain list |
| GDPR Cleanup | 4:00 AM | Anonymize IPs, delete expired strikes |
| AI Snapshot Cleanup | 4:30 AM | Delete SAFE snapshots after 14 days |
| Video Cleanup | 5:00 AM | Shrink old videos to 480p (if enabled) |
| Freeze Cleanup | Hourly | Unfreeze expired accounts |
| Weekly Summary | Mon 9 AM | Email stats to admin |

### Evidence Emails

When violations are detected, admins receive emails with:
- `{username}_{date}_{time}_evidence.json` - Machine-readable report
- `{username}_{date}_{time}_evidence.txt` - Human-readable report
- SHA256 hashes for court-admissibility
- For CSAM: Original media file attached for BKA reporting

---

## Matrix Terminal Landing Page

An interactive Matrix-style terminal as landing page for new visitors.

### Enable During Installation

```bash
# Quick install with Matrix Terminal
curl -sSL https://raw.githubusercontent.com/error-wtf/errordon/main/deploy/quick-install.sh | bash -s -- --domain your.domain.com --with-matrix

# Or with deploy script
./deploy.sh  # Answer "y" when asked about Matrix Terminal
```

### Enable Manually

```bash
# Via Rails console
docker compose exec web bundle exec rails runner "Setting.landing_page = 'matrix'"

# Or in Admin UI:
# Admin → Server Settings → Branding → Landing Page → "Matrix Terminal"
```

### Terminal Commands

| Command | Action |
|---------|--------|
| `enter matrix` | Access login page |
| `register` | Go to signup |
| `about` | About Errordon |
| `tetris` | Play Tetris game |
| `quote` | Random Matrix quote |
| `hack` | Hack simulation |
| `talk <name>` | Chat with Neo, Trinity, Morpheus, Smith, Oracle |
| `rain` | Toggle Matrix rain |
| `help` | Show all commands |

### Features

- 🎮 Built-in Tetris game
- 🌧️ Animated Matrix rain background
- 💬 Interactive character dialogues
- 🔓 "enter matrix" command to access network
- 📝 "register" command for new users
- ℹ️ "about" command with instance info

---

## Matrix Theme

Enable the animated Matrix rain background:

```bash
# In .env.production
ERRORDON_MATRIX_THEME_ENABLED=true
```

Or toggle per-user with `Ctrl+Shift+M` in browser.

Features:
- Animated Matrix rain background
- Semi-transparent UI overlays
- Matrix green (#00ff00) color scheme

---

## One-Line Install

For a fresh Ubuntu 22.04 VPS:

```bash
curl -sSL https://raw.githubusercontent.com/error-wtf/errordon/main/deploy/quick-install.sh | bash -s -- --domain your.domain.com
```

---

## Post-Install Verification

```bash
# Check all services are running
docker compose ps

# Test web interface
curl -I https://your.domain.com

# Check NSFW-Protect (if enabled)
docker compose exec web bundle exec rake errordon:nsfw_protect:blocklist_stats

# Check Sidekiq jobs
docker compose exec web bundle exec rake sidekiq:cron:status
```

---

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Service definitions |
| `.env.production` | Configuration |
| `nginx.conf` | Reverse proxy |
| `quick-install.sh` | One-line installer |
| `backup.sh` | Automated backups |
| `update.sh` | Update script |
