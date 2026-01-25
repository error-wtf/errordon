import { start } from 'mastodon/common';
import { initMatrixTheme } from 'mastodon/features/errordon/matrix_theme';

// Import Matrix rain effect (side-effect: auto-initializes when theme-matrix class is present)
import '@/errordon/matrix/index.js';

start();
initMatrixTheme();
