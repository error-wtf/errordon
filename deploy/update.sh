#!/bin/bash
#
# Errordon Update Script
# Updates to latest version with zero-downtime
#
# Usage: ./update.sh
#

set -e

cd /home/mastodon/errordon

echo "╔════════════════════════════════════════╗"
echo "║     Errordon Update                    ║"
echo "╚════════════════════════════════════════╝"

# Backup first
echo "[1/6] Creating backup..."
./deploy/backup.sh

# Pull latest
echo "[2/6] Pulling latest changes..."
git fetch origin
git pull origin main

# Update dependencies
echo "[3/6] Updating dependencies..."
docker compose pull

# Run migrations
echo "[4/6] Running database migrations..."
docker compose run --rm web bundle exec rake db:migrate

# Precompile assets
echo "[5/6] Precompiling assets..."
docker compose run --rm web bundle exec rake assets:precompile

# Restart services (rolling)
echo "[6/6] Restarting services..."
docker compose up -d --force-recreate

echo ""
echo "✓ Update complete!"
echo ""
echo "Check logs: docker compose logs -f"
