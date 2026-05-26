import React from 'react';
import { useCurrentFrame, useVideoConfig, interpolate, spring, Easing } from 'remotion';

/**
 * TransitionWrapper Component
 *
 * Wraps children with transition effects using Remotion's interpolate and spring.
 * Supports 4 transition types: fade, slide_in, zoom, cut.
 */

export type TransitionType = 'fade' | 'slide_in' | 'zoom' | 'cut';
export type SlideDirection = 'left' | 'right' | 'top' | 'bottom';
export type EasingType = 'linear' | 'easeIn' | 'easeOut' | 'easeInOut';

export interface TransitionWrapperProps {
  /** Transition type */
  type: TransitionType;

  /** Duration of the transition in frames */
  duration?: number;

  /** Direction for slide_in transition */
  direction?: SlideDirection;

  /** Easing function for interpolation */
  easing?: EasingType;

  /** Use spring physics instead of interpolation */
  useSpring?: boolean;

  /** Spring configuration (when useSpring is true) */
  springConfig?: {
    damping?: number;
    stiffness?: number;
    mass?: number;
  };

  /** Delay before transition starts (frames) */
  delay?: number;

  /** Children to wrap with transition */
  children: React.ReactNode;

  /** Custom opacity range [from, to] */
  opacityRange?: [number, number];

  /** Custom scale range [from, to] for zoom */
  scaleRange?: [number, number];

  /** Custom slide distance in pixels */
  slideDistance?: number;
}

const EASING_MAP: Record<EasingType, typeof Easing.linear> = {
  linear: Easing.linear,
  easeIn: Easing.in(Easing.ease),
  easeOut: Easing.out(Easing.ease),
  easeInOut: Easing.inOut(Easing.ease),
};

export const TransitionWrapper: React.FC<TransitionWrapperProps> = ({
  type,
  duration = 15,
  direction = 'right',
  easing = 'easeInOut',
  useSpring: shouldUseSpring = false,
  springConfig = {
    damping: 200,
    stiffness: 100,
    mass: 1,
  },
  delay = 0,
  children,
  opacityRange = [0, 1],
  scaleRange = [0.5, 1],
  slideDistance = 100,
}) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();

  const relativeFrame = frame - delay;

  // Calculate transition progress
  let progress: number;

  if (type === 'cut') {
    // Instant cut (no animation)
    progress = relativeFrame >= 0 ? 1 : 0;
  } else if (shouldUseSpring) {
    // Use spring physics
    progress = spring({
      frame: relativeFrame,
      fps,
      config: springConfig,
    });
  } else {
    // Use interpolation with easing
    progress = interpolate(
      relativeFrame,
      [0, duration],
      [0, 1],
      {
        easing: EASING_MAP[easing],
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      }
    );
  }

  // Calculate transition properties based on type
  const getTransitionStyle = (): React.CSSProperties => {
    switch (type) {
      case 'fade': {
        const opacity = interpolate(
          progress,
          [0, 1],
          opacityRange,
          { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
        );
        return {
          opacity,
        };
      }

      case 'slide_in': {
        const slideOffset = interpolate(
          progress,
          [0, 1],
          [slideDistance, 0],
          { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
        );

        let translateX = 0;
        let translateY = 0;

        switch (direction) {
          case 'left':
            translateX = slideOffset;
            break;
          case 'right':
            translateX = -slideOffset;
            break;
          case 'top':
            translateY = slideOffset;
            break;
          case 'bottom':
            translateY = -slideOffset;
            break;
        }

        const opacity = interpolate(
          progress,
          [0, 0.3, 1],
          [0, 1, 1],
          { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
        );

        return {
          transform: `translate(${translateX}px, ${translateY}px)`,
          opacity,
        };
      }

      case 'zoom': {
        const scale = interpolate(
          progress,
          [0, 1],
          scaleRange,
          { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
        );

        const opacity = interpolate(
          progress,
          [0, 0.2, 1],
          [0, 1, 1],
          { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
        );

        return {
          transform: `scale(${scale})`,
          opacity,
        };
      }

      case 'cut':
      default: {
        return {
          opacity: progress >= 1 ? 1 : 0,
        };
      }
    }
  };

  const transitionStyle = getTransitionStyle();

  const containerStyle: React.CSSProperties = {
    width: '100%',
    height: '100%',
    position: 'relative',
    ...transitionStyle,
  };

  return (
    <div style={containerStyle}>
      {children}
    </div>
  );
};

/**
 * Utility function to create transition presets
 */
export const TransitionPresets = {
  fadeIn: (duration = 15): Partial<TransitionWrapperProps> => ({
    type: 'fade',
    duration,
    opacityRange: [0, 1],
  }),

  fadeOut: (duration = 15): Partial<TransitionWrapperProps> => ({
    type: 'fade',
    duration,
    opacityRange: [1, 0],
  }),

  slideFromRight: (duration = 20): Partial<TransitionWrapperProps> => ({
    type: 'slide_in',
    duration,
    direction: 'right',
    slideDistance: 200,
  }),

  slideFromLeft: (duration = 20): Partial<TransitionWrapperProps> => ({
    type: 'slide_in',
    duration,
    direction: 'left',
    slideDistance: 200,
  }),

  zoomIn: (duration = 20): Partial<TransitionWrapperProps> => ({
    type: 'zoom',
    duration,
    scaleRange: [0.8, 1],
  }),

  springBounce: (): Partial<TransitionWrapperProps> => ({
    type: 'zoom',
    useSpring: true,
    springConfig: {
      damping: 100,
      stiffness: 200,
      mass: 1,
    },
  }),
};
