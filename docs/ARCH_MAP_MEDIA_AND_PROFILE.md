# Architecture Map: Media & Profile in Mastodon

This document maps the relevant code locations for implementing profile media columns and upload changes.

## Database / Models

### MediaAttachment (`app/models/media_attachment.rb`)

Core model for all uploaded media.

```ruby
# Key attributes:
# - type: image, gifv, video, audio, unknown
# - file: paperclip attachment
# - status_id: belongs_to status
# - account_id: belongs_to account
# - file_file_size: size in bytes

# Key scopes to add:
scope :videos, -> { where(type: :video) }
scope :audio, -> { where(type: :audio) }
scope :images, -> { where(type: :image) }
```

### Status (`app/models/status.rb`)

Posts that contain media attachments.

```ruby
# Relevant associations:
has_many :media_attachments, dependent: :destroy

# Existing scope for media:
scope :with_media, -> { where(id: MediaAttachment.select(:status_id)) }
```

### Account (`app/models/account.rb`)

User profiles.

```ruby
# Relevant associations:
has_many :statuses, inverse_of: :account, dependent: :destroy
has_many :media_attachments, dependent: :destroy
```

## API Endpoints

### Account Statuses (`app/controllers/api/v1/accounts/statuses_controller.rb`)

**Current endpoint:** `GET /api/v1/accounts/:id/statuses`

**Existing params:**
- `only_media` - filter to posts with media
- `exclude_replies` - exclude replies
- `exclude_reblogs` - exclude boosts
- `pinned` - only pinned posts

**New param to add:**
- `media_type` - filter by type: `video`, `audio`, `image`

```ruby
# Location: app/controllers/api/v1/accounts/statuses_controller.rb
# Method: index
# Add filtering logic:

def account_statuses
  statuses = @account.statuses.without_reblogs
  statuses = statuses.joins(:media_attachments)
                     .where(media_attachments: { type: params[:media_type] }) if params[:media_type]
  statuses
end
```

### Media Upload (`app/controllers/api/v1/media_controller.rb`)

**Endpoint:** `POST /api/v1/media`

Handles file uploads, triggers processing jobs.

## Frontend Components

### Profile Page (`app/javascript/mastodon/features/account/`)

```
account/
├── components/
│   ├── header.jsx           # Profile header
│   └── action_bar.jsx       # Follow/block buttons
├── containers/
│   └── account_container.js
└── index.jsx                # Main profile component
```

### Account Timeline (`app/javascript/mastodon/features/account_timeline/`)

```
account_timeline/
├── components/
│   └── header.jsx           # Tab navigation (Posts/Replies/Media)
├── containers/
│   └── account_timeline_container.js
└── index.jsx                # Timeline component
```

**Key file for tabs:** `app/javascript/mastodon/features/ui/components/tabs_bar.jsx`

### Media Components

```
app/javascript/mastodon/components/
├── media_gallery.jsx        # Image grid display
├── video.jsx                # Video player
├── audio.jsx                # Audio player
└── attachment_list.jsx      # Generic attachment list
```

## Upload Limits

### Configuration Files

```ruby
# config/initializers/paperclip.rb
# - MIME type allowlists
# - File size limits

# app/models/media_attachment.rb
# - MAX_VIDEO_SIZE
# - MAX_IMAGE_SIZE
# - Validation callbacks

# config/settings.yml
# - Default limits (can be overridden)
```

### Nginx Config

```nginx
# /etc/nginx/sites-available/mastodon
client_max_body_size 40m;  # Change to 250m
```

## Processing Pipeline (Sidekiq Jobs)

### Media Processing

```ruby
# app/workers/
├── post_process_media_worker.rb  # Main processing job
├── process_media_service.rb      # Service for processing
└── video_transcoding_worker.rb   # Video-specific (if exists)

# app/services/
└── post_status_service.rb        # Creates status + triggers media processing
```

### Transcoding (ffmpeg integration)

```ruby
# app/lib/paperclip/
├── video_transcoder.rb           # Video transcoding
├── audio_transcoder.rb           # Audio transcoding
└── transcoder.rb                 # Base transcoder
```

## Key Constants & Config

| Constant | Location | Current Value | Target |
|----------|----------|---------------|--------|
| `MAX_VIDEO_SIZE` | `media_attachment.rb` | 40 MB | 250 MB |
| `MAX_AUDIO_SIZE` | `media_attachment.rb` | 40 MB | 250 MB |
| `MAX_IMAGE_SIZE` | `media_attachment.rb` | 10 MB | 10 MB |
| `client_max_body_size` | nginx.conf | 40m | 250m |

## Changes Required by Feature

### Profile Media Columns

| Layer | File | Change |
|-------|------|--------|
| API | `accounts/statuses_controller.rb` | Add `media_type` param |
| Model | `status.rb` | Add scopes for media types |
| Frontend | `account_timeline/` | Add tabs for Video/Audio/Images |
| Frontend | `components/tabs_bar.jsx` | New tab entries |
| Routes | `routes.rb` | New frontend routes |

### Upload 250MB

| Layer | File | Change |
|-------|------|--------|
| Model | `media_attachment.rb` | Update size constants |
| Config | nginx.conf | `client_max_body_size 250m` |
| Config | `paperclip.rb` | Update limits |
| Jobs | `post_process_media_worker.rb` | Handle larger files |

### Transcoding Pipeline

| Layer | File | Change |
|-------|------|--------|
| Jobs | New: `transcode_video_worker.rb` | ffmpeg processing |
| Service | New: `video_transcode_service.rb` | Variant generation |
| Model | `media_attachment.rb` | Add variant columns |
| Storage | S3/local config | Multiple file versions |
