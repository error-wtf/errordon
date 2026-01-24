// Errordon Matrix Theme Integration
// Matrix rain background + Enter Matrix splash screen

// Matrix Rain Effect
class MatrixRain {
  constructor() {
    this.canvas = null;
    this.ctx = null;
    this.columns = 0;
    this.drops = [];
    this.active = true;
    this.intervalId = null;
    this.chars = 'アァカサタナハマヤャラワガザダバパイィキシチニヒミリギジヂビピウゥクスツヌフムユュルグズヅブプエェケセテネヘメレゲゼデベペオォコソトノホモヨョロゴゾドボポヴッン0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    this.fontSize = 14;
  }

  init() {
    // Only init if theme-matrix is active
    if (!document.body.classList.contains('theme-matrix')) {
      return;
    }

    this.canvas = document.createElement('canvas');
    this.canvas.id = 'matrix-rain-canvas';
    this.canvas.className = 'matrix-rain-canvas';
    document.body.prepend(this.canvas);

    this.ctx = this.canvas.getContext('2d');
    this.resize();
    
    window.addEventListener('resize', () => this.resize());
    this.start();
    
    console.log('[Errordon] Matrix rain initialized');
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

  draw() {
    if (!this.active || !this.ctx) return;

    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    this.ctx.fillStyle = '#00ff00';
    this.ctx.font = `${this.fontSize}px monospace`;

    for (let i = 0; i < this.columns; i++) {
      const char = this.chars.charAt(Math.floor(Math.random() * this.chars.length));
      const x = i * this.fontSize;
      const y = this.drops[i] * this.fontSize;

      // Occasional bright character
      this.ctx.fillStyle = Math.random() > 0.98 ? '#ffffff' : '#00ff00';
      this.ctx.fillText(char, x, y);

      if (y > this.canvas.height && Math.random() > 0.975) {
        this.drops[i] = 0;
      }
      this.drops[i] += 0.3 + Math.random() * 0.4;
    }
  }

  start() {
    if (this.intervalId) return;
    this.active = true;
    this.intervalId = setInterval(() => this.draw(), 50);
  }

  stop() {
    this.active = false;
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
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
}

// Matrix Splash Screen
class MatrixSplash {
  constructor() {
    this.overlay = null;
    this.splashInterval = null;
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
    this.startRain();
    this.bindEvents();
  }

  createOverlay() {
    this.overlay = document.createElement('div');
    this.overlay.id = 'matrix-splash-overlay';
    this.overlay.className = 'matrix-splash-overlay';
    this.overlay.innerHTML = `
      <canvas id="splash-matrix-canvas" class="splash-matrix-canvas"></canvas>
      <div class="matrix-splash-content">
        <h1 class="matrix-splash-title">ERRORDON</h1>
        <p class="matrix-splash-subtitle">The Matrix has you...</p>
        <div class="matrix-splash-terminal">
          <span class="matrix-prompt">root@matrix:~$</span>
          <input type="text" id="matrix-splash-input" class="matrix-splash-input" 
                 placeholder="type 'enter matrix' to continue..." autocomplete="off" autofocus>
        </div>
        <p class="matrix-splash-hint">Wake up, Neo...</p>
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

    this.splashInterval = setInterval(() => {
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
    }, 50);
  }

  bindEvents() {
    const input = document.getElementById('matrix-splash-input');
    if (!input) return;

    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const cmd = input.value.trim().toLowerCase();
        if (cmd === 'enter matrix' || cmd === 'entermatrix' || cmd === 'enter') {
          this.enterMatrix();
        } else {
          input.value = '';
          input.placeholder = 'Try: enter matrix';
        }
      }
    });

    setTimeout(() => input.focus(), 100);
  }

  enterMatrix() {
    sessionStorage.setItem('matrix_entered', 'true');

    if (this.splashInterval) {
      clearInterval(this.splashInterval);
    }

    // Glitch effect
    this.overlay.classList.add('matrix-glitch');
    
    const content = this.overlay.querySelector('.matrix-splash-content');
    content.innerHTML = `
      <h1 class="matrix-splash-title matrix-glitch-text">WELCOME TO THE REAL WORLD</h1>
      <p class="matrix-splash-subtitle">Follow the white rabbit...</p>
    `;

    // Fade out
    setTimeout(() => {
      this.overlay.classList.add('matrix-fade-out');
      setTimeout(() => {
        this.overlay.remove();
        document.dispatchEvent(new CustomEvent('matrix:entered'));
      }, 1000);
    }, 1500);
  }
}

// Theme toggle keyboard shortcut
function initMatrixKeyboardShortcut() {
  document.addEventListener('keydown', (e) => {
    // Ctrl+Shift+M to toggle Matrix theme
    if (e.ctrlKey && e.shiftKey && e.key === 'M') {
      e.preventDefault();
      document.body.classList.toggle('theme-matrix');
      
      const isMatrix = document.body.classList.contains('theme-matrix');
      localStorage.setItem('errordon_matrix_theme', isMatrix ? 'true' : 'false');
      
      if (isMatrix && !window.matrixRain) {
        window.matrixRain = new MatrixRain();
        window.matrixRain.init();
      } else if (!isMatrix && window.matrixRain) {
        window.matrixRain.stop();
        const canvas = document.getElementById('matrix-rain-canvas');
        if (canvas) canvas.remove();
        window.matrixRain = null;
      }
      
      console.log(`[Errordon] Matrix theme ${isMatrix ? 'enabled' : 'disabled'}`);
    }
  });
}

// Initialize on load
function initErrordonMatrix() {
  // Check stored preference
  const matrixEnabled = localStorage.getItem('errordon_matrix_theme') === 'true';
  
  if (matrixEnabled) {
    document.body.classList.add('theme-matrix');
  }

  // Initialize rain if theme active
  if (document.body.classList.contains('theme-matrix')) {
    window.matrixRain = new MatrixRain();
    window.matrixRain.init();
    
    // Show splash for new sessions
    const splash = new MatrixSplash();
    splash.init();
  }

  // Enable keyboard shortcut
  initMatrixKeyboardShortcut();
}

// Export
window.MatrixRain = MatrixRain;
window.MatrixSplash = MatrixSplash;
window.initErrordonMatrix = initErrordonMatrix;

// Auto-init when DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initErrordonMatrix);
} else {
  initErrordonMatrix();
}
