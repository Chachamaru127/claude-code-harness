import React from 'react';
import { useCurrentFrame, useVideoConfig, interpolate, spring } from 'remotion';

/**
 * EmphasisBox Component
 *
 * Displays emphasized text with three levels of intensity (high/medium/low),
 * optional sound effects, animations (pulse, glow), and customizable colors.
 */

export type EmphasisLevel = 'high' | 'medium' | 'low';
export type EmphasisSound = 'none' | 'pop' | 'whoosh' | 'chime' | 'ding';
export type EmphasisStyle = 'bold' | 'glitch' | 'underline' | 'highlight' | 'glow';

export interface EmphasisBoxProps {
  /** Emphasis level affecting size, animation intensity, and visual impact */
  level: EmphasisLevel;

  /** Text content to display */
  text: string;

  /** Sound effect type (optional, for audio integration) */
  sound?: EmphasisSound;

  /** Primary color for text and effects (hex format) */
  color?: string;

  /** Start frame for the emphasis (relative to scene) */
  startFrame?: number;

  /** Duration in frames for the emphasis display */
  durationFrames?: number;

  /** Text style variant */
  style?: EmphasisStyle;

  /** Enable pulse animation */
  enablePulse?: boolean;

  /** Enable glow effect */
  enableGlow?: boolean;

  /** Glow intensity (blur radius in pixels) */
  glowIntensity?: number;

  /** Font size override (pixels) */
  fontSize?: number;

  /** Background color (optional, for box mode) */
  backgroundColor?: string;

  /** Enable background box */
  enableBackground?: boolean;
}

const LEVEL_CONFIG = {
  high: {
    fontSize: 72,
    glowIntensity: 30,
    pulseScale: 1.15,
    pulseSpeed: 0.15,
    animationDuration: 20,
  },
  medium: {
    fontSize: 56,
    glowIntensity: 20,
    pulseScale: 1.08,
    pulseSpeed: 0.12,
    animationDuration: 15,
  },
  low: {
    fontSize: 42,
    glowIntensity: 12,
    pulseScale: 1.04,
    pulseSpeed: 0.1,
    animationDuration: 12,
  },
};

export const EmphasisBox: React.FC<EmphasisBoxProps> = ({
  level,
  text,
  sound = 'none',
  color = '#00F5FF',
  startFrame = 0,
  durationFrames = 90,
  style = 'bold',
  enablePulse = false,
  enableGlow = true,
  glowIntensity,
  fontSize,
  backgroundColor = 'rgba(0, 0, 0, 0.8)',
  enableBackground = false,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const config = LEVEL_CONFIG[level];
  const effectiveFontSize = fontSize ?? config.fontSize;
  const effectiveGlowIntensity = glowIntensity ?? config.glowIntensity;

  // Calculate relative frame within emphasis duration
  const relativeFrame = frame - startFrame;
  const isVisible = relativeFrame >= 0 && relativeFrame < durationFrames;

  if (!isVisible) {
    return null;
  }

  // Entry animation (fade + scale)
  const entryProgress = spring({
    frame: relativeFrame,
    fps,
    config: {
      damping: 200,
      stiffness: 100,
      mass: 1,
    },
  });

  // Exit animation
  const exitStartFrame = durationFrames - config.animationDuration;
  const exitProgress = relativeFrame >= exitStartFrame
    ? interpolate(
        relativeFrame,
        [exitStartFrame, durationFrames],
        [1, 0],
        {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        }
      )
    : 1;

  const opacity = entryProgress * exitProgress;

  // Pulse animation
  let scale = entryProgress;
  if (enablePulse && relativeFrame >= config.animationDuration) {
    const pulsePhase = (relativeFrame * config.pulseSpeed) % (Math.PI * 2);
    const pulseValue = Math.sin(pulsePhase);
    const pulseAmount = (config.pulseScale - 1) * ((pulseValue + 1) / 2);
    scale = entryProgress * (1 + pulseAmount);
  }

  // Style-specific effects
  const getTextStyle = (): React.CSSProperties => {
    const baseStyle: React.CSSProperties = {
      fontSize: effectiveFontSize,
      fontWeight: 700,
      color,
      margin: 0,
      padding: 0,
      lineHeight: 1.2,
    };

    switch (style) {
      case 'bold':
        return {
          ...baseStyle,
          fontWeight: 900,
        };

      case 'glitch':
        // Glitch effect with text shadow
        const glitchOffset = enablePulse ? Math.sin(relativeFrame * 0.5) * 2 : 0;
        return {
          ...baseStyle,
          textShadow: `
            ${glitchOffset}px 0 0 #ff00ff,
            ${-glitchOffset}px 0 0 #00ffff,
            0 0 ${effectiveGlowIntensity}px ${color}
          `,
        };

      case 'underline':
        return {
          ...baseStyle,
          textDecoration: 'underline',
          textDecorationColor: color,
          textDecorationThickness: '4px',
        };

      case 'highlight':
        return {
          ...baseStyle,
          background: `linear-gradient(90deg, transparent 0%, ${color}40 50%, transparent 100%)`,
          WebkitBackgroundClip: 'text',
          padding: '0 20px',
        };

      case 'glow':
      default:
        return {
          ...baseStyle,
          textShadow: enableGlow
            ? `0 0 ${effectiveGlowIntensity}px ${color}, 0 0 ${effectiveGlowIntensity * 2}px ${color}`
            : 'none',
        };
    }
  };

  const containerStyle: React.CSSProperties = {
    position: 'absolute',
    top: '50%',
    left: '50%',
    transform: `translate(-50%, -50%) scale(${scale})`,
    opacity,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    ...(enableBackground && {
      backgroundColor,
      padding: '24px 48px',
      borderRadius: '12px',
      border: enableGlow ? `2px solid ${color}` : 'none',
      boxShadow: enableGlow
        ? `0 0 ${effectiveGlowIntensity}px ${color}, inset 0 0 ${effectiveGlowIntensity / 2}px ${color}40`
        : 'none',
    }),
  };

  const textStyle = getTextStyle();

  return (
    <div style={containerStyle}>
      <h1 style={textStyle}>
        {text}
      </h1>

      {/* Sound effect metadata (for audio system integration) */}
      {sound !== 'none' && (
        <div
          data-sound-effect={sound}
          data-trigger-frame={startFrame}
          style={{ display: 'none' }}
        />
      )}
    </div>
  );
};
