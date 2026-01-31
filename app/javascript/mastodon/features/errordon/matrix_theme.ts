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

// Remove inline background from modal overlays and containers (CSS can't override inline styles reliably)
const fixModalOverlay = (element: Element): void => {
  const el = element as HTMLElement;
  
  // Fix overlay
  if (element.classList.contains('modal-root__overlay')) {
    el.style.backgroundColor = 'transparent';
    el.style.background = 'transparent';
  }
  
  // Fix container when it contains a media modal
  if (element.classList.contains('modal-root__container')) {
    const hasMediaModal = element.querySelector('.media-modal, .image-modal, .video-modal, .audio-modal');
    if (hasMediaModal) {
      el.style.backgroundColor = 'transparent';
      el.style.background = 'transparent';
    }
  }
  
  // Fix the modal-root itself
  if (element.classList.contains('modal-root')) {
    el.style.backgroundColor = 'transparent';
    el.style.background = 'transparent';
  }
};

const initModalOverlayFixer = (): void => {
  // Selectors for elements that need transparent backgrounds
  const selectors = '.modal-root__overlay, .modal-root__container, .modal-root';
  
  // Fix any existing elements
  document.querySelectorAll(selectors).forEach(fixModalOverlay);
  
  // Watch for new elements being added
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node instanceof Element) {
          // Check the node itself
          fixModalOverlay(node);
          // Check descendants
          node.querySelectorAll(selectors).forEach(fixModalOverlay);
        }
      });
      // Also check for attribute changes on existing elements
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
