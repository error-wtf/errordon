# Errordon

[![Fediverse Compatible](https://img.shields.io/badge/Fediverse-Compatible-blueviolet)](https://joinmastodon.org/)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-0.3.0-green.svg)](https://github.com/error-wtf/errordon)
[![EU Law Compliant](https://img.shields.io/badge/EU%20Law-Compliant-blue.svg)](https://eur-lex.europa.eu/)
[![German Law](https://img.shields.io/badge/German%20Law-StGB%20%C2%A7130%2C%20%C2%A7184b%2C%20%C2%A786a-red.svg)](https://www.gesetze-im-internet.de/stgb/)
[![NSFW-Protect AI](https://img.shields.io/badge/NSFW--Protect-AI%20Powered-ff4444.svg)](docs/NSFW_PROTECT_ARCHITECTURE.md)

---

<div align="center">

## 🛡️ A Safe Fediverse Instance for European Law Compliance

**Errordon** is a Mastodon fork designed for instance operators who want to run a **legally compliant** social media platform under **European and German law** — with **AI-assisted content moderation**.

</div>

---

## 🚫 ZERO TOLERANCE POLICY

<table>
<tr>
<td width="33%" align="center">

### 🔞 NO PORN
Every upload is **automatically scanned** by AI. Pornographic content is **immediately deleted** and accounts are **frozen**.

</td>
<td width="33%" align="center">

### 🚫 NO HATE
Hate speech, antisemitism, and incitement (§130 StGB) trigger **automatic review** and **escalating bans**.

</td>
<td width="33%" align="center">

### ⛔ NO FASCISM
Nazi symbols, Holocaust denial, and unconstitutional content (§86a StGB) result in **permanent bans**.

</td>
</tr>
</table>

---

## 🤖 NSFW-Protect AI System

Errordon includes a revolutionary **AI-powered content moderation system** that helps instance administrators enforce European law with minimal manual effort.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        NSFW-PROTECT AI PIPELINE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   📤 UPLOAD                    🤖 AI ANALYSIS                           │
│   ───────────                  ──────────────                           │
│   User uploads                 Ollama AI checks:                        │
│   image/video                  • Pornographic content                   │
│         │                      • Hate symbols                           │
│         ▼                      • Illegal material                       │
│   ┌─────────────┐                     │                                 │
│   │  INTERCEPT  │────────────────────▶│                                 │
│   └─────────────┘                     ▼                                 │
│                              ┌────────────────┐                         │
│                              │  SAFE? ──▶ ✅   │                         │
│                              │  PORN? ──▶ 🚫   │──▶ Auto-delete + Strike │
│                              │  HATE? ──▶ 🚫   │──▶ Review + Strike      │
│                              │  CSAM? ──▶ 🚨   │──▶ Ban + Authorities    │
│                              └────────────────┘                         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Strike System (Escalating Consequences)

| Strike | Porn Violation | Hate Violation |
|--------|----------------|----------------|
| 1st | 24 hours freeze | Warning + Review |
| 2nd | 3 days freeze | 3 days freeze |
| 3rd | 7 days freeze | 7 days freeze |
| 4th | 30 days freeze | **PERMANENT** |
| 5th+ | **PERMANENT** | — |

### Scheduled Jobs (automatic via Sidekiq)

| Job | Schedule | Purpose |
|-----|----------|---------|
| Blocklist Update | 3:00 AM | Update porn domain list |
| GDPR Cleanup | 4:00 AM | Delete expired data, anonymize IPs |
| AI Snapshot Cleanup | 4:30 AM | Delete SAFE snapshots after 14 days |
| Video Cleanup | 5:00 AM | Shrink old videos to 480p |
| Freeze Cleanup | Hourly | Unfreeze expired accounts |
| Weekly Summary | Mon 9 AM | Email stats to admin |

### Instance-Wide Protection

- **10+ active alarms** → Instance posting freeze for flagged accounts
- **CSAM detection** → Immediate permanent ban + law enforcement notification
- **Admin email alerts** → Real-time notifications for all violations

---

## ⚖️ Legal Framework (German/EU Law)

This instance software is designed to help operators comply with:

| Law | Description | Errordon Response |
|-----|-------------|-------------------|
| **§130 StGB** | Volksverhetzung (Incitement) | AI detection + auto-ban |
| **§184b StGB** | Child pornography | Immediate ban + authorities |
| **§86a StGB** | Unconstitutional symbols | AI detection + permanent ban |
| **§131 StGB** | Glorification of violence | AI review + escalating bans |
| **NetzDG** | Network Enforcement Act | IP logging, content removal |
| **DSGVO/GDPR** | Data protection | Privacy-first defaults |

### Legal Documents Included

- ✅ **Terms of Service** (German law compliant)
- ✅ **Privacy Policy** (DSGVO/GDPR compliant)
- ✅ **Community Guidelines** (Clear rules with legal references)

---

## 🔐 Registration Security

Errordon supports **invite-only registration** with mandatory checks:

```
┌─────────────────────────────────────────┐
│         REGISTRATION FLOW               │
├─────────────────────────────────────────┤
│  1. ✉️  Invite Code Required             │
│     └─ Max 3 uses per code              │
│                                         │
│  2. 🔞 Age Verification                  │
│     └─ Checkbox: "I am 18 or older"     │
│                                         │
│  3. 📜 Legal Acceptance                  │
│     └─ Terms of Service                 │
│     └─ Privacy Policy                   │
│     └─ Community Guidelines             │
│                                         │
│  4. ✅ Email Verification                │
└─────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Enable NSFW-Protect AI

```bash
# Install Ollama for AI content moderation
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llava    # Vision model for images/videos
ollama pull llama3   # Text model for hate speech

# Enable in .env.production
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://localhost:11434
ERRORDON_NSFW_ADMIN_EMAIL=admin@your-instance.com
ERRORDON_INVITE_ONLY=true
ERRORDON_REQUIRE_AGE_18=true
```

### One-Line Installation (Ubuntu/Debian)

```bash
curl -sSL https://raw.githubusercontent.com/error-wtf/errordon/main/install.sh | bash
```

The installer will ask if you want to enable NSFW-Protect AI.

### Docker Deployment

```bash
git clone https://github.com/error-wtf/errordon.git
cd errordon
cp deploy/.env.example .env.production
# Edit .env.production with your settings
./deploy/deploy.sh your-domain.com
```

---

## ✨ Additional Features

Beyond legal compliance, Errordon includes:

| Feature | Description |
|---------|-------------|
| 🎬 **Profile Media Tabs** | Separate Videos/Audio/Images tabs |
| 🎨 **Matrix Theme** | Cyberpunk green UI (opt-in) |
| 😎 **25 Custom Emojis** | Matrix/Hacker/Nerd themed |
| 📤 **250MB Uploads** | With server-side transcoding |
| 🔒 **Privacy-First** | Strict defaults via ENV |
| 📊 **Admin Quotas** | Per-user storage limits |
| 🔍 **Media Filters** | Originals only, Alt text, Public |
| 📹 **Auto Video Cleanup** | Shrink videos >7 days to 480p |
| 🗑️ **GDPR Compliance** | Auto-delete expired data |
| 📧 **Evidence Emails** | Forensic reports for violations |

---

## 🎨 Matrix Theme

Errordon includes an optional **Matrix-style cyberpunk theme** with:

- **Green neon color palette** (`#00ff00`)
- **VT323 hacker font** for headings (UTF-8 compatible)
- **Glitch effects** on hover
- **Dark background** with white text for readability
- **100% Fediverse-compatible** (opt-in, no structural changes)

### Toggle Theme

```
Keyboard: Ctrl + Shift + M
```

Or set default via environment:
```bash
ERRORDON_THEME=matrix  # Options: matrix, default, light
```

## 😎 Custom Emojis

25 Matrix/Hacker/Nerd themed emojis in 3 categories:

| Category | Emojis |
|----------|--------|
| **Matrix** | `:matrix_code:` `:red_pill:` `:blue_pill:` `:skull_matrix:` `:matrix_cat:` `:glitch:` |
| **Hacker** | `:hacker:` `:terminal:` `:binary:` `:encrypt:` `:access_granted:` `:access_denied:` `:anonymous:` `:wifi_hack:` `:firewall:` `:sudo:` |
| **Nerd** | `:nerd:` `:keyboard:` `:code:` `:bug:` `:cyber_eye:` `:robot:` `:coffee_code:` `:git:` `:loading:` |

### Import Emojis

```bash
bundle exec rails errordon:import_emojis
```

## 🔧 API Endpoints

### Errordon-specific APIs

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/errordon/quotas/current` | GET | Current user's quota stats |
| `/api/v1/errordon/quotas` | GET | Admin: All user quotas |
| `/api/v1/errordon/quotas/:id` | GET/PUT | Admin: User quota details/update |
| `/api/v1/errordon/transcoding/:media_id/status` | GET | Transcoding status for media |

### Enhanced Mastodon APIs

| Endpoint | Enhancement |
|----------|-------------|
| `/api/v1/accounts/:id/statuses` | New `media_type` param: `video\|audio\|image` |

## 🎯 Goals

- **Profile Media Columns**: Separate tabs for Videos, Audio, Images in user profiles
- **Filter UI**: Filter by "originals only", "with alt text", visibility
- **Large Uploads**: Up to 250MB for video/audio with automatic transcoding
- **Privacy Defaults**: Strict preset inspired by chaos.social principles

## 📁 Repository Structure

```
errordon/
├── app/
│   ├── controllers/api/v1/errordon/     # Errordon API controllers
│   │   ├── quotas_controller.rb          # Quota management
│   │   └── transcoding_controller.rb     # Transcoding status
│   ├── services/errordon/               # Business logic
│   │   ├── quota_service.rb              # Quota calculations
│   │   ├── security_service.rb           # File validation
│   │   ├── audit_logger.rb               # Security logging
│   │   ├── video_transcoder_service.rb   # Video transcoding
│   │   └── audio_transcoder_service.rb   # Audio transcoding
│   ├── workers/errordon/                # Background jobs
│   │   └── media_transcode_worker.rb     # Sidekiq worker
│   └── javascript/
│       ├── mastodon/features/errordon/   # React components
│       │   ├── matrix_theme.ts           # Theme controller
│       │   ├── admin_quotas.tsx          # Admin UI
│       │   └── video_grid.tsx            # Video grid
│       └── styles/errordon_matrix.scss   # Matrix theme styles
├── config/
│   ├── initializers/errordon_*.rb       # Feature configs
│   ├── routes/errordon.rb               # API routes
│   └── locales/errordon.*.yml           # Translations
├── public/emoji/errordon/               # 25 custom SVG emojis
├── lib/tasks/errordon_emojis.rake       # Emoji import task
├── deploy/                              # Production configs
├── docs/                                # Documentation
└── spec/initializers/                   # Tests
```

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [NSFW_PROTECT_ARCHITECTURE.md](docs/NSFW_PROTECT_ARCHITECTURE.md) | Technical details of AI moderation |
| [GDPR_COMPLIANCE.md](docs/GDPR_COMPLIANCE.md) | Data retention & privacy |
| [VIDEO_CLEANUP.md](docs/VIDEO_CLEANUP.md) | Auto video shrinking |
| [TRANSCODING_PIPELINE.md](docs/TRANSCODING_PIPELINE.md) | Media transcoding |
| [Terms of Service](public/terms_of_service.md) | Legal terms (DE/EN) |
| [Privacy Policy](public/privacy_policy.md) | DSGVO/GDPR compliant |
| [Community Guidelines](public/community_guidelines.md) | Rules with legal references |

---

## 🏛️ Why This Exists

Running a social media instance in Germany/EU comes with **legal responsibilities**:

- **NetzDG** requires removal of illegal content within 24 hours
- **§184b StGB** criminalizes hosting of CSAM
- **§130 StGB** prohibits hosting hate speech and incitement
- Instance operators can be held **personally liable**

**Errordon helps you comply** by automating detection and enforcement — so you can run a safe community without becoming a full-time moderator.

---

## 🤝 For Instance Operators

This software is for you if:

- ✅ You want to run a **safe, family-friendly** Fediverse instance
- ✅ You want **EU/German law compliance** out of the box
- ✅ You want **AI assistance** for content moderation
- ✅ You want **clear legal documents** for your users
- ✅ You believe in **free speech within the law** (no fascism, no porn, no hate)

---

## 📜 License

**AGPLv3** - Compatible with Mastodon's license.

All Errordon additions are also AGPLv3.

---

## 🔗 Links

- [Mastodon](https://github.com/mastodon/mastodon) - Upstream project
- [Ollama](https://ollama.com/) - AI backend for NSFW-Protect
- [German Criminal Code (StGB)](https://www.gesetze-im-internet.de/stgb/) - Legal framework

---

<div align="center">

**Errordon** — *A Safe Fediverse for Europe* 🇪🇺🇩🇪

*NO PORN • NO HATE • NO FASCISM*

</div>
