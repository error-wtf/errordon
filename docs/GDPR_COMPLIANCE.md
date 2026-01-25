# GDPR Compliance Documentation

## Overview

Errordon implements comprehensive GDPR (DSGVO) compliance with automatic data retention management, IP anonymization, and transparent data handling.

## Data Retention Periods

| Data Type | Retention | Legal Basis |
|-----------|-----------|-------------|
| IP Addresses (general) | 7 days | Art. 6(1)(f) - Legitimate interest |
| IP Addresses (CSAM) | 5 years | §184b StGB - Legal obligation |
| Strike Records (general) | 1 year | Art. 6(1)(c) - Legal obligation |
| Strike Records (CSAM) | 5 years | §184b StGB - Evidence preservation |
| AI Analysis Snapshots (SAFE) | 14 days | Art. 5(1)(e) - Storage limitation |
| AI Analysis Snapshots (Violation) | 1 year | Art. 6(1)(c) - Legal obligation |
| Audit Logs | 2 years | NetzDG compliance |

## Environment Variables

```bash
# Data retention periods (in days)
ERRORDON_GDPR_IP_RETENTION_DAYS=7
ERRORDON_GDPR_STRIKE_RETENTION_DAYS=365
ERRORDON_GDPR_AUDIT_RETENTION_DAYS=730
ERRORDON_GDPR_SNAPSHOT_RETENTION_DAYS=14
```

## Automatic Cleanup Jobs

### GDPR Cleanup Worker (4:00 AM daily)

Performs:
1. **IP Anonymization** - Replaces IPs with NULL after retention period
2. **Strike Deletion** - Removes resolved strikes older than retention period
3. **Session Cleanup** - Removes expired session data

### AI Snapshot Cleanup Worker (4:30 AM daily)

Performs:
1. **SAFE Snapshot Deletion** - Deletes analysis snapshots for content marked SAFE after 14 days
2. **Violation snapshots** - Kept for 1 year for potential legal proceedings

## Rake Tasks

```bash
# Show GDPR compliance status
rake errordon:gdpr:status

# Run cleanup manually
rake errordon:gdpr:cleanup

# Show retention policy
rake errordon:gdpr:policy

# Generate compliance report
rake errordon:gdpr:report

# Show AI snapshot statistics
rake errordon:gdpr:snapshot_stats

# Cleanup expired snapshots
rake errordon:gdpr:cleanup_snapshots
```

## Data Subject Rights

### Right to Access (Art. 15)

Users can request their data via:
- Settings → Export Data

### Right to Erasure (Art. 17)

Users can delete their account via:
- Settings → Delete Account

Note: Strike data may be retained for legal compliance (Art. 17(3)(b)).

### Right to Data Portability (Art. 20)

Users can export their data in machine-readable format (JSON).

## IP Address Handling

### When IPs are Logged

| Event | IP Logged | Retention |
|-------|-----------|-----------|
| Registration | Yes | 7 days |
| Login | Yes | 7 days |
| Content Violation | Yes | 7 days (1 year for serious) |
| CSAM Detection | Yes | 5 years (§184b StGB) |

### Anonymization Process

```ruby
# IPs are replaced with NULL, not hashed
strike.update!(ip_address: nil)
```

## Audit Trail

All GDPR-relevant actions are logged:

```
log/gdpr_audit/
├── ip_anonymization.log
├── data_deletion.log
└── access_requests.log
```

## Legal Basis Summary

| Processing Activity | Legal Basis (GDPR) |
|--------------------|-------------------|
| Content moderation | Art. 6(1)(f) - Legitimate interest |
| Strike system | Art. 6(1)(c) - Legal obligation (NetzDG) |
| IP logging | Art. 6(1)(f) - Security |
| CSAM reporting | Art. 6(1)(c) - Legal obligation (§184b StGB) |
| Email alerts | Art. 6(1)(f) - Legitimate interest |

## Service Files

| File | Purpose |
|------|---------|
| `app/services/errordon/gdpr_compliance_service.rb` | Main GDPR logic |
| `app/workers/errordon/gdpr_cleanup_worker.rb` | Scheduled cleanup |
| `app/workers/errordon/snapshot_cleanup_worker.rb` | AI snapshot cleanup |
| `lib/tasks/errordon_nsfw_protect.rake` | Rake tasks |

## Evidence Package for Law Enforcement

When violations require reporting to authorities, Errordon generates:

1. **JSON Report** - Machine-readable evidence
2. **Text Report** - Human-readable summary
3. **SHA256 Hashes** - For integrity verification
4. **Media Files** - Original content (CSAM cases only)

File naming: `{username}_{YYYY-MM-DD}_{HH-MM-SS}_strike{ID}_evidence.{json|txt}`

## Contact

For GDPR inquiries, contact the instance administrator via the configured admin email.
