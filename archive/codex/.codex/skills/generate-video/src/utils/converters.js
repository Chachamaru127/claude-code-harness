/**
 * @file converters.js
 * @description Utility functions for converting between time units (frames ↔ milliseconds)
 * @version 1.0.0
 */

/**
 * Default FPS for video (commonly 30fps)
 */
const DEFAULT_FPS = 30;

/**
 * Converts milliseconds to frames
 *
 * @param {number} ms - Duration in milliseconds
 * @param {number} [fps=30] - Frames per second (default: 30)
 * @returns {number} Duration in frames (rounded to nearest integer)
 *
 * @example
 * msToFrames(1000, 30) // => 30 (1 second at 30fps)
 * msToFrames(500, 60) // => 30 (0.5 seconds at 60fps)
 * msToFrames(33.33, 30) // => 1 (approximately 1 frame)
 */
function msToFrames(ms, fps = DEFAULT_FPS) {
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
 * @param {number} frames - Duration in frames
 * @param {number} [fps=30] - Frames per second (default: 30)
 * @returns {number} Duration in milliseconds (rounded to 2 decimal places)
 *
 * @example
 * framesToMs(30, 30) // => 1000 (30 frames at 30fps = 1 second)
 * framesToMs(60, 60) // => 1000 (60 frames at 60fps = 1 second)
 * framesToMs(15, 30) // => 500 (0.5 seconds)
 */
function framesToMs(frames, fps = DEFAULT_FPS) {
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
 * @param {number} seconds - Duration in seconds
 * @param {number} [fps=30] - Frames per second (default: 30)
 * @returns {number} Duration in frames (rounded to nearest integer)
 *
 * @example
 * secondsToFrames(1, 30) // => 30
 * secondsToFrames(0.5, 60) // => 30
 */
function secondsToFrames(seconds, fps = DEFAULT_FPS) {
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
 * @param {number} frames - Duration in frames
 * @param {number} [fps=30] - Frames per second (default: 30)
 * @returns {number} Duration in seconds (rounded to 2 decimal places)
 *
 * @example
 * framesToSeconds(30, 30) // => 1.00
 * framesToSeconds(15, 30) // => 0.50
 */
function framesToSeconds(frames, fps = DEFAULT_FPS) {
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
 * @param {number} ms - Duration in milliseconds
 * @returns {number} Duration in seconds (rounded to 2 decimal places)
 *
 * @example
 * msToSeconds(1000) // => 1.00
 * msToSeconds(500) // => 0.50
 */
function msToSeconds(ms) {
  if (ms < 0) {
    throw new Error(`msToSeconds: milliseconds must be non-negative, got ${ms}`);
  }

  return Math.round((ms / 1000) * 100) / 100; // Round to 2 decimal places
}

/**
 * Converts seconds to milliseconds
 *
 * @param {number} seconds - Duration in seconds
 * @returns {number} Duration in milliseconds
 *
 * @example
 * secondsToMs(1) // => 1000
 * secondsToMs(0.5) // => 500
 */
function secondsToMs(seconds) {
  if (seconds < 0) {
    throw new Error(`secondsToMs: seconds must be non-negative, got ${seconds}`);
  }

  return Math.round(seconds * 1000);
}

/**
 * Batch convert multiple millisecond values to frames
 *
 * @param {number[]} msValues - Array of millisecond values
 * @param {number} [fps=30] - Frames per second (default: 30)
 * @returns {number[]} Array of frame values
 *
 * @example
 * batchMsToFrames([1000, 2000, 3000], 30) // => [30, 60, 90]
 */
function batchMsToFrames(msValues, fps = DEFAULT_FPS) {
  return msValues.map(ms => msToFrames(ms, fps));
}

/**
 * Batch convert multiple frame values to milliseconds
 *
 * @param {number[]} frameValues - Array of frame values
 * @param {number} [fps=30] - Frames per second (default: 30)
 * @returns {number[]} Array of millisecond values
 *
 * @example
 * batchFramesToMs([30, 60, 90], 30) // => [1000, 2000, 3000]
 */
function batchFramesToMs(frameValues, fps = DEFAULT_FPS) {
  return frameValues.map(frames => framesToMs(frames, fps));
}

/**
 * Calculate frame number at a specific timestamp
 *
 * @param {number} timestampMs - Timestamp in milliseconds
 * @param {number} [fps=30] - Frames per second (default: 30)
 * @returns {number} Frame number at the given timestamp
 *
 * @example
 * getFrameAtTimestamp(1500, 30) // => 45
 */
function getFrameAtTimestamp(timestampMs, fps = DEFAULT_FPS) {
  return msToFrames(timestampMs, fps);
}

/**
 * Calculate timestamp at a specific frame
 *
 * @param {number} frameNumber - Frame number
 * @param {number} [fps=30] - Frames per second (default: 30)
 * @returns {number} Timestamp in milliseconds
 *
 * @example
 * getTimestampAtFrame(45, 30) // => 1500
 */
function getTimestampAtFrame(frameNumber, fps = DEFAULT_FPS) {
  return framesToMs(frameNumber, fps);
}

/**
 * Helper to validate FPS value
 *
 * @param {number} fps - Frames per second to validate
 * @returns {boolean} True if FPS is valid
 */
function isValidFps(fps) {
  return typeof fps === 'number' && fps > 0 && Number.isFinite(fps);
}

/**
 * Common FPS presets
 */
const FPS_PRESETS = {
  CINEMA: 24,
  STANDARD: 30,
  HD: 60,
  SMOOTH: 120,
};

module.exports = {
  msToFrames,
  framesToMs,
  secondsToFrames,
  framesToSeconds,
  msToSeconds,
  secondsToMs,
  batchMsToFrames,
  batchFramesToMs,
  getFrameAtTimestamp,
  getTimestampAtFrame,
  isValidFps,
  DEFAULT_FPS,
  FPS_PRESETS,
};
