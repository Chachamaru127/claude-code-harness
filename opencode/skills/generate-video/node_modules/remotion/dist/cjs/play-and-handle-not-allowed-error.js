"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.playAndHandleNotAllowedError = void 0;
const log_1 = require("./log");
const playback_logging_1 = require("./playback-logging");
const playAndHandleNotAllowedError = ({ mediaRef, mediaType, onAutoPlayError, logLevel, mountTime, reason, isPlayer, }) => {
    const { current } = mediaRef;
    if (!current) {
        return;
    }
    (0, playback_logging_1.playbackLogging)({
        logLevel,
        tag: 'play',
        message: `Attempting to play ${current.src}. Reason: ${reason}`,
        mountTime,
    });
    const prom = current.play();
    if (!prom.catch) {
        return;
    }
    prom.catch((err) => {
        if (!current) {
            return;
        }
        // Pause was called after play in Chrome
        if (err.message.includes('request was interrupted by a call to pause')) {
            return;
        }
        // Pause was called after play in Safari
        if (err.message.includes('The operation was aborted.')) {
            return;
        }
        // Pause was called after play in Firefox
        if (err.message.includes('The fetching process for the media resource was aborted by the user agent')) {
            return;
        }
        // Got replaced by a different audio source in Chromium
        if (err.message.includes('request was interrupted by a new load request')) {
            return;
        }
        // Audio tag got unmounted
        if (err.message.includes('because the media was removed from the document')) {
            return;
        }
        // Audio tag got unmounted
        if (err.message.includes("user didn't interact with the document") &&
            current.muted) {
            return;
        }
        // eslint-disable-next-line no-console
        console.log(`Could not play ${mediaType} due to following error: `, err);
        if (!current.muted) {
            if (onAutoPlayError) {
                onAutoPlayError();
                return;
            }
            if (mediaType === 'video' && isPlayer) {
                log_1.Log.info({ logLevel, tag: '<' + mediaType + '>' }, `The video will be muted and we'll retry playing it.`);
                log_1.Log.info({ logLevel, tag: '<' + mediaType + '>' }, 'Use onAutoPlayError() to handle this error yourself.');
                current.muted = true;
                current.play();
            }
        }
    });
};
exports.playAndHandleNotAllowedError = playAndHandleNotAllowedError;
