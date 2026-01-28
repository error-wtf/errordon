# PHASE -1: Foundation Report

**Date:** 2026-01-28
**Task:** Codebase analysis and helper artifact creation (READ-ONLY phase)

---

## 1. Repository Overview

| Item | Value |
|------|-------|
| **Repo Path** | `E:\clone\errordon` |
| **Base** | Mastodon v4.5.5 fork |
| **Primary Features** | NSFW-Protect AI, Matrix Theme, 127 Custom Emojis, 250MB Uploads |
| **Build System** | Vite (replaced Webpacker) |
| **Backend** | Ruby on Rails 7.x |
| **Frontend** | React + TypeScript |
| **Job Queue** | Sidekiq |
| **Database** | PostgreSQL 14 |
| **Cache** | Redis 7 |

---

## 2. Key Entry Points

### Backend (Rails)
| Type | Path | Purpose |
|------|------|---------|
| Web | `config.ru` → `config/puma.rb` | Puma web server |
| Background | `bundle exec sidekiq` | Job processing |
| Streaming | `streaming/index.js` | WebSocket server |
| Console | `bin/rails console` | Debug/admin |
| CLI | `bin/tootctl` | Admin commands |

### Frontend (Vite)
| Entrypoint | Path | Purpose |
|------------|------|---------|
| `application.ts` | `app/javascript/entrypoints/` | Main Mastodon SPA |
| `common.ts` | `app/javascript/entrypoints/` | Shared + Matrix theme init |
| `admin.tsx` | `app/javascript/entrypoints/` | Admin panel |
| `public.tsx` | `app/javascript/entrypoints/` | Public pages |
| `embed.tsx` | `app/javascript/entrypoints/` | Embed widgets |

---

## 3. Errordon-Specific Components

### Controllers (`app/controllers/api/v1/errordon/`)
- `gdpr_controller.rb` - DSGVO Export/Delete
- `invite_codes_controller.rb` - Invite Management
- `nsfw_protect_controller.rb` - NSFW Admin API
- `quotas_controller.rb` - Storage Quotas
- `storage_quota_controller.rb` - User Storage
- `transcoding_controller.rb` - Video Status

### Services (`app/services/errordon/`)
- `ollama_content_analyzer.rb` - AI content moderation
- `media_upload_checker.rb` - NSFW-Protect integration
- `video_transcoder_service.rb` - Video processing
- `storage_quota_service.rb` - Dynamic disk quotas
- `security_service.rb` - File validation
- `audit_logger.rb` - Security logging

### Workers (`app/workers/errordon/`)
- `nsfw_check_worker.rb` - On upload AI check
- `media_transcode_worker.rb` - Video transcoding
- `video_cleanup_worker.rb` - Daily 5AM cleanup
- `gdpr_cleanup_worker.rb` - Daily 4AM GDPR
- `blocklist_update_worker.rb` - Daily 3AM update

---

## 4. Media & Profile Code Locations

### Upload Limits
| Constant | File | Current Value |
|----------|------|---------------|
| `IMAGE_LIMIT` | `app/models/media_attachment.rb:43` | 16 MB |
| `VIDEO_LIMIT` | `app/models/media_attachment.rb:44` | 99 MB |
| `client_max_body_size` | `deploy/nginx.conf` | 250m |

### Profile Rendering
- **Controller:** `app/controllers/api/v1/accounts/statuses_controller.rb`
- **Filter Logic:** `AccountStatusesFilter` (uses `params` including `only_media`)
- **Frontend:** `app/javascript/mastodon/features/account_timeline/`

### Media Attachments
- **Model:** `app/models/media_attachment.rb`
- **Types:** `image`, `gifv`, `video`, `unknown`, `audio` (enum)
- **Processing:** `app/workers/post_process_media_worker.rb`

### Transcoding
- **Errordon Service:** `app/services/errordon/video_transcoder_service.rb`
- **Errordon Worker:** `app/workers/errordon/media_transcode_worker.rb`
- **Base Transcoder:** `app/lib/paperclip/transcoder.rb`

---

## 5. Matrix Landing / Static Pages

### Location
- **Path:** `public/matrix/`
- **Files:** `index.html`, `tetris.html`, `talk_db_*.json`

### Key Finding
The Matrix terminal (`public/matrix/index.html`) is a **standalone HTML file** with:
- Inline CSS (no external stylesheet)
- Inline JavaScript (no external JS file)
- No dependency on Mastodon CSS/JS bundles
- Self-contained Matrix rain animation
- Commands: `enter matrix`, `tetris`, `talk`, `quote`, `hack`, `help`

### Reference Implementation
- **Path:** `E:\clone\matrix-full\`
- Contains source files: `main.js`, `main.css`, component JS files
- Used as reference for the terminal, but errordon uses inlined version

---

## 6. API Routes (Errordon-specific)

```
/api/v1/errordon/quotas/current       GET   - User quota stats
/api/v1/errordon/storage_quota        GET   - Dynamic disk-based quota
/api/v1/errordon/quotas               GET   - Admin: All user quotas
/api/v1/errordon/quotas/:id           GET/PUT - Admin: User quota details
/api/v1/errordon/transcoding/:id/status GET - Transcoding status
/api/v1/errordon/nsfw_protect/stats   GET   - NSFW-Protect statistics
/api/v1/errordon/invite_codes         CRUD  - Invite code management
/api/v1/errordon/gdpr/export          POST  - GDPR data export
/api/v1/errordon/gdpr/delete          DELETE - GDPR data deletion
```

---

## 7. Build & Test Commands

### Ruby/Rails
```bash
bundle install                    # Install gems
bundle exec rails db:migrate      # Run migrations
bundle exec rails assets:precompile # Build assets (uses Vite)
bundle exec rspec                 # Run tests
bundle exec rails c               # Console
```

### JavaScript/Vite
```bash
corepack enable && yarn install   # Install JS deps
yarn build                        # Production build
yarn dev                          # Dev server (port 3036)
yarn test                         # Vitest tests
```

### Docker
```bash
docker compose build              # Build images
docker compose up -d              # Start services
docker compose exec web bin/rails db:setup
docker compose logs -f web        # View logs
```

---

## 8. Configuration Files

| File | Purpose |
|------|---------|
| `.env.production` | Production environment vars |
| `config/initializers/errordon_*.rb` | Feature configs |
| `config/routes/errordon.rb` | API routes |
| `vite.config.mts` | Vite build config |
| `docker-compose.yml` | Docker services |
| `deploy/nginx.conf` | Nginx config |

---

## 9. Known Hazards

1. **Lockfile Sensitivity** - `Gemfile.lock` and `yarn.lock` must stay in sync with CI
2. **Migration Order** - Errordon migrations depend on base Mastodon tables
3. **Ollama Dependency** - NSFW-Protect requires Ollama running on port 11434
4. **Docker Volumes** - `postgres14/` can become root-owned, blocking cleanup
5. **Vite Build** - Replaces Webpacker; asset paths changed in v4.5+

---

## 10. Existing Documentation

| Doc | Content |
|-----|---------|
| `ARCH_MAP_MEDIA_AND_PROFILE.md` | Media/profile code locations |
| `ERRORDON_INVENTORY.md` | Component inventory |
| `NSFW_PROTECT_ARCHITECTURE.md` | AI moderation system |
| `STORAGE_QUOTA.md` | Dynamic quotas |
| `TRANSCODING_PIPELINE.md` | Video processing |
| `GDPR_COMPLIANCE.md` | Data retention |

---

## Summary

The errordon repo is a well-structured Mastodon fork with:
- Clear separation of Errordon-specific code (`app/*/errordon/`)
- Comprehensive documentation in `docs/`
- Docker-first deployment strategy
- Vite-based modern frontend build

**Next Step:** Proceed to PHASE 0 (planning)
