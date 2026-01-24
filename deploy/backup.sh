#!/bin/bash
#
# Errordon Backup Script
# Creates database and media backups
#
# Usage: ./backup.sh
# Cron: 0 3 * * * /home/mastodon/errordon/deploy/backup.sh
#

set -e

BACKUP_DIR="/home/mastodon/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p $BACKUP_DIR

echo "[$(date)] Starting backup..."

# Database backup
echo "Backing up database..."
docker compose -f /home/mastodon/errordon/docker-compose.yml exec -T db \
    pg_dump -U mastodon mastodon_production | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Redis backup (optional)
echo "Backing up Redis..."
docker compose -f /home/mastodon/errordon/docker-compose.yml exec -T redis \
    redis-cli BGSAVE
cp /home/mastodon/errordon/redis/dump.rdb $BACKUP_DIR/redis_$DATE.rdb 2>/dev/null || true

# Media files (if local storage)
if [ -d "/home/mastodon/errordon/public/system" ]; then
    echo "Backing up media files..."
    tar -czf $BACKUP_DIR/media_$DATE.tar.gz -C /home/mastodon/errordon/public system
fi

# Cleanup old backups
echo "Cleaning up old backups..."
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Backup complete!"
echo "Files in $BACKUP_DIR:"
ls -lh $BACKUP_DIR
