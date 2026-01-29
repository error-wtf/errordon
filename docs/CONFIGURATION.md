# Errordon Configuration Reference

Complete reference for all Errordon configuration options.

---

## Table of Contents

1. [Environment Variables](#environment-variables)
2. [Core Mastodon Settings](#core-mastodon-settings)
3. [Errordon Features](#errordon-features)
4. [NSFW-Protect AI](#nsfw-protect-ai)
5. [Storage Quotas](#storage-quotas)
6. [Privacy Settings](#privacy-settings)
7. [Matrix Theme](#matrix-theme)
8. [Email Configuration](#email-configuration)
9. [Database & Cache](#database--cache)
10. [Federation](#federation)

---

## Environment Variables

All configuration is done via environment variables in `.env.production`.

### Quick Reference

```bash
# Generate this file
cp .env.production.sample .env.production
```

---

## Core Mastodon Settings

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `LOCAL_DOMAIN` | Your instance domain | `example.com` |
| `SECRET_KEY_BASE` | Rails secret key | `bundle exec rails secret` |
| `OTP_SECRET` | 2FA secret key | `bundle exec rails secret` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `SINGLE_USER_MODE` | Single-user instance | `false` |
| `AUTHORIZED_FETCH` | Require signatures | `false` |
| `LIMITED_FEDERATION_MODE` | Allowlist-only federation | `false` |
| `RAILS_LOG_LEVEL` | Log verbosity | `info` |

---

## Errordon Features

### Theme

| Variable | Description | Options | Default |
|----------|-------------|---------|---------|
| `ERRORDON_THEME` | UI theme | `matrix`, `default`, `light` | `matrix` |
| `ERRORDON_THEME_COLOR` | Accent color | `green`, `red`, `blue`, `purple` | `green` |

### Registration

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_INVITE_ONLY` | Require invite codes | `true` |
| `ERRORDON_REQUIRE_AGE_18` | Age verification checkbox | `true` |
| `ERRORDON_REQUIRE_TOS_ACCEPT` | ToS acceptance required | `true` |

### Uploads

| Variable | Description | Default |
|----------|-------------|---------|
| `MAX_VIDEO_SIZE` | Max video upload | `262144000` (250MB) |
| `MAX_IMAGE_SIZE` | Max image upload | `16777216` (16MB) |
| `MAX_AUDIO_SIZE` | Max audio upload | `52428800` (50MB) |

---

## NSFW-Protect AI

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_NSFW_PROTECT_ENABLED` | Enable AI moderation | `false` |
| `ERRORDON_NSFW_OLLAMA_ENDPOINT` | Ollama API URL | `http://localhost:11434` |
| `ERRORDON_NSFW_ADMIN_EMAIL` | Admin notification email | (required) |

### Detection Thresholds

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_NSFW_PORN_THRESHOLD` | Porn confidence threshold | `0.8` |
| `ERRORDON_NSFW_HATE_THRESHOLD` | Hate speech threshold | `0.7` |
| `ERRORDON_NSFW_VIOLENCE_THRESHOLD` | Violence threshold | `0.75` |

### Automatic Actions

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_NSFW_AUTO_DELETE` | Auto-delete flagged content | `true` |
| `ERRORDON_NSFW_AUTO_FREEZE` | Auto-freeze violating accounts | `true` |
| `ERRORDON_NSFW_AUTO_NOTIFY` | Email notifications | `true` |
| `ERRORDON_NSFW_AUTO_BAN_CSAM` | Immediate ban for CSAM | `true` |

### Strike System

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_NSFW_STRIKE_1_DURATION` | First strike freeze | `86400` (24h) |
| `ERRORDON_NSFW_STRIKE_2_DURATION` | Second strike freeze | `259200` (3d) |
| `ERRORDON_NSFW_STRIKE_3_DURATION` | Third strike freeze | `604800` (7d) |
| `ERRORDON_NSFW_STRIKE_4_DURATION` | Fourth strike freeze | `2592000` (30d) |
| `ERRORDON_NSFW_MAX_STRIKES` | Strikes before permaban | `5` |

### Models

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_NSFW_VISION_MODEL` | Image/video analysis | `llava` |
| `ERRORDON_NSFW_TEXT_MODEL` | Text analysis | `llama3` |

### Scheduled Jobs

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_NSFW_CLEANUP_HOUR` | Hour to run cleanup | `4` |
| `ERRORDON_NSFW_SNAPSHOT_RETENTION` | Days to keep snapshots | `14` |

---

## Storage Quotas

### Core Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_STORAGE_ENABLED` | Enable quota system | `true` |
| `ERRORDON_STORAGE_BASE_QUOTA` | Base quota per user (bytes) | `1073741824` (1GB) |
| `ERRORDON_STORAGE_MAX_QUOTA` | Maximum quota (bytes) | `10737418240` (10GB) |

### Fair Share System

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_STORAGE_FAIR_SHARE_PERCENT` | % of disk for fair share | `60` |
| `ERRORDON_STORAGE_RESERVED_DISK_PERCENT` | % of disk to keep free | `20` |
| `ERRORDON_STORAGE_ACTIVE_USER_DAYS` | Days for "active" user | `30` |

### Admin Overrides

```ruby
# Via Rails console
account = Account.find_by(username: 'user')
Errordon::StorageQuota.create!(
  account: account,
  custom_quota: 5.gigabytes,
  admin_notes: 'VIP user'
)
```

---

## Privacy Settings

### Presets

| Variable | Value | Description |
|----------|-------|-------------|
| `ERRORDON_PRIVACY_PRESET` | `STANDARD` | Mastodon defaults |
| | `STRICT` | chaos.social inspired |
| | `PARANOID` | Maximum privacy |

### STANDARD Preset (Default)

- Search engine indexing: Opt-in
- Profile directory: Enabled
- Trends: Enabled

### STRICT Preset

- Search engine indexing: Disabled
- Profile discovery: Opt-in
- Default post visibility: Unlisted
- Default profile privacy: Followers-only

### PARANOID Preset

- All above + Limited federation
- No public API access
- Minimal metadata exposure

### Individual Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_PRIVACY_INDEX_PROFILES` | Allow search engines | `false` |
| `ERRORDON_PRIVACY_DEFAULT_VISIBILITY` | Default post visibility | `public` |
| `ERRORDON_PRIVACY_DEFAULT_DISCOVERABLE` | Default discoverability | `true` |
| `ERRORDON_PRIVACY_LOG_IP_DAYS` | Days to retain IPs | `7` |

---

## Matrix Theme

### Appearance

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_THEME` | Theme name | `matrix` |
| `ERRORDON_THEME_COLOR` | Primary color | `green` |
| `ERRORDON_MATRIX_RAIN` | Enable rain animation | `true` |
| `ERRORDON_MATRIX_GLITCH` | Enable glitch effects | `true` |

### Fonts

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRORDON_MATRIX_FONT_HEADING` | Heading font | `VT323` |
| `ERRORDON_MATRIX_FONT_BODY` | Body font | `system-ui` |

### Custom CSS

For advanced customization, edit:
```
app/javascript/styles/errordon_matrix.scss
```

---

## Email Configuration

### SMTP Settings

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_SERVER` | SMTP hostname | `smtp.mailgun.org` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_LOGIN` | Username/API key | `postmaster@mg.example.com` |
| `SMTP_PASSWORD` | Password | `your-password` |
| `SMTP_FROM_ADDRESS` | Sender address | `noreply@example.com` |
| `SMTP_AUTH_METHOD` | Auth method | `plain` |
| `SMTP_OPENSSL_VERIFY_MODE` | SSL verification | `peer` |
| `SMTP_ENABLE_STARTTLS` | Use STARTTLS | `auto` |

### Common Providers

#### Mailgun
```bash
SMTP_SERVER=smtp.mailgun.org
SMTP_PORT=587
SMTP_LOGIN=postmaster@mg.your-domain.com
SMTP_PASSWORD=your-mailgun-key
```

#### SendGrid
```bash
SMTP_SERVER=smtp.sendgrid.net
SMTP_PORT=587
SMTP_LOGIN=apikey
SMTP_PASSWORD=your-sendgrid-api-key
```

#### AWS SES
```bash
SMTP_SERVER=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_LOGIN=your-ses-access-key
SMTP_PASSWORD=your-ses-secret-key
```

---

## Database & Cache

### PostgreSQL

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | Database host | `localhost` |
| `DB_PORT` | Database port | `5432` |
| `DB_NAME` | Database name | `mastodon_production` |
| `DB_USER` | Database user | `mastodon` |
| `DB_PASS` | Database password | (required) |
| `DB_POOL` | Connection pool size | `25` |

### Redis

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Redis URL | `redis://localhost:6379/0` |
| `CACHE_REDIS_URL` | Cache Redis URL | (uses REDIS_URL) |
| `SIDEKIQ_REDIS_URL` | Sidekiq Redis URL | (uses REDIS_URL) |

### Elasticsearch/OpenSearch

| Variable | Description | Default |
|----------|-------------|---------|
| `ES_ENABLED` | Enable search | `true` |
| `ES_HOST` | Elasticsearch host | `localhost` |
| `ES_PORT` | Elasticsearch port | `9200` |
| `ES_USER` | Username (optional) | |
| `ES_PASS` | Password (optional) | |

---

## Federation

### ActivityPub

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTHORIZED_FETCH` | Require signed fetches | `false` |
| `LIMITED_FEDERATION_MODE` | Allowlist federation | `false` |
| `DISALLOW_UNAUTHENTICATED_API_ACCESS` | Require auth for API | `false` |

### Domain Blocks

Managed via admin UI or:

```ruby
# Block a domain
DomainBlock.create!(
  domain: 'spam-instance.com',
  severity: :suspend
)
```

### Relays

```bash
# Add relay
bin/rails mastodon:relay:add URL=https://relay.example.com/inbox

# List relays
bin/rails mastodon:relay:list
```

---

## Object Storage (S3)

| Variable | Description | Example |
|----------|-------------|---------|
| `S3_ENABLED` | Use S3 storage | `true` |
| `S3_BUCKET` | Bucket name | `your-bucket` |
| `S3_REGION` | AWS region | `us-east-1` |
| `S3_HOSTNAME` | Custom endpoint | `s3.amazonaws.com` |
| `AWS_ACCESS_KEY_ID` | Access key | |
| `AWS_SECRET_ACCESS_KEY` | Secret key | |
| `S3_ALIAS_HOST` | CDN hostname | `cdn.example.com` |

---

## Web Push (Vapid)

| Variable | Description |
|----------|-------------|
| `VAPID_PRIVATE_KEY` | Private key |
| `VAPID_PUBLIC_KEY` | Public key |

Generate keys:
```bash
bundle exec rails mastodon:webpush:generate_vapid_key
```

---

## Complete Example

```bash
# .env.production

# === REQUIRED ===
LOCAL_DOMAIN=example.com
SECRET_KEY_BASE=your-64-char-secret
OTP_SECRET=your-64-char-secret

# === DATABASE ===
DB_HOST=db
DB_PORT=5432
DB_NAME=mastodon
DB_USER=mastodon
DB_PASS=secure-password
DB_POOL=25

# === REDIS ===
REDIS_URL=redis://redis:6379/0

# === ELASTICSEARCH ===
ES_ENABLED=true
ES_HOST=es
ES_PORT=9200

# === EMAIL ===
SMTP_SERVER=smtp.mailgun.org
SMTP_PORT=587
SMTP_LOGIN=postmaster@mg.example.com
SMTP_PASSWORD=mailgun-password
SMTP_FROM_ADDRESS=noreply@example.com

# === ERRORDON ===
ERRORDON_THEME=matrix
ERRORDON_THEME_COLOR=green
ERRORDON_INVITE_ONLY=true
ERRORDON_REQUIRE_AGE_18=true

# === NSFW-PROTECT ===
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://host.docker.internal:11434
ERRORDON_NSFW_ADMIN_EMAIL=admin@example.com

# === STORAGE ===
ERRORDON_STORAGE_ENABLED=true
ERRORDON_STORAGE_BASE_QUOTA=1073741824
ERRORDON_STORAGE_FAIR_SHARE_PERCENT=60

# === PRIVACY ===
ERRORDON_PRIVACY_PRESET=STANDARD

# === VAPID ===
VAPID_PRIVATE_KEY=your-vapid-private
VAPID_PUBLIC_KEY=your-vapid-public
```
