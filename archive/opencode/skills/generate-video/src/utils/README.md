# Utility Functions

Conversion utilities for working with Remotion time units.

## Overview

Remotion uses **frames** as the primary time unit, while JSON schemas use **milliseconds**. These utilities provide bidirectional conversion between time units.

## Files

- **`converters.ts`** - TypeScript version (for Remotion components)
- **`converters.js`** - JavaScript version (for Node.js scripts and tests)
- **`index.ts`** - Barrel export

## Core Conversions

### msToFrames(ms, fps)

Converts milliseconds to frames.

```javascript
msToFrames(1000, 30)  // => 30 (1 second at 30fps)
msToFrames(500, 60)   // => 30 (0.5 seconds at 60fps)
msToFrames(33.33, 30) // => 1 (approximately 1 frame)
```

**Parameters**:
- `ms` (number) - Duration in milliseconds
- `fps` (number, optional) - Frames per second (default: 30)

**Returns**: Duration in frames (rounded to nearest integer)

**Throws**: Error if ms < 0 or fps <= 0

---

### framesToMs(frames, fps)

Converts frames to milliseconds.

```javascript
framesToMs(30, 30) // => 1000 (30 frames at 30fps = 1 second)
framesToMs(15, 30) // => 500 (0.5 seconds)
framesToMs(1, 30)  // => 33.33
```

**Parameters**:
- `frames` (number) - Duration in frames
- `fps` (number, optional) - Frames per second (default: 30)

**Returns**: Duration in milliseconds (rounded to 2 decimal places)

**Throws**: Error if frames < 0 or fps <= 0

---

### secondsToFrames(seconds, fps)

Converts seconds to frames.

```javascript
secondsToFrames(1, 30)    // => 30
secondsToFrames(0.5, 60)  // => 30
```

---

### framesToSeconds(frames, fps)

Converts frames to seconds.

```javascript
framesToSeconds(30, 30) // => 1.00
framesToSeconds(15, 30) // => 0.50
```

---

### msToSeconds(ms)

Converts milliseconds to seconds.

```javascript
msToSeconds(1000) // => 1.00
msToSeconds(500)  // => 0.50
```

---

### secondsToMs(seconds)

Converts seconds to milliseconds.

```javascript
secondsToMs(1)   // => 1000
secondsToMs(0.5) // => 500
```

---

## Batch Conversions

### batchMsToFrames(msValues, fps)

Convert multiple millisecond values to frames.

```javascript
batchMsToFrames([1000, 2000, 3000], 30)
// => [30, 60, 90]
```

---

### batchFramesToMs(frameValues, fps)

Convert multiple frame values to milliseconds.

```javascript
batchFramesToMs([30, 60, 90], 30)
// => [1000, 2000, 3000]
```

---

## Timestamp Utilities

### getFrameAtTimestamp(timestampMs, fps)

Calculate frame number at a specific timestamp.

```javascript
getFrameAtTimestamp(1500, 30) // => 45
```

---

### getTimestampAtFrame(frameNumber, fps)

Calculate timestamp at a specific frame.

```javascript
getTimestampAtFrame(45, 30) // => 1500
```

---

## Validation

### isValidFps(fps)

Validate FPS value.

```javascript
isValidFps(30)       // => true
isValidFps(0)        // => false
isValidFps(-30)      // => false
isValidFps(Infinity) // => false
```

---

## Constants

### DEFAULT_FPS

Default frames per second (30).

```javascript
const { DEFAULT_FPS } = require('./converters');
console.log(DEFAULT_FPS); // => 30
```

---

### FPS_PRESETS

Common FPS presets.

```javascript
const { FPS_PRESETS } = require('./converters');

FPS_PRESETS.CINEMA   // => 24 (cinematic video)
FPS_PRESETS.STANDARD // => 30 (standard video)
FPS_PRESETS.HD       // => 60 (high frame rate)
FPS_PRESETS.SMOOTH   // => 120 (very smooth)
```

---

## Usage Examples

### Example 1: Converting Schema Duration to Remotion Frames

```typescript
import { msToFrames } from '../src/utils/converters';
import { useVideoConfig } from 'remotion';

export const MyScene: React.FC<{ durationMs: number }> = ({ durationMs }) => {
  const { fps } = useVideoConfig();
  const durationFrames = msToFrames(durationMs, fps);

  return <Sequence durationInFrames={durationFrames}>{/* ... */}</Sequence>;
};
```

### Example 2: Batch Converting Animation Timings

```javascript
const { batchMsToFrames } = require('./src/utils/converters');

const animationTimings = {
  intro: 1000,
  main: 3000,
  outro: 1000,
};

const fps = 30;
const [introFrames, mainFrames, outroFrames] = batchMsToFrames(
  [animationTimings.intro, animationTimings.main, animationTimings.outro],
  fps
);

console.log({ introFrames, mainFrames, outroFrames });
// => { introFrames: 30, mainFrames: 90, outroFrames: 30 }
```

### Example 3: Working with Different FPS

```javascript
const { msToFrames, FPS_PRESETS } = require('./src/utils/converters');

// Cinema (24fps)
const cinema = msToFrames(1000, FPS_PRESETS.CINEMA); // => 24

// Standard (30fps)
const standard = msToFrames(1000, FPS_PRESETS.STANDARD); // => 30

// HD (60fps)
const hd = msToFrames(1000, FPS_PRESETS.HD); // => 60
```

### Example 4: Round-Trip Conversion

```javascript
const { msToFrames, framesToMs } = require('./src/utils/converters');

const originalMs = 1500;
const frames = msToFrames(originalMs, 30); // => 45
const backToMs = framesToMs(frames, 30);   // => 1500

console.log(originalMs === backToMs); // => true
```

---

## Error Handling

All conversion functions validate inputs and throw descriptive errors:

```javascript
msToFrames(-100, 30)
// Error: msToFrames: milliseconds must be non-negative, got -100

framesToMs(30, 0)
// Error: framesToMs: fps must be positive, got 0

secondsToFrames(-1, 30)
// Error: secondsToFrames: seconds must be non-negative, got -1
```

---

## Testing

Run tests to verify all conversions:

```bash
npm test -- tests/converters.test.js
```

Test coverage includes:
- ✅ Basic conversions
- ✅ Default parameters
- ✅ Batch operations
- ✅ Edge cases (zero, very small, very large values)
- ✅ Error handling
- ✅ Round-trip conversions
- ✅ Different FPS values

---

## Performance

All conversion functions are lightweight and optimized for performance:

- **Arithmetic operations only** (no heavy computations)
- **Rounding to 2 decimal places** for precision
- **No external dependencies**

Suitable for use in Remotion's rendering loop without performance concerns.

---

## Related Files

- **Type Definitions**: `src/types/components.ts` - Component type definitions
- **Tests**: `tests/converters.test.js` - Comprehensive test suite
- **Remotion Components**: `remotion/components/*.tsx` - Components using these utilities
