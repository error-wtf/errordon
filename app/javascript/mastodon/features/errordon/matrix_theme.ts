// Errordon Matrix Theme Controller
// Applies and manages the Matrix cyberpunk theme

const THEME_KEY = 'errordon_theme';
const MATRIX_CLASS = 'theme-matrix';

export type ThemeName = 'matrix' | 'default' | 'light';

interface ThemeConfig {
  name: string;
  bodyClass: string;
  description: string;
}

const themes: Record<ThemeName, ThemeConfig> = {
  matrix: {
    name: 'Matrix',
    bodyClass: 'theme-matrix',
    description: 'Cyberpunk hacker style',
  },
  default: {
    name: 'Default',
    bodyClass: '',
    description: 'Standard Mastodon dark theme',
  },
  light: {
    name: 'Light',
    bodyClass: 'theme-mastodon-light',
    description: 'Standard Mastodon light mode',
  },
};

export const getStoredTheme = (): ThemeName => {
  const stored = localStorage.getItem(THEME_KEY);
  if (stored && stored in themes) {
    return stored as ThemeName;
  }
  // Default to standard Mastodon theme for Fediverse compatibility
  // Users can opt-in to Matrix theme via Ctrl+Shift+M or settings
  return 'default';
};

export const setTheme = (themeName: ThemeName): void => {
  const theme = themes[themeName];
  if (!theme) return;

  // Remove all theme classes
  Object.values(themes).forEach((t) => {
    if (t.bodyClass) {
      document.body.classList.remove(t.bodyClass);
    }
  });

  // Apply new theme class
  if (theme.bodyClass) {
    document.body.classList.add(theme.bodyClass);
  }

  // Store preference
  localStorage.setItem(THEME_KEY, themeName);

  // Dispatch event for other components
  window.dispatchEvent(
    new CustomEvent('errordon:theme-change', { detail: { theme: themeName } })
  );
};

export const toggleMatrixTheme = (): void => {
  const current = getStoredTheme();
  const next: ThemeName = current === 'matrix' ? 'default' : 'matrix';
  setTheme(next);
};

export const initMatrixTheme = (): void => {
  // Apply stored theme on page load
  const theme = getStoredTheme();
  setTheme(theme);

  // Add keyboard shortcut: Ctrl+Shift+M to toggle Matrix theme
  document.addEventListener('keydown', (e: KeyboardEvent) => {
    if (e.ctrlKey && e.shiftKey && e.key === 'M') {
      e.preventDefault();
      toggleMatrixTheme();
    }
  });
};

// Auto-initialize when DOM is ready
if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initMatrixTheme);
  } else {
    initMatrixTheme();
  }
}

export default {
  getStoredTheme,
  setTheme,
  toggleMatrixTheme,
  initMatrixTheme,
  themes,
};
