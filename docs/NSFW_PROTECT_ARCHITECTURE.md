# NSFW-Protect-KI System Architecture

## Overview

A comprehensive AI-powered content moderation system for Errordon with automatic NSFW detection,
escalating ban policy, and legally compliant registration flow.

## System Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           NSFW-PROTECT-KI SYSTEM                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │  UPLOAD      │    │   REPORT     │    │   ADMIN      │                  │
│  │  INTERCEPTOR │    │   HANDLER    │    │   PANEL      │                  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                  │
│         │                   │                   │                          │
│         └───────────────────┼───────────────────┘                          │
│                             ▼                                              │
│                 ┌───────────────────────┐                                  │
│                 │   OLLAMA AI SERVICE   │                                  │
│                 │  ┌─────────────────┐  │                                  │
│                 │  │ Image Analyzer  │  │                                  │
│                 │  │ Video Snapshots │  │                                  │
│                 │  │ Text Classifier │  │                                  │
│                 │  └─────────────────┘  │                                  │
│                 └───────────┬───────────┘                                  │
│                             ▼                                              │
│                 ┌───────────────────────┐                                  │
│                 │   STRIKE MANAGER      │                                  │
│                 │  ┌─────────────────┐  │                                  │
│                 │  │ Escalation      │  │                                  │
│                 │  │ Freeze Logic    │  │                                  │
│                 │  │ Email Alerts    │  │                                  │
│                 │  └─────────────────┘  │                                  │
│                 └───────────────────────┘                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 1. Database Schema

### New Tables

```ruby
# nsfw_protect_strikes - Tracks user violations
create_table :nsfw_protect_strikes do |t|
  t.references :account, null: false, foreign_key: true
  t.integer :strike_type, null: false  # 0=porn, 1=hate, 2=illegal, 3=other
  t.integer :strike_count, default: 1
  t.datetime :freeze_until
  t.boolean :permanent_freeze, default: false
  t.inet :ip_address
  t.references :status, foreign_key: true
  t.references :media_attachment, foreign_key: true
  t.text :ai_analysis_result
  t.float :ai_confidence
  t.timestamps
end

# nsfw_protect_config - Instance-wide settings
create_table :nsfw_protect_config do |t|
  t.boolean :enabled, default: false
  t.boolean :porn_detection_enabled, default: true
  t.boolean :hate_detection_enabled, default: true
  t.boolean :auto_delete_violations, default: true
  t.string :admin_alert_email
  t.string :ollama_endpoint, default: 'http://localhost:11434'
  t.string :ollama_model, default: 'llava'
  t.integer :instance_alarm_threshold, default: 10
  t.boolean :instance_frozen, default: false
  t.timestamps
end

# invite_codes - Enhanced invite system
create_table :errordon_invite_codes do |t|
  t.references :account, null: false, foreign_key: true
  t.string :code, null: false, index: { unique: true }
  t.integer :uses, default: 0
  t.integer :max_uses, default: 3
  t.datetime :expires_at
  t.boolean :active, default: true
  t.timestamps
end
```

### Account Extensions

```ruby
# Add to accounts table
add_column :accounts, :nsfw_strike_count, :integer, default: 0
add_column :accounts, :nsfw_frozen_until, :datetime
add_column :accounts, :nsfw_permanent_freeze, :boolean, default: false
add_column :accounts, :nsfw_ever_frozen, :boolean, default: false
add_column :accounts, :last_strike_ip, :inet
```

## 2. Strike/Ban Policy

### Porn Content (Zero Tolerance - Every Upload Checked)

| Strike | Duration | Action |
|--------|----------|--------|
| 1st | 24 hours | Account freeze, content deleted, IP logged |
| 2nd | 3 days | Account freeze, content deleted |
| 3rd | 7 days | Account freeze, content deleted |
| 4th | 30 days | Account freeze, content deleted |
| 5th+ | PERMANENT | Account permanently frozen |

### Hate/Illegal Content (Report-Based)

| Strike | Duration | Action |
|--------|----------|--------|
| 1st | Warning + 24h review | Content hidden, admin notified |
| 2nd | 3 days | Account freeze |
| 3rd | 7 days | Account freeze |
| 4th+ | PERMANENT | Account permanently frozen |

### Instance-Wide Freeze

- When 10+ active alarms exist → Instance posting freeze
- Only accounts with ANY freeze history are affected
- Clears when all alarms resolved by admin

## 3. Ollama AI Integration

### System Prompt (German Law Compliant)

```
Du bist ein Content-Moderations-KI-System für eine deutsche Social-Media-Plattform.

DEINE AUFGABEN:
1. Erkennung von pornografischen Inhalten (Bilder/Videos)
2. Erkennung von Hassrede und Volksverhetzung (§130 StGB)
3. Erkennung von verfassungsfeindlichen Symbolen (§86a StGB)
4. Erkennung von Kindesmissbrauch-Material (sofortige Meldung!)
5. Erkennung von Gewaltverherrlichung

ANALYSE-KATEGORIEN:
- PORN: Explizite sexuelle Darstellungen, Nacktheit in sexuellem Kontext
- HATE: Rassismus, Antisemitismus, Volksverhetzung, NS-Symbole
- ILLEGAL: Kindesmissbrauch, Gewalt, Terror-Propaganda
- SAFE: Kein problematischer Inhalt erkannt

WICHTIG:
- Politische Diskussionen sind ERLAUBT (Meinungsfreiheit Art. 5 GG)
- Satire und Kunst sind ERLAUBT
- Nacktheit in künstlerischem/medizinischem Kontext ist ERLAUBT
- Bei Unsicherheit: Als REVIEW markieren für menschliche Überprüfung

ANTWORT-FORMAT (JSON):
{
  "category": "PORN|HATE|ILLEGAL|SAFE|REVIEW",
  "confidence": 0.0-1.0,
  "reason": "Kurze Begründung",
  "german_law_reference": "Falls relevant: §XY StGB"
}
```

### Video Analysis

```ruby
# Extract frames at 0%, 25%, 50%, 75%, 100% of video duration
# Analyze each frame separately
# If ANY frame is flagged → content flagged
```

## 4. Registration Flow

### Requirements

1. **Invite-Only**: Must have valid invite code (3 uses max per user)
2. **Age Verification**: Checkbox "I am 18 years or older"
3. **Terms Acceptance**: Must read and accept:
   - Terms of Service
   - Privacy Policy (DSGVO compliant)
   - Community Guidelines
4. **Email Verification**: Standard Mastodon flow

### Legal Disclaimers (German Law)

```markdown
## Nutzungsbedingungen

### §1 Geltungsbereich
Diese Plattform richtet sich ausschließlich an Personen ab 18 Jahren.

### §2 Verbotene Inhalte
Folgende Inhalte sind strikt untersagt:
- Pornografische Darstellungen jeglicher Art
- Kindesmissbrauchsmaterial (§184b StGB)
- Volksverhetzung und Hassrede (§130 StGB)
- Verfassungsfeindliche Symbole (§86a StGB)
- Gewaltverherrlichung (§131 StGB)

### §3 KI-basierte Moderation
Diese Plattform verwendet KI-Systeme zur automatischen Inhaltsprüfung.
Durch die Registrierung stimmen Sie dieser automatisierten Verarbeitung zu.

### §4 Haftungsausschluss
Der Betreiber haftet nicht für nutzergenerierte Inhalte.
Illegale Inhalte werden unverzüglich gelöscht und ggf. den Behörden gemeldet.
```

## 5. Admin Panel Features

### NSFW-Protect Dashboard

```
┌─────────────────────────────────────────────────────────┐
│  NSFW-PROTECT DASHBOARD                                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Status: [🟢 ACTIVE] [Toggle Off]                       │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │ Active Alarms   │  │ Frozen Accounts │              │
│  │      3/10       │  │       7         │              │
│  └─────────────────┘  └─────────────────┘              │
│                                                         │
│  Settings:                                              │
│  ☑ Porn Detection (all uploads)                        │
│  ☑ Hate Speech Detection (reports)                     │
│  ☑ Auto-delete violations                              │
│  ☐ Instance freeze at 10 alarms                        │
│                                                         │
│  Admin Alert Email: [admin@example.com      ]          │
│  Ollama Endpoint:   [http://localhost:11434 ]          │
│  Ollama Model:      [llava                  ]          │
│                                                         │
│  [Save Settings]                                        │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Recent Alarms                                          │
│  ────────────────────────────────────────────────────── │
│  🔴 @user1 - PORN - 0.95 confidence - [View] [Dismiss] │
│  🟡 @user2 - HATE - 0.72 confidence - [View] [Dismiss] │
│  🔴 @user3 - PORN - 0.98 confidence - [View] [Dismiss] │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 6. API Endpoints

### Errordon NSFW-Protect API

```
GET  /api/v1/errordon/nsfw_protect/status
     → Current system status and stats

POST /api/v1/errordon/nsfw_protect/check
     → Manual content check (admin only)

GET  /api/v1/errordon/nsfw_protect/alarms
     → List active alarms (admin only)

POST /api/v1/errordon/nsfw_protect/alarms/:id/resolve
     → Resolve alarm (admin only)

GET  /api/v1/errordon/nsfw_protect/config
     → Get config (admin only)

PUT  /api/v1/errordon/nsfw_protect/config
     → Update config (admin only)
```

## 7. Environment Variables

```bash
# NSFW-Protect Configuration
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://localhost:11434
ERRORDON_NSFW_OLLAMA_MODEL=llava
ERRORDON_NSFW_ADMIN_EMAIL=admin@example.com
ERRORDON_NSFW_INSTANCE_ALARM_THRESHOLD=10

# Registration
ERRORDON_INVITE_ONLY=true
ERRORDON_INVITE_MAX_USES=3
ERRORDON_REQUIRE_AGE_18=true
```

## 8. Server Rules Template

```
Welcome to [Instance Name] - A Safe Space for Adults

🌟 BE KIND: Treat everyone with respect. Disagreement is fine, hatred is not.

🔞 ADULTS ONLY: This platform is for users 18+. We cannot verify IDs, 
   so we block ALL pornographic content to protect potential minors.

🚫 ZERO TOLERANCE: Pornography, hate speech, and illegal content result 
   in immediate account restrictions. Our AI monitors all uploads.

💬 FREE SPEECH: Political discussions and debates are welcome. 
   We protect your right to express opinions within legal bounds.

🤖 AI MODERATION: Content is automatically scanned. False positives 
   can be appealed. Human moderators review edge cases.

🚨 REPORT: If you see content that harms minors or violates laws, 
   please use the report button. You're helping keep everyone safe.

⚖️ GERMAN LAW: This instance operates under German law. 
   Violations of §130, §184b, §86a StGB are reported to authorities.
```

## 9. Implementation Priority

1. **Phase 1**: Database migrations + Account freeze logic
2. **Phase 2**: Ollama service integration
3. **Phase 3**: Upload interceptor (porn check on ALL uploads)
4. **Phase 4**: Report enhancement (AI check on reports)
5. **Phase 5**: Admin panel UI
6. **Phase 6**: Registration flow (invite-only, 18+, terms)
7. **Phase 7**: Legal documents (ToS, Privacy, Rules)
8. **Phase 8**: Email notifications + Instance freeze logic
