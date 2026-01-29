# Errordon Troubleshooting Guide

Solutions for common issues and problems.

---

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Docker Problems](#docker-problems)
3. [Database Issues](#database-issues)
4. [Email Problems](#email-problems)
5. [NSFW-Protect AI Issues](#nsfw-protect-ai-issues)
6. [Storage Quota Issues](#storage-quota-issues)
7. [Federation Problems](#federation-problems)
8. [Performance Issues](#performance-issues)
9. [UI/Theme Issues](#uitheme-issues)
10. [Embed/Media Issues](#embedmedia-issues)

---

## Installation Issues

### Installer Fails with "Permission Denied"

**Problem:** `bash: permission denied: install-docker.sh`

**Solution:**
```bash
chmod +x install-docker.sh
./install-docker.sh
```

### Docker Not Found

**Problem:** `docker: command not found`

**Solution:**
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

### Port Already in Use

**Problem:** `Error: bind: address already in use`

**Solution:**
```bash
# Find what's using the port
sudo lsof -i :3000
sudo lsof -i :5432

# Kill the process or change port in docker-compose.yml
```

---

## Docker Problems

### Container Keeps Restarting

**Problem:** Container in restart loop

**Solution:**
```bash
# Check logs
docker compose logs web --tail=100

# Common causes:
# 1. Missing .env.production
# 2. Database not ready
# 3. Invalid configuration
```

### Out of Disk Space

**Problem:** `no space left on device`

**Solution:**
```bash
# Clean Docker
docker system prune -a --volumes

# Check disk usage
df -h
du -sh /var/lib/docker/
```

### Container Can't Connect to Database

**Problem:** `could not connect to server: Connection refused`

**Solution:**
```bash
# Check if db container is running
docker compose ps db

# Check db logs
docker compose logs db

# Verify database exists
docker compose exec db psql -U postgres -c "\l"
```

### Build Fails

**Problem:** `ERROR: failed to solve: ...`

**Solution:**
```bash
# Clear build cache
docker builder prune

# Rebuild without cache
docker compose build --no-cache
```

---

## Database Issues

### Migration Failed

**Problem:** `Migrations are pending`

**Solution:**
```bash
# Run migrations
docker compose exec web bin/rails db:migrate

# If stuck, check status
docker compose exec web bin/rails db:migrate:status

# Reset (DANGER: loses data)
docker compose exec web bin/rails db:reset
```

### Database Connection Pool Exhausted

**Problem:** `could not obtain a connection from the pool`

**Solution:**
```bash
# Increase pool in .env.production
DB_POOL=50

# Restart services
docker compose restart web sidekiq
```

### Search Not Working

**Problem:** Search returns no results

**Solution:**
```bash
# Check Elasticsearch
curl http://localhost:9200/_cluster/health

# Reindex
docker compose exec web bin/tootctl search deploy

# Check index status
docker compose exec web bin/rails runner "puts Chewy.client.indices.get('*')"
```

---

## Email Problems

### Emails Not Sending

**Problem:** No emails received

**Solution:**
```bash
# Check Sidekiq mailer queue
docker compose exec web bin/rails runner "puts Sidekiq::Queue.new('mailers').size"

# Test email manually
docker compose exec web bin/rails runner "
  ActionMailer::Base.mail(
    to: 'test@example.com',
    from: 'noreply@your-domain.com',
    subject: 'Test',
    body: 'Test email'
  ).deliver_now
"

# Check SMTP settings
docker compose exec web bin/rails runner "
  puts ActionMailer::Base.smtp_settings.inspect
"
```

### SMTP Authentication Failed

**Problem:** `535 Authentication failed`

**Solution:**
```bash
# Verify credentials
SMTP_SERVER=smtp.mailgun.org
SMTP_PORT=587
SMTP_LOGIN=postmaster@mg.your-domain.com  # Not your account email
SMTP_PASSWORD=your-api-key-not-password
```

### Emails Going to Spam

**Solution:**
1. Set up SPF record in DNS:
   ```
   v=spf1 include:mailgun.org ~all
   ```
2. Set up DKIM (provider-specific)
3. Set up DMARC record:
   ```
   v=DMARC1; p=none; rua=mailto:dmarc@your-domain.com
   ```

---

## NSFW-Protect AI Issues

### Ollama Not Responding

**Problem:** `connection refused` to Ollama

**Solution:**
```bash
# Check if Ollama is running
systemctl status ollama
curl http://localhost:11434/api/tags

# Restart Ollama
sudo systemctl restart ollama

# Check logs
journalctl -u ollama -f
```

### Model Not Found

**Problem:** `model 'llava' not found`

**Solution:**
```bash
# Download model
ollama pull llava
ollama pull llama3

# Verify
ollama list
```

### AI Analysis Too Slow

**Problem:** Uploads taking too long

**Solution:**
```bash
# Check GPU availability (if using)
nvidia-smi

# Reduce image size for analysis
ERRORDON_NSFW_MAX_ANALYSIS_SIZE=1024  # pixels

# Or disable for certain file types
ERRORDON_NSFW_SKIP_AUDIO=true
```

### False Positives

**Problem:** Safe content being flagged

**Solution:**
```bash
# Increase threshold (more permissive)
ERRORDON_NSFW_PORN_THRESHOLD=0.9  # Default 0.8
ERRORDON_NSFW_HATE_THRESHOLD=0.85  # Default 0.7

# Review and whitelist
docker compose exec web bin/rails runner "
  report = Errordon::NsfwReport.last
  report.update!(reviewed: true, false_positive: true)
"
```

---

## Storage Quota Issues

### Quota Not Calculating

**Problem:** All users show 0 quota

**Solution:**
```bash
# Check if enabled
docker compose exec web bin/rails runner "
  puts ENV['ERRORDON_STORAGE_ENABLED']
"

# Check disk stats
docker compose exec web bin/rails runner "
  puts Errordon::StorageQuotaService.disk_stats
"

# Recalculate quotas
docker compose exec web bin/rails runner "
  Account.find_each do |a|
    Errordon::StorageQuotaService.recalculate_for(a)
  end
"
```

### Users Can't Upload Despite Having Quota

**Problem:** "Quota exceeded" when quota shows available

**Solution:**
```bash
# Check actual usage
docker compose exec web bin/rails runner "
  account = Account.find_by(username: 'user')
  puts Errordon::StorageQuotaService.usage_for(account)
  puts Errordon::StorageQuotaService.quota_for(account)
"

# Clear cache
docker compose exec web bin/rails runner "
  Rails.cache.clear
"
```

---

## Federation Problems

### Posts Not Federating

**Problem:** Posts not appearing on other instances

**Solution:**
```bash
# Check Sidekiq queues
docker compose exec web bin/rails runner "
  Sidekiq::Queue.all.each { |q| puts \"#{q.name}: #{q.size}\" }
"

# Check for delivery failures
docker compose exec web bin/rails runner "
  Account.local.first.statuses.last.tap do |s|
    puts s.id
    puts DeliveryFailureTracker.available_domains
  end
"

# Retry failed deliveries
docker compose exec web bin/tootctl accounts refresh --all
```

### Blocked by Other Instances

**Problem:** Your instance is blocked elsewhere

**Solution:**
1. Check blocklists:
   - [fediblock.org](https://fediblock.org)
   - [gardenfence.github.io](https://gardenfence.github.io)

2. Common reasons:
   - Open registration + spam
   - Missing moderation
   - Hate speech
   
3. Contact other admins to resolve

### Can't Follow Remote Users

**Problem:** `could not resolve account`

**Solution:**
```bash
# Try manual resolution
docker compose exec web bin/tootctl accounts resolve user@remote-instance.com

# Check WebFinger
curl "https://remote-instance.com/.well-known/webfinger?resource=acct:user@remote-instance.com"
```

---

## Performance Issues

### Slow Page Loads

**Solution:**
```bash
# Check which process is slow
docker stats

# Optimize database
docker compose exec db psql -U postgres mastodon -c "VACUUM ANALYZE;"

# Check for N+1 queries (in development)
# Add to Gemfile: gem 'bullet'
```

### High Memory Usage

**Solution:**
```bash
# Reduce Sidekiq concurrency
# In docker-compose.yml:
sidekiq:
  command: bundle exec sidekiq -c 10  # Default is 25

# Reduce Puma workers
# In config/puma.rb:
workers 2  # Instead of 4
```

### Sidekiq Backlog

**Problem:** Jobs piling up

**Solution:**
```bash
# Check queue sizes
docker compose exec web bin/rails runner "
  Sidekiq::Queue.all.each { |q| puts \"#{q.name}: #{q.size}\" }
"

# Clear stuck jobs (careful!)
docker compose exec web bin/rails runner "
  Sidekiq::Queue.new('default').clear
"

# Scale Sidekiq
docker compose up -d --scale sidekiq=3
```

---

## UI/Theme Issues

### Matrix Theme Not Loading

**Problem:** Default Mastodon theme shows

**Solution:**
```bash
# Check environment variable
echo $ERRORDON_THEME  # Should be 'matrix'

# Rebuild assets
docker compose exec web bin/rails assets:precompile
docker compose restart web

# Clear browser cache
# Ctrl+Shift+R or Cmd+Shift+R
```

### CSS Not Updating

**Problem:** Style changes not visible

**Solution:**
```bash
# Recompile assets
docker compose exec web bin/rails assets:precompile

# Clear Rails cache
docker compose exec web bin/rails tmp:cache:clear

# Restart with fresh assets
docker compose restart web
```

### Matrix Rain Freezing

**Problem:** Animation stutters/freezes

**Solution:**
This was fixed in v1.2.0. Update to latest:
```bash
git pull origin main
docker compose build web
docker compose up -d web
```

---

## Embed/Media Issues

### Embeds Not Playing

**Problem:** Spotify/hearthis.at/etc. shows preview but no player

**Solution:**
```bash
# Re-fetch preview cards
docker compose exec web bin/rails runner "
  Status.where(\"text LIKE ?\", '%spotify.com%').find_each do |s|
    FetchLinkCardService.new.call(s)
  end
"

# Check if cards have HTML
docker compose exec web bin/rails runner "
  PreviewCard.where(type: 'video').each do |c|
    puts \"#{c.provider_name}: #{c.html&.length || 0} chars\"
  end
"
```

### Video Transcoding Stuck

**Problem:** Videos stay "processing"

**Solution:**
```bash
# Check FFmpeg
docker compose exec web ffmpeg -version

# Check transcoding queue
docker compose exec web bin/rails runner "
  MediaAttachment.where(processing: :processing).count
"

# Retry stuck media
docker compose exec web bin/rails runner "
  MediaAttachment.where(processing: :processing).find_each do |m|
    PostProcessMediaWorker.perform_async(m.id)
  end
"
```

### Large Uploads Failing

**Problem:** Uploads over 100MB fail

**Solution:**
```bash
# Check Nginx limit
# In /etc/nginx/sites-available/errordon:
client_max_body_size 250M;

# Check Rails limit
MAX_VIDEO_SIZE=262144000  # 250MB

# Reload Nginx
sudo nginx -t && sudo systemctl reload nginx
```

---

## Getting More Help

### Collect Debug Information

```bash
# System info
docker compose exec web bin/rails runner "
  puts 'Ruby: ' + RUBY_VERSION
  puts 'Rails: ' + Rails.version
  puts 'Mastodon: ' + Mastodon::Version.to_s
  puts 'Errordon: 1.2.0'
"

# Recent errors
docker compose logs web --tail=200 | grep -i error
```

### Where to Ask

1. **GitHub Issues** - Bug reports with reproduction steps
2. **GitHub Discussions** - Questions and help
3. **Mastodon Forums** - General Mastodon questions

### Reporting Bugs

Include:
- Errordon version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs
- Screenshots if applicable
