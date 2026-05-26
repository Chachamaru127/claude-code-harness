/**
 * Visual Components for Remotion Video Generation
 *
 * Phase 5: Visual Components
 * - EmphasisBox: 3-level emphasis display with animations
 * - TransitionWrapper: 4 transition types (fade, slideIn, zoom, cut)
 * - ProgressIndicator: Section progress visualization
 * - BackgroundLayer: 5 background types with animations
 */

export { EmphasisBox } from './EmphasisBox';
export type {
  EmphasisBoxProps,
  EmphasisLevel,
  EmphasisSound,
  EmphasisStyle,
} from './EmphasisBox';

export { TransitionWrapper, TransitionPresets } from './TransitionWrapper';
export type {
  TransitionWrapperProps,
  TransitionType,
  SlideDirection,
  EasingType,
} from './TransitionWrapper';

export { ProgressIndicator, createSections } from './ProgressIndicator';
export type {
  ProgressIndicatorProps,
  Section,
} from './ProgressIndicator';

export { BackgroundLayer, getRecommendedBackground } from './BackgroundLayer';
export type {
  BackgroundLayerProps,
  BackgroundType,
} from './BackgroundLayer';
