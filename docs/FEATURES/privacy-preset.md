# Feature: Privacy Preset (Strict)

## Summary

Privacy-first default settings inspired by chaos.social principles.

## Principles

- Opt-in discovery, not opt-out
- Minimal data collection
- Clear user communication
- Conservative federation defaults

## Default Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Default visibility | unlisted | New posts not in public timelines |
| Discoverable | false | Profile not in directory |
| Indexable | false | Posts not searchable |
| Hide network | true | Followers/following hidden |
| Require follow | false | But encouraged |

## Admin Defaults

| Setting | Value | Description |
|---------|-------|-------------|
| Open registrations | false | Invite-only |
| Approval required | true | Manual approval |
| Email verification | true | Required |
| Authorized fetch | true | Signed fetches only |

## Telemetry

- No external analytics
- Minimal error reporting
- Log retention: 7 days

## Implementation

- `config/initializers/privacy_preset.rb`
- Admin UI toggle: "Apply strict preset"
- Documentation for all settings

## Files to Create

- `config/initializers/privacy_preset.rb`
- `docs/PRIVACY_SETTINGS.md`
