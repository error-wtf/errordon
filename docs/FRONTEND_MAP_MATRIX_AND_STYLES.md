# Frontend Map: Matrix Theme & Styles

**Date:** 2026-01-28
**Purpose:** Document frontend architecture, main.js role, and CSS integration

---

## 1. Build System Overview

Errordon uses **Vite** (not Webpacker) for frontend builds.

### Entry Points
```
app/javascript/
├── entrypoints/           # JS entry points (Vite discovers these)
│   ├── application.ts     # Main Mastodon SPA
│   ├── common.ts          # Shared code + Matrix theme init
│   ├── admin.tsx          # Admin panel
│   ├── public.tsx         # Public pages
│   ├── embed.tsx          # Embed widgets
│   └── ...
└── styles/
    └── entrypoints/       # CSS entry points
        ├── inert.scss
        └── mailer.scss
```

### Build Output
- **Dev:** `public/packs-dev/`
- **Prod:** `public/packs/`
- **Manifest:** `.vite/manifest.json`

---

## 2. What is "main.js"?

### Clarification: TWO Different `main.js` Files

#### A) Matrix Terminal `main.js` (in `matrix-full/`)
**Location:** `E:\clone\matrix-full\main.js`

This is a **standalone** JavaScript file for the Matrix terminal landing page:
- Pure vanilla JS, no React
- Handles: Matrix rain animation, terminal commands, login/logout
- **Does NOT include Mastodon CSS**
- Used as reference; errordon's `public/matrix/index.html` has this code **inlined**

```javascript
// matrix-full/main.js - standalone, no Mastodon deps
const matrixCanvas = document.getElementById('matrixCanvas');
// ... Matrix rain, terminal commands, etc.
```

#### B) Mastodon's `main` Entry (no file literally named main.js)
**Location:** `app/javascript/mastodon/main.tsx`

This is the **React app bootstrap**:
- Loaded via `entrypoints/application.ts`
- Initializes React, Redux, routing
- **Includes Mastodon CSS** via Vite imports

```typescript
// entrypoints/application.ts
import { loadLocale } from 'mastodon/locales';
import main from 'mastodon/main';  // <-- This is the React app
import { loadPolyfills } from 'mastodon/polyfills';

loadPolyfills()
  .then(loadLocale)
  .then(main)  // <-- Boots React app
```

---

## 3. CSS Integration

### How CSS is Loaded

1. **Vite discovers SCSS entrypoints** in `styles/entrypoints/`
2. **Components import CSS modules** directly (e.g., `import styles from './style.module.scss'`)
3. **Global styles** are in `app/javascript/styles/`

### Matrix Theme CSS

**File:** `app/javascript/styles/errordon_matrix.scss` (641 lines)

**How it works:**
1. Adds `theme-matrix` class to `<body>`
2. SCSS rules target `.theme-matrix` selector
3. Toggled via `Ctrl+Shift+M` or localStorage

**Key selectors:**
```scss
body.theme-matrix {
  background: $matrix-black;
  color: $matrix-text;
  
  .column, .drawer { background: $matrix-dark; }
  .status { border-color: rgba(0, 255, 0, 0.2); }
  // ... 600+ lines of Matrix styling
}
```

### Theme Controller

**File:** `app/javascript/mastodon/features/errordon/matrix_theme.ts`

```typescript
export const initMatrixTheme = (): void => {
  // Apply stored theme on page load
  const theme = getStoredTheme();
  setTheme(theme);

  // Keyboard shortcut: Ctrl+Shift+M
  document.addEventListener('keydown', (e) => {
    if (e.ctrlKey && e.shiftKey && e.key === 'M') {
      toggleMatrixTheme();
    }
  });
};
```

**Initialization chain:**
```
entrypoints/common.ts
  → import { initMatrixTheme } from 'mastodon/features/errordon/matrix_theme'
  → initMatrixTheme()  // Applies theme class to body
```

---

## 4. Matrix Terminal (public/matrix/)

### Files
```
public/matrix/
├── index.html          # Self-contained terminal (inline CSS+JS)
├── tetris.html         # Tetris game
├── tetris-script.js    # Tetris logic
├── tetris-style.css    # Tetris styles
└── talk_db_*.json      # Dialog databases for characters
```

### Key Point: NO External Dependencies

The `public/matrix/index.html` does NOT load:
- ❌ Mastodon CSS bundles
- ❌ Mastodon JS bundles
- ❌ External stylesheets
- ❌ External JS files (except dialog JSON)

Everything is **inline**:
```html
<style>
  /* ~75 lines of inline CSS */
  body { background: #000; color: #0f0; ... }
</style>

<script>
  // ~300 lines of inline JS
  // Matrix rain, terminal, commands
</script>
```

### Why Inline?
From the loop failure analysis (`E:\Fixing Errordon Docker Install.md`):
- External CSS/JS files caused **cache issues**
- Browsers cached old versions
- Multiple cache-busting attempts failed
- Solution: **inline everything** to eliminate caching problems

---

## 5. How to Tell if a Page Uses Mastodon CSS

### Check 1: HTML Structure
**Mastodon pages** have:
```html
<body class="app-body ...">
  <div id="mastodon" data-props="...">
```

**Matrix terminal** has:
```html
<body>
  <canvas id="matrixCanvas">
  <div id="loginScreen">
  <div id="terminal">
```

### Check 2: Asset Loading
**Mastodon pages** load Vite bundles:
```html
<link rel="stylesheet" href="/packs/application-abc123.css">
<script src="/packs/application-def456.js">
```

**Matrix terminal** loads nothing external:
```html
<!-- No link/script tags for bundles -->
```

### Check 3: React Root
**Mastodon pages** have a React mount point:
```javascript
const container = document.getElementById('mastodon');
createRoot(container).render(<App />);
```

**Matrix terminal** is vanilla DOM:
```javascript
document.getElementById('terminal').style.display = 'flex';
```

---

## 6. CSS Module Scoping

Vite generates scoped class names:
```scss
// Input: features/account/components/header.module.scss
.header { ... }

// Output: ._feat_account_header__header
```

Pattern: `_${parentDir}_${dir}__${className}`

---

## 7. Adding New Styles

### For Mastodon App
1. Create `*.module.scss` in component directory
2. Import in component: `import styles from './style.module.scss'`
3. Use: `className={styles.myClass}`

### For Global Styles
1. Add to `app/javascript/styles/`
2. Import in an entrypoint or component

### For Matrix Theme
1. Edit `app/javascript/styles/errordon_matrix.scss`
2. Use `body.theme-matrix` selector
3. Rebuild: `yarn build`

---

## 8. Frontend File Map

```
app/javascript/
├── entrypoints/                  # Vite entry points
├── mastodon/
│   ├── main.tsx                  # React app bootstrap
│   ├── features/
│   │   ├── account_timeline/     # Profile timeline
│   │   ├── errordon/             # Errordon-specific features
│   │   │   └── matrix_theme.ts   # Theme controller
│   │   └── ...
│   ├── components/
│   │   ├── media_gallery.jsx     # Image grid
│   │   ├── video.jsx             # Video player
│   │   ├── audio.jsx             # Audio player
│   │   └── ...
│   └── locales/                  # Translations
├── styles/
│   ├── entrypoints/              # CSS entry points
│   ├── errordon_matrix.scss      # Matrix theme (641 lines)
│   └── ...
└── errordon/
    └── matrix/
        └── index.js              # Matrix rain effect (optional)
```

---

## Summary

| Component | Uses Mastodon CSS? | Build System |
|-----------|-------------------|--------------|
| Main Mastodon App | ✅ Yes | Vite bundles |
| Admin Panel | ✅ Yes | Vite bundles |
| Public Pages | ✅ Yes | Vite bundles |
| Matrix Terminal (`/matrix/`) | ❌ No | Inline CSS/JS |
| Embeds | ✅ Yes | Vite bundles |

**Key Takeaway:** The Matrix terminal at `/matrix/index.html` is intentionally isolated from Mastodon's CSS/JS to avoid caching issues and maintain simplicity.
