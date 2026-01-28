# Storage Fair Share Policy

> **Errordon** implements a fair-share storage quota system that ensures equitable resource distribution while maintaining fediverse compatibility.

## Table of Contents

- [Overview](#overview)
- [Fediverse Compatibility](#fediverse-compatibility)
- [Fair Share Calculation](#fair-share-calculation)
- [User Experience](#user-experience)
- [Configuration](#configuration)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)

---

## Overview

### Core Principles

1. **Fediverse First**: Upload limits are conservative to ensure posts federate reliably
2. **Fair Share**: Storage is distributed equally among all active users
3. **Transparency**: Users can see their usage, quota, and how it's calculated
4. **Graceful Degradation**: When quota is exceeded, text+links posting remains allowed

### Key Limits (Defaults)

| Type | Limit | Reason |
|------|-------|--------|
| **Image** | 16 MB | Standard fediverse limit |
| **Video/Audio** | 40 MB | Conservative fediverse-compatible limit |
| **Global Pool** | 50% of disk | Protects system operations |
| **Per-User** | Pool / Active Users | Dynamic fair share |
| **Daily Upload** | 1 GB | Prevents abuse |
| **Hourly Rate** | 20 uploads | Prevents spam |

---

## Fediverse Compatibility

### Why Conservative Limits?

Our upload limits are intentionally conservative (40MB video vs Mastodon's 99MB default) because:

1. **Federation Reliability**: Many instances reject or timeout on large files during ActivityPub delivery
2. **Fair to Remote Instances**: Large files push storage costs to remote servers that didn't choose those limits
3. **Network Diversity**: Not all instances have fast connections or large storage
4. **Bandwidth Fairness**: Heavy uploads consume shared bandwidth on federated instances

### What Happens to Large Files?

When someone from another instance tries to share your content:
- Files within fediverse limits federate normally
- The file is delivered to remote instances following your account
- Remote instances store a copy for their users

If limits were too high:
- Remote instances might reject the media
- Delivery timeouts would break federation
- The post might appear without media on other instances

### Configuring Limits

```bash
# In .env.production

# Image limit (default: 16 MB, fediverse standard)
ERRORDON_IMAGE_LIMIT_MB=16

# Video/Audio limit (default: 40 MB, conservative)
# WARNING: Values > 50MB may cause federation issues
ERRORDON_VIDEO_LIMIT_MB=40
```

---

## Fair Share Calculation

### How It Works

```
upload_pool_bytes = disk_total × (ERRORDON_STORAGE_MAX_PERCENT / 100)
per_user_quota = upload_pool_bytes / active_users_count
```

### Example

| Disk Size | 50% Pool | 10 Users | Per-User Quota |
|-----------|----------|----------|----------------|
| 100 GB | 50 GB | 10 | 5 GB |
| 100 GB | 50 GB | 50 | 1 GB |
| 100 GB | 50 GB | 100 | 512 MB |
| 500 GB | 250 GB | 100 | 2.5 GB |

### Why Total Disk Size (Not Free Space)?

We use **total disk size** as the basis because:

1. **Predictability**: Total size is constant; free space fluctuates with system operations
2. **User Trust**: Quotas don't randomly shrink when the system does maintenance
3. **Fair Planning**: Users can plan their uploads around a stable quota

### Active User Definition

By default, "active users" means:
- Local accounts (not remote/federated)
- Email confirmed
- Not suspended

Alternative definitions (via `ERRORDON_ACTIVE_USER_DEFINITION`):
- `confirmed` (default): All confirmed, non-suspended local users
- `active_30`: Users with login activity in last 30 days
- `active_90`: Users with login activity in last 90 days

---

## User Experience

### Account Page Display

Users see on their profile:

```
┌─────────────────────────────────────┐
│ Storage Quota                       │
├─────────────────────────────────────┤
│ [████████░░░░░░░░░░░░] 40%         │
│                                     │
│   Used        Available     Quota   │
│  400 MB         600 MB       1 GB   │
│                                     │
│ Your quota (1 GB) is shared fairly  │
│ among 50 users. As more users join, │
│ individual quotas may decrease.     │
└─────────────────────────────────────┘
```

### When Quota is Exceeded

| State | Uploads | Text Posts | Links |
|-------|---------|------------|-------|
| Under Quota | ✅ Allowed | ✅ Allowed | ✅ Allowed |
| At Limit | ❌ Blocked | ✅ Allowed | ✅ Allowed |
| Exempt (Admin) | ✅ Allowed | ✅ Allowed | ✅ Allowed |

**User Message:**
> "You have reached your storage limit. Delete some media to upload more.
> You can still post text and links."

### How to Free Space

Users can free space by:
1. Going to their profile → Media tab
2. Selecting old uploads they no longer need
3. Deleting them (immediate quota update)

---

## Configuration

### Environment Variables

```bash
# === UPLOAD LIMITS (Fediverse-Compatible) ===

# Image upload limit in MB (default: 16, standard)
ERRORDON_IMAGE_LIMIT_MB=16

# Video/Audio upload limit in MB (default: 40, conservative)
ERRORDON_VIDEO_LIMIT_MB=40

# === STORAGE POOL ===

# Maximum % of disk for user uploads (default: 50)
ERRORDON_STORAGE_MAX_PERCENT=50

# Minimum quota per user in MB (floor, default: 50)
ERRORDON_STORAGE_MIN_QUOTA_MB=50

# Maximum quota per user in GB (ceiling, default: 10)
ERRORDON_STORAGE_MAX_QUOTA_GB=10

# === ACTIVE USER DEFINITION ===

# How to count "active users" for fair share
# Options: 'confirmed' (default), 'active_30', 'active_90'
ERRORDON_ACTIVE_USER_DEFINITION=confirmed

# === RATE LIMITS ===

# Max daily upload size per user (default: 1 GB)
ERRORDON_DAILY_UPLOAD_LIMIT_GB=1

# Max uploads per hour per user (default: 20)
ERRORDON_HOURLY_UPLOAD_LIMIT=20

# === EXEMPTIONS ===

# Comma-separated list of roles exempt from quotas
ERRORDON_QUOTA_EXEMPT_ROLES=Admin,Moderator
```

### Rails Configuration

The quota system can also be configured via Rails:

```ruby
# config/initializers/errordon_quotas.rb

Rails.application.config.x.errordon_quotas = {
  enabled: true,
  storage: {
    max_per_user: 10.gigabytes  # Fallback if dynamic quota disabled
  },
  rate_limits: {
    upload_size_per_day: 1.gigabyte,
    uploads_per_hour: 20
  },
  exempt_roles: %w[Admin Moderator]
}
```

---

## API Reference

### GET /api/v1/errordon/storage_quota

Returns current user's storage quota information.

**Response:**

```json
{
  "storage": {
    "used": 419430400,
    "used_human": "400 MB",
    "quota": 1073741824,
    "quota_human": "1 GB",
    "available": 654311424,
    "available_human": "624 MB",
    "percent": 39.1,
    "at_limit": false,
    "can_upload": true
  },
  "fair_share": {
    "active_users": 50,
    "pool_total": 53687091200,
    "pool_total_human": "50 GB",
    "max_percent": 50,
    "notice": "Your quota (1 GB) is shared fairly among 50 users."
  },
  "daily": {
    "uploaded": 104857600,
    "uploaded_human": "100 MB",
    "limit": 1073741824,
    "limit_human": "1 GB",
    "remaining": 968884224,
    "remaining_human": "924 MB"
  },
  "hourly": {
    "uploads": 3,
    "limit": 20,
    "remaining": 17
  },
  "upload_limits": {
    "image": 16777216,
    "image_human": "16 MB",
    "video": 41943040,
    "video_human": "40 MB"
  },
  "can_upload": true,
  "at_limit": false,
  "exempt": false
}
```

### GET /api/v1/errordon/storage_quota/status

Quick status check for UI components.

**Response:**

```json
{
  "can_upload": true,
  "at_limit": false,
  "used_percent": 39.1,
  "available": 654311424,
  "available_human": "624 MB"
}
```

---

## Troubleshooting

### "Why did my quota shrink?"

Your per-user quota is calculated dynamically:

```
per_user_quota = (disk_total × 50%) / active_users
```

If new users joined, the pool is divided among more people. This is fair-share in action.

### "I'm exempt but still see quota"

Only users with Admin or Moderator roles are exempt. Check:
1. Your role in Admin → Accounts → [Your Account]
2. The `ERRORDON_QUOTA_EXEMPT_ROLES` environment variable

### "Video uploads fail even under quota"

Check the individual file size limits:
- Videos must be ≤ 40 MB (default)
- This is separate from your total storage quota

### "Storage shows 0 available but I haven't uploaded much"

This can happen if:
1. Many users joined, shrinking per-user quota
2. System disk is critically full (check `df -h`)
3. Cache needs clearing: `docker compose exec web rails errordon:refresh_quotas`

### Checking Current Limits

```bash
# In Rails console
docker compose exec web rails c

# Check system stats
Errordon::StorageQuotaService.system_stats

# Check specific user
account = Account.find_by(username: 'someuser')
Errordon::StorageQuotaService.quota_for(account)
```

---

## Technical Implementation

### Services

| Service | Purpose |
|---------|---------|
| `Errordon::StorageQuotaService` | Fair share calculations, disk stats |
| `Errordon::QuotaService` | Per-user enforcement, rate limiting |

### Database Queries

The quota system uses efficient queries:
- User count: Cached for 5 minutes
- Disk stats: Cached for 5 minutes
- User storage: SUM query on `media_attachments.file_file_size`

### Cache Keys

```ruby
'errordon:disk_total'   # Total disk size
'errordon:disk_free'    # Free disk space
'errordon:user_count'   # Active user count
```

Force refresh:
```ruby
Errordon::StorageQuotaService.refresh!
```

---

## Changelog

- **v1.0.0**: Initial fair-share implementation
  - 50% global cap (down from 60%)
  - VIDEO_LIMIT reduced to 40MB (fediverse-compatible)
  - UI component for account page
  - Comprehensive API
