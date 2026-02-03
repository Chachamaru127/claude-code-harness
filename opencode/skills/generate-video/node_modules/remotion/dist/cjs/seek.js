"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.seek = void 0;
const playback_logging_1 = require("./playback-logging");
const video_fragment_1 = require("./video/video-fragment");
const seek = ({ mediaRef, time, logLevel, why, mountTime, }) => {
    // iOS seeking does not support multiple decimals
    const timeToSet = (0, video_fragment_1.isIosSafari)() ? Number(time.toFixed(1)) : time;
    (0, playback_logging_1.playbackLogging)({
        logLevel,
        tag: 'seek',
        message: `Seeking from ${mediaRef.currentTime} to ${timeToSet}. src= ${mediaRef.src} Reason: ${why}`,
        mountTime,
    });
    mediaRef.currentTime = timeToSet;
    return timeToSet;
};
exports.seek = seek;
