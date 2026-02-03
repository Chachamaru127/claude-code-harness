"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.VideoForRendering = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const RenderAssetManager_js_1 = require("../RenderAssetManager.js");
const SequenceContext_js_1 = require("../SequenceContext.js");
const absolute_src_js_1 = require("../absolute-src.js");
const use_audio_frame_js_1 = require("../audio/use-audio-frame.js");
const is_approximately_the_same_js_1 = require("../is-approximately-the-same.js");
const log_level_context_js_1 = require("../log-level-context.js");
const random_js_1 = require("../random.js");
const timeline_position_state_js_1 = require("../timeline-position-state.js");
const use_current_frame_js_1 = require("../use-current-frame.js");
const use_delay_render_js_1 = require("../use-delay-render.js");
const use_remotion_environment_js_1 = require("../use-remotion-environment.js");
const use_unsafe_video_config_js_1 = require("../use-unsafe-video-config.js");
const volume_prop_js_1 = require("../volume-prop.js");
const volume_safeguard_js_1 = require("../volume-safeguard.js");
const get_current_time_js_1 = require("./get-current-time.js");
const seek_until_right_js_1 = require("./seek-until-right.js");
const VideoForRenderingForwardFunction = ({ onError, volume: volumeProp, allowAmplificationDuringRender, playbackRate, onDuration, toneFrequency, name, acceptableTimeShiftInSeconds, delayRenderRetries, delayRenderTimeoutInMilliseconds, loopVolumeCurveBehavior, audioStreamIndex, onVideoFrame, ...props }, ref) => {
    const absoluteFrame = (0, timeline_position_state_js_1.useTimelinePosition)();
    const frame = (0, use_current_frame_js_1.useCurrentFrame)();
    const volumePropsFrame = (0, use_audio_frame_js_1.useFrameForVolumeProp)(loopVolumeCurveBehavior !== null && loopVolumeCurveBehavior !== void 0 ? loopVolumeCurveBehavior : 'repeat');
    const videoConfig = (0, use_unsafe_video_config_js_1.useUnsafeVideoConfig)();
    const videoRef = (0, react_1.useRef)(null);
    const sequenceContext = (0, react_1.useContext)(SequenceContext_js_1.SequenceContext);
    const mediaStartsAt = (0, use_audio_frame_js_1.useMediaStartsAt)();
    const environment = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    const logLevel = (0, log_level_context_js_1.useLogLevel)();
    const mountTime = (0, log_level_context_js_1.useMountTime)();
    const { delayRender, continueRender } = (0, use_delay_render_js_1.useDelayRender)();
    const { registerRenderAsset, unregisterRenderAsset } = (0, react_1.useContext)(RenderAssetManager_js_1.RenderAssetManager);
    // Generate a string that's as unique as possible for this asset
    // but at the same time the same on all threads
    const id = (0, react_1.useMemo)(() => {
        var _a;
        return `video-${(0, random_js_1.random)((_a = props.src) !== null && _a !== void 0 ? _a : '')}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.cumulatedFrom}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.durationInFrames}`;
    }, [
        props.src,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.cumulatedFrom,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.durationInFrames,
    ]);
    if (!videoConfig) {
        throw new Error('No video config found');
    }
    const volume = (0, volume_prop_js_1.evaluateVolume)({
        volume: volumeProp,
        frame: volumePropsFrame,
        mediaVolume: 1,
    });
    (0, volume_safeguard_js_1.warnAboutTooHighVolume)(volume);
    (0, react_1.useEffect)(() => {
        var _a;
        if (!props.src) {
            throw new Error('No src passed');
        }
        if (props.muted) {
            return;
        }
        if (volume <= 0) {
            return;
        }
        if (!window.remotion_audioEnabled) {
            return;
        }
        registerRenderAsset({
            type: 'video',
            src: (0, absolute_src_js_1.getAbsoluteSrc)(props.src),
            id,
            frame: absoluteFrame,
            volume,
            mediaFrame: frame,
            playbackRate: playbackRate !== null && playbackRate !== void 0 ? playbackRate : 1,
            toneFrequency: toneFrequency !== null && toneFrequency !== void 0 ? toneFrequency : 1,
            audioStartFrame: Math.max(0, -((_a = sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom) !== null && _a !== void 0 ? _a : 0)),
            audioStreamIndex: audioStreamIndex !== null && audioStreamIndex !== void 0 ? audioStreamIndex : 0,
        });
        return () => unregisterRenderAsset(id);
    }, [
        props.muted,
        props.src,
        registerRenderAsset,
        id,
        unregisterRenderAsset,
        volume,
        frame,
        absoluteFrame,
        playbackRate,
        toneFrequency,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom,
        audioStreamIndex,
    ]);
    (0, react_1.useImperativeHandle)(ref, () => {
        return videoRef.current;
    }, []);
    (0, react_1.useEffect)(() => {
        var _a, _b;
        if (!window.remotion_videoEnabled) {
            return;
        }
        const { current } = videoRef;
        if (!current) {
            return;
        }
        const currentTime = (0, get_current_time_js_1.getMediaTime)({
            frame,
            playbackRate: playbackRate || 1,
            startFrom: -mediaStartsAt,
            fps: videoConfig.fps,
        });
        const handle = delayRender(`Rendering <Html5Video /> with src="${props.src}" at time ${currentTime}`, {
            retries: delayRenderRetries !== null && delayRenderRetries !== void 0 ? delayRenderRetries : undefined,
            timeoutInMilliseconds: delayRenderTimeoutInMilliseconds !== null && delayRenderTimeoutInMilliseconds !== void 0 ? delayRenderTimeoutInMilliseconds : undefined,
        });
        if (((_b = (_a = window.process) === null || _a === void 0 ? void 0 : _a.env) === null || _b === void 0 ? void 0 : _b.NODE_ENV) === 'test') {
            continueRender(handle);
            return;
        }
        if ((0, is_approximately_the_same_js_1.isApproximatelyTheSame)(current.currentTime, currentTime)) {
            if (current.readyState >= 2) {
                continueRender(handle);
                return;
            }
            const loadedDataHandler = () => {
                continueRender(handle);
            };
            current.addEventListener('loadeddata', loadedDataHandler, { once: true });
            return () => {
                current.removeEventListener('loadeddata', loadedDataHandler);
            };
        }
        const endedHandler = () => {
            continueRender(handle);
        };
        const seek = (0, seek_until_right_js_1.seekToTimeMultipleUntilRight)({
            element: current,
            desiredTime: currentTime,
            fps: videoConfig.fps,
            logLevel,
            mountTime,
        });
        seek.prom.then(() => {
            continueRender(handle);
        });
        current.addEventListener('ended', endedHandler, { once: true });
        const errorHandler = () => {
            var _a;
            if (current === null || current === void 0 ? void 0 : current.error) {
                // eslint-disable-next-line no-console
                console.error('Error occurred in video', current === null || current === void 0 ? void 0 : current.error);
                // If user is handling the error, we don't cause an unhandled exception
                if (onError) {
                    return;
                }
                throw new Error(`The browser threw an error while playing the video ${props.src}: Code ${current.error.code} - ${(_a = current === null || current === void 0 ? void 0 : current.error) === null || _a === void 0 ? void 0 : _a.message}. See https://remotion.dev/docs/media-playback-error for help. Pass an onError() prop to handle the error.`);
            }
            else {
                throw new Error('The browser threw an error');
            }
        };
        current.addEventListener('error', errorHandler, { once: true });
        // If video skips to another frame or unmounts, we clear the created handle
        return () => {
            seek.cancel();
            current.removeEventListener('ended', endedHandler);
            current.removeEventListener('error', errorHandler);
            continueRender(handle);
        };
    }, [
        volumePropsFrame,
        props.src,
        playbackRate,
        videoConfig.fps,
        frame,
        mediaStartsAt,
        onError,
        delayRenderRetries,
        delayRenderTimeoutInMilliseconds,
        logLevel,
        mountTime,
        continueRender,
        delayRender,
    ]);
    const { src } = props;
    // If video source switches, make new handle
    if (environment.isRendering) {
        // eslint-disable-next-line react-hooks/rules-of-hooks
        (0, react_1.useLayoutEffect)(() => {
            var _a, _b;
            if (((_b = (_a = window.process) === null || _a === void 0 ? void 0 : _a.env) === null || _b === void 0 ? void 0 : _b.NODE_ENV) === 'test') {
                return;
            }
            const newHandle = delayRender('Loading <Html5Video> duration with src=' + src, {
                retries: delayRenderRetries !== null && delayRenderRetries !== void 0 ? delayRenderRetries : undefined,
                timeoutInMilliseconds: delayRenderTimeoutInMilliseconds !== null && delayRenderTimeoutInMilliseconds !== void 0 ? delayRenderTimeoutInMilliseconds : undefined,
            });
            const { current } = videoRef;
            const didLoad = () => {
                if (current === null || current === void 0 ? void 0 : current.duration) {
                    onDuration(src, current.duration);
                }
                continueRender(newHandle);
            };
            if (current === null || current === void 0 ? void 0 : current.duration) {
                onDuration(src, current.duration);
                continueRender(newHandle);
            }
            else {
                current === null || current === void 0 ? void 0 : current.addEventListener('loadedmetadata', didLoad, { once: true });
            }
            // If tag gets unmounted, clear pending handles because video metadata is not going to load
            return () => {
                current === null || current === void 0 ? void 0 : current.removeEventListener('loadedmetadata', didLoad);
                continueRender(newHandle);
            };
        }, [
            src,
            onDuration,
            delayRenderRetries,
            delayRenderTimeoutInMilliseconds,
            continueRender,
            delayRender,
        ]);
    }
    return (0, jsx_runtime_1.jsx)("video", { ref: videoRef, disableRemotePlayback: true, ...props });
};
exports.VideoForRendering = (0, react_1.forwardRef)(VideoForRenderingForwardFunction);
