# Feature: Media Filters UI

## Summary

Filter chips/options for media tabs to show originals only, with text, by visibility, etc.

## Acceptance Criteria

- [ ] Filter chips appear above media grid
- [ ] "Originals only" - exclude boosts/reblogs
- [ ] "With text" - only posts that have caption text
- [ ] "Public only" / "Unlisted" / "All" visibility filter
- [ ] "No CW" - exclude content-warned posts
- [ ] Filters persist in URL (shareable)
- [ ] Filters work with all media tabs

## Filter Options

| Filter | Param | Default |
|--------|-------|---------|
| Originals only | `exclude_reblogs=true` | false |
| With text | `with_text=true` | false |
| Visibility | `visibility=public,unlisted` | all |
| No CW | `exclude_cw=true` | false |

## Technical Approach

- Extend existing statuses endpoint params
- Frontend filter chip components
- URL query string sync

## Files to Modify

- `app/controllers/api/v1/accounts/statuses_controller.rb`
- `app/javascript/mastodon/features/account_timeline/components/filter_bar.jsx` (new)
