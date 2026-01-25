# Errordon Fork - Inventarliste

**Stand:** 2026-01-25

## Komponenten-Übersicht

| Kategorie | Anzahl | Pfad |
|-----------|--------|------|
| API Controller | 6 | `app/controllers/api/v1/errordon/` |
| Services | 14 | `app/services/errordon/` |
| Workers | 8 | `app/workers/errordon/` |
| Models | 5 | `app/models/` |
| Mailer | 1 | `app/mailers/errordon/` |
| Mail-Templates | 6 | `app/views/errordon/` |
| Initializers | 8 | `config/initializers/` |
| Locales | 6 | `config/locales/` |
| Migrations | 4 | `db/migrate/` |
| Rake Tasks | 3 | `lib/tasks/` |
| Tests | 7 | `spec/` |
| Docs | 14 | `docs/` |
| Emojis | 127 | `public/emoji/errordon/` |
| Matrix Terminal | 10 | `public/matrix/` |
| SCSS Theme | 641 Zeilen | `app/javascript/styles/` |
| Install Script | 724 Zeilen | `install.sh` |

## Controller
- `gdpr_controller.rb` - DSGVO Export/Delete
- `invite_codes_controller.rb` - Invite Management
- `nsfw_protect_controller.rb` - NSFW Admin API
- `quotas_controller.rb` - Storage Quotas
- `storage_quota_controller.rb` - User Storage
- `transcoding_controller.rb` - Video Status

## Services
- `audio_transcoder_service.rb`
- `audit_logger.rb`
- `domain_blocklist_service.rb`
- `gdpr_compliance_service.rb`
- `media_upload_checker.rb`
- `media_validator.rb`
- `nsfw_audit_logger.rb`
- `nsfw_strike_service.rb`
- `ollama_content_analyzer.rb`
- `quota_service.rb`
- `security_service.rb`
- `storage_quota_service.rb`
- `video_cleanup_service.rb`
- `video_transcoder_service.rb`

## Workers (Sidekiq)
- `blocklist_update_worker.rb` - Daily 3 AM
- `gdpr_cleanup_worker.rb` - Daily 4 AM
- `media_transcode_worker.rb` - On Upload
- `nsfw_check_worker.rb` - On Upload
- `nsfw_freeze_cleanup_worker.rb` - Hourly
- `snapshot_cleanup_worker.rb` - Daily 4:30 AM
- `video_cleanup_worker.rb` - Daily 5 AM
- `weekly_summary_worker.rb` - Monday 9 AM

## Models
- `errordon_invite_code.rb`
- `nsfw_analysis_snapshot.rb`
- `nsfw_protect_config.rb`
- `nsfw_protect_freeze.rb`
- `nsfw_protect_strike.rb`

## Locales (6 Sprachen)
- EN, DE, FR, ES, IT, PT

## Tests (7 Specs)
- 2 Controller Specs
- 2 Initializer Specs
- 3 Service Specs

## Matrix Terminal Features
- Login Screen
- 10+ Commands (help, tetris, talk, quote, hack, enter matrix)
- Tetris Spiel
- 6 Dialog-Charaktere
- Matrix Rain Animation
