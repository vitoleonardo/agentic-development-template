/**
 * Visual Testing Configuration
 *
 * Centralized configuration for visual regression tests.
 * Import this in your test files for consistent settings.
 *
 * USAGE:
 * ```typescript
 * import { visualConfig, CRITICAL_ROUTES, VIEWPORTS } from './visual-testing.config';
 * ```
 */

/**
 * Routes to test for visual regression.
 * Add your application's critical routes here.
 */
export const CRITICAL_ROUTES = [
  { name: 'home', path: '/', description: 'Landing page' },
  { name: 'login', path: '/login', description: 'Authentication page' },
  { name: 'dashboard', path: '/dashboard', description: 'Main dashboard' },
  // Add more routes as needed:
  // { name: 'settings', path: '/settings', description: 'User settings' },
  // { name: 'profile', path: '/profile', description: 'User profile' },
] as const;

/**
 * Viewport configurations for responsive testing.
 */
export const VIEWPORTS = {
  mobile: { width: 375, height: 667, name: 'iPhone SE' },
  mobileLarge: { width: 414, height: 896, name: 'iPhone 11 Pro Max' },
  tablet: { width: 768, height: 1024, name: 'iPad' },
  tabletLandscape: { width: 1024, height: 768, name: 'iPad Landscape' },
  desktop: { width: 1280, height: 720, name: 'Desktop HD' },
  desktopLarge: { width: 1920, height: 1080, name: 'Desktop Full HD' },
} as const;

/**
 * Screenshot comparison options.
 */
export const SCREENSHOT_OPTIONS = {
  /** Maximum allowed pixel difference ratio (0-1) */
  maxDiffPixelRatio: 0.01,
  /** Threshold for color difference (0-1) */
  threshold: 0.2,
  /** Animation settings */
  animations: 'disabled' as const,
};

/**
 * Visual test configuration object.
 */
export const visualConfig = {
  /** Base URL for the application */
  baseURL: process.env.BASE_URL || 'http://localhost:3000',

  /** Storybook URL for component testing */
  storybookURL: process.env.STORYBOOK_URL || 'http://localhost:6006',

  /** Directory for storing snapshots */
  snapshotDir: './tests/visual/snapshots',

  /** Routes configuration */
  routes: CRITICAL_ROUTES,

  /** Viewport configurations */
  viewports: VIEWPORTS,

  /** Screenshot options */
  screenshotOptions: SCREENSHOT_OPTIONS,

  /** Selectors to hide during screenshots (e.g., dynamic timestamps) */
  hideSelectors: [
    '[data-testid="timestamp"]',
    '[data-testid="random-content"]',
    '.dynamic-content',
  ],

  /** CSS to inject before screenshots to stabilize tests */
  stabilizationCSS: `
    *, *::before, *::after {
      animation-duration: 0s !important;
      animation-delay: 0s !important;
      transition-duration: 0s !important;
      transition-delay: 0s !important;
    }
    [data-testid="skeleton"], .skeleton {
      background: #e0e0e0 !important;
    }
  `,
};

export default visualConfig;
