import React from 'react';
import { useCurrentFrame, interpolate } from 'remotion';

/**
 * ProgressIndicator Component
 *
 * Displays section position in the video with current position highlight.
 * Shows a visual progress bar or dot indicators for multi-section videos.
 */

export interface Section {
  /** Section identifier */
  id: string;

  /** Section display name */
  name: string;

  /** Start frame of this section */
  startFrame: number;

  /** End frame of this section */
  endFrame: number;

  /** Optional section color */
  color?: string;
}

export interface ProgressIndicatorProps {
  /** Array of sections in the video */
  sections: Section[];

  /** Current section index (0-based) */
  currentIndex?: number;

  /** Position on screen */
  position?: 'top' | 'bottom' | 'left' | 'right';

  /** Display style */
  style?: 'bar' | 'dots' | 'minimal';

  /** Show section labels */
  showLabels?: boolean;

  /** Primary color for active section */
  activeColor?: string;

  /** Color for inactive sections */
  inactiveColor?: string;

  /** Size of the indicator (pixels) */
  size?: 'small' | 'medium' | 'large';

  /** Animate transitions between sections */
  animated?: boolean;
}

const SIZE_CONFIG = {
  small: { height: 3, dotSize: 8, fontSize: 12, padding: 8 },
  medium: { height: 4, dotSize: 12, fontSize: 14, padding: 12 },
  large: { height: 6, dotSize: 16, fontSize: 16, padding: 16 },
};

export const ProgressIndicator: React.FC<ProgressIndicatorProps> = ({
  sections,
  currentIndex,
  position = 'bottom',
  style = 'dots',
  showLabels = false,
  activeColor = '#00F5FF',
  inactiveColor = '#444444',
  size = 'medium',
  animated = true,
}) => {
  const frame = useCurrentFrame();
  const sizeConfig = SIZE_CONFIG[size];

  // Auto-detect current index if not provided
  const effectiveCurrentIndex = currentIndex !== undefined
    ? currentIndex
    : sections.findIndex(s => frame >= s.startFrame && frame <= s.endFrame);

  // Calculate progress within current section
  const currentSection = sections[effectiveCurrentIndex];
  const sectionProgress = currentSection
    ? interpolate(
        frame,
        [currentSection.startFrame, currentSection.endFrame],
        [0, 1],
        { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
      )
    : 0;

  // Calculate overall progress
  const totalFrames = sections.length > 0
    ? sections[sections.length - 1].endFrame - sections[0].startFrame
    : 1;
  const overallProgress = sections.length > 0
    ? interpolate(
        frame,
        [sections[0].startFrame, sections[sections.length - 1].endFrame],
        [0, 100],
        { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
      )
    : 0;

  // Position styles
  const getPositionStyle = (): React.CSSProperties => {
    const baseStyle: React.CSSProperties = {
      position: 'absolute',
      zIndex: 100,
    };

    switch (position) {
      case 'top':
        return { ...baseStyle, top: sizeConfig.padding, left: sizeConfig.padding, right: sizeConfig.padding };
      case 'bottom':
        return { ...baseStyle, bottom: sizeConfig.padding, left: sizeConfig.padding, right: sizeConfig.padding };
      case 'left':
        return { ...baseStyle, left: sizeConfig.padding, top: sizeConfig.padding, bottom: sizeConfig.padding };
      case 'right':
        return { ...baseStyle, right: sizeConfig.padding, top: sizeConfig.padding, bottom: sizeConfig.padding };
    }
  };

  const containerStyle: React.CSSProperties = {
    ...getPositionStyle(),
    display: 'flex',
    flexDirection: position === 'left' || position === 'right' ? 'column' : 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: sizeConfig.padding,
  };

  // Render based on style
  const renderBar = () => {
    const barStyle: React.CSSProperties = {
      width: position === 'left' || position === 'right' ? `${sizeConfig.height}px` : '100%',
      height: position === 'left' || position === 'right' ? '100%' : `${sizeConfig.height}px`,
      backgroundColor: inactiveColor,
      borderRadius: sizeConfig.height,
      position: 'relative',
      overflow: 'hidden',
    };

    const fillStyle: React.CSSProperties = {
      position: 'absolute',
      top: 0,
      left: 0,
      width: position === 'left' || position === 'right' ? '100%' : `${overallProgress}%`,
      height: position === 'left' || position === 'right' ? `${overallProgress}%` : '100%',
      backgroundColor: activeColor,
      transition: animated ? 'width 0.3s ease, height 0.3s ease' : 'none',
      boxShadow: `0 0 10px ${activeColor}`,
    };

    return (
      <div style={barStyle}>
        <div style={fillStyle} />
      </div>
    );
  };

  const renderDots = () => {
    return (
      <>
        {sections.map((section, index) => {
          const isActive = index === effectiveCurrentIndex;
          const isPast = index < effectiveCurrentIndex;

          const dotStyle: React.CSSProperties = {
            width: sizeConfig.dotSize,
            height: sizeConfig.dotSize,
            borderRadius: '50%',
            backgroundColor: isActive || isPast ? activeColor : inactiveColor,
            transition: animated ? 'background-color 0.3s ease, transform 0.3s ease' : 'none',
            transform: isActive ? 'scale(1.3)' : 'scale(1)',
            boxShadow: isActive ? `0 0 12px ${activeColor}` : 'none',
            cursor: 'pointer',
          };

          return (
            <div key={section.id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
              <div style={dotStyle} />
              {showLabels && (
                <span
                  style={{
                    fontSize: sizeConfig.fontSize,
                    color: isActive ? activeColor : inactiveColor,
                    fontWeight: isActive ? 700 : 400,
                    transition: animated ? 'color 0.3s ease' : 'none',
                  }}
                >
                  {section.name}
                </span>
              )}
            </div>
          );
        })}
      </>
    );
  };

  const renderMinimal = () => {
    const minimalStyle: React.CSSProperties = {
      fontSize: sizeConfig.fontSize,
      color: activeColor,
      fontWeight: 600,
      fontFamily: 'monospace',
    };

    return (
      <div style={minimalStyle}>
        {effectiveCurrentIndex + 1} / {sections.length}
      </div>
    );
  };

  return (
    <div style={containerStyle}>
      {style === 'bar' && renderBar()}
      {style === 'dots' && renderDots()}
      {style === 'minimal' && renderMinimal()}
    </div>
  );
};

/**
 * Utility function to create sections from scene data
 */
export const createSections = (
  scenes: Array<{ id: string; name: string; startFrame: number; durationFrames: number }>
): Section[] => {
  return scenes.map(scene => ({
    id: scene.id,
    name: scene.name,
    startFrame: scene.startFrame,
    endFrame: scene.startFrame + scene.durationFrames,
  }));
};
