/**
 * @file converters.ts
 * @description Utility functions for converting between time units (frames ↔ milliseconds)
 * @version 1.0.0
 */

/**
 * Default FPS for video (commonly 30fps)
 */
export const DEFAULT_FPS = 30;

/**
 * Converts milliseconds to frames
 *
 * @param ms - Duration in milliseconds
 * @param fps - Frames per second (default: 30)
 * @returns Duration in frames (rounded to nearest integer)
 *
 * @example
 * msToFrames(1000, 30) // => 30 (1 second at 30fps)
 * msToFrames(500, 60) // => 30 (0.5 seconds at 60fps)
 * msToFrames(33.33, 30) // => 1 (approximately 1 frame)
 */
export function msToFrames(ms: number, fps: number = DEFAULT_FPS): number {
  if (ms < 0) {
    throw new Error(`msToFrames: milliseconds must be non-negative, got ${ms}`);
  }
  if (fps <= 0) {
    throw new Error(`msToFrames: fps must be positive, got ${fps}`);
  }

  return Math.round((ms / 1000) * fps);
}

/**
 * Converts frames to milliseconds
 *
 * @param frames - Duration in frames
 * @param fps - Frames per second (default: 30)
 * @returns Duration in milliseconds (rounded to 2 decimal places)
 *
 * @example
 * framesToMs(30, 30) // => 1000 (30 frames at 30fps = 1 second)
 * framesToMs(60, 60) // => 1000 (60 frames at 60fps = 1 second)
 * framesToMs(15, 30) // => 500 (0.5 seconds)
 */
export function framesToMs(frames: number, fps: number = DEFAULT_FPS): number {
  if (frames < 0) {
    throw new Error(`framesToMs: frames must be non-negative, got ${frames}`);
  }
  if (fps <= 0) {
    throw new Error(`framesToMs: fps must be positive, got ${fps}`);
  }

  const ms = (frames / fps) * 1000;
  return Math.round(ms * 100) / 100; // Round to 2 decimal places
}

/**
 * Converts seconds to frames
 *
 * @param seconds - Duration in seconds
 * @param fps - Frames per second (default: 30)
 * @returns Duration in frames (rounded to nearest integer)
 *
 * @example
 * secondsToFrames(1, 30) // => 30
 * secondsToFrames(0.5, 60) // => 30
 */
export function secondsToFrames(seconds: number, fps: number = DEFAULT_FPS): number {
  if (seconds < 0) {
    throw new Error(`secondsToFrames: seconds must be non-negative, got ${seconds}`);
  }
  if (fps <= 0) {
    throw new Error(`secondsToFrames: fps must be positive, got ${fps}`);
  }

  return Math.round(seconds * fps);
}

/**
 * Converts frames to seconds
 *
 * @param frames - Duration in frames
 * @param fps - Frames per second (default: 30)
 * @returns Duration in seconds (rounded to 2 decimal places)
 *
 * @example
 * framesToSeconds(30, 30) // => 1.00
 * framesToSeconds(15, 30) // => 0.50
 */
export function framesToSeconds(frames: number, fps: number = DEFAULT_FPS): number {
  if (frames < 0) {
    throw new Error(`framesToSeconds: frames must be non-negative, got ${frames}`);
  }
  if (fps <= 0) {
    throw new Error(`framesToSeconds: fps must be positive, got ${fps}`);
  }

  const seconds = frames / fps;
  return Math.round(seconds * 100) / 100; // Round to 2 decimal places
}

/**
 * Converts milliseconds to seconds
 *
 * @param ms - Duration in milliseconds
 * @returns Duration in seconds (rounded to 2 decimal places)
 *
 * @example
 * msToSeconds(1000) // => 1.00
 * msToSeconds(500) // => 0.50
 */
export function msToSeconds(ms: number): number {
  if (ms < 0) {
    throw new Error(`msToSeconds: milliseconds must be non-negative, got ${ms}`);
  }

  return Math.round((ms / 1000) * 100) / 100; // Round to 2 decimal places
}

/**
 * Converts seconds to milliseconds
 *
 * @param seconds - Duration in seconds
 * @returns Duration in milliseconds
 *
 * @example
 * secondsToMs(1) // => 1000
 * secondsToMs(0.5) // => 500
 */
export function secondsToMs(seconds: number): number {
  if (seconds < 0) {
    throw new Error(`secondsToMs: seconds must be non-negative, got ${seconds}`);
  }

  return Math.round(seconds * 1000);
}

/**
 * Batch convert multiple millisecond values to frames
 *
 * @param msValues - Array of millisecond values
 * @param fps - Frames per second (default: 30)
 * @returns Array of frame values
 *
 * @example
 * batchMsToFrames([1000, 2000, 3000], 30) // => [30, 60, 90]
 */
export function batchMsToFrames(msValues: number[], fps: number = DEFAULT_FPS): number[] {
  return msValues.map(ms => msToFrames(ms, fps));
}

/**
 * Batch convert multiple frame values to milliseconds
 *
 * @param frameValues - Array of frame values
 * @param fps - Frames per second (default: 30)
 * @returns Array of millisecond values
 *
 * @example
 * batchFramesToMs([30, 60, 90], 30) // => [1000, 2000, 3000]
 */
export function batchFramesToMs(frameValues: number[], fps: number = DEFAULT_FPS): number[] {
  return frameValues.map(frames => framesToMs(frames, fps));
}

/**
 * Calculate frame number at a specific timestamp
 *
 * @param timestampMs - Timestamp in milliseconds
 * @param fps - Frames per second (default: 30)
 * @returns Frame number at the given timestamp
 *
 * @example
 * getFrameAtTimestamp(1500, 30) // => 45
 */
export function getFrameAtTimestamp(timestampMs: number, fps: number = DEFAULT_FPS): number {
  return msToFrames(timestampMs, fps);
}

/**
 * Calculate timestamp at a specific frame
 *
 * @param frameNumber - Frame number
 * @param fps - Frames per second (default: 30)
 * @returns Timestamp in milliseconds
 *
 * @example
 * getTimestampAtFrame(45, 30) // => 1500
 */
export function getTimestampAtFrame(frameNumber: number, fps: number = DEFAULT_FPS): number {
  return framesToMs(frameNumber, fps);
}

/**
 * Helper to validate FPS value
 *
 * @param fps - Frames per second to validate
 * @returns True if FPS is valid
 */
export function isValidFps(fps: number): boolean {
  return typeof fps === 'number' && fps > 0 && Number.isFinite(fps);
}

/**
 * Common FPS presets
 */
export const FPS_PRESETS = {
  CINEMA: 24,
  STANDARD: 30,
  HD: 60,
  SMOOTH: 120,
} as const;
