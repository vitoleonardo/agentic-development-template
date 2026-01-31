/**
 * UI Component Library
 *
 * This module exports all UI components for the application.
 * Components are organized by category and follow the visual layer pattern.
 *
 * SETUP REQUIRED:
 * 1. Install your UI framework (e.g., React, Vue, Svelte)
 * 2. Configure Storybook for component development
 * 3. Set up visual regression tests with Playwright
 *
 * DIRECTORY STRUCTURE:
 * src/ui/
 * ├── components/     # Reusable UI components
 * │   └── [name]/     # Each component in its own directory
 * │       ├── [name].tsx          # Component implementation
 * │       ├── [name].stories.tsx  # Storybook stories
 * │       ├── [name].test.tsx     # Unit tests (optional)
 * │       └── index.ts            # Barrel export
 * ├── layouts/        # Page layouts (add when needed)
 * ├── themes/         # Theme definitions (add when needed)
 * └── index.ts        # Main barrel export
 */

// Components
export * from './components/example-card';
