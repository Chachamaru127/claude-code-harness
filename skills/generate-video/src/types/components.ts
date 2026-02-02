/**
 * @file components.ts
 * @description Type definitions for Remotion component props
 * @version 1.0.0
 *
 * NOTE: These types are for Remotion React components (visual rendering layer).
 * They are intentionally different from JSON Schema types (data validation layer).
 *
 * For JSON Schema validation types, use Zod-inferred types from src/schemas/:
 *   import { Animation, Emphasis, Scene } from '../schemas';
 *   type AnimationType = z.infer<typeof AnimationSchema>;
 *
 * These component props include Remotion-specific fields (opacity_range, scale_range,
 * spring config, etc.) that are not part of the video-script.json schema.
 */

/**
 * Transition configuration for TransitionWrapper component
 * Provides Remotion-specific props for animation rendering
 */
export interface TransitionConfig {
  /** Transition type */
  type: 'fade' | 'slide_in' | 'zoom' | 'cut';

  /** Duration in milliseconds */
  duration_ms: number;

  /** Easing function (ignored for spring type) */
  easing?: 'linear' | 'easeIn' | 'easeOut' | 'easeInOut' | 'easeInQuad' | 'easeOutQuad' | 'easeInOutQuad' | 'easeInCubic' | 'easeOutCubic' | 'easeInOutCubic';

  /** Spring configuration (for spring type transitions) */
  spring?: {
    damping?: number;
    stiffness?: number;
    mass?: number;
    overshootClamping?: boolean;
  };

  /** Delay before transition starts (milliseconds) */
  delay_ms?: number;

  /** Slide direction (for slide_in type) */
  direction?: 'left' | 'right' | 'top' | 'bottom';

  /** Custom opacity range [from, to] */
  opacity_range?: [number, number];

  /** Custom scale range [from, to] for zoom */
  scale_range?: [number, number];

  /** Custom slide distance in pixels */
  slide_distance?: number;
}

/**
 * Emphasis configuration for EmphasisBox component
 * Provides Remotion-specific props for emphasis rendering
 */
export interface EmphasisConfig {
  /** Emphasis level affecting visual impact */
  level: 'high' | 'medium' | 'low';

  /** Visual effect type */
  effect: 'glow' | 'pulse' | 'outline' | 'none';

  /** Duration of emphasis in milliseconds */
  duration_ms?: number;

  /** Text content to emphasize */
  text?: string;

  /** Primary color (HEX format) */
  color?: string;

  /** Glow intensity (blur radius in pixels) */
  glow_intensity?: number;

  /** Enable pulse animation */
  enable_pulse?: boolean;

  /** Font size in pixels */
  font_size?: number;

  /** Background color (optional) */
  background_color?: string;

  /** Enable background box */
  enable_background?: boolean;
}

/**
 * Background configuration for BackgroundLayer component
 * Provides Remotion-specific props for background rendering
 */
export interface BackgroundConfig {
  /** Background type */
  type: 'solid' | 'gradient' | 'image' | 'video' | 'particles';

  /** Background value (color, URL, or gradient definition) */
  value: string;

  /** Opacity (0.0 - 1.0) */
  opacity?: number;

  /** Blur intensity in pixels */
  blur?: number;

  /** Enable animated effects */
  animated?: boolean;

  /** Overlay color (for tinting) */
  overlay_color?: string;

  /** Overlay opacity (0.0 - 1.0) */
  overlay_opacity?: number;

  /** For gradient type: secondary color */
  secondary_color?: string;

  /** For gradient type: angle in degrees */
  gradient_angle?: number;
}

/**
 * Text emphasis configuration
 * Provides props for animated text rendering
 */
export interface TextEmphasisConfig {
  /** Text content to emphasize */
  content: string;

  /** Start time in milliseconds (relative to scene) */
  start_ms?: number;

  /** Duration in milliseconds */
  duration_ms?: number;

  /** Text style variant */
  style?: 'bold' | 'glitch' | 'underline' | 'highlight' | 'glow';
}

/**
 * Sound effect configuration for emphasis
 * Provides props for audio cue synchronization
 */
export interface SoundEffectConfig {
  /** Sound effect type */
  type: 'none' | 'pop' | 'whoosh' | 'chime' | 'ding';

  /** Volume (0.0 - 1.0) */
  volume?: number;

  /** Timing relative to emphasis */
  timing?: 'start' | 'end' | 'peak';

  /** Trigger time in milliseconds (relative to scene) */
  trigger_ms?: number;
}

/**
 * Animation configuration
 * Provides props for entry/exit animations
 */
export interface AnimationConfig {
  /** Entry animation */
  entry?: 'none' | 'fade_in' | 'slide_in' | 'zoom_in' | 'bounce';

  /** Exit animation */
  exit?: 'none' | 'fade_out' | 'slide_out' | 'zoom_out';

  /** Animation duration in milliseconds */
  duration_ms?: number;

  /** Enable pulse effect */
  pulse?: boolean;

  /** Pulse speed */
  pulse_speed?: number;
}

/**
 * Progress indicator configuration
 */
export interface ProgressIndicatorConfig {
  /** Display style */
  style: 'bar' | 'circle' | 'dots' | 'none';

  /** Position on screen */
  position?: 'top' | 'bottom' | 'left' | 'right';

  /** Color (HEX format) */
  color?: string;

  /** Thickness in pixels */
  thickness?: number;

  /** Show percentage text */
  show_percentage?: boolean;
}

/**
 * Type guards for runtime validation
 */

export function isTransitionConfig(obj: unknown): obj is TransitionConfig {
  if (typeof obj !== 'object' || obj === null) return false;
  const config = obj as TransitionConfig;
  return (
    typeof config.type === 'string' &&
    ['fade', 'slide_in', 'zoom', 'cut'].includes(config.type) &&
    typeof config.duration_ms === 'number'
  );
}

export function isEmphasisConfig(obj: unknown): obj is EmphasisConfig {
  if (typeof obj !== 'object' || obj === null) return false;
  const config = obj as EmphasisConfig;
  return (
    typeof config.level === 'string' &&
    ['high', 'medium', 'low'].includes(config.level) &&
    typeof config.effect === 'string' &&
    ['glow', 'pulse', 'outline', 'none'].includes(config.effect)
  );
}

export function isBackgroundConfig(obj: unknown): obj is BackgroundConfig {
  if (typeof obj !== 'object' || obj === null) return false;
  const config = obj as BackgroundConfig;
  return (
    typeof config.type === 'string' &&
    ['solid', 'gradient', 'image', 'video', 'particles'].includes(config.type) &&
    typeof config.value === 'string'
  );
}
