/**
 * Example Card Component
 *
 * This is a placeholder component demonstrating the visual layer structure.
 * Replace with your actual UI components once a framework is selected.
 *
 * FRAMEWORK REQUIREMENTS:
 * - For React: npm install react react-dom
 * - For React types: npm install -D @types/react @types/react-dom
 *
 * This file assumes React but can be adapted to other frameworks.
 * Delete or replace this file once you have real components.
 */

// NOTE: Uncomment the import below once React is installed
// import React from 'react';

/**
 * Component state variants for visual testing
 */
export type ExampleCardState = 'default' | 'loading' | 'empty' | 'error';

export interface ExampleCardProps {
  /** Card title */
  title: string;
  /** Card description */
  description?: string;
  /** Current state of the card */
  state?: ExampleCardState;
  /** Error message when state is 'error' */
  errorMessage?: string;
  /** Click handler */
  onClick?: () => void;
}

/**
 * Example card component - placeholder for visual layer demonstration.
 *
 * States to test in Storybook:
 * - default: Normal display with title and description
 * - loading: Shows loading indicator
 * - empty: Shows empty state message
 * - error: Shows error state with message
 */
export function ExampleCard({
  title,
  description,
  state = 'default',
  errorMessage,
  onClick,
}: ExampleCardProps): JSX.Element {
  // NOTE: This is a placeholder. Replace with actual JSX once React is installed.
  // The structure below shows the expected component shape.

  throw new Error(
    'ExampleCard: React is not installed. ' +
      'Install React and uncomment the JSX implementation, or replace this component with your framework of choice.'
  );

  // Uncomment once React is installed:
  /*
  if (state === 'loading') {
    return (
      <div className="example-card example-card--loading" aria-busy="true">
        <div className="example-card__spinner" />
        <span>Loading...</span>
      </div>
    );
  }

  if (state === 'empty') {
    return (
      <div className="example-card example-card--empty">
        <span>No content available</span>
      </div>
    );
  }

  if (state === 'error') {
    return (
      <div className="example-card example-card--error" role="alert">
        <span className="example-card__error-icon">⚠</span>
        <span>{errorMessage || 'An error occurred'}</span>
      </div>
    );
  }

  return (
    <div
      className="example-card"
      onClick={onClick}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
    >
      <h3 className="example-card__title">{title}</h3>
      {description && (
        <p className="example-card__description">{description}</p>
      )}
    </div>
  );
  */
}

export default ExampleCard;
