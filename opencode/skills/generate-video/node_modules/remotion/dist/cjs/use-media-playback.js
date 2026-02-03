"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useMediaPlayback = void 0;
const react_1 = require("react");
const use_audio_frame_js_1 = require("./audio/use-audio-frame.js");
const buffer_until_first_frame_js_1 = require("./buffer-until-first-frame.js");
const buffering_js_1 = require("./buffering.js");
const log_level_context_js_1 = require("./log-level-context.js");
const log_js_1 = require("./log.js");
const media_tag_current_time_timestamp_js_1 = require("./media-tag-current-time-timestamp.js");
const play_and_handle_not_allowed_error_js_1 = require("./play-and-handle-not-allowed-error.js");
const playback_logging_js_1 = require("./playback-logging.js");
const seek_js_1 = require("./seek.js");
const timeline_position_state_js_1 = require("./timeline-position-state.js");
const TimelineContext_js_1 = require("./TimelineContext.js");
const use_current_frame_js_1 = require("./use-current-frame.js");
const use_media_buffering_js_1 = require("./use-media-buffering.js");
const use_remotion_environment_js_1 = require("./use-remotion-environment.js");
const use_request_video_callback_time_js_1 = require("./use-request-video-callback-time.js");
const use_video_config_js_1 = require("./use-video-config.js");
const get_current_time_js_1 = require("./video/get-current-time.js");
const warn_about_non_seekable_media_js_1 = require("./warn-about-non-seekable-media.js");
const useMediaPlayback = ({ mediaRef, src, mediaType, playbackRate: localPlaybackRate, onlyWarnForMediaSeekingError, acceptableTimeshift, pauseWhenBuffering, isPremounting, isPostmounting, onAutoPlayError, }) => {
    const { playbackRate: globalPlaybackRate } = (0, react_1.useContext)(TimelineContext_js_1.TimelineContext);
    const frame = (0, use_current_frame_js_1.useCurrentFrame)();
    const absoluteFrame = (0, timeline_position_state_js_1.useTimelinePosition)();
    const [playing] = (0, timeline_position_state_js_1.usePlayingState)();
    const buffering = (0, react_1.useContext)(buffering_js_1.BufferingContextReact);
    const { fps } = (0, use_video_config_js_1.useVideoConfig)();
    const mediaStartsAt = (0, use_audio_frame_js_1.useMediaStartsAt)();
    const lastSeekDueToShift = (0, react_1.useRef)(null);
    const lastSeek = (0, react_1.useRef)(null);
    const logLevel = (0, log_level_context_js_1.useLogLevel)();
    const mountTime = (0, log_level_context_js_1.useMountTime)();
    if (!buffering) {
        throw new Error('useMediaPlayback must be used inside a <BufferingContext>');
    }
    const isVariableFpsVideoMap = (0, react_1.useRef)({});
    const onVariableFpsVideoDetected = (0, react_1.useCallback)(() => {
        if (!src) {
            return;
        }
        if (isVariableFpsVideoMap.current[src]) {
            return;
        }
        log_js_1.Log.verbose({ logLevel, tag: null }, `Detected ${src} as a variable FPS video. Disabling buffering while seeking.`);
        isVariableFpsVideoMap.current[src] = true;
    }, [logLevel, src]);
    const rvcCurrentTime = (0, use_request_video_callback_time_js_1.useRequestVideoCallbackTime)({
        mediaRef,
        mediaType,
        lastSeek,
        onVariableFpsVideoDetected,
    });
    const mediaTagCurrentTime = (0, media_tag_current_time_timestamp_js_1.useCurrentTimeOfMediaTagWithUpdateTimeStamp)(mediaRef);
    const desiredUnclampedTime = (0, get_current_time_js_1.getMediaTime)({
        frame,
        playbackRate: localPlaybackRate,
        startFrom: -mediaStartsAt,
        fps,
    });
    const isMediaTagBuffering = (0, use_media_buffering_js_1.useMediaBuffering)({
        element: mediaRef,
        shouldBuffer: pauseWhenBuffering,
        isPremounting,
        isPostmounting,
        logLevel,
        mountTime,
        src: src !== null && src !== void 0 ? src : null,
    });
    const { bufferUntilFirstFrame, isBuffering } = (0, buffer_until_first_frame_js_1.useBufferUntilFirstFrame)({
        mediaRef,
        mediaType,
        onVariableFpsVideoDetected,
        pauseWhenBuffering,
        logLevel,
        mountTime,
    });
    const playbackRate = localPlaybackRate * globalPlaybackRate;
    const acceptableTimeShiftButLessThanDuration = (() => {
        var _a;
        // In Safari, it seems to lag behind mostly around ~0.4 seconds
        const DEFAULT_ACCEPTABLE_TIMESHIFT_WITH_NORMAL_PLAYBACK = 0.45;
        // If there is amplification, the acceptable timeshift is higher
        const DEFAULT_ACCEPTABLE_TIMESHIFT_WITH_AMPLIFICATION = DEFAULT_ACCEPTABLE_TIMESHIFT_WITH_NORMAL_PLAYBACK + 0.2;
        const defaultAcceptableTimeshift = DEFAULT_ACCEPTABLE_TIMESHIFT_WITH_AMPLIFICATION;
        // For short audio, a lower acceptable time shift is used
        if ((_a = mediaRef.current) === null || _a === void 0 ? void 0 : _a.duration) {
            return Math.min(mediaRef.current.duration, acceptableTimeshift !== null && acceptableTimeshift !== void 0 ? acceptableTimeshift : defaultAcceptableTimeshift);
        }
        return acceptableTimeshift !== null && acceptableTimeshift !== void 0 ? acceptableTimeshift : defaultAcceptableTimeshift;
    })();
    const isPlayerBuffering = (0, buffering_js_1.useIsPlayerBuffering)(buffering);
    (0, react_1.useEffect)(() => {
        var _a, _b, _c, _d, _e;
        if ((_a = mediaRef.current) === null || _a === void 0 ? void 0 : _a.paused) {
            return;
        }
        if (!playing) {
            (0, playback_logging_js_1.playbackLogging)({
                logLevel,
                tag: 'pause',
                message: `Pausing ${(_b = mediaRef.current) === null || _b === void 0 ? void 0 : _b.src} because ${isPremounting ? 'media is premounting' : isPostmounting ? 'media is postmounting' : 'Player is not playing'}`,
                mountTime,
            });
            (_c = mediaRef.current) === null || _c === void 0 ? void 0 : _c.pause();
            return;
        }
        const isMediaTagBufferingOrStalled = isMediaTagBuffering || isBuffering();
        const playerBufferingNotStateButLive = buffering.buffering.current;
        if (playerBufferingNotStateButLive && !isMediaTagBufferingOrStalled) {
            (0, playback_logging_js_1.playbackLogging)({
                logLevel,
                tag: 'pause',
                message: `Pausing ${(_d = mediaRef.current) === null || _d === void 0 ? void 0 : _d.src} because player is buffering but media tag is not`,
                mountTime,
            });
            (_e = mediaRef.current) === null || _e === void 0 ? void 0 : _e.pause();
        }
    }, [
        isBuffering,
        isMediaTagBuffering,
        buffering,
        isPlayerBuffering,
        isPremounting,
        logLevel,
        mediaRef,
        mediaType,
        mountTime,
        playing,
        isPostmounting,
    ]);
    const env = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    // This must be a useLayoutEffect, because afterwards, useVolume() looks at the playbackRate
    // and it is also in a useLayoutEffect.
    (0, react_1.useLayoutEffect)(() => {
        const playbackRateToSet = Math.max(0, playbackRate);
        if (mediaRef.current &&
            mediaRef.current.playbackRate !== playbackRateToSet) {
            mediaRef.current.playbackRate = playbackRateToSet;
        }
    }, [mediaRef, playbackRate]);
    (0, react_1.useEffect)(() => {
        var _a, _b, _c;
        const tagName = mediaType === 'audio' ? '<Html5Audio>' : '<Html5Video>';
        if (!mediaRef.current) {
            throw new Error(`No ${mediaType} ref found`);
        }
        if (!src) {
            throw new Error(`No 'src' attribute was passed to the ${tagName} element.`);
        }
        const { duration } = mediaRef.current;
        const shouldBeTime = !Number.isNaN(duration) && Number.isFinite(duration)
            ? Math.min(duration, desiredUnclampedTime)
            : desiredUnclampedTime;
        const mediaTagTime = mediaTagCurrentTime.current.time;
        const rvcTime = (_b = (_a = rvcCurrentTime.current) === null || _a === void 0 ? void 0 : _a.time) !== null && _b !== void 0 ? _b : null;
        const isVariableFpsVideo = isVariableFpsVideoMap.current[src];
        const timeShiftMediaTag = Math.abs(shouldBeTime - mediaTagTime);
        const timeShiftRvcTag = rvcTime ? Math.abs(shouldBeTime - rvcTime) : null;
        const mostRecentTimeshift = ((_c = rvcCurrentTime.current) === null || _c === void 0 ? void 0 : _c.lastUpdate) &&
            rvcCurrentTime.current.time > mediaTagCurrentTime.current.lastUpdate
            ? timeShiftRvcTag
            : timeShiftMediaTag;
        const timeShift = timeShiftRvcTag && !isVariableFpsVideo
            ? mostRecentTimeshift
            : timeShiftMediaTag;
        if (timeShift > acceptableTimeShiftButLessThanDuration &&
            lastSeekDueToShift.current !== shouldBeTime) {
            // If scrubbing around, adjust timing
            // or if time shift is bigger than 0.45sec
            lastSeek.current = (0, seek_js_1.seek)({
                mediaRef: mediaRef.current,
                time: shouldBeTime,
                logLevel,
                why: `because time shift is too big. shouldBeTime = ${shouldBeTime}, isTime = ${mediaTagTime}, requestVideoCallbackTime = ${rvcTime}, timeShift = ${timeShift}${isVariableFpsVideo ? ', isVariableFpsVideo = true' : ''}, isPremounting = ${isPremounting}, isPostmounting = ${isPostmounting}, pauseWhenBuffering = ${pauseWhenBuffering}`,
                mountTime,
            });
            lastSeekDueToShift.current = lastSeek.current;
            if (playing) {
                if (playbackRate > 0) {
                    bufferUntilFirstFrame(shouldBeTime);
                }
                if (mediaRef.current.paused) {
                    (0, play_and_handle_not_allowed_error_js_1.playAndHandleNotAllowedError)({
                        mediaRef,
                        mediaType,
                        onAutoPlayError,
                        logLevel,
                        mountTime,
                        reason: 'player is playing but media tag is paused, and just seeked',
                        isPlayer: env.isPlayer,
                    });
                }
            }
            if (!onlyWarnForMediaSeekingError) {
                (0, warn_about_non_seekable_media_js_1.warnAboutNonSeekableMedia)(mediaRef.current, onlyWarnForMediaSeekingError ? 'console-warning' : 'console-error');
            }
            return;
        }
        const seekThreshold = playing ? 0.15 : 0.01;
        // Only perform a seek if the time is not already the same.
        // Chrome rounds to 6 digits, so 0.033333333 -> 0.033333,
        // therefore a threshold is allowed.
        // Refer to the https://github.com/remotion-dev/video-buffering-example
        // which is fixed by only seeking conditionally.
        const makesSenseToSeek = Math.abs(mediaRef.current.currentTime - shouldBeTime) > seekThreshold;
        const isMediaTagBufferingOrStalled = isMediaTagBuffering || isBuffering();
        const isSomethingElseBuffering = buffering.buffering.current && !isMediaTagBufferingOrStalled;
        if (!playing || isSomethingElseBuffering) {
            if (makesSenseToSeek) {
                lastSeek.current = (0, seek_js_1.seek)({
                    mediaRef: mediaRef.current,
                    time: shouldBeTime,
                    logLevel,
                    why: `not playing or something else is buffering. time offset is over seek threshold (${seekThreshold})`,
                    mountTime,
                });
            }
            return;
        }
        if (!playing || buffering.buffering.current) {
            return;
        }
        // We now assured we are in playing state and not buffering
        const pausedCondition = mediaRef.current.paused && !mediaRef.current.ended;
        const firstFrameCondition = absoluteFrame === 0;
        if (pausedCondition || firstFrameCondition) {
            const reason = pausedCondition
                ? 'media tag is paused'
                : 'absolute frame is 0';
            if (makesSenseToSeek) {
                lastSeek.current = (0, seek_js_1.seek)({
                    mediaRef: mediaRef.current,
                    time: shouldBeTime,
                    logLevel,
                    why: `is over timeshift threshold (threshold = ${seekThreshold}) and ${reason}`,
                    mountTime,
                });
            }
            (0, play_and_handle_not_allowed_error_js_1.playAndHandleNotAllowedError)({
                mediaRef,
                mediaType,
                onAutoPlayError,
                logLevel,
                mountTime,
                reason: `player is playing and ${reason}`,
                isPlayer: env.isPlayer,
            });
            if (!isVariableFpsVideo && playbackRate > 0) {
                bufferUntilFirstFrame(shouldBeTime);
            }
        }
    }, [
        absoluteFrame,
        acceptableTimeShiftButLessThanDuration,
        bufferUntilFirstFrame,
        buffering.buffering,
        rvcCurrentTime,
        logLevel,
        desiredUnclampedTime,
        isBuffering,
        isMediaTagBuffering,
        mediaRef,
        mediaType,
        onlyWarnForMediaSeekingError,
        playbackRate,
        playing,
        src,
        onAutoPlayError,
        isPremounting,
        isPostmounting,
        pauseWhenBuffering,
        mountTime,
        mediaTagCurrentTime,
        env.isPlayer,
    ]);
};
exports.useMediaPlayback = useMediaPlayback;
