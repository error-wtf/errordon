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

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Service definitions |
| `.env.production` | Configuration |
| `nginx.conf` | Reverse proxy |
