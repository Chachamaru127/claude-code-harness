"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.VideoForPreview = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = __importStar(require("react"));
const SequenceContext_js_1 = require("../SequenceContext.js");
const SequenceManager_js_1 = require("../SequenceManager.js");
const shared_audio_tags_js_1 = require("../audio/shared-audio-tags.js");
const shared_element_source_node_js_1 = require("../audio/shared-element-source-node.js");
const use_audio_frame_js_1 = require("../audio/use-audio-frame.js");
const get_cross_origin_value_js_1 = require("../get-cross-origin-value.js");
const log_level_context_js_1 = require("../log-level-context.js");
const playback_logging_js_1 = require("../playback-logging.js");
const prefetch_js_1 = require("../prefetch.js");
const use_amplification_js_1 = require("../use-amplification.js");
const use_media_in_timeline_js_1 = require("../use-media-in-timeline.js");
const use_media_playback_js_1 = require("../use-media-playback.js");
const use_media_tag_js_1 = require("../use-media-tag.js");
const use_video_config_js_1 = require("../use-video-config.js");
const version_js_1 = require("../version.js");
const volume_position_state_js_1 = require("../volume-position-state.js");
const volume_prop_js_1 = require("../volume-prop.js");
const volume_safeguard_js_1 = require("../volume-safeguard.js");
const emit_video_frame_js_1 = require("./emit-video-frame.js");
const video_fragment_js_1 = require("./video-fragment.js");
const VideoForDevelopmentRefForwardingFunction = (props, ref) => {
    var _a, _b, _c, _d, _e, _f;
    const context = (0, react_1.useContext)(shared_audio_tags_js_1.SharedAudioContext);
    if (!context) {
        throw new Error('SharedAudioContext not found');
    }
    const videoRef = (0, react_1.useRef)(null);
    const sharedSource = (0, react_1.useMemo)(() => {
        if (!context.audioContext) {
            return null;
        }
        return (0, shared_element_source_node_js_1.makeSharedElementSourceNode)({
            audioContext: context.audioContext,
            ref: videoRef,
        });
    }, [context.audioContext]);
    /**
     * Effects in React 18 fire twice, and we are looking for a way to only fire it once.
     * - useInsertionEffect only fires once. If it's available we are in React 18.
     * - useLayoutEffect only fires once in React 17.
     *
     * Need to import it from React to fix React 17 ESM support.
     */
    const effectToUse = (_a = react_1.default.useInsertionEffect) !== null && _a !== void 0 ? _a : react_1.default.useLayoutEffect;
    // Disconnecting the SharedElementSourceNodes if the tag unmounts to prevent leak.
    // https://github.com/remotion-dev/remotion/issues/6285
    // But useInsertionEffect will fire before other effects, meaning the
    // nodes might still be used. Using rAF to ensure it's after other effects.
    effectToUse(() => {
        return () => {
            requestAnimationFrame(() => {
                sharedSource === null || sharedSource === void 0 ? void 0 : sharedSource.cleanup();
            });
        };
    }, [sharedSource]);
    const { volume, muted, playbackRate, onlyWarnForMediaSeekingError, src, onDuration, 
    // @ts-expect-error
    acceptableTimeShift, acceptableTimeShiftInSeconds, toneFrequency, name, _remotionInternalNativeLoopPassed, _remotionInternalStack, style, pauseWhenBuffering, showInTimeline, loopVolumeCurveBehavior, onError, onAutoPlayError, onVideoFrame, crossOrigin, delayRenderRetries, delayRenderTimeoutInMilliseconds, allowAmplificationDuringRender, useWebAudioApi, audioStreamIndex, ...nativeProps } = props;
    const _propsValid = true;
    if (!_propsValid) {
        throw new Error('typecheck error');
    }
    const volumePropFrame = (0, use_audio_frame_js_1.useFrameForVolumeProp)(loopVolumeCurveBehavior !== null && loopVolumeCurveBehavior !== void 0 ? loopVolumeCurveBehavior : 'repeat');
    const { fps, durationInFrames } = (0, use_video_config_js_1.useVideoConfig)();
    const parentSequence = (0, react_1.useContext)(SequenceContext_js_1.SequenceContext);
    const { hidden } = (0, react_1.useContext)(SequenceManager_js_1.SequenceVisibilityToggleContext);
    const logLevel = (0, log_level_context_js_1.useLogLevel)();
    const mountTime = (0, log_level_context_js_1.useMountTime)();
    const [timelineId] = (0, react_1.useState)(() => String(Math.random()));
    const isSequenceHidden = (_b = hidden[timelineId]) !== null && _b !== void 0 ? _b : false;
    if (typeof acceptableTimeShift !== 'undefined') {
        throw new Error('acceptableTimeShift has been removed. Use acceptableTimeShiftInSeconds instead.');
    }
    const [mediaVolume] = (0, volume_position_state_js_1.useMediaVolumeState)();
    const [mediaMuted] = (0, volume_position_state_js_1.useMediaMutedState)();
    const userPreferredVolume = (0, volume_prop_js_1.evaluateVolume)({
        frame: volumePropFrame,
        volume,
        mediaVolume,
    });
    (0, volume_safeguard_js_1.warnAboutTooHighVolume)(userPreferredVolume);
    (0, use_media_in_timeline_js_1.useMediaInTimeline)({
        volume,
        mediaVolume,
        mediaType: 'video',
        src,
        playbackRate: (_c = props.playbackRate) !== null && _c !== void 0 ? _c : 1,
        displayName: name !== null && name !== void 0 ? name : null,
        id: timelineId,
        stack: _remotionInternalStack,
        showInTimeline,
        premountDisplay: (_d = parentSequence === null || parentSequence === void 0 ? void 0 : parentSequence.premountDisplay) !== null && _d !== void 0 ? _d : null,
        postmountDisplay: (_e = parentSequence === null || parentSequence === void 0 ? void 0 : parentSequence.postmountDisplay) !== null && _e !== void 0 ? _e : null,
        loopDisplay: undefined,
    });
    // putting playback before useVolume
    // because volume looks at playbackrate
    (0, use_media_playback_js_1.useMediaPlayback)({
        mediaRef: videoRef,
        src,
        mediaType: 'video',
        playbackRate: (_f = props.playbackRate) !== null && _f !== void 0 ? _f : 1,
        onlyWarnForMediaSeekingError,
        acceptableTimeshift: acceptableTimeShiftInSeconds !== null && acceptableTimeShiftInSeconds !== void 0 ? acceptableTimeShiftInSeconds : null,
        isPremounting: Boolean(parentSequence === null || parentSequence === void 0 ? void 0 : parentSequence.premounting),
        isPostmounting: Boolean(parentSequence === null || parentSequence === void 0 ? void 0 : parentSequence.postmounting),
        pauseWhenBuffering,
        onAutoPlayError: onAutoPlayError !== null && onAutoPlayError !== void 0 ? onAutoPlayError : null,
    });
    (0, use_media_tag_js_1.useMediaTag)({
        id: timelineId,
        isPostmounting: Boolean(parentSequence === null || parentSequence === void 0 ? void 0 : parentSequence.postmounting),
        isPremounting: Boolean(parentSequence === null || parentSequence === void 0 ? void 0 : parentSequence.premounting),
        mediaRef: videoRef,
        mediaType: 'video',
        onAutoPlayError: onAutoPlayError !== null && onAutoPlayError !== void 0 ? onAutoPlayError : null,
    });
    (0, use_amplification_js_1.useVolume)({
        logLevel,
        mediaRef: videoRef,
        volume: userPreferredVolume,
        source: sharedSource,
        shouldUseWebAudioApi: useWebAudioApi !== null && useWebAudioApi !== void 0 ? useWebAudioApi : false,
    });
    const actualFrom = parentSequence ? parentSequence.relativeFrom : 0;
    const duration = parentSequence
        ? Math.min(parentSequence.durationInFrames, durationInFrames)
        : durationInFrames;
    const preloadedSrc = (0, prefetch_js_1.usePreload)(src);
    const actualSrc = (0, video_fragment_js_1.useAppendVideoFragment)({
        actualSrc: preloadedSrc,
        actualFrom,
        duration,
        fps,
    });
    (0, react_1.useImperativeHandle)(ref, () => {
        return videoRef.current;
    }, []);
    (0, react_1.useState)(() => (0, playback_logging_js_1.playbackLogging)({
        logLevel,
        message: `Mounting video with source = ${actualSrc}, v=${version_js_1.VERSION}, user agent=${typeof navigator === 'undefined' ? 'server' : navigator.userAgent}`,
        tag: 'video',
        mountTime,
    }));
    (0, react_1.useEffect)(() => {
        const { current } = videoRef;
        if (!current) {
            return;
        }
        const errorHandler = () => {
            var _a;
            if (current.error) {
                // eslint-disable-next-line no-console
                console.error('Error occurred in video', current === null || current === void 0 ? void 0 : current.error);
                // If user is handling the error, we don't cause an unhandled exception
                if (onError) {
                    const err = new Error(`Code ${current.error.code}: ${current.error.message}`);
                    onError(err);
                    return;
                }
                throw new Error(`The browser threw an error while playing the video ${src}: Code ${current.error.code} - ${(_a = current === null || current === void 0 ? void 0 : current.error) === null || _a === void 0 ? void 0 : _a.message}. See https://remotion.dev/docs/media-playback-error for help. Pass an onError() prop to handle the error.`);
            }
            else {
                // If user is handling the error, we don't cause an unhandled exception
                if (onError) {
                    const err = new Error(`The browser threw an error while playing the video ${src}`);
                    onError(err);
                    return;
                }
                throw new Error('The browser threw an error while playing the video');
            }
        };
        current.addEventListener('error', errorHandler, { once: true });
        return () => {
            current.removeEventListener('error', errorHandler);
        };
    }, [onError, src]);
    const currentOnDurationCallback = (0, react_1.useRef)(onDuration);
    currentOnDurationCallback.current = onDuration;
    (0, emit_video_frame_js_1.useEmitVideoFrame)({ ref: videoRef, onVideoFrame });
    (0, react_1.useEffect)(() => {
        var _a;
        const { current } = videoRef;
        if (!current) {
            return;
        }
        if (current.duration) {
            (_a = currentOnDurationCallback.current) === null || _a === void 0 ? void 0 : _a.call(currentOnDurationCallback, src, current.duration);
            return;
        }
        const onLoadedMetadata = () => {
            var _a;
            (_a = currentOnDurationCallback.current) === null || _a === void 0 ? void 0 : _a.call(currentOnDurationCallback, src, current.duration);
        };
        current.addEventListener('loadedmetadata', onLoadedMetadata);
        return () => {
            current.removeEventListener('loadedmetadata', onLoadedMetadata);
        };
    }, [src]);
    (0, react_1.useEffect)(() => {
        const { current } = videoRef;
        if (!current) {
            return;
        }
        // Without this, on iOS Safari, the video cannot be seeked.
        // if a seek is triggered before `loadedmetadata` is fired,
        // the video will not seek, even if `loadedmetadata` is fired afterwards.
        // Also, this needs to happen in a useEffect, because otherwise
        // the SSR props will be applied.
        if ((0, video_fragment_js_1.isIosSafari)()) {
            current.preload = 'metadata';
        }
        else {
            current.preload = 'auto';
        }
    }, []);
    const actualStyle = (0, react_1.useMemo)(() => {
        var _a;
        return {
            ...style,
            opacity: isSequenceHidden ? 0 : ((_a = style === null || style === void 0 ? void 0 : style.opacity) !== null && _a !== void 0 ? _a : 1),
        };
    }, [isSequenceHidden, style]);
    const crossOriginValue = (0, get_cross_origin_value_js_1.getCrossOriginValue)({
        crossOrigin,
        requestsVideoFrame: Boolean(onVideoFrame),
        isClientSideRendering: false,
    });
    return ((0, jsx_runtime_1.jsx)("video", { ref: videoRef, muted: muted || mediaMuted || isSequenceHidden || userPreferredVolume <= 0, playsInline: true, src: actualSrc, loop: _remotionInternalNativeLoopPassed, style: actualStyle, disableRemotePlayback: true, crossOrigin: crossOriginValue, ...nativeProps }));
};
exports.VideoForPreview = (0, react_1.forwardRef)(VideoForDevelopmentRefForwardingFunction);
