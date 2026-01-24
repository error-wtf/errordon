# Feature: Transcoding Pipeline

## Summary

Server-side video/audio transcoding to optimize storage and playback.

## Acceptance Criteria

- [ ] Videos transcoded to H.264/AAC/MP4
- [ ] Two variants: mobile (480p), default (720p)
- [ ] Thumbnails auto-generated
- [ ] Duration/codec metadata stored
- [ ] Processing status shown to user
- [ ] Fallback on transcode failure
- [ ] Queue monitoring/alerts

## Output Specifications

| Variant | Resolution | Bitrate | Codec |
|---------|------------|---------|-------|
| mobile | 480p | 1 Mbps | H.264 |
| default | 720p | 2.5 Mbps | H.264 |
| original | preserved | preserved | original |

Audio: AAC 128kbps stereo

## Pipeline Flow

```
Upload → Validate → Queue Job → ffmpeg transcode → Store variants → Update DB → Notify
```

## Sidekiq Jobs

- `TranscodeVideoWorker` - Main transcoding job
- `GenerateThumbnailWorker` - Extract frame
- `CleanupOriginalWorker` - Optional: remove original after transcode

## Files to Create/Modify

- `app/workers/transcode_video_worker.rb` (new)
- `app/services/video_transcode_service.rb` (new)
- `app/models/media_attachment.rb` - Add variant columns
- `db/migrate/xxx_add_variants_to_media_attachments.rb` (new)

## ffmpeg Commands

```bash
# 720p default
ffmpeg -i input.mov -vf scale=-2:720 -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k output_720p.mp4

# 480p mobile
ffmpeg -i input.mov -vf scale=-2:480 -c:v libx264 -preset fast -crf 28 -c:a aac -b:a 96k output_480p.mp4

# Thumbnail
ffmpeg -i input.mov -ss 00:00:01 -vframes 1 -vf scale=400:-2 thumb.jpg
```
