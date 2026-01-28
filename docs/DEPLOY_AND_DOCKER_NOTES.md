# Deploy & Docker Notes

**Date:** 2026-01-28
**Purpose:** Deployment procedures, Docker configuration, and loop prevention rules

---

## 1. Docker Architecture

### Services (docker-compose.yml)

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `db` | postgres:14-alpine | - | Database |
| `redis` | redis:7-alpine | - | Cache/queue |
| `web` | Local build | 3000 | Puma web server |
| `streaming` | Local build | 4000 | WebSocket server |
| `sidekiq` | Local build | - | Background jobs |

### Key Configuration
```yaml
web:
  build: .  # Builds from local Dockerfile
  env_file: .env.production
  command: bundle exec puma -C config/puma.rb
  volumes:
    - ./public/system:/mastodon/public/system  # User uploads
```

### Networks
- `external_network` - Internet access
- `internal_network` - Service-to-service (no external)

---

## 2. Installation Scripts

### Primary: `install-docker.sh` (root level)
Interactive installation with prompts for:
- Domain & admin email
- SMTP configuration
- Matrix theme (y/N)
- Ollama AI for NSFW-Protect (Y/n)

```bash
# Recommended method (download first, then run)
curl -fsSL https://raw.githubusercontent.com/error-wtf/errordon/main/install-docker.sh -o install-docker.sh
bash install-docker.sh

# NOT recommended (can break interactive prompts)
# curl ... | bash  <- DON'T DO THIS
```

### Deploy Scripts (`deploy/`)
| Script | Purpose |
|--------|---------|
| `quick-install.sh` | Minimal install |
| `interactive-install.sh` | Full interactive |
| `deploy.sh` | Deploy updates |
| `update.sh` | Pull & rebuild |
| `backup.sh` | Database backup |

---

## 3. Environment Variables

### Core (`.env.production`)
```bash
LOCAL_DOMAIN=your-domain.com
SINGLE_USER_MODE=false
SECRET_KEY_BASE=<generated>
OTP_SECRET=<generated>

# Database
DB_HOST=db
DB_USER=postgres
DB_PASS=<generated>
DB_NAME=mastodon_production

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# SMTP
SMTP_SERVER=smtp.example.com
SMTP_PORT=587
SMTP_LOGIN=your@email.com
SMTP_PASSWORD=<password>
SMTP_FROM_ADDRESS=notifications@your-domain.com
```

### Errordon-Specific
```bash
# NSFW-Protect AI
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://localhost:11434
ERRORDON_NSFW_ADMIN_EMAIL=admin@your-domain.com

# Registration
ERRORDON_INVITE_ONLY=true
ERRORDON_REQUIRE_AGE_18=true

# Theme
ERRORDON_THEME=matrix  # matrix, default, light
ERRORDON_MATRIX_LANDING_ENABLED=true

# Active Record Encryption (required since Mastodon 4.x)
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<generated>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<generated>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<generated>
```

---

## 4. Nginx Configuration

**File:** `deploy/nginx.conf`

### Key Settings
```nginx
# Upload limit (250MB for video)
client_max_body_size 250m;

# Matrix terminal - no caching
location /matrix/ {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
}

# WebSocket streaming
location /api/v1/streaming {
    proxy_pass http://127.0.0.1:4000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

---

## 5. Common Operations

### Start/Stop
```bash
cd ~/errordon
docker compose up -d          # Start all
docker compose down           # Stop all
docker compose restart web    # Restart web only
```

### View Logs
```bash
docker compose logs -f web      # Web server logs
docker compose logs -f sidekiq  # Background job logs
docker compose logs -f db       # Database logs
```

### Database
```bash
# Run migrations
docker compose exec web bin/rails db:migrate

# Rails console
docker compose exec web bin/rails c

# Backup
docker compose exec db pg_dump -U postgres mastodon_production > backup.sql

# Restore
cat backup.sql | docker compose exec -T db psql -U postgres mastodon_production
```

### Rebuild After Code Changes
```bash
git pull origin master
docker compose build
docker compose up -d
```

---

## 6. Loop Failure Mode from "Fixing Errordon Docker Install.md"

### Summary of the Loop Pattern

From the extensive troubleshooting log, a **loop failure** occurred when:

1. **Symptom:** Cache issues with Matrix terminal CSS/JS
2. **Action:** Agent made a fix (commit + push)
3. **Result:** User tested → still broken
4. **Repeat:** Agent made another fix → still broken → repeat

**User's explicit frustration:**
> "jetzt ist das nen fucking loop - ich bekomme jetzt nen ausraster - höre auf mich abzufucken"

### What Was Repeated
- Multiple commits to fix caching:
  - Added `?t=Date.now()` cache-buster
  - Changed to inline CSS
  - Added no-cache meta tags
  - Added no-cache nginx headers
- Each fix involved: edit → commit → push → `git pull` on server → test → fail

### Why It Repeated
1. **Root cause misdiagnosis** - Assumed browser cache when issue was server-side
2. **No verification step** - Didn't check if changes actually deployed
3. **Incremental guessing** - Each fix was a guess without evidence
4. **No stop condition** - Kept trying variations of the same approach

### Signals That Indicated Looping
- Same symptom persisted after 3+ attempts
- User frustration escalating
- No new diagnostic information gathered between attempts
- Agent trying variations of same fix type

---

## 7. Loop Breakers (Stop Conditions)

### Rule 1: Two-Strike Rule
**If a command/step fails twice with no new evidence, STOP.**

```
Attempt 1: Fix X → Fail
Attempt 2: Fix X variant → Fail
→ STOP RETRYING THIS APPROACH
→ Write diagnosis
→ Propose different approach or request more info
```

### Rule 2: Mandatory Verification
Before claiming a fix works:
1. Verify the change is actually on the server
2. Verify the service restarted/reloaded
3. Test with cache bypass (incognito, curl, different device)

### Rule 3: No Destructive Cleanup to Break Loops
**NEVER do:**
```bash
rm -rf ~/errordon          # Can fail on root-owned files
docker system prune -af    # Can break other containers
```

**Instead:**
```bash
# Safe cleanup with explicit scope
docker compose down -v     # Stop and remove volumes
sudo rm -rf ~/errordon     # Only with sudo, only this directory
```

### Rule 4: Log Stop Decisions
When stopping retries, document:
1. What was attempted (with commit hashes)
2. What evidence showed it didn't work
3. Why continued retrying won't help
4. Recommended next action

**Example entry:**
```markdown
## Stop Decision: Cache Fix Loop
- Attempts: 3 (commits abc123, def456, ghi789)
- Evidence: Browser still shows old version despite:
  - Inline CSS
  - No-cache headers
  - Cache-buster params
- Diagnosis: Server may not be pulling latest code
- Next action: Verify `git log` on server matches repo
```

---

## 8. Safe Deployment Checklist

### Before Deploying
- [ ] Code tested locally (if possible)
- [ ] No breaking migration changes
- [ ] `.env.production` has all required vars
- [ ] Backup database if touching data

### Deploy Steps
```bash
# 1. Pull code
cd ~/errordon
git pull origin master

# 2. Rebuild (only if Dockerfile/deps changed)
docker compose build

# 3. Run migrations (only if db/migrate/ changed)
docker compose exec web bin/rails db:migrate

# 4. Restart services
docker compose up -d

# 5. Verify health
docker compose ps
curl -I https://your-domain.com/health
```

### After Deploying
- [ ] Check `docker compose ps` - all services "Up"
- [ ] Check `docker compose logs web` - no errors
- [ ] Test critical paths (login, post, upload)
- [ ] Check `/health` endpoint returns OK

---

## 9. Known Docker Hazards

### 1. Root-Owned Volumes
**Problem:** `postgres14/` directory becomes root-owned, blocking `rm -rf`

**Solution:**
```bash
# Stop containers first
docker compose down -v

# Remove with sudo
sudo rm -rf ~/errordon/postgres14
```

### 2. Role "mastodon" Does Not Exist
**Problem:** Database setup fails because mastodon user doesn't exist

**Cause:** `docker-compose.yml` uses `POSTGRES_HOST_AUTH_METHOD=trust` but doesn't create user

**Solution:** The installer now handles this, but if it fails:
```bash
docker compose exec db psql -U postgres -c "CREATE USER mastodon WITH CREATEDB PASSWORD 'your_db_pass';"
docker compose exec web bin/rails db:setup
```

### 3. Active Record Encryption Missing
**Problem:** Rails errors about missing encryption keys

**Solution:** Add to `.env.production`:
```bash
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(openssl rand -base64 32)
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -base64 32)
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -base64 32)
```

---

## 10. Rollback Procedure

If deployment fails:

### Quick Rollback (revert code)
```bash
cd ~/errordon
git reset --hard HEAD~1   # Revert last commit
docker compose build
docker compose up -d
```

### Full Rollback (restore backup)
```bash
# Stop services
docker compose down

# Restore database
cat backup.sql | docker compose exec -T db psql -U postgres mastodon_production

# Checkout known-good version
git checkout <known-good-tag>
docker compose build
docker compose up -d
```

---

## Summary

| Topic | Key Point |
|-------|-----------|
| Installation | Use `install-docker.sh`, download first then run |
| Services | 5 containers: db, redis, web, streaming, sidekiq |
| Loop Prevention | Two-strike rule, mandatory verification, no destructive cleanup |
| Hazards | Root volumes, missing DB user, encryption keys |
| Rollback | `git reset --hard` + rebuild, or restore backup |
