import React from 'react';
import { useCurrentFrame, useVideoConfig, interpolate, Img, Video } from 'remotion';

/**
 * BackgroundLayer Component
 *
 * Provides 5 types of animated backgrounds for video scenes.
 * Supports both static images and video backgrounds.
 */

export type BackgroundType = 'neutral' | 'highlight' | 'dramatic' | 'tech' | 'warm';

export interface BackgroundLayerProps {
  /** Background type */
  type: BackgroundType;

  /** Path to background image or video (optional, falls back to generated gradient) */
  src?: string;

  /** Is the source a video? */
  isVideo?: boolean;

  /** Primary color for generated backgrounds (hex format) */
  primaryColor?: string;

  /** Secondary color for gradients (hex format) */
  secondaryColor?: string;

  /** Background opacity */
  opacity?: number;

  /** Enable animated effects */
  animated?: boolean;

  /** Blur intensity (pixels) */
  blur?: number;

  /** Overlay color (optional, for tinting) */
  overlayColor?: string;

  /** Overlay opacity */
  overlayOpacity?: number;
}

const TYPE_CONFIG: Record<BackgroundType, {
  primaryColor: string;
  secondaryColor: string;
  gradientAngle: number;
  animationSpeed: number;
}> = {
  neutral: {
    primaryColor: '#1a1a1a',
    secondaryColor: '#2a2a2a',
    gradientAngle: 135,
    animationSpeed: 0.5,
  },
  highlight: {
    primaryColor: '#00F5FF',
    secondaryColor: '#FF00F5',
    gradientAngle: 45,
    animationSpeed: 1,
  },
  dramatic: {
    primaryColor: '#0a0a0a',
    secondaryColor: '#FF1744',
    gradientAngle: 180,
    animationSpeed: 0.3,
  },
  tech: {
    primaryColor: '#0D1117',
    secondaryColor: '#1E3A8A',
    gradientAngle: 90,
    animationSpeed: 0.8,
  },
  warm: {
    primaryColor: '#FF6B35',
    secondaryColor: '#F7931E',
    gradientAngle: 315,
    animationSpeed: 0.6,
  },
};

export const BackgroundLayer: React.FC<BackgroundLayerProps> = ({
  type,
  src,
  isVideo = false,
  primaryColor,
  secondaryColor,
  opacity = 1,
  animated = true,
  blur = 0,
  overlayColor,
  overlayOpacity = 0.3,
}) => {
  const frame = useCurrentFrame();
  const { width, height, fps } = useVideoConfig();

  const config = TYPE_CONFIG[type];
  const effectivePrimaryColor = primaryColor ?? config.primaryColor;
  const effectiveSecondaryColor = secondaryColor ?? config.secondaryColor;

  // Animated gradient rotation
  const gradientAngle = animated
    ? interpolate(
        frame,
        [0, fps * 10], // 10 second cycle
        [config.gradientAngle, config.gradientAngle + 360],
        { extrapolateRight: 'wrap' }
      )
    : config.gradientAngle;

  // Animated gradient position for flowing effect
  const gradientPosition = animated
    ? interpolate(
        frame,
        [0, fps * 5], // 5 second cycle
        [0, 100],
        { extrapolateRight: 'wrap' }
      )
    : 0;

  // Background styles
  const containerStyle: React.CSSProperties = {
    position: 'absolute',
    width: '100%',
    height: '100%',
    top: 0,
    left: 0,
    overflow: 'hidden',
    zIndex: -1,
  };

  const gradientStyle: React.CSSProperties = {
    position: 'absolute',
    width: '100%',
    height: '100%',
    background: `linear-gradient(${gradientAngle}deg, ${effectivePrimaryColor} ${gradientPosition}%, ${effectiveSecondaryColor} ${100 + gradientPosition}%)`,
    opacity,
    filter: blur > 0 ? `blur(${blur}px)` : 'none',
  };

  // Tech-specific grid overlay
  const renderTechGrid = () => {
    if (type !== 'tech') return null;

    const gridOpacity = animated
      ? interpolate(
          Math.sin(frame * 0.05),
          [-1, 1],
          [0.1, 0.3]
        )
      : 0.2;

    return (
      <div
        style={{
          position: 'absolute',
          width: '100%',
          height: '100%',
          backgroundImage: `
            linear-gradient(${effectivePrimaryColor}40 1px, transparent 1px),
            linear-gradient(90deg, ${effectivePrimaryColor}40 1px, transparent 1px)
          `,
          backgroundSize: '50px 50px',
          opacity: gridOpacity,
        }}
      />
    );
  };

  // Dramatic-specific vignette
  const renderDramaticVignette = () => {
    if (type !== 'dramatic') return null;

    return (
      <div
        style={{
          position: 'absolute',
          width: '100%',
          height: '100%',
          background: 'radial-gradient(circle at center, transparent 0%, rgba(0,0,0,0.8) 100%)',
        }}
      />
    );
  };

  // Highlight-specific particles effect (CSS-based)
  const renderHighlightParticles = () => {
    if (type !== 'highlight' || !animated) return null;

    const particleCount = 20;
    const particles = Array.from({ length: particleCount }, (_, i) => {
      const x = (i * 5) % 100;
      const delay = i * 0.2;
      const translateY = interpolate(
        frame - delay * fps,
        [0, fps * 3],
        [0, height],
        { extrapolateRight: 'wrap' }
      );

      return (
        <div
          key={i}
          style={{
            position: 'absolute',
            left: `${x}%`,
            width: '2px',
            height: '2px',
            backgroundColor: effectivePrimaryColor,
            borderRadius: '50%',
            transform: `translateY(${translateY}px)`,
            opacity: 0.6,
            boxShadow: `0 0 10px ${effectivePrimaryColor}`,
          }}
        />
      );
    });

    return <>{particles}</>;
  };

  // Warm-specific radial gradient
  const renderWarmRadial = () => {
    if (type !== 'warm') return null;

    const pulseScale = animated
      ? interpolate(
          Math.sin(frame * 0.1),
          [-1, 1],
          [0.8, 1.2]
        )
      : 1;

    return (
      <div
        style={{
          position: 'absolute',
          width: '100%',
          height: '100%',
          background: `radial-gradient(circle at center, ${effectivePrimaryColor} 0%, ${effectiveSecondaryColor} 100%)`,
          transform: `scale(${pulseScale})`,
          transformOrigin: 'center',
        }}
      />
    );
  };

  return (
    <div style={containerStyle}>
      {/* Base gradient or solid color */}
      {!src && <div style={gradientStyle} />}

      {/* Image or video source */}
      {src && !isVideo && (
        <Img
          src={src}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            opacity,
            filter: blur > 0 ? `blur(${blur}px)` : 'none',
          }}
        />
      )}

      {src && isVideo && (
        <Video
          src={src}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            opacity,
            filter: blur > 0 ? `blur(${blur}px)` : 'none',
          }}
        />
      )}

      {/* Type-specific effects */}
      {renderTechGrid()}
      {renderDramaticVignette()}
      {renderHighlightParticles()}
      {renderWarmRadial()}

      {/* Optional overlay tint */}
      {overlayColor && (
        <div
          style={{
            position: 'absolute',
            width: '100%',
            height: '100%',
            backgroundColor: overlayColor,
            opacity: overlayOpacity,
            pointerEvents: 'none',
          }}
        />
      )}
    </div>
  );
};

/**
 * Utility function to get recommended background for scene type
 */
export const getRecommendedBackground = (sceneType: string): BackgroundType => {
  const typeMap: Record<string, BackgroundType> = {
    intro: 'highlight',
    hook: 'dramatic',
    demo: 'neutral',
    feature: 'tech',
    cta: 'warm',
    conclusion: 'dramatic',
  };

  return typeMap[sceneType.toLowerCase()] ?? 'neutral';
};
