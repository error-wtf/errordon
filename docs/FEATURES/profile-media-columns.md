# Feature: Profile Media Columns

## Summary

Add separate tabs in user profiles for Videos, Audio, and Images.

## User Story

As a user viewing someone's profile, I want to see their videos, audio, and images in separate tabs, so I can quickly find the type of content I'm interested in.

## Acceptance Criteria

- [ ] Profile page has new tabs: "Videos", "Audio", "Images"
- [ ] Each tab shows only that media type
- [ ] Tabs show count of items
- [ ] Grid layout for images (Instagram-style thumbnails)
- [ ] Card layout for videos (with duration overlay)
- [ ] List layout for audio (with waveform/player)
- [ ] Existing "Media" tab unchanged (shows all)
- [ ] Works with federated profiles

## Technical Approach

### Backend

1. Add `media_type` param to `/api/v1/accounts/:id/statuses`

```ruby
# app/controllers/api/v1/accounts/statuses_controller.rb
def account_statuses
  statuses = @account.statuses
  if params[:media_type].present?
    statuses = statuses.joins(:media_attachments)
                       .where(media_attachments: { type: params[:media_type] })
  end
  statuses
end
```

2. Add media type scopes to Status model

```ruby
# app/models/status.rb
scope :with_video, -> { joins(:media_attachments).where(media_attachments: { type: :video }) }
scope :with_audio, -> { joins(:media_attachments).where(media_attachments: { type: :audio }) }
scope :with_image, -> { joins(:media_attachments).where(media_attachments: { type: :image }) }
```

### Frontend

1. Add new routes in `app/javascript/mastodon/features/ui/index.jsx`
2. Create tab components in `app/javascript/mastodon/features/account_timeline/`
3. Add tab entries to profile navigation

### API Response

Same as existing statuses endpoint, filtered by media type.

## Files to Modify

| File | Change |
|------|--------|
| `app/controllers/api/v1/accounts/statuses_controller.rb` | Add media_type param |
| `app/models/status.rb` | Add scopes |
| `app/javascript/mastodon/features/ui/index.jsx` | Add routes |
| `app/javascript/mastodon/features/account_timeline/` | New tab components |

## Tests

- Request spec: filter by media_type returns correct statuses
- Component test: tabs render correctly
- Integration: switching tabs loads correct content

## Risks

- Federation: other instances may not have this filter
- Performance: joins on media_attachments could be slow for large accounts
