# Privacy Preset: Strict Mode

**Last Updated:** 2026-01-28
**Inspired by:** [chaos.social](https://chaos.social) privacy principles

---

## Overview

Errordon implements a **privacy-first** approach by default. The "strict" preset applies conservative defaults that protect user privacy out of the box, while still allowing federation and social interaction.

---

## Quick Configuration

```bash
# Enable strict privacy (default)
ERRORDON_PRIVACY_PRESET=strict

# Or use standard Mastodon defaults
ERRORDON_PRIVACY_PRESET=standard
```

---

## Strict Mode Defaults

| Setting | Strict Value | Mastodon Default | Purpose |
|---------|--------------|------------------|---------|
| Post visibility | `unlisted` | `public` | Posts don't appear in public timelines |
| Discoverable | `false` | `true` | Profile not listed in directory |
| Indexable | `false` | `true` | Posts not searchable by external search engines |
| Hide network | `true` | `false` | Follower/following counts hidden |

---

## Environment Variables

### Core Preset

```bash
# Master switch - 'strict' or 'standard'
ERRORDON_PRIVACY_PRESET=strict
```

### Individual Overrides

```bash
# Post visibility: public, unlisted, private
ERRORDON_DEFAULT_VISIBILITY=unlisted

# Profile in directory
ERRORDON_DEFAULT_DISCOVERABLE=false

# Posts searchable by external engines
ERRORDON_DEFAULT_INDEXABLE=false

# Hide follower/following counts
ERRORDON_DEFAULT_HIDE_NETWORK=true
```

---

## Privacy Philosophy

### 1. Default to Unlisted

Posts with `unlisted` visibility:
- ✅ Visible on your profile
- ✅ Visible to followers in home timeline
- ✅ Can be boosted (but boost is unlisted too)
- ❌ Do NOT appear in Local/Federated timelines
- ❌ Do NOT appear in hashtag searches (public timelines)

**Why:** Users should opt-in to public visibility, not opt-out.

### 2. Non-Discoverable by Default

- Profile not listed in instance directory
- Profile not suggested to other users
- Profile not included in "Who to follow"

**Why:** Users should choose to be discovered.

### 3. Non-Indexable by Default

- Posts include `noindex` meta tag
- Search engines cannot index posts
- External search services (like search.joinmastodon.org) cannot index

**Why:** Social media posts shouldn't be permanently archived by search engines.

### 4. Hidden Network

- Follower count hidden from profile
- Following count hidden from profile
- Other users cannot see who you follow

**Why:** Prevents social graph analysis and reduces pressure of "popularity metrics".

---

## Federation Compatibility

All strict mode settings are **fully federation compatible**:

| Feature | Impact on Federation |
|---------|---------------------|
| Unlisted posts | ✅ Still federate to followers |
| Non-discoverable | ✅ Profile still accessible via URL |
| Non-indexable | ✅ Only affects search engines |
| Hidden network | ✅ Followers/following still work |

**Important:** These settings affect:
- New users at registration
- How your instance appears to others
- What external services can access

They do **NOT** prevent:
- Following/followers functionality
- Boosting and interactions
- ActivityPub federation

---

## Configuration Examples

### Maximum Privacy

```bash
ERRORDON_PRIVACY_PRESET=strict
ERRORDON_DEFAULT_VISIBILITY=private
ERRORDON_DEFAULT_DISCOVERABLE=false
ERRORDON_DEFAULT_INDEXABLE=false
ERRORDON_DEFAULT_HIDE_NETWORK=true
```

### Balanced (Unlisted but discoverable)

```bash
ERRORDON_PRIVACY_PRESET=strict
ERRORDON_DEFAULT_VISIBILITY=unlisted
ERRORDON_DEFAULT_DISCOVERABLE=true
ERRORDON_DEFAULT_INDEXABLE=false
ERRORDON_DEFAULT_HIDE_NETWORK=false
```

### Public Instance

```bash
ERRORDON_PRIVACY_PRESET=standard
```

---

## Technical Implementation

### Initializer

**File:** `config/initializers/errordon_privacy_preset.rb`

The initializer:
1. Checks `ERRORDON_PRIVACY_PRESET` environment variable
2. If "strict", patches the `User` model with `after_initialize` callback
3. Applies defaults to new users at registration time
4. Logs configuration to Rails logger

### Where Settings Apply

| Setting | Model | Column |
|---------|-------|--------|
| visibility | User | `settings['default_privacy']` |
| discoverable | Account | `discoverable` |
| indexable | Account | `indexable` |
| hide_network | Account | `hide_collections` |

### Logging

Check Rails logs for confirmation:
```
[Errordon] Privacy preset: STRICT mode enabled
[Errordon] Default visibility: unlisted
[Errordon] Default discoverable: false
[Errordon] Default indexable: false
[Errordon] Default hide_network: true
```

---

## GDPR/DSGVO Compliance

Strict mode helps with GDPR compliance by:

1. **Data Minimization** - Less public exposure of user data
2. **Privacy by Default** - Conservative settings without user action
3. **Right to be Forgotten** - Non-indexed content easier to remove

Additional GDPR features in Errordon:
- Scheduled data cleanup (`GdprCleanupWorker`)
- Export functionality (`/api/v1/errordon/gdpr/export`)
- Delete functionality (`/api/v1/errordon/gdpr/delete`)

See `docs/GDPR_COMPLIANCE.md` for full details.

---

## Chaos.social Principles

This implementation is inspired by [chaos.social](https://chaos.social), which:

1. Defaults to unlisted posting
2. Encourages thoughtful content sharing
3. Minimizes algorithmic amplification
4. Prioritizes consent over viral reach

---

## Changing Existing Users

The privacy preset only affects **new users** at registration. To update existing users:

```ruby
# Rails console
User.find_each do |user|
  user.settings['default_privacy'] = 'unlisted'
  user.save
  
  user.account.update(
    discoverable: false,
    indexable: false,
    hide_collections: true
  )
end
```

**Warning:** Only run this if you have user consent or clear terms of service.
