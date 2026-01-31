// Errordon Matrix Theme Controller
// Applies and manages the Matrix cyberpunk theme

const THEME_KEY = 'errordon_matrix_theme';
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
  // Default to Matrix theme for Errordon
  // Users can switch to default/light via Ctrl+Shift+M
  return 'matrix';
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

// Remove inline background from modal overlays (CSS can't override inline styles reliably)
const fixModalOverlay = (element: Element): void => {
  if (element.classList.contains('modal-root__overlay')) {
    (element as HTMLElement).style.backgroundColor = 'transparent';
    (element as HTMLElement).style.background = 'transparent';
  }
};

const initModalOverlayFixer = (): void => {
  // Fix any existing overlays
  document.querySelectorAll('.modal-root__overlay').forEach(fixModalOverlay);
  
  // Watch for new overlays being added
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node instanceof Element) {
          // Check the node itself
          fixModalOverlay(node);
          // Check descendants
          node.querySelectorAll('.modal-root__overlay').forEach(fixModalOverlay);
        }
      });
      // Also check for attribute changes on existing overlays
      if (mutation.type === 'attributes' && mutation.target instanceof Element) {
        fixModalOverlay(mutation.target);
      }
    });
  });
  
  observer.observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['style', 'class']
  });
};

export const initMatrixTheme = (): void => {
  // Apply stored theme on page load
  const theme = getStoredTheme();
  setTheme(theme);

  // Initialize modal overlay fixer for Matrix theme
  if (theme === 'matrix') {
    initModalOverlayFixer();
  }

  // Add keyboard shortcut: Ctrl+Shift+M to toggle Matrix theme
  document.addEventListener('keydown', (e: KeyboardEvent) => {
    if (e.ctrlKey && e.shiftKey && e.key === 'M') {
      e.preventDefault();
      toggleMatrixTheme();
    }
  });
  
  // Re-init overlay fixer when theme changes
  window.addEventListener('errordon:theme-change', ((e: CustomEvent) => {
    if (e.detail.theme === 'matrix') {
      initModalOverlayFixer();
    }
  }) as EventListener);
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
