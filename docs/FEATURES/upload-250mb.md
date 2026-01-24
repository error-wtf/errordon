# Feature: Upload Limit 250MB

## Summary

Increase video/audio upload limit from 40MB to 250MB.

## Acceptance Criteria

- [ ] Video uploads up to 250MB accepted
- [ ] Audio uploads up to 250MB accepted
- [ ] Image limit unchanged (10MB)
- [ ] Clear error messages for oversized files
- [ ] Progress indicator for large uploads
- [ ] Timeout settings adequate for slow connections

## Configuration Changes

| Setting | Location | Current | Target |
|---------|----------|---------|--------|
| MAX_VIDEO_SIZE | media_attachment.rb | 40 MB | 250 MB |
| MAX_AUDIO_SIZE | media_attachment.rb | 40 MB | 250 MB |
| client_max_body_size | nginx.conf | 40m | 250m |
| proxy_read_timeout | nginx.conf | 60s | 300s |

## Files to Modify

- `app/models/media_attachment.rb` - Size constants
- `config/initializers/paperclip.rb` - Paperclip limits
- nginx config - Body size and timeouts
- Environment variables documentation

## Risks

- Storage costs increase
- Processing time for large files
- Potential abuse (quota system needed)
- Federation: large files may not transfer well
