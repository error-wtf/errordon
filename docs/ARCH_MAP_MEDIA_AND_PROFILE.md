# Architecture Map: Media & Profile in Errordon

**Last Updated:** 2026-01-28
**Status:** IMPLEMENTED

This document maps the code locations for profile media columns and upload configuration.

---

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| `media_type` API param | ✅ Done | `video`, `audio`, `image` filtering |
| Backend tests | ✅ Done | Full coverage in `account_statuses_filter_spec.rb` |
| Frontend tabs | ✅ Done | Videos, Audio, Images tabs |
| Frontend routes | ✅ Done | `/@:acct/videos`, `/@:acct/audio`, `/@:acct/images` |
| Filter bar | ✅ Done | Exclude reblogs, Alt text only, Public only |
| Upload limit 250MB | ✅ Done | `VIDEO_LIMIT = 250.megabytes` |
| Nginx config | ✅ Done | `client_max_body_size 300m` |

---

## Database / Models

### MediaAttachment (`app/models/media_attachment.rb`)

```ruby
# Type enum (line 38):
enum :type, { image: 0, gifv: 1, video: 2, unknown: 3, audio: 4 }

# Upload limits (lines 43-44):
IMAGE_LIMIT = 16.megabytes
VIDEO_LIMIT = 250.megabytes  # Raised from 99MB for large uploads
```

### Status (`app/models/status.rb`)

```ruby
has_many :media_attachments, dependent: :destroy

# Media scope:
scope :with_media, -> { where(id: MediaAttachment.select(:status_id)) }
```

---

## API Endpoints

### Account Statuses (`app/controllers/api/v1/accounts/statuses_controller.rb`)

**Endpoint:** `GET /api/v1/accounts/:id/statuses`

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `only_media` | boolean | Filter to posts with media |
| `media_type` | string | Filter by type: `video`, `audio`, `image` |
| `exclude_replies` | boolean | Exclude replies |
| `exclude_reblogs` | boolean | Exclude boosts |
| `pinned` | boolean | Only pinned posts |
| `tagged` | string | Filter by hashtag |

**Example:**
```bash
# Get only videos from user
curl "https://example.com/api/v1/accounts/123/statuses?only_media=true&media_type=video"
```

### Filter Logic (`app/lib/account_statuses_filter.rb`)

```ruby
KEYS = %i(
  pinned
  tagged
  only_media
  media_type      # ✅ IMPLEMENTED
  exclude_replies
  exclude_reblogs
).freeze

def media_type_scope
  type = params[:media_type].to_s.downcase
  valid_types = %w(video audio image)
  return Status.none unless valid_types.include?(type)

  Status.joins(:media_attachments)
        .where(media_attachments: { type: type })
        .group(Status.arel_table[:id])
end
```

---

## Frontend Components

### Profile Tabs (`app/javascript/mastodon/features/account_timeline/components/tabs.tsx`)

```tsx
<NavLink exact to={`/@${acct}/media`}>Media</NavLink>
<NavLink exact to={`/@${acct}/videos`}>Videos</NavLink>
<NavLink exact to={`/@${acct}/audio`}>Audio</NavLink>
<NavLink exact to={`/@${acct}/images`}>Images</NavLink>
```

### Routes (`app/javascript/mastodon/features/ui/index.jsx`)

```jsx
<WrappedRoute path='/@:acct/media' component={AccountGallery} />
<WrappedRoute path='/@:acct/videos' component={AccountGallery} componentParams={{ mediaType: 'video' }} />
<WrappedRoute path='/@:acct/audio' component={AccountGallery} componentParams={{ mediaType: 'audio' }} />
<WrappedRoute path='/@:acct/images' component={AccountGallery} componentParams={{ mediaType: 'image' }} />
```

### Gallery Component (`app/javascript/mastodon/features/account_gallery/index.tsx`)

```tsx
export const AccountGallery: React.FC<{
  multiColumn: boolean;
  mediaType?: 'video' | 'audio' | 'image';
}> = ({ multiColumn, mediaType }) => {
  // Filter attachments by media type if specified
  let attachments = mediaType
    ? allAttachments.filter((attachment) => attachment.get('type') === mediaType)
    : allAttachments;
  // ...
};
```

### Filter Bar (`app/javascript/mastodon/features/account_gallery/components/media_filter_bar.tsx`)

Provides UI for:
- Exclude reblogs
- Only with alt text
- Only public posts

---

## Upload Limits

| Layer | File | Setting |
|-------|------|---------|
| Rails | `app/models/media_attachment.rb` | `VIDEO_LIMIT = 250.megabytes` |
| Rails | `app/models/media_attachment.rb` | `IMAGE_LIMIT = 16.megabytes` |
| Nginx | `deploy/nginx.conf` | `client_max_body_size 300m` |
| Nginx | `deploy/nginx.conf` | `proxy_read_timeout 300s` |

---

## Tests

### Backend (`spec/lib/account_statuses_filter_spec.rb`)

```ruby
describe 'media_type filter' do
  it 'filters by video media type'
  it 'filters by audio media type'
  it 'filters by image media type'
  it 'returns nothing for invalid media type'
end
```

---

## Localization

| Key | English | File |
|-----|---------|------|
| `account.videos` | Videos | `app/javascript/mastodon/locales/en.json` |
| `account.audio` | Audio | `app/javascript/mastodon/locales/en.json` |
| `account.images` | Images | `app/javascript/mastodon/locales/en.json` |

---

## Related Files

| Component | Path |
|-----------|------|
| Filter class | `app/lib/account_statuses_filter.rb` |
| Filter spec | `spec/lib/account_statuses_filter_spec.rb` |
| Gallery component | `app/javascript/mastodon/features/account_gallery/index.tsx` |
| Tabs component | `app/javascript/mastodon/features/account_timeline/components/tabs.tsx` |
| Routes | `app/javascript/mastodon/features/ui/index.jsx` |
| Nginx config | `deploy/nginx.conf` |
