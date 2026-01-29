#!/bin/bash
#
# Errordon Update Script v1.2.0
# Updates to latest version with zero-downtime rolling restart
#
# Usage: ./update.sh [--skip-backup] [--branch BRANCH]
#
# Options:
#   --skip-backup    Skip backup before update
#   --branch NAME    Use specific branch (default: main)
#

set -euo pipefail

# Configuration
ERRORDON_DIR="${ERRORDON_DIR:-/home/errordon/errordon}"
BRANCH="main"
SKIP_BACKUP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-backup) SKIP_BACKUP=true; shift ;;
        --branch) BRANCH="$2"; shift 2 ;;
        *) shift ;;
    esac
done

cd "$ERRORDON_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     Errordon Update v1.2.0             ║"
echo "║     Branch: $BRANCH"
echo "╚════════════════════════════════════════╝"
echo ""

# Step 1: Backup
if [ "$SKIP_BACKUP" = false ]; then
    log "[1/7] Creating backup..."
    ./deploy/backup.sh || warn "Backup failed, continuing anyway"
else
    warn "[1/7] Skipping backup (--skip-backup)"
fi

# Step 2: Fetch latest
log "[2/7] Fetching latest changes..."
git fetch origin

# Check for local changes
if ! git diff --quiet; then
    warn "Local changes detected. Stashing..."
    git stash
fi

# Step 3: Pull changes
log "[3/7] Pulling $BRANCH branch..."
git checkout "$BRANCH"
git pull origin "$BRANCH"

# Step 4: Rebuild containers
log "[4/7] Rebuilding Docker images..."
docker compose build --pull

# Step 5: Run migrations
log "[5/7] Running database migrations..."
docker compose run --rm web bundle exec rake db:migrate

# Step 6: Precompile assets
log "[6/7] Precompiling assets..."
docker compose run --rm web bundle exec rake assets:precompile

# Step 7: Rolling restart
log "[7/7] Performing rolling restart..."
docker compose up -d --force-recreate --remove-orphans

# Wait for health checks
log "Waiting for services to be healthy..."
sleep 10

# Verify services
if docker compose ps | grep -q "unhealthy"; then
    error "Some services are unhealthy! Check: docker compose ps"
fi

echo ""
log "Update complete!"
echo ""
echo "Current version: $(git describe --tags 2>/dev/null || git rev-parse --short HEAD)"
echo "Check logs: docker compose logs -f"
echo "Check health: docker compose ps"
