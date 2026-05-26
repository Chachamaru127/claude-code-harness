# Remotion Visual Components

Phase 5: 視覚コンポーネント実装

## Components

### 1. EmphasisBox

3段階の強調表示コンポーネント。

**Features**:
- 3 levels: `high`, `medium`, `low`
- 5 styles: `bold`, `glitch`, `underline`, `highlight`, `glow`
- Pulse animation support
- Glow effects
- Sound effect integration
- Customizable colors and fonts

**Usage**:
```tsx
import { EmphasisBox } from './components';

<EmphasisBox
  level="high"
  text="Important Message"
  color="#00F5FF"
  enablePulse={true}
  enableGlow={true}
  sound="pop"
  startFrame={30}
  durationFrames={90}
/>
```

**Props**:
- `level`: `'high' | 'medium' | 'low'` - Emphasis intensity
- `text`: `string` - Text to display
- `color`: `string` - Primary color (hex)
- `sound`: `'none' | 'pop' | 'whoosh' | 'chime' | 'ding'` - Sound effect
- `style`: `'bold' | 'glitch' | 'underline' | 'highlight' | 'glow'`
- `enablePulse`: `boolean` - Enable pulse animation
- `enableGlow`: `boolean` - Enable glow effect
- `startFrame`: `number` - Start frame (relative to scene)
- `durationFrames`: `number` - Duration in frames

---

### 2. TransitionWrapper

4種類のトランジションエフェクトでコンテンツをラップ。

**Features**:
- 4 types: `fade`, `slideIn`, `zoom`, `cut`
- Remotion `interpolate` and `spring` support
- 4 easing functions: `linear`, `easeIn`, `easeOut`, `easeInOut`
- Customizable slide direction
- Spring physics option
- Preset configurations

**Usage**:
```tsx
import { TransitionWrapper, TransitionPresets } from './components';

<TransitionWrapper
  type="slideIn"
  duration={20}
  direction="right"
  easing="easeInOut"
>
  <YourContent />
</TransitionWrapper>

// Or use presets
<TransitionWrapper {...TransitionPresets.fadeIn(15)}>
  <YourContent />
</TransitionWrapper>
```

**Props**:
- `type`: `'fade' | 'slideIn' | 'zoom' | 'cut'` - Transition type
- `duration`: `number` - Duration in frames (default: 15)
- `direction`: `'left' | 'right' | 'top' | 'bottom'` - Slide direction
- `easing`: `'linear' | 'easeIn' | 'easeOut' | 'easeInOut'`
- `useSpring`: `boolean` - Use spring physics instead of interpolation
- `springConfig`: `{ damping, stiffness, mass }` - Spring parameters
- `delay`: `number` - Delay before transition starts (frames)

**Presets**:
- `TransitionPresets.fadeIn(duration)`
- `TransitionPresets.fadeOut(duration)`
- `TransitionPresets.slideFromRight(duration)`
- `TransitionPresets.slideFromLeft(duration)`
- `TransitionPresets.zoomIn(duration)`
- `TransitionPresets.springBounce()`

---

### 3. ProgressIndicator

セクション位置表示コンポーネント。

**Features**:
- 3 styles: `bar`, `dots`, `minimal`
- 4 positions: `top`, `bottom`, `left`, `right`
- Auto-detection of current section
- Animated transitions
- Optional section labels
- 3 sizes: `small`, `medium`, `large`

**Usage**:
```tsx
import { ProgressIndicator, createSections } from './components';

const sections = createSections([
  { id: 'intro', name: 'Intro', startFrame: 0, durationFrames: 90 },
  { id: 'demo', name: 'Demo', startFrame: 90, durationFrames: 180 },
  { id: 'cta', name: 'CTA', startFrame: 270, durationFrames: 60 },
]);

<ProgressIndicator
  sections={sections}
  position="bottom"
  style="dots"
  showLabels={true}
  activeColor="#00F5FF"
  size="medium"
/>
```

**Props**:
- `sections`: `Section[]` - Array of sections
- `currentIndex`: `number` - Current section (auto-detected if omitted)
- `position`: `'top' | 'bottom' | 'left' | 'right'`
- `style`: `'bar' | 'dots' | 'minimal'`
- `showLabels`: `boolean` - Show section names
- `activeColor`: `string` - Color for active section
- `inactiveColor`: `string` - Color for inactive sections
- `size`: `'small' | 'medium' | 'large'`
- `animated`: `boolean` - Animate transitions

**Section Type**:
```typescript
interface Section {
  id: string;
  name: string;
  startFrame: number;
  endFrame: number;
  color?: string;
}
```

---

### 4. BackgroundLayer

5種類のアニメーション背景レイヤー。

**Features**:
- 5 types: `neutral`, `highlight`, `dramatic`, `tech`, `warm`
- Static image or video support
- Animated gradients
- Type-specific effects:
  - `tech`: Animated grid overlay
  - `dramatic`: Vignette effect
  - `highlight`: Floating particles
  - `warm`: Pulsing radial gradient
- Blur and overlay support
- Customizable colors

**Usage**:
```tsx
import { BackgroundLayer, getRecommendedBackground } from './components';

// Generated gradient background
<BackgroundLayer
  type="tech"
  animated={true}
  opacity={0.8}
/>

// Image background
<BackgroundLayer
  type="neutral"
  src="/path/to/background.jpg"
  blur={5}
  overlayColor="rgba(0,0,0,0.3)"
/>

// Video background
<BackgroundLayer
  type="highlight"
  src="/path/to/background.mp4"
  isVideo={true}
  opacity={0.6}
/>

// Auto-select based on scene type
const bgType = getRecommendedBackground('intro'); // Returns 'highlight'
```

**Props**:
- `type`: `'neutral' | 'highlight' | 'dramatic' | 'tech' | 'warm'`
- `src`: `string` - Path to image/video (optional)
- `isVideo`: `boolean` - Is the source a video?
- `primaryColor`: `string` - Primary gradient color (hex)
- `secondaryColor`: `string` - Secondary gradient color (hex)
- `opacity`: `number` - Background opacity (0-1)
- `animated`: `boolean` - Enable animations
- `blur`: `number` - Blur intensity (pixels)
- `overlayColor`: `string` - Overlay tint color
- `overlayOpacity`: `number` - Overlay opacity (0-1)

**Background Types**:
| Type | Primary | Secondary | Use Case |
|------|---------|-----------|----------|
| `neutral` | Dark gray | Light gray | General content, demos |
| `highlight` | Cyan | Magenta | Intros, CTAs, highlights |
| `dramatic` | Black | Red | Hooks, problem statements |
| `tech` | Dark blue | Navy | Architecture, technical content |
| `warm` | Orange | Yellow | Conclusions, warm CTAs |

---

## Integration with Schemas

All components are designed to work with the Phase 4 schemas:

- `EmphasisBox` ← `emphasis.schema.json`
- `TransitionWrapper` ← `animation.schema.json`
- `BackgroundLayer` ← `direction.schema.json` (background section)

**Example Integration**:
```typescript
import { EmphasisBox, TransitionWrapper, BackgroundLayer } from './components';
import { EmphasisSchema, AnimationSchema, DirectionSchema } from '../schemas';

// Load direction data from JSON
const direction = DirectionSchema.parse(directionData);

// Use in Remotion composition
<>
  <BackgroundLayer
    type={direction.background.type}
    primaryColor={direction.background.primaryColor}
    opacity={direction.background.opacity}
  />

  <TransitionWrapper
    type={direction.transition.type}
    duration={direction.transition.duration_frames}
    easing={direction.transition.easing}
  >
    <EmphasisBox
      level={direction.emphasis.level}
      text={direction.emphasis.text[0]}
      sound={direction.emphasis.sound}
      color={direction.emphasis.color}
    />
  </TransitionWrapper>
</>
```

---

## Animation Performance

All components use Remotion's native `interpolate` and `spring` functions for optimal performance:

- **CPU-efficient**: No heavy React re-renders
- **Predictable**: Deterministic animations
- **Smooth**: 60fps at 1920x1080

**Best Practices**:
1. Use `spring` for natural motion (bounces, elastic)
2. Use `interpolate` for linear/eased motion
3. Avoid complex CSS filters in animated sections
4. Prefer CSS transforms over layout changes

---

## Testing

Each component can be tested individually in Remotion Studio:

```bash
cd remotion
npm run dev
```

Create test compositions in `src/Root.tsx`:

```tsx
import { Composition } from 'remotion';
import { EmphasisBox, TransitionWrapper, ProgressIndicator, BackgroundLayer } from './components';

export const RemotionRoot = () => (
  <>
    <Composition
      id="EmphasisTest"
      component={EmphasisBox}
      durationInFrames={180}
      fps={30}
      width={1920}
      height={1080}
      defaultProps={{
        level: 'high',
        text: 'Test Emphasis',
        enablePulse: true,
      }}
    />
    {/* More test compositions... */}
  </>
);
```

---

## Next Steps

### Phase 6: Image Generation Patterns

Now that visual components are implemented, integrate them with AI-generated images:

1. **Task 6.1**: Define `visual-patterns.schema.json`
2. **Task 6.2**: Create image prompt templates
3. **Task 6.3**: Implement comparison/concept/flow patterns
4. **Task 6.4**: Integrate with Nano Banana Pro

### Integration Points

- Use `BackgroundLayer` with AI-generated backgrounds
- Overlay `EmphasisBox` on AI-generated diagrams
- Animate AI images with `TransitionWrapper`
- Show generation progress with `ProgressIndicator`

---

## License

Part of Claude Code Harness - generate-video skill.
MIT License.
