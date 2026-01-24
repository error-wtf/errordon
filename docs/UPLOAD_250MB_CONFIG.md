# Upload Limit 250MB Configuration Guide

This document describes all configuration points needed to increase the upload limit to 250MB for video/audio files.

## Overview

Mastodon's default upload limits are conservative. To support longer tutorial videos (~1 hour), we need to increase limits at multiple layers:

1. **nginx** - Reverse proxy body size
2. **Rails** - Application-level validation
3. **Paperclip/ActiveStorage** - File attachment limits
4. **Sidekiq** - Job timeout for processing

## Configuration Changes

### 1. nginx Configuration

```nginx
# /etc/nginx/sites-available/mastodon
server {
    # ...existing config...
    
    # Increase max body size for uploads
    client_max_body_size 250m;
    
    # Increase timeouts for large uploads
    proxy_read_timeout 300s;
    proxy_send_timeout 300s;
    client_body_timeout 300s;
    
    # Buffer settings for large uploads
    client_body_buffer_size 128k;
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;
}
```

### 2. Rails Configuration

#### Environment Variables

```bash
# .env.production
MAX_VIDEO_SIZE=262144000      # 250MB in bytes
MAX_AUDIO_SIZE=262144000      # 250MB in bytes
MAX_IMAGE_SIZE=16777216       # 16MB (unchanged)
```

#### Application Config

```ruby
# config/initializers/upload_limits.rb
Rails.application.config.x.upload_limits = {
  video: ENV.fetch('MAX_VIDEO_SIZE', 262_144_000).to_i,
  audio: ENV.fetch('MAX_AUDIO_SIZE', 262_144_000).to_i,
  image: ENV.fetch('MAX_IMAGE_SIZE', 16_777_216).to_i
}
```

### 3. MediaAttachment Model

Location: `app/models/media_attachment.rb`

The `IMAGE_FILE_SIZE_LIMIT` and related constants need adjustment:

```ruby
# Current Mastodon defaults (approximate)
IMAGE_FILE_SIZE_LIMIT = 16.megabytes
VIDEO_FILE_SIZE_LIMIT = 99.megabytes  # Needs increase

# Errordon target
VIDEO_FILE_SIZE_LIMIT = 250.megabytes
AUDIO_FILE_SIZE_LIMIT = 250.megabytes
```

### 4. Sidekiq Job Configuration

For large video processing, increase job timeout:

```ruby
# config/sidekiq.yml
:concurrency: 5
:timeout: 600  # 10 minutes for transcoding jobs
```

### 5. Storage Considerations

#### Local Storage
- Ensure sufficient disk space (estimate: 500GB+ for active instance)
- Monitor disk usage alerts

#### S3/Object Storage
```bash
# .env.production
S3_ENABLED=true
S3_BUCKET=your-bucket
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
S3_REGION=eu-central-1
S3_PROTOCOL=https

# Optional: S3-compatible (MinIO, Wasabi)
S3_ENDPOINT=https://s3.wasabisys.com
```

## User Quotas (Recommended)

To prevent abuse, implement per-user quotas:

```ruby
# Suggested limits
MAX_STORAGE_PER_USER = 10.gigabytes
MAX_UPLOADS_PER_HOUR = 10
MAX_UPLOAD_SIZE_PER_DAY = 1.gigabyte
```

## Rate Limiting

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle('uploads/ip', limit: 10, period: 1.hour) do |req|
  req.ip if req.path.start_with?('/api/v1/media', '/api/v2/media')
end
```

## Monitoring

### Key Metrics
- Upload queue length (Sidekiq)
- Disk usage / S3 storage
- Transcoding job duration
- Failed upload rate

### Recommended Alerts
- Disk usage > 80%
- Queue length > 100 jobs
- Transcoding failure rate > 5%

## Federation Notes

⚠️ **Important**: Large media files may not federate well:
- Other instances may refuse to fetch large files
- Remote instances have their own size limits
- Consider transcoding to reduce file size before federation

## Files to Modify

| File | Change |
|------|--------|
| `nginx.conf` | `client_max_body_size 250m` |
| `.env.production` | `MAX_VIDEO_SIZE`, `MAX_AUDIO_SIZE` |
| `app/models/media_attachment.rb` | Size constants |
| `config/initializers/upload_limits.rb` | Create new |
| `config/sidekiq.yml` | Job timeout |

## Testing

1. Upload 250MB video file
2. Verify transcoding completes
3. Verify federation (thumbnail + URL)
4. Check storage usage
5. Test rate limits
