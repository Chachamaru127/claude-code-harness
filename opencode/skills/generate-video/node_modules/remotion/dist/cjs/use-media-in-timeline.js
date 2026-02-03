"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useMediaInTimeline = exports.useBasicMediaInTimeline = void 0;
const react_1 = require("react");
const SequenceContext_js_1 = require("./SequenceContext.js");
const SequenceManager_js_1 = require("./SequenceManager.js");
const TimelineContext_js_1 = require("./TimelineContext.js");
const use_audio_frame_js_1 = require("./audio/use-audio-frame.js");
const calculate_media_duration_js_1 = require("./calculate-media-duration.js");
const get_asset_file_name_js_1 = require("./get-asset-file-name.js");
const nonce_js_1 = require("./nonce.js");
const use_remotion_environment_js_1 = require("./use-remotion-environment.js");
const use_video_config_js_1 = require("./use-video-config.js");
const volume_prop_js_1 = require("./volume-prop.js");
const didWarn = {};
const warnOnce = (message) => {
    if (didWarn[message]) {
        return;
    }
    // eslint-disable-next-line no-console
    console.warn(message);
    didWarn[message] = true;
};
const useBasicMediaInTimeline = ({ volume, mediaVolume, mediaType, src, displayName, trimBefore, trimAfter, playbackRate, }) => {
    if (!src) {
        throw new Error('No src passed');
    }
    const startsAt = (0, use_audio_frame_js_1.useMediaStartsAt)();
    const parentSequence = (0, react_1.useContext)(SequenceContext_js_1.SequenceContext);
    const videoConfig = (0, use_video_config_js_1.useVideoConfig)();
    const [initialVolume] = (0, react_1.useState)(() => volume);
    const mediaDuration = (0, calculate_media_duration_js_1.calculateMediaDuration)({
        mediaDurationInFrames: videoConfig.durationInFrames,
        playbackRate,
        trimBefore,
        trimAfter,
    });
    const duration = parentSequence
        ? Math.min(parentSequence.durationInFrames, mediaDuration)
        : mediaDuration;
    const volumes = (0, react_1.useMemo)(() => {
        if (typeof volume === 'number') {
            return volume;
        }
        return new Array(Math.floor(Math.max(0, duration + startsAt)))
            .fill(true)
            .map((_, i) => {
            return (0, volume_prop_js_1.evaluateVolume)({
                frame: i + startsAt,
                volume,
                mediaVolume,
            });
        })
            .join(',');
    }, [duration, startsAt, volume, mediaVolume]);
    (0, react_1.useEffect)(() => {
        if (typeof volume === 'number' && volume !== initialVolume) {
            warnOnce(`Remotion: The ${mediaType} with src ${src} has changed it's volume. Prefer the callback syntax for setting volume to get better timeline display: https://www.remotion.dev/docs/audio/volume`);
        }
    }, [initialVolume, mediaType, src, volume]);
    const doesVolumeChange = typeof volume === 'function';
    const nonce = (0, nonce_js_1.useNonce)();
    const { rootId } = (0, react_1.useContext)(TimelineContext_js_1.TimelineContext);
    const env = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    return {
        volumes,
        duration,
        doesVolumeChange,
        nonce,
        rootId,
        isStudio: env.isStudio,
        finalDisplayName: displayName !== null && displayName !== void 0 ? displayName : (0, get_asset_file_name_js_1.getAssetDisplayName)(src),
    };
};
exports.useBasicMediaInTimeline = useBasicMediaInTimeline;
const useMediaInTimeline = ({ volume, mediaVolume, src, mediaType, playbackRate, displayName, id, stack, showInTimeline, premountDisplay, postmountDisplay, loopDisplay, }) => {
    const parentSequence = (0, react_1.useContext)(SequenceContext_js_1.SequenceContext);
    const startsAt = (0, use_audio_frame_js_1.useMediaStartsAt)();
    const { registerSequence, unregisterSequence } = (0, react_1.useContext)(SequenceManager_js_1.SequenceManager);
    const { volumes, duration, doesVolumeChange, nonce, rootId, isStudio, finalDisplayName, } = (0, exports.useBasicMediaInTimeline)({
        volume,
        mediaVolume,
        mediaType,
        src,
        displayName,
        trimAfter: undefined,
        trimBefore: undefined,
        playbackRate,
    });
    (0, react_1.useEffect)(() => {
        var _a, _b, _c;
        if (!src) {
            throw new Error('No src passed');
        }
        if (!isStudio && ((_b = (_a = window.process) === null || _a === void 0 ? void 0 : _a.env) === null || _b === void 0 ? void 0 : _b.NODE_ENV) !== 'test') {
            return;
        }
        if (!showInTimeline) {
            return;
        }
        registerSequence({
            type: mediaType,
            src,
            id,
            duration,
            from: 0,
            parent: (_c = parentSequence === null || parentSequence === void 0 ? void 0 : parentSequence.id) !== null && _c !== void 0 ? _c : null,
            displayName: finalDisplayName,
            rootId,
            volume: volumes,
            showInTimeline: true,
            nonce,
            startMediaFrom: 0 - startsAt,
            doesVolumeChange,
            loopDisplay,
            playbackRate,
            stack,
            premountDisplay,
            postmountDisplay,
        });
        return () => {
            unregisterSequence(id);
        };
    }, [
        duration,
        id,
        parentSequence,
        src,
        registerSequence,
        unregisterSequence,
        volumes,
        doesVolumeChange,
        nonce,
        mediaType,
        startsAt,
        playbackRate,
        stack,
        showInTimeline,
        premountDisplay,
        postmountDisplay,
        isStudio,
        loopDisplay,
        rootId,
        finalDisplayName,
    ]);
};
exports.useMediaInTimeline = useMediaInTimeline;
