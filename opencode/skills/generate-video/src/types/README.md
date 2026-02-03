# Component Type Definitions

TypeScript type definitions for Remotion components, synchronized with JSON schemas.

## Overview

This directory contains TypeScript type definitions that match the JSON schema definitions in `schemas/`. These types ensure type safety when using Remotion components.

## Files

- **`components.ts`** - Core type definitions for Remotion components
- **`index.ts`** - Barrel export for convenience

## Type Definitions

### TransitionConfig

Configuration for the `TransitionWrapper` component.

```typescript
interface TransitionConfig {
  type: 'fade' | 'slide_in' | 'zoom' | 'cut';
  duration_ms: number;
  easing?: 'linear' | 'easeIn' | 'easeOut' | 'easeInOut' | ...;
  spring?: { damping?: number; stiffness?: number; mass?: number; };
  delay_ms?: number;
  direction?: 'left' | 'right' | 'top' | 'bottom';
  opacity_range?: [number, number];
  scale_range?: [number, number];
  slide_distance?: number;
}
```

**Maps to**: `schemas/animation.schema.json`

**Example**:
```typescript
const transition: TransitionConfig = {
  type: 'fade',
  duration_ms: 500,
  easing: 'easeInOut'
};
```

### EmphasisConfig

Configuration for the `EmphasisBox` component.

```typescript
interface EmphasisConfig {
  level: 'subtle' | 'medium' | 'strong';
  effect: 'glow' | 'pulse' | 'outline' | 'none';
  duration_ms?: number;
  text?: string;
  color?: string;
  glow_intensity?: number;
  enable_pulse?: boolean;
  font_size?: number;
  background_color?: string;
  enable_background?: boolean;
}
```

**Maps to**: `schemas/emphasis.schema.json`

**Example**:
```typescript
const emphasis: EmphasisConfig = {
  level: 'strong',
  effect: 'glow',
  text: 'Important!',
  color: '#00F5FF',
  glow_intensity: 30
};
```

### BackgroundConfig

Configuration for the `BackgroundLayer` component.

```typescript
interface BackgroundConfig {
  type: 'solid' | 'gradient' | 'image' | 'video' | 'particles';
  value: string;
  opacity?: number;
  blur?: number;
  animated?: boolean;
  overlay_color?: string;
  overlay_opacity?: number;
  secondary_color?: string;
  gradient_angle?: number;
}
```

**Maps to**: `schemas/visual-patterns.schema.json` background section

**Example**:
```typescript
const background: BackgroundConfig = {
  type: 'gradient',
  value: '#1a1a1a',
  secondary_color: '#2a2a2a',
  gradient_angle: 135,
  animated: true
};
```

## Type Guards

Runtime validation functions to check if objects conform to expected types:

```typescript
// Check if object is valid TransitionConfig
if (isTransitionConfig(obj)) {
  // TypeScript knows obj is TransitionConfig here
}

// Check if object is valid EmphasisConfig
if (isEmphasisConfig(obj)) {
  // TypeScript knows obj is EmphasisConfig here
}

// Check if object is valid BackgroundConfig
if (isBackgroundConfig(obj)) {
  // TypeScript knows obj is BackgroundConfig here
}
```

## Usage in Remotion Components

### Example: Using TransitionConfig

```tsx
import { TransitionConfig } from '../src/types/components';
import { msToFrames } from '../src/utils/converters';

interface MyComponentProps {
  transition: TransitionConfig;
}

export const MyComponent: React.FC<MyComponentProps> = ({ transition }) => {
  const durationFrames = msToFrames(transition.duration_ms, 30);

  return (
    <TransitionWrapper
      type={transition.type}
      duration={durationFrames}
      easing={transition.easing}
    >
      {/* Your content */}
    </TransitionWrapper>
  );
};
```

## Schema Synchronization

These types are manually synchronized with JSON schemas. When schemas change:

1. Update the corresponding type definition
2. Update type guards if needed
3. Run tests to ensure compatibility

### Automated Schema Generation

For automated type generation from JSON schemas, use:

```bash
npm run generate:schemas
```

This generates Zod schemas in `src/schemas/` which can be used for runtime validation.

## Related Files

- **Schemas**: `schemas/*.schema.json` - JSON Schema definitions
- **Zod Schemas**: `src/schemas/*.ts` - Auto-generated Zod schemas
- **Components**: `remotion/components/*.tsx` - Remotion components
- **Utilities**: `src/utils/converters.ts` - Frame/ms conversion utilities
