# Errordon

A Mastodon fork adding **profile media tabs** (Videos/Audio/Images), **filter UI**, **250MB uploads** with server-side transcoding, and **privacy-first defaults**.

> **Release:** `errordon-0.1.0` - Phase 1 Complete ✅

## ✅ Implemented Features

| Feature | Status | Description |
|---------|--------|-------------|
| **API: media_type filter** | ✅ | `?media_type=video\|audio\|image` |
| **Profile Tabs** | ✅ | Videos/Audio/Images tabs on profiles |
| **MediaFilterBar** | ✅ | Originals only, With alt text, Public only |
| **Instagram Grid** | ✅ | 3-column layout with hover effects |
| **Privacy Preset** | ✅ | Strict defaults via ENV config |
| **Deploy Templates** | ✅ | Docker Compose, Nginx, .env |

## ⏳ Phase 2 (Needs VPS)

| Feature | Status | Description |
|---------|--------|-------------|
| **250MB Uploads** | 📄 Docs | Nginx + Rails config ready |
| **Transcoding** | 📄 Docs | ffmpeg pipeline documented |
| **Production** | ⏳ | Waiting for VPS |

## 🎯 Goals

- **Profile Media Columns**: Separate tabs for Videos, Audio, Images in user profiles
- **Filter UI**: Filter by "originals only", "with alt text", visibility
- **Large Uploads**: Up to 250MB for video/audio with automatic transcoding
- **Privacy Defaults**: Strict preset inspired by chaos.social principles

## 📁 Repository Structure

```
errordon/
├── docs/
│   ├── ARCH_MAP_MEDIA_AND_PROFILE.md    # Code architecture analysis
│   ├── FEATURES/
│   │   ├── profile-media-columns.md      # Tabs: Videos/Audio/Images
│   │   ├── media-filters-ui.md           # Filter chips & options
│   │   ├── upload-250mb.md               # Upload limit changes
│   │   ├── transcoding-pipeline.md       # ffmpeg/Sidekiq jobs
│   │   └── privacy-preset.md             # Strict privacy defaults
│   └── DEV_SETUP.md                      # Local development guide
├── .github/workflows/
│   └── ci.yml                            # Lint + test pipeline
├── LICENSE                               # AGPLv3 (Mastodon compatible)
├── CONTRIBUTING.md                       # How to contribute
└── README.md                             # This file
```

## 🔀 Branching Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, upstream-tracking |
| `develop` | Integration branch |
| `feature/profile-media-columns` | Videos/Audio/Images tabs |
| `feature/media-filters-ui` | Filter chips & options |
| `feature/upload-250mb-limits` | Upload size configuration |
| `feature/transcoding-pipeline` | ffmpeg processing jobs |
| `feature/privacy-chaos-defaults` | Strict privacy preset |

## 🔗 Upstream Setup

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

## 🚀 Quick Start (Local Development)

See [docs/DEV_SETUP.md](docs/DEV_SETUP.md) for full instructions.

```bash
# Clone this repo
git clone https://github.com/error-wtf/errordon.git
cd errordon

# Set up upstream
git remote add upstream https://github.com/mastodon/mastodon.git

# Install dependencies (requires Ruby, Node, Postgres, Redis)
bundle install
yarn install

# Setup database
rails db:setup

# Start development server
foreman start
```

## 📋 Feature Roadmap

### Phase 1: UI + API (No breaking changes)
- [ ] Analyze Mastodon codebase → `docs/ARCH_MAP_MEDIA_AND_PROFILE.md`
- [ ] API filter param `media_type=video|audio|image`
- [ ] Frontend profile tabs: Videos, Audio, Images
- [ ] Filter chips UI

### Phase 2: Uploads + Transcoding
- [ ] Increase upload limit to 250MB
- [ ] Server-side transcoding pipeline (Sidekiq + ffmpeg)
- [ ] Output variants: mobile (480p), default (720p)
- [ ] Quota/rate-limit guardrails

### Phase 3: Privacy + Polish
- [ ] Privacy preset "strict"
- [ ] Audio player UX improvements
- [ ] Video grid view
- [ ] Admin UI for quotas

## 📜 License

AGPLv3 - Compatible with Mastodon's license.

## 🔗 References

- [Mastodon GitHub](https://github.com/mastodon/mastodon)
- [Mastodon Docs](https://docs.joinmastodon.org/)
- [Media API](https://docs.joinmastodon.org/methods/media/)
- [Admin Scaling](https://docs.joinmastodon.org/admin/scaling/)
