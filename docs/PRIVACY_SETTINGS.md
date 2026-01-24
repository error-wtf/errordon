# Errordon Privacy Settings

## Overview

Errordon implements a **strict privacy-first** approach by default, inspired by chaos.social principles.

## Quick Start

Add to your `.env` file:

```bash
# Enable strict privacy (default)
ERRORDON_PRIVACY_PRESET=strict

# Or use standard Mastodon defaults
ERRORDON_PRIVACY_PRESET=standard
```

## Default Settings (Strict Mode)

| Setting | Default | ENV Override |
|---------|---------|--------------|
| Post visibility | `unlisted` | `ERRORDON_DEFAULT_VISIBILITY` |
| Discoverable | `false` | `ERRORDON_DEFAULT_DISCOVERABLE` |
| Indexable | `false` | `ERRORDON_DEFAULT_INDEXABLE` |
| Hide network | `true` | `ERRORDON_DEFAULT_HIDE_NETWORK` |

## ENV Variables

### `ERRORDON_PRIVACY_PRESET`

- `strict` (default): Privacy-first defaults
- `standard`: Standard Mastodon defaults

### `ERRORDON_DEFAULT_VISIBILITY`

Default visibility for new posts:
- `public`: Visible in public timelines
- `unlisted` (default in strict): Not in public timelines
- `private`: Followers only

### `ERRORDON_DEFAULT_DISCOVERABLE`

- `false` (default in strict): Profile not listed in directory
- `true`: Profile listed in directory

### `ERRORDON_DEFAULT_INDEXABLE`

- `false` (default in strict): Posts not searchable
- `true`: Posts searchable

### `ERRORDON_DEFAULT_HIDE_NETWORK`

- `true` (default in strict): Hide followers/following counts
- `false`: Show network publicly

## Example Configurations

### Maximum Privacy (Strict)

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

### Standard Mastodon

```bash
ERRORDON_PRIVACY_PRESET=standard
```

## Technical Details

The privacy preset is implemented via:
- `config/initializers/errordon_privacy_preset.rb`

Settings are applied:
1. On new user registration
2. Via `after_initialize` callback on User model
3. Propagated to associated Account model

## Logs

Check Rails logs for confirmation:
```
[Errordon] Privacy preset: STRICT mode enabled
[Errordon] Default visibility: unlisted
[Errordon] Default discoverable: false
```
