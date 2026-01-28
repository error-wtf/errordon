# Work Plan: Profile Media Columns

**Date:** 2026-01-28
**Feature:** Add separate tabs for Videos, Audio, Images in user profiles
**Status:** Planning (PHASE -1 complete, ready for PHASE 0)

---

## 1. Feature Overview

### Goal
Add tabbed navigation to user profiles showing:
- **Videos** - All video posts
- **Audio** - All audio posts  
- **Images** - All image posts (default behavior enhanced)

### Existing State
- Profile shows "Media" tab that displays all media types together
- API supports `only_media` param but NOT `media_type` filtering
- `MediaAttachment` model has `type` enum: `image`, `gifv`, `video`, `unknown`, `audio`

---

## 2. Code Locations (from ARCH_MAP)

### Backend
| File | Change Needed |
|------|---------------|
| `app/controllers/api/v1/accounts/statuses_controller.rb` | Accept `media_type` param |
| `app/models/concerns/account_statuses_filter.rb` | Add media_type filtering logic |
| `app/models/media_attachment.rb` | Already has scopes (`.video`, `.audio`, `.image`) |

### Frontend
| File | Change Needed |
|------|---------------|
| `app/javascript/mastodon/features/account_timeline/index.jsx` | Add tabs for media types |
| `app/javascript/mastodon/features/account_timeline/components/header.jsx` | Tab navigation |
| `app/javascript/mastodon/actions/accounts.js` | Add `media_type` to API calls |
| `app/javascript/mastodon/locales/*.json` | Translation keys |

### Routes
| File | Change Needed |
|------|---------------|
| `config/routes.rb` | No change (existing route handles params) |

---

## 3. Implementation Steps

### PHASE 0: Planning & Validation
- [ ] Verify existing `only_media` behavior
- [ ] Review `AccountStatusesFilter` implementation
- [ ] Identify exact UI placement for tabs
- [ ] Define API contract for `media_type` param

### PHASE 1: Backend (API)
- [ ] Add `media_type` to `AccountStatusesFilter::KEYS`
- [ ] Implement filtering in `account_statuses_filter.rb`
- [ ] Add tests for new parameter
- [ ] Verify pagination works with filter

### PHASE 2: Frontend (React)
- [ ] Add tab navigation UI component
- [ ] Wire up tabs to API calls with `media_type`
- [ ] Handle loading states per tab
- [ ] Add translations (EN, DE minimum)

### PHASE 3: Integration & Testing
- [ ] End-to-end test: click tab → see filtered results
- [ ] Test with empty results (no videos, etc.)
- [ ] Test pagination within each tab
- [ ] Verify ActivityPub compatibility (no federation impact)

### PHASE 4: Polish
- [ ] Add icons for video/audio/image tabs
- [ ] Cache tab counts (optional)
- [ ] Documentation update

---

## 4. API Design

### Endpoint
```
GET /api/v1/accounts/:id/statuses
```

### New Parameter
```
media_type=video|audio|image
```

### Example Requests
```bash
# All videos from user
GET /api/v1/accounts/123/statuses?only_media=true&media_type=video

# All audio from user
GET /api/v1/accounts/123/statuses?only_media=true&media_type=audio

# All images from user
GET /api/v1/accounts/123/statuses?only_media=true&media_type=image
```

### Response
Same as existing statuses endpoint (array of Status objects).

---

## 5. Backend Implementation Detail

### `app/models/concerns/account_statuses_filter.rb`

```ruby
KEYS = %i(
  pinned
  tagged
  only_media
  media_type    # NEW
  exclude_replies
  exclude_reblogs
).freeze

def results
  scope = @account.statuses
  
  scope = scope.joins(:media_attachments) if only_media?
  
  # NEW: Filter by media type
  if media_type.present?
    scope = scope.joins(:media_attachments)
                 .where(media_attachments: { type: media_type })
  end
  
  # ... existing filters
  scope
end

private

def media_type
  params[:media_type]&.to_sym if %i[video audio image].include?(params[:media_type]&.to_sym)
end
```

---

## 6. Frontend Implementation Detail

### Tab Component (conceptual)

```tsx
// In account_timeline header
<NavLink to={`/@${username}/media`}>All Media</NavLink>
<NavLink to={`/@${username}/videos`}>Videos</NavLink>
<NavLink to={`/@${username}/audio`}>Audio</NavLink>
<NavLink to={`/@${username}/images`}>Images</NavLink>
```

### API Call Modification

```javascript
// In actions/accounts.js
export function fetchAccountMedia(id, mediaType = null) {
  return api().get(`/api/v1/accounts/${id}/statuses`, {
    params: {
      only_media: true,
      media_type: mediaType,  // NEW
    },
  });
}
```

---

## 7. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Breaking existing "Media" tab | Keep existing behavior as default, only filter when `media_type` specified |
| Performance (extra join) | Media query already joins, no additional cost |
| ActivityPub compatibility | No impact - this is local UI only, no federation changes |
| Migration needed? | No - using existing `type` column |

---

## 8. Dependencies

### Required
- No new gems/packages
- No database migrations
- No new ENV vars

### Optional Enhancements
- Tab count display (requires additional query)
- Icon library update (if new icons needed)

---

## 9. Testing Strategy

### Unit Tests
- `AccountStatusesFilter` with `media_type` param
- Edge cases: invalid media_type, combined params

### Integration Tests
- API returns correct filtered results
- Pagination works correctly

### E2E Tests
- Click video tab → see only videos
- Click audio tab → see only audio
- Handle empty results gracefully

---

## 10. Estimated Scope

| Phase | Effort | Files Changed |
|-------|--------|---------------|
| Backend | Small | 2-3 files |
| Frontend | Medium | 4-6 files |
| Tests | Medium | 2-4 files |
| Docs | Small | 1-2 files |

**Total estimate:** 1-2 days of focused work

---

## 11. Acceptance Criteria

1. ✅ User profiles show tabs: All Media | Videos | Audio | Images
2. ✅ Clicking "Videos" shows only video posts
3. ✅ Clicking "Audio" shows only audio posts
4. ✅ Clicking "Images" shows only image posts
5. ✅ Pagination works within each tab
6. ✅ Empty state shows appropriate message
7. ✅ No breaking changes to existing functionality
8. ✅ Works with Matrix theme enabled

---

## 12. Related Documentation

- `docs/ARCH_MAP_MEDIA_AND_PROFILE.md` - Code location reference
- `docs/FEATURES/profile-media-columns.md` - Feature specification
- `docs/TRANSCODING_PIPELINE.md` - Video processing details

---

## Next Step

**Proceed to PHASE 0:** Validate assumptions, review existing code, finalize API contract.
