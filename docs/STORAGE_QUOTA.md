# Storage Quota System

Errordon implements a dynamic storage quota system that fairly distributes disk space among all users.

## Overview

- **60% of system disk** is available for user uploads
- Space is **equally divided** among all active users
- Quota adjusts **dynamically** as users join/leave
- When quota is full, users can only post **text and links**

## How It Works

```
System Disk: 500 GB
├── Reserved (40%): 200 GB (OS, DB, cache, logs)
└── User Space (60%): 300 GB
    ├── User A: 20 GB (300 GB ÷ 15 users)
    ├── User B: 20 GB
    └── ... (15 users total)
```

## Configuration

```bash
# .env.production

# Maximum percentage of disk for user uploads (default: 60)
ERRORDON_STORAGE_MAX_PERCENT=60

# Minimum quota per user (default: 50 MB)
ERRORDON_STORAGE_MIN_QUOTA_MB=50

# Maximum quota per user (default: 50 GB)
ERRORDON_STORAGE_MAX_QUOTA_GB=50
```

## API Endpoints

### Get Current User Quota

```
GET /api/v1/errordon/storage_quota
Authorization: Bearer <token>
```

**Response:**
```json
{
  "quota": 21474836480,
  "used": 2684354560,
  "available": 18790481920,
  "percentage": 12.5,
  "can_upload": true,
  "quota_human": "20 GB",
  "used_human": "2.5 GB",
  "available_human": "17.5 GB"
}
```

### User Profile (Credential Account)

The `storage_quota` field is automatically included in `/api/v1/accounts/verify_credentials`:

```json
{
  "id": "123",
  "username": "user",
  "storage_quota": {
    "used": 2684354560,
    "quota": 21474836480,
    "percentage": 12.5,
    "can_upload": true,
    "used_human": "2.5 GB",
    "quota_human": "20 GB"
  }
}
```

## Fediverse Compatibility

- Quota only applies to **local accounts**
- Remote/federated accounts are **not affected**
- ActivityPub federation works normally
- `storage_quota` field returns `null` for remote accounts

## User Experience

### Normal State
User sees their quota in profile: `2.5 GB von 20 GB`

### Quota Exceeded
- Upload attempts return error 422
- Error message: "Speicherplatz aufgebraucht (20 GB von 20 GB). Bitte lösche alte Medien oder teile nur Text/Links."
- User can still post text and links
- User must delete old media to upload new files

## Technical Details

### Service Location
`app/services/errordon/storage_quota_service.rb`

### Key Methods

```ruby
# Get quota info for account
Errordon::StorageQuotaService.quota_for(account)

# Check if upload is allowed
Errordon::StorageQuotaService.can_upload?(account, file_size)

# Get system-wide stats
Errordon::StorageQuotaService.system_stats

# Refresh cache
Errordon::StorageQuotaService.refresh!
```

### Caching

- Disk space: cached 5 minutes
- User count: cached 5 minutes
- Refresh automatically or call `refresh!`

### Dependencies

- `sys-filesystem` gem for disk space detection
- Works with local storage and cloud (S3) configurations

## Admin Commands

```bash
# Rails console
rails c

# Check system stats
Errordon::StorageQuotaService.system_stats

# Check specific user quota
account = Account.find_by(username: 'user')
Errordon::StorageQuotaService.quota_for(account)

# Force refresh caches
Errordon::StorageQuotaService.refresh!
```

## Error Handling

The `QuotaExceededError` is raised when:
- User's used storage >= their quota
- File size would exceed remaining quota

```ruby
rescue Errordon::MediaUploadChecker::QuotaExceededError => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```
