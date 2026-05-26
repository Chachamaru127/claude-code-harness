/**
 * @file converters.test.js
 * @description Tests for time conversion utilities (frames ↔ milliseconds)
 */

const {
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
} = require('../src/utils/converters');

describe('Time Conversion Utilities', () => {
  describe('msToFrames', () => {
    it('converts 1 second (1000ms) to 30 frames at 30fps', () => {
      expect(msToFrames(1000, 30)).toBe(30);
    });

    it('converts 500ms to 15 frames at 30fps', () => {
      expect(msToFrames(500, 30)).toBe(15);
    });

    it('converts 1000ms to 60 frames at 60fps', () => {
      expect(msToFrames(1000, 60)).toBe(60);
    });

    it('rounds to nearest integer', () => {
      expect(msToFrames(33.33, 30)).toBe(1);
      expect(msToFrames(66.67, 30)).toBe(2);
    });

    it('uses default FPS when not provided', () => {
      expect(msToFrames(1000)).toBe(30); // DEFAULT_FPS = 30
    });

    it('throws error for negative milliseconds', () => {
      expect(() => msToFrames(-100, 30)).toThrow('milliseconds must be non-negative');
    });

    it('throws error for non-positive fps', () => {
      expect(() => msToFrames(1000, 0)).toThrow('fps must be positive');
      expect(() => msToFrames(1000, -30)).toThrow('fps must be positive');
    });
  });

  describe('framesToMs', () => {
    it('converts 30 frames to 1000ms at 30fps', () => {
      expect(framesToMs(30, 30)).toBe(1000);
    });

    it('converts 15 frames to 500ms at 30fps', () => {
      expect(framesToMs(15, 30)).toBe(500);
    });

    it('converts 60 frames to 1000ms at 60fps', () => {
      expect(framesToMs(60, 60)).toBe(1000);
    });

    it('rounds to 2 decimal places', () => {
      expect(framesToMs(1, 30)).toBe(33.33);
    });

    it('uses default FPS when not provided', () => {
      expect(framesToMs(30)).toBe(1000); // DEFAULT_FPS = 30
    });

    it('throws error for negative frames', () => {
      expect(() => framesToMs(-10, 30)).toThrow('frames must be non-negative');
    });

    it('throws error for non-positive fps', () => {
      expect(() => framesToMs(30, 0)).toThrow('fps must be positive');
    });
  });

  describe('secondsToFrames', () => {
    it('converts 1 second to 30 frames at 30fps', () => {
      expect(secondsToFrames(1, 30)).toBe(30);
    });

    it('converts 0.5 seconds to 15 frames at 30fps', () => {
      expect(secondsToFrames(0.5, 30)).toBe(15);
    });

    it('converts 1 second to 60 frames at 60fps', () => {
      expect(secondsToFrames(1, 60)).toBe(60);
    });

    it('throws error for negative seconds', () => {
      expect(() => secondsToFrames(-1, 30)).toThrow('seconds must be non-negative');
    });
  });

  describe('framesToSeconds', () => {
    it('converts 30 frames to 1 second at 30fps', () => {
      expect(framesToSeconds(30, 30)).toBe(1.00);
    });

    it('converts 15 frames to 0.5 seconds at 30fps', () => {
      expect(framesToSeconds(15, 30)).toBe(0.50);
    });

    it('converts 60 frames to 1 second at 60fps', () => {
      expect(framesToSeconds(60, 60)).toBe(1.00);
    });

    it('rounds to 2 decimal places', () => {
      expect(framesToSeconds(10, 30)).toBe(0.33);
    });

    it('throws error for negative frames', () => {
      expect(() => framesToSeconds(-10, 30)).toThrow('frames must be non-negative');
    });
  });

  describe('msToSeconds', () => {
    it('converts 1000ms to 1 second', () => {
      expect(msToSeconds(1000)).toBe(1.00);
    });

    it('converts 500ms to 0.5 seconds', () => {
      expect(msToSeconds(500)).toBe(0.50);
    });

    it('rounds to 2 decimal places', () => {
      expect(msToSeconds(333)).toBe(0.33);
    });

    it('throws error for negative milliseconds', () => {
      expect(() => msToSeconds(-100)).toThrow('milliseconds must be non-negative');
    });
  });

  describe('secondsToMs', () => {
    it('converts 1 second to 1000ms', () => {
      expect(secondsToMs(1)).toBe(1000);
    });

    it('converts 0.5 seconds to 500ms', () => {
      expect(secondsToMs(0.5)).toBe(500);
    });

    it('rounds to nearest integer', () => {
      expect(secondsToMs(0.3333)).toBe(333);
    });

    it('throws error for negative seconds', () => {
      expect(() => secondsToMs(-1)).toThrow('seconds must be non-negative');
    });
  });

  describe('batchMsToFrames', () => {
    it('converts array of milliseconds to frames', () => {
      expect(batchMsToFrames([1000, 2000, 3000], 30)).toEqual([30, 60, 90]);
    });

    it('works with empty array', () => {
      expect(batchMsToFrames([], 30)).toEqual([]);
    });

    it('uses default FPS', () => {
      expect(batchMsToFrames([1000, 500])).toEqual([30, 15]);
    });
  });

  describe('batchFramesToMs', () => {
    it('converts array of frames to milliseconds', () => {
      expect(batchFramesToMs([30, 60, 90], 30)).toEqual([1000, 2000, 3000]);
    });

    it('works with empty array', () => {
      expect(batchFramesToMs([], 30)).toEqual([]);
    });

    it('uses default FPS', () => {
      expect(batchFramesToMs([30, 15])).toEqual([1000, 500]);
    });
  });

  describe('getFrameAtTimestamp', () => {
    it('calculates frame number at timestamp', () => {
      expect(getFrameAtTimestamp(1500, 30)).toBe(45);
    });

    it('works with 0 timestamp', () => {
      expect(getFrameAtTimestamp(0, 30)).toBe(0);
    });
  });

  describe('getTimestampAtFrame', () => {
    it('calculates timestamp at frame', () => {
      expect(getTimestampAtFrame(45, 30)).toBe(1500);
    });

    it('works with frame 0', () => {
      expect(getTimestampAtFrame(0, 30)).toBe(0);
    });
  });

  describe('isValidFps', () => {
    it('validates positive numbers', () => {
      expect(isValidFps(30)).toBe(true);
      expect(isValidFps(60)).toBe(true);
      expect(isValidFps(0.5)).toBe(true);
    });

    it('rejects zero and negative numbers', () => {
      expect(isValidFps(0)).toBe(false);
      expect(isValidFps(-30)).toBe(false);
    });

    it('rejects non-numeric values', () => {
      expect(isValidFps('30')).toBe(false);
      expect(isValidFps(null)).toBe(false);
      expect(isValidFps(undefined)).toBe(false);
    });

    it('rejects infinity', () => {
      expect(isValidFps(Infinity)).toBe(false);
      expect(isValidFps(-Infinity)).toBe(false);
    });
  });

  describe('Constants', () => {
    it('exports DEFAULT_FPS', () => {
      expect(DEFAULT_FPS).toBe(30);
    });

    it('exports FPS_PRESETS', () => {
      expect(FPS_PRESETS.CINEMA).toBe(24);
      expect(FPS_PRESETS.STANDARD).toBe(30);
      expect(FPS_PRESETS.HD).toBe(60);
      expect(FPS_PRESETS.SMOOTH).toBe(120);
    });
  });

  describe('Round-trip conversions', () => {
    it('ms → frames → ms should be consistent', () => {
      const originalMs = 1500;
      const frames = msToFrames(originalMs, 30);
      const resultMs = framesToMs(frames, 30);
      expect(resultMs).toBe(originalMs);
    });

    it('frames → ms → frames should be consistent', () => {
      const originalFrames = 45;
      const ms = framesToMs(originalFrames, 30);
      const resultFrames = msToFrames(ms, 30);
      expect(resultFrames).toBe(originalFrames);
    });

    it('seconds → frames → seconds should be consistent', () => {
      const originalSeconds = 1.5;
      const frames = secondsToFrames(originalSeconds, 30);
      const resultSeconds = framesToSeconds(frames, 30);
      expect(resultSeconds).toBe(originalSeconds);
    });
  });

  describe('Edge cases', () => {
    it('handles zero values', () => {
      expect(msToFrames(0, 30)).toBe(0);
      expect(framesToMs(0, 30)).toBe(0);
      expect(secondsToFrames(0, 30)).toBe(0);
      expect(framesToSeconds(0, 30)).toBe(0);
    });

    it('handles very small values', () => {
      expect(msToFrames(1, 30)).toBe(0); // Rounds to 0
      expect(framesToMs(1, 30)).toBe(33.33);
    });

    it('handles large values', () => {
      expect(msToFrames(60000, 30)).toBe(1800); // 1 minute
      expect(framesToMs(1800, 30)).toBe(60000); // 1 minute
    });

    it('handles different FPS values', () => {
      // 24fps (cinema)
      expect(msToFrames(1000, 24)).toBe(24);
      // 60fps (high frame rate)
      expect(msToFrames(1000, 60)).toBe(60);
      // 120fps (very smooth)
      expect(msToFrames(1000, 120)).toBe(120);
    });
  });
});
