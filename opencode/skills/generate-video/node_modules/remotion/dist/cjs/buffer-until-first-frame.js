"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useBufferUntilFirstFrame = void 0;
const react_1 = require("react");
const playback_logging_1 = require("./playback-logging");
const use_buffer_state_1 = require("./use-buffer-state");
const isSafariWebkit = () => {
    const isSafari = /^((?!chrome|android).)*safari/i.test(window.navigator.userAgent);
    return isSafari;
};
const useBufferUntilFirstFrame = ({ mediaRef, mediaType, onVariableFpsVideoDetected, pauseWhenBuffering, logLevel, mountTime, }) => {
    const bufferingRef = (0, react_1.useRef)(false);
    const { delayPlayback } = (0, use_buffer_state_1.useBufferState)();
    const bufferUntilFirstFrame = (0, react_1.useCallback)((requestedTime) => {
        var _a;
        if (mediaType !== 'video') {
            return;
        }
        if (!pauseWhenBuffering) {
            return;
        }
        const current = mediaRef.current;
        if (!current) {
            return;
        }
        if (current.readyState >= current.HAVE_FUTURE_DATA && !isSafariWebkit()) {
            (0, playback_logging_1.playbackLogging)({
                logLevel,
                message: `Not using buffer until first frame, because readyState is ${current.readyState} and is not Safari or Desktop Chrome`,
                mountTime,
                tag: 'buffer',
            });
            return;
        }
        if (!current.requestVideoFrameCallback) {
            (0, playback_logging_1.playbackLogging)({
                logLevel,
                message: `Not using buffer until first frame, because requestVideoFrameCallback is not supported`,
                mountTime,
                tag: 'buffer',
            });
            return;
        }
        bufferingRef.current = true;
        (0, playback_logging_1.playbackLogging)({
            logLevel,
            message: `Buffering ${(_a = mediaRef.current) === null || _a === void 0 ? void 0 : _a.src} until the first frame is received`,
            mountTime,
            tag: 'buffer',
        });
        const playback = delayPlayback();
        const unblock = () => {
            playback.unblock();
            current.removeEventListener('ended', unblock, {
                // @ts-expect-error
                once: true,
            });
            current.removeEventListener('pause', unblock, {
                // @ts-expect-error
                once: true,
            });
            bufferingRef.current = false;
        };
        const onEndedOrPauseOrCanPlay = () => {
            unblock();
        };
        current.requestVideoFrameCallback((_, info) => {
            const differenceFromRequested = Math.abs(info.mediaTime - requestedTime);
            if (differenceFromRequested > 0.5) {
                onVariableFpsVideoDetected();
            }
            unblock();
        });
        current.addEventListener('ended', onEndedOrPauseOrCanPlay, { once: true });
        current.addEventListener('pause', onEndedOrPauseOrCanPlay, { once: true });
        current.addEventListener('canplay', onEndedOrPauseOrCanPlay, {
            once: true,
        });
    }, [
        delayPlayback,
        logLevel,
        mediaRef,
        mediaType,
        mountTime,
        onVariableFpsVideoDetected,
        pauseWhenBuffering,
    ]);
    return (0, react_1.useMemo)(() => {
        return {
            isBuffering: () => bufferingRef.current,
            bufferUntilFirstFrame,
        };
    }, [bufferUntilFirstFrame]);
};
exports.useBufferUntilFirstFrame = useBufferUntilFirstFrame;
