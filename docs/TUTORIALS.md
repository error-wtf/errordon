# Errordon Tutorials

Step-by-step guides for common tasks.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [First-Time Setup](#first-time-setup)
3. [Configuring NSFW-Protect AI](#configuring-nsfw-protect-ai)
4. [Managing Storage Quotas](#managing-storage-quotas)
5. [Customizing the Matrix Theme](#customizing-the-matrix-theme)
6. [Importing Custom Emojis](#importing-custom-emojis)
7. [Setting Up Email](#setting-up-email)
8. [Creating Invite Codes](#creating-invite-codes)
9. [Moderating Content](#moderating-content)
10. [Backup Strategies](#backup-strategies)

---

## Getting Started

### Prerequisites

Before installing Errordon, ensure you have:

- A VPS with at least 4GB RAM
- A domain name pointing to your server
- Basic Linux command line knowledge
- SSH access to your server

### Quick Installation

```bash
# SSH into your server
ssh root@your-server-ip

# Download installer
curl -fsSL https://raw.githubusercontent.com/error-wtf/errordon/main/install-docker.sh -o install-docker.sh

# Run installer
bash install-docker.sh
```

The installer will guide you through the configuration.

---

## First-Time Setup

### 1. Access Admin Interface

After installation, access your instance at `https://your-domain.com`.

Log in with your admin credentials and go to **Preferences → Administration**.

### 2. Configure Site Settings

Navigate to **Administration → Server Settings → Branding**:

| Setting | Recommended Value |
|---------|-------------------|
| Site Title | Your Instance Name |
| Short Description | Brief description (160 chars) |
| Contact Email | admin@your-domain.com |
| Registrations | Invite Only |

### 3. Enable Features

Navigate to **Administration → Server Settings → Features**:

- ✅ Enable Trends
- ✅ Enable Profile Directory
- ✅ Enable Search

### 4. Create First Invite

```bash
# Generate invite code
docker compose exec web bin/rails mastodon:invite

# Or via admin UI:
# Administration → Invites → Generate Invite Link
```

---

## Configuring NSFW-Protect AI

### Step 1: Install Ollama

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
sudo systemctl enable ollama
sudo systemctl start ollama
```

### Step 2: Download AI Models

```bash
# Vision model for images/videos (required)
ollama pull llava

# Text model for hate speech (recommended)
ollama pull llama3

# Verify models
ollama list
```

### Step 3: Configure Environment

Add to `.env.production`:

```bash
# Enable NSFW-Protect
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://localhost:11434
ERRORDON_NSFW_ADMIN_EMAIL=admin@your-domain.com

# Automatic actions
ERRORDON_NSFW_AUTO_DELETE=true
ERRORDON_NSFW_AUTO_FREEZE=true
ERRORDON_NSFW_AUTO_NOTIFY=true

# Strike thresholds
ERRORDON_NSFW_PORN_THRESHOLD=0.8
ERRORDON_NSFW_HATE_THRESHOLD=0.7
```

### Step 4: Restart Services

```bash
docker compose up -d --force-recreate
```

### Step 5: Verify AI is Working

```bash
# Check Ollama status
curl http://localhost:11434/api/tags

# Check logs
docker compose logs web | grep -i "nsfw\|ollama"
```

### Monitoring AI Activity

View AI decisions in the admin panel:
**Administration → Moderation → NSFW Reports**

Or via command line:
```bash
docker compose exec web bin/rails runner "
  Errordon::NsfwReport.recent.each do |r|
    puts \"#{r.created_at}: #{r.result} - #{r.media_attachment.id}\"
  end
"
```

---

## Managing Storage Quotas

### Understanding the Quota System

Errordon uses a **fair-share storage system**:

```
Total User Quota = Base Quota + (Fair Share Pool / Active Users)

Where:
- Base Quota = 1 GB (configurable)
- Fair Share Pool = 60% of free disk space
- Active Users = Users with posts in last 30 days
```

### Configure Quotas

In `.env.production`:

```bash
ERRORDON_STORAGE_ENABLED=true
ERRORDON_STORAGE_BASE_QUOTA=1073741824          # 1 GB
ERRORDON_STORAGE_MAX_QUOTA=10737418240          # 10 GB max
ERRORDON_STORAGE_FAIR_SHARE_PERCENT=60          # 60% of disk
ERRORDON_STORAGE_RESERVED_DISK_PERCENT=20       # Keep 20% free
```

### Check User Quota

Via API:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://your-domain.com/api/v1/errordon/quotas/current
```

Response:
```json
{
  "used_bytes": 524288000,
  "quota_bytes": 2147483648,
  "used_percent": 24.4,
  "remaining_bytes": 1623195648
}
```

### Admin: Override User Quota

```bash
docker compose exec web bin/rails runner "
  account = Account.find_by(username: 'someuser')
  Errordon::StorageQuota.create!(
    account: account,
    custom_quota: 5.gigabytes,
    admin_notes: 'Power user - increased quota'
  )
"
```

---

## Customizing the Matrix Theme

### Enable Matrix Theme

In `.env.production`:

```bash
ERRORDON_THEME=matrix
ERRORDON_THEME_COLOR=green  # Options: green, red, blue, purple
```

### Toggle via Keyboard

Press `Ctrl + Shift + M` to toggle the Matrix theme on/off.

### Customize Colors

Edit `app/javascript/styles/errordon_matrix.scss`:

```scss
:root {
  --matrix-primary: #00ff00;        // Main green
  --matrix-secondary: #003300;      // Dark green
  --matrix-background: #0a0a0a;     // Near black
  --matrix-text: #ffffff;           // White text
  --matrix-glow: rgba(0, 255, 0, 0.5);
}
```

### Add Custom Matrix Rain

The Matrix rain animation can be customized:

```javascript
// app/javascript/errordon/matrix/index.js
const config = {
  fontSize: 14,
  speed: 1.5,
  density: 0.05,
  characters: 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789',
};
```

---

## Importing Custom Emojis

### Built-in Emojis

Errordon includes 127 custom emojis. Import them:

```bash
docker compose exec web bin/rails errordon:import_emojis
```

### Add Your Own Emojis

1. Create SVG files (recommended) or PNG (128x128):

```bash
public/emoji/custom/
├── my_emoji.svg
├── another_emoji.png
└── ...
```

2. Import via admin UI:
   - **Administration → Custom Emojis → Upload**

3. Or via command line:

```bash
docker compose exec web bin/rails runner "
  CustomEmoji.create!(
    shortcode: 'my_emoji',
    image: File.open('public/emoji/custom/my_emoji.svg'),
    visible_in_picker: true
  )
"
```

### Emoji Categories

Organize emojis into categories:

```bash
docker compose exec web bin/rails runner "
  emoji = CustomEmoji.find_by(shortcode: 'my_emoji')
  emoji.update!(category: 'My Category')
"
```

---

## Setting Up Email

### Using Mailgun (Recommended)

1. Create Mailgun account at [mailgun.com](https://mailgun.com)
2. Add and verify your domain
3. Configure in `.env.production`:

```bash
SMTP_SERVER=smtp.mailgun.org
SMTP_PORT=587
SMTP_LOGIN=postmaster@mg.your-domain.com
SMTP_PASSWORD=your-mailgun-key
SMTP_FROM_ADDRESS=notifications@your-domain.com
SMTP_AUTH_METHOD=plain
SMTP_OPENSSL_VERIFY_MODE=none
```

### Test Email

```bash
docker compose exec web bin/rails runner "
  UserMailer.confirmation_instructions(
    User.first,
    'test-token'
  ).deliver_now
"
```

### Check Email Queue

```bash
docker compose exec web bin/rails runner "
  puts Sidekiq::Queue.new('mailers').size
"
```

---

## Creating Invite Codes

### Via Command Line

```bash
# Single-use invite
docker compose exec web bin/rails mastodon:invite

# Multi-use invite (10 uses)
docker compose exec web bin/rails mastodon:invite USES=10

# Invite with expiration
docker compose exec web bin/rails mastodon:invite EXPIRES=7d
```

### Via Admin UI

1. Go to **Administration → Invites**
2. Click **Generate Invite Link**
3. Configure:
   - Max uses (blank = unlimited)
   - Expiration date

### Track Invite Usage

```bash
docker compose exec web bin/rails runner "
  Invite.where('uses > 0').each do |i|
    puts \"#{i.code}: #{i.uses}/#{i.max_uses || '∞'} by #{i.user.account.username}\"
  end
"
```

---

## Moderating Content

### View Reports

**Administration → Moderation → Reports**

### Quick Actions

| Action | Effect |
|--------|--------|
| Resolve | Close report, no action |
| Silence | Hide from public timelines |
| Suspend | Remove from instance |
| Delete Content | Remove specific posts |

### Batch Moderation

```bash
# Silence all accounts from a domain
docker compose exec web bin/rails runner "
  Account.where(domain: 'spam-domain.com').update_all(silenced_at: Time.current)
"

# Remove all media from a user
docker compose exec web bin/rails runner "
  account = Account.find_by(username: 'spammer')
  account.media_attachments.destroy_all
"
```

### Domain Blocks

**Administration → Federation → Domain Blocks**

| Severity | Effect |
|----------|--------|
| Silence | Hide from public timelines |
| Suspend | Block all interaction |
| None | Reject media only |

---

## Backup Strategies

### Automated Daily Backups

```bash
# Add to crontab
crontab -e

# Add this line:
0 3 * * * /home/errordon/errordon/deploy/backup.sh >> /var/log/backup.log 2>&1
```

### Manual Backup

```bash
# Database only
docker compose exec db pg_dump -U postgres mastodon > backup.sql

# Full backup (database + media)
./deploy/backup.sh
```

### Offsite Backup (S3)

```bash
# Install AWS CLI
apt install awscli

# Configure
aws configure

# Sync backups to S3
aws s3 sync /home/errordon/backups/ s3://your-bucket/errordon-backups/
```

### Restore from Backup

```bash
# Stop services
docker compose stop web sidekiq

# Restore database
cat backup.sql | docker compose exec -T db psql -U postgres mastodon

# Restart
docker compose start web sidekiq
```

---

## Next Steps

- [DEPLOYMENT.md](DEPLOYMENT.md) - Full deployment guide
- [CONFIGURATION.md](CONFIGURATION.md) - All configuration options
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
