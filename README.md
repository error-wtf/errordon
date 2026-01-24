# Errordon

[![Fediverse Compatible](https://img.shields.io/badge/Fediverse-Compatible-blueviolet)](https://joinmastodon.org/)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-0.3.0-green.svg)](https://github.com/error-wtf/errordon)

A **Mastodon fork** with enhanced media features, cyberpunk aesthetics, and privacy-first defaults.

**Features:**
- 🎬 **Profile Media Tabs** - Videos/Audio/Images
- 🎨 **Matrix Theme** - Cyberpunk green UI (opt-in)
- 😎 **25 Custom Emojis** - Matrix/Hacker/Nerd themed
- 📤 **250MB Uploads** - With server-side transcoding
- 🔒 **Privacy-First** - Strict defaults via ENV
- ✅ **100% Fediverse Compatible**

> **Release:** `errordon-0.3.0` - Bug Fixes + API Improvements

## ✅ Implemented Features

| Feature | Status | Description |
|---------|--------|-------------|
| **API: media_type filter** | ✅ | `?media_type=video\|audio\|image` |
| **Profile Tabs** | ✅ | Videos/Audio/Images tabs on profiles |
| **MediaFilterBar** | ✅ | Originals only, With alt text, Public only |
| **Instagram Grid** | ✅ | 3-column layout with hover effects |
| **Privacy Preset** | ✅ | Strict defaults via ENV config |
| **Deploy Templates** | ✅ | Docker Compose, Nginx, .env |
| **Matrix Theme** | ✅ | Cyberpunk green theme (Fediverse-compatible) |
| **Custom Emojis** | ✅ | 25 Matrix/Hacker/Nerd emojis |
| **Transcoding API** | ✅ | `/api/v1/errordon/transcoding/:id/status` |
| **Quota Management** | ✅ | Admin API for user quotas |
| **Security Layer** | ✅ | File validation, rate limiting, audit logging |

## 🎨 Matrix Theme

Errordon includes an optional **Matrix-style cyberpunk theme** with:

- **Green neon color palette** (`#00ff00`)
- **VT323 hacker font** for headings (UTF-8 compatible)
- **Glitch effects** on hover
- **Dark background** with white text for readability
- **100% Fediverse-compatible** (opt-in, no structural changes)

### Toggle Theme

```
Keyboard: Ctrl + Shift + M
```

Or set default via environment:
```bash
ERRORDON_THEME=matrix  # Options: matrix, default, light
```

## 😎 Custom Emojis

25 Matrix/Hacker/Nerd themed emojis in 3 categories:

| Category | Emojis |
|----------|--------|
| **Matrix** | `:matrix_code:` `:red_pill:` `:blue_pill:` `:skull_matrix:` `:matrix_cat:` `:glitch:` |
| **Hacker** | `:hacker:` `:terminal:` `:binary:` `:encrypt:` `:access_granted:` `:access_denied:` `:anonymous:` `:wifi_hack:` `:firewall:` `:sudo:` |
| **Nerd** | `:nerd:` `:keyboard:` `:code:` `:bug:` `:cyber_eye:` `:robot:` `:coffee_code:` `:git:` `:loading:` |

### Import Emojis

```bash
bundle exec rails errordon:import_emojis
```

## 🔧 API Endpoints

### Errordon-specific APIs

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/errordon/quotas/current` | GET | Current user's quota stats |
| `/api/v1/errordon/quotas` | GET | Admin: All user quotas |
| `/api/v1/errordon/quotas/:id` | GET/PUT | Admin: User quota details/update |
| `/api/v1/errordon/transcoding/:media_id/status` | GET | Transcoding status for media |

### Enhanced Mastodon APIs

| Endpoint | Enhancement |
|----------|-------------|
| `/api/v1/accounts/:id/statuses` | New `media_type` param: `video\|audio\|image` |

## 🎯 Goals

- **Profile Media Columns**: Separate tabs for Videos, Audio, Images in user profiles
- **Filter UI**: Filter by "originals only", "with alt text", visibility
- **Large Uploads**: Up to 250MB for video/audio with automatic transcoding
- **Privacy Defaults**: Strict preset inspired by chaos.social principles

## 📁 Repository Structure

```
errordon/
├── app/
│   ├── controllers/api/v1/errordon/     # Errordon API controllers
│   │   ├── quotas_controller.rb          # Quota management
│   │   └── transcoding_controller.rb     # Transcoding status
│   ├── services/errordon/               # Business logic
│   │   ├── quota_service.rb              # Quota calculations
│   │   ├── security_service.rb           # File validation
│   │   ├── audit_logger.rb               # Security logging
│   │   ├── video_transcoder_service.rb   # Video transcoding
│   │   └── audio_transcoder_service.rb   # Audio transcoding
│   ├── workers/errordon/                # Background jobs
│   │   └── media_transcode_worker.rb     # Sidekiq worker
│   └── javascript/
│       ├── mastodon/features/errordon/   # React components
│       │   ├── matrix_theme.ts           # Theme controller
│       │   ├── admin_quotas.tsx          # Admin UI
│       │   └── video_grid.tsx            # Video grid
│       └── styles/errordon_matrix.scss   # Matrix theme styles
├── config/
│   ├── initializers/errordon_*.rb       # Feature configs
│   ├── routes/errordon.rb               # API routes
│   └── locales/errordon.*.yml           # Translations
├── public/emoji/errordon/               # 25 custom SVG emojis
├── lib/tasks/errordon_emojis.rake       # Emoji import task
├── deploy/                              # Production configs
├── docs/                                # Documentation
└── spec/initializers/                   # Tests
```

## Branching Strategy

| Branch | Purpose |
|--------|--------|
| `main` | Stable release (Phase 1 complete) |
| `master` | Development mirror |
| `develop` | Initial blueprint |

## Upstream Setup

This repo tracks the official Mastodon repository as upstream.

### Initial Setup (after cloning)

```bash
# Add upstream remote
git remote add upstream https://github.com/mastodon/mastodon.git

# Verify remotes
git remote -v
# origin    https://github.com/error-wtf/errordon.git (fetch)
# origin    https://github.com/error-wtf/errordon.git (push)
# upstream  https://github.com/mastodon/mastodon.git (fetch)
# upstream  https://github.com/mastodon/mastodon.git (push)
```

### Syncing with Upstream

```bash
# Fetch upstream changes
git fetch upstream

# Merge upstream into main (preferred for stability)
git checkout main
git merge upstream/main

# Or rebase develop onto upstream (cleaner history)
git checkout develop
git rebase upstream/main
```

### Update Policy

- **Weekly**: Check upstream for security patches
- **Monthly**: Full sync with upstream/main
- **Before release**: Ensure all feature branches rebase cleanly

## 🚀 Quick Start

### Linux (Ubuntu/Debian) - One-liner

```bash
curl -sSL https://raw.githubusercontent.com/error-wtf/errordon/main/install.sh | bash
```

### Manual Setup

See [docs/DEV_SETUP.md](docs/DEV_SETUP.md) for full instructions.

```bash
# Clone this repo
git clone https://github.com/error-wtf/errordon.git
cd errordon

# Run install script
chmod +x install.sh
./install.sh

# Or manually:
bundle install
yarn install
rails db:setup
foreman start
```

## 📋 Feature Roadmap

### Phase 1: UI + API ✅ Complete
- [x] Analyze Mastodon codebase → `docs/ARCH_MAP_MEDIA_AND_PROFILE.md`
- [x] API filter param `media_type=video|audio|image`
- [x] Frontend profile tabs: Videos, Audio, Images
- [x] Filter chips UI (Originals, Alt text, Public)
- [x] Instagram-style grid layout
- [x] Privacy preset "strict" via ENV

### Phase 2: Uploads + Transcoding ✅ Code Ready
- [x] Increase upload limit to 250MB (`config/initializers/errordon_upload_limits.rb`)
- [x] Server-side transcoding pipeline (`app/workers/errordon/media_transcode_worker.rb`)
- [x] Output variants: mobile (480p), default (720p)
- [x] Quota/rate-limit guardrails (`config/initializers/errordon_quotas.rb`)
- [ ] **Needs VPS to test live**

### Phase 3: Polish ✅ Complete
- [x] Audio player UX improvements (hover effects, waveform styles)
- [x] Video grid view (`features/errordon/video_grid.tsx`)
- [x] Admin UI for quotas (`features/errordon/admin_quotas.tsx`)

## 📜 License

AGPLv3 - Compatible with Mastodon's license.

## 🔗 References

- [Mastodon GitHub](https://github.com/mastodon/mastodon)
- [Mastodon Docs](https://docs.joinmastodon.org/)
- [Media API](https://docs.joinmastodon.org/methods/media/)
- [Admin Scaling](https://docs.joinmastodon.org/admin/scaling/)
