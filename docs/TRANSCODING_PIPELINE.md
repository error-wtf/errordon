# Video/Audio Transcoding Pipeline

Server-side transcoding pipeline for Errordon to optimize large uploads.

## Pipeline Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Upload    │────▶│  Validate   │────▶│  Transcode  │────▶│   Store     │
│  (250MB)    │     │  (MIME/Size)│     │  (ffmpeg)   │     │  (S3/Local) │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  Thumbnail  │
                                        │  + Metadata │
                                        └─────────────┘
```

## Output Variants

### Video

| Variant | Resolution | Bitrate | Codec | Use Case |
|---------|------------|---------|-------|----------|
| `default` | 720p | 2.5 Mbps | H.264 | Desktop playback |
| `mobile` | 480p | 1.0 Mbps | H.264 | Mobile/slow connections |
| `thumbnail` | 400x225 | - | JPEG | Preview image |

### Audio

| Variant | Bitrate | Codec | Use Case |
|---------|---------|-------|----------|
| `default` | 128 kbps | AAC | Standard playback |
| `waveform` | - | JSON | Visual waveform data |

## ffmpeg Commands

### Video Transcoding (720p)

```bash
ffmpeg -i input.mov \
  -c:v libx264 \
  -preset medium \
  -crf 23 \
  -maxrate 2500k \
  -bufsize 5000k \
  -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2" \
  -c:a aac \
  -b:a 128k \
  -movflags +faststart \
  output_720p.mp4
```

### Video Transcoding (480p Mobile)

```bash
ffmpeg -i input.mov \
  -c:v libx264 \
  -preset fast \
  -crf 26 \
  -maxrate 1000k \
  -bufsize 2000k \
  -vf "scale=854:480:force_original_aspect_ratio=decrease,pad=854:480:(ow-iw)/2:(oh-ih)/2" \
  -c:a aac \
  -b:a 96k \
  -movflags +faststart \
  output_480p.mp4
```

### Thumbnail Generation

```bash
ffmpeg -i input.mp4 \
  -ss 00:00:01 \
  -vframes 1 \
  -vf "scale=400:225:force_original_aspect_ratio=decrease,pad=400:225:(ow-iw)/2:(oh-ih)/2" \
  thumbnail.jpg
```

### Audio Transcoding

```bash
ffmpeg -i input.wav \
  -c:a aac \
  -b:a 128k \
  output.m4a
```

## Sidekiq Jobs

### Job Structure

```ruby
# app/workers/media_transcode_worker.rb
class MediaTranscodeWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: 'media', retry: 3, dead: false
  
  def perform(media_attachment_id)
    attachment = MediaAttachment.find(media_attachment_id)
    
    case attachment.type
    when 'video'
      transcode_video(attachment)
    when 'audio'
      transcode_audio(attachment)
    end
  rescue => e
    attachment.update!(processing_status: 'failed')
    raise e
  end
  
  private
  
  def transcode_video(attachment)
    # 1. Generate thumbnail
    # 2. Transcode to 720p
    # 3. Optionally transcode to 480p
    # 4. Extract metadata (duration, dimensions)
    # 5. Upload to storage
    # 6. Update attachment record
  end
  
  def transcode_audio(attachment)
    # 1. Transcode to AAC
    # 2. Generate waveform
    # 3. Extract metadata (duration)
    # 4. Upload to storage
    # 5. Update attachment record
  end
end
```

### Queue Configuration

```yaml
# config/sidekiq.yml
:queues:
  - [default, 5]
  - [push, 4]
  - [pull, 3]
  - [media, 2]      # Lower priority for transcoding
  - [scheduler, 1]

:concurrency: 5
```

## Database Schema

```ruby
# Migration: add_transcoding_fields_to_media_attachments
add_column :media_attachments, :processing_status, :string, default: 'pending'
add_column :media_attachments, :variants, :jsonb, default: {}
add_column :media_attachments, :original_size, :bigint
add_column :media_attachments, :transcoded_size, :bigint

add_index :media_attachments, :processing_status
```

### Variants JSON Structure

```json
{
  "default": {
    "url": "https://...",
    "size": 15000000,
    "bitrate": 2500000,
    "resolution": "1280x720"
  },
  "mobile": {
    "url": "https://...",
    "size": 8000000,
    "bitrate": 1000000,
    "resolution": "854x480"
  }
}
```

## Error Handling

### Retry Strategy

| Error Type | Action |
|------------|--------|
| ffmpeg crash | Retry 3x, then mark failed |
| Storage full | Alert admin, pause queue |
| Timeout | Retry with longer timeout |
| Corrupt file | Mark failed, notify user |

### Status Flow

```
pending → processing → completed
                   ↘ failed
```

## Monitoring

### Key Metrics

```ruby
# Prometheus metrics (if using)
transcode_duration_seconds
transcode_queue_size
transcode_failure_rate
storage_bytes_saved
```

### Alerts

- Queue > 50 jobs: Warning
- Queue > 200 jobs: Critical
- Failure rate > 10%: Critical
- Job duration > 10min: Warning

## Storage Optimization

### Space Savings Estimate

| Input | Output | Savings |
|-------|--------|---------|
| 250MB raw | ~50MB 720p | ~80% |
| 250MB raw | ~20MB 480p | ~92% |

### Cleanup Policy

```ruby
# Delete original after successful transcode
after_transcode do |attachment|
  attachment.original_file.purge if ENV['DELETE_ORIGINALS'] == 'true'
end
```

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `app/workers/media_transcode_worker.rb` | Main job |
| `app/services/video_transcoder.rb` | ffmpeg wrapper |
| `app/services/audio_transcoder.rb` | Audio processing |
| `config/initializers/transcoding.rb` | Settings |
| `db/migrate/xxx_add_transcoding_fields.rb` | Schema |

## Dependencies

```bash
# System packages
apt install ffmpeg

# Check version (needs 4.0+)
ffmpeg -version
```

## Testing

```ruby
# spec/workers/media_transcode_worker_spec.rb
RSpec.describe MediaTranscodeWorker do
  it 'transcodes video to 720p' do
    attachment = create(:media_attachment, :video)
    described_class.new.perform(attachment.id)
    
    expect(attachment.reload.processing_status).to eq('completed')
    expect(attachment.variants['default']).to be_present
  end
  
  it 'handles ffmpeg failures gracefully' do
    attachment = create(:media_attachment, :corrupt_video)
    described_class.new.perform(attachment.id)
    
    expect(attachment.reload.processing_status).to eq('failed')
  end
end
```
