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
exports.AudioForPreview = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = __importStar(require("react"));
const SequenceContext_js_1 = require("../SequenceContext.js");
const SequenceManager_js_1 = require("../SequenceManager.js");
const get_cross_origin_value_js_1 = require("../get-cross-origin-value.js");
const log_level_context_js_1 = require("../log-level-context.js");
const prefetch_js_1 = require("../prefetch.js");
const random_js_1 = require("../random.js");
const use_amplification_js_1 = require("../use-amplification.js");
const use_media_in_timeline_js_1 = require("../use-media-in-timeline.js");
const use_media_playback_js_1 = require("../use-media-playback.js");
const use_media_tag_js_1 = require("../use-media-tag.js");
const volume_position_state_js_1 = require("../volume-position-state.js");
const volume_prop_js_1 = require("../volume-prop.js");
const volume_safeguard_js_1 = require("../volume-safeguard.js");
const shared_audio_tags_js_1 = require("./shared-audio-tags.js");
const use_audio_frame_js_1 = require("./use-audio-frame.js");
const AudioForDevelopmentForwardRefFunction = (props, ref) => {
    var _a, _b, _c, _d;
    const [initialShouldPreMountAudioElements] = (0, react_1.useState)(props.shouldPreMountAudioTags);
    if (props.shouldPreMountAudioTags !== initialShouldPreMountAudioElements) {
        throw new Error('Cannot change the behavior for pre-mounting audio tags dynamically.');
    }
    const logLevel = (0, log_level_context_js_1.useLogLevel)();
    const { volume, muted, playbackRate, shouldPreMountAudioTags, src, onDuration, acceptableTimeShiftInSeconds, _remotionInternalNeedsDurationCalculation, _remotionInternalNativeLoopPassed, _remotionInternalStack, allowAmplificationDuringRender, name, pauseWhenBuffering, showInTimeline, loopVolumeCurveBehavior, stack, crossOrigin, delayRenderRetries, delayRenderTimeoutInMilliseconds, toneFrequency, useWebAudioApi, onError, onNativeError, audioStreamIndex, ...nativeProps } = props;
    // Typecheck that we are not accidentially passing unrecognized props
    // to the DOM
    const _propsValid = true;
    if (!_propsValid) {
        throw new Error('typecheck error');
    }
    const [mediaVolume] = (0, volume_position_state_js_1.useMediaVolumeState)();
    const [mediaMuted] = (0, volume_position_state_js_1.useMediaMutedState)();
    const volumePropFrame = (0, use_audio_frame_js_1.useFrameForVolumeProp)(loopVolumeCurveBehavior !== null && loopVolumeCurveBehavior !== void 0 ? loopVolumeCurveBehavior : 'repeat');
    const { hidden } = (0, react_1.useContext)(SequenceManager_js_1.SequenceVisibilityToggleContext);
    if (!src) {
        throw new TypeError("No 'src' was passed to <Html5Audio>.");
    }
    const preloadedSrc = (0, prefetch_js_1.usePreload)(src);
    const sequenceContext = (0, react_1.useContext)(SequenceContext_js_1.SequenceContext);
    const [timelineId] = (0, react_1.useState)(() => String(Math.random()));
    const isSequenceHidden = (_a = hidden[timelineId]) !== null && _a !== void 0 ? _a : false;
    const userPreferredVolume = (0, volume_prop_js_1.evaluateVolume)({
        frame: volumePropFrame,
        volume,
        mediaVolume,
    });
    (0, volume_safeguard_js_1.warnAboutTooHighVolume)(userPreferredVolume);
    const crossOriginValue = (0, get_cross_origin_value_js_1.getCrossOriginValue)({
        crossOrigin,
        requestsVideoFrame: false,
        isClientSideRendering: false,
    });
    const propsToPass = (0, react_1.useMemo)(() => {
        return {
            muted: muted || mediaMuted || isSequenceHidden || userPreferredVolume <= 0,
            src: preloadedSrc,
            loop: _remotionInternalNativeLoopPassed,
            crossOrigin: crossOriginValue,
            ...nativeProps,
        };
    }, [
        _remotionInternalNativeLoopPassed,
        isSequenceHidden,
        mediaMuted,
        muted,
        nativeProps,
        preloadedSrc,
        userPreferredVolume,
        crossOriginValue,
    ]);
    // Generate a string that's as unique as possible for this asset
    // but at the same time deterministic. We use it to combat strict mode issues.
    const id = (0, react_1.useMemo)(() => `audio-${(0, random_js_1.random)(src !== null && src !== void 0 ? src : '')}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.cumulatedFrom}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.durationInFrames}-muted:${props.muted}-loop:${props.loop}`, [
        src,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.cumulatedFrom,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.durationInFrames,
        props.muted,
        props.loop,
    ]);
    const { el: audioRef, mediaElementSourceNode, cleanupOnMediaTagUnmount, } = (0, shared_audio_tags_js_1.useSharedAudio)({
        aud: propsToPass,
        audioId: id,
        premounting: Boolean(sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.premounting),
        postmounting: Boolean(sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.postmounting),
    });
    (0, use_media_in_timeline_js_1.useMediaInTimeline)({
        volume,
        mediaVolume,
        src,
        mediaType: 'audio',
        playbackRate: playbackRate !== null && playbackRate !== void 0 ? playbackRate : 1,
        displayName: name !== null && name !== void 0 ? name : null,
        id: timelineId,
        stack: _remotionInternalStack,
        showInTimeline,
        premountDisplay: (_b = sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.premountDisplay) !== null && _b !== void 0 ? _b : null,
        postmountDisplay: (_c = sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.postmountDisplay) !== null && _c !== void 0 ? _c : null,
        loopDisplay: undefined,
    });
    // putting playback before useVolume
    // because volume looks at playbackrate
    (0, use_media_playback_js_1.useMediaPlayback)({
        mediaRef: audioRef,
        src,
        mediaType: 'audio',
        playbackRate: playbackRate !== null && playbackRate !== void 0 ? playbackRate : 1,
        onlyWarnForMediaSeekingError: false,
        acceptableTimeshift: acceptableTimeShiftInSeconds !== null && acceptableTimeShiftInSeconds !== void 0 ? acceptableTimeShiftInSeconds : null,
        isPremounting: Boolean(sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.premounting),
        isPostmounting: Boolean(sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.postmounting),
        pauseWhenBuffering,
        onAutoPlayError: null,
    });
    (0, use_media_tag_js_1.useMediaTag)({
        id: timelineId,
        isPostmounting: Boolean(sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.postmounting),
        isPremounting: Boolean(sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.premounting),
        mediaRef: audioRef,
        mediaType: 'audio',
        onAutoPlayError: null,
    });
    (0, use_amplification_js_1.useVolume)({
        logLevel,
        mediaRef: audioRef,
        source: mediaElementSourceNode,
        volume: userPreferredVolume,
        shouldUseWebAudioApi: useWebAudioApi !== null && useWebAudioApi !== void 0 ? useWebAudioApi : false,
    });
    /**
     * Effects in React 18 fire twice, and we are looking for a way to only fire it once.
     * - useInsertionEffect only fires once. If it's available we are in React 18.
     * - useLayoutEffect only fires once in React 17.
     *
     * Need to import it from React to fix React 17 ESM support.
     */
    const effectToUse = (_d = react_1.default.useInsertionEffect) !== null && _d !== void 0 ? _d : react_1.default.useLayoutEffect;
    // Disconnecting the SharedElementSourceNodes if the Audio tag unmounts to prevent leak.
    // https://github.com/remotion-dev/remotion/issues/6285
    // But useInsertionEffect will fire before other effects, meaning the
    // nodes might still be used. Using rAF to ensure it's after other effects.
    effectToUse(() => {
        return () => {
            requestAnimationFrame(() => {
                cleanupOnMediaTagUnmount();
            });
        };
    }, [cleanupOnMediaTagUnmount]);
    (0, react_1.useImperativeHandle)(ref, () => {
        return audioRef.current;
    }, [audioRef]);
    const currentOnDurationCallback = (0, react_1.useRef)(onDuration);
    currentOnDurationCallback.current = onDuration;
    (0, react_1.useEffect)(() => {
        var _a;
        const { current } = audioRef;
        if (!current) {
            return;
        }
        if (current.duration) {
            (_a = currentOnDurationCallback.current) === null || _a === void 0 ? void 0 : _a.call(currentOnDurationCallback, current.src, current.duration);
            return;
        }
        const onLoadedMetadata = () => {
            var _a;
            (_a = currentOnDurationCallback.current) === null || _a === void 0 ? void 0 : _a.call(currentOnDurationCallback, current.src, current.duration);
        };
        current.addEventListener('loadedmetadata', onLoadedMetadata);
        return () => {
            current.removeEventListener('loadedmetadata', onLoadedMetadata);
        };
    }, [audioRef, src]);
    if (initialShouldPreMountAudioElements) {
        return null;
    }
    return ((0, jsx_runtime_1.jsx)("audio", { ref: audioRef, preload: "metadata", crossOrigin: crossOriginValue, ...propsToPass }));
};
exports.AudioForPreview = (0, react_1.forwardRef)(AudioForDevelopmentForwardRefFunction);
