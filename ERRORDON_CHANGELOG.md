# Errordon Changelog

All notable changes to the Errordon fork are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [0.3.0] - 2026-01-24

### Fixed
- **TranscodingController**: Added missing controller for `/api/v1/errordon/transcoding/:media_id/status`
- **QuotasController**: Fixed to use user settings instead of non-existent database field
- **QuotaService**: Added support for admin-defined custom quotas per user
- **Routes**: Errordon routes now properly included in main `routes.rb`
- **Transcoding Services**: Added missing `require 'open3'` and `require 'fileutils'`
- **React Components**: Added proper `import type React` for TypeScript compatibility

### Added
- **Transcoding Status API**: `GET /api/v1/errordon/transcoding/:media_id/status`
- **Custom Quota Support**: Admins can set per-user storage quotas
- **Audit Logging**: Quota changes logged via `AuditLogger`

### Changed
- Version bumped to 0.3.0
- Improved error handling in controllers

---

## [0.2.0] - 2026-01-24

### Added - Matrix Theme & Custom Emojis
- **Matrix Theme**: Cyberpunk green UI with glitch effects
  - Toggle via `Ctrl+Shift+M`
  - VT323 hacker font
  - 100% Fediverse-compatible (opt-in only)
- **25 Custom Emojis**: Matrix/Hacker/Nerd themed SVGs
  - Categories: Matrix, Hacker, Nerd
  - Import via `rails errordon:import_emojis`

### Added - Phase 2: Uploads & Transcoding
- **Upload Limits**: Configurable 250MB video/audio uploads via `ERRORDON_UPLOAD_LIMITS=true`
- **Transcoding Pipeline**: Server-side ffmpeg transcoding with Sidekiq worker
  - 720p default variant (2.5 Mbps H.264)
  - 480p mobile variant (1.0 Mbps H.264)
  - Automatic thumbnail generation
- **Quota System**: Rate limiting and per-user storage quotas
  - `ERRORDON_QUOTA_ENABLED=true`
  - Configurable max storage per user
  - Upload rate limits per hour
- **Database Migration**: New fields for transcoding status and variants

### Files Added
- `config/initializers/errordon_upload_limits.rb`
- `config/initializers/errordon_transcoding.rb`
- `config/initializers/errordon_quotas.rb`
- `app/workers/errordon/media_transcode_worker.rb`
- `db/migrate/20260124000001_add_errordon_transcoding_fields.rb`

## [0.1.0] - 2026-01-24

### Added - Phase 1: UI & API
- **API Enhancement**: `media_type` filter parameter for account statuses
  - `?media_type=video` - Only video attachments
  - `?media_type=audio` - Only audio attachments
  - `?media_type=image` - Only image attachments
- **Profile Tabs**: Separate tabs for Videos, Audio, Images on user profiles
- **MediaFilterBar Component**: Filter chips for media gallery
  - "Originals only" - Hide reblogs/boosts
  - "With alt text" - Only media with descriptions
  - "Public only" - Only publicly visible posts
- **Instagram-style Grid**: 3-column layout with hover effects and type badges
- **Privacy Preset**: Strict privacy-first defaults via ENV
  - `ERRORDON_PRIVACY_PRESET=strict`
  - Default visibility: unlisted
  - Default discoverable: false
  - Default indexable: false

### Files Added/Modified
- `app/javascript/mastodon/features/account_gallery/components/media_filter_bar.tsx`
- `app/javascript/mastodon/features/account_gallery/index.tsx`
- `app/javascript/styles/mastodon/components.scss` (grid styles)
- `config/initializers/errordon_privacy_preset.rb`

### Documentation
- `docs/ARCH_MAP_MEDIA_AND_PROFILE.md` - Code architecture analysis
- `docs/FEATURES/` - Feature specifications
- `docs/UPLOAD_250MB_CONFIG.md` - Upload configuration guide
- `docs/TRANSCODING_PIPELINE.md` - Transcoding documentation
- `docs/PRIVACY_SETTINGS.md` - Privacy configuration

### Deployment
- `install.sh` - One-liner Linux installation script
- `deploy/deploy.sh` - Production deployment script
- `deploy/backup.sh` - Backup script (cron-ready)
- `deploy/update.sh` - Zero-downtime update script
- `deploy/errordon.service` - Systemd service file
- `deploy/nginx.conf` - Nginx configuration
- `deploy/docker-compose.yml` - Docker setup
- `deploy/.env.example` - Environment template

---

## Compatibility

- **Base**: Mastodon v4.3.x
- **Federation**: 100% compatible with Fediverse
- **API**: Backward compatible, additive changes only
- **ActivityPub**: No modifications to federation protocol

## Environment Variables

### Phase 1
```bash
ERRORDON_PRIVACY_PRESET=strict|standard
ERRORDON_DEFAULT_VISIBILITY=unlisted|public|private
ERRORDON_DEFAULT_DISCOVERABLE=false|true
ERRORDON_DEFAULT_INDEXABLE=false|true
ERRORDON_DEFAULT_HIDE_NETWORK=true|false
```

### Phase 2
```bash
ERRORDON_UPLOAD_LIMITS=true|false
MAX_VIDEO_SIZE=262144000
MAX_AUDIO_SIZE=262144000
ERRORDON_TRANSCODING_ENABLED=true|false
ERRORDON_TRANSCODE_480P=true|false
ERRORDON_DELETE_ORIGINALS=false|true
ERRORDON_QUOTA_ENABLED=true|false
ERRORDON_MAX_STORAGE_GB=10
ERRORDON_MAX_UPLOADS_HOUR=20
```

### Phase 3 (0.3.0)
```bash
ERRORDON_THEME=matrix|default|light
ERRORDON_AUDIT_FILE=true|false
ERRORDON_AUDIT_WEBHOOK_URL=https://...
ERRORDON_SECURITY_STRICT=true|false
ERRORDON_BLOCK_SUSPICIOUS_IPS=true|false
```

---

## File Reference

### Controllers
| File | Purpose |
|------|--------|
| `quotas_controller.rb` | Quota management API |
| `transcoding_controller.rb` | Transcoding status API |

### Services
| File | Purpose |
|------|--------|
| `quota_service.rb` | Storage/rate limit calculations |
| `security_service.rb` | File validation, malware detection |
| `audit_logger.rb` | Security event logging |
| `video_transcoder_service.rb` | ffmpeg video transcoding |
| `audio_transcoder_service.rb` | ffmpeg audio transcoding |
| `media_validator.rb` | MIME type validation |

### Initializers
| File | Purpose |
|------|--------|
| `errordon_privacy_preset.rb` | Privacy defaults |
| `errordon_upload_limits.rb` | File size limits |
| `errordon_transcoding.rb` | Transcoding config |
| `errordon_quotas.rb` | Quota settings |
| `errordon_security.rb` | Security settings |
| `errordon_theme.rb` | Theme config |
