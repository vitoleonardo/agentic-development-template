/**
 * Storybook stories for ExampleCard component
 *
 * STORYBOOK SETUP REQUIRED:
 * 1. Install Storybook: npx storybook@latest init
 * 2. Install React: npm install react react-dom
 * 3. Install types: npm install -D @types/react @types/react-dom
 *
 * This file demonstrates the story structure for visual testing.
 * Each state variant should have its own story for comprehensive visual coverage.
 *
 * VISUAL TESTING STATES:
 * - Default: Normal rendering
 * - Loading: Async/loading state
 * - Empty: No data state
 * - Error: Error state with message
 * - Interactive: With click handlers (for interaction testing)
 */

// NOTE: Uncomment imports once Storybook and React are installed
// import type { Meta, StoryObj } from '@storybook/react';
// import { ExampleCard } from './example-card';

/**
 * Placeholder type definitions for story structure.
 * Replace with actual Storybook types once installed.
 */
type Meta<T> = {
  title: string;
  component: T;
  tags?: string[];
  argTypes?: Record<string, unknown>;
};

type StoryObj<T> = {
  args?: Partial<T>;
  parameters?: Record<string, unknown>;
};

// Placeholder component reference
const ExampleCard = {} as React.ComponentType<{
  title: string;
  description?: string;
  state?: 'default' | 'loading' | 'empty' | 'error';
  errorMessage?: string;
  onClick?: () => void;
}>;

/**
 * Story metadata
 */
const meta: Meta<typeof ExampleCard> = {
  title: 'Components/ExampleCard',
  component: ExampleCard,
  tags: ['autodocs'],
  argTypes: {
    state: {
      control: 'select',
      options: ['default', 'loading', 'empty', 'error'],
      description: 'Visual state of the card',
    },
    onClick: {
      action: 'clicked',
      description: 'Click handler',
    },
  },
};

export default meta;
type Story = StoryObj<typeof ExampleCard>;

/**
 * Default state - normal card display
 */
export const Default: Story = {
  args: {
    title: 'Example Card',
    description: 'This is an example card component for visual testing.',
    state: 'default',
  },
};

/**
 * Loading state - shows loading indicator
 * Use for async operations, data fetching
 */
export const Loading: Story = {
  args: {
    title: 'Loading Card',
    state: 'loading',
  },
  parameters: {
    docs: {
      description: {
        story: 'Card in loading state while fetching data.',
      },
    },
  },
};

/**
 * Empty state - no content available
 * Use when data returns empty results
 */
export const Empty: Story = {
  args: {
    title: 'Empty Card',
    state: 'empty',
  },
  parameters: {
    docs: {
      description: {
        story: 'Card showing empty state when no data is available.',
      },
    },
  },
};

/**
 * Error state - shows error message
 * Use for failed operations, validation errors
 */
export const Error: Story = {
  args: {
    title: 'Error Card',
    state: 'error',
    errorMessage: 'Failed to load card content. Please try again.',
  },
  parameters: {
    docs: {
      description: {
        story: 'Card showing error state with descriptive message.',
      },
    },
  },
};

/**
 * Interactive state - with click handler
 * Use for clickable cards, buttons
 */
export const Interactive: Story = {
  args: {
    title: 'Clickable Card',
    description: 'Click me to trigger an action.',
    state: 'default',
    onClick: () => console.log('Card clicked'),
  },
  parameters: {
    docs: {
      description: {
        story: 'Interactive card with click handler.',
      },
    },
  },
};

/**
 * Long content - tests text overflow
 */
export const LongContent: Story = {
  args: {
    title: 'Card with Very Long Title That Might Overflow the Container',
    description:
      'This is a very long description that tests how the card handles overflow. ' +
      'It should wrap appropriately and not break the layout. Lorem ipsum dolor sit amet, ' +
      'consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
    state: 'default',
  },
  parameters: {
    docs: {
      description: {
        story: 'Tests text overflow handling with long content.',
      },
    },
  },
};
