# Video Cleanup Documentation

## Overview

Errordon automatically shrinks videos older than 7 days to 480p resolution to save disk space while maintaining acceptable quality for social media viewing.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    VIDEO CLEANUP PIPELINE                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   1. FIND OLD VIDEOS                                        │
│      └─ Older than 7 days                                   │
│      └─ Larger than 10 MB                                   │
│      └─ Not already shrunk                                  │
│                                                             │
│   2. TRANSCODE TO 480p                                      │
│      └─ ffmpeg -i input.mp4 -vf scale=-2:480                │
│      └─ CRF 28 (good quality/size balance)                  │
│      └─ libx264 codec                                       │
│                                                             │
│   3. REPLACE ORIGINAL                                       │
│      └─ Mark as shrunk (errordon_shrunk=true)               │
│      └─ Store original size for stats                       │
│      └─ ~40% space savings typical                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

```bash
# Enable automatic video cleanup
ERRORDON_VIDEO_CLEANUP_ENABLED=true

# Videos older than X days will be shrunk (default: 7)
ERRORDON_VIDEO_CLEANUP_DAYS=7

# Only shrink videos larger than X MB (default: 10)
ERRORDON_VIDEO_CLEANUP_MIN_SIZE_MB=10

# Process X videos per batch (default: 10)
ERRORDON_VIDEO_CLEANUP_BATCH_SIZE=10

# Dry run mode - no actual changes (default: false)
ERRORDON_VIDEO_CLEANUP_DRY_RUN=false
```

## Scheduled Job

- **Time**: Daily at 5:00 AM
- **Worker**: `Errordon::VideoCleanupWorker`
- **Queue**: `pull` (low priority)

## Rake Tasks

```bash
# Show video cleanup statistics
rake errordon:video:stats

# Dry run - show what would be cleaned
rake errordon:video:dry_run

# Run cleanup interactively
rake errordon:video:cleanup

# Shrink a single video by ID
rake errordon:video:shrink_one[123]
```

## Database Schema

New columns on `media_attachments`:

```ruby
add_column :media_attachments, :errordon_shrunk, :boolean, default: false
add_column :media_attachments, :errordon_shrunk_at, :datetime
add_column :media_attachments, :errordon_original_size, :bigint
```

## Space Savings

Typical results:

| Original | After 480p | Savings |
|----------|------------|---------|
| 100 MB | 40-60 MB | 40-60% |
| 50 MB | 20-30 MB | 40-60% |
| 250 MB | 100-150 MB | 40-60% |

## FFmpeg Parameters

```bash
ffmpeg -i input.mp4 \
  -vf "scale=-2:480" \
  -c:v libx264 \
  -preset medium \
  -crf 28 \
  -c:a aac \
  -b:a 128k \
  -movflags +faststart \
  output.mp4
```

Parameters explained:
- `scale=-2:480` - Scale to 480p height, maintain aspect ratio
- `libx264` - H.264 codec (universal compatibility)
- `preset medium` - Balance between speed and compression
- `crf 28` - Quality level (lower = better quality, larger file)
- `aac 128k` - Audio codec and bitrate
- `movflags +faststart` - Enable streaming playback

## Service Files

| File | Purpose |
|------|---------|
| `app/services/errordon/video_cleanup_service.rb` | Main cleanup logic |
| `app/workers/errordon/video_cleanup_worker.rb` | Sidekiq worker |
| `lib/tasks/errordon_video_cleanup.rake` | Rake tasks |
| `db/migrate/*_add_errordon_shrunk_to_media_attachments.rb` | Migration |

## Logging

Cleanup operations are logged:

```
[VIDEO-CLEANUP] Starting cleanup (dry_run=false)
[VIDEO-CLEANUP] Processing video ID=123, size=52428800
[VIDEO-CLEANUP] Shrunk ID=123: 50.0MB → 22.5MB (55% saved)
[VIDEO-CLEANUP] Cleanup complete: processed=10, shrunk=8, saved=150MB
```

## Exclusions

Videos are NOT shrunk if:
- Already at 480p or lower resolution
- Already marked as `errordon_shrunk=true`
- Smaller than `ERRORDON_VIDEO_CLEANUP_MIN_SIZE_MB`
- Younger than `ERRORDON_VIDEO_CLEANUP_DAYS`

## Rollback

There is no automatic rollback. Original files are replaced. If you need to preserve originals:

1. Enable S3 storage with versioning
2. Or set `ERRORDON_VIDEO_CLEANUP_DRY_RUN=true` first

## Requirements

- **ffmpeg** with libx264 support
- Sufficient temporary disk space for transcoding
- `tmp/errordon_cleanup/` directory (created by install scripts)
