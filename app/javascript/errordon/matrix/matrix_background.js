// Matrix Rain Background for Errordon
// Integrated from matrix-full project

class MatrixRain {
  constructor(canvasId = 'matrix-rain-canvas') {
    this.canvasId = canvasId;
    this.canvas = null;
    this.ctx = null;
    this.columns = 0;
    this.drops = [];
    this.active = true;
    this.intervalId = null;
    
    // Matrix characters (Japanese katakana + numbers + letters)
    this.chars = 'アァカサタナハマヤャラワガザダバパイィキシチニヒミリギジヂビピウゥクスツヌフムユュルグズヅブプエェケセテネヘメレゲゼデベペオォコソトノホモヨョロゴゾドボポヴッン0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    this.fontSize = 14;
    this.speed = 0.3;
  }

  init() {
    // Create canvas if not exists
    this.canvas = document.getElementById(this.canvasId);
    if (!this.canvas) {
      this.canvas = document.createElement('canvas');
      this.canvas.id = this.canvasId;
      this.canvas.className = 'matrix-rain-canvas';
      document.body.prepend(this.canvas);
    }

    this.ctx = this.canvas.getContext('2d');
    this.resize();
    
    // Handle window resize
    window.addEventListener('resize', () => this.resize());
    
    // Start animation
    this.start();
    
    console.log('[Matrix] Rain initialized');
  }

  resize() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.columns = Math.floor(this.canvas.width / this.fontSize);
    this.drops = Array.from({ length: this.columns }, () => 
      Math.random() * this.canvas.height / this.fontSize
    );
  }

  draw() {
    if (!this.active) return;

    // Semi-transparent black to create fade effect
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    // Matrix green color
    this.ctx.fillStyle = '#00ff00';
    this.ctx.font = `${this.fontSize}px monospace`;

    for (let i = 0; i < this.columns; i++) {
      const char = this.chars.charAt(Math.floor(Math.random() * this.chars.length));
      const x = i * this.fontSize;
      const y = this.drops[i] * this.fontSize;

      // Vary brightness for depth effect
      const brightness = Math.random() > 0.95 ? '#fff' : '#0f0';
      this.ctx.fillStyle = brightness;
      this.ctx.fillText(char, x, y);

      // Reset drop when it reaches bottom
      if (y > this.canvas.height && Math.random() > 0.975) {
        this.drops[i] = 0;
      }

      this.drops[i] += this.speed + Math.random() * 0.4;
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
    // Clear canvas
    if (this.ctx) {
      this.ctx.fillStyle = '#000';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
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

// Matrix Splash Screen (Enter Matrix)
class MatrixSplash {
  constructor() {
    this.overlay = null;
    this.terminal = null;
    this.entered = false;
  }

  init() {
    // Check if already entered
    if (sessionStorage.getItem('matrix_entered') === 'true') {
      this.entered = true;
      return;
    }

    this.createOverlay();
    this.showSplash();
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

  showSplash() {
    // Initialize splash rain
    const splashCanvas = document.getElementById('splash-matrix-canvas');
    const splashCtx = splashCanvas.getContext('2d');
    splashCanvas.width = window.innerWidth;
    splashCanvas.height = window.innerHeight;

    const chars = 'アァカサタナハマヤャラワ01';
    const fontSize = 16;
    let columns = Math.floor(splashCanvas.width / fontSize);
    let drops = Array.from({ length: columns }, () => Math.random() * splashCanvas.height / fontSize);

    const drawSplash = () => {
      splashCtx.fillStyle = 'rgba(0, 0, 0, 0.05)';
      splashCtx.fillRect(0, 0, splashCanvas.width, splashCanvas.height);
      splashCtx.fillStyle = '#0f0';
      splashCtx.font = `${fontSize}px monospace`;

      for (let i = 0; i < columns; i++) {
        const char = chars.charAt(Math.floor(Math.random() * chars.length));
        splashCtx.fillText(char, i * fontSize, drops[i] * fontSize);
        if (drops[i] * fontSize > splashCanvas.height && Math.random() > 0.975) {
          drops[i] = 0;
        }
        drops[i] += 0.5;
      }
    };

    const splashInterval = setInterval(drawSplash, 50);

    // Handle input
    const input = document.getElementById('matrix-splash-input');
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const cmd = input.value.trim().toLowerCase();
        if (cmd === 'enter matrix' || cmd === 'entermatrix' || cmd === 'enter') {
          clearInterval(splashInterval);
          this.enterMatrix();
        } else {
          input.value = '';
          input.placeholder = 'Command not recognized. Try "enter matrix"';
        }
      }
    });

    // Focus input
    setTimeout(() => input.focus(), 100);
  }

  enterMatrix() {
    this.entered = true;
    sessionStorage.setItem('matrix_entered', 'true');

    // Glitch effect
    this.overlay.classList.add('matrix-glitch');
    
    // Type effect
    const content = this.overlay.querySelector('.matrix-splash-content');
    content.innerHTML = `
      <h1 class="matrix-splash-title matrix-glitch-text">WELCOME TO THE REAL WORLD</h1>
      <p class="matrix-splash-subtitle">Follow the white rabbit...</p>
    `;

    // Fade out and remove
    setTimeout(() => {
      this.overlay.classList.add('matrix-fade-out');
      setTimeout(() => {
        this.overlay.remove();
        // Trigger custom event
        document.dispatchEvent(new CustomEvent('matrix:entered'));
      }, 1000);
    }, 1500);
  }
}

// Export for use
window.MatrixRain = MatrixRain;
window.MatrixSplash = MatrixSplash;

// Auto-initialize when DOM ready
document.addEventListener('DOMContentLoaded', () => {
  // Initialize Matrix rain background
  window.matrixRain = new MatrixRain();
  window.matrixRain.init();

  // Initialize splash screen (only for non-logged-in or first visit)
  const splash = new MatrixSplash();
  splash.init();
});
