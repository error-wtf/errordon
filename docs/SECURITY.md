# Errordon Security

## Components

| Component | Purpose |
|-----------|---------|
| `SecurityService` | File upload validation |
| `MediaValidator` | ffprobe media analysis |
| `AuditLogger` | Security event logging |
| `errordon_security.rb` | Configuration |

## ENV Variables

```bash
ERRORDON_SECURITY_STRICT=true
ERRORDON_BLOCK_SUSPICIOUS_IPS=true
ERRORDON_MAX_REQUEST_SIZE=314572800
ERRORDON_AUDIT_FILE=true
```

## Blocked Content

- Executables (.exe, .bat, .sh, .ps1)
- Scripts (.php, .js, .vbs)
- Path traversal (../)
- Null bytes
- Polyglot files (GIFAR)

## Usage

```ruby
# Validate upload
Errordon::SecurityService.new(file).validate!

# Validate media
Errordon::MediaValidator.new(path, expected_type: :video).validate!

# Log event
Errordon::AuditLogger.log_security_event(:file_rejected, details)
```
