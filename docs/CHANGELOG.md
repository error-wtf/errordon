# Changelog

All notable changes to Errordon are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0] - 2026-01-29

### Added

- **Rich oEmbed Support**: hearthis.at, Spotify, Bandcamp, SoundCloud embeds now play directly in the UI
- **GDPR Self-Service**: Users can request account deletion via API (`/api/v1/errordon/gdpr/delete`)
- **Auto-Login on Email Confirmation**: Users are automatically signed in after confirming their email
- **Terms of Service Integration**: ToS and Privacy Policy links in navigation sidebar
- **DSGVO-Compliant Terms of Service**: Comprehensive German law compliant ToS template

### Changed

- **Matrix Rain Animation**: No longer freezes on scroll, only pauses when tab is hidden
- **Embed Processing**: `type: "rich"` oEmbed responses with iframes are now converted to `type: "video"` for playback

### Fixed

- Profile hover cards now use Matrix dark theme
- Media tabs styling improved for Matrix theme
- Audio/video player controls now white on dark background
- Preview card play buttons styled for Matrix theme

### Security

- Rich embeds are sanitized - only iframes allowed, scripts blocked
- GDPR deletion requests require password confirmation
- IP addresses anonymized in audit logs after 7 days

---

## [1.1.0] - 2026-01-28

### Added

- **Storage Quotas**: Dynamic fair-share storage system
  - Base quota: 1GB per user
  - Fair share: 60% of disk divided equally among active users
  - Admin override capability
  - Quota display in user profile

- **Matrix Theme Improvements**
  - VT323 font for headings (UTF-8 compatible)
  - Glitch effects on hover
  - Matrix rain background animation
  - 127 custom emojis

- **NSFW-Protect AI Enhancements**
  - Strike system with escalating consequences
  - Evidence email system for violations
  - Scheduled cleanup jobs
  - Instance-wide protection mode

### Changed

- Improved Docker deployment scripts
- Better error messages for quota limits
- Enhanced admin UI for quota management

### Fixed

- Video transcoding queue stability
- Memory usage in Sidekiq workers
- Search indexing for hashtags

---

## [1.0.0] - 2026-01-15

### Added

- **NSFW-Protect AI System**
  - Ollama-based image/video analysis
  - Automatic pornography detection
  - Hate symbol detection
  - CSAM detection with authority notification

- **Profile Media Tabs**
  - Separate Videos, Audio, Images tabs
  - Media type filtering API
  - Grid view for media

- **Matrix Terminal Theme**
  - Cyberpunk green UI
  - Interactive landing page
  - Toggle with Ctrl+Shift+M

- **Legal Compliance**
  - German/EU law framework
  - Terms of Service template
  - Privacy Policy template
  - Community Guidelines

- **Registration Security**
  - Invite-only mode
  - Age verification (18+)
  - Legal acceptance checkboxes

- **Large File Uploads**
  - 250MB upload limit
  - Server-side transcoding
  - Automatic video optimization

### Infrastructure

- Docker-based deployment
- OpenSearch integration
- Redis caching
- PostgreSQL 14

---

## Upgrade Notes

### From 1.1.x to 1.2.0

```bash
# Pull latest changes
git pull origin main

# Rebuild containers
docker compose build

# Run migrations
docker compose exec web bin/rails db:migrate

# Restart all services
docker compose up -d --force-recreate
```

### From 1.0.x to 1.1.0

```bash
# Database migration required
docker compose exec web bin/rails db:migrate

# New environment variables (optional)
ERRORDON_STORAGE_ENABLED=true
ERRORDON_STORAGE_BASE_QUOTA=1073741824
```

---

## Roadmap

### Planned for 1.3.0

- [ ] Federated blocklist sharing
- [ ] Improved AI model selection
- [ ] Multi-language ToS templates
- [ ] Mobile app deep linking improvements
- [ ] Admin dashboard enhancements

### Under Consideration

- ActivityPub relay support
- Custom emoji packs marketplace
- AI-assisted alt text generation
- Automated content warnings

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute to Errordon.
