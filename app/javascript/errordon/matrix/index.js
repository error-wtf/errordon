// Errordon Matrix Theme Integration
// Matrix rain background + Enter Matrix splash screen
// With accessibility support (prefers-reduced-motion) and performance optimizations

// =============================================================================
// CONFIGURATION
// =============================================================================
const MATRIX_CONFIG = {
  // Intensity presets: low (battery saver), medium (default), high (full effect)
  intensity: {
    low:    { fps: 15, fadeOpacity: 0.03, speed: 0.2 },
    medium: { fps: 20, fadeOpacity: 0.05, speed: 0.35 },
    high:   { fps: 30, fadeOpacity: 0.07, speed: 0.5 }
  },
  // Color variants (admin-configurable during install)
  colors: {
    green:  { primary: '#00ff00', dark: '#00cc00', rgb: '0, 255, 0' },
    red:    { primary: '#ff0000', dark: '#cc0000', rgb: '255, 0, 0' },
    blue:   { primary: '#00bfff', dark: '#0099cc', rgb: '0, 191, 255' },
    purple: { primary: '#bf00ff', dark: '#9900cc', rgb: '191, 0, 255' }
  },
  // Character set (Japanese katakana + alphanumeric)
  chars: 'アァカサタナハマヤャラワガザダバパイィキシチニヒミリギジヂビピウゥクスツヌフムユュルグズヅブプエェケセテネヘメレゲゼデベペオォコソトノホモヨョロゴゾドボポヴッン0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',
  // Default font size (pixels)
  fontSize: 14,
  // Mobile font size (larger = fewer columns = better performance)
  mobileFontSize: 18,
  // Mobile breakpoint
  mobileBreakpoint: 768
};

// =============================================================================
// COLOR MANAGEMENT
// =============================================================================

/**
 * Get the server-configured default color (from meta tag or ENV)
 */
function getServerDefaultColor() {
  const meta = document.querySelector('meta[name="errordon-matrix-color"]');
  return meta?.content || 'green';
}

/**
 * Get stored color preference or server default
 */
function getColorPreference() {
  const stored = localStorage.getItem('errordon_matrix_color');
  if (stored && MATRIX_CONFIG.colors[stored]) {
    return stored;
  }
  return getServerDefaultColor();
}

/**
 * Apply color variant to document
 */
function applyMatrixColor(color) {
  if (!MATRIX_CONFIG.colors[color]) {
    color = 'green';
  }
  
  // Remove all color classes
  document.body.classList.remove(
    'matrix-color-green',
    'matrix-color-red',
    'matrix-color-blue',
    'matrix-color-purple'
  );
  
  // Add the selected color class
  document.body.classList.add(`matrix-color-${color}`);
  
  // Store preference
  localStorage.setItem('errordon_matrix_color', color);
  
  // Dispatch event for other components
  window.dispatchEvent(new CustomEvent('errordon:color-change', { 
    detail: { color } 
  }));
  
  console.log(`[Errordon] Matrix color set to: ${color}`);
}

/**
 * Get current color config object
 */
function getCurrentColorConfig() {
  const color = getColorPreference();
  return MATRIX_CONFIG.colors[color] || MATRIX_CONFIG.colors.green;
}

/**
 * Cycle through color variants
 */
function cycleColor() {
  const colors = Object.keys(MATRIX_CONFIG.colors);
  const current = getColorPreference();
  const currentIndex = colors.indexOf(current);
  const nextIndex = (currentIndex + 1) % colors.length;
  const nextColor = colors[nextIndex];
  
  applyMatrixColor(nextColor);
  
  // Update rain color if active
  if (window.matrixRain) {
    window.matrixRain.setColor(nextColor);
  }
  
  return nextColor;
}

// =============================================================================
// ACCESSIBILITY HELPERS
// =============================================================================

/**
 * Check if user prefers reduced motion
 */
function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/**
 * Check if device is low-end (for performance scaling)
 */
function isLowEndDevice() {
  const cores = navigator.hardwareConcurrency || 4;
  const memory = navigator.deviceMemory || 4;
  return cores <= 2 || memory <= 2;
}

/**
 * Get stored intensity preference or auto-detect
 */
function getIntensityPreference() {
  const stored = localStorage.getItem('errordon_matrix_intensity');
  if (stored && MATRIX_CONFIG.intensity[stored]) {
    return stored;
  }
  // Auto-detect based on device capability
  if (isLowEndDevice()) {
    return 'low';
  }
  return 'medium';
}

// =============================================================================
// MATRIX RAIN EFFECT
// =============================================================================

class MatrixRain {
  constructor(options = {}) {
    this.canvas = null;
    this.ctx = null;
    this.columns = 0;
    this.drops = [];
    this.active = false;
    this.animationId = null;
    this.lastFrameTime = 0;
    this.paused = false;
    
    // Configuration
    this.intensity = options.intensity || getIntensityPreference();
    this.config = MATRIX_CONFIG.intensity[this.intensity];
    this.frameInterval = 1000 / this.config.fps;
    this.chars = MATRIX_CONFIG.chars;
    this.fontSize = window.innerWidth < MATRIX_CONFIG.mobileBreakpoint 
      ? MATRIX_CONFIG.mobileFontSize 
      : MATRIX_CONFIG.fontSize;
    
    // Color configuration
    this.colorName = options.color || getColorPreference();
    this.colorConfig = MATRIX_CONFIG.colors[this.colorName] || MATRIX_CONFIG.colors.green;
    
    // Resize handler
    this.handleResize = this.handleResize.bind(this);
    this.draw = this.draw.bind(this);
    
    // Visibility change handler (pause when tab not visible)
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this);
  }

  init() {
    // ACCESSIBILITY: Skip animation if user prefers reduced motion
    if (prefersReducedMotion()) {
      console.log('[Errordon] Matrix rain disabled (prefers-reduced-motion)');
      document.body.classList.add('matrix-static-background');
      return false;
    }

    // Only init if theme-matrix is active
    if (!document.body.classList.contains('theme-matrix')) {
      return false;
    }

    // Create canvas
    this.canvas = document.createElement('canvas');
    this.canvas.id = 'matrix-rain-canvas';
    this.canvas.className = 'matrix-rain-canvas';
    this.canvas.setAttribute('aria-hidden', 'true'); // Screen reader skip
    document.body.prepend(this.canvas);

    this.ctx = this.canvas.getContext('2d');
    this.resize();
    
    // Event listeners
    window.addEventListener('resize', this.handleResize, { passive: true });
    // Pause only when tab is not visible (saves battery/CPU)
    document.addEventListener('visibilitychange', this.handleVisibilityChange);
    
    // Listen for reduced motion changes
    window.matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change', (e) => {
      if (e.matches) {
        this.stop();
        this.canvas?.remove();
        document.body.classList.add('matrix-static-background');
      }
    });
    
    this.start();
    console.log(`[Errordon] Matrix rain initialized (intensity: ${this.intensity})`);
    return true;
  }

  handleResize() {
    if (!this.canvas) return;
    
    // Recalculate font size for mobile
    this.fontSize = window.innerWidth < MATRIX_CONFIG.mobileBreakpoint 
      ? MATRIX_CONFIG.mobileFontSize 
      : MATRIX_CONFIG.fontSize;
    
    this.resize();
  }

  handleVisibilityChange() {
    // Pause when tab is hidden (saves battery/CPU)
    if (document.hidden) {
      this.pause();
    } else {
      this.resume();
    }
  }

  resize() {
    if (!this.canvas) return;
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.columns = Math.floor(this.canvas.width / this.fontSize);
    this.drops = Array.from({ length: this.columns }, () => 
      Math.random() * this.canvas.height / this.fontSize
    );
  }

  draw(timestamp) {
    if (!this.active || this.paused || !this.ctx) {
      if (this.active && !this.paused) {
        this.animationId = requestAnimationFrame(this.draw);
      }
      return;
    }

    // Frame rate limiting
    const elapsed = timestamp - this.lastFrameTime;
    if (elapsed < this.frameInterval) {
      this.animationId = requestAnimationFrame(this.draw);
      return;
    }
    this.lastFrameTime = timestamp - (elapsed % this.frameInterval);

    // Draw fade effect (creates trail)
    this.ctx.fillStyle = `rgba(0, 0, 0, ${this.config.fadeOpacity})`;
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    // Draw characters
    this.ctx.font = `${this.fontSize}px monospace`;

    for (let i = 0; i < this.columns; i++) {
      const char = this.chars.charAt(Math.floor(Math.random() * this.chars.length));
      const x = i * this.fontSize;
      const y = this.drops[i] * this.fontSize;

      // Occasional bright character (lead character effect)
      // Use configured color instead of hardcoded green
      this.ctx.fillStyle = Math.random() > 0.98 ? '#ffffff' : this.colorConfig.primary;
      this.ctx.fillText(char, x, y);

      // Reset drop when it reaches bottom
      if (y > this.canvas.height && Math.random() > 0.975) {
        this.drops[i] = 0;
      }
      this.drops[i] += this.config.speed + Math.random() * 0.2;
    }

    this.animationId = requestAnimationFrame(this.draw);
  }

  /**
   * Change the rain color dynamically
   */
  setColor(colorName) {
    if (!MATRIX_CONFIG.colors[colorName]) return;
    this.colorName = colorName;
    this.colorConfig = MATRIX_CONFIG.colors[colorName];
    localStorage.setItem('errordon_matrix_color', colorName);
    console.log(`[Errordon] Matrix rain color set to: ${colorName}`);
  }

  start() {
    if (this.active) return;
    this.active = true;
    this.paused = false;
    this.lastFrameTime = performance.now();
    this.animationId = requestAnimationFrame(this.draw);
  }

  stop() {
    this.active = false;
    this.paused = false;
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
    // Clear canvas
    if (this.ctx && this.canvas) {
      this.ctx.fillStyle = '#000';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    }
  }

  pause() {
    this.paused = true;
  }

  resume() {
    if (!this.active) return;
    this.paused = false;
    this.lastFrameTime = performance.now();
    if (!this.animationId) {
      this.animationId = requestAnimationFrame(this.draw);
    }
  }

  toggle() {
    if (this.active) {
      this.stop();
    } else {
      this.start();
    }
    return this.active;
  }

  setIntensity(level) {
    if (!MATRIX_CONFIG.intensity[level]) return;
    this.intensity = level;
    this.config = MATRIX_CONFIG.intensity[level];
    this.frameInterval = 1000 / this.config.fps;
    localStorage.setItem('errordon_matrix_intensity', level);
    console.log(`[Errordon] Matrix intensity set to: ${level}`);
  }

  destroy() {
    this.stop();
    window.removeEventListener('resize', this.handleResize);
    document.removeEventListener('visibilitychange', this.handleVisibilityChange);
    if (this.canvas) {
      this.canvas.remove();
      this.canvas = null;
    }
    this.ctx = null;
  }
}

// =============================================================================
// MATRIX SPLASH SCREEN
// =============================================================================

class MatrixSplash {
  constructor() {
    this.overlay = null;
    this.splashAnimationId = null;
    this.reducedMotion = prefersReducedMotion();
  }

  shouldShow() {
    // Show splash if not entered in this session and theme-matrix is active
    return document.body.classList.contains('theme-matrix') && 
           sessionStorage.getItem('matrix_entered') !== 'true';
  }

  init() {
    if (!this.shouldShow()) {
      return;
    }

    this.createOverlay();
    
    // Only animate if user allows motion
    if (!this.reducedMotion) {
      this.startRain();
    }
    
    this.bindEvents();
  }

  createOverlay() {
    this.overlay = document.createElement('div');
    this.overlay.id = 'matrix-splash-overlay';
    this.overlay.className = 'matrix-splash-overlay';
    this.overlay.setAttribute('role', 'dialog');
    this.overlay.setAttribute('aria-label', 'Welcome to Errordon');
    
    // Simplified version for reduced motion
    const canvasHtml = this.reducedMotion 
      ? '' 
      : '<canvas id="splash-matrix-canvas" class="splash-matrix-canvas" aria-hidden="true"></canvas>';
    
    this.overlay.innerHTML = `
      ${canvasHtml}
      <div class="matrix-splash-content">
        <h1 class="matrix-splash-title">ERRORDON</h1>
        <p class="matrix-splash-subtitle">The Matrix has you...</p>
        <div class="matrix-splash-terminal">
          <label for="matrix-splash-input" class="visually-hidden">Enter command</label>
          <span class="matrix-prompt" aria-hidden="true">root@matrix:~$</span>
          <input type="text" id="matrix-splash-input" class="matrix-splash-input" 
                 placeholder="type 'enter matrix' to continue..." autocomplete="off" autofocus>
        </div>
        <p class="matrix-splash-hint">Wake up, Neo...</p>
        <button type="button" class="matrix-splash-skip" aria-label="Skip intro">
          Press Enter or click to continue
        </button>
      </div>
    `;
    document.body.appendChild(this.overlay);
  }

  startRain() {
    const canvas = document.getElementById('splash-matrix-canvas');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const chars = 'アァカサタナハマヤャラワ01';
    const fontSize = 16;
    let columns = Math.floor(canvas.width / fontSize);
    let drops = Array.from({ length: columns }, () => Math.random() * canvas.height / fontSize);
    let lastTime = 0;
    const frameInterval = 1000 / 20; // 20 FPS for splash

    const draw = (timestamp) => {
      if (!this.overlay) return; // Stop if overlay removed
      
      const elapsed = timestamp - lastTime;
      if (elapsed >= frameInterval) {
        lastTime = timestamp - (elapsed % frameInterval);
        
        ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#0f0';
        ctx.font = `${fontSize}px monospace`;

        for (let i = 0; i < columns; i++) {
          const char = chars.charAt(Math.floor(Math.random() * chars.length));
          ctx.fillText(char, i * fontSize, drops[i] * fontSize);
          if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
            drops[i] = 0;
          }
          drops[i] += 0.5;
        }
      }
      
      this.splashAnimationId = requestAnimationFrame(draw);
    };

    this.splashAnimationId = requestAnimationFrame(draw);
  }

  bindEvents() {
    const input = document.getElementById('matrix-splash-input');
    const skipButton = this.overlay?.querySelector('.matrix-splash-skip');
    
    if (input) {
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          const cmd = input.value.trim().toLowerCase();
          if (cmd === 'enter matrix' || cmd === 'entermatrix' || cmd === 'enter' || cmd === '') {
            this.enterMatrix();
          } else {
            input.value = '';
            input.placeholder = 'Try: enter matrix (or just press Enter)';
          }
        }
      });

      setTimeout(() => input.focus(), 100);
    }
    
    // Skip button for accessibility
    if (skipButton) {
      skipButton.addEventListener('click', () => this.enterMatrix());
    }
    
    // Allow clicking anywhere to skip (accessibility)
    this.overlay?.addEventListener('click', (e) => {
      if (e.target === this.overlay) {
        this.enterMatrix();
      }
    });
  }

  enterMatrix() {
    sessionStorage.setItem('matrix_entered', 'true');

    if (this.splashAnimationId) {
      cancelAnimationFrame(this.splashAnimationId);
      this.splashAnimationId = null;
    }

    // Skip animation if reduced motion
    if (this.reducedMotion) {
      this.overlay?.remove();
      document.dispatchEvent(new CustomEvent('matrix:entered'));
      return;
    }

    // Glitch effect
    this.overlay?.classList.add('matrix-glitch');
    
    const content = this.overlay?.querySelector('.matrix-splash-content');
    if (content) {
      content.innerHTML = `
        <h1 class="matrix-splash-title matrix-glitch-text">WELCOME TO THE REAL WORLD</h1>
        <p class="matrix-splash-subtitle">Follow the white rabbit...</p>
      `;
    }

    // Fade out
    setTimeout(() => {
      this.overlay?.classList.add('matrix-fade-out');
      setTimeout(() => {
        this.overlay?.remove();
        document.dispatchEvent(new CustomEvent('matrix:entered'));
      }, 1000);
    }, 1500);
  }
}

// =============================================================================
// KEYBOARD SHORTCUTS
// =============================================================================

function initMatrixKeyboardShortcut() {
  document.addEventListener('keydown', (e) => {
    // Ctrl+Shift+M to toggle Matrix theme
    if (e.ctrlKey && e.shiftKey && e.key === 'M') {
      e.preventDefault();
      toggleMatrixTheme();
    }
    
    // Ctrl+Shift+I to cycle intensity (low → medium → high → low)
    if (e.ctrlKey && e.shiftKey && e.key === 'I') {
      e.preventDefault();
      cycleIntensity();
    }
    
    // Ctrl+Shift+C to cycle colors (green → red → blue → purple → green)
    if (e.ctrlKey && e.shiftKey && e.key === 'C') {
      e.preventDefault();
      cycleColor();
    }
  });
}

function toggleMatrixTheme() {
  document.body.classList.toggle('theme-matrix');
  
  const isMatrix = document.body.classList.contains('theme-matrix');
  localStorage.setItem('errordon_matrix_theme', isMatrix ? 'matrix' : 'default');
  
  if (isMatrix && !window.matrixRain) {
    window.matrixRain = new MatrixRain();
    window.matrixRain.init();
  } else if (!isMatrix && window.matrixRain) {
    window.matrixRain.destroy();
    window.matrixRain = null;
    document.body.classList.remove('matrix-static-background');
  }
  
  console.log(`[Errordon] Matrix theme ${isMatrix ? 'enabled' : 'disabled'}`);
  
  // Dispatch event for other components
  window.dispatchEvent(new CustomEvent('errordon:theme-change', { 
    detail: { theme: isMatrix ? 'matrix' : 'default' } 
  }));
}

function cycleIntensity() {
  if (!window.matrixRain) return;
  
  const levels = ['low', 'medium', 'high'];
  const currentIndex = levels.indexOf(window.matrixRain.intensity);
  const nextIndex = (currentIndex + 1) % levels.length;
  window.matrixRain.setIntensity(levels[nextIndex]);
}

// =============================================================================
// INITIALIZATION
// =============================================================================

function initErrordonMatrix() {
  // Matrix theme is ENABLED BY DEFAULT for Errordon
  // User can disable with Ctrl+Shift+M (saves preference to localStorage)
  const stored = localStorage.getItem('errordon_matrix_theme');
  
  // Only disable if user EXPLICITLY chose 'default' or 'false'
  // null/undefined/anything else = Matrix enabled (default behavior)
  const userDisabled = stored === 'default' || stored === 'false';
  const matrixEnabled = !userDisabled;
  
  if (matrixEnabled) {
    document.body.classList.add('theme-matrix');
    
    // Apply color variant
    const colorPref = getColorPreference();
    applyMatrixColor(colorPref);
  }

  // Initialize rain if theme active
  if (document.body.classList.contains('theme-matrix')) {
    window.matrixRain = new MatrixRain();
    const rainInitialized = window.matrixRain.init();
    
    // Show splash for new sessions (only if rain initialized, i.e., motion allowed)
    if (rainInitialized || !prefersReducedMotion()) {
      const splash = new MatrixSplash();
      splash.init();
    }
  }

  // Enable keyboard shortcuts
  initMatrixKeyboardShortcut();
  
  console.log('[Errordon] Matrix module loaded');
}

// =============================================================================
// PUBLIC API
// =============================================================================

// Expose for external use
window.MatrixRain = MatrixRain;
window.MatrixSplash = MatrixSplash;
window.initErrordonMatrix = initErrordonMatrix;
window.toggleMatrixTheme = toggleMatrixTheme;
window.cycleIntensity = cycleIntensity;
window.cycleColor = cycleColor;
window.applyMatrixColor = applyMatrixColor;

// Configuration access
window.MATRIX_CONFIG = MATRIX_CONFIG;

// Utility exports
window.matrixUtils = {
  prefersReducedMotion,
  isLowEndDevice,
  getIntensityPreference,
  getColorPreference,
  getCurrentColorConfig
};

// =============================================================================
// AUTO-INITIALIZATION
// =============================================================================

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initErrordonMatrix);
} else {
  initErrordonMatrix();
}
