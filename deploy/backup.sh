#!/bin/bash
#
# Errordon Backup Script v1.2.0
# Creates database, redis, and media backups
#
# Usage: ./backup.sh [--full]
# Cron:  0 3 * * * /home/errordon/errordon/deploy/backup.sh >> /var/log/errordon-backup.log 2>&1
#
# Options:
#   --full    Include media files (can be large!)
#

set -euo pipefail

# Configuration
BACKUP_DIR="${ERRORDON_BACKUP_DIR:-/home/errordon/backups}"
ERRORDON_DIR="${ERRORDON_DIR:-/home/errordon/errordon}"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${ERRORDON_BACKUP_RETENTION:-7}
FULL_BACKUP=false

# Parse arguments
[[ "${1:-}" == "--full" ]] && FULL_BACKUP=true

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }

mkdir -p "$BACKUP_DIR"

log "Starting Errordon backup..."

# Database backup
log "Backing up PostgreSQL database..."
if docker compose -f "$ERRORDON_DIR/docker-compose.yml" exec -T db \
    pg_dump -U mastodon mastodon_production 2>/dev/null | gzip > "$BACKUP_DIR/db_$DATE.sql.gz"; then
    log "Database backup: $(du -h "$BACKUP_DIR/db_$DATE.sql.gz" | cut -f1)"
else
    warn "Database backup failed - check if containers are running"
fi

# Redis backup
log "Backing up Redis..."
if docker compose -f "$ERRORDON_DIR/docker-compose.yml" exec -T redis \
    redis-cli BGSAVE &>/dev/null; then
    sleep 2  # Wait for BGSAVE to complete
    if [ -f "$ERRORDON_DIR/redis/dump.rdb" ]; then
        cp "$ERRORDON_DIR/redis/dump.rdb" "$BACKUP_DIR/redis_$DATE.rdb"
        log "Redis backup: $(du -h "$BACKUP_DIR/redis_$DATE.rdb" | cut -f1)"
    fi
else
    warn "Redis backup skipped"
fi

# Media files (only with --full flag)
if [ "$FULL_BACKUP" = true ] && [ -d "$ERRORDON_DIR/public/system" ]; then
    log "Backing up media files (this may take a while)..."
    tar -czf "$BACKUP_DIR/media_$DATE.tar.gz" -C "$ERRORDON_DIR/public" system
    log "Media backup: $(du -h "$BACKUP_DIR/media_$DATE.tar.gz" | cut -f1)"
fi

# Backup .env.production (secrets)
if [ -f "$ERRORDON_DIR/.env.production" ]; then
    cp "$ERRORDON_DIR/.env.production" "$BACKUP_DIR/env_$DATE.backup"
    chmod 600 "$BACKUP_DIR/env_$DATE.backup"
    log "Environment backup created"
fi

# Cleanup old backups
log "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -delete

log "Backup complete!"
echo ""
echo "Backup directory: $BACKUP_DIR"
ls -lh "$BACKUP_DIR" | tail -10
